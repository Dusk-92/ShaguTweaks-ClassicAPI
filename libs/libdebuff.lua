local _G = ShaguTweaks.GetGlobalEnv()
local L = ShaguTweaks.L
local API = ShaguTweaks.API
local GetExpansion = ShaguTweaks.GetExpansion
local libtipscan = ShaguTweaks.libtipscan
local libspell = ShaguTweaks.libspell
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local QueueFunction = ShaguTweaks.QueueFunction
local cmatch = ShaguTweaks.cmatch

-- return instantly if we're not on a vanilla client
if GetExpansion() ~= "vanilla" then return end

-- fix a typo (missing $) in ruRU capture index
if GetLocale() == "ruRU" then
  SPELLREFLECTSELFOTHER = gsub(SPELLREFLECTSELFOTHER, "%%2s", "%%2%$s")
end

local libdebuff = CreateFrame("Frame", "ShaguTweaksDebuffsScanner", UIParent)
local scanner
local function GetScanner()
  if not scanner then
    scanner = libtipscan:GetScanner("libdebuff")
  end
  return scanner
end
local _, class = UnitClass("player")
local lastspell

function libdebuff:GetDuration(effect, rank)
  if L["debuffs"][effect] then
    local rank = rank and tonumber((string.gsub(rank, RANK .. " ", ""))) or 0
    local rank = L["debuffs"][effect][rank] and rank or libdebuff:GetMaxRank(effect)
    local duration = L["debuffs"][effect][rank]

    if effect == L["dyndebuffs"]["Rupture"] then
      -- Rupture: +2 sec per combo point
      duration = duration + GetComboPoints()*2
    elseif effect == L["dyndebuffs"]["Kidney Shot"] then
      -- Kidney Shot: +1 sec per combo point
      duration = duration + GetComboPoints()*1
    elseif effect == L["dyndebuffs"]["Demoralizing Shout"] then
      -- Booming Voice: 10% per talent
      local _,_,_,_,count = GetTalentInfo(2,1)
      if count and count > 0 then duration = duration + ( duration / 100 * (count*10)) end
    elseif effect == L["dyndebuffs"]["Shadow Word: Pain"] then
      -- Improved Shadow Word: Pain: +3s per talent
      local _,_,_,_,count = GetTalentInfo(3,4)
      if count and count > 0 then duration = duration + count * 3 end
    elseif effect == L["dyndebuffs"]["Frostbolt"] then
      -- Permafrost: +1s per talent
      local _,_,_,_,count = GetTalentInfo(3,7)
      if count and count > 0 then duration = duration + count end
    elseif effect == L["dyndebuffs"]["Gouge"] then
      -- Improved Gouge: +.5s per talent
      local _,_,_,_,count = GetTalentInfo(2,1)
      if count and count > 0 then duration = duration + (count*.5) end
    end
    return duration
  else
    return 0
  end
end

function libdebuff:UpdateDuration(unit, unitlevel, effect, duration)
  if not unit or not effect or not duration then return end
  unitlevel = unitlevel or 0

  if libdebuff.objects[unit] and libdebuff.objects[unit][unitlevel] and libdebuff.objects[unit][unitlevel][effect] then
    libdebuff.objects[unit][unitlevel][effect].duration = duration
  end
end

function libdebuff:GetMaxRank(effect)
  local max = 0
  for id in pairs(L["debuffs"][effect]) do
    if id > max then max = id end
  end
  return max
end

function libdebuff:UpdateUnits()
  TargetDebuffButton_Update()
end

function libdebuff:AddPending(unit, unitlevel, effect, duration)
  if not unit then return end
  if not L["debuffs"][effect] then return end

  duration = duration or libdebuff:GetDuration(effect)
  if duration > 0 and libdebuff.pending[3] ~= effect then
    libdebuff.pending[1] = unit
    libdebuff.pending[2] = unitlevel or 0
    libdebuff.pending[3] = effect
    libdebuff.pending[4] = duration
  end
end

function libdebuff:RemovePending()
  libdebuff.pending[1] = nil
  libdebuff.pending[2] = nil
  libdebuff.pending[3] = nil
  libdebuff.pending[4] = nil
end

function libdebuff:PersistPending(effect)
  if not libdebuff.pending[3] then return end
  if libdebuff.pending[3] == effect or ( effect == nil and libdebuff.pending[3] ) then
    libdebuff:AddEffect(libdebuff.pending[1], libdebuff.pending[2], libdebuff.pending[3], libdebuff.pending[4])
    libdebuff:RemovePending()
  end
end

function libdebuff:RevertLastAction()
  lastspell.start = lastspell.start_old
  lastspell.start_old = nil
  libdebuff:UpdateUnits()
end

function libdebuff:AddEffect(unit, unitlevel, effect, duration, deferUpdate)
  if not unit or not effect then return end
  unitlevel = unitlevel or 0
  if not libdebuff.objects[unit] then libdebuff.objects[unit] = {} end
  if not libdebuff.objects[unit][unitlevel] then libdebuff.objects[unit][unitlevel] = {} end
  if not libdebuff.objects[unit][unitlevel][effect] then libdebuff.objects[unit][unitlevel][effect] = {} end

  -- save current effect as lastspell
  lastspell = libdebuff.objects[unit][unitlevel][effect]

  libdebuff.objects[unit][unitlevel][effect].effect = effect
  libdebuff.objects[unit][unitlevel][effect].start_old = libdebuff.objects[unit][unitlevel][effect].start
  libdebuff.objects[unit][unitlevel][effect].start = GetTime()
  libdebuff.objects[unit][unitlevel][effect].duration = duration or libdebuff:GetDuration(effect)

  if not deferUpdate then
    libdebuff:UpdateUnits()
  end
end

-- ClassicAPI exposes aura identity and timing directly. The old periodic
-- combat-text parser only exists to reconstruct off-target applications on
-- older ClassicAPI builds; current ClassicAPI does not register those noisy
-- events at all.
if not (API and API.aurapositional and API.UnitDebuff) then
  libdebuff:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
  libdebuff:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
end

-- These events still support the legacy estimated-duration fallback when an
-- exact expiration time is unavailable.
libdebuff:RegisterEvent("CHAT_MSG_SPELL_FAILED_LOCALPLAYER")
libdebuff:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
libdebuff:RegisterEvent("PLAYER_TARGET_CHANGED")
libdebuff:RegisterEvent("SPELLCAST_STOP")
libdebuff:RegisterEvent("UNIT_AURA")

-- register seal handler
if class == "PALADIN" then
  libdebuff:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
end

-- Remove Pending
libdebuff.rp = { SPELLIMMUNESELFOTHER, IMMUNEDAMAGECLASSSELFOTHER,
  SPELLMISSSELFOTHER, SPELLRESISTSELFOTHER, SPELLEVADEDSELFOTHER,
  SPELLDODGEDSELFOTHER, SPELLDEFLECTEDSELFOTHER, SPELLREFLECTSELFOTHER,
  SPELLPARRIEDSELFOTHER, SPELLLOGABSORBSELFOTHER }

libdebuff.objects = {}
libdebuff.pending = {}

-- Gather Data by Events
libdebuff:SetScript("OnEvent", function()
  -- paladin seal refresh
  if event == "CHAT_MSG_COMBAT_SELF_HITS" then
    local hit = cmatch(arg1, COMBATHITSELFOTHER)
    local crit = cmatch(arg1, COMBATHITCRITSELFOTHER)
    if hit or crit then
      for seal in L["judgements"] do
        local name = UnitName("target")
        local level = UnitLevel("target")
        if name and libdebuff.objects[name] then
          if level and libdebuff.objects[name][level] and libdebuff.objects[name][level][seal] then
            libdebuff:AddEffect(name, level, seal)
          elseif libdebuff.objects[name][0] and libdebuff.objects[name][0][seal] then
            libdebuff:AddEffect(name, 0, seal)
          end
        end
      end
    end

  -- Add Combat Log
  elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
    local unit, effect = cmatch(arg1, AURAADDEDOTHERHARMFUL)
    if unit and effect then
      local unitlevel = UnitName("target") == unit and UnitLevel("target") or 0
      if not libdebuff.objects[unit] or not libdebuff.objects[unit][unitlevel] or not libdebuff.objects[unit][unitlevel][effect] then
        libdebuff:AddEffect(unit, unitlevel, effect)
      end
    end

  -- Add Missing Buffs by Iteration
  elseif ( event == "UNIT_AURA" and arg1 == "target" ) or event == "PLAYER_TARGET_CHANGED" then
    local unit = UnitName("target")
    if not unit then return end

    local unitlevel = UnitLevel("target") or 0
    local changed = false

    for i=1, 16 do
      local effect, rank, texture, stacks, dtype, duration, timeleft = libdebuff:UnitDebuff("target", i)

      -- abort when no further debuff was found
      if not texture then break end

      if effect and effect ~= "" then
        -- Don't overwrite existing timers. Defer the expensive target-frame
        -- refresh until the complete aura pass is done.
        if not libdebuff.objects[unit] or not libdebuff.objects[unit][unitlevel] or not libdebuff.objects[unit][unitlevel][effect] then
          libdebuff:AddEffect(unit, unitlevel, effect, nil, true)
          changed = true
        end
      end
    end

    if changed then
      libdebuff:UpdateUnits()
    end

  -- Update Pending Spells
  elseif event == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
    -- Most combat messages cannot affect libdebuff. Avoid running the whole
    -- miss/resist/immune pattern set unless there is state to repair.
    if not libdebuff.pending[3] and not (lastspell and lastspell.start_old) then
      return
    end

    for _, msg in pairs(libdebuff.rp) do
      local effect = cmatch(arg1, msg)
      if effect and libdebuff.pending[3] == effect then
        -- instant removal of the pending spell
        libdebuff:RemovePending()
        return
      elseif effect and lastspell and lastspell.start_old and lastspell.effect == effect then
        -- late removal of debuffs (e.g hunter arrows as they hit late)
        libdebuff:RevertLastAction()
        return
      end
    end
  elseif event == "SPELLCAST_STOP" then
    if libdebuff.pending[3] then
      QueueFunction(libdebuff.PersistPending)
    end
  end
end)

-- Gather Data by User Actions
hooksecurefunc("CastSpell", function(id, bookType)
  local effect, rank = GetSpellName(id, bookType)
  if not effect or not L["debuffs"][effect] then return end

  local duration = libdebuff:GetDuration(effect, rank)
  libdebuff:AddPending(UnitName("target"), UnitLevel("target"), effect, duration)
end)

hooksecurefunc("CastSpellByName", function(effect, target)
  if not effect then return end

  -- Strip an explicit rank before checking the duration database. Reject
  -- ordinary damage/heal casts before doing any spell metadata work.
  local _, _, baseEffect, explicitRank = string.find(effect, "(.+)%((.+)%)")
  local name = baseEffect or effect
  if not L["debuffs"][name] then return end
  if libdebuff.pending[3] == name then return end

  local rank = explicitRank
  if not rank then
    _, rank = libspell.GetSpellInfo(name)
  end

  local duration = libdebuff:GetDuration(name, rank)
  libdebuff:AddPending(UnitName("target"), UnitLevel("target"), name, duration)
end)

hooksecurefunc("UseAction", function(slot, target, button)
  -- Macros are intentionally left to CastSpellByName: conditional macros can
  -- select a different spell than their first /cast line.
  if API and API.actioninfo and API.GetActionInfo then
    local actionType, actionID = API.GetActionInfo(slot)
    if actionType == "macro" or actionType == "item" then return end

    if actionType == "spell" and actionID then
      if not IsCurrentAction(slot) then return end
      local effect, rank = API.GetSpellInfo(actionID)
      if not effect or not L["debuffs"][effect] then return end
      local duration = libdebuff:GetDuration(effect, rank)
      libdebuff:AddPending(UnitName("target"), UnitLevel("target"), effect, duration)
      return
    elseif actionType then
      return
    end
  end

  if GetActionText(slot) or not IsCurrentAction(slot) then return end
  local tip = GetScanner()
  tip:SetAction(slot)
  local effect, rank = tip:Line(1)
  if not effect or not L["debuffs"][effect] then return end
  local duration = libdebuff:GetDuration(effect, rank)
  libdebuff:AddPending(UnitName("target"), UnitLevel("target"), effect, duration)
end)

function libdebuff:UnitDebuff(unit, id)
  local unitname = UnitName(unit)
  local unitlevel = UnitLevel(unit)
  local effect, texture, stacks, dtype
  local duration, timeleft = nil, -1
  local rank = nil -- no backport

  -- ClassicAPI already exposes the aura name together with the positional
  -- debuff data. Prefer it here so UNIT_AURA refreshes don't need to build and
  -- scan up to 16 hidden tooltips just to recover each effect name.
  if API and API.aurapositional and API.UnitDebuff then
    effect, texture, stacks, dtype = API.UnitDebuff(unit, id)
  end

  -- Plain Vanilla / older ClassicAPI compatibility. Also acts as a defensive
  -- fallback if a positional API unexpectedly failed to resolve a visible aura.
  if not texture then
    texture, stacks, dtype = UnitDebuff(unit, id)
  end

  if texture and (not effect or effect == "") then
    local tip = GetScanner()
    tip:SetUnitDebuff(unit, id)
    effect = tip:Line(1) or ""
  end

  if libdebuff.objects[unitname] and libdebuff.objects[unitname][unitlevel] and libdebuff.objects[unitname][unitlevel][effect] then
    -- clean up cache
    if libdebuff.objects[unitname][unitlevel][effect].duration and libdebuff.objects[unitname][unitlevel][effect].duration + libdebuff.objects[unitname][unitlevel][effect].start < GetTime() then
      libdebuff.objects[unitname][unitlevel][effect] = nil
    else
      duration = libdebuff.objects[unitname][unitlevel][effect].duration
      timeleft = duration + libdebuff.objects[unitname][unitlevel][effect].start - GetTime()
    end

  -- no level data
  elseif libdebuff.objects[unitname] and libdebuff.objects[unitname][0] and libdebuff.objects[unitname][0][effect] then
    -- clean up cache
    if libdebuff.objects[unitname][0][effect].duration and libdebuff.objects[unitname][0][effect].duration + libdebuff.objects[unitname][0][effect].start < GetTime() then
      libdebuff.objects[unitname][0][effect] = nil
    else
      duration = libdebuff.objects[unitname][0][effect].duration
      timeleft = duration + libdebuff.objects[unitname][0][effect].start - GetTime()
    end
  end

  return effect, rank, texture, stacks, dtype, duration, timeleft
end

ShaguTweaks.libdebuff = libdebuff
