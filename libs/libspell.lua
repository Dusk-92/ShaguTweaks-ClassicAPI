local _G = ShaguTweaks.GetGlobalEnv()
local API = ShaguTweaks.API
local libtipscan = ShaguTweaks.libtipscan

-- Current ClassicAPI supplies spell metadata directly. Create the tooltip
-- scanner only if that surface is unavailable for a specific lookup.
local scanner
local function GetScanner()
  if not scanner then
    scanner = libtipscan:GetScanner("libspell")
  end
  return scanner
end

local libspell = {}
local spellmaxrank = {}
local spellindex = {}
local spellinfo = {}

local function ClearSpellCaches()
  spellmaxrank = {}
  spellindex = {}
  spellinfo = {}
end

-- Learned ranks and talent/trainer changes can invalidate both successful and
-- negative spellbook lookups. Without clearing these caches, a spell queried
-- before it was learned can remain "missing" until the next UI reload.
local events = CreateFrame("Frame")
events:RegisterEvent("LEARNED_SPELL_IN_TAB")
if API.eventutils and _G.C_EventUtils
  and _G.C_EventUtils.IsEventValid("SPELLS_CHANGED") then
  events:RegisterEvent("SPELLS_CHANGED")
end
events:SetScript("OnEvent", ClearSpellCaches)

-- [ GetSpellMaxRank ]
-- Returns the maximum rank of a players spell.
-- 'name'       [string]            spellname to query
-- return:      [string],[number]   maximum rank in characters and the number
--                                  e.g "Rank 1" and "1"
function libspell.GetSpellMaxRank(name)
  local cache = spellmaxrank[name]
  if cache then return cache[1], cache[2] end

  local rank = { 0, nil}
  for i = 1, GetNumSpellTabs() do
    local _, _, offset, num = GetSpellTabInfo(i)
    local bookType = BOOKTYPE_SPELL
    for id = offset + 1, offset + num do
      local spellName, spellRank = GetSpellName(id, bookType)
      if spellName == name then
        if not rank[2] then rank[2] = spellRank end

        local _, _, numRank = string.find(spellRank, " (%d+)$")
        if numRank and tonumber(numRank) > rank[1] then
          rank = { tonumber(numRank), spellRank}
        end
      end
    end
  end

  spellmaxrank[name] = { rank[2], rank[1] }
  return rank[2], rank[1]
end

-- [ GetSpellIndex ]
-- Returns the spellbook index and bookid of the given spell.
-- 'name'       [string]            spellname to query
-- 'rank'       [string]            rank to query (optional)
-- return:      [number],[string]   spell index and spellbook id
function libspell.GetSpellIndex(name, rank)
  if not name then return end
  local cache = spellindex[name..(rank or "")]
  if cache then return cache[1], cache[2] end

  if not rank then rank = libspell.GetSpellMaxRank(name) end

  for i = 1, GetNumSpellTabs() do
    local _, _, offset, num = GetSpellTabInfo(i)
    local bookType = BOOKTYPE_SPELL
    for id = offset + 1, offset + num do
      local spellName, spellRank = GetSpellName(id, bookType)
      if rank and rank == spellRank and name == spellName then
        spellindex[name..rank] = { id, bookType }
        return id, bookType
      elseif not rank and name == spellName then
        spellindex[name] = { id, bookType }
        return id, bookType
      end
    end
  end
  spellindex[name..(rank or "")] = { nil }
  return nil
end

-- [ GetSpellInfo ]
-- Returns several information about a spell.
-- 'index'      [string/number]     Spellname or Index of a spell in the spellbook
-- 'bookType'   [string]            Type of spellbook (optional)
-- return:
--              [string]            Name of the spell
--              [string]            Secondary text associated with the spell
--                                  (e.g."Rank 5", "Racial", etc.)
--              [string]            Path to an icon texture for the spell
--              [number]            Casting time of the spell in milliseconds
--              [number]            Minimum range from the target required to cast the spell
--              [number]            Maximum range from the target at which you can cast the spell
function libspell.GetSpellInfo(index, bookType)
  local cacheKey = tostring(index) .. ":" .. tostring(bookType or "")
  local cache = spellinfo[cacheKey]
  if cache then return cache[1], cache[2], cache[3], cache[4], cache[5], cache[6] end

  -- ClassicAPI resolves spell IDs, spellbook slots, spell names and explicit
  -- ranks directly in native code. Use that first so normal casts never walk
  -- the Lua spellbook or build a hidden tooltip.
  local name, rank, icon, _, _, _, castingTime, minRange, maxRange =
    API.GetSpellInfo(index, bookType)

  if name then
    spellinfo[cacheKey] = {
      name,
      rank or "",
      icon or "",
      castingTime or 0,
      minRange or 0,
      maxRange or 0,
    }
    return name, rank or "", icon or "", castingTime or 0,
      minRange or 0, maxRange or 0
  end

  -- Defensive compatibility path for an older ClassicAPI build that does not
  -- expose the direct GetSpellInfo resolver. This path stays cold on current
  -- ClassicAPI and preserves the historical ShaguTweaks behavior.
  local id
  icon = ""
  castingTime = 0
  minRange = 0
  maxRange = 0

  if type(index) == "string" then
    local _, _, sname, srank = string.find(index, '(.+)%((.+)%)')
    name = sname or index
    rank = srank or libspell.GetSpellMaxRank(name)
    id, bookType = libspell.GetSpellIndex(name, rank)
  else
    name, rank = GetSpellName(index, bookType)
    id, bookType = libspell.GetSpellIndex(name, rank)
  end

  if id then
    icon = GetSpellTexture(id, bookType) or ""
    local tip = GetScanner()
    tip:SetSpell(id, bookType)
    local _, sec = tip:Find(gsub(SPELL_CAST_TIME_SEC, "%%.3g", "%(.+%)"))
    local _, min = tip:Find(gsub(SPELL_CAST_TIME_MIN, "%%.3g", "%(.+%)"))
    local _, range = tip:Find(gsub(SPELL_RANGE, "%%s", "%(.+%)"))
    castingTime = (tonumber(sec) or tonumber(min) or 0) * 1000
    if range then
      local _, _, low, high = string.find(range, "(.+)-(.+)")
      if low and high then
        minRange = tonumber(low)
        maxRange = tonumber(high)
      else
        minRange = 0
        maxRange = tonumber(range)
      end
    end
  end

  spellinfo[cacheKey] = { name, rank, icon, castingTime, minRange, maxRange }
  return name, rank, icon, castingTime, minRange, maxRange
end

ShaguTweaks.libspell = libspell
