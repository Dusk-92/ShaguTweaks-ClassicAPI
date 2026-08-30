local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local AddBorder = ShaguTweaks.AddBorder
local HookScript = ShaguTweaks.HookScript
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local HookAddonOrVariable = ShaguTweaks.HookAddonOrVariable

local borderModule = ShaguTweaks:register({
  title = T["Item Rarity Borders"],
  description = T["Show item rarity as colored borders on bags, bank, character, inspect, merchant, quest, mail, trade, craft, tradeskill and loot frames."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local glowModule = ShaguTweaks:register({
  title = T["Item Rarity Glows"],
  description = T["Show a rarity-colored glow on item buttons independently from Item Rarity Borders."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = nil,
})

local Engine = ShaguTweaks.ItemRarityEngine or {}
ShaguTweaks.ItemRarityEngine = Engine

Engine.borders = Engine.borders or false
Engine.glows = Engine.glows or false
Engine.installed = Engine.installed or false
Engine.glowTextures = Engine.glowTextures or {}

local paperdollSlots = {
  [0] = "AmmoSlot", "HeadSlot", "NeckSlot", "ShoulderSlot", "ShirtSlot",
  "ChestSlot", "WaistSlot", "LegsSlot", "FeetSlot", "WristSlot", "HandsSlot",
  "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "BackSlot",
  "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "TabardSlot",
}

local inspectSlots = {
  "HeadSlot", "NeckSlot", "ShoulderSlot", "ShirtSlot", "ChestSlot",
  "WaistSlot", "LegsSlot", "FeetSlot", "WristSlot", "HandsSlot",
  "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "BackSlot",
  "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "TabardSlot",
}

local function Quality(itemID)
  if not itemID then return end
  return API.GetItemQualityByID(itemID)
end

local function IsQuestItem(itemID)
  if not itemID then return false end
  local _, _, _, _, _, itemType = API.GetItemInfo(itemID)
  return itemType == "Quest"
end

local function NormalizeInsets(inset)
  if type(inset) == "table" then
    local top, right, bottom, left = unpack(inset)
    return left and -left or 0, top or 0, right or 0, bottom and -bottom or 0
  end

  inset = inset or 0
  return -inset, inset, inset, -inset
end

local function EnsureGlow(button, inset)
  if not button then return end
  if button.ShaguTweaks_itemRarityGlow then return button.ShaguTweaks_itemRarityGlow end

  local left, top, right, bottom = NormalizeInsets(inset or 14)
  local texture = button:CreateTexture(nil, "OVERLAY")
  texture:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  texture:SetBlendMode("ADD")
  texture:SetPoint("TOPLEFT", button, "TOPLEFT", left, top)
  texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", right, bottom)
  texture:Hide()

  button.ShaguTweaks_itemRarityGlow = texture
  table.insert(Engine.glowTextures, texture)
  return texture
end

local function SetVisualColor(button, itemID, opts)
  if not button then return end
  opts = opts or {}

  local default = opts.default or { r = .5, g = .5, b = .46 }
  local quality = Quality(itemID)
  local quest = opts.quest ~= false and IsQuestItem(itemID)
  local r, g, b
  local hasRarity = false

  if quest then
    r, g, b = 1, 1, 0
    hasRarity = true
  elseif quality ~= nil and quality >= (opts.borderMin or 0) then
    r, g, b = GetItemQualityColor(quality)
    hasRarity = true
  end

  if Engine.borders then
    local border = AddBorder(button, opts.borderInset or 3, default)
    if border then
      if hasRarity then
        border:SetBackdropBorderColor(r, g, b, 1)
      else
        border:SetBackdropBorderColor(default.r, default.g, default.b, opts.defaultAlpha or 1)
      end
    end
  end

  if Engine.glows then
    local glow = EnsureGlow(button, opts.glowInset or 14)
    if glow then
      local glowRarity = quest or (quality ~= nil and quality >= (opts.glowMin or 2))
      if glowRarity then
        if not quest then r, g, b = GetItemQualityColor(quality) end
        glow:SetVertexColor(r, g, b, .7)
        glow:Show()
      else
        glow:Hide()
      end
    end
  end
end

local function ReanchorToIcon(button, icon, borderInset, glowInset)
  if not button or not icon then return end

  if Engine.borders and button.ShaguTweaks_border then
    local border = button.ShaguTweaks_border
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -(borderInset or 2), borderInset or 2)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", borderInset or 2, -(borderInset or 2))
  end

  if Engine.glows and button.ShaguTweaks_itemRarityGlow then
    local glow = button.ShaguTweaks_itemRarityGlow
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -(glowInset or 14), glowInset or 14)
    glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", glowInset or 14, -(glowInset or 14))
  end
end

local function ApplyIconButton(button, icon, itemID, opts)
  SetVisualColor(button, itemID, opts)
  ReanchorToIcon(button, icon, opts and opts.borderInset or 2, opts and opts.glowInset or 14)
end

function Engine:Install()
  if self.installed then return end
  self.installed = true

  local function RefreshPaperdoll()
    for slotID, slotName in pairs(paperdollSlots) do
      local button = _G["Character" .. slotName]
      if button then
        SetVisualColor(button, API.GetInventoryItemID("player", slotID), {
          default = { r = .5, g = .5, b = .5 },
          borderMin = 0,
          glowMin = 2,
        })
      end
    end
  end

  local function RefreshInspect()
    for slotID, slotName in pairs(inspectSlots) do
      local button = _G["Inspect" .. slotName]
      if button then
        SetVisualColor(button, API.GetInventoryItemID("target", slotID), {
          default = { r = .5, g = .5, b = .5 },
          borderMin = 0,
          glowMin = 2,
        })
      end
    end
  end

  local function RefreshBags(bagID)
    bagID = bagID and tonumber(bagID) or nil
    for frameIndex = 1, 12 do
      local frame = _G["ContainerFrame" .. frameIndex]
      if frame and frame:IsShown() then
        local id = frame:GetID()
        if not bagID or id == bagID then
          local name = frame:GetName()
          for slot = 1, MAX_CONTAINER_ITEMS do
            local button = _G[name .. "Item" .. slot]
            if button and button:IsShown() then
              SetVisualColor(button, API.GetContainerItemID(id, button:GetID()), {
                borderMin = 0,
                glowMin = 2,
              })
            end
          end
        end
      end
    end

    for bag = 0, 3 do
      local button = _G["CharacterBag" .. bag .. "Slot"]
      if button then
        local inventorySlot = bag + 20
        SetVisualColor(button, API.GetInventoryItemID("player", inventorySlot), {
          borderMin = 0,
          glowMin = 2,
        })
      end
    end
  end

  local function RefreshBank()
    for slot = 1, 28 do
      local button = _G["BankFrameItem" .. slot]
      if button then
        SetVisualColor(button, API.GetContainerItemID(-1, slot), {
          borderMin = 2,
          glowMin = 2,
        })
      end
    end
  end

  local function RefreshWeapons()
    local mainID = API.GetInventoryItemID("player", TempEnchant1:GetID())
    local offID = API.GetInventoryItemID("player", TempEnchant2:GetID())
    SetVisualColor(TempEnchant1, mainID, {
      default = { r = .2, g = .2, b = .2 },
      borderMin = 0, glowMin = 2,
    })
    SetVisualColor(TempEnchant2, offID, {
      default = { r = .2, g = .2, b = .2 },
      borderMin = 0, glowMin = 2,
    })
    if TempEnchant1Border then TempEnchant1Border:SetAlpha(0) end
    if TempEnchant2Border then TempEnchant2Border:SetAlpha(0) end
  end

  local function RefreshMerchant()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    if MerchantFrame.selectedTab == 1 then
      local page = MerchantFrame.page or 1
      local perPage = MERCHANT_ITEMS_PER_PAGE or 10
      local startIndex = (page - 1) * perPage + 1

      for i = 1, perPage do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
          local index = startIndex + i - 1
          local itemID
          if index <= GetMerchantNumItems() then itemID = API.GetMerchantItemID(index) end
          SetVisualColor(button, itemID, { borderMin = 2, glowMin = 2, defaultAlpha = 0 })
        end
      end

      local buybackButton = _G["MerchantBuyBackItemItemButton"]
      if buybackButton then
        local count = GetNumBuybackItems()
        local itemID = count > 0 and API.GetBuybackItemID(count) or nil
        SetVisualColor(buybackButton, itemID, { borderMin = 2, glowMin = 2, defaultAlpha = 0 })
      end
    else
      local perPage = MERCHANT_ITEMS_PER_PAGE or 10
      for i = 1, perPage do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
          SetVisualColor(button, API.GetBuybackItemID(i), {
            borderMin = 2, glowMin = 2, defaultAlpha = 0,
          })
        end
      end
    end
  end

  local function QuestButtonItemID(i)
    local choices = GetNumQuestChoices() or 0
    local rewards = GetNumQuestRewards() or 0
    if i <= choices then return API.GetQuestItemID("choice", i) end
    if i <= choices + rewards then return API.GetQuestItemID("reward", i - choices) end
  end

  local function RefreshQuest()
    for i = 1, 4 do
      local itemID = QuestButtonItemID(i)

      local detail = _G["QuestDetailItem" .. i]
      local detailIcon = _G["QuestDetailItem" .. i .. "IconTexture"]
      if detail and detailIcon then
        ApplyIconButton(detail, detailIcon, itemID, {
          borderInset = 2, glowInset = 14, borderMin = 2, glowMin = 2,
          defaultAlpha = 0,
        })
      end

      local reward = _G["QuestRewardItem" .. i]
      local rewardIcon = _G["QuestRewardItem" .. i .. "IconTexture"]
      if reward and rewardIcon then
        ApplyIconButton(reward, rewardIcon, itemID, {
          borderInset = 2, glowInset = 14, borderMin = 2, glowMin = 2,
          defaultAlpha = 0,
        })
      end
    end
  end

  local function RefreshQuestLog()
    if not QuestLogFrame or not QuestLogFrame:IsShown() then return end
    for i = 1, 4 do
      local itemID = API.GetQuestLogItemID("reward", i)
        or API.GetQuestLogItemID("choice", i)
      local button = _G["QuestLogItem" .. i]
      local icon = _G["QuestLogItem" .. i .. "IconTexture"]
      if button and icon then
        ApplyIconButton(button, icon, itemID, {
          borderInset = 2, glowInset = 14, borderMin = 2, glowMin = 2,
          defaultAlpha = 0,
        })
      end
    end
  end

  local function RefreshMail()
    -- The inbox list uses seven 37x37 MailItemXButton frames. Their native
    -- slot texture is colored only by read/unread state, so apply our rarity
    -- border/glow directly to those item buttons after Blizzard refreshes them.
    if InboxFrame then
      local page = InboxFrame.pageNum or 1
      local numItems = GetInboxNumItems() or 0

      for row = 1, 7 do
        local button = _G["MailItem" .. row .. "Button"]
        local icon = _G["MailItem" .. row .. "ButtonIcon"]
        local absolute = (page - 1) * 7 + row
        local itemID

        if absolute <= numItems then
          itemID = API.GetInboxItemID(absolute)
        end

        if button and icon then
          ApplyIconButton(button, icon, itemID, {
            borderInset = 2,
            glowInset = 12,
            borderMin = 2,
            glowMin = 2,
            defaultAlpha = 0,
          })
        end
      end
    end

    -- Keep the opened-mail attachment colored as well.
    local openButton = _G.OpenMailPackageButton
    if openButton then
      local mailID = InboxFrame and InboxFrame.openMailID
      local itemID = mailID and mailID > 0 and API.GetInboxItemID(mailID) or nil
      SetVisualColor(openButton, itemID, {
        borderMin = 2, glowMin = 2, defaultAlpha = 0,
      })
    end
  end

  local function RefreshTrade()
    for i = 1, 7 do
      local player = _G["TradePlayerItem" .. i .. "ItemButton"]
      local target = _G["TradeRecipientItem" .. i .. "ItemButton"]
      if player then
        SetVisualColor(player, API.GetTradePlayerItemID(i), {
          borderMin = 2, glowMin = 2, defaultAlpha = 0,
        })
      end
      if target then
        SetVisualColor(target, API.GetTradeTargetItemID(i), {
          borderMin = 2, glowMin = 2, defaultAlpha = 0,
        })
      end
    end
  end

  local function RefreshTradeSkill()
    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end
    local id = TradeSkillFrame.selectedSkill
    if not id then return end

    local output = _G.TradeSkillSkillIcon
    if output then
      SetVisualColor(output, API.GetTradeSkillItemID(id), {
        borderMin = 2, glowMin = 2, defaultAlpha = 0,
      })
    end

    local num = GetTradeSkillNumReagents(id) or 0
    for i = 1, num do
      local button = _G["TradeSkillReagent" .. i]
      local icon = _G["TradeSkillReagent" .. i .. "IconTexture"]
      if button and icon then
        ApplyIconButton(button, icon, API.GetTradeSkillReagentItemID(id, i), {
          borderInset = 2, glowInset = 12, borderMin = 2, glowMin = 2,
          defaultAlpha = 0,
        })
      end
    end
  end

  local function RefreshCraft()
    if not CraftFrame or not CraftFrame:IsShown() then return end
    local id = GetCraftSelectionIndex()
    if not id or id <= 0 then return end

    local output = _G.CraftIcon
    if output then
      local name = GetCraftInfo(id)
      local link = name and ShaguTweaks.GetItemLinkByName and ShaguTweaks.GetItemLinkByName(name)
      local itemID = link and API.GetItemIDFromLink(link)
      SetVisualColor(output, itemID, {
        borderMin = 2, glowMin = 2, defaultAlpha = 0,
      })
    end

    local num = GetCraftNumReagents(id) or 0
    for i = 1, num do
      local button = _G["CraftReagent" .. i]
      local icon = _G["CraftReagent" .. i .. "IconTexture"]
      if button and icon then
        ApplyIconButton(button, icon, API.GetCraftReagentItemID(id, i), {
          borderInset = 2, glowInset = 12, borderMin = 2, glowMin = 2,
          defaultAlpha = 0,
        })
      end
    end
  end

  local function RefreshLoot()
    if not LootFrame or not LootFrame:IsShown() then return end
    local numLoot = GetNumLootItems() or 0
    local page = LootFrame.page or 1
    local perPage = numLoot <= 4 and 4 or 3
    local startSlot = (page - 1) * perPage + 1

    for buttonIndex = 1, 4 do
      local button = _G["LootButton" .. buttonIndex]
      local slot = startSlot + buttonIndex - 1
      local itemID = slot <= numLoot and API.GetLootSlotItemID(slot) or nil
      if button then
        SetVisualColor(button, itemID, {
          borderMin = 1, glowMin = 2, defaultAlpha = 0,
        })
      end
    end
  end

  self.RefreshAll = function()
    RefreshPaperdoll()
    RefreshWeapons()
    RefreshBags()
    if BankFrame and BankFrame:IsShown() then RefreshBank() end
    if MerchantFrame and MerchantFrame:IsShown() then RefreshMerchant() end
    if QuestFrame and QuestFrame:IsShown() then RefreshQuest() end
    if QuestLogFrame and QuestLogFrame:IsShown() then RefreshQuestLog() end
    if TradeFrame and TradeFrame:IsShown() then RefreshTrade() end
    if LootFrame and LootFrame:IsShown() then RefreshLoot() end
    if TradeSkillFrame and TradeSkillFrame:IsShown() then RefreshTradeSkill() end
    if CraftFrame and CraftFrame:IsShown() then RefreshCraft() end
  end

  local paperdoll = CreateFrame("Frame", nil, CharacterFrame)
  paperdoll:RegisterEvent("UNIT_INVENTORY_CHANGED")
  paperdoll:SetScript("OnEvent", function()
    if not arg1 or arg1 == "player" then
      RefreshPaperdoll()
      RefreshWeapons()
    end
  end)
  paperdoll:SetScript("OnShow", RefreshPaperdoll)

  HookAddonOrVariable("Blizzard_InspectUI", function()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", RefreshInspect)
    if InspectFrame then HookScript(InspectFrame, "OnShow", RefreshInspect) end
  end)

  local bags = CreateFrame("Frame", nil, ContainerFrame1)
  bags:RegisterEvent("BAG_UPDATE")
  bags:SetScript("OnEvent", function() RefreshBags(arg1) end)
  hooksecurefunc("ContainerFrame_OnShow", function()
    RefreshBags(this and this:GetID())
  end)

  local bank = CreateFrame("Frame", nil, BankFrame)
  bank:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  bank:SetScript("OnEvent", RefreshBank)
  bank:SetScript("OnShow", RefreshBank)

  local merchant = CreateFrame("Frame", nil, MerchantFrame)
  merchant:RegisterEvent("MERCHANT_SHOW")
  merchant:RegisterEvent("MERCHANT_UPDATE")
  merchant:SetScript("OnEvent", RefreshMerchant)
  hooksecurefunc("MerchantFrame_Update", RefreshMerchant)

  local quest = CreateFrame("Frame", nil, QuestFrame)
  quest:RegisterEvent("QUEST_DETAIL")
  quest:RegisterEvent("QUEST_COMPLETE")
  quest:SetScript("OnEvent", function() ShaguTweaks.QueueFunction(RefreshQuest) end)
  quest:SetScript("OnShow", function() ShaguTweaks.QueueFunction(RefreshQuest) end)

  if QuestLogFrame then
    HookScript(QuestLogFrame, "OnShow", function() ShaguTweaks.QueueFunction(RefreshQuestLog) end)
  end
  hooksecurefunc("QuestLog_Update", RefreshQuestLog)

  if MailFrame then
    HookScript(MailFrame, "OnShow", function()
      ShaguTweaks.QueueFunction(RefreshMail)
    end)
  end

  -- These native refresh functions already run for inbox changes, page changes
  -- and opening a message. Post-hook them so rarity state always wins after
  -- Blizzard has updated the reused mail buttons.
  hooksecurefunc("InboxFrame_Update", RefreshMail)
  hooksecurefunc("OpenMail_Update", RefreshMail)

  local trade = CreateFrame("Frame", nil, TradeFrame)
  trade:RegisterEvent("TRADE_SHOW")
  trade:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
  trade:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
  trade:SetScript("OnEvent", RefreshTrade)

  HookAddonOrVariable("Blizzard_TradeSkillUI", function()
    hooksecurefunc("TradeSkillFrame_Update", RefreshTradeSkill)
    if TradeSkillFrame then HookScript(TradeSkillFrame, "OnShow", RefreshTradeSkill) end
  end)

  HookAddonOrVariable("Blizzard_CraftUI", function()
    hooksecurefunc("CraftFrame_Update", RefreshCraft)
    if CraftFrame then HookScript(CraftFrame, "OnShow", RefreshCraft) end
  end)

  local loot = CreateFrame("Frame", nil, LootFrame)
  loot:RegisterEvent("LOOT_OPENED")
  loot:RegisterEvent("LOOT_SLOT_CLEARED")
  loot:RegisterEvent("LOOT_CLOSED")
  loot:SetScript("OnEvent", function()
    if event == "LOOT_CLOSED" then
      for i = 1, 4 do
        local button = _G["LootButton" .. i]
        if button then SetVisualColor(button, nil, { borderMin = 1, glowMin = 2, defaultAlpha = 0 }) end
      end
    else
      ShaguTweaks.QueueFunction(RefreshLoot)
    end
  end)
  hooksecurefunc("LootFrame_Update", RefreshLoot)

  self:RefreshAll()
end

borderModule.enable = function(self)
  Engine.borders = true
  Engine:Install()
  if Engine.RefreshAll then Engine:RefreshAll() end
end

glowModule.enable = function(self)
  Engine.glows = true
  Engine:Install()
  if Engine.RefreshAll then Engine:RefreshAll() end
end
