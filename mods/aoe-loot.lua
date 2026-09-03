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
    frame:SetScript("OnUpdate", nil)
    pending = false

    if CanStartAoELoot() then
      API.LootAllCorpses()
    end
  end

  local function ResolveLootSession()
    -- Give the client's own autoloot path one frame to act before taking over.
    -- This avoids closing the loot session underneath SuperWoW/SuperAPI or a
    -- quickloot-patched client while remaining independent of either mod.
    frame:SetScript("OnUpdate", nil)
    if not pending then return end

    -- Manual loot still has items after that frame. Close only in that case;
    -- when native autoloot already emptied/closed the session, leave it alone.
    if GetNumLootItems and GetNumLootItems() > 0 then
      CloseLoot()
    end

    -- The original path already waits one frame after CloseLoot before handing
    -- control to ClassicAPI. Keep that release frame for both manual and native
    -- autoloot paths.
    frame:SetScript("OnUpdate", StartAoELoot)
  end

  frame:RegisterEvent("LOOT_OPENED")

  frame:SetScript("OnEvent", function()
    if event ~= "LOOT_OPENED" then return end

    -- Inventory containers use the same loot event as corpses. Let the normal
    -- client finish them instead of treating them as an AoE-loot trigger.
    if containerLootDeadline > 0 then
      local isContainerLoot = GetTime() <= containerLootDeadline
      containerLootDeadline = 0
      if isContainerLoot then return end
    end

    -- The master looter must keep the normal window to inspect and assign loot.
    if IsMasterLootActive() then
      pending = false
      frame:SetScript("OnUpdate", nil)
      return
    end

    -- Chests, fishing nodes and other non-corpse sources also emit LOOT_OPENED.
    -- Only take over when ClassicAPI can see at least one nearby lootable unit.
    if not HasNearbyLootableCorpse() then return end

    if pending or not CanStartAoELoot() then return end

    pending = true
    frame:SetScript("OnUpdate", ResolveLootSession)
  end)
end
