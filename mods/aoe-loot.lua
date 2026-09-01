-- Adapted from AoELoot by Sandrea / ChatGPT for ShaguTweaks-ClassicAPI.

local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["AoE Loot"],
  description = T["Automatically loots all nearby corpses using ClassicAPI. Leaves Master Loot untouched."],
  expansions = { ["vanilla"] = true },
  category = T["Loot"],
  enabled = nil,
})

module.enable = function(self)
  local frame = CreateFrame("Frame", "ShaguTweaksAoELoot")
  local pending = false

  local function IsMasterLootActive()
    if not GetLootMethod then return false end
    return GetLootMethod() == "master"
  end

  local function CanStartAoELoot()
    if IsMasterLootActive() then return false end
    if not C_Loot or not C_Loot.LootAllCorpses then return false end

    if C_Loot.IsScanInProgress and C_Loot.IsScanInProgress() then
      return false
    end

    return true
  end

  local function StartAoELoot()
    -- Defer for one frame so the normal loot session can close cleanly.
    frame:SetScript("OnUpdate", nil)

    if CanStartAoELoot() then
      C_Loot.LootAllCorpses()
    end
  end

  frame:RegisterEvent("LOOT_OPENED")
  frame:RegisterEvent("LOOT_CLOSED")

  frame:SetScript("OnEvent", function()
    if event == "LOOT_OPENED" then
      -- The master looter must keep the normal window to inspect and assign loot.
      if IsMasterLootActive() then
        pending = false
        frame:SetScript("OnUpdate", nil)
        return
      end

      if pending or not CanStartAoELoot() then return end

      pending = true
      CloseLoot()
      return
    end

    if event == "LOOT_CLOSED" and pending then
      pending = false
      frame:SetScript("OnUpdate", StartAoELoot)
    end
  end)
end
