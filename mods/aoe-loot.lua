-- Adapted from AoELoot by Sandrea / ChatGPT for ShaguTweaks-ClassicAPI.

local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["AoE Loot"],
  description = T["Automatically loots all nearby corpses using ClassicAPI without confirmation prompts. Leaves Master Loot untouched."],
  expansions = { ["vanilla"] = true },
  category = T["Loot"],
  enabled = nil,
})

module.enable = function(self)
  -- AoE Loot relies entirely on ClassicAPI's native corpse walker,
  -- container classification and timer. Do not keep partial legacy behavior
  -- when those capabilities are unavailable.
  if not API or not API.aoeloot or not API.containeropenable or not API.timer then return end

  local frame = CreateFrame("Frame", "ShaguTweaksAoELoot")
  local pending = false
  local containerLootDeadline = 0
  local takeoverGeneration = 0
  local TAKEOVER_DELAY = 0.3

  local function CancelTakeover()
    takeoverGeneration = takeoverGeneration + 1
    pending = false
  end

  local function TrackContainerUse(bag, slot)
    local isOpenable, canOpen = API.IsContainerItemOpenable(bag, slot)
    if isOpenable and canOpen then
      -- LOOT_OPENED is also fired by clams, lockboxes and similar bag items.
      -- Mark that session before UseContainerItem runs so it remains under the
      -- normal client handling and the consumed container can leave the bag.
      containerLootDeadline = GetTime() + 3
    end
  end

  -- Use the ShaguTweaks hook explicitly because its prepend mode records the
  -- bag item before UseContainerItem can synchronously fire LOOT_OPENED.
  ShaguTweaks.hooksecurefunc("UseContainerItem", TrackContainerUse, true)

  local function IsMasterLootActive()
    if not GetLootMethod then return false end
    return GetLootMethod() == "master"
  end

  local function CanStartAoELoot()
    if IsMasterLootActive() then return false end
    if API.IsLootScanInProgress() then return false end
    return true
  end

  local function HasNearbyLootableCorpse()
    local units = API.GetNearbyLootableUnits()
    return type(units) == "table" and table.getn(units) > 0
  end

  local function StartAoELoot(generation)
    if generation ~= takeoverGeneration or not pending then return end

    pending = false
    if CanStartAoELoot() then
      API.LootAllCorpses()
    end
  end

  local function TakeOverLootSession()
    -- AoE Loot owns corpse sessions while enabled. Close the normal client
    -- window immediately so Vanilla autoloot, SuperAPI SetAutoloot modes and
    -- quickloot-patched clients cannot keep control of the session.
    takeoverGeneration = takeoverGeneration + 1
    local generation = takeoverGeneration
    pending = true
    CloseLoot()

    -- Native autoloot may already have emitted loot packets before LOOT_OPENED
    -- reaches Lua. ClassicAPI's own loot test uses the same 0.3s settling
    -- window between loot operations; after it expires the native corpse walker
    -- becomes the sole owner of all remaining nearby corpse loot.
    C_Timer.After(TAKEOVER_DELAY, function()
      StartAoELoot(generation)
    end)
  end

  frame:RegisterEvent("LOOT_OPENED")

  frame:SetScript("OnEvent", function()
    if event ~= "LOOT_OPENED" then return end

    -- Inventory containers use the same loot event as corpses. Let the normal
    -- client finish them instead of treating them as an AoE-loot trigger.
    if containerLootDeadline > 0 then
      local isContainerLoot = GetTime() <= containerLootDeadline
      containerLootDeadline = 0
      if isContainerLoot then
        CancelTakeover()
        return
      end
    end

    -- The master looter must keep the normal window to inspect and assign loot.
    if IsMasterLootActive() then
      CancelTakeover()
      return
    end

    -- Chests, fishing nodes and other non-corpse sources also emit LOOT_OPENED.
    -- Only take over when ClassicAPI can see at least one nearby lootable unit.
    if not HasNearbyLootableCorpse() then return end

    -- A queued takeover already owns this interaction. ClassicAPI suppresses
    -- its own LOOT_OPENED/LOOT_CLOSED events while walking corpses, so no
    -- additional session needs to be stacked here.
    if pending then return end

    TakeOverLootSession()
  end)
end
