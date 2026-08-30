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

API.spellrange = type(_G.C_Spell) == "table"
  and type(_G.C_Spell.IsSpellInRange) == "function"

API.auras = type(_G.C_UnitAuras) == "table"
  and type(_G.C_UnitAuras.GetAuraDataByIndex) == "function"
  and type(_G.C_UnitAuras.GetDebuffDataByIndex) == "function"

API.aurapositional = type(_G.C_UnitAuras) == "table"
  and type(_G.C_UnitAuras.UnitDebuff) == "function"

API.spellinfo = type(_G.GetSpellInfo) == "function"
API.actioninfo = type(_G.GetActionInfo) == "function"
API.autoattack = type(_G.C_Spell) == "table"
  and type(_G.C_Spell.IsAutoAttackSpell) == "function"
  and type(_G.C_Spell.IsRangedAutoAttackSpell) == "function"
API.autoattackbook = type(_G.C_SpellBook) == "table"
  and type(_G.C_SpellBook.IsAutoAttackSpellBookItem) == "function"
  and type(_G.C_SpellBook.IsRangedAutoAttackSpellBookItem) == "function"

API.inventory = type(_G.C_Container) == "table"
  and type(_G.C_Container.GetContainerNumFreeSlots) == "function"

API.containeritems = type(_G.C_Container) == "table"
  and type(_G.C_Container.GetContainerItemID) == "function"

API.containeriteminfo = type(_G.C_Container) == "table"
  and type(_G.C_Container.GetContainerItemInfo) == "function"

API.items = type(_G.C_Item) == "table"
API.iteminfo = API.items and type(_G.C_Item.GetItemInfo) == "function"
API.itemname = API.items and type(_G.C_Item.GetItemNameByID) == "function"
API.itemquality = API.items and type(_G.C_Item.GetItemQualityByID) == "function"
API.itemprice = API.items and type(_G.C_Item.GetItemSellPriceByID) == "function"
API.iteminventorytype = API.items and type(_G.C_Item.GetItemInventoryTypeByID) == "function"
API.iteminventoryslotkey = API.items and type(_G.C_Item.GetItemInventorySlotKey) == "function"
API.itemrange = API.items and type(_G.C_Item.IsItemInRange) == "function"

API.eventutils = type(_G.C_EventUtils) == "table"
  and type(_G.C_EventUtils.IsEventValid) == "function"
API.modifierkeys = type(_G.IsLeftShiftKeyDown) == "function"
  and type(_G.IsRightShiftKeyDown) == "function"
  and type(_G.IsLeftControlKeyDown) == "function"
  and type(_G.IsRightControlKeyDown) == "function"
  and type(_G.IsLeftAltKeyDown) == "function"
  and type(_G.IsRightAltKeyDown) == "function"
API.modifierstate = API.eventutils and API.modifierkeys
  and _G.C_EventUtils.IsEventValid("MODIFIER_STATE_CHANGED")

API.merchant = type(_G.C_MerchantFrame) == "table"
  and type(_G.C_MerchantFrame.GetNumJunkItems) == "function"
  and type(_G.C_MerchantFrame.SellAllJunkItems) == "function"

API.playerstate = type(_G.IsMounted) == "function"
  and type(_G.Dismount) == "function"
  and type(_G.GetShapeshiftFormID) == "function"
  and type(_G.CancelShapeshiftForm) == "function"

API.unitguid = type(_G.UnitGUID) == "function"
API.unitrange = type(_G.UnitInRange) == "function"

API.macrospell = type(_G.GetMacroSpell) == "function"
API.attackverbs = type(_G.StartAttack) == "function"
  and type(_G.StopAttack) == "function"
API.focus = type(_G.FocusUnit) == "function"
  and type(_G.ClearFocus) == "function"

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

  if not name then return end

  -- ClassicAPI can know that a remote unit is channeling even when the
  -- channel began before it was observed, in which case timing is nil. Keep
  -- the normalized first value nil, but expose the live spell identity in
  -- trailing values so castbar modules can safely try a timed SuperWoW cache.
  if not startTime or not endTime then
    return nil, nil, nil, nil, nil, nil, nil,
      notInterruptible, spellID, true
  end

  return name, "", displayName or "", texture, startTime, endTime,
    isTradeSkill, notInterruptible, spellID, true
end

API.IsSpellInRange = function(spell, unit)
  if API.spellrange then
    return _G.C_Spell.IsSpellInRange(spell, unit)
  end
end

API.GetActionInfo = function(slot)
  if API.actioninfo then
    return _G.GetActionInfo(slot)
  end
end

API.GetMacroSpell = function(slot)
  if API.macrospell then
    return _G.GetMacroSpell(slot)
  end
end

API.StartAttack = function(unit)
  if API.attackverbs then
    if unit then return _G.StartAttack(unit) end
    return _G.StartAttack()
  end
end

API.StopAttack = function()
  if API.attackverbs then
    return _G.StopAttack()
  end
end

API.FocusUnit = function(unit)
  if API.focus then
    if unit then return _G.FocusUnit(unit) end
    return _G.FocusUnit()
  end
end

API.ClearFocus = function()
  if API.focus then
    return _G.ClearFocus()
  end
end

API.IsAutoAttackSpell = function(spellID)
  return API.autoattack and _G.C_Spell.IsAutoAttackSpell(spellID) or false
end

API.IsRangedAutoAttackSpell = function(spellID)
  return API.autoattack and _G.C_Spell.IsRangedAutoAttackSpell(spellID) or false
end

API.IsAutoAttackSpellBookItem = function(slot, bookType)
  return API.autoattackbook
    and _G.C_SpellBook.IsAutoAttackSpellBookItem(slot, bookType) or false
end

API.IsRangedAutoAttackSpellBookItem = function(slot, bookType)
  return API.autoattackbook
    and _G.C_SpellBook.IsRangedAutoAttackSpellBookItem(slot, bookType) or false
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

-- ClassicAPI's positional UnitDebuff mirrors the Classic-Era 15-value shape
-- without allocating an AuraData table. Prefer it in hot UI refresh paths.
API.UnitDebuff = function(unit, index, filter)
  if API.aurapositional then
    return _G.C_UnitAuras.UnitDebuff(unit, index, filter)
  end
end

-- Normalize the debuff type across ClassicAPI's Classic-Era-shaped
-- positional return and Vanilla's legacy three-value UnitDebuff return.
API.GetDebuffType = function(unit, index, filter)
  if API.aurapositional then
    local _, _, _, debuffType = _G.C_UnitAuras.UnitDebuff(unit, index, filter)
    return debuffType
  end

  if type(_G.UnitDebuff) == "function" then
    local _, _, debuffType = _G.UnitDebuff(unit, index)
    return debuffType
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

-- ClassicAPI updates its own left/right modifier bitmap before firing
-- MODIFIER_STATE_CHANGED. Prefer that state over vanilla's merged Win32 key
-- state when the richer ClassicAPI functions are available.
API.IsShiftKeyDown = function()
  if API.modifierkeys then
    return (_G.IsLeftShiftKeyDown() or _G.IsRightShiftKeyDown()) and true or false
  end

  if type(_G.IsShiftKeyDown) == "function" then
    return _G.IsShiftKeyDown() and true or false
  end

  return false
end

API.IsControlKeyDown = function()
  if API.modifierkeys then
    return (_G.IsLeftControlKeyDown() or _G.IsRightControlKeyDown()) and true or false
  end

  if type(_G.IsControlKeyDown) == "function" then
    return _G.IsControlKeyDown() and true or false
  end

  return false
end

API.IsAltKeyDown = function()
  if API.modifierkeys then
    return (_G.IsLeftAltKeyDown() or _G.IsRightAltKeyDown()) and true or false
  end

  if type(_G.IsAltKeyDown) == "function" then
    return _G.IsAltKeyDown() and true or false
  end

  return false
end

-- Direct item IDs avoid a class of Turtle WoW custom-item failures caused by
-- relying exclusively on legacy item-link parsing.
local function GetItemIDFromLink(link)
  if not link then return end
  local _, _, itemID = string.find(link, "item:(%d+)")
  return itemID and tonumber(itemID) or nil
end

API.GetItemIDFromLink = GetItemIDFromLink

API.GetContainerItemLink = function(bag, slot)
  if API.containeriteminfo then
    local info = _G.C_Container.GetContainerItemInfo(bag, slot)
    if info and info.hyperlink then
      return info.hyperlink
    end
  end

  return _G.GetContainerItemLink(bag, slot)
end

API.GetContainerItemStackCount = function(bag, slot)
  if API.containeriteminfo then
    local info = _G.C_Container.GetContainerItemInfo(bag, slot)
    if info and info.stackCount then
      return info.stackCount
    end
  end

  local _, count = _G.GetContainerItemInfo(bag, slot)
  return count or 0
end

API.GetContainerItemID = function(bag, slot)
  if API.containeritems then
    local itemID = _G.C_Container.GetContainerItemID(bag, slot)
    if itemID then return itemID end
  end

  return GetItemIDFromLink(API.GetContainerItemLink(bag, slot))
end

API.GetInventoryItemID = function(unit, slot)
  if type(_G.GetInventoryItemID) == "function" then
    local itemID = _G.GetInventoryItemID(unit, slot)
    if itemID then return itemID end
  end

  return GetItemIDFromLink(_G.GetInventoryItemLink(unit, slot))
end

API.GetItemInfo = function(item)
  if API.iteminfo then
    return _G.C_Item.GetItemInfo(item)
  end
  return _G.GetItemInfo(item)
end

API.GetItemNameByID = function(itemID)
  if not itemID then return end
  if API.itemname then
    return _G.C_Item.GetItemNameByID(itemID)
  end

  local name = _G.GetItemInfo(itemID)
  return name
end

API.GetItemQualityByID = function(itemID)
  if not itemID then return end
  if API.itemquality then
    return _G.C_Item.GetItemQualityByID(itemID)
  end

  local _, _, quality = _G.GetItemInfo(itemID)
  return quality
end

API.GetItemSellPriceByID = function(itemID)
  if not itemID then return end
  if API.itemprice then
    return _G.C_Item.GetItemSellPriceByID(itemID)
  end
end

API.GetItemInventoryTypeByID = function(itemID)
  if not itemID then return end
  if API.iteminventorytype then
    return _G.C_Item.GetItemInventoryTypeByID(itemID)
  end
end

API.GetItemInventorySlotKey = function(inventoryType)
  if inventoryType == nil then return end
  if API.iteminventoryslotkey then
    return _G.C_Item.GetItemInventorySlotKey(inventoryType)
  end
end

API.IsItemInRange = function(item, unit)
  if API.itemrange then
    return _G.C_Item.IsItemInRange(item, unit)
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

-- Prefer ClassicAPI's reach-aware 40-yard UnitInRange. The wrapper handles
-- the player's own frame explicitly and preserves a Vanilla interaction check
-- only as a centralized compatibility fallback.
API.UnitInRange = function(unit)
  if not unit then return false, false end

  if type(_G.UnitIsUnit) == "function" and _G.UnitIsUnit(unit, "player") then
    return true, true
  end

  if API.unitrange then
    local inRange, checked = _G.UnitInRange(unit)
    if checked then
      return inRange and true or false, true
    end
  end

  if type(_G.UnitExists) == "function"
    and type(_G.CheckInteractDistance) == "function"
    and _G.UnitExists(unit) then
    return _G.CheckInteractDistance(unit, 4) and true or false, true
  end

  return false, false
end
