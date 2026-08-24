local _G = ShaguTweaks.GetGlobalEnv()
local API = ShaguTweaks.API

if not API then return end

local pending = {}

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

  pending[itemID] = nil

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

-- ClassicAPI explicitly documents that a cache miss warms the item cache and
-- GET_ITEM_INFO_RECEIVED(itemID, success) fires when that implicit load ends.
-- Keep only merchant-hovered item IDs pending, then persist the price exactly
-- when ClassicAPI says the item record is ready. No polling or permanent
-- OnUpdate is needed.
local itemWatcher = CreateFrame("Frame")
itemWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemWatcher:SetScript("OnEvent", function()
  local itemID = tonumber(arg1)
  if not itemID or not pending[itemID] then return end

  local price = GetLiveVendorPrice(itemID)
  if price and price > 0 then
    StoreVendorPrice(itemID, price)
  elseif arg2 == false or arg2 == 0 then
    -- Definitive failed item query: don't keep a dead pending entry forever.
    pending[itemID] = nil
  end
end)

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
  -- default UI already displays the real sell value. Hovering a bag item here
  -- marks it for persistence. If ClassicAPI has the value immediately, save it;
  -- otherwise GET_ITEM_INFO_RECEIVED finishes the job asynchronously.
  ShaguTweaks.hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, container, slot)
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    local link = GetContainerItemLink(container, slot)
    local itemID = link and ShaguTweaks.GetItemIDFromLink(link)
    if not itemID then return end

    pending[itemID] = true

    -- This also starts ClassicAPI's implicit cache warmup on a miss.
    if API.RememberVendorPrice(itemID) then return end

    -- Immediate Vanilla tooltip fallback. This is useful if the native UI has
    -- already populated the sell price before ClassicAPI's item record arrives.
    local _, count = GetContainerItemInfo(container, slot)
    count = tonumber(count) or 1
    if count < 1 then count = 1 end

    local tooltipName = tooltip and tooltip:GetName()
    if not tooltipName then return end

    local moneyFrame = _G[tooltipName .. "MoneyFrame"] or _G[tooltipName .. "MoneyFrame1"]
    local stackPrice = moneyFrame and moneyFrame:IsShown() and tonumber(moneyFrame.staticMoney)
    if not stackPrice or stackPrice <= 0 then return end

    local unitPrice = floor(stackPrice / count)
    if unitPrice > 0 and unitPrice * count == stackPrice then
      StoreVendorPrice(itemID, unitPrice)
    end
  end)
end
