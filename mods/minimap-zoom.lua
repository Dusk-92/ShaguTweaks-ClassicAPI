local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Enlarged Minimap"],
  description = T["Increases the minimap size and shifts buff icons left to prevent overlap."],
  expansions = { ["vanilla"] = true },
  category = T["Minimap & World Map"],
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

local function GetMoverState(group)
  local state = ShaguTweaks.MovableUnitFramesState
  if not state then return false, false end

  local manual = state.manual and state.manual[group] and true or false
  local dragging = state.dragging and state.dragging[group] and true or false
  return manual, dragging
end

local function GetMovedPosition(key)
  local config = ShaguTweaks_config and ShaguTweaks_config["MoveUnitframes"]
  return config and config[key]
end

local function EnsureMovedPosition(frame, key)
  local pos = GetMovedPosition(key)
  if not frame or not pos or not pos[1] or not pos[2] then return end

  EnsurePoint(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
end

-- Keep a moved/scaled minimap fully on screen without touching its saved
-- Movable Unit Frames position. Bounds are compared in physical screen space
-- because MinimapCluster can have a different effective scale than UIParent.
local function ClampMinimapToScreen()
  local frame = MinimapCluster
  if not frame or not UIParent then return end

  local left = frame:GetLeft()
  local right = frame:GetRight()
  local top = frame:GetTop()
  local bottom = frame:GetBottom()
  if not left or not right or not top or not bottom then return end

  local frameScale = frame:GetEffectiveScale()
  local uiScale = UIParent:GetEffectiveScale()
  if not frameScale or frameScale <= 0 or not uiScale or uiScale <= 0 then return end

  local uiLeft = (UIParent:GetLeft() or 0) * uiScale
  local uiRight = (UIParent:GetRight() or UIParent:GetWidth()) * uiScale
  local uiTop = (UIParent:GetTop() or UIParent:GetHeight()) * uiScale
  local uiBottom = (UIParent:GetBottom() or 0) * uiScale

  local frameLeft = left * frameScale
  local frameRight = right * frameScale
  local frameTop = top * frameScale
  local frameBottom = bottom * frameScale

  local dx, dy = 0, 0

  if frameLeft < uiLeft then
    dx = uiLeft - frameLeft
  elseif frameRight > uiRight then
    dx = uiRight - frameRight
  end

  if frameBottom < uiBottom then
    dy = uiBottom - frameBottom
  elseif frameTop > uiTop then
    dy = uiTop - frameTop
  end

  if dx == 0 and dy == 0 then return end

  -- Anchor from the measured top-left so only the overflowing amount is moved.
  -- This changes the live position only; the saved mover coordinates stay intact.
  local newLeft = (frameLeft + dx - uiLeft) / frameScale
  local newTop = (frameTop + dy - uiBottom) / frameScale

  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft, newTop)
end

-- Layout coordinates can lag one frame after SetScale()/SetPoint() on Vanilla.
-- Coalesce clamp requests into a single deferred pass with no permanent OnUpdate.
local minimapClampFrame = CreateFrame("Frame")
minimapClampFrame:Hide()
minimapClampFrame:SetScript("OnUpdate", function()
  this:Hide()
  ClampMinimapToScreen()
end)

ShaguTweaks.ScheduleMinimapClamp = function()
  minimapClampFrame:Show()
end

module.enable = function(self)
  local scale = module.config["minimap.scale"]
  if scale < 1.0 then scale = 1.0 end
  if scale > 2.0 then scale = 2.0 end

  if MinimapCluster.SetClampedToScreen then
    MinimapCluster:SetClampedToScreen(true)
  end

  MinimapCluster:SetScale(scale)
  ShaguTweaks.ScheduleMinimapClamp()

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
    local buffsManual, buffsDragging = GetMoverState("buffs")
    local debuffsManual, debuffsDragging = GetMoverState("debuffs")
    local weaponManual, weaponDragging = GetMoverState("weapon")

    -- Manually moved aura groups always win. While a group is actively being
    -- dragged, do not write any anchor for it; once released, enforce the
    -- saved user position instead of the Enlarged Minimap default.
    if buffsManual then
      if not buffsDragging then
        EnsureMovedPosition(BuffButton0, "BuffButton0")
      end
    else
      EnsurePoint(BuffFrame, "TOPRIGHT", UIParent, "TOPRIGHT", targetX, targetY)

      if BuffButton8 then
        EnsurePoint(BuffButton8, "TOPRIGHT", UIParent, "TOPRIGHT", buffRowX, buffRowY)
      end
    end

    if debuffsManual then
      if not debuffsDragging then
        EnsureMovedPosition(BuffButton32, "BuffButton32")
      end
    elseif BuffButton16 then
      EnsurePoint(BuffButton16, "TOPRIGHT", UIParent, "TOPRIGHT", debuffX, debuffY)
    end

    if weaponManual then
      if not weaponDragging then
        EnsureMovedPosition(TempEnchant1, "TempEnchant1")

        if TempEnchant2 and TempEnchant1 then
          EnsurePoint(TempEnchant2, "TOP", TempEnchant1, "BOTTOM", 0, -2)
        end
      end
    else
      -- Temporary enchant buttons are also restored by the stock aura layout.
      -- Verify their anchors like the buff rows instead of clearing and setting
      -- them unconditionally every frame.
      if TempEnchant1 then
        EnsurePoint(TempEnchant1, "TOPLEFT", BuffFrame, "TOPRIGHT", 5, 0)
      end

      if TempEnchant2 and TempEnchant1 then
        EnsurePoint(TempEnchant2, "TOP", TempEnchant1, "BOTTOM", 0, -2)
      end
    end
  end)
end

module.disable = function(self)
  if self.enforcer then
    self.enforcer:SetScript("OnUpdate", nil)
  end
end
