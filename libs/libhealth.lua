local _G = ShaguTweaks.GetGlobalEnv()

-- Real-health fallback for stock Vanilla servers.
--
-- Turtle WoW and some custom clients expose real UnitHealth/UnitHealthMax
-- values directly. Stock 1.12 often exposes target health as 0..100 instead.
-- Keep the original ShaguTweaks estimation idea, but leave it completely
-- dormant until Real Health Numbers asks for it and only listen to combat/
-- health events while the current target actually needs estimation.

local mobdb = {}
local targetKey
local damage = 0
local percent = 0

local libhealth = CreateFrame("Frame")
libhealth.enabled = false
libhealth.reqhit = 2
libhealth.reqdmg = 10

local function InitCache()
  ShaguTweaks_cache = ShaguTweaks_cache or {}
  ShaguTweaks_cache["libhealth"] = ShaguTweaks_cache["libhealth"] or {}
  mobdb = ShaguTweaks_cache["libhealth"]
end

local function IsPercentHealth(unit)
  if not unit or not UnitExists(unit) then return false end

  local cur = _G.UnitHealth(unit)
  local max = _G.UnitHealthMax(unit)

  return cur ~= nil and max == 100 and cur <= 100
end

local function StopSampling()
  libhealth:UnregisterEvent("UNIT_COMBAT")
  libhealth:UnregisterEvent("UNIT_HEALTH")
end

local function StartSampling()
  libhealth:RegisterEvent("UNIT_COMBAT")
  libhealth:RegisterEvent("UNIT_HEALTH")
end

local function SelectTarget()
  StopSampling()

  damage = 0
  percent = _G.UnitHealth("target") or 0
  targetKey = nil

  if not IsPercentHealth("target") then return end

  local name = UnitName("target")
  local level = UnitLevel("target")
  if not name or not level then return end

  targetKey = string.format("%s:%s", name, level)
  StartSampling()
end

local function GetCachedHealth(unitstr, cur, max)
  local name = UnitName(unitstr)
  local level = UnitLevel(unitstr)
  if not name or not level then return cur, max end

  local key = string.format("%s:%s", name, level)
  local data = mobdb[key]
  if data and data[1] and data[2]
    and data[2] > libhealth.reqdmg
    and (not data[3] or data[3] > libhealth.reqhit) then
    return ceil(data[1] / 100 * cur), data[1], true
  end

  return cur, max
end

-- ClassicAPI can expose the real health deficit even when stock UnitHealth()
-- still reports a percentage. Use that as an immediate estimate when possible.
-- At 100% there is no deficit to derive a maximum from, so the historical
-- combat estimator/cache remains useful.
local function GetMissingHealthEstimate(unitstr, cur, max)
  if max ~= 100 or cur >= 100 then return end
  if type(_G.UnitHealthMissing) ~= "function" then return end

  local missing = _G.UnitHealthMissing(unitstr)
  local lostPercent = 100 - cur
  if not missing or missing <= 0 or lostPercent <= 0 then return end

  local estimatedMax = ceil(missing / lostPercent * 100)
  if estimatedMax <= 100 then return end

  local estimatedCur = estimatedMax - missing
  if estimatedCur < 0 then estimatedCur = 0 end

  return estimatedCur, estimatedMax, true
end

function libhealth:GetUnitHealth(unitstr)
  local cur = _G.UnitHealth(unitstr)
  local max = _G.UnitHealthMax(unitstr)

  if not cur or not max then return cur or 0, max or 0 end

  -- Real values are already available: do not estimate.
  if cur > 100 or max > 100 or max < 100 then
    return cur, max, true
  end

  local missingCur, missingMax, missingKnown =
    GetMissingHealthEstimate(unitstr, cur, max)
  if missingKnown then
    return missingCur, missingMax, true
  end

  return GetCachedHealth(unitstr, cur, max)
end

function libhealth:GetUnitHealthByName(name, level, cur, max)
  if not cur or not max then return cur or 0, max or 0 end

  if cur > 100 or max > 100 or max < 100 then
    return cur, max, true
  end

  if not name or not level then return cur, max end

  local key = string.format("%s:%s", name, level)
  local data = mobdb[key]
  if data and data[1] and data[2]
    and data[2] > libhealth.reqdmg
    and (not data[3] or data[3] > libhealth.reqhit) then
    return ceil(data[1] / 100 * cur), data[1], true
  end

  return cur, max
end

function libhealth:Enable()
  if self.enabled then return end
  self.enabled = true

  InitCache()

  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  SelectTarget()
end

function libhealth:Disable()
  if not self.enabled then return end
  self.enabled = false

  self:UnregisterAllEvents()
  targetKey = nil
  damage = 0
  percent = 0
end

libhealth:SetScript("OnEvent", function()
  if not libhealth.enabled then return end

  if event == "PLAYER_ENTERING_WORLD" then
    InitCache()
    SelectTarget()
  elseif event == "PLAYER_TARGET_CHANGED" then
    SelectTarget()
  elseif targetKey and event == "UNIT_COMBAT" and arg1 == "target" then
    if arg2 == "HEAL" then return end

    local amount = tonumber(arg4) or 0
    if amount > 0 then
      damage = damage + amount
    end
  elseif targetKey and event == "UNIT_HEALTH" and arg1 == "target" then
    local currentPercent = _G.UnitHealth("target") or 0
    local diff = percent - currentPercent

    if damage > 0 and diff > 0 then
      local estimate = ceil(damage / diff * 100)
      local data = mobdb[targetKey]

      if not data or not data[2] or diff > data[2] then
        mobdb[targetKey] = {
          estimate,
          diff,
          data and data[3] and data[3] + 1 or 1,
        }
      elseif data then
        data[3] = data[3] and data[3] + 1 or 1
      end
    end

    damage = 0
    percent = currentPercent
  end
end)

ShaguTweaks.libhealth = libhealth
