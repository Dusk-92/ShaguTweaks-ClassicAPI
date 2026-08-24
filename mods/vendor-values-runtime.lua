local T = ShaguTweaks.T
local GetItemLinkByName = ShaguTweaks.GetItemLinkByName
local GetItemIDFromLink = ShaguTweaks.GetItemIDFromLink

-- Runtime replacement for Vendor Values.
-- vendor-values.lua still owns the sell-price database and exports it as
-- ShaguTweaks.SellValueDB. Registering the same module title here replaces only
-- the old tooltip runtime without duplicating the large database.
local module = ShaguTweaks:register({
  title = T["Vendor Values"],
  description = T["Shows the vendor sell values on all item tooltips."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local function AddVendorPrices(frame, id, count)
  local price = id and ShaguTweaks.SellValueDB and ShaguTweaks.SellValueDB[id]
  count = math.max(tonumber(count) or 1, 1)

  if price and price > 0 then
    SetTooltipMoney(frame, price * count)
    frame:Show()
  end
end

local function AddVendorPriceFromLink(frame, link, count, ignoreMerchant)
  if not link then return end
  if not ignoreMerchant and MerchantFrame:IsShown() then return end

  local itemID = GetItemIDFromLink(link)
  if itemID then
    AddVendorPrices(frame, itemID, count)
  end
end

module.enable = function(self)
  -- Some native tooltip setters call SetHyperlink internally. Track nesting so
  -- each item gets exactly one vendor-price line.
  local setterDepth = 0

  local HookSetHyperlink = GameTooltip.SetHyperlink
  function GameTooltip.SetHyperlink(self, link)
    local result = HookSetHyperlink(self, link)
    if setterDepth == 0 then
      AddVendorPriceFromLink(self, link, 1, true)
    end
    return result
  end

  local HookSetItemRef = SetItemRef
  SetItemRef = function(link, text, button)
    local itemID = GetItemIDFromLink(link)
    local result = HookSetItemRef(link, text, button)
    if not IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown() and itemID then
      AddVendorPrices(ItemRefTooltip, itemID, 1)
    end
    return result
  end

  local HookSetBagItem = GameTooltip.SetBagItem
  function GameTooltip.SetBagItem(self, container, slot)
    local itemLink = GetContainerItemLink(container, slot)
    local _, itemCount = GetContainerItemInfo(container, slot)
    setterDepth = setterDepth + 1
    local result = HookSetBagItem(self, container, slot)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, itemCount, false)
    return result
  end

  local HookSetQuestLogItem = GameTooltip.SetQuestLogItem
  function GameTooltip.SetQuestLogItem(self, itemType, index)
    local itemLink = GetQuestLogItemLink(itemType, index)
    setterDepth = setterDepth + 1
    local result = HookSetQuestLogItem(self, itemType, index)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetQuestItem = GameTooltip.SetQuestItem
  function GameTooltip.SetQuestItem(self, itemType, index)
    local itemLink = GetQuestItemLink(itemType, index)
    setterDepth = setterDepth + 1
    local result = HookSetQuestItem(self, itemType, index)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetLootItem = GameTooltip.SetLootItem
  function GameTooltip.SetLootItem(self, slot)
    local itemLink = GetLootSlotLink(slot)
    setterDepth = setterDepth + 1
    local result = HookSetLootItem(self, slot)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetInboxItem = GameTooltip.SetInboxItem
  function GameTooltip.SetInboxItem(self, mailID, attachmentIndex)
    local itemName, _, itemCount = GetInboxItem(mailID, attachmentIndex)
    local itemLink = itemName and GetItemLinkByName(itemName)
    setterDepth = setterDepth + 1
    local result = HookSetInboxItem(self, mailID, attachmentIndex)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, itemCount, true)
    return result
  end

  local HookSetInventoryItem = GameTooltip.SetInventoryItem
  function GameTooltip.SetInventoryItem(self, unit, slot)
    local itemLink = GetInventoryItemLink(unit, slot)
    setterDepth = setterDepth + 1
    local result = HookSetInventoryItem(self, unit, slot)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetLootRollItem = GameTooltip.SetLootRollItem
  function GameTooltip.SetLootRollItem(self, id)
    local itemLink = GetLootRollItemLink(id)
    setterDepth = setterDepth + 1
    local result = HookSetLootRollItem(self, id)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetMerchantItem = GameTooltip.SetMerchantItem
  function GameTooltip.SetMerchantItem(self, merchantIndex)
    local itemLink = GetMerchantItemLink(merchantIndex)
    setterDepth = setterDepth + 1
    local result = HookSetMerchantItem(self, merchantIndex)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, false)
    return result
  end

  local HookSetCraftItem = GameTooltip.SetCraftItem
  function GameTooltip.SetCraftItem(self, skill, slot)
    local itemLink = GetCraftReagentItemLink(skill, slot)
    setterDepth = setterDepth + 1
    local result = HookSetCraftItem(self, skill, slot)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetCraftSpell = GameTooltip.SetCraftSpell
  function GameTooltip.SetCraftSpell(self, slot)
    local itemLink = GetCraftItemLink(slot)
    setterDepth = setterDepth + 1
    local result = HookSetCraftSpell(self, slot)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetTradeSkillItem = GameTooltip.SetTradeSkillItem
  function GameTooltip.SetTradeSkillItem(self, skillIndex, reagentIndex)
    local itemLink
    if reagentIndex then
      itemLink = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
    else
      itemLink = GetTradeSkillItemLink(skillIndex)
    end

    setterDepth = setterDepth + 1
    local result = HookSetTradeSkillItem(self, skillIndex, reagentIndex)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetAuctionItem = GameTooltip.SetAuctionItem
  function GameTooltip.SetAuctionItem(self, atype, index)
    local _, _, itemCount = GetAuctionItemInfo(atype, index)
    local itemLink = GetAuctionItemLink(atype, index)
    setterDepth = setterDepth + 1
    local result = HookSetAuctionItem(self, atype, index)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, itemCount, true)
    return result
  end

  local HookSetAuctionSellItem = GameTooltip.SetAuctionSellItem
  function GameTooltip.SetAuctionSellItem(self)
    local itemName, _, itemCount = GetAuctionSellItemInfo()
    local itemLink = itemName and GetItemLinkByName(itemName)
    setterDepth = setterDepth + 1
    local result = HookSetAuctionSellItem(self)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, itemCount, true)
    return result
  end

  local HookSetTradePlayerItem = GameTooltip.SetTradePlayerItem
  function GameTooltip.SetTradePlayerItem(self, index)
    local itemLink = GetTradePlayerItemLink(index)
    setterDepth = setterDepth + 1
    local result = HookSetTradePlayerItem(self, index)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end

  local HookSetTradeTargetItem = GameTooltip.SetTradeTargetItem
  function GameTooltip.SetTradeTargetItem(self, index)
    local itemLink = GetTradeTargetItemLink(index)
    setterDepth = setterDepth + 1
    local result = HookSetTradeTargetItem(self, index)
    setterDepth = setterDepth - 1
    AddVendorPriceFromLink(self, itemLink, 1, true)
    return result
  end
end
