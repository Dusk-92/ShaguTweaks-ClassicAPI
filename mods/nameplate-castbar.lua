local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local LegacyCastingInfo = ShaguTweaks.UnitCastingInfo
local LegacyChannelInfo = ShaguTweaks.UnitChannelInfo

local module = ShaguTweaks:register({
  title = T["Nameplate Castbar"],
  description = T["Adds a castbar to enemy nameplates."],
  expansions = { ["vanilla"] = true },
  category = T["Nameplates"],
  enabled = true,
})

local function QueryLegacy(query)
  if not query then return end

  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = LegacyCastingInfo(query)
  if cast then
    return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
  end

  local channel
  channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill = LegacyChannelInfo(query)
  if channel then
    return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
  end
end

local function QuerySuperWoW(guid, channelSpellID, hasChannel)
  if not guid then return end

  local cached = ShaguTweaks.libcast.db[guid]
  if not cached then return end

  if cached.channel then
    if not hasChannel or cached.spellID ~= channelSpellID then return end

    local channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill = LegacyChannelInfo(guid)
    if channel then
      return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
    end
    return
  end

  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = LegacyCastingInfo(guid)
  if cast then
    return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
  end
end

module.enable = function(self)
  if ShaguPlates then return end

  local backdrop = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  }

  local platesByUnit = {}
  local useClassicNameplateTokens = false

  local function GetCastbarWidth(plate)
    if not plate then return end

    -- Match the visible healthbar, not the outer nameplate frame. Nameplate
    -- Scale reparents/scales the healthbar, so convert its width back into the
    -- plate's coordinate space using effective scales.
    local healthbar = plate.healthbar
    if not healthbar or not healthbar.GetWidth then
      healthbar = plate:GetChildren()
    end

    if healthbar and healthbar.GetWidth then
      local width = healthbar:GetWidth()
      local healthScale = healthbar.GetEffectiveScale and healthbar:GetEffectiveScale()
      local plateScale = plate.GetEffectiveScale and plate:GetEffectiveScale()

      if width and width > 0 and healthScale and healthScale > 0
        and plateScale and plateScale > 0
      then
        width = width * healthScale / plateScale
        if width > 0 then return width end
      elseif width and width > 0 then
        return width
      end
    end

    -- Defensive fallback matching the historical ShaguTweaks layout.
    local width = plate:GetWidth()
    return width and width > 22 and width - 22 or nil
  end

  local function SyncCastbarWidth(plate)
    if not plate or not plate.castbar then return end

    local width = GetCastbarWidth(plate)
    if not width then return end

    local current = plate.castbar:GetWidth()
    if not current or math.abs(current - width) > .5 then
      plate.castbar:SetWidth(width)
    end
  end

  local function create_castbar(plate)
    if not plate or plate.castbar then return end

    plate.castbar = CreateFrame("StatusBar", nil, plate)
    plate.castbar:SetPoint("BOTTOM", plate, "BOTTOM", 8, -11)
    plate.castbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    plate.castbar:SetStatusBarColor(1, .8, 0, 1)
    plate.castbar:SetWidth(GetCastbarWidth(plate) or 100)
    plate.castbar:SetHeight(10)
    plate.castbar.ownerPlate = plate

    plate.castbar.texture = CreateFrame("Frame", nil, plate.castbar)
    plate.castbar.texture:SetPoint("RIGHT", plate.castbar, "LEFT", 0, 0)
    plate.castbar.texture:SetHeight(18)
    plate.castbar.texture:SetWidth(18)
    plate.castbar.texture.icon = plate.castbar.texture:CreateTexture(nil, "BACKGROUND")
    plate.castbar.texture.icon:SetPoint("CENTER", 0, 0)
    plate.castbar.texture.icon:SetWidth(12)
    plate.castbar.texture.icon:SetHeight(12)
    plate.castbar.texture:SetBackdrop(backdrop)
    plate.castbar.texture:SetBackdropBorderColor(1,.8,0)

    plate.castbar.bg = plate.castbar:CreateTexture(nil, "BACKGROUND")
    plate.castbar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    plate.castbar.bg:SetVertexColor(.1, .1, 0, .8)
    plate.castbar.bg:SetAllPoints(true)

    plate.castbar.spark = plate.castbar:CreateTexture(nil, "OVERLAY")
    plate.castbar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    plate.castbar.spark:SetWidth(20)
    plate.castbar.spark:SetHeight(20)
    plate.castbar.spark:SetBlendMode("ADD")

    plate.castbar.backdrop = CreateFrame("Frame", nil, plate.castbar)
    plate.castbar.backdrop:SetFrameLevel(plate.castbar:GetFrameLevel())
    plate.castbar.backdrop:SetPoint("TOPLEFT", plate.castbar, "TOPLEFT", -3, 3)
    plate.castbar.backdrop:SetPoint("BOTTOMRIGHT", plate.castbar, "BOTTOMRIGHT", 3, -3)
    plate.castbar.backdrop:SetBackdrop(backdrop)
    plate.castbar.backdrop:SetBackdropBorderColor(1,.8,0)

    plate.castbar.text = plate.castbar:CreateFontString(nil, "HIGH", "GameFontWhite")
    plate.castbar.text:SetPoint("CENTER", plate.castbar, "CENTER", 0, 0)
    local font, size = plate.castbar.text:GetFont()
    plate.castbar.text:SetFont(font, size - 3, "THINOUTLINE")

    plate.castbar:Hide()
  end

  local function HideCast(plate)
    if not plate or not plate.castbar then return end
    plate.castbar.startTime = nil
    plate.castbar.endTime = nil
    plate.castbar.isChannel = nil
    plate.castbar:Hide()
  end

  local function QueryPlateCast(plate)
    if not plate then return end

    -- nameplateN tokens are tied to a GUID by ClassicAPI. Verify the mapping
    -- before trusting a token kept on a recycled nameplate frame.
    local unit = plate.unit
    if unit and plate.guid and API.UnitGUID(unit) ~= plate.guid then
      unit = nil
    end

    if unit and API.casts then
      local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = API.GetCastInfo(unit)
      if cast then
        return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
      end

      local channel, notInterruptible, channelSpellID, hasChannel
      channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill,
        notInterruptible, channelSpellID, hasChannel = API.GetChannelInfo(unit)
      if channel then
        return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
      end

      -- With a real ClassicAPI unit token, "no cast" is authoritative. Never
      -- fall through to the old name-keyed database, otherwise two mobs with
      -- the same name can incorrectly share a castbar. The GUID-keyed
      -- SuperWoW fallback remains safe; channels must also match ClassicAPI's
      -- live channel spellID before their cached timing is trusted.
      if ShaguTweaks.superwow_active and plate.guid then
        return QuerySuperWoW(plate.guid, channelSpellID, hasChannel)
      end
      return
    end

    -- SuperWoW's GUID path is safe because it identifies the exact creature.
    if ShaguTweaks.superwow_active and plate.guid then
      local a, b, c, d, e, f, g, h = QueryLegacy(plate.guid)
      if a then return a, b, c, d, e, f, g, h end
    end

    -- Only legacy environments without ClassicAPI nameplate identity are
    -- allowed to fall back to names. This preserves old compatibility while
    -- preventing same-name leakage on the ClassicAPI path.
    if not useClassicNameplateTokens then
      local name = plate.name and plate.name:GetText()
      return QueryLegacy(name)
    end
  end

  local function UpdateProgress(plate)
    if not plate or not plate.castbar then return end
    local bar = plate.castbar
    local startTime = bar.startTime
    local endTime = bar.endTime

    if not startTime or not endTime or endTime <= startTime then
      HideCast(plate)
      return
    end

    local now = GetTime()
    if now >= endTime then
      HideCast(plate)
      return
    end

    local max = endTime - startTime
    local cur
    if bar.isChannel then
      cur = endTime - now
    else
      cur = now - startTime
    end

    cur = cur > max and max or cur
    cur = cur < 0 and 0 or cur
    bar:SetValue(cur)

    local percent = max > 0 and cur / max or 0
    local x = bar:GetWidth() * percent
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", bar, "LEFT", x, 0)
    bar:SetAlpha(plate:GetAlpha())
  end

  local function RefreshPlate(plate)
    if not plate then return end
    if not plate.castbar then create_castbar(plate) end

    local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, isChannel = QueryPlateCast(plate)
    if not cast or not startTime or not endTime or endTime <= startTime then
      HideCast(plate)
      return
    end

    local bar = plate.castbar

    -- NAME_PLATE_UNIT_ADDED can arrive before other visual modules finish
    -- sizing the plate. Re-read the final healthbar width when a cast is
    -- actually shown instead of keeping the early creation width.
    SyncCastbarWidth(plate)

    bar.startTime = startTime / 1000
    bar.endTime = endTime / 1000
    bar.isChannel = isChannel

    local max = bar.endTime - bar.startTime
    bar:SetMinMaxValues(0, max)
    bar.text:SetText(cast)

    if texture then
      bar.texture.icon:SetTexture(texture)
      bar.texture.icon:Show()
    else
      bar.texture.icon:Hide()
    end

    bar:Show()
    UpdateProgress(plate)
  end

  local function AttachUnit(unit)
    if not unit or not API.GetNamePlateForUnit then return end
    local plate = API.GetNamePlateForUnit(unit)
    if not plate then return end

    local oldUnit = plate.unit
    if oldUnit and oldUnit ~= unit and platesByUnit[oldUnit] == plate then
      platesByUnit[oldUnit] = nil
    end

    plate.unit = unit
    plate.guid = API.UnitGUID(unit)
    platesByUnit[unit] = plate

    if not plate.castbar then create_castbar(plate) end
    RefreshPlate(plate)
    return plate
  end

  -- A castbar animates only while visible. Hidden bars receive no useful work,
  -- while cast discovery itself is driven by ClassicAPI events below.
  local function EnableBarAnimation(plate)
    if not plate or not plate.castbar or plate.castbar.animationHooked then return end
    plate.castbar.animationHooked = true
    plate.castbar:SetScript("OnUpdate", function()
      local owner = this.ownerPlate
      if owner then UpdateProgress(owner) end
    end)
  end

  local oldCreate = create_castbar
  create_castbar = function(plate)
    oldCreate(plate)
    EnableBarAnimation(plate)
  end

  local listener = CreateFrame("Frame")
  local eventValid = API and API.eventutils and _G.C_EventUtils and _G.C_EventUtils.IsEventValid

  if eventValid and _G.C_EventUtils.IsEventValid("NAME_PLATE_UNIT_ADDED")
    and _G.C_EventUtils.IsEventValid("NAME_PLATE_UNIT_REMOVED") then
    listener:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    listener:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    useClassicNameplateTokens = true
  end

  local castEvents = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
  }

  local hasClassicCastEvents = false
  if eventValid then
    for _, eventName in pairs(castEvents) do
      if _G.C_EventUtils.IsEventValid(eventName) then
        listener:RegisterEvent(eventName)
        hasClassicCastEvents = true
      end
    end
  end

  listener:SetScript("OnEvent", function()
    if event == "NAME_PLATE_UNIT_ADDED" then
      AttachUnit(arg1)
      return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
      local unit = arg1
      local plate = platesByUnit[unit]
      if not plate and API.GetNamePlateForUnit then
        plate = API.GetNamePlateForUnit(unit)
      end

      if plate then
        HideCast(plate)
        if plate.unit == unit then
          plate.unit = nil
          plate.guid = nil
        end
      end
      platesByUnit[unit] = nil
      return
    end

    local unit = arg1
    if unit and string.find(unit, "^nameplate%d+$") then
      local plate = platesByUnit[unit] or AttachUnit(unit)
      if plate then RefreshPlate(plate) end
    end
  end)

  if useClassicNameplateTokens and hasClassicCastEvents then
    -- ClassicAPI owns identity and cast discovery. libnameplate is still used
    -- by the other visual modules, but this module no longer queries every
    -- visible plate's cast state on every rendered frame.
    table.insert(ShaguTweaks.libnameplate.OnShow, function(plate)
      plate = plate or this
      if plate.unit then
        RefreshPlate(plate)
      end
    end)
  else
    -- Compatibility path for older ClassicAPI / plain Vanilla. Preserve the
    -- original per-plate discovery behavior where modern nameplate tokens or
    -- spellcast events do not exist.
    table.insert(ShaguTweaks.libnameplate.OnUpdate, function(plate)
      plate = plate or this
      if not plate.castbar then create_castbar(plate) end
      RefreshPlate(plate)
    end)
  end
end
