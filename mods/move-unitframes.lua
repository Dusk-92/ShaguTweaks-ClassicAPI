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

  -- Shared live state lets other modules (notably Enlarged Minimap) respect
  -- manually positioned aura anchors without fighting the mover while dragging.
  ShaguTweaks.MovableUnitFramesState = ShaguTweaks.MovableUnitFramesState or {
    manual = {},
    dragging = {},
  }
  local sharedState = ShaguTweaks.MovableUnitFramesState

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

  -- Existing saved positions already mean those groups were manually placed.
  -- This also covers positions migrated from the former Extras module.
  sharedState.manual.buffs = movedb["BuffButton0"] ~= nil
  sharedState.manual.debuffs = movedb["BuffButton32"] ~= nil
  sharedState.manual.weapon = movedb["TempEnchant1"] ~= nil
  sharedState.dragging.buffs = false
  sharedState.dragging.debuffs = false
  sharedState.dragging.weapon = false

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
    { name = "Minimap", moveParent = true, persist = true, clamp = true },
    { name = "BuffButton0", persist = true, manualGroup = "buffs", cursorDrag = true },
    { name = "BuffButton32", persist = true, manualGroup = "debuffs", cursorDrag = true },
    { name = "TempEnchant1", persist = true, manualGroup = "weapon", cursorDrag = true },
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

  local function SetDragging(target, value)
    if target.manualGroup then
      sharedState.dragging[target.manualGroup] = value and true or false
    end
  end

  local function MarkManual(target)
    if target.manualGroup then
      sharedState.manual[target.manualGroup] = true
    end
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
    MarkManual(target)
  end

  local function RestorePosition(target)
    if not target.persist then return end

    local _, moveFrame = Resolve(target)
    if not moveFrame then return end

    local pos = movedb[PositionKey(target, moveFrame)]
    if not pos or not pos[1] or not pos[2] then return end

    if not target.cursorDrag then
      moveFrame:SetMovable(true)
      if moveFrame.SetUserPlaced then moveFrame:SetUserPlaced(true) end
    end
    moveFrame:ClearAllPoints()
    moveFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])

    if target.name == "Minimap" and ShaguTweaks.ScheduleMinimapClamp then
      ShaguTweaks.ScheduleMinimapClamp()
    end
  end

  -- Aura buttons are layout-owned frames on some Vanilla/Turtle UI builds.
  -- Calling StartMoving() on them can fail with "Frame ... is not movable or
  -- resizable" even after SetMovable(true). For those frames, follow the cursor
  -- ourselves and only change their anchor; regular unit frames still use the
  -- native StartMoving path.
  local cursorDrag = CreateFrame("Frame")
  cursorDrag:Hide()

  local function CursorPosition()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    return x / scale, y / scale
  end

  local function StartCursorDrag(state, target, moveFrame)
    local left = moveFrame:GetLeft()
    local top = moveFrame:GetTop()
    if not left or not top then return false end

    local x, y = CursorPosition()
    state.cursorStartX = x
    state.cursorStartY = y
    state.frameStartLeft = left
    state.frameStartTop = top

    cursorDrag.state = state
    cursorDrag.target = target
    cursorDrag.moveFrame = moveFrame
    cursorDrag:Show()
    return true
  end

  local function StopCursorDrag(state)
    if cursorDrag.state ~= state then return end

    cursorDrag:Hide()
    cursorDrag.state = nil
    cursorDrag.target = nil
    cursorDrag.moveFrame = nil
  end

  cursorDrag:SetScript("OnUpdate", function()
    local state = this.state
    local target = this.target
    local moveFrame = this.moveFrame
    if not state or not target or not moveFrame then
      this:Hide()
      return
    end

    local x, y = CursorPosition()
    local left = state.frameStartLeft + (x - state.cursorStartX)
    local top = state.frameStartTop + (y - state.cursorStartY)

    moveFrame:ClearAllPoints()
    moveFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  end)

  local function CreateGrid()
    if grid then return grid end

    -- Keep the original WorldFrame coordinate space so the cells retain the
    -- same visual size as the old grid. Instead of deriving the yellow center
    -- lines from top-left offsets, build the whole grid symmetrically around
    -- WorldFrame:CENTER. This guarantees the two yellow axes are truly centered
    -- regardless of UI scale / widescreen coordinate quirks.
    grid = CreateFrame("Frame", nil, WorldFrame)
    grid:SetAllPoints(WorldFrame)
    grid:Hide()

    local size = 1
    local step = GetScreenWidth() / 64

    -- Vertical lines: 32 cells to the left and right of the exact center.
    for i = -32, 32 do
      local line = grid:CreateTexture(nil, i == 0 and "BORDER" or "BACKGROUND")

      if i == 0 then
        line:SetTexture(.8, .6, 0)
      else
        line:SetTexture(0, 0, 0, .2)
      end

      line:SetWidth(size)
      line:SetPoint("TOP", grid, "TOP", i * step, 0)
      line:SetPoint("BOTTOM", grid, "BOTTOM", i * step, 0)
    end

    -- Use the exact same step vertically so every cell remains square, as in
    -- the original implementation. Extra off-screen lines are harmless.
    for i = -32, 32 do
      local line = grid:CreateTexture(nil, i == 0 and "BORDER" or "BACKGROUND")

      if i == 0 then
        line:SetTexture(.8, .6, 0)
      else
        line:SetTexture(0, 0, 0, .2)
      end

      line:SetHeight(size)
      line:SetPoint("LEFT", grid, "LEFT", 0, i * step)
      line:SetPoint("RIGHT", grid, "RIGHT", 0, i * step)
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

    if not target.cursorDrag and moveFrame.IsMovable then
      state.movable = moveFrame:IsMovable() and true or false
    else
      state.movable = nil
    end

    if not target.cursorDrag and moveFrame.IsUserPlaced then
      state.userPlaced = moveFrame:IsUserPlaced() and true or false
    else
      state.userPlaced = nil
    end

    if target.clamp and moveFrame.SetClampedToScreen then
      moveFrame:SetClampedToScreen(true)
    end

    -- Aura buttons can reject StartMoving() on some clients. They only need
    -- mouse/drag scripts because cursorDrag handles their position directly.
    if not target.cursorDrag then
      moveFrame:SetMovable(true)
    end
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    handle:SetScript("OnDragStart", function()
      state.dragged = true
      MarkManual(target)
      SetDragging(target, true)

      if not target.cursorDrag and moveFrame.SetUserPlaced then
        moveFrame:SetUserPlaced(true)
      end

      if target.cursorDrag then
        if not StartCursorDrag(state, target, moveFrame) then
          state.dragged = false
          SetDragging(target, false)
        end
      else
        moveFrame:StartMoving()
      end
    end)

    handle:SetScript("OnDragStop", function()
      if target.cursorDrag then
        StopCursorDrag(state)
      else
        moveFrame:StopMovingOrSizing()
      end

      if state.dragged then
        SavePosition(target, moveFrame)
      end

      SetDragging(target, false)
    end)
  end

  local function LockTarget(index, target)
    local state = states[index]
    if not state or not state.active then return end

    local handle = state.handle
    local moveFrame = state.moveFrame

    if moveFrame then
      if target.cursorDrag then
        StopCursorDrag(state)
      else
        moveFrame:StopMovingOrSizing()
      end
      SetDragging(target, false)

      if state.dragged then
        SavePosition(target, moveFrame)
      end

      -- Restore UserPlaced while the frame is still temporarily movable.
      -- Some Vanilla/Turtle frames (notably MinimapCluster) reject
      -- SetUserPlaced() after SetMovable(false), which caused repeated
      -- "not movable or resizable" errors when releasing Ctrl+Shift.
      if not target.cursorDrag
        and not state.dragged
        and state.userPlaced ~= nil
        and moveFrame.SetUserPlaced then
        moveFrame:SetUserPlaced(state.userPlaced)
      end

      if not target.cursorDrag and state.movable ~= nil then
        moveFrame:SetMovable(state.movable)
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
