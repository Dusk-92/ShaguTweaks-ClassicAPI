local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local GetExpansion = ShaguTweaks.GetExpansion
local AddBorder = ShaguTweaks.AddBorder
local HookAddonOrVariable = ShaguTweaks.HookAddonOrVariable

local module = ShaguTweaks:register({
  title = T["Item Rarity Borders"],
  description = T["Show item rarity as the border color on bags, bank, character and inspect frames."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local defcolor = {}

local function GetQualityFromLink(link)
  if not link then return end

  local itemID = API and API.GetItemIDFromLink and API.GetItemIDFromLink(link)
  if itemID and API and API.GetItemQualityByID then
    local quality = API.GetItemQualityByID(itemID)
    if quality ~= nil then return quality end
  end

  local _, _, istring = string.find(link, "|H(.+)|h")
  if istring then
    local _, _, quality = GetItemInfo(istring)
    return quality
  end
end

local function GetBagItemQuality(bag, slot)
  if API and API.GetContainerItemID and API.GetItemQualityByID then
    local itemID = API.GetContainerItemID(bag, slot)
    if itemID then
      local quality = API.GetItemQualityByID(itemID)
      if quality ~= nil then return quality end
    end
  end

  return GetQualityFromLink(GetContainerItemLink(bag, slot))
end

local function GetUnitItemQuality(unit, slot)
  if API and API.GetInventoryItemID and API.GetItemQualityByID then
    local itemID = API.GetInventoryItemID(unit, slot)
    if itemID then
      local quality = API.GetItemQualityByID(itemID)
      if quality ~= nil then return quality end
    end
  end

  return GetQualityFromLink(GetInventoryItemLink(unit, slot))
end

local paperdoll_slots = {
  [0] = "AmmoSlot", "HeadSlot",
  "NeckSlot", "ShoulderSlot",
  "ShirtSlot", "ChestSlot",
  "WaistSlot", "LegsSlot",
  "FeetSlot", "WristSlot",
  "HandsSlot", "Finger0Slot",
  "Finger1Slot", "Trinket0Slot",
  "Trinket1Slot", "BackSlot",
  "MainHandSlot", "SecondaryHandSlot",
  "RangedSlot", "TabardSlot",
}

local inspect_slots = {
  "HeadSlot", "NeckSlot",
  "ShoulderSlot", "ShirtSlot",
  "ChestSlot", "WaistSlot",
  "LegsSlot", "FeetSlot",
  "WristSlot", "HandsSlot",
  "Finger0Slot", "Finger1Slot",
  "Trinket0Slot", "Trinket1Slot",
  "BackSlot", "MainHandSlot",
  "SecondaryHandSlot", "RangedSlot",
  "TabardSlot"
}

module.enable = function(self)
  do -- paperdoll
    local refresh_paperdoll = function()
      for i, slot in pairs(paperdoll_slots) do
        local button = _G["Character"..slot]
        if button then
          local border = button.ShaguTweaks_border

          if not border then
            border = AddBorder(button, 3, { r = .5, g = .5, b = .5 })
          end

          if not defcolor["paperdoll"] then
            defcolor["paperdoll"] = { border:GetBackdropBorderColor() }
          end

          local quality = GetInventoryItemQuality("player", i)
          if quality then
            local r, g, b = GetItemQualityColor(quality)
            border:SetBackdropBorderColor(r, g, b, 1)
          else
            border:SetBackdropBorderColor(defcolor["paperdoll"][1], defcolor["paperdoll"][2], defcolor["paperdoll"][3], 1)
          end
        end
      end
    end

    local paperdoll = CreateFrame("Frame", nil, CharacterFrame)
    paperdoll:RegisterEvent("UNIT_INVENTORY_CHANGED")
    paperdoll:SetScript("OnEvent", function()
      if not arg1 or arg1 == "player" then
        refresh_paperdoll()
      end
    end)
    paperdoll:SetScript("OnShow", refresh_paperdoll)
  end

  do -- inspect
    local refresh_inspect = function()
      for i, v in pairs(inspect_slots) do
        local button = _G["Inspect"..v]
        local quality = GetUnitItemQuality("target", i)
        local border = button.ShaguTweaks_border

        if not border then
          border = AddBorder(button, 3, { r = .5, g = .5, b = .5 })
        end

        if not defcolor["inspect"] then
          defcolor["inspect"] = { border:GetBackdropBorderColor() }
        end

        border:SetBackdropBorderColor(defcolor["inspect"][1], defcolor["inspect"][2], defcolor["inspect"][3], 1)
        if quality ~= nil then
          local r, g, b = GetItemQualityColor(quality)
          border:SetBackdropBorderColor(r, g, b, 1)
        end
      end
    end

    HookAddonOrVariable("Blizzard_InspectUI", function()
      local HookInspectPaperDollItemSlotButton_Update = InspectPaperDollItemSlotButton_Update
      InspectPaperDollItemSlotButton_Update = function(arg)
        HookInspectPaperDollItemSlotButton_Update(arg)
        refresh_inspect()
      end
    end)
  end

  do -- bags
    local color = { r = .5, g = .5, b = .46 }

    for i = 0, 3 do
      AddBorder(_G["CharacterBag"..i.."Slot"], 3, color)
    end

    for i = 1, 12 do
      for k = 1, MAX_CONTAINER_ITEMS do
        AddBorder(_G["ContainerFrame"..i.."Item"..k], 3, color)
      end
    end

    local refresh_bags = function(bagID)
      bagID = bagID and tonumber(bagID) or nil

      for i = 1, 12 do
        local frame = _G["ContainerFrame"..i]
        if frame and frame:IsShown() then
          local id = frame:GetID()
          if not bagID or id == bagID then
            local name = frame:GetName()
            for k = 1, MAX_CONTAINER_ITEMS do
              local button = _G[name.."Item"..k]
              if button and button:IsShown() then
                if not defcolor["bag"] then
                  defcolor["bag"] = { button.ShaguTweaks_border:GetBackdropBorderColor() }
                end

                button.ShaguTweaks_border:SetBackdropBorderColor(defcolor["bag"][1], defcolor["bag"][2], defcolor["bag"][3], 1)

                local quality = GetBagItemQuality(id, button:GetID())
                if quality ~= nil then
                  local r, g, b = GetItemQualityColor(quality)
                  button.ShaguTweaks_border:SetBackdropBorderColor(r,g,b)
                end
              end
            end
          end
        end
      end
    end

    local bags = CreateFrame("Frame", nil, ContainerFrame1)
    bags:RegisterEvent("BAG_UPDATE")
    bags:SetScript("OnEvent", function()
      refresh_bags(arg1)
    end)

    local HookContainerFrame_OnShow = ContainerFrame_OnShow
    function ContainerFrame_OnShow()
      HookContainerFrame_OnShow()
      refresh_bags(this and this:GetID())
    end
  end

  do -- bank
    for i = 1, 28 do
      AddBorder(_G["BankFrameItem"..i], 3, color)
    end

    local refresh_bank = function()
      for i = 1, 28 do
        local button = _G["BankFrameItem"..i]
        local quality = GetBagItemQuality(-1, i)
        if button then
          if not defcolor["bank"] then
            defcolor["bank"] = { button.ShaguTweaks_border:GetBackdropBorderColor() }
          end

          button.ShaguTweaks_border:SetBackdropBorderColor(defcolor["bank"][1], defcolor["bank"][2], defcolor["bank"][3], 1)

          if quality and quality > 1 then
            local r, g, b = GetItemQualityColor(quality)
            button.ShaguTweaks_border:SetBackdropBorderColor(r,g,b)
          end
        end
      end
    end

    local bank = CreateFrame("Frame", nil, BankFrame)
    bank:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    bank:SetScript("OnEvent", refresh_bank)
    bank:SetScript("OnShow", refresh_bank)
  end

  do -- weapon buff
    AddBorder(TempEnchant1, 3, {.2,.2,.2})
    AddBorder(TempEnchant2, 3, {.2,.2,.2})

    -- Item quality only changes when equipment changes. Keep the enchant frames'
    -- native OnUpdate untouched and refresh our border colors on inventory events
    -- instead of resolving both weapon qualities on every rendered frame.
    TempEnchant1Border:SetAlpha(0)
    TempEnchant2Border:SetAlpha(0)

    local function refresh_weapon_borders()
      local r, g, b = GetItemQualityColor(GetUnitItemQuality("player", TempEnchant1:GetID()) or 1)
      TempEnchant1.ShaguTweaks_border:SetBackdropBorderColor(r,g,b,1)

      local r, g, b = GetItemQualityColor(GetUnitItemQuality("player", TempEnchant2:GetID()) or 1)
      TempEnchant2.ShaguTweaks_border:SetBackdropBorderColor(r,g,b,1)
    end

    local weapon = CreateFrame("Frame")
    weapon:RegisterEvent("UNIT_INVENTORY_CHANGED")
    weapon:SetScript("OnEvent", function()
      if not arg1 or arg1 == "player" then
        refresh_weapon_borders()
      end
    end)

    refresh_weapon_borders()
  end
end
