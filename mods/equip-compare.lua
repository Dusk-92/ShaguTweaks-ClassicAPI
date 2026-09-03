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
  if not API.tooltipsetitem or not API.modifierstate or not API.timer
    or not API.iteminventorytype or not API.iteminventoryslotkey then
    return
  end

  local sides = { "Left", "Right" }

  local function AddHeader(tooltip)
    local name = tooltip:GetName()

    for i=tooltip:NumLines(), 1, -1 do
      for _, side in pairs(sides) do
        local current = _G[name.."Text"..side..i]
        local below = _G[name.."Text"..side..i+1]

        if current and current:IsShown() then
          local text = current:GetText()
          local r, g, b = current:GetTextColor()

          if text and text ~= "" then
            if tooltip:NumLines() < i+1 then
              tooltip:AddLine(text, r, g, b, true)
            else
              below:SetText(text)
              below:SetTextColor(r, g, b)
              below:Show()
              current:Hide()
            end
          end
        end
      end
    end

    _G[name.."TextLeft1"]:SetTextColor(.5, .5, .5, 1)
    _G[name.."TextLeft1"]:SetText(CURRENTLY_EQUIPPED)
    _G[name.."TextLeft1"]:Show()
    tooltip:Show()
  end

  local slots = {
    ["INVTYPE_2HWEAPON"] = { "MainHandSlot" },
    ["INVTYPE_BODY"] = { "ShirtSlot" },
    ["INVTYPE_CHEST"] = { "ChestSlot" },
    ["INVTYPE_CLOAK"] = { "BackSlot" },
    ["INVTYPE_FEET"] = { "FeetSlot" },
    ["INVTYPE_FINGER"] = { "Finger0Slot", "Finger1Slot" },
    ["INVTYPE_HAND"] = { "HandsSlot" },
    ["INVTYPE_HEAD"] = { "HeadSlot" },
    ["INVTYPE_HOLDABLE"] = { "SecondaryHandSlot" },
    ["INVTYPE_LEGS"] = { "LegsSlot" },
    ["INVTYPE_NECK"] = { "NeckSlot" },
    ["INVTYPE_RANGED"] = { "RangedSlot" },
    ["INVTYPE_RANGEDRIGHT"] = { "RangedSlot" },
    ["INVTYPE_RELIC"] = { "RangedSlot" },
    ["INVTYPE_ROBE"] = { "ChestSlot" },
    ["INVTYPE_SHIELD"] = { "SecondaryHandSlot" },
    ["INVTYPE_SHOULDER"] = { "ShoulderSlot" },
    ["INVTYPE_TABARD"] = { "TabardSlot" },
    ["INVTYPE_TRINKET"] = { "Trinket0Slot", "Trinket1Slot" },
    ["INVTYPE_WAIST"] = { "WaistSlot" },
    ["INVTYPE_WEAPON"] = { "MainHandSlot", "SecondaryHandSlot" },
    ["INVTYPE_WEAPONMAINHAND"] = { "MainHandSlot" },
    ["INVTYPE_WEAPONOFFHAND"] = { "SecondaryHandSlot" },
    ["INVTYPE_WRIST"] = { "WristSlot" },
    ["INVTYPE_AMMO"] = { "AmmoSlot" },
    ["INVTYPE_THROWN"] = { "RangedSlot" },
  }

  ShoppingTooltip1:SetClampedToScreen(true)
  ShoppingTooltip2:SetClampedToScreen(true)

  local function GetSlotNames(tooltip)
    local itemID = API.GetTooltipItemID(tooltip)
    if not itemID then return end

    local inventoryType = API.GetItemInventoryTypeByID(itemID)
    if inventoryType == nil then return end

    local slotKey = API.GetItemInventorySlotKey(inventoryType)
    return slotKey and slots[slotKey]
  end

  local activeTooltip

  local function HideCompare(tooltip)
    if tooltip and activeTooltip ~= tooltip then return end
    ShoppingTooltip1:Hide()
    ShoppingTooltip2:Hide()
    activeTooltip = nil
  end

  local function ShowCompare(tooltip)
    if not tooltip then return end

    HideCompare()

    if not API.IsShiftKeyDown() then return end

    local slotNames = GetSlotNames(tooltip)
    if not slotNames or not slotNames[1] then return end

    local x = GetCursorPosition() / UIParent:GetEffectiveScale()
    local anchor = x < GetScreenWidth() / 2 and "TOPLEFT" or "TOPRIGHT"
    local relative = x < GetScreenWidth() / 2 and "TOPRIGHT" or "TOPLEFT"

    local pos, parent = tooltip:GetPoint()
    if parent and parent == UIParent and pos == "TOPRIGHT" then
      anchor = "TOPRIGHT"
      relative = "TOPLEFT"
    end

    local slotID = GetInventorySlotInfo(slotNames[1])
    ShoppingTooltip1:SetOwner(tooltip, "ANCHOR_NONE")
    ShoppingTooltip1:ClearAllPoints()
    ShoppingTooltip1:SetPoint(anchor, tooltip, relative, 0, 0)
    ShoppingTooltip1:SetInventoryItem("player", slotID)
    ShoppingTooltip1:Show()
    AddHeader(ShoppingTooltip1)

    if slotNames[2] then
      local secondSlotID = GetInventorySlotInfo(slotNames[2])
      ShoppingTooltip2:SetOwner(tooltip, "ANCHOR_NONE")
      ShoppingTooltip2:ClearAllPoints()
      if ShoppingTooltip1:IsShown() then
        ShoppingTooltip2:SetPoint(anchor, ShoppingTooltip1, relative, 0, 0)
      else
        ShoppingTooltip2:SetPoint(anchor, tooltip, relative, 0, 0)
      end
      ShoppingTooltip2:SetInventoryItem("player", secondSlotID)
      ShoppingTooltip2:Show()
      AddHeader(ShoppingTooltip2)
    end

    activeTooltip = tooltip
  end

  local trackedTooltips = {}
  local pending = {}

  local function ScheduleCompare(tooltip)
    if not tooltip or pending[tooltip] then return end
    pending[tooltip] = true

    API.Defer(function()
      pending[tooltip] = nil
      if tooltip:IsShown() then
        ShowCompare(tooltip)
      end
    end)
  end

  local function TrackTooltip(tooltip)
    if not tooltip or trackedTooltips[tooltip] then return end
    trackedTooltips[tooltip] = true

    tooltip:HookScript("OnTooltipSetItem", function()
      ScheduleCompare(tooltip)
    end)

    tooltip:HookScript("OnTooltipCleared", function()
      HideCompare(tooltip)
    end)
  end

  TrackTooltip(GameTooltip)

  local modifier = CreateFrame("Frame")
  modifier:RegisterEvent("MODIFIER_STATE_CHANGED")
  modifier:SetScript("OnEvent", function()
    if arg1 ~= "LSHIFT" and arg1 ~= "RSHIFT" then return end

    for tooltip in pairs(trackedTooltips) do
      if tooltip:IsShown() and API.GetTooltipItemID(tooltip) then
        ShowCompare(tooltip)
      end
    end
  end)

  ShaguTweaks.HookAddonOrVariable("AtlasLoot", function()
    TrackTooltip(AtlasLootTooltip)
    TrackTooltip(AtlasLootTooltip2)
  end)
end
