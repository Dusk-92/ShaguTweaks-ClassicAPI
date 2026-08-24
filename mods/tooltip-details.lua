local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local round = ShaguTweaks.round
local rgbhex = ShaguTweaks.rgbhex
local Abbreviate = ShaguTweaks.Abbreviate
local API = ShaguTweaks.API

local current_unit = "none"
local current_guid = nil
local statusbar = nil

local direct_units = { "mouseover", "target", "focus", "player", "pet" }

local function UnitMatchesGUID(unit, guid)
  if not guid or not UnitExists(unit) then return false end

  if API and API.UnitGUID then
    return API.UnitGUID(unit) == guid
  elseif type(UnitGUID) == "function" then
    return UnitGUID(unit) == guid
  end

  return false
end

local function FindUnitByGUID(guid)
  if not guid then return end

  -- The common case is mouseover/target, so check cheap tokens first.
  for _, unit in pairs(direct_units) do
    if UnitMatchesGUID(unit, guid) then
      return unit
    end
  end

  for i=1,4 do
    if UnitMatchesGUID("party" .. i, guid) then return "party" .. i end
    if UnitMatchesGUID("partypet" .. i, guid) then return "partypet" .. i end
  end

  for i=1,40 do
    if UnitMatchesGUID("raid" .. i, guid) then return "raid" .. i end
    if UnitMatchesGUID("raidpet" .. i, guid) then return "raidpet" .. i end
  end
end

local function FindUnitByName()
  local tooltipName = GameTooltipTextLeft1:GetText()
  if not tooltipName then return end

  for _, unit in pairs(direct_units) do
    if UnitExists(unit) and
      (UnitName(unit) == tooltipName or UnitPVPName(unit) == tooltipName) then
      return unit
    end
  end

  for i=1,4 do
    local party = "party" .. i
    local pet = "partypet" .. i
    if UnitExists(party) and
      (UnitName(party) == tooltipName or UnitPVPName(party) == tooltipName) then
      return party
    end
    if UnitExists(pet) and
      (UnitName(pet) == tooltipName or UnitPVPName(pet) == tooltipName) then
      return pet
    end
  end

  for i=1,40 do
    local raid = "raid" .. i
    local pet = "raidpet" .. i
    if UnitExists(raid) and
      (UnitName(raid) == tooltipName or UnitPVPName(raid) == tooltipName) then
      return raid
    end
    if UnitExists(pet) and
      (UnitName(pet) == tooltipName or UnitPVPName(pet) == tooltipName) then
      return pet
    end
  end
end

local function GetUnit()
  -- ClassicAPI stores the actual unit GUID on GameTooltip. Prefer it over the
  -- old name-comparison heuristic, which can misidentify units with matching
  -- display names or PvP titles.
  if type(GameTooltip.GetUnitGUID) == "function" then
    local _, guid = GameTooltip:GetUnitGUID()
    if guid then
      if current_guid == guid and current_unit ~= "none" and
        UnitMatchesGUID(current_unit, guid) then
        return current_unit
      end

      local unit = FindUnitByGUID(guid)
      if unit then
        current_guid = guid
        current_unit = unit
        return current_unit
      end
    end
  end

  -- Compatibility fallback for clients without the ClassicAPI tooltip method,
  -- or for a unit that cannot currently be mapped back to a known unit token.
  current_guid = nil
  current_unit = FindUnitByName() or "none"
  return current_unit
end

local updating = false

local function UpdateTooltip()
  if updating then return end
  updating = true

  local unit = GetUnit()
  if unit == "none" then
    updating = false
    return
  end

  local pvpname = UnitPVPName(unit)
  local name = UnitName(unit)
  local target = UnitName(unit .. "target")
  local _, targetClass = UnitClass(unit .. "target")
  local targetReaction = UnitReaction("player", unit .. "target")
  local _, class = UnitClass(unit)
  local guild = GetGuildInfo(unit)
  local reaction = UnitReaction(unit, "player")
  local pvptitle = name and gsub(pvpname or name, " " .. name, "", 1) or nil

  -- Keep the health estimator bound to the unit actually represented by the
  -- tooltip, not merely whichever unit happened to be mouseover last.
  if statusbar then
    statusbar.name = name
    statusbar.level = UnitLevel(unit)
    statusbar.lastHP = nil
    statusbar.lastHPMax = nil
    statusbar.lastName = nil
    statusbar.lastLevel = nil
  end

  if name then
    if UnitIsPlayer(unit) and class then
      local color = RAID_CLASS_COLORS[class]
      if color then
        GameTooltipStatusBar:SetStatusBarColor_orig(color.r, color.g, color.b)
        GameTooltipStatusBar.bg:SetVertexColor(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.8)
        GameTooltipTextLeft1:SetText(rgbhex(color.r, color.g, color.b, color.a) .. name)
      else
        GameTooltipTextLeft1:SetText("|cff999999" .. name)
      end
    elseif reaction then
      local color = UnitReactionColor[reaction]
      if color then
        GameTooltipStatusBar:SetStatusBarColor_orig(color.r, color.g, color.b)
        GameTooltipStatusBar.bg:SetVertexColor(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.8)
      end
    end

    if pvptitle and pvptitle ~= name then
      GameTooltip:AppendText(" |cff666666[" .. pvptitle .. "]|r")
    end
  end

  -- Guild name only (no rank)
  if guild then
    local guildAlready = false
    for i = 2, GameTooltip:NumLines() do
      local left = _G["GameTooltipTextLeft" .. i]
      if left and left:GetText() == "<" .. guild .. ">" then
        guildAlready = true
        break
      end
    end
    if not guildAlready then
      GameTooltip:AddLine("<" .. guild .. ">", 0.3, 1, 0.5)
    end
  end

  -- Current target, colored by class or reaction
  local alreadyAdded = false
  if target then
    for i = 2, GameTooltip:NumLines() do
      local left = _G["GameTooltipTextLeft" .. i]
      if left and left:GetText() == target then
        alreadyAdded = true
        break
      end
    end
  end

  if target and not alreadyAdded then
    if UnitIsPlayer(unit .. "target") and targetClass then
      local color = RAID_CLASS_COLORS[targetClass]
      if color then
        GameTooltip:AddLine(target, color.r, color.g, color.b)
      else
        GameTooltip:AddLine(target, .5, .5, .5)
      end
    elseif targetReaction then
      local color = UnitReactionColor[targetReaction]
      if color then
        GameTooltip:AddLine(target, color.r, color.g, color.b)
      else
        GameTooltip:AddLine(target, .5, .5, .5)
      end
    end
  end

  GameTooltip:Show()
  updating = false
end

local module = ShaguTweaks:register({
  title = T["Tooltip Details"],
  description = T["Enriches unit tooltips with health, class color, guild name, rank, and current target."],
  expansions = { ["vanilla"] = true },
  category = T["General"],
  enabled = true,
  order = 50,
})

local backdrop = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

module.enable = function(self)
  GameTooltipStatusBar:SetHeight(10)
  GameTooltipStatusBar:ClearAllPoints()
  GameTooltipStatusBar:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 4, 2)
  GameTooltipStatusBar:SetPoint("BOTTOMRIGHT", GameTooltip, "TOPRIGHT", -4, 2)

  GameTooltipStatusBar.bg = GameTooltipStatusBar:CreateTexture(nil, "BACKGROUND")
  GameTooltipStatusBar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  GameTooltipStatusBar.bg:SetVertexColor(.1, .1, 0, .8)
  GameTooltipStatusBar.bg:SetAllPoints(true)

  GameTooltipStatusBar.backdrop = CreateFrame("Frame", "GameTooltipStatusBarBackdrop", GameTooltipStatusBar)
  GameTooltipStatusBar.backdrop:SetPoint("TOPLEFT", GameTooltipStatusBar, "TOPLEFT", -3, 3)
  GameTooltipStatusBar.backdrop:SetPoint("BOTTOMRIGHT", GameTooltipStatusBar, "BOTTOMRIGHT", 3, -3)
  GameTooltipStatusBar.backdrop:SetBackdrop(backdrop)
  GameTooltipStatusBar.backdrop:SetBackdropBorderColor(.8,.8,.8,1)

  GameTooltipStatusBar.backdrop.health = GameTooltipStatusBar.backdrop:CreateFontString("Status", "DIALOG", "GameFontWhite")
  GameTooltipStatusBar.backdrop.health:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  GameTooltipStatusBar.backdrop.health:SetPoint("TOP", 0, 4)
  GameTooltipStatusBar.backdrop.health:SetNonSpaceWrap(false)

  GameTooltipStatusBar.SetStatusBarColor_orig = GameTooltipStatusBar.SetStatusBarColor
  GameTooltipStatusBar.SetStatusBarColor = function() return end

  -- update tooltip whenever it gets shown
  local details = CreateFrame("Frame", nil, GameTooltip)
  details:SetScript("OnShow", UpdateTooltip)

  -- refresh the currently displayed unit identity
  statusbar = CreateFrame("Frame", nil, GameTooltipStatusBar)
  statusbar:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  statusbar:SetScript("OnEvent", function()
    local unit = GetUnit()
    if unit ~= "none" then
      this.name = UnitName(unit)
      this.level = UnitLevel(unit)
    else
      this.name = UnitName("mouseover")
      this.level = UnitLevel("mouseover")
    end

    this.lastHP = nil
    this.lastHPMax = nil
    this.lastName = nil
    this.lastLevel = nil
    UpdateTooltip()
  end)

  -- Keep the lightweight OnUpdate because the vanilla tooltip statusbar can
  -- change without a dedicated Lua event. Skip the expensive estimator/string
  -- work entirely while its inputs are unchanged.
  statusbar:SetScript("OnUpdate", function()
    local hp = GameTooltipStatusBar:GetValue()
    local _, hpmax = GameTooltipStatusBar:GetMinMaxValues()

    if hp == this.lastHP and hpmax == this.lastHPMax and
      this.name == this.lastName and this.level == this.lastLevel then
      return
    end

    this.lastHP = hp
    this.lastHPMax = hpmax
    this.lastName = this.name
    this.lastLevel = this.level

    local rhp, rhpmax, estimated

    if hpmax > 100 or (round(hpmax/100*hp) ~= hp) then
      rhp, rhpmax = hp, hpmax
    else
      rhp, rhpmax, estimated = ShaguTweaks.libhealth:GetUnitHealthByName(this.name, this.level, tonumber(hp), tonumber(hpmax))
    end

    if estimated or hpmax > 100 or round(hpmax/100*hp) ~= hp then
      GameTooltipStatusBar.backdrop.health:SetText(string.format("%s / %s", Abbreviate(rhp, true), Abbreviate(rhpmax, true)))
    elseif hpmax > 0 then
      GameTooltipStatusBar.backdrop.health:SetText(string.format("%s%%", ceil(hp/hpmax*100)))
    else
      GameTooltipStatusBar.backdrop.health:SetText("")
    end
  end)
end
