local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["WorldMap Class Colors"],
  description = T["Show class colored circles on world and battlefield map."],
  expansions = { ["vanilla"] = true },
  category = T["Minimap & World Map"],
  enabled = true,
})

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in pairs(tocs) do
  local current = string.format("ShaguTweaks%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end

local partyUnits = { "party1", "party2", "party3", "party4" }

local function SetAllPointsOffset(frame, parent, offset)
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", offset, -offset)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -offset, offset)
end

local function IsMapVisible()
  local worldmap = _G.WorldMapFrame
  local battlefield = _G.BattlefieldMinimap
  return (worldmap and worldmap:IsVisible()) or (battlefield and battlefield:IsVisible())
end

local function UpdateWorldMapColors()
  -- This module used to iterate up to 88 map buttons all the time, even when
  -- both maps were closed. Keep the OnUpdate compatibility path, but make the
  -- expensive work conditional on a visible map.
  if not IsMapVisible() then return end

  -- throttle to one update per .1 second
  if (this.tick or 1) > GetTime() then return else this.tick = GetTime() + .1 end

  local frame, icon

  -- initialize all button names
  if not this.buttons then
    this.buttons = {}

    for i = 1, 4 do
      icon = string.format("WorldMapParty%d", i)
      this.buttons[icon] = string.format("party%d", i)
    end

    for i = 1, 4 do
      icon = string.format("BattlefieldMinimapParty%d", i)
      this.buttons[icon] = string.format("party%d", i)
    end

    for i = 1, 40 do
      icon = string.format("BattlefieldMinimapRaid%d", i)
      this.buttons[icon] = string.format("raid%d", i)
    end

    for i = 1, 40 do
      icon = string.format("WorldMapRaid%d", i)
      this.buttons[icon] = string.format("raid%d", i)
    end
  end

  -- update all available buttons
  local ingroup
  for name, unitstr in pairs(this.buttons) do
    frame = _G[name]

    if frame and UnitExists(unitstr) then
      icon = _G[name.."Icon"]
      if icon then icon:SetTexture() end

      -- create icon if not yet existing
      if not frame.texture then
        frame.texture = frame:CreateTexture(nil, "OVERLAY")
        SetAllPointsOffset(frame.texture, frame, 12)
      end

      -- check if unit is in same party group
      local unitName = UnitName(unitstr)
      ingroup = nil
      for i=1,4 do
        if UnitName(partyUnits[i]) == unitName then
          ingroup = true
          break
        end
      end

      -- update texture according to raid/group state
      if ingroup and frame.texture.ingroup ~= "PARTY" then
        frame.texture:SetTexture(addonpath .. "\\img\\circleparty")
        frame.texture.ingroup = "PARTY"
      elseif not ingroup and frame.texture.ingroup ~= "RAID" then
        frame.texture:SetTexture(addonpath .. "\\img\\circleraid")
        frame.texture.ingroup = "RAID"
      end

      -- detect unit class and set color
      local _, class = UnitClass(unitstr)
      local color = RAID_CLASS_COLORS[class]
      if color then
        frame.texture:SetVertexColor(color.r, color.g, color.b)
      else
        frame.texture:SetVertexColor(.5,1,.5)
      end
    end
  end
end

local mapcolors = CreateFrame("Frame", nil, UIParent)

module.enable = function(self)
  mapcolors:SetScript("OnUpdate", UpdateWorldMapColors)
end
