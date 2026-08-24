local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Equip Compare"],
  description = T["Shows currently equipped items on tooltips while the shift key is pressed."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

module.enable = function(self)
  local sides = { "Left", "Right" }

  local function AddHeader(tooltip)
    local name = tooltip:GetName()

    -- shift all entries one line down
    for i=tooltip:NumLines(), 1, -1 do
      for _, side in pairs(sides) do
        local current = _G[name.."Text"..side..i]
        local below = _G[name.."Text"..side..i+1]

        if current and current:IsShown() then
          local text = current:GetText()
          local r, g, b = current:GetTextColor()

          if text and text ~= "" then
            if tooltip:NumLines() < i+1 then
              -- add new line if required
              tooltip:AddLine(text, r, g, b, true)
            else
              -- update existing lines
              below:SetText(text)
              below:SetTextColor(r, g, b)
              below:Show()

              -- hide processed line
              current:Hide()
            end
          end
        end
      end
    end

    -- add label to first line
    _G[name.."TextLeft1"]:SetTextColor(.5, .5, .5, 1)
    _G[name.."TextLeft1"]:SetText(CURRENTLY_EQUIPPED)
    _G[name.."TextLeft1"]:Show()

    -- update tooltip sizes
    tooltip:Show()
  end

  local itemtypes = {
    ["deDE"] = {
      ["INVTYPE_WAND"] = "Zauberstab",
      ["INVTYPE_THROWN"] = "Wurfwaffe",
      ["INVTYPE_GUN"] = "Schusswaffe",
      ["INVTYPE_CROSSBOW"] = "Armbrust",
      ["INVTYPE_PROJECTILE"] = "Projektil",
    },
    ["enUS"] = {
      ["INVTYPE_WAND"] = "Wand",
      ["INVTYPE_THROWN"] = "Thrown",
      ["INVTYPE_GUN"] = "Gun",
      ["INVTYPE_CROSSBOW"] = "Crossbow",
      ["INVTYPE_PROJECTILE"] = "Projectile",
    },
    ["esES"] = {
      ["INVTYPE_WAND"] = "Varita",
      ["INVTYPE_THROWN"] = "Arma arrojadiza",
      ["INVTYPE_GUN"] = "Arma de fuego",
      ["INVTYPE_CROSSBOW"] = "Ballesta",
      ["INVTYPE_PROJECTILE"] = "Proyectil",
    },
    ["frFR"] = {
      ["INVTYPE_WAND"] = "Baguette",
      ["INVTYPE_THROWN"] = "Armes de jet",
      ["INVTYPE_GUN"] = "Arme à feu",
      ["INVTYPE_CROSSBOW"] = "Arbalète",
      ["INVTYPE_PROJECTILE"] = "Projectile",
    },
    ["koKR"] = {
      ["INVTYPE_WAND"] = "마법봉",
      ["INVTYPE_THROWN"] = "투척 무기",
      ["INVTYPE_GUN"] = "총",
      ["INVTYPE_CROSSBOW"] = "석궁",
      ["INVTYPE_PROJECTILE"] = "투사체",
    },
    ["ruRU"] = {
      ["INVTYPE_WAND"] = "Жезл",
      ["INVTYPE_THROWN"] = "Метательное",
      ["INVTYPE_GUN"] = "Огнестрельное",
      ["INVTYPE_CROSSBOW"] = "Арбалет",
      ["INVTYPE_PROJECTILE"] = "Боеприпасы",
    },
    ["zhCN"] = {
      ["INVTYPE_WAND"] = "魔杖",
      ["INVTYPE_THROWN"] = "投掷武器",
      ["INVTYPE_GUN"] = "枪械",
      ["INVTYPE_CROSSBOW"] = "弩",
      ["INVTYPE_PROJECTILE"] = "弹药",
    }
  }

  -- Vanilla misses a few inventory type labels in some locales.
  local localeTypes = itemtypes[GetLocale()] or {}
  for key, value in pairs(localeTypes) do setglobal(key, value) end
  INVTYPE_WEAPON_OTHER = INVTYPE_WEAPON.."_other"
  INVTYPE_FINGER_OTHER = INVTYPE_FINGER.."_other"
  INVTYPE_TRINKET_OTHER = INVTYPE_TRINKET.."_other"

  local slots = {
    [INVTYPE_2HWEAPON] = "MainHandSlot",
    [INVTYPE_BODY] = "ShirtSlot",
    [INVTYPE_CHEST] = "ChestSlot",
    [INVTYPE_CLOAK] = "BackSlot",
    [INVTYPE_FEET] = "FeetSlot",
    [INVTYPE_FINGER] = "Finger0Slot",
    [INVTYPE_FINGER_OTHER] = "Finger1Slot",
    [INVTYPE_HAND] = "HandsSlot",
    [INVTYPE_HEAD] = "HeadSlot",
    [INVTYPE_HOLDABLE] = "SecondaryHandSlot",
    [INVTYPE_LEGS] = "LegsSlot",
    [INVTYPE_NECK] = "NeckSlot",
    [INVTYPE_RANGED] = "RangedSlot",
    [INVTYPE_RELIC] = "RangedSlot",
    [INVTYPE_ROBE] = "ChestSlot",
    [INVTYPE_SHIELD] = "SecondaryHandSlot",
    [INVTYPE_SHOULDER] = "ShoulderSlot",
    [INVTYPE_TABARD] = "TabardSlot",
    [INVTYPE_TRINKET] = "Trinket0Slot",
    [INVTYPE_TRINKET_OTHER] = "Trinket1Slot",
    [INVTYPE_WAIST] = "WaistSlot",
    [INVTYPE_WEAPON] = "MainHandSlot",
    [INVTYPE_WEAPON_OTHER] = "SecondaryHandSlot",
    [INVTYPE_WEAPONMAINHAND] = "MainHandSlot",
    [INVTYPE_WEAPONOFFHAND] = "SecondaryHandSlot",
    [INVTYPE_WRIST] = "WristSlot",
    [INVTYPE_WAND] = "RangedSlot",
    [INVTYPE_GUN] = "RangedSlot",
    [INVTYPE_PROJECTILE] = "AmmoSlot",
    [INVTYPE_CROSSBOW] = "RangedSlot",
    [INVTYPE_THROWN] = "RangedSlot",
  }

  ShoppingTooltip1:SetClampedToScreen(true)
  ShoppingTooltip2:SetClampedToScreen(true)

  local function GetSlotType(tooltip)
    -- Prefer ClassicAPI's cache-backed inventory type. This avoids depending on
    -- localized tooltip text and works for Turtle WoW custom items when the
    -- tooltip exposes its item link.
    if API and tooltip.GetItem and API.GetItemIDFromLink
      and API.GetItemInventoryTypeByID and API.GetItemInventorySlotKey then
      local _, link = tooltip:GetItem()
      local itemID = API.GetItemIDFromLink(link)
      local inventoryType = itemID and API.GetItemInventoryTypeByID(itemID)
      local slotKey = inventoryType and API.GetItemInventorySlotKey(inventoryType)
      local slotType = slotKey and _G[slotKey]
      if slotType and slots[slotType] then
        return slotType
      end
    end

    -- 1.12 fallback: find the localized inventory type in the tooltip text.
    local tooltipName = tooltip:GetName()
    for i=1,tooltip:NumLines() do
      local tmpText = _G[tooltipName .. "TextLeft"..i]
      local text = tmpText and tmpText:GetText()
      if text and slots[text] then
        return text
      end
    end
  end

  local function ShowCompare(tooltip)
    if not tooltip then return end

    -- Always clear previous comparisons first so switching from a ring/trinket
    -- to a single-slot item cannot leave ShoppingTooltip2 behind.
    ShoppingTooltip1:Hide()
    ShoppingTooltip2:Hide()

    if not IsShiftKeyDown() then return end

    local slotType = GetSlotType(tooltip)
    local slotName = slotType and slots[slotType]
    if not slotName then return end

    local slotID = GetInventorySlotInfo(slotName)

    -- determine screen part
    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local anchor = x < GetScreenWidth() / 2 and "TOPLEFT" or "TOPRIGHT"
    local relative = x < GetScreenWidth() / 2 and "TOPRIGHT" or "TOPLEFT"

    -- overwrite position for tooltips without owner
    local pos, parent = tooltip:GetPoint()
    if parent and parent == UIParent and pos == "TOPRIGHT" then
      anchor = "TOPRIGHT"
      relative = "TOPLEFT"
    end

    -- first tooltip
    ShoppingTooltip1:SetOwner(tooltip, "ANCHOR_NONE")
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint(anchor, tooltip, relative, 0, 0)
    ShoppingTooltip1:SetInventoryItem("player", slotID)
    ShoppingTooltip1:Show()
    AddHeader(ShoppingTooltip1)

    -- second tooltip for rings, trinkets and one-hand weapons
    if slots[slotType .. "_other"] then
      local slotID_other = GetInventorySlotInfo(slots[slotType .. "_other"])
      ShoppingTooltip2:SetOwner(tooltip, "ANCHOR_NONE")
      ShoppingTooltip2:ClearAllPoints()
      if ShoppingTooltip1:IsShown() then
        ShoppingTooltip2:SetPoint(anchor, ShoppingTooltip1, relative, 0, 0)
      else
        ShoppingTooltip2:SetPoint(anchor, tooltip, relative, 0, 0)
      end
      ShoppingTooltip2:SetInventoryItem("player", slotID_other)
      ShoppingTooltip2:Show()
      AddHeader(ShoppingTooltip2)
    end
  end

  -- Recalculate only when a tooltip is actually shown/updated. The original
  -- module scanned every tooltip line on every rendered frame.
  local trackedTooltips = {}
  local function TrackTooltip(tooltip)
    if not tooltip or trackedTooltips[tooltip] then return end
    trackedTooltips[tooltip] = true

    ShaguTweaks.hooksecurefunc(tooltip, "Show", function()
      ShowCompare(tooltip)
    end)
  end

  TrackTooltip(GameTooltip)

  -- ClassicAPI exposes modifier transitions, so pressing/releasing Shift can
  -- refresh an already visible tooltip without an always-running OnUpdate.
  local modifier = CreateFrame("Frame")
  if API and API.modifierstate then
    modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
    modifier:SetScript("OnEvent", function()
      if arg1 == "LSHIFT" or arg1 == "RSHIFT" then
        for tooltip in pairs(trackedTooltips) do
          if tooltip:IsShown() then
            ShowCompare(tooltip)
          end
        end
      end
    end)
  else
    -- Compatibility fallback for an older ClassicAPI build: poll only the
    -- Shift boolean, not all tooltip lines every frame.
    local previousShift = IsShiftKeyDown()
    modifier:SetScript("OnUpdate", function()
      local currentShift = IsShiftKeyDown()
      if currentShift ~= previousShift then
        previousShift = currentShift
        for tooltip in pairs(trackedTooltips) do
          if tooltip:IsShown() then
            ShowCompare(tooltip)
          end
        end
      end
    end)
  end

  -- AtlasLoot uses its own tooltip frames; hook their Show calls the same way.
  ShaguTweaks.HookAddonOrVariable("AtlasLoot", function()
    TrackTooltip(AtlasLootTooltip)
    TrackTooltip(AtlasLootTooltip2)
  end)
end
