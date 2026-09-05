local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local HookScript = ShaguTweaks.HookScript

local module = ShaguTweaks:register({
  title = T["WorldMap Window"],
  description = T["Turns the world map into a movable window. The map can be scaled with <Ctrl> + Mousewheel."],
  expansions = { ["vanilla"] = true },
  category = T["Minimap & World Map"],
  enabled = true,
})

local function AddSpecialFrame(name)
  for i = 1, table.getn(UISpecialFrames) do
    if UISpecialFrames[i] == name then return end
  end
  table.insert(UISpecialFrames, name)
end

module.enable = function(self)
  -- Only advertise the window as active after the delayed compatibility check.
  -- Turtle WoW consumes this flag instead of looking at config alone.
  ShaguTweaks.WorldMapWindowActive = nil

  -- Reuse one initialization frame so repeated enable() calls cannot stack
  -- PLAYER_ENTERING_WORLD handlers or duplicate WorldMapFrame hooks.
  if not self.delay then
    self.delay = CreateFrame("Frame")
  end

  local delay = self.delay
  delay:RegisterEvent("PLAYER_ENTERING_WORLD")
  delay:SetScript("OnEvent", function()
    -- Do not touch the stock world-map controls at all when a dedicated map
    -- addon owns them. Run this before replacing ToggleWorldMap or adding hooks.
    if Cartographer or METAMAP_TITLE then
      ShaguTweaks.WorldMapWindowActive = nil
      this:UnregisterAllEvents()
      this:Hide()
      return
    end

    ShaguTweaks.WorldMapWindowActive = true
    AddSpecialFrame("WorldMapFrame")

    -- Window mode requires a direct Show/Hide toggle instead of the stock
    -- full-screen panel toggle. Install it only after the compatibility check.
    if not self.toggleInstalled then
      self.toggleInstalled = true
      function _G.ToggleWorldMap()
        if WorldMapFrame:IsShown() then
          WorldMapFrame:Hide()
        else
          WorldMapFrame:Show()
        end
      end
    end

    UIPanelWindows["WorldMapFrame"] = { area = "center" }

    if not self.hooked then
      self.hooked = true

      HookScript(WorldMapFrame, "OnShow", function()
        this:EnableKeyboard(false)
        this:EnableMouseWheel(1)
        WorldMapFrame:SetScale(.85)
      end)

      HookScript(WorldMapFrame, "OnMouseWheel", function()
        if API.IsShiftKeyDown() then
          WorldMapFrame:SetAlpha(WorldMapFrame:GetAlpha() + arg1 / 10)
        elseif API.IsControlKeyDown() then
          WorldMapFrame:SetScale(WorldMapFrame:GetScale() + arg1 / 10)
        end
      end)

      HookScript(WorldMapFrame, "OnMouseDown", function()
        WorldMapFrame:StartMoving()
      end)

      HookScript(WorldMapFrame, "OnMouseUp", function()
        WorldMapFrame:StopMovingOrSizing()
      end)
    end

    WorldMapFrame:SetMovable(true)
    WorldMapFrame:EnableMouse(true)

    WorldMapFrame:SetScale(.85)
    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    WorldMapFrame:SetWidth(WorldMapButton:GetWidth() + 15)
    WorldMapFrame:SetHeight(WorldMapButton:GetHeight() + 55)
    BlackoutWorld:Hide()

    -- Initialization is complete. Keeping this event registered would repeat
    -- the full layout work on every loading screen and reset a moved window.
    this:UnregisterAllEvents()
    this:Hide()
  end)
end
