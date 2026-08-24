local _G = ShaguTweaks.GetGlobalEnv()

-- Central capability layer for ClassicAPI / SuperWoW integration.
-- Keep feature checks here so individual modules don't scatter DLL-specific
-- detection logic all over the codebase.
ShaguTweaks.API = ShaguTweaks.API or {}
local API = ShaguTweaks.API

API.classicapi_version = tonumber(_G.CLASSIC_API_VERSION) or 0
API.classicapi = type(_G.C_NamePlate) == "table"
  or type(_G.C_Spell) == "table"
  or type(_G.C_UnitAuras) == "table"
  or type(_G.UnitGUID) == "function"

API.nameplates = type(_G.C_NamePlate) == "table"
  and type(_G.C_NamePlate.GetNamePlateForUnit) == "function"

API.casts = type(_G.C_Spell) == "table"
  and type(_G.C_Spell.UnitCastingInfo) == "function"
  and type(_G.C_Spell.UnitChannelInfo) == "function"

API.auras = type(_G.C_UnitAuras) == "table"
  and type(_G.C_UnitAuras.GetAuraDataByIndex) == "function"
  and type(_G.C_UnitAuras.GetDebuffDataByIndex) == "function"

API.spellinfo = type(_G.GetSpellInfo) == "function"

API.inventory = type(_G.C_Container) == "table"
  and type(_G.C_Container.GetContainerNumFreeSlots) == "function"

API.itemprice = type(_G.C_Item) == "table"
  and type(_G.C_Item.GetItemSellPriceByID) == "function"

API.merchant = type(_G.C_MerchantFrame) == "table"
  and type(_G.C_MerchantFrame.GetNumJunkItems) == "function"
  and type(_G.C_MerchantFrame.SellAllJunkItems) == "function"

API.playerstate = type(_G.IsMounted) == "function"
  and type(_G.Dismount) == "function"
  and type(_G.GetShapeshiftFormID) == "function"
  and type(_G.CancelShapeshiftForm) == "function"

API.unitguid = type(_G.UnitGUID) == "function"

API.chatidentity = type(_G.GetCurrentChatGUID) == "function"
  and type(_G.GetPlayerInfoByGUID) == "function"

API.playercache = type(_G.C_PlayerCache) == "table"
  and type(_G.C_PlayerCache.GetPlayerInfoByName) == "function"

-- SuperWoW remains optional. It can still provide useful extra cast/GUID
-- information, but ClassicAPI is the primary compatibility layer.
API.superwow = type(_G.SpellInfo) == "function"
  and type(_G.CombatLogAdd) == "function"

API.GetNamePlateForUnit = function(unit)
  if API.nameplates then
    return _G.C_NamePlate.GetNamePlateForUnit(unit)
  end
end

API.UnitCastingInfo = function(unit)
  if API.casts then
    return _G.C_Spell.UnitCastingInfo(unit)
  end
end

API.UnitChannelInfo = function(unit)
  if API.casts then
    return _G.C_Spell.UnitChannelInfo(unit)
  end
end

-- ShaguTweaks' castbar modules use the old 1.12-compatible seven-value shape.
-- Keep that public shape while sourcing the data from ClassicAPI first.
API.GetCastInfo = function(unit)
  if not API.casts then return end

  local name, displayName, texture, startTime, endTime, isTradeSkill,
    castID, notInterruptible, spellID = _G.C_Spell.UnitCastingInfo(unit)

  -- Remote channels seen after they started can have metadata but no timing.
  -- Castbars require start/end times, so only expose complete timing data here.
  if not name or not startTime or not endTime then return end

  return name, "", displayName or "", texture, startTime, endTime,
    isTradeSkill, castID, notInterruptible, spellID
end

API.GetChannelInfo = function(unit)
  if not API.casts then return end

  local name, displayName, texture, startTime, endTime, isTradeSkill,
    notInterruptible, spellID = _G.C_Spell.UnitChannelInfo(unit)

  if not name or not startTime or not endTime then return end

  return name, "", displayName or "", texture, startTime, endTime,
    isTradeSkill, notInterruptible, spellID
end

API.GetAuraDataByIndex = function(unit, index, filter)
  if API.auras then
    return _G.C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
  end
end

API.GetDebuffDataByIndex = function(unit, index)
  if API.auras then
    return _G.C_UnitAuras.GetDebuffDataByIndex(unit, index)
  end
end

API.GetCurrentChatGUID = function()
  if API.chatidentity then
    return _G.GetCurrentChatGUID()
  end
end

API.GetPlayerInfoByGUID = function(guid)
  if API.chatidentity and guid then
    return _G.GetPlayerInfoByGUID(guid)
  end
end

-- Read-only bridge to ClassicAPI's optional persistent player cache.
-- ShaguTweaks never enables that cache or its visible-object scanner itself.
API.GetCachedPlayerInfoByName = function(name)
  if API.playercache and name then
    return _G.C_PlayerCache.GetPlayerInfoByName(name)
  end
end

API.GetSpellInfo = function(spell, bookType)
  if API.spellinfo then
    return _G.GetSpellInfo(spell, bookType)
  end
end

API.GetContainerNumFreeSlots = function(bag)
  if API.inventory then
    return _G.C_Container.GetContainerNumFreeSlots(bag)
  end
  return 0, 0
end

-- Returns the live vendor sell price in copper when the client has the item
-- cached. ClassicAPI warms uncached item data itself and returns nil until the
-- cache fill completes, allowing callers to keep an immediate legacy fallback.
API.GetItemSellPriceByID = function(itemID)
  if API.itemprice and itemID then
    return _G.C_Item.GetItemSellPriceByID(itemID)
  end
end

API.GetNumJunkItems = function()
  if API.merchant then
    return _G.C_MerchantFrame.GetNumJunkItems()
  end
  return 0
end

API.SellAllJunkItems = function()
  if API.merchant then
    return _G.C_MerchantFrame.SellAllJunkItems()
  end
end

API.IsMounted = function()
  return API.playerstate and _G.IsMounted() or false
end

API.Dismount = function()
  if API.playerstate then return _G.Dismount() end
end

API.GetShapeshiftFormID = function()
  if API.playerstate then return _G.GetShapeshiftFormID() end
  return 0
end

API.CancelShapeshiftForm = function()
  if API.playerstate then return _G.CancelShapeshiftForm() end
end

API.UnitGUID = function(unit)
  if API.unitguid then
    return _G.UnitGUID(unit)
  end
end
