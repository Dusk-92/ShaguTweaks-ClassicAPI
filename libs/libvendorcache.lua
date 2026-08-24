local _G = ShaguTweaks.GetGlobalEnv()
local API = ShaguTweaks.API

if not API then return end

local function GetVendorPriceCache()
  _G.ShaguTweaks_vendor_prices = _G.ShaguTweaks_vendor_prices or {}

  -- Migrate prices learned by the first Phase 2 implementation.
  if _G.ShaguTweaks_cache and type(_G.ShaguTweaks_cache["vendor_prices"]) == "table" then
    for itemID, price in pairs(_G.ShaguTweaks_cache["vendor_prices"]) do
      if type(itemID) == "number" and type(price) == "number" and price > 0 and
        not _G.ShaguTweaks_vendor_prices[itemID] then
        _G.ShaguTweaks_vendor_prices[itemID] = price
      end
    end

    _G.ShaguTweaks_cache["vendor_prices"] = nil
  end

  return _G.ShaguTweaks_vendor_prices
end

local function GetLiveVendorPrice(itemID)
  if type(itemID) ~= "number" then return end

  local citem = _G.C_Item
  local getter = citem and citem.GetItemSellPriceByID
  if type(getter) == "function" then
    API.itemprice = true
    return getter(itemID)
  end
end

API.GetItemSellPriceByID = GetLiveVendorPrice

local function StoreVendorPrice(itemID, price)
  if type(itemID) ~= "number" or type(price) ~= "number" or price <= 0 then return end

  local learned = GetVendorPriceCache()
  local legacy = ShaguTweaks.SellValueLegacyDB or ShaguTweaks.SellValueDB
  local legacyPrice = legacy and legacy[itemID]

  -- Only persist values that add something to the bundled static database.
  if not legacyPrice or legacyPrice ~= price then
    learned[itemID] = price
  else
    learned[itemID] = nil
  end

  -- Make the learned value available immediately during this session too.
  if ShaguTweaks.SellValueLegacyDB and ShaguTweaks.SellValueDB then
    rawset(ShaguTweaks.SellValueDB, itemID, price)
  end

  return price
end

API.StoreVendorPrice = StoreVendorPrice

API.RememberVendorPrice = function(itemID)
  local price = GetLiveVendorPrice(itemID)
  if price and price > 0 then
    return StoreVendorPrice(itemID, price)
  end
end

-- Always install the Vendor Values proxy, even if ClassicAPI's C_Item table is
-- not ready yet during VARIABLES_LOADED. Learned prices must still survive and
-- work after /reload; live ClassicAPI availability is checked dynamically.
API.PrepareVendorValues = function()
  if not ShaguTweaks.SellValueDB or ShaguTweaks.SellValueLegacyDB then return end

  local legacy = ShaguTweaks.SellValueDB
  local learned = GetVendorPriceCache()
  local live = {}

  setmetatable(live, {
    __index = function(tab, itemID)
      if type(itemID) ~= "number" then
        return legacy[itemID]
      end

      local price = GetLiveVendorPrice(itemID)
      if price and price > 0 then
        StoreVendorPrice(itemID, price)
        rawset(tab, itemID, price)
        return price
      end

      local remembered = learned[itemID]
      if remembered and remembered > 0 then
        return remembered
      end

      return legacy[itemID]
    end
  })

  ShaguTweaks.SellValueLegacyDB = legacy
  ShaguTweaks.SellValueDB = live

  if API.vendorprice_tooltip_hooks then return end
  API.vendorprice_tooltip_hooks = true

  -- Vendor Values suppresses its own price while a merchant is open because the
  -- default UI already displays the real sell value. Learn that native value
  -- from the player's bag tooltip so new Turtle items persist afterwards.
  ShaguTweaks.hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, container, slot)
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    local link = GetContainerItemLink(container, slot)
    local itemID = link and ShaguTweaks.GetItemIDFromLink(link)
    if not itemID then return end

    -- Prefer the item-record value whenever ClassicAPI already knows it.
    if API.RememberVendorPrice(itemID) then return end

    local _, count = GetContainerItemInfo(container, slot)
    count = tonumber(count) or 1
    if count < 1 then count = 1 end

    local tooltipName = tooltip and tooltip:GetName()
    local moneyFrame = tooltipName and _G[tooltipName .. "MoneyFrame1"]
    local stackPrice = moneyFrame and moneyFrame:IsShown() and tonumber(moneyFrame.staticMoney)
    if not stackPrice or stackPrice <= 0 then return end

    local unitPrice = floor(stackPrice / count)
    if unitPrice > 0 and unitPrice * count == stackPrice then
      StoreVendorPrice(itemID, unitPrice)
    end
  end)
end
