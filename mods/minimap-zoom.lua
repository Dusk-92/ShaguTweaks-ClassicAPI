local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Enlarged Minimap"],
  description = T["Increases the minimap size and shifts buff icons left to prevent overlap."],
  expansions = { ["vanilla"] = true },
  category = T["World & MiniMap"],
  enabled = false,
  order = 73,
  config = {
    ["minimap.scale"] = 1.2,
  }
})

local function EnsurePoint(frame, point, relativeTo, relativePoint, x, y)
  if not frame then return end

  local currentPoint, currentRelative, currentRelativePoint, currentX, currentY = frame:GetPoint(1)
  if currentPoint == point and currentRelative == relativeTo
    and currentRelativePoint == relativePoint and currentX == x and currentY == y then
    return
  end

  frame:ClearAllPoints()
  frame:SetPoint(point, relativeTo, relativePoint, x, y)
end

module.enable = function(self)
  local scale = module.config["minimap.scale"]
  if scale < 1.0 then scale = 1.0 end
  if scale > 2.0 then scale = 2.0 end

  MinimapCluster:SetScale(scale)

  -- BuffFrame is anchored to UIParent TOPRIGHT/TOPRIGHT x=-205 y=-13 by vanilla.
  -- The C engine can restore these anchors after aura layout updates, so keep a
  -- lightweight per-frame verifier and only write when an anchor actually moved.
  local extra = MinimapCluster:GetWidth() * (scale - 1.0)
  local targetX = -205 - extra
  local targetY = -13

  -- BuffButton16 is the anchor for the player debuff row in vanilla 1.12.
  local debuffX = -205 - extra
  local debuffY = -13 - 70

  -- BuffButton8 ends the top buff row and can overlap an enlarged minimap.
  local buffRowX = -205 - extra
  local buffRowY = debuffY + 26

  -- Reuse a single verifier if enable() is called again. This prevents stacked
  -- OnUpdate frames from fighting over the same anchors.
  if not self.enforcer then
    self.enforcer = CreateFrame("Frame")
  end
  local enforcer = self.enforcer

  enforcer:SetScript("OnUpdate", function()
    EnsurePoint(BuffFrame, "TOPRIGHT", UIParent, "TOPRIGHT", targetX, targetY)

    if BuffButton16 then
      EnsurePoint(BuffButton16, "TOPRIGHT", UIParent, "TOPRIGHT", debuffX, debuffY)
    end

    if BuffButton8 then
      EnsurePoint(BuffButton8, "TOPRIGHT", UIParent, "TOPRIGHT", buffRowX, buffRowY)
    end

    -- Temporary enchant buttons are also restored by the stock aura layout.
    -- Verify their anchors like the buff rows instead of clearing and setting
    -- them unconditionally every frame.
    if TempEnchant1 then
      EnsurePoint(TempEnchant1, "TOPLEFT", BuffFrame, "TOPRIGHT", 5, 0)
    end

    if TempEnchant2 and TempEnchant1 then
      EnsurePoint(TempEnchant2, "TOP", TempEnchant1, "BOTTOM", 0, -2)
    end
  end)
end

module.disable = function(self)
  if self.enforcer then
    self.enforcer:SetScript("OnUpdate", nil)
  end
end
