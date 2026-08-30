local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local module = ShaguTweaks:register({
  title = T["MiniMap Square"],
  description = T["Draw the mini map in a squared shape instead of a round one."],
  expansions = { ["vanilla"] = true },
  category = T["Minimap & World Map"],
  enabled = nil,
  config = {
    ["minimap.size"] = 144,
  },
})
module.enable = function(self)
  local size = module.config["minimap.size"]
  MinimapBorder:SetTexture(nil)
  Minimap:SetWidth(size)
  Minimap:SetHeight(size)
  Minimap:SetPoint("CENTER", MinimapCluster, "TOP", 9, -98)
  Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")

  -- IMPORTANT: enable() can be called multiple times (reload UI, toggling
  -- the module in ShaguTweaks settings, expansion switch, etc). Without
  -- reusing a single persistent frame, every call created a brand new
  -- anonymous CreateFrame("Frame") parented to Minimap, and the old ones
  -- were never released -- they kept piling up as orphaned children of
  -- Minimap forever. That's a likely contributor to the minimap-related
  -- crashes (addons like MinimapButtonFrame walk Minimap:GetChildren()
  -- every second and can choke on the growing pile of stale frames).
  -- We now store the border on the module and just reconfigure it if it
  -- already exists, instead of creating a new frame.
  if not self.border then
    self.border = CreateFrame("Frame", nil, Minimap)
  end
  Minimap.border = self.border

  Minimap.border:SetFrameStrata("BACKGROUND")
  Minimap.border:SetFrameLevel(1)
  Minimap.border:ClearAllPoints()
  Minimap.border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -3, 3)
  Minimap.border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 3, -3)
  Minimap.border:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }})
  Minimap.border:SetBackdropBorderColor(.9,.8,.5,1)
  Minimap.border:SetBackdropColor(.4,.4,.4,1)
  Minimap.border:Show()

  if _G.MinimapClock then
    if not self.clockOriginalPoint then
      local point, relativeTo, relativePoint, x, y = MinimapClock:GetPoint()
      self.clockOriginalPoint = { point, relativeTo, relativePoint, x, y }
    end

    MinimapClock:ClearAllPoints()
    MinimapClock:SetPoint("TOP", Minimap, "BOTTOM", 0, -2)
  end
end

module.disable = function(self)
  -- Hide instead of leaking: keep the frame alive but out of the way so a
  -- future enable() can reuse it cleanly.
  if self.border then
    self.border:Hide()
  end

  if _G.MinimapClock and self.clockOriginalPoint then
    MinimapClock:ClearAllPoints()
    MinimapClock:SetPoint(unpack(self.clockOriginalPoint))
  end
end
