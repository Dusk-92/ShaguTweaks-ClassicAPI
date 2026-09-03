local _G = ShaguTweaks.GetGlobalEnv()
local L = ShaguTweaks.L
local API = ShaguTweaks.API
local GetExpansion = ShaguTweaks.GetExpansion
local libtipscan = ShaguTweaks.libtipscan
local libspell = ShaguTweaks.libspell
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local cmatch = ShaguTweaks.cmatch

-- return instantly if we're not on a vanilla client
if GetExpansion() ~= "vanilla" then return end

local valid_units = {}
valid_units["pet"] = true
valid_units["player"] = true
valid_units["target"] = true
valid_units["mouseover"] = true

valid_units["pettarget"] = true
valid_units["playertarget"] = true
valid_units["targettarget"] = true
valid_units["mouseovertarget"] = true
valid_units["targettargettarget"] = true

for i=1,4 do valid_units["party" .. i] = true end
for i=1,4 do valid_units["partypet" .. i] = true end
for i=1,40 do valid_units["raid" .. i] = true end
for i=1,40 do valid_units["raidpet" .. i] = true end

for i=1,4 do valid_units["party" .. i .. "target"] = true end
for i=1,4 do valid_units["partypet" .. i .. "target"] = true end
for i=1,40 do valid_units["raid" .. i .. "target"] = true end
for i=1,40 do valid_units["raidpet" .. i .. "target"] = true end

local lastcasttex, lastrank, _
local scanner
local function GetScanner()
  if not scanner then
    scanner = libtipscan:GetScanner("libcast")
  end
  return scanner
end

local libcast = CreateFrame("Frame", "ShaguTweaksEnemyCast")
local player = UnitName("player")
local _, playerClass = UnitClass("player")
local useClassicCasts = API and API.casts
local needsCustomHunter = useClassicCasts and playerClass == "HUNTER"

ShaguTweaks.UnitChannelInfo = _G.UnitChannelInfo or function(unit)
  -- ClassicAPI is authoritative for real unit tokens. Fall through to the
  -- legacy database only for the player's custom Hunter cast emulation or for
  -- name/GUID keys maintained for compatibility.
  if valid_units[unit] and useClassicCasts then
    local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill =
      API.GetChannelInfo(unit)
    if cast then
      return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill
    end
    if unit ~= "player" then return end
  end

  unit = valid_units[unit] and UnitName(unit) or unit

  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill
  local db = libcast.db[unit]

  if db and db.cast and db.start + db.casttime / 1000 > GetTime() then
    if not db.channel then return end
    cast = db.cast
    nameSubtext = db.rank
    text = ""
    texture = db.icon
    startTime = db.start * 1000
    endTime = startTime + db.casttime
    isTradeSkill = nil
  elseif db then
    db.cast = nil
    db.rank = nil
    db.start = nil
    db.casttime = nil
    db.icon = nil
    db.channel = nil
  end

  return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill
end

ShaguTweaks.UnitCastingInfo = _G.UnitCastingInfo or function(unit)
  if valid_units[unit] and useClassicCasts then
    local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill =
      API.GetCastInfo(unit)
    if cast then
      return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill
    end
    if unit ~= "player" then return end
  end

  unit = valid_units[unit] and UnitName(unit) or unit

  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill
  local db = libcast.db[unit]

  if db and db.cast and db.start + db.casttime / 1000 > GetTime() then
    if db.channel then return end
    cast = db.cast
    nameSubtext = db.rank or ""
    text = ""
    texture = db.icon
    startTime = db.start * 1000
    endTime = startTime + db.casttime
    isTradeSkill = nil
  elseif db then
    db.cast = nil
    db.rank = nil
    db.start = nil
    db.casttime = nil
    db.icon = nil
    db.channel = nil
  end

  return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill
end

function libcast:AddAction(mob, spell, channel)
  if not mob or not spell then return nil end

  local data = L["spells"][spell]
  if data and data.t then
    local casttime = data.t
    local icon = data.icon and string.format("%s%s", "Interface\\Icons\\", data.icon) or nil

    -- add cast action to the database
    if not self.db[mob] then self.db[mob] = {} end
    self.db[mob].cast = spell
    self.db[mob].rank = nil
    self.db[mob].start = GetTime()
    self.db[mob].casttime = casttime
    self.db[mob].icon = icon
    self.db[mob].channel = channel

    return true
  end

  return nil
end

function libcast:RemoveAction(mob, spell)
  if self.db[mob] and ( L["interrupts"][spell] ~= nil or spell == "INTERRUPT" ) then

    -- remove cast action to the database
    self.db[mob].cast = nil
    self.db[mob].rank = nil
    self.db[mob].start = nil
    self.db[mob].casttime = nil
    self.db[mob].icon = nil
    self.db[mob].channel = nil
    return true
  end

  return nil
end

-- main data
libcast.db = { [player] = {} }

-- Current ClassicAPI can maintain the legacy name-keyed libcast cache from
-- structured unit spell events. This preserves the public ShaguTweaks
-- UnitCastingInfo/UnitChannelInfo fallback without parsing every combat-text
-- line. Older ClassicAPI builds keep the historical parser below.
local classicRemoteEvents = API and API.casts and API.eventutils
  and _G.C_EventUtils
  and _G.C_EventUtils.IsEventValid("UNIT_SPELLCAST_START")
  and _G.C_EventUtils.IsEventValid("UNIT_SPELLCAST_STOP")
  and _G.C_EventUtils.IsEventValid("UNIT_SPELLCAST_CHANNEL_START")
  and _G.C_EventUtils.IsEventValid("UNIT_SPELLCAST_CHANNEL_STOP")

if classicRemoteEvents then
  libcast:RegisterEvent("UNIT_SPELLCAST_START")
  libcast:RegisterEvent("UNIT_SPELLCAST_STOP")
  libcast:RegisterEvent("UNIT_SPELLCAST_FAILED")
  libcast:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  libcast:RegisterEvent("UNIT_SPELLCAST_DELAYED")
  libcast:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
  libcast:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
  libcast:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
else
  libcast:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF")
  libcast:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS")
  libcast:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
  libcast:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF")
end

-- Full legacy player tracking is only needed when ClassicAPI cast data is
-- unavailable. On current ClassicAPI, only Hunters keep the stop/fail events
-- required to end the Aimed Shot / Multi-Shot custom cast emulation.
if not useClassicCasts then
  libcast:RegisterEvent("SPELLCAST_START")
  libcast:RegisterEvent("SPELLCAST_STOP")
  libcast:RegisterEvent("SPELLCAST_FAILED")
  libcast:RegisterEvent("SPELLCAST_INTERRUPTED")
  libcast:RegisterEvent("SPELLCAST_DELAYED")
  libcast:RegisterEvent("SPELLCAST_CHANNEL_START")
  libcast:RegisterEvent("SPELLCAST_CHANNEL_STOP")
  libcast:RegisterEvent("SPELLCAST_CHANNEL_UPDATE")
elseif needsCustomHunter then
  libcast:RegisterEvent("SPELLCAST_STOP")
  libcast:RegisterEvent("SPELLCAST_FAILED")
  libcast:RegisterEvent("SPELLCAST_INTERRUPTED")
end

local function ClearClassicRemote(unit)
  if not unit or unit == "player" then return end
  local name = UnitName(unit)
  if not name then return end

  local cast = libcast.db[name]
  if cast then
    cast.cast = nil
    cast.rank = nil
    cast.start = nil
    cast.casttime = nil
    cast.icon = nil
    cast.channel = nil
  end
end

local function UpdateClassicRemote(unit, channel)
  if not unit or unit == "player" then return end
  local name = UnitName(unit)
  if not name then return end

  local spell, rank, text, icon, startTime, endTime
  if channel then
    spell, rank, text, icon, startTime, endTime = API.GetChannelInfo(unit)
  else
    spell, rank, text, icon, startTime, endTime = API.GetCastInfo(unit)
  end

  if not spell or not startTime or not endTime then
    ClearClassicRemote(unit)
    return
  end

  local cast = libcast.db[name]
  if not cast then
    cast = {}
    libcast.db[name] = cast
  end

  cast.cast = spell
  cast.rank = rank
  cast.start = startTime / 1000
  cast.casttime = endTime - startTime
  cast.icon = icon
  cast.channel = channel and true or nil
end

libcast:SetScript("OnEvent", function()
  -- Keep the public legacy cache current from ClassicAPI without combat text.
  if classicRemoteEvents and strfind(event, "UNIT_SPELLCAST_", 1) then
    if arg1 == "player" then return end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
      UpdateClassicRemote(arg1, false)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
      UpdateClassicRemote(arg1, true)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
      or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    then
      ClearClassicRemote(arg1)
    end
    return
  end

  -- Fill database with player casts
  if event == "SPELLCAST_START" then
    local icon = L["spells"][arg1] and L["spells"][arg1].icon and string.format("%s%s", "Interface\\Icons\\", L["spells"][arg1].icon) or lastcasttex
    -- add cast action to the database
    this.db[player].cast = arg1
    this.db[player].rank = lastrank
    this.db[player].start = GetTime()
    this.db[player].casttime = arg2
    this.db[player].icon = icon
    this.db[player].channel = nil
    if not L["spells"][arg1] or not L["spells"][arg1].icon or not L["spells"][arg1].t then
      L["spells"][arg1] = L["spells"][arg1] or { }
      L["spells"][arg1].icon = L["spells"][arg1].icon or icon
      L["spells"][arg1].t = L["spells"][arg1].t or arg2
    end
    lastcasttex, lastrank = nil, nil
  elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
    if this.db[player] and not this.db[player].channel then
      -- remove cast action to the database
      this.db[player].cast = nil
      this.db[player].rank = nil
      this.db[player].rank = nil
      this.db[player].start = nil
      this.db[player].casttime = nil
      this.db[player].icon = nil
      this.db[player].channel = nil
    else
      lastcasttex, lastrank = nil, nil
    end
  elseif event == "SPELLCAST_DELAYED" then
    if this.db[player].cast then
      this.db[player].start = this.db[player].start + arg1/1000
    end
  elseif event == "SPELLCAST_CHANNEL_START" then
    -- add cast action to the database
    this.db[player].cast = arg2
    this.db[player].rank = lastrank
    this.db[player].start = GetTime()
    this.db[player].casttime = arg1
    this.db[player].icon = L["spells"][arg2] and L["spells"][arg2].icon and string.format("%s%s", "Interface\\Icons\\", L["spells"][arg2].icon) or lastcasttex
    this.db[player].channel = true
    lastcasttex, lastrank = nil, nil
  elseif event == "SPELLCAST_CHANNEL_STOP" then
    if this.db[player] and this.db[player].channel then
      -- remove cast action to the database
      this.db[player].cast = nil
      this.db[player].rank = nil
      this.db[player].start = nil
      this.db[player].casttime = nil
      this.db[player].icon = nil
      this.db[player].channel = nil
    end
  elseif event == "SPELLCAST_CHANNEL_UPDATE" then
    if this.db[player].cast then
      this.db[player].start = -this.db[player].casttime/1000 + GetTime() + arg1/1000
    end
  -- Fill database with environmental casts
  elseif arg1 then
    local mob, spell, _

    -- (.+) begins to cast (.+).
    mob, spell = cmatch(arg1, SPELLCASTOTHERSTART)
    if libcast:AddAction(mob, spell) then return end

    -- (.+) begins to perform (.+).
    mob, spell = cmatch(arg1, SPELLPERFORMOTHERSTART)
    if libcast:AddAction(mob, spell) then return end

    -- (.+) gains (.+).
    mob, spell = cmatch(arg1, AURAADDEDOTHERHELPFUL)
    if libcast:RemoveAction(mob, spell) then return end

    -- (.+) is afflicted by (.+).
    mob, spell = cmatch(arg1, AURAADDEDOTHERHARMFUL)
    if libcast:RemoveAction(mob, spell) then return end

    -- Your (.+) hits (.+) for (%d+).
    spell, mob = cmatch(arg1, SPELLLOGSELFOTHER)
    if libcast:RemoveAction(mob, spell) then return end

    -- Your (.+) crits (.+) for (%d+).
    spell, mob = cmatch(arg1, SPELLLOGCRITSELFOTHER)
    if libcast:RemoveAction(mob, spell) then return end

    -- (.+)'s (.+) %a hits (.+) for (%d+).
    _, spell, mob = cmatch(arg1, SPELLLOGOTHEROTHER)
    if libcast:RemoveAction(mob, spell) then return end

    -- (.+)'s (.+) %a crits (.+) for (%d+).
    _, spell, mob = cmatch(arg1, SPELLLOGCRITOTHEROTHER)
    if libcast:RemoveAction(mob, spell) then return end

    -- You interrupt (.+)'s (.+).
    mob, spell = cmatch(arg1, SPELLINTERRUPTSELFOTHER)
    if libcast:RemoveAction(mob, spell) then return end

    -- (.+) interrupts (.+)'s (.+).
    _, mob, spell = cmatch(arg1, SPELLINTERRUPTOTHEROTHER)
    if libcast:RemoveAction(mob, spell) then return end
  end
end)

--[[ Custom Casts
  Enable Castbars for spells that don't have a castbar by default
  (e.g Multi-Shot and Aimed Shot)
]]--
local aimedshot = L["customcast"]["AIMEDSHOT"]
local multishot = L["customcast"]["MULTISHOT"]

libcast.customcast = {}
libcast.customcast[strlower(aimedshot)] = function(begin, duration)
  if begin then
    local duration = duration or 3000

    for i=1,32 do
      local buff = UnitBuff("player", i)
      if buff == "Interface\\Icons\\Racial_Troll_Berserk" then
        local berserk = 0.3
        if((UnitHealth("player")/UnitHealthMax("player")) >= 0.40) then
          berserk = (1.30 - (UnitHealth("player") / UnitHealthMax("player"))) / 3
        end
        duration = duration / (1 + berserk)
      elseif buff == "Interface\\Icons\\Ability_Hunter_RunningShot" then
        duration = duration / 1.4
      elseif buff == "Interface\\Icons\\Ability_Warrior_InnerRage" then
        duration = duration / 1.3
      elseif buff == "Interface\\Icons\\Inv_Trinket_Naxxramas04" then
        duration = duration / 1.2
      end
    end

    local _,_, lag = GetNetStats()
    local start = GetTime() + lag/1000

    -- add cast action to the database
    libcast.db[player].cast = aimedshot
    libcast.db[player].rank = lastrank
    libcast.db[player].start = start
    libcast.db[player].casttime = duration
    libcast.db[player].icon = "Interface\\Icons\\Inv_spear_07"
    libcast.db[player].channel = nil
  else
    -- remove cast action to the database
    libcast.db[player].cast = nil
    libcast.db[player].rank = nil
    libcast.db[player].start = nil
    libcast.db[player].casttime = nil
    libcast.db[player].icon = nil
    libcast.db[player].channel = nil
  end
end

libcast.customcast[strlower(multishot)] = function(begin, duration)
  if begin then
    local duration = duration or 500

    for i=1,32 do
      local buff = UnitBuff("player", i)
      if buff == "Interface\\Icons\\Racial_Troll_Berserk" then
        local berserk = 0.3
        if((UnitHealth("player")/UnitHealthMax("player")) >= 0.40) then
          berserk = (1.30 - (UnitHealth("player") / UnitHealthMax("player"))) / 3
        end
        duration = duration / (1 + berserk)
      elseif buff == "Interface\\Icons\\Ability_Hunter_RunningShot" then
        duration = duration / 1.4
      elseif buff == "Interface\\Icons\\Ability_Warrior_InnerRage" then
        duration = duration / 1.3
      elseif buff == "Interface\\Icons\\Inv_Trinket_Naxxramas04" then
        duration = duration / 1.2
      end
    end

    local _,_, lag = GetNetStats()
    local start = GetTime() + lag/1000

    -- add cast action to the database
    libcast.db[player].cast = multishot
    libcast.db[player].rank = lastrank
    libcast.db[player].start = start
    libcast.db[player].casttime = duration
    libcast.db[player].icon = "Interface\\Icons\\Ability_upgrademoonglaive"
    libcast.db[player].channel = nil
  else
    -- remove cast action to the database
    libcast.db[player].cast = nil
    libcast.db[player].rank = nil
    libcast.db[player].start = nil
    libcast.db[player].casttime = nil
    libcast.db[player].icon = nil
    libcast.db[player].channel = nil
  end
end

local function GetCustomCast(spell)
  if not spell then return end

  local lowerSpell = strlower(spell)
  for custom, func in pairs(libcast.customcast) do
    if strfind(lowerSpell, custom) then
      return func
    end
  end
end

local function CastCustom(spell)
  local func = GetCustomCast(spell)
  if func and not ShaguTweaks.UnitCastingInfo("player") then
    func(true)
  end
end

if not useClassicCasts or needsCustomHunter then
hooksecurefunc("UseContainerItem", function(id, index)
  lastcasttex = GetContainerItemInfo(id, index)
end)

hooksecurefunc("CastSpell", function(id, bookType)
  local spellName, rank = GetSpellName(id, bookType)
  lastrank = rank
  lastcasttex = GetSpellTexture(id, bookType)

  if GetSpellCooldown(id, bookType) ~= 0 then
    CastCustom(spellName)
  end
end)

hooksecurefunc("CastSpellByName", function(spell, target)
  -- Only Aimed Shot and Multi-Shot need the legacy custom-cast emulation.
  -- Ordinary macro casts can return immediately instead of resolving their
  -- spellbook rank on every invocation.
  local custom = GetCustomCast(spell)
  if not custom then return end

  _, lastrank = libspell.GetSpellInfo(spell)

  for i=1,120 do
    -- detect if any cast is ongoing
    if IsCurrentAction(i) then
      if not ShaguTweaks.UnitCastingInfo(player) then
        custom(true)
      end
      return
    end
  end
end)

hooksecurefunc("UseAction", function(slot, target, button)
  -- ClassicAPI identifies action slots in native code. This avoids building a
  -- hidden tooltip for every button press, while keeping the old scanner as a
  -- cold compatibility path for an older ClassicAPI action surface.
  if API and API.actioninfo and API.GetActionInfo then
    local actionType, actionID = API.GetActionInfo(slot)

    if actionType == "macro" then
      -- The real spell selected by a conditional macro is handled later by
      -- CastSpellByName. Do not guess it from the macro's first cast line.
      return
    elseif actionType == "item" then
      lastcasttex = GetActionTexture(slot)
      lastrank = nil
      return
    elseif actionType == "spell" and actionID then
      local spellName, rank, icon = API.GetSpellInfo(actionID)
      lastcasttex = icon or GetActionTexture(slot)
      lastrank = rank
      if not IsCurrentAction(slot) then return end
      CastCustom(spellName)
      return
    elseif actionType then
      return
    end
  end

  if GetActionText(slot) or not IsCurrentAction(slot) then return end
  local tip = GetScanner()
  tip:SetAction(slot)
  local spellName, rank = tip:Line(1)

  lastcasttex = GetActionTexture(slot)
  lastrank = rank
  CastCustom(spellName)
end)
end

ShaguTweaks.libcast = libcast