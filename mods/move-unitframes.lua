local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Movable Unit Frames"],
  description = T["Player and Target unit frames can be moved while <Shift> and <Ctrl> are pressed together."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = true,
})

local movables = { "PlayerFrame", "TargetFrame" }

module.enable = function(self)
  local unlocker = CreateFrame("Frame", nil, UIParent)

  for _, frame in pairs(movables) do
    _G[frame]:SetClampedToScreen(true)
  end

  unlocker.grid = CreateFrame("Frame", nil, WorldFrame)
  unlocker.grid:SetAllPoints(WorldFrame)
  unlocker.grid:Hide()

  local size = 1
  local line = {}

  local width = GetScreenWidth()
  local height = GetScreenHeight()

  local ratio = width / GetScreenHeight()
  local rheight = GetScreenHeight() * ratio

  local wStep = width / 64
  local hStep = rheight / 64

  -- vertical lines
  for i = 0, 64 do
    if i == 64 / 2 then
      line = unlocker.grid:CreateTexture(nil, 'BORDER')
      line:SetTexture(.8, .6, 0)
    else
      line = unlocker.grid:CreateTexture(nil, 'BACKGROUND')
      line:SetTexture(0, 0, 0, .2)
    end
    line:SetPoint("TOPLEFT", unlocker.grid, "TOPLEFT", i*wStep - (size/2), 0)
    line:SetPoint('BOTTOMRIGHT', unlocker.grid, 'BOTTOMLEFT', i*wStep + (size/2), 0)
  end

  -- horizontal lines
  for i = 1, floor(height/hStep) do
    if i == floor(height/hStep / 2) then
      line = unlocker.grid:CreateTexture(nil, 'BORDER')
      line:SetTexture(.8, .6, 0)
    else
      line = unlocker.grid:CreateTexture(nil, 'BACKGROUND')
      line:SetTexture(0, 0, 0, .2)
    end

    line:SetPoint("TOPLEFT", unlocker.grid, "TOPLEFT", 0, -(i*hStep) + (size/2))
    line:SetPoint('BOTTOMRIGHT', unlocker.grid, 'TOPRIGHT', 0, -(i*hStep + size/2))
  end

  local function SetMovableState(shouldMove)
    if shouldMove and not unlocker.movable then
      for _, frame in pairs(movables) do
        _G[frame]:SetUserPlaced(true)
        _G[frame]:SetMovable(true)
        _G[frame]:EnableMouse(true)
        _G[frame]:RegisterForDrag("LeftButton")
        _G[frame]:SetScript("OnDragStart", function() this:StartMoving() end)
        _G[frame]:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
      end

      unlocker.movable = true
      unlocker.grid:Show()
    elseif not shouldMove and unlocker.movable then
      for _, frame in pairs(movables) do
        _G[frame]:SetScript("OnDragStart", function() end)
        _G[frame]:SetScript("OnDragStop", function() end)
        _G[frame]:StopMovingOrSizing()
      end

      unlocker.movable = nil
      unlocker.grid:Hide()
    end
  end

  local hasModifierEvent = _G.C_EventUtils
    and type(_G.C_EventUtils.IsEventValid) == "function"
    and _G.C_EventUtils.IsEventValid("MODIFIER_STATE_CHANGED")

  if hasModifierEvent then
    -- Do not re-query modifier functions from inside MODIFIER_STATE_CHANGED.
    -- The event already tells us exactly which physical key transitioned and
    -- whether it is now down (arg2=1) or up (arg2=0). Keeping our own state
    -- avoids any merged/stale Win32 key-state ambiguity in the callback.
    local state = {
      LSHIFT = type(_G.IsLeftShiftKeyDown) == "function" and _G.IsLeftShiftKeyDown() and true or false,
      RSHIFT = type(_G.IsRightShiftKeyDown) == "function" and _G.IsRightShiftKeyDown() and true or false,
      LCTRL = type(_G.IsLeftControlKeyDown) == "function" and _G.IsLeftControlKeyDown() and true or false,
      RCTRL = type(_G.IsRightControlKeyDown) == "function" and _G.IsRightControlKeyDown() and true or false,
    }

    local function RefreshFromState()
      SetMovableState((state.LSHIFT or state.RSHIFT) and (state.LCTRL or state.RCTRL))
    end

    unlocker:RegisterEvent("MODIFIER_STATE_CHANGED")
    unlocker:RegisterEvent("PLAYER_ENTERING_WORLD")
    unlocker:SetScript("OnEvent", function()
      if event == "MODIFIER_STATE_CHANGED" then
        if state[arg1] ~= nil then
          state[arg1] = arg2 == 1
        end
      elseif event == "PLAYER_ENTERING_WORLD" then
        state.LSHIFT = type(_G.IsLeftShiftKeyDown) == "function" and _G.IsLeftShiftKeyDown() and true or false
        state.RSHIFT = type(_G.IsRightShiftKeyDown) == "function" and _G.IsRightShiftKeyDown() and true or false
        state.LCTRL = type(_G.IsLeftControlKeyDown) == "function" and _G.IsLeftControlKeyDown() and true or false
        state.RCTRL = type(_G.IsRightControlKeyDown) == "function" and _G.IsRightControlKeyDown() and true or false
      end

      RefreshFromState()
    end)
  else
    -- Compatibility fallback for clients without ClassicAPI's modifier event.
    -- This is intentionally tiny: two boolean key checks per rendered frame.
    unlocker:SetScript("OnUpdate", function()
      SetMovableState(IsShiftKeyDown() and IsControlKeyDown())
    end)
  end
end
