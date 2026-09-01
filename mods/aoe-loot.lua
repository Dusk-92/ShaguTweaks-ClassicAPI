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
  local releaseDeadline = 0

  local function IsMasterLootActive()
    if not GetLootMethod then return false end
    return GetLootMethod() == "master"
  end

  local function IsAutoLootActive()
    if not GetCVar then return false end

    local enabled = tonumber(GetCVar("autoLootDefault")) == 1
    if IsShiftKeyDown and IsShiftKeyDown() then
      enabled = not enabled
    end

    return enabled
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
    pending = false
    releaseDeadline = 0

    if CanStartAoELoot() then
      C_Loot.LootAllCorpses()
    end
  end

  local function QueueAoELoot()
    pending = false
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
      -- The master looter must keep the normal window to inspect and assign loot.
      if IsMasterLootActive() then
        pending = false
        releaseDeadline = 0
        frame:SetScript("OnUpdate", nil)
        return
      end

      if pending or not CanStartAoELoot() then return end

      pending = true
      releaseDeadline = GetTime() + 3
      frame:SetScript("OnUpdate", WaitForLootRelease)

      -- Let native Auto Loot drain the first corpse. Without Auto Loot,
      -- close the normal session so ClassicAPI can take over all corpses.
      if not IsAutoLootActive() then
        CloseLoot()
      end

      return
    end

    if event == "LOOT_CLOSED" and pending then
      QueueAoELoot()
    end
  end)
end
