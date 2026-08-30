local _G = ShaguTweaks.GetGlobalEnv()
local L, T = ShaguTweaks.L, ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Free Slot Count"],
  description = T["Shows free slot counts on the backpack button: class bag slots (top right), reagent bag slots (bottom left), and total free slots (bottom right)."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
  order = 31,
})

module.enable = function(self)
  local button = MainMenuBarBackpackButton

  button.class = button:CreateFontString("Status", "LOW", "GameFontNormal")
  button.class:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  button.class:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -4)
  button.class:SetJustifyH("RIGHT")
  button.class:SetFontObject(GameFontWhite)
  local _, playerclass = UnitClass("player")
  local classcolor = RAID_CLASS_COLORS[playerclass] or { r = .5, g = .5, b = .5, a = 1 }
  button.class:SetTextColor(classcolor.r, classcolor.g, classcolor.b)

  button.reagent = button:CreateFontString("Status", "LOW", "GameFontNormal")
  button.reagent:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  button.reagent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 4)
  button.reagent:SetJustifyH("LEFT")
  button.reagent:SetFontObject(GameFontWhite)
  button.reagent:SetTextColor(.25, .78, .92)

  button.count = button:CreateFontString("Status", "LOW", "GameFontNormal")
  button.count:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 4)
  button.count:SetJustifyH("RIGHT")
  button.count:SetFontObject(GameFontWhite)

  local function UpdateSlots()
    local freeClass, freeReagent, freeGeneral = 0, 0, 0
    local hasClass, hasReagent = false, false

    for bag = 0, 4 do
      local free, family = API.GetContainerNumFreeSlots(bag)
      free = free or 0
      family = family or 0

      -- Preserve the original categories exactly:
      -- arrows/ammo/soul bags are class bags; herb/enchanting bags are reagents.
      if family == 1 or family == 2 or family == 4 then
        hasClass = true
        freeClass = freeClass + free
      elseif family == 32 or family == 64 then
        hasReagent = true
        freeReagent = freeReagent + free
      else
        freeGeneral = freeGeneral + free
      end
    end

    button.class:SetText(hasClass and freeClass or "")
    button.reagent:SetText(hasReagent and freeReagent or "")
    button.count:SetText(freeGeneral)
  end

  UpdateSlots()

  local events = CreateFrame("Frame")
  events:RegisterEvent("BAG_UPDATE_DELAYED")
  events:SetScript("OnEvent", UpdateSlots)
end
