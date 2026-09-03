local _G = ShaguTweaks.GetGlobalEnv()
local GetExpansion = ShaguTweaks.GetExpansion
local L = ShaguTweaks.L
local API = ShaguTweaks.API

local units = { players = {}, mobs = {} }
local queue = { }
local PASSIVE_CACHE_TTL = 90 * 24 * 60 * 60

local libunitscan = CreateFrame("Frame", "ShaguTweaksUnitScan", UIParent)

-- Chat history can be restored before PLAYER_ENTERING_WORLD. Bind the shared
-- realm player database lazily whenever unit data is queried so every character
-- on the same realm reuses the same class/name cache.
local cacheMigrationDone = false
local cacheMigrationFinalized = false
local cachedCacheRoot
local cachedRealm
local cachedRealmDB
local cachedPlayers
local normalizedRealm

local function GetPlayerTimestamp(data)
  if type(data) ~= "table" then return end

  local seen = type(data.lastseen) == "number" and data.lastseen or nil
  local seenTs = type(data.lastseen_ts) == "number" and data.lastseen_ts or nil

  if seen and seenTs then
    return seen > seenTs and seen or seenTs
  end

  return seen or seenTs
end

local function MergePlayerData(target, source)
  local targetSeen = GetPlayerTimestamp(target)
  local sourceSeen = GetPlayerTimestamp(source)
  local sourceNewer = sourceSeen and
    (not targetSeen or sourceSeen > targetSeen)

  -- Character levels cannot normally go backwards. Prefer the highest known
  -- numeric level even when a newer chat timestamp belongs to an older cached
  -- level, so merging alts cannot regress Chat Levels.
  local targetLevel = tonumber(target.level)
  local sourceLevel = tonumber(source.level)
  local sourceHasBetterLevel = sourceLevel
    and (not targetLevel or sourceLevel > targetLevel)

  for key, value in pairs(source) do
    if key == "lastseen_ts" then
      if type(value) == "number" and
        (type(target.lastseen_ts) ~= "number" or value > target.lastseen_ts)
      then
        target.lastseen_ts = value
      end
    elseif key == "lastseen" then
      if type(value) == "number" then
        if type(target.lastseen) ~= "number" or value > target.lastseen then
          target.lastseen = value
        end
      elseif sourceNewer or target.lastseen == nil then
        target.lastseen = value
      end
    elseif key == "level" then
      -- Never regress a raw player level just because an older level happened
      -- to carry a newer chat timestamp in another character's cache.
      if sourceHasBetterLevel or target.level == nil then
        target.level = value
      end
    elseif key == "clevel" then
      -- Legacy presentation fallback only. Raw level wins whenever available.
      if sourceNewer or target.clevel == nil then
        target.clevel = value
      end
    elseif sourceNewer or target[key] == nil then
      target[key] = value
    end
  end
end

local function NormalizePlayerData(data)
  if type(data) ~= "table" then return end

  -- The old per-character Social Colors cache stored presentation strings.
  -- Those can depend on the current character (level difficulty colors and
  -- optional class-color tweaks), so never keep them once the raw facts needed
  -- to rebuild the display are available in the shared account cache.
  if data.class then
    data.cname = nil
    data.cclass = nil
  end

  local level = tonumber(data.level)
  if level and level > 0 then
    data.clevel = nil
  end
end

local function NormalizePlayerTable(playerdb)
  if type(playerdb) ~= "table" then return end
  for _, data in pairs(playerdb) do
    NormalizePlayerData(data)
  end
end

local function MergePlayerTable(target, source)
  if type(source) ~= "table" or source == target then return end

  for name, data in pairs(source) do
    if type(name) == "string" and type(data) == "table" then
      if type(target[name]) ~= "table" then
        target[name] = data
      else
        MergePlayerData(target[name], data)
      end

      NormalizePlayerData(target[name])
    end
  end
end

local function GetRealmPlayerCache()
  local root = _G.ShaguTweaks_player_cache
  if type(root) ~= "table" then
    root = {}
    _G.ShaguTweaks_player_cache = root
  end

  -- Once the real realm is known, the backing table cannot change during the
  -- character session. Keep the hot GetUnitData path as cheap as it was before
  -- the account-wide migration.
  if cachedCacheRoot == root and cachedRealm and cachedRealm ~= "Unknown"
    and cachedRealmDB == root[cachedRealm]
    and type(cachedRealmDB) == "table"
    and cachedRealmDB.players == cachedPlayers
    and type(cachedPlayers) == "table"
  then
    return cachedPlayers, cachedRealmDB, cachedRealm
  end

  local realm = GetRealmName and GetRealmName() or "Unknown"
  if not realm or realm == "" then realm = "Unknown" end

  if type(root[realm]) ~= "table" then
    root[realm] = {}
  end

  local realmdb = root[realm]
  if type(realmdb.players) ~= "table" then
    realmdb.players = {}
  end

  cachedCacheRoot = root
  cachedRealm = realm
  cachedRealmDB = realmdb
  cachedPlayers = realmdb.players

  return cachedPlayers, cachedRealmDB, cachedRealm
end

local function MigrateLegacyPlayerCaches(playerdb, realmdb, realm)
  -- After PLAYER_ENTERING_WORLD all SavedVariables are settled. Skip legacy
  -- probing entirely on the hot GetUnitData path; PLAYER_LOGOUT re-enables one
  -- final pass so any third-party recreation is still merged before saving.
  if cacheMigrationFinalized and cacheMigrationDone then return end

  local perCharacterPlayers = type(ShaguTweaks_cache) == "table"
    and type(ShaguTweaks_cache.players) == "table"

  local oldGlobal = _G.ShaguTweaks_social_cache
  local oldRealm = type(oldGlobal) == "table" and oldGlobal[realm]
  local oldGlobalPlayers = type(oldRealm) == "table"
    and type(oldRealm.players) == "table" and oldRealm.players
  local oldUnknownRealm = type(oldGlobal) == "table" and realm ~= "Unknown"
    and oldGlobal["Unknown"]
  local oldUnknownPlayers = type(oldUnknownRealm) == "table"
    and type(oldUnknownRealm.players) == "table" and oldUnknownRealm.players
  local hasOldGlobalPlayers = (oldGlobalPlayers and next(oldGlobalPlayers))
    or (oldUnknownPlayers and next(oldUnknownPlayers))

  -- Normally this is a one-time migration. Still check both legacy sources:
  -- the first global-cache test may become available after an earlier cache
  -- lookup, and must not be postponed until PLAYER_LOGOUT.
  if cacheMigrationDone and normalizedRealm == realm
    and not perCharacterPlayers
    and not hasOldGlobalPlayers
  then
    return
  end

  local migratedLegacyPlayers = false

  -- Merge the old per-character cache, then remove its player entries so they
  -- are no longer written back to each character's SavedVariables file.
  if type(ShaguTweaks_cache) == "table" then
    local legacyPlayers = ShaguTweaks_cache.players
    if type(legacyPlayers) == "table" and next(legacyPlayers) then
      -- Grant the migration grace period only once per character. This avoids
      -- an external legacy module recreating players on every session and
      -- postponing the shared 180-day cleanup forever.
      if not ShaguTweaks_cache.player_cache_migrated then
        migratedLegacyPlayers = true
      end

      MergePlayerTable(playerdb, legacyPlayers)
      ShaguTweaks_cache.player_cache_migrated = 1
    end

    ShaguTweaks_cache.players = nil
    ShaguTweaks_cache.players_cleanup = nil
    ShaguTweaks_cache.social_global_migrated = nil
  end

  -- Migrate the first test branch's temporary global Social Colors cache too.
  if type(oldGlobal) == "table" then
    if type(oldRealm) == "table" then
      local oldPlayers = oldRealm.players
      if type(oldPlayers) == "table" then
        if next(oldPlayers) then migratedLegacyPlayers = true end
        MergePlayerTable(playerdb, oldPlayers)
      end

      oldGlobal[realm] = nil
    end

    -- Very early revisions could create an "Unknown" realm bucket before
    -- GetRealmName() was ready. If the real realm is now known, fold that
    -- orphaned test data into it instead of leaving a stale account cache.
    if realm ~= "Unknown" and type(oldUnknownRealm) == "table" then
      local oldPlayers = oldUnknownRealm.players
      if type(oldPlayers) == "table" then
        if next(oldPlayers) then migratedLegacyPlayers = true end
        MergePlayerTable(playerdb, oldPlayers)
      end

      oldGlobal["Unknown"] = nil
    end

    if next(oldGlobal) == nil then
      _G.ShaguTweaks_social_cache = nil
    end
  end

  -- Any character contributing an old cache gets a fresh 180-day grace period.
  -- This prevents a long-unused alt from importing data and having it purged
  -- immediately because of an older cleanup timestamp from another character.
  if migratedLegacyPlayers and time then
    realmdb.players_cleanup = time()
  end

  -- Also clean presentation fields left by earlier revisions of this test
  -- branch that already wrote directly into ShaguTweaks_player_cache. Do this
  -- once per resolved realm, not again during every logout.
  if normalizedRealm ~= realm then
    NormalizePlayerTable(playerdb)
    normalizedRealm = realm
  end

  cacheMigrationDone = true
end

local function EnsurePlayerCache()
  local previousRealm = cachedRealm
  local previousRoot = cachedCacheRoot
  local shared, realmdb, realm = GetRealmPlayerCache()

  if units.players ~= shared then
    local transient = units.players
    units.players = shared
    MergePlayerTable(units.players, transient)

    -- If the cache was touched before the realm name became available, its
    -- temporary Unknown bucket has just been merged into the real realm. Drop
    -- that session-local duplicate so it cannot linger in SavedVariables.
    if previousRealm == "Unknown" and realm ~= "Unknown"
      and previousRoot == _G.ShaguTweaks_player_cache
      and type(previousRoot["Unknown"]) == "table"
      and previousRoot["Unknown"].players == transient
    then
      previousRoot["Unknown"] = nil
    end
  end

  MigrateLegacyPlayerCaches(units.players, realmdb, realm)

  return units.players, realmdb
end

ShaguTweaks.GetPlayerCache = EnsurePlayerCache

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

  EnsurePlayerCache()

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

  EnsurePlayerCache()

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
  local now = time()
  units.players[name].lastseen = now
  units.players[name].lastseen_ts = now
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

local useNameplateUnitEvents = API and API.nameplateevents

libunitscan:RegisterEvent("PLAYER_ENTERING_WORLD")
libunitscan:RegisterEvent("PLAYER_LOGOUT")
libunitscan:RegisterEvent("FRIENDLIST_UPDATE")
libunitscan:RegisterEvent("GUILD_ROSTER_UPDATE")
libunitscan:RegisterEvent("RAID_ROSTER_UPDATE")
libunitscan:RegisterEvent("PARTY_MEMBERS_CHANGED")
libunitscan:RegisterEvent("PLAYER_TARGET_CHANGED")
libunitscan:RegisterEvent("WHO_LIST_UPDATE")
libunitscan:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
if useNameplateUnitEvents then
  libunitscan:RegisterEvent("NAME_PLATE_UNIT_ADDED")
end
for chatEvent in pairs(passiveChatEvents) do
  libunitscan:RegisterEvent(chatEvent)
end

libunitscan:SetScript("OnEvent", function()
  if event == "PLAYER_LOGOUT" then
    -- SavedVariables are written after this event. Re-run the migration here so
    -- even a legacy addon path that recreated ShaguTweaks_cache.players during
    -- the session cannot persist a duplicate per-character player database.
    cacheMigrationFinalized = false
    cacheMigrationDone = false
    EnsurePlayerCache()

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Ensure the saved database is already bound even if another module queried
    -- it earlier while restoring UI state. From here onward SavedVariables are
    -- settled, so future cache reads can skip migration checks completely.
    EnsurePlayerCache()
    cacheMigrationFinalized = true

    -- One cheap cleanup pass at login. Known classes are kept forever.
    PrunePassivePlayers()

    -- update own character details
    local name = UnitName("player")
    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    local guid = API and API.UnitGUID and API.UnitGUID("player")
    AddData("players", name, class, level, nil, guid)

  elseif event == "NAME_PLATE_UNIT_ADDED" then
    -- ClassicAPI exposes an exact nameplateN unit token here. Cache players
    -- passively while they are already visible in the world; this improves
    -- Social Colors/Chat Levels coverage without /who, TargetByName or frame
    -- wrappers, and deliberately does not use NAME_PLATE_CREATED.
    local unit = arg1
    if unit and UnitIsPlayer(unit) then
      local name = UnitName(unit)
      local _, class = UnitClass(unit)
      local level = UnitLevel(unit)
      local guid = API and API.UnitGUID and API.UnitGUID(unit)
      AddData("players", name, class, level, nil, guid)
    end

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

  elseif event == "WHO_LIST_UPDATE" then
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

  -- Active legacy scans sleep while the player has a target. Wake the scanner
  -- only when that target disappears and queued work is actually waiting.
  if event == "PLAYER_TARGET_CHANGED" and next(queue) and
    not UnitExists("target") and not UnitName("target") then
    libunitscan:Show()
  end
end)

-- since TargetByName can only be triggered within vanilla,
-- we can't auto-scan targets on further expansions.
if GetExpansion() == "vanilla" then
  -- setup sound function switches
  local SoundOn = PlaySound
  local SoundOff = function() return end

  libunitscan:SetScript("OnUpdate", function()
    -- A queued legacy scan cannot do useful work while the player already has
    -- a target. Hide completely instead of polling this condition every frame;
    -- PLAYER_TARGET_CHANGED above wakes us when the target is cleared.
    if UnitExists("target") or UnitName("target") then
      this:Hide()
      return
    end

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
