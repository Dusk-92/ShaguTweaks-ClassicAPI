local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Loot Cursor"],
  description = T["Positions the loot window directly under your cursor so you can loot without moving your mouse."],
  expansions = { ["vanilla"] = true },
  category = T["Loot"],
  enabled = true,
  order = 44,
})

module.enable = function(self)
  local loot = CreateFrame("Frame", "ShaguTweaksLoot", LootFrame)
  local buttons = {}

  for i = 1, LOOTFRAME_NUMBUTTONS do
    buttons[i] = getglobal("LootButton"..i)
  end

  loot:RegisterEvent("LOOT_OPENED")
  loot:RegisterEvent("LOOT_SLOT_CLEARED")
  loot:RegisterEvent("LOOT_CLOSED")

  loot:SetScript("OnEvent", function()
    if event == "LOOT_OPENED" then
      loot.last_button = nil
      loot:Show()
    elseif event == "LOOT_SLOT_CLEARED" then
      loot:Show()
    else
      loot:Hide()
    end
  end)

  loot:SetScript("OnUpdate", function()
    if GetNumLootItems() == 0 then
      loot:Hide()
      HideUIPanel(LootFrame)
      return
    end

    for i = 1, LOOTFRAME_NUMBUTTONS do
      local button = buttons[i]
      if button:IsVisible() then
        if loot.last_button ~= button then
          local x, y = GetCursorPosition()
          local s = LootFrame:GetEffectiveScale()
          local button_offset = (i-1) * button:GetHeight()
          x, y = x / s, y / s
          LootFrame:ClearAllPoints()
          LootFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 40, y + 100 + button_offset)
          loot.last_button = button
        end
        loot:Hide()
        return
      end
    end
  end)

  -- Stay fully dormant between loot changes. If LootFrame has not populated
  -- its buttons yet, OnUpdate remains active until the first one appears.
  loot:Hide()
end
