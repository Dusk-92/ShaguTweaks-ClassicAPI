local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Minimap Clean"],
  description = T["Hides minimap addon buttons automatically when the cursor leaves the minimap area."],
  expansions = { ["vanilla"] = true },
  category = T["World & MiniMap"],
  enabled = false,
})

-- Frames and textures that belong to the minimap itself or should stay visible.
local ignoreList = {
  "MiniMapTrackingFrame",
  "MiniMapMeetingStoneFrame",
  "MiniMapMailFrame",
  "MiniMapPing",
  "MinimapBackdrop",
  "MinimapZoomIn",
  "MinimapZoomOut",
  "BookOfTracksFrame",
  "GatherNote",
  "FishingExtravaganzaMini",
  "MiniNotePOI",
  "RecipeRadarMinimapIcon",
  "FWGMinimapPOI",
  "MBB_MinimapButtonFrame",
  "QuestieNote",
  "MetaMap",
  "LootLinkMinimapButton",
  "TimeManagerClockButton",
  "pfMiniMapPin",
  "Clock",
  "Timer",
  "GameTimeFrame",
  "MinimapToggleButton",
  "TWMinimapShopFrame",
  "LFT_Minimap"
}

local function ShouldIgnore(name)
  if not name then return true end
  for i = 1, table.getn(ignoreList) do
    if string.find(name, ignoreList[i], 1, true) then
      return true
    end
  end
  return false
end

-- Vanilla 1.12 can throw an error when GetScript() is queried with a script
-- type that the frame object doesn't support (AtlasCFMButtonFrame is one
-- example). pcall keeps detection harmless for every frame type.
local function GetScriptSafe(frame, script)
  if not frame or type(frame.GetScript) ~= "function" then return nil end

  local ok, handler = pcall(frame.GetScript, frame, script)
  if ok then return handler end
  return nil
end

local function IsAddonButton(child)
  if not child or not child.GetName then return false end

  local name = child:GetName()
  if ShouldIgnore(name) then return false end

  local hasClick = GetScriptSafe(child, "OnClick")
  local hasMouseUp = GetScriptSafe(child, "OnMouseUp")
  local hasMouseDown = GetScriptSafe(child, "OnMouseDown")

  -- Sometimes the clickable button is nested in a child of the main frame.
  if not (hasClick or hasMouseUp or hasMouseDown) and child.GetChildren then
    local subchildren = { child:GetChildren() }
    for i = 1, table.getn(subchildren) do
      if GetScriptSafe(subchildren[i], "OnClick") then
        return true
      end
    end
  end

  return hasClick or hasMouseUp or hasMouseDown
end

local buttonCache = {}
local cachedChildCount = -1

local function RefreshButtonCache()
  local childCount = Minimap:GetNumChildren()
  if childCount == cachedChildCount then return end

  cachedChildCount = childCount
  buttonCache = {}

  local children = { Minimap:GetChildren() }
  for i = 1, table.getn(children) do
    local child = children[i]
    if IsAddonButton(child) then
      buttonCache[table.getn(buttonCache) + 1] = child
    end
  end
end

local function SetButtonsAlpha(alpha)
  RefreshButtonCache()

  for i = 1, table.getn(buttonCache) do
    local button = buttonCache[i]
    if button and button.SetAlpha then
      button:SetAlpha(alpha)
    end
  end
end

module.enable = function(self)
  self.isShown = true
  self.leaveTime = nil
  self.elapsed = 0

  local HIDE_DELAY = 3
  local THROTTLE = 0.1
  local MARGIN = 30

  self.frame = self.frame or CreateFrame("Frame")

  -- Prime the cache once. Future scans only happen when the minimap child count
  -- changes, e.g. when an addon creates a button after login.
  RefreshButtonCache()

  self.frame:SetScript("OnUpdate", function()
    self.elapsed = self.elapsed + arg1
    if self.elapsed < THROTTLE then return end
    self.elapsed = 0

    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local mx, my = x / scale, y / scale

    local left = Minimap:GetLeft()
    local right = Minimap:GetRight()
    local bottom = Minimap:GetBottom()
    local top = Minimap:GetTop()
    if not left or not right or not bottom or not top then return end

    local isOver = mx >= (left - MARGIN) and mx <= (right + MARGIN)
      and my >= (bottom - MARGIN) and my <= (top + MARGIN)

    if isOver then
      self.leaveTime = nil
      if not self.isShown then
        SetButtonsAlpha(1)
        self.isShown = true
      end
    elseif self.isShown then
      local now = GetTime()
      if not self.leaveTime then
        self.leaveTime = now
      elseif now - self.leaveTime >= HIDE_DELAY then
        SetButtonsAlpha(0)
        self.isShown = false
        self.leaveTime = nil
      end
    end
  end)
end

module.disable = function(self)
  if self.frame then
    self.frame:SetScript("OnUpdate", nil)
  end

  -- Restore all detected addon buttons when the module is disabled.
  cachedChildCount = -1
  SetButtonsAlpha(1)
end
