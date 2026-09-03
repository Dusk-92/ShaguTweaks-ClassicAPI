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
  -- AoE Loot relies entirely on ClassicAPI's native corpse walker and
  -- container classification. Do not keep partial legacy behavior when those
  -- capabilities are unavailable.
  if not API or not API.aoeloot or not API.containeropenable then return end

  local frame = CreateFrame("Frame", "ShaguTweaksAoELoot")
  local pending = false
  local releaseDeadline = 0
  local containerLootDeadline = 0

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

  local function StartAoELoot()
    -- Defer for one frame so the normal loot session can close cleanly.
    frame:SetScript("OnUpdate", nil)
    pending = false
    releaseDeadline = 0

    if CanStartAoELoot() then
      API.LootAllCorpses()
    end
  end

  local function QueueAoELoot()
    releaseDeadline = 0
    frame:SetScript("OnUpdate", StartAoELoot)
  end

  local function WaitForLootRelease()
    -- Native Auto Loot can finish before this module receives LOOT_OPENED.
    -- In that case LOOT_CLOSED has already passed, so use the empty session
    -- as a fallback and queue the ClassicAPI walk on the following frame.
    if pending and (not GetNumLootItems or GetNumLootItems() == 0) then
      QueueAoELoot()
    elseif pending and GetTime() >= releaseDeadline then
      -- Never leave a per-frame waiter behind if the native loot session
      -- cannot finish, for example because every inventory bag is full.
      pending = false
      releaseDeadline = 0
      frame:SetScript("OnUpdate", nil)
    end
  end

  frame:RegisterEvent("LOOT_OPENED")
  frame:RegisterEvent("LOOT_CLOSED")

  frame:SetScript("OnEvent", function()
    if event == "LOOT_OPENED" then
      -- Inventory containers use the same loot events as corpses. Let the
      -- normal client finish them instead of closing their loot session.
      if containerLootDeadline > 0 then
        local isContainerLoot = GetTime() <= containerLootDeadline
        containerLootDeadline = 0
        if isContainerLoot then return end
      end

      -- The master looter must keep the normal window to inspect and assign loot.
      if IsMasterLootActive() then
        pending = false
        releaseDeadline = 0
        frame:SetScript("OnUpdate", nil)
        return
      end

      -- Chests, fishing nodes and other non-corpse sources also emit
      -- LOOT_OPENED. AoE Loot only has work to do when ClassicAPI can actually
      -- see at least one nearby lootable unit.
      if not HasNearbyLootableCorpse() then return end

      if pending or not CanStartAoELoot() then return end

      pending = true
      releaseDeadline = GetTime() + 3
      frame:SetScript("OnUpdate", WaitForLootRelease)

      -- Close the normal session so ClassicAPI can take over. The temporary
      -- waiter also handles clients whose native Auto Loot already completed
      -- and fired LOOT_CLOSED before this module received LOOT_OPENED.
      CloseLoot()

      return
    end

    if event == "LOOT_CLOSED" and pending then
      QueueAoELoot()
    end
  end)
end
