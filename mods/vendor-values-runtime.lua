local T = ShaguTweaks.T
local GetItemIDFromLink = ShaguTweaks.GetItemIDFromLink

-- Runtime replacement for Vendor Values.
-- vendor-values.lua still owns the static sell-price database and exports it as
-- ShaguTweaks.SellValueDB. This runtime prefers ClassicAPI's direct item-ID and
-- sell-price APIs, then falls back to the static database / legacy links.
local module = ShaguTweaks:register({
  title = T["Vendor Values"],
  description = T["Shows the vendor sell values on all item tooltips."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local function GetVendorPrice(id)
  if not id then return end

  -- ClassicAPI reads m_sellPrice directly from the live item cache. This is
  -- preferable on Turtle WoW because custom items are not always reliable when
  -- their ID has to be recovered by parsing a legacy item link.
  if C_Item and C_Item.GetItemSellPriceByID then
    local price = C_Item.GetItemSellPriceByID(id)
    if price ~= nil then
      return price
    end
  end

  return ShaguTweaks.SellValueDB and ShaguTweaks.SellValueDB[id]
end

local function AddVendorPrices(frame, id, count, ignoreMerchant)
  if not id then return end
  if not ignoreMerchant and MerchantFrame:IsShown() then return end

  local price = GetVendorPrice(id)
  count = math.max(tonumber(count) or 1, 1)

  if price and price > 0 then
    SetTooltipMoney(frame, price * count)
    frame:Show()
  end
end

local function AddVendorPriceFromLink(frame, link, count, ignoreMerchant)
  if not link then return end
  AddVendorPrices(frame, GetItemIDFromLink(link), count, ignoreMerchant)
end

local function GetBagItemID(container, slot)
  if C_Container and C_Container.GetContainerItemID then
    local id = C_Container.GetContainerItemID(container, slot)
    if id then return id end
  end
  return GetItemIDFromLink(GetContainerItemLink(container, slot))
end

local function GetInventoryID(unit, slot)
  if GetInventoryItemID then
    local id = GetInventoryItemID(unit, slot)
    if id then return id end
  end
  return GetItemIDFromLink(GetInventoryItemLink(unit, slot))
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
      AddVendorPrices(ItemRefTooltip, itemID, 1, true)
    end
    return result
  end

  local HookSetBagItem = GameTooltip.SetBagItem
  function GameTooltip.SetBagItem(self, container, slot)
    local itemID = GetBagItemID(container, slot)
    local _, itemCount = GetContainerItemInfo(container, slot)
    setterDepth = setterDepth + 1
    local result = HookSetBagItem(self, container, slot)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, itemCount, false)
    return result
  end

  local HookSetQuestLogItem = GameTooltip.SetQuestLogItem
  function GameTooltip.SetQuestLogItem(self, itemType, index)
    local itemID
    if GetQuestLogItemID then itemID = GetQuestLogItemID(itemType, index) end
    if not itemID then itemID = GetItemIDFromLink(GetQuestLogItemLink(itemType, index)) end
    setterDepth = setterDepth + 1
    local result = HookSetQuestLogItem(self, itemType, index)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end

  local HookSetQuestItem = GameTooltip.SetQuestItem
  function GameTooltip.SetQuestItem(self, itemType, index)
    local itemID
    if GetQuestItemID then itemID = GetQuestItemID(itemType, index) end
    if not itemID then itemID = GetItemIDFromLink(GetQuestItemLink(itemType, index)) end
    setterDepth = setterDepth + 1
    local result = HookSetQuestItem(self, itemType, index)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end

  local HookSetLootItem = GameTooltip.SetLootItem
  function GameTooltip.SetLootItem(self, slot)
    local itemID
    if GetLootSlotItemID then itemID = GetLootSlotItemID(slot) end
    if not itemID then itemID = GetItemIDFromLink(GetLootSlotLink(slot)) end
    setterDepth = setterDepth + 1
    local result = HookSetLootItem(self, slot)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end

  local HookSetInboxItem = GameTooltip.SetInboxItem
  function GameTooltip.SetInboxItem(self, mailID, attachmentIndex)
    local _, _, itemCount = GetInboxItem(mailID, attachmentIndex)
    local itemID
    if GetInboxItemID then itemID = GetInboxItemID(mailID) end
    setterDepth = setterDepth + 1
    local result = HookSetInboxItem(self, mailID, attachmentIndex)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, itemCount, true)
    return result
  end

  local HookSetInventoryItem = GameTooltip.SetInventoryItem
  function GameTooltip.SetInventoryItem(self, unit, slot)
    local itemID = GetInventoryID(unit, slot)
    setterDepth = setterDepth + 1
    local result = HookSetInventoryItem(self, unit, slot)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end

  local HookSetLootRollItem = GameTooltip.SetLootRollItem
  function GameTooltip.SetLootRollItem(self, id)
    local itemID
    if GetLootRollItemID then itemID = GetLootRollItemID(id) end
    if not itemID then itemID = GetItemIDFromLink(GetLootRollItemLink(id)) end
    setterDepth = setterDepth + 1
    local result = HookSetLootRollItem(self, id)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end

  local HookSetMerchantItem = GameTooltip.SetMerchantItem
  function GameTooltip.SetMerchantItem(self, merchantIndex)
    local itemID
    if GetMerchantItemID then itemID = GetMerchantItemID(merchantIndex) end
    if not itemID then itemID = GetItemIDFromLink(GetMerchantItemLink(merchantIndex)) end
    setterDepth = setterDepth + 1
    local result = HookSetMerchantItem(self, merchantIndex)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, false)
    return result
  end

  local HookSetCraftItem = GameTooltip.SetCraftItem
  function GameTooltip.SetCraftItem(self, skill, slot)
    local itemID
    if GetCraftReagentItemID then itemID = GetCraftReagentItemID(skill, slot) end
    if not itemID then itemID = GetItemIDFromLink(GetCraftReagentItemLink(skill, slot)) end
    setterDepth = setterDepth + 1
    local result = HookSetCraftItem(self, skill, slot)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
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
    local itemID
    if reagentIndex then
      if GetTradeSkillReagentItemID then itemID = GetTradeSkillReagentItemID(skillIndex, reagentIndex) end
      if not itemID then itemID = GetItemIDFromLink(GetTradeSkillReagentItemLink(skillIndex, reagentIndex)) end
    else
      if GetTradeSkillItemID then itemID = GetTradeSkillItemID(skillIndex) end
      if not itemID then itemID = GetItemIDFromLink(GetTradeSkillItemLink(skillIndex)) end
    end

    setterDepth = setterDepth + 1
    local result = HookSetTradeSkillItem(self, skillIndex, reagentIndex)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end

  local HookSetAuctionItem = GameTooltip.SetAuctionItem
  function GameTooltip.SetAuctionItem(self, atype, index)
    local _, _, itemCount = GetAuctionItemInfo(atype, index)
    local itemID
    if GetAuctionItemID then itemID = GetAuctionItemID(atype, index) end
    if not itemID then itemID = GetItemIDFromLink(GetAuctionItemLink(atype, index)) end
    setterDepth = setterDepth + 1
    local result = HookSetAuctionItem(self, atype, index)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, itemCount, true)
    return result
  end

  local HookSetAuctionSellItem = GameTooltip.SetAuctionSellItem
  function GameTooltip.SetAuctionSellItem(self)
    local _, _, itemCount = GetAuctionSellItemInfo()
    local itemID
    if GetAuctionSellItemID then itemID = GetAuctionSellItemID() end
    setterDepth = setterDepth + 1
    local result = HookSetAuctionSellItem(self)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, itemCount, true)
    return result
  end

  local HookSetTradePlayerItem = GameTooltip.SetTradePlayerItem
  function GameTooltip.SetTradePlayerItem(self, index)
    local itemID
    if GetTradePlayerItemID then itemID = GetTradePlayerItemID(index) end
    if not itemID then itemID = GetItemIDFromLink(GetTradePlayerItemLink(index)) end
    setterDepth = setterDepth + 1
    local result = HookSetTradePlayerItem(self, index)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end

  local HookSetTradeTargetItem = GameTooltip.SetTradeTargetItem
  function GameTooltip.SetTradeTargetItem(self, index)
    local itemID
    if GetTradeTargetItemID then itemID = GetTradeTargetItemID(index) end
    if not itemID then itemID = GetItemIDFromLink(GetTradeTargetItemLink(index)) end
    setterDepth = setterDepth + 1
    local result = HookSetTradeTargetItem(self, index)
    setterDepth = setterDepth - 1
    AddVendorPrices(self, itemID, 1, true)
    return result
  end
end
