local API = ShaguTweaks.API

-- Keep the original static database as an immediate compatibility fallback.
-- ClassicAPI's live item cache is authoritative when it has the item record,
-- which also covers Turtle/custom items and server-side price changes.
if not API or not API.itemprice or not ShaguTweaks.SellValueDB then return end

local legacy = ShaguTweaks.SellValueDB
local live = {}

setmetatable(live, {
  __index = function(tab, itemID)
    if type(itemID) ~= "number" then
      return legacy[itemID]
    end

    local price = API.GetItemSellPriceByID(itemID)
    if price ~= nil then
      -- Vendor values don't change during a session. Cache successful reads so
      -- the tooltip's repeated lookups stay pure Lua after the first hit.
      rawset(tab, itemID, price)
      return price
    end

    -- An uncached item is warmed by ClassicAPI in the background. Use the old
    -- database now; a later tooltip lookup will transparently pick up live data.
    return legacy[itemID]
  end
})

ShaguTweaks.SellValueLegacyDB = legacy
ShaguTweaks.SellValueDB = live
