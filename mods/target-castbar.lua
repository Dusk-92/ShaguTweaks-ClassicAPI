local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local LegacyCastingInfo = ShaguTweaks.UnitCastingInfo
local LegacyChannelInfo = ShaguTweaks.UnitChannelInfo

local module = ShaguTweaks:register({
  title = T["Enemy Castbars"],
  description = T["Shows an enemy castbar on target unit frame."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = true,
})

local castbar = CreateFrame("StatusBar", "ShaguTargetCastbar", TargetFrame)
castbar:SetPoint("BOTTOM", TargetFrame, "BOTTOM", -12, -4)
castbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
castbar:SetStatusBarColor(1, .8, 0, 1)
castbar:SetWidth(140)
castbar:SetHeight(10)
castbar:Hide()

castbar.texture = CreateFrame("Frame", nil, castbar)
castbar.texture:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
castbar.texture:SetHeight(20)
castbar.texture:SetWidth(20)

castbar.texture.icon = castbar.texture:CreateTexture(nil, "BACKGROUND")
castbar.texture.icon:SetPoint("CENTER", 0, 0)
castbar.texture.icon:SetWidth(16)
castbar.texture.icon:SetHeight(16)
castbar.texture:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

castbar.bg = castbar:CreateTexture(nil, "BACKGROUND")
castbar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
castbar.bg:SetVertexColor(.1, .1, 0, .8)
castbar.bg:SetAllPoints(true)

castbar.spark = castbar:CreateTexture(nil, "OVERLAY")
castbar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
castbar.spark:SetWidth(20)
castbar.spark:SetHeight(20)
castbar.spark:SetBlendMode("ADD")

castbar.backdrop = CreateFrame("Frame", nil, castbar)
castbar.backdrop:SetFrameStrata("BACKGROUND")
castbar.backdrop:SetPoint("TOPLEFT", castbar, "TOPLEFT", -3, 3)
castbar.backdrop:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", 3, -3)
castbar.backdrop:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

castbar.text = castbar:CreateFontString(nil, "HIGH", "GameFontWhite")
castbar.text:SetPoint("CENTER", castbar, "CENTER", 0, 0)
local font, size = castbar.text:GetFont()
castbar.text:SetFont(font, size - 2, "THINOUTLINE")

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

local function QueryCast(unit)
  if not unit then return end

  -- ClassicAPI is authoritative for real unit tokens and provides exact
  -- engine/server timing. A nil result for an existing unit means that exact
  -- GUID is not casting; don't fall back to the legacy name-keyed database,
  -- otherwise two NPCs with the same name can share one castbar incorrectly.
  if API and API.casts then
    local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = API.GetCastInfo(unit)
    if cast then
      return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
    end

    local channel
    channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill = API.GetChannelInfo(unit)
    if channel then
      return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
    end

    -- SuperWoW's GUID-keyed legacy cache is still safe because it cannot
    -- collide merely because two creatures share the same display name.
    if ShaguTweaks.superwow_active and not UnitIsUnit(unit, "player") then
      local guid = API.UnitGUID(unit)
      if guid then
        local a, b, c, d, e, f, g, h = QueryLegacy(guid)
        if a then return a, b, c, d, e, f, g, h end
      end
    end

    return
  end

  -- Compatibility path for environments without ClassicAPI cast support.
  if ShaguTweaks.superwow_active and not UnitIsUnit(unit, "player") then
    local guid = API and API.UnitGUID and API.UnitGUID(unit)
    if guid then
      local a, b, c, d, e, f, g, h = QueryLegacy(guid)
      if a then return a, b, c, d, e, f, g, h end
    end
  end

  return QueryLegacy(unit)
end

local function UpdatePosition()
  local targetOfTarget = TargetofTargetFrame and TargetofTargetFrame:IsShown()
  local debuff11 = TargetFrameDebuff11 and TargetFrameDebuff11:IsShown()
  local debuff7 = TargetFrameDebuff7 and TargetFrameDebuff7:IsShown()
  local buff1 = TargetFrameBuff1 and TargetFrameBuff1:IsShown()

  local y = -4
  if targetOfTarget then
    y = -24
    if debuff11 then
      y = -45
      if buff1 then
        y = -65
      end
    end
  elseif debuff7 then
    y = -24
  end

  -- Buff/debuff rows usually remain unchanged for the whole cast. Keep checking
  -- their cheap visibility state while animating, but only touch the frame
  -- anchors when the required position actually changes.
  if castbar.positionY == y then return end
  castbar.positionY = y
  castbar:ClearAllPoints()
  castbar:SetPoint("BOTTOM", TargetFrame, "BOTTOM", -12, y)
end

local function HideCast()
  castbar.startTime = nil
  castbar.endTime = nil
  castbar.isChannel = nil
  castbar:Hide()
end

local function UpdateProgress()
  local startTime = castbar.startTime
  local endTime = castbar.endTime
  if not startTime or not endTime or endTime <= startTime then
    HideCast()
    return
  end

  local now = GetTime()
  local max = endTime - startTime
  if now >= endTime then
    HideCast()
    return
  end

  local cur
  if castbar.isChannel then
    cur = endTime - now
  else
    cur = now - startTime
  end

  cur = cur > max and max or cur
  cur = cur < 0 and 0 or cur

  castbar:SetValue(cur)

  local percent = max > 0 and cur / max or 0
  local x = castbar:GetWidth() * percent
  castbar.spark:ClearAllPoints()
  castbar.spark:SetPoint("CENTER", castbar, "LEFT", x, 0)

  -- The target frame can move its buff/debuff rows while a cast is active.
  UpdatePosition()
end

local function RefreshCast()
  if not UnitExists("target") then
    HideCast()
    return
  end

  local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, isChannel = QueryCast("target")
  if not cast or not startTime or not endTime or endTime <= startTime then
    HideCast()
    return
  end

  castbar.startTime = startTime / 1000
  castbar.endTime = endTime / 1000
  castbar.isChannel = isChannel

  local max = castbar.endTime - castbar.startTime
  castbar:SetMinMaxValues(0, max)
  castbar.text:SetText(cast)

  if texture then
    castbar.texture.icon:SetTexture(texture)
    castbar.texture.icon:Show()
  else
    castbar.texture.icon:Hide()
  end

  UpdatePosition()
  castbar:Show()
  UpdateProgress()
end

module.enable = function(self)
  -- OnUpdate is now animation-only and runs only while the castbar is visible.
  -- Cast discovery is driven by ClassicAPI's UNIT_SPELLCAST_* events instead
  -- of querying the target's cast state on every rendered frame.
  castbar:SetScript("OnUpdate", UpdateProgress)

  local listener = CreateFrame("Frame")
  listener:RegisterEvent("PLAYER_TARGET_CHANGED")

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
  if API and API.eventutils and _G.C_EventUtils and _G.C_EventUtils.IsEventValid then
    for _, eventName in pairs(castEvents) do
      if _G.C_EventUtils.IsEventValid(eventName) then
        listener:RegisterEvent(eventName)
        hasClassicCastEvents = true
      end
    end
  end

  listener:SetScript("OnEvent", function()
    if event == "PLAYER_TARGET_CHANGED" then
      RefreshCast()
      return
    end

    -- ClassicAPI fans remote cast events out to every unit token currently
    -- resolving to the caster, including "target" when appropriate.
    if arg1 == "target" then
      RefreshCast()
    end
  end)

  if not hasClassicCastEvents then
    -- Compatibility fallback for older ClassicAPI builds: discover state at
    -- 20 Hz, while the bar itself still animates every frame when visible.
    listener.elapsed = 0
    listener:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + arg1
      if this.elapsed >= .05 then
        this.elapsed = 0
        RefreshCast()
      end
    end)
  end

  RefreshCast()
end
