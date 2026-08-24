local _G = ShaguTweaks.GetGlobalEnv()
local GetExpansion = ShaguTweaks.GetExpansion
local L = ShaguTweaks.L
local API = ShaguTweaks.API

local units = { players = {}, mobs = {} }
local queue = { }
local PASSIVE_CACHE_TTL = 90 * 24 * 60 * 60

local libunitscan = CreateFrame("Frame", "ShaguTweaksUnitScan", UIParent)

local function EnrichPlayerFromClassicAPI(name)
  if not name or not API or not API.GetCachedPlayerInfoByName then return end

  local _, class, _, _, _, _, _, guid = API.GetCachedPlayerInfoByName(name)
  class = class and class ~= "" and class or nil
  guid = guid and guid ~= "" and guid or nil
  if not class and not guid then return end

  -- Keep ShaguTweaks keyed by the exact name it already knows. This avoids
  -- duplicate SavedVariable entries if another cache normalizes name casing.
  units.players[name] = units.players[name] or {}
  units.players[name].class = class or units.players[name].class
  units.players[name].guid = guid or units.players[name].guid

  return name
end

local function EnrichPlayerFromCurrentChat(name)
  if not name or not API or not API.GetCurrentChatGUID or not API.GetPlayerInfoByGUID then return end

  -- ChatFrame:AddMessage can run before our CHAT_MSG_* listener has populated
  -- the passive cache. ClassicAPI exposes the current chat sender GUID during
  -- that same dispatch, so resolve the class synchronously when the GUID really
  -- belongs to the player name being requested.
  local guid = API.GetCurrentChatGUID()
  if not guid or guid == "" then return end

  local apiName, class = API.GetPlayerInfoByGUID(guid)
  class = class and class ~= "" and class or nil
  if not apiName or apiName == "" or not class then return end
  if string.lower(apiName) ~= string.lower(name) then return end

  units.players[name] = units.players[name] or {}
  units.players[name].class = class
  units.players[name].guid = guid

  return name
end

function ShaguTweaks.GetUnitData(name, active)
  if not name then return end

  if not units["players"][name] then
    EnrichPlayerFromClassicAPI(name)
    if not units["players"][name] then
      EnrichPlayerFromCurrentChat(name)
    end
  elseif not units["players"][name].class then
    EnrichPlayerFromClassicAPI(name)
    if not units["players"][name].class then
      EnrichPlayerFromCurrentChat(name)
    end
  end

  if units["players"][name] then
    local ret = units["players"][name]
    return ret.class, ret.level, ret.elite, true
  end

  if units["mobs"][name] then
    local ret = units["mobs"][name]
    return ret.class, ret.level, ret.elite, nil
  elseif active then
    queue[name] = true
    libunitscan:Show()
  end
end

local function AddData(db, name, class, level, elite, guid)
  if not name then return end
  units[db][name] = units[db][name] or {}
  units[db][name].class = class or units[db][name].class
  units[db][name].level = level or units[db][name].level
  units[db][name].elite = elite or units[db][name].elite
  units[db][name].guid = guid or units[db][name].guid
  queue[name] = nil
end

local function RememberPlayer(name)
  if not name or name == "" or name == _G.UNKNOWN then return end

  ShaguTweaks_cache = ShaguTweaks_cache or {}
  ShaguTweaks_cache["players"] = ShaguTweaks_cache["players"] or {}
  units.players = ShaguTweaks_cache["players"]

  -- ClassicAPI exposes the GUID of the CHAT_MSG_* sender synchronously.
  -- Resolve class from the engine's existing name cache only: this is a pure
  -- cache read and never sends a /who or any other network query.
  local guid = API and API.GetCurrentChatGUID and API.GetCurrentChatGUID()
  guid = guid and guid ~= "" and guid or nil

  local class
  if guid and API.GetPlayerInfoByGUID then
    local _, apiClass = API.GetPlayerInfoByGUID(guid)
    class = apiClass and apiClass ~= "" and apiClass or nil
  end

  units.players[name] = units.players[name] or {}
  units.players[name].class = class or units.players[name].class
  units.players[name].guid = guid or units.players[name].guid
  units.players[name].lastseen = date("%a %d-%b-%Y")
  units.players[name].lastseen_ts = time()
end

local function PrunePassivePlayers()
  local now = time()

  for name, data in pairs(units.players) do
    -- Normalize any empty legacy/API class token back to an unknown value.
    if data and data.class == "" then data.class = nil end

    -- Keep every player whose class was learned. Only anonymous/passive chat
    -- entries expire, and only when they carry our numeric last-seen timestamp.
    if data and not data.class and data.lastseen_ts and
      now - data.lastseen_ts > PASSIVE_CACHE_TTL then
      units.players[name] = nil
    end
  end
end

ShaguTweaks.RememberPlayer = RememberPlayer

local passiveChatEvents = {
  ["CHAT_MSG_CHANNEL"] = true,
  ["CHAT_MSG_SAY"] = true,
  ["CHAT_MSG_YELL"] = true,
  ["CHAT_MSG_GUILD"] = true,
  ["CHAT_MSG_OFFICER"] = true,
  ["CHAT_MSG_PARTY"] = true,
  ["CHAT_MSG_RAID"] = true,
  ["CHAT_MSG_RAID_LEADER"] = true,
  ["CHAT_MSG_RAID_WARNING"] = true,
  ["CHAT_MSG_BATTLEGROUND"] = true,
  ["CHAT_MSG_BATTLEGROUND_LEADER"] = true,
  ["CHAT_MSG_WHISPER"] = true,
}

libunitscan:RegisterEvent("PLAYER_ENTERING_WORLD")
libunitscan:RegisterEvent("FRIENDLIST_UPDATE")
libunitscan:RegisterEvent("GUILD_ROSTER_UPDATE")
libunitscan:RegisterEvent("RAID_ROSTER_UPDATE")
libunitscan:RegisterEvent("PARTY_MEMBERS_CHANGED")
libunitscan:RegisterEvent("PLAYER_TARGET_CHANGED")
libunitscan:RegisterEvent("WHO_LIST_UPDATE")
libunitscan:RegisterEvent("CHAT_MSG_SYSTEM")
libunitscan:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
for chatEvent in pairs(passiveChatEvents) do
  libunitscan:RegisterEvent(chatEvent)
end

libunitscan:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    -- load database
    ShaguTweaks_cache = ShaguTweaks_cache or {}
    ShaguTweaks_cache["players"] = ShaguTweaks_cache["players"] or {}
    units.players = ShaguTweaks_cache["players"]

    -- One cheap cleanup pass at login. Known classes are kept forever.
    PrunePassivePlayers()

    -- update own character details
    local name = UnitName("player")
    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    local guid = API and API.UnitGUID and API.UnitGUID("player")
    AddData("players", name, class, level, nil, guid)

  elseif passiveChatEvents[event] then
    -- Passive cache only: remember speakers already delivered by the client.
    -- No /who, no TargetByName queue, no timer and no additional server query.
    RememberPlayer(arg2)

  elseif event == "FRIENDLIST_UPDATE" then
    local name, class, level
    for i = 1, GetNumFriends() do
      name, level, class = GetFriendInfo(i)
      class = L["class"][class] or nil
      -- friendlist updates due to friend going off-line return level 0, let's not overwrite good older values
      level = level > 0 and level or nil
      AddData("players", name, class, level)
    end

  elseif event == "GUILD_ROSTER_UPDATE" then
    local name, class, level, _
    for i = 1, GetNumGuildMembers() do
      name, _, _, level, class = GetGuildRosterInfo(i)
      class = L["class"][class] or nil
      AddData("players", name, class, level)
    end

  elseif event == "RAID_ROSTER_UPDATE" then
    local name, class, SubGroup, level, _
    for i = 1, GetNumRaidMembers() do
      name, _, SubGroup, level, class = GetRaidRosterInfo(i)
      class = L["class"][class] or nil
      local guid = API and API.UnitGUID and API.UnitGUID("raid" .. i)
      AddData("players", name, class, level, nil, guid)
    end

  elseif event == "PARTY_MEMBERS_CHANGED" then
    local name, class, level, unit, _
    for i = 1, GetNumPartyMembers() do
      unit = "party" .. i
      _, class = UnitClass(unit)
      name = UnitName(unit)
      level = UnitLevel(unit)
      local guid = API and API.UnitGUID and API.UnitGUID(unit)
      AddData("players", name, class, level, nil, guid)
    end

  elseif event == "WHO_LIST_UPDATE" or event == "CHAT_MSG_SYSTEM" then
    local name, class, level, _
    for i = 1, GetNumWhoResults() do
      name, _, level, _, class, _ = GetWhoInfo(i)
      class = L["class"][class] or nil
      AddData("players", name, class, level)
    end

  elseif event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_TARGET_CHANGED" then
    local scan = event == "PLAYER_TARGET_CHANGED" and "target" or "mouseover"
    local name, class, level, elite, _
    if UnitIsPlayer(scan) then
      _, class = UnitClass(scan)
      level = UnitLevel(scan)
      name = UnitName(scan)
      local guid = API and API.UnitGUID and API.UnitGUID(scan)
      AddData("players", name, class, level, nil, guid)
    else
      _, class = UnitClass(scan)
      elite = UnitClassification(scan)
      level = UnitLevel(scan)
      name = UnitName(scan)
      AddData("mobs", name, class, level, elite)
    end
  end
end)

-- since TargetByName can only be triggered within vanilla,
-- we can't auto-scan targets on further expansions.
if GetExpansion() == "vanilla" then
  -- setup sound function switches
  local SoundOn = PlaySound
  local SoundOff = function() return end

  libunitscan:SetScript("OnUpdate", function()
    -- don't scan when another unit is in target
    if UnitExists("target") or UnitName("target") then return end

    local name = next(queue)
    if name then
      -- disable sound
      _G.PlaySound = SoundOff

      -- try to target the unknown unit
      TargetByName(name, true)
      ClearTarget()

      -- enable sound again
      _G.PlaySound = SoundOn

      queue[name] = nil
    end

    this:Hide()
  end)
end
