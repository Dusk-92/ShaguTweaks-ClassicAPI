local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Chat Spam Filter"],
  description = T["Hides repeated messages in say/yell/channel chat (70s cooldown per unique message). Also suppresses BigWigs cast spam and #showtooltip errors."],
  expansions = { ["vanilla"] = true },
  category = T["Chat & Social"],
  enabled = nil,
})

-- how long (in seconds) a given message text stays "known" and gets suppressed on repeat
local COOLDOWN = 70

-- how often (in seconds) stale entries may be pruned when chat traffic arrives
local CLEAN_INTERVAL = 30

-- double-buffered cache of [frame] = {message = last_seen_time}, keyed per
-- chat frame so that a message shown in one tab (e.g. "General") doesn't
-- get treated as a duplicate when it also needs to show in another tab
-- (e.g. a custom "World" tab)
local cache = { {}, {}, INDEX = 1 }
local last_cleanup = 0

local canFilterEmotes = API and API.guildmembership and API.friendmembership

local function IsGuildMate(name)
  return name and API.UnitIsInMyGuild(name) or false
end

local function IsFriendOf(name)
  return name and API.IsFriend(name) or false
end

local function PruneCache(now)
  if now - last_cleanup < CLEAN_INTERVAL then return end
  last_cleanup = now

  local index = cache.INDEX
  local newindex = (index == 1) and 2 or 1
  cache[newindex] = {}

  for frame, frameCache in pairs(cache[index]) do
    for msg, seen_at in pairs(frameCache) do
      if (seen_at + COOLDOWN) > now then
        cache[newindex][frame] = cache[newindex][frame] or {}
        cache[newindex][frame][msg] = seen_at
      end
    end
  end

  cache[index] = {}
  cache.INDEX = newindex
end

-- returns true (and records the message) if this exact text was already seen
-- on this specific chat frame within the cooldown window
local function IsDuplicate(frame, msg)
  local now = GetTime()
  PruneCache(now)

  local index = cache.INDEX
  local frameCache = cache[index][frame]
  if not frameCache then
    frameCache = {}
    cache[index][frame] = frameCache
  end

  local seen_at = frameCache[msg]
  if seen_at and (seen_at + COOLDOWN) > now then
    return true
  end

  frameCache[msg] = now
  return false
end

-- SuperWoW exposes GetUnitName (faster / more reliable than UnitName),
-- fall back to the vanilla API if it's not loaded
local GetPlayerName = GetUnitName or UnitName

module.enable = function(self)
  -- force an early guild roster sync: GetNumGuildMembers() returns 0 until
  -- the roster has been fetched at least once, which would otherwise let
  -- guildmate emotes get filtered right after login/reload
  if IsInGuild() then
    GuildRoster()
  end

  local Original_ChatFrame_OnEvent = ChatFrame_OnEvent

  ChatFrame_OnEvent = function(event)
    -- suppress "#showtooltip" macro errors leaking into chat
    if strfind(arg1 or "", "^#showtooltip") then
      return
    end

    -- suppress BigWigs "Casted X on Y" cast announcements
    if event == "CHAT_MSG_SAY" and strfind(arg1 or "", "^Casted %u[%a%s]+ on %u[%a%s]+") then
      return
    end

    -- hide repeated messages in say/yell/channel chat, and emotes from
    -- strangers (guildmates/friends are never filtered on emote)
    if arg1 and arg2 and arg2 ~= GetPlayerName("player") then
      local isChatType = event == "CHAT_MSG_SAY" or event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_YELL"
      local isStrangerEmote = canFilterEmotes and event == "CHAT_MSG_EMOTE"
        and not (IsGuildMate(arg2) or IsFriendOf(arg2))

      if (isChatType or isStrangerEmote) and IsDuplicate(this, arg1) then
        return
      end
    end

    return Original_ChatFrame_OnEvent(event)
  end
end
