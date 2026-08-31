-- Movable Unit Frames
-- Extended frame support adapted from TokensWorth/ShaguTweaks-mods
-- (MIT, original copyright GryllsAddons).

local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Movable Unit Frames"],
  description = T["Player, Target, Party, Minimap, Buffs, Weapon Buffs and Debuffs can be moved while <Shift> and <Ctrl> are pressed together."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = true,
})

module.enable = function(self)
  ShaguTweaks_config = ShaguTweaks_config or {}
  ShaguTweaks_config["MoveUnitframes"] = ShaguTweaks_config["MoveUnitframes"] or {}

  local movedb = ShaguTweaks_config["MoveUnitframes"]

  -- Preserve positions created by the former Extras module. The legacy table
  -- is intentionally left untouched so downgrading does not destroy data.
  local legacy = ShaguTweaks_config["MoveUnitframesExtended"]
  if legacy then
    for key, value in pairs(legacy) do
      if movedb[key] == nil then
        movedb[key] = value
      end
    end
  end

  local unlocked = false
  local states = {}
  local grid

  -- Player/Target keep the original ShaguTweaks user-placed behavior.
  -- The formerly-Extended frames use ShaguTweaks_config so their positions
  -- survive reload/relog consistently.
  local targets = {
    { name = "PlayerFrame", clamp = true, persist = false },
    { name = "TargetFrame", clamp = true, persist = false },
    { name = "PartyMemberFrame1", persist = true },
    { name = "PartyMemberFrame2", persist = true },
    { name = "PartyMemberFrame3", persist = true },
    { name = "PartyMemberFrame4", persist = true },
    { name = "Minimap", moveParent = true, persist = true },
    { name = "BuffButton0", persist = true },
    { name = "BuffButton32", persist = true },
    { name = "TempEnchant1", persist = true },
  }

  local function Resolve(target)
    local handle = _G[target.name]
    if not handle then return end

    local moveFrame = target.moveParent and handle:GetParent() or handle
    if not moveFrame then return end

    return handle, moveFrame
  end

  local function PositionKey(target, moveFrame)
    if moveFrame.GetName then
      local name = moveFrame:GetName()
      if name then return name end
    end

    return target.name
  end

  local function SavePosition(target, moveFrame)
    if not target.persist then return end

    if not moveFrame then
      local _, resolved = Resolve(target)
      moveFrame = resolved
    end
    if not moveFrame then return end

    local left = moveFrame:GetLeft()
    local top = moveFrame:GetTop()
    if not left or not top then return end

    movedb[PositionKey(target, moveFrame)] = { left, top }
  end

  local function RestorePosition(target)
    if not target.persist then return end

    local _, moveFrame = Resolve(target)
    if not moveFrame then return end

    local pos = movedb[PositionKey(target, moveFrame)]
    if not pos or not pos[1] or not pos[2] then return end

    moveFrame:SetMovable(true)
    if moveFrame.SetUserPlaced then moveFrame:SetUserPlaced(true) end
    moveFrame:ClearAllPoints()
    moveFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
  end

  local function CreateGrid()
    if grid then return grid end

    grid = CreateFrame("Frame", nil, WorldFrame)
    grid:SetAllPoints(WorldFrame)
    grid:Hide()

    local size = 1
    local width = GetScreenWidth()
    local height = GetScreenHeight()
    local ratio = width / height
    local adjustedHeight = height * ratio
    local wStep = width / 64
    local hStep = adjustedHeight / 64

    for i = 0, 64 do
      local line = grid:CreateTexture(nil, i == 32 and "BORDER" or "BACKGROUND")

      if i == 32 then
        line:SetTexture(.8, .6, 0)
      else
        line:SetTexture(0, 0, 0, .2)
      end

      line:SetPoint("TOPLEFT", grid, "TOPLEFT", i * wStep - (size / 2), 0)
      line:SetPoint("BOTTOMRIGHT", grid, "BOTTOMLEFT", i * wStep + (size / 2), 0)
    end

    local rows = floor(height / hStep)
    local middle = floor(rows / 2)

    for i = 1, rows do
      local line = grid:CreateTexture(nil, i == middle and "BORDER" or "BACKGROUND")

      if i == middle then
        line:SetTexture(.8, .6, 0)
      else
        line:SetTexture(0, 0, 0, .2)
      end

      line:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -(i * hStep) + (size / 2))
      line:SetPoint("BOTTOMRIGHT", grid, "TOPRIGHT", 0, -(i * hStep + size / 2))
    end

    return grid
  end

  local function UnlockTarget(index, target)
    local handle, moveFrame = Resolve(target)
    if not handle or not moveFrame then return end

    states[index] = states[index] or {}
    local state = states[index]
    if state.active then return end

    state.active = true
    state.dragged = false
    state.handle = handle
    state.moveFrame = moveFrame
    state.onDragStart = handle:GetScript("OnDragStart")
    state.onDragStop = handle:GetScript("OnDragStop")

    if handle.IsMouseEnabled then
      state.mouseEnabled = handle:IsMouseEnabled() and true or false
    else
      state.mouseEnabled = nil
    end

    if moveFrame.IsMovable then
      state.movable = moveFrame:IsMovable() and true or false
    else
      state.movable = nil
    end

    if moveFrame.IsUserPlaced then
      state.userPlaced = moveFrame:IsUserPlaced() and true or false
    else
      state.userPlaced = nil
    end

    if target.clamp and moveFrame.SetClampedToScreen then
      moveFrame:SetClampedToScreen(true)
    end

    moveFrame:SetMovable(true)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    handle:SetScript("OnDragStart", function()
      state.dragged = true

      if moveFrame.SetUserPlaced then
        moveFrame:SetUserPlaced(true)
      end

      moveFrame:StartMoving()
    end)

    handle:SetScript("OnDragStop", function()
      moveFrame:StopMovingOrSizing()

      if state.dragged then
        SavePosition(target, moveFrame)
      end
    end)
  end

  local function LockTarget(index, target)
    local state = states[index]
    if not state or not state.active then return end

    local handle = state.handle
    local moveFrame = state.moveFrame

    if moveFrame then
      moveFrame:StopMovingOrSizing()

      if state.dragged then
        SavePosition(target, moveFrame)
      end

      if state.movable ~= nil then
        moveFrame:SetMovable(state.movable)
      end

      -- A dragged frame remains user-placed. An untouched frame is restored
      -- exactly to the state it had before Ctrl+Shift was pressed.
      if not state.dragged
        and state.userPlaced ~= nil
        and moveFrame.SetUserPlaced then
        moveFrame:SetUserPlaced(state.userPlaced)
      end
    end

    if handle then
      handle:SetScript("OnDragStart", state.onDragStart)
      handle:SetScript("OnDragStop", state.onDragStop)

      if state.mouseEnabled ~= nil then
        handle:EnableMouse(state.mouseEnabled)
      end
    end

    state.active = false
  end

  local function UnlockAll()
    if unlocked then return end
    unlocked = true

    for i, target in ipairs(targets) do
      UnlockTarget(i, target)
    end

    CreateGrid():Show()
  end

  local function LockAll()
    if not unlocked then return end

    for i, target in ipairs(targets) do
      LockTarget(i, target)
    end

    if grid then grid:Hide() end
    unlocked = false
  end

  local function UpdateLockState()
    if API.IsShiftKeyDown() and API.IsControlKeyDown() then
      UnlockAll()
    else
      LockAll()
    end
  end

  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")

  if API.modifierstate then
    events:RegisterEvent("MODIFIER_STATE_CHANGED")
  end

  events:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      for _, target in ipairs(targets) do
        RestorePosition(target)
      end
    end

    UpdateLockState()
  end)

  -- ClassicAPI supplies MODIFIER_STATE_CHANGED. Only old/fallback clients use
  -- a small throttled key-state check.
  if not API.modifierstate then
    events.elapsed = 0
    events:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + (arg1 or 0)
      if this.elapsed < .10 then return end
      this.elapsed = 0
      UpdateLockState()
    end)
  end

  for _, target in ipairs(targets) do
    if target.clamp then
      local _, moveFrame = Resolve(target)
      if moveFrame and moveFrame.SetClampedToScreen then
        moveFrame:SetClampedToScreen(true)
      end
    end

    RestorePosition(target)
  end

  UpdateLockState()
end
