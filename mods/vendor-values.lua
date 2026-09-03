local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local GetItemIDFromLink = ShaguTweaks.GetItemIDFromLink
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Vendor Values"],
  description = T["Shows the vendor sell values on all item tooltips."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local function GetVendorPrice(id)
  if not id then return end
  if API and API.GetItemSellPriceByID then
    return API.GetItemSellPriceByID(id)
  end
end

local pendingPrices = {}

local function ClearPending(frame)
  if frame then
    pendingPrices[frame] = nil
  end
end

local function AddVendorPrices(frame, id, count, ignoreMerchant)
  if not frame or not id then return end
  if not ignoreMerchant and MerchantFrame:IsShown() then
    ClearPending(frame)
    return
  end

  local price = GetVendorPrice(id)
  count = math.max(tonumber(count) or 1, 1)

  if price ~= nil then
    ClearPending(frame)
    if price > 0 then
      SetTooltipMoney(frame, price * count)
      frame:Show()
      return true
    end
    return
  end

  -- ClassicAPI warms uncached item records in the background. Remember the
  -- currently displayed item so GET_ITEM_INFO_RECEIVED can add its price once
  -- the record arrives, without polling or a permanent OnUpdate.
  if API and API.itemprice then
    pendingPrices[frame] = {
      itemID = id,
      count = count,
      ignoreMerchant = ignoreMerchant,
    }
  end
end

local function AddVendorPriceFromLink(frame, link, count, ignoreMerchant)
  if not link then return end
  AddVendorPrices(frame, GetItemIDFromLink(link), count, ignoreMerchant)
end

module.enable = function(self)
  -- Refresh a still-visible tooltip when ClassicAPI finishes warming an item
  -- record. The handler does no work unless a tooltip actually has a pending
  -- uncached item.
  if API and API.eventutils and _G.C_EventUtils
    and _G.C_EventUtils.IsEventValid("GET_ITEM_INFO_RECEIVED") then
    local priceEvents = CreateFrame("Frame")
    priceEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    priceEvents:SetScript("OnEvent", function()
      for frame, pending in pairs(pendingPrices) do
        if not frame:IsShown() then
          pendingPrices[frame] = nil
        elseif pending.itemID == arg1 then
          AddVendorPrices(frame, pending.itemID, pending.count,
            pending.ignoreMerchant)
        end
      end
    end)
  end

  -- Every tooltip setter is described once here. Prefer ClassicAPI's direct
  -- item IDs; link parsing remains only as a cold compatibility path inside
  -- api.lua or for SetHyperlink/SetCraftSpell where a link is the natural API.
  local fill = {
    SetHyperlink = function(self, link)
      return nil, 1, true, link
    end,

    SetBagItem = function(self, container, slot)
      if container == -1 and BankButtonIDToInvSlotID then
        local invSlot = BankButtonIDToInvSlotID(slot)
        local itemID = invSlot and API.GetInventoryItemID("player", invSlot)
        local count = invSlot and GetInventoryItemCount("player", invSlot)
        return itemID, count, false
      end

      return API.GetContainerItemID(container, slot),
        API.GetContainerItemStackCount(container, slot), false
    end,

    SetQuestLogItem = function(self, itemType, index)
      return API.GetQuestLogItemID(itemType, index), 1, true
    end,

    SetQuestItem = function(self, itemType, index)
      return API.GetQuestItemID(itemType, index), 1, true
    end,

    SetLootItem = function(self, slot)
      return API.GetLootSlotItemID(slot), 1, true
    end,

    SetInboxItem = function(self, mailID, attachmentIndex)
      local _, _, count = GetInboxItem(mailID, attachmentIndex)
      return API.GetInboxItemID(mailID), count, true
    end,

    SetInventoryItem = function(self, unit, slot)
      return API.GetInventoryItemID(unit, slot), 1, true
    end,

    SetLootRollItem = function(self, rollID)
      return API.GetLootRollItemID(rollID), 1, true
    end,

    SetMerchantItem = function(self, merchantIndex)
      return API.GetMerchantItemID(merchantIndex), 1, false
    end,

    SetCraftItem = function(self, skill, slot)
      return API.GetCraftReagentItemID(skill, slot), 1, true
    end,

    SetCraftSpell = function(self, slot)
      return nil, 1, true, GetCraftItemLink(slot)
    end,

    SetTradeSkillItem = function(self, skillIndex, reagentIndex)
      if reagentIndex then
        return API.GetTradeSkillReagentItemID(skillIndex, reagentIndex), 1, true
      end
      return API.GetTradeSkillItemID(skillIndex), 1, true
    end,

    SetAuctionItem = function(self, atype, index)
      local _, _, count = GetAuctionItemInfo(atype, index)
      return API.GetAuctionItemID(atype, index), count, true
    end,

    SetAuctionSellItem = function(self)
      local _, _, count = GetAuctionSellItemInfo()
      return API.GetAuctionSellItemID(), count, true
    end,

    SetTradePlayerItem = function(self, index)
      return API.GetTradePlayerItemID(index), 1, true
    end,

    SetTradeTargetItem = function(self, index)
      return API.GetTradeTargetItemID(index), 1, true
    end,
  }

  local installed = {}
  local fillDepth = 0
  local context

  local function Capture(prepare, frame, a1, a2, a3)
    local itemID, count, ignoreMerchant, link = prepare(frame, a1, a2, a3)
    context = context or {}

    if itemID and not context.itemID then context.itemID = itemID end
    if link and not context.link then context.link = link end
    if context.count == nil and count ~= nil then context.count = count end
    if context.ignoreMerchant == nil and ignoreMerchant ~= nil then
      context.ignoreMerchant = ignoreMerchant
    end
  end

  local function InstallTooltipHooks()
    for method, prepare in pairs(fill) do
      -- Lua 5.0 shares generic-for control variables between closures. Keep
      -- body locals so each wrapper captures the correct method and callback.
      local method = method
      local prepare = prepare
      local original = GameTooltip[method]

      -- A load-on-demand bag/UI addon may replace a setter after ShaguTweaks
      -- initialized. Wrap that new outer setter while keeping the old captured
      -- call chain intact. fillDepth prevents duplicate vendor-price lines.
      if type(original) == "function" and original ~= installed[method] then
        local wrapper = function(frame, a1, a2, a3)
          local outer = fillDepth == 0
          if outer then context = {} end

          -- If an outer virtual bag method cannot identify an item, allow a
          -- nested real SetInventoryItem/SetHyperlink call to provide it.
          if outer or (context and not context.itemID and not context.link) then
            Capture(prepare, frame, a1, a2, a3)
          end

          fillDepth = fillDepth + 1
          local ok, r1, r2, r3, r4 = pcall(original, frame, a1, a2, a3)
          fillDepth = fillDepth - 1

          if outer then
            local captured = context
            context = nil

            if ok and captured then
              if captured.itemID then
                AddVendorPrices(frame, captured.itemID, captured.count,
                  captured.ignoreMerchant)
              elseif captured.link then
                AddVendorPriceFromLink(frame, captured.link, captured.count,
                  captured.ignoreMerchant)
              end
            end
          end

          if not ok then error(r1) end
          return r1, r2, r3, r4
        end

        installed[method] = wrapper
        GameTooltip[method] = wrapper
      end
    end
  end

  -- SetItemRef is global rather than a GameTooltip method. Keep the same
  -- late-replacement protection without introducing a second shared helper.
  local installedItemRef
  local itemRefDepth = 0

  local function InstallItemRefHook()
    local original = _G.SetItemRef
    if type(original) ~= "function" or original == installedItemRef then return end

    local wrapper = function(link, text, button)
      local outer = itemRefDepth == 0
      local itemID = outer and GetItemIDFromLink(link) or nil

      itemRefDepth = itemRefDepth + 1
      local ok, r1, r2, r3, r4 = pcall(original, link, text, button)
      itemRefDepth = itemRefDepth - 1

      if ok and outer and itemID
        and not API.IsAltKeyDown()
        and not API.IsShiftKeyDown()
        and not API.IsControlKeyDown() then
        AddVendorPrices(ItemRefTooltip, itemID, 1, true)
      end

      if not ok then error(r1) end
      return r1, r2, r3, r4
    end

    installedItemRef = wrapper
    _G.SetItemRef = wrapper
  end

  InstallTooltipHooks()
  InstallItemRefHook()

  -- Re-check after load-on-demand UI addons install their own tooltip wrappers.
  -- The one-shot next-frame pass handles event registration order without a
  -- permanent OnUpdate.
  local hookwatch = CreateFrame("Frame")
  local rehook = CreateFrame("Frame")
  rehook:SetScript("OnUpdate", nil)

  local function ScheduleRehook()
    if rehook:GetScript("OnUpdate") then return end
    rehook:SetScript("OnUpdate", function()
      this:SetScript("OnUpdate", nil)
      InstallTooltipHooks()
      InstallItemRefHook()
    end)
  end

  hookwatch:RegisterEvent("ADDON_LOADED")
  hookwatch:RegisterEvent("PLAYER_LOGIN")
  hookwatch:RegisterEvent("PLAYER_ENTERING_WORLD")
  hookwatch:SetScript("OnEvent", function()
    InstallTooltipHooks()
    InstallItemRefHook()
    ScheduleRehook()
  end)
end
