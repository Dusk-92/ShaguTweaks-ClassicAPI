local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local HookAddonOrVariable = ShaguTweaks.HookAddonOrVariable
local GetExpansion = ShaguTweaks.GetExpansion
local AddBorder = ShaguTweaks.AddBorder

local module = ShaguTweaks:register({
  title = T["Darkened UI"],
  description = T["Turns the entire interface into darker colors."],
  expansions = { ["vanilla"] = true },
  category = T["Interface"],
  enabled = nil,
  config = {
    ["darkmode.color"] = { r = .3, g = .3, b = .3, a = .9 }
  }
})

local blacklist = {
  ["Solid Texture"] = true,
  ["WHITE8X8"] = true,
  ["StatusBar"] = true,
  ["BarFill"] = true,
  ["Portrait"] = true,
  ["Button"] = true,
  ["Icon"] = true,
  ["AddOns"] = true,
  ["StationeryTest"] = true,
  ["TargetDead"] = true, -- LootFrame Icon
  ["^KeyRing"] = true, -- bag frame
  ["GossipIcon"] = true,
  ["WorldMap\\(.+)\\"] = true,
  ["PetHappiness"] = true,
  ["Elite"] = true,
  ["Rare"] = true,
  ["ColorPickerWheel"] = true,
  ["ComboPoint"] = true,
  ["Skull"] = true,

  -- LFT:
  ["battlenetworking0"] = true,
  ["damage"] = true,
  ["tank"] = true,
  ["healer"] = true,
}

local regionskips = {
  -- colorpicker gradient
  ["ColorPickerFrame"] = { [15] = true },
  -- EQL3: background art tiles on the main frame - BookIcon(1), TopLeft(2), Top_Switch_Off(3), BottomLeft(4), Bottom_Switch_Off(5), Top_Switch_On(6), Bottom_Switch_On(7)
  ["EQL3_QuestLogFrame"] = { [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true },
  -- EQL3: parchment tiles on the description panel - TopMiddle(1), TopRight(2), BottomMiddle(3), BottomRight(4)
  ["EQL3_QuestLogFrame_Description"] = { [1]=true, [2]=true, [3]=true, [4]=true },
}

local backgrounds = {
  ["^SpellBookFrame$"] = { 325, 355, 17, -74 },
  ["^ItemTextFrame$"] = { 300, 355, 24, -74 },
  ["^QuestLogDetailScrollFrame$"] = { QuestLogDetailScrollChildFrame:GetWidth(), QuestLogDetailScrollChildFrame:GetHeight(), 0, 0 },
  ["^QuestFrame(.+)Panel$"] = { 300, 330, 24, -82 },
  ["^GossipFrameGreetingPanel$"] = { 300, 330, 24, -82 },
}

local borders = {
  ["ShapeshiftButton"] = 3,
  ["BuffButton"] = 3,
  ["TargetFrameBuff"] = 3,
  ["TempEnchant"] = 3,
  ["SpellButton"] = 3,
  ["SpellBookSkillLineTab"] = 3,
  ["ActionButton%d+$"] = 3,
  ["MultiBar(.+)Button%d+$"] = 3,
  ["KeyRingButton"] = 2,
  ["ActionBarUpButton"] = -3,
  ["ActionBarDownButton"] = -3,
  ["MainMenuBarPerformanceBarFrameButton"] = { -12, -1, -8, 4 },
  ["Character(.+)Slot$"] = 3,
  ["Inspect(.+)Slot$"] = 3,
  ["ContainerFrame(.+)Item"] = 3,
  ["MainMenuBarBackpackButton$"] = 3,
  ["CharacterBag(.+)Slot$"] = 3,
  ["ChatFrame(.+)Button"] = -2,
  ["PetFrameHappiness"] = 2,
  ["MicroButton"] = { -21, 0, 0, 0 },
}

local addonframes = {
  ["Blizzard_TalentUI"] = { "TalentFrame" },
  ["Blizzard_AuctionUI"] = { "AuctionFrame", "AuctionDressUpFrame" },
  ["Blizzard_CraftUI"] = { "CraftFrame" },
  ["Blizzard_InspectUI"] = {
    "InspectPaperDollFrame",
    "InspectHonorFrame",
    "InspectFrameTab1",
    "InspectFrameTab2",
  },
  ["Blizzard_MacroUI"] = { "MacroFrame", "MacroPopupFrame" },
  ["Blizzard_RaidUI"] = { "ReadyCheckFrame" },
  ["Blizzard_TradeSkillUI"] = { "TradeSkillFrame" },
  ["Blizzard_TrainerUI"] = { "ClassTrainerFrame" },
}

-- Turtle WoW exposes these extra inspect pages. Keep them out of the generic
-- Vanilla path so missing Turtle-only frames don't leave compatibility lurkers
-- registered for the whole session.
local isTurtle = TargetHPText and TargetHPPercText
if isTurtle then
  table.insert(addonframes["Blizzard_InspectUI"], "InspectArenaFrame")
  table.insert(addonframes["Blizzard_InspectUI"], "InspectTalentsFrame")
  table.insert(addonframes["Blizzard_InspectUI"], "InspectFrameTab3")
  table.insert(addonframes["Blizzard_InspectUI"], "InspectFrameTab4")
end

-- sizing is a bit different on tbc
if GetExpansion() == "tbc" then
  borders["BuffButton"] = 2
  borders["TempEnchant"] = 2
  borders["MicroButton"] = { -21, 0, 0, 0 }
end

local function IsBlacklisted(texture)
  local name = texture:GetName()
  local texture = texture:GetTexture()
  if not texture then return true end

  if name then
    for entry in pairs(blacklist) do
      if string.find(name, entry, 1) then return true end
    end
  end

  for entry in pairs(blacklist) do
    if string.find(texture, entry, 1) then return true end
  end

  return nil
end

local function AddSpecialBackground(frame, w, h, x, y)
  frame.Material = frame.Material or frame:CreateTexture(nil, "OVERLAY")
  frame.Material:SetTexture("Interface\\Stationery\\StationeryTest1")
  frame.Material:SetWidth(w)
  frame.Material:SetHeight(h)
  frame.Material:SetPoint("TOPLEFT", frame, x, y)
  frame.Material:SetVertexColor(.8, .8, .8)
end

local function DarkenFrame(frame, r, g, b, a)
  -- dont't do anything if disabled
  if not ShaguTweaks.DarkMode then return end

  -- set defaults
  if not r and not g and not b then
    r, g, b, a = module.config["darkmode.color"].r, module.config["darkmode.color"].g, module.config["darkmode.color"].b, module.config["darkmode.color"].a
  end

  -- iterate through all subframes
  if frame and frame.GetChildren then
    for _, frame in pairs({frame:GetChildren()}) do
      DarkenFrame(frame, r, g, b, a)
    end
  end

  -- set vertex on all regions
  if frame and frame.GetRegions then
    -- read name
    local name = frame.GetName and frame:GetName()

    -- set a dark backdrop border color everywhere
    frame:SetBackdropBorderColor(module.config["darkmode.color"].r, module.config["darkmode.color"].g, module.config["darkmode.color"].b, module.config["darkmode.color"].a)

    -- add special backgrounds to quests and such
    for pattern, inset in pairs(backgrounds) do
      if name and string.find(name, pattern) then AddSpecialBackground(frame, inset[1], inset[2], inset[3], inset[4]) end
    end

    -- add black borders around specified buttons
    for pattern, inset in pairs(borders) do
      if name and string.find(name, pattern) then AddBorder(frame, inset, module.config["darkmode.color"]) end
    end

    -- scan through all regions (textures)
    for id, region in pairs({frame:GetRegions()}) do
      if region.SetVertexColor and region:GetObjectType() == "Texture" then
        if region:GetTexture() and string.find(region:GetTexture(), "UI%-Panel%-Button%-Up") then
          -- monochrome buttons
          -- region:SetDesaturated(true)
        elseif name and id and regionskips[name] and regionskips[name][id] then
          -- skip special regions
        elseif region.GetBlendMode and region:GetBlendMode() == "ADD" then
          -- skip blend over textures
        elseif IsBlacklisted(region) then
          -- skip blacklisted texture names
        else
          region:SetVertexColor(r,g,b,a)
        end
      end
    end
  end
end

-- register darken frame to global
ShaguTweaks.DarkenFrame = DarkenFrame

module.enable = function(self)
  ShaguTweaks.DarkMode = true

  local name, original, r, g, b
  local hookBuffButton_Update = BuffButton_Update
  function BuffButton_Update(buttonName, index, filter)
    hookBuffButton_Update(buttonName, index, filter)

    -- tbc passes buttonName and index arguments, vanilla uses "this" context
    name = buttonName and index and buttonName .. index or this:GetName()
    original = _G[name.."Border"]

    if original and this.ShaguTweaks_border then
      r, g, b = original:GetVertexColor()
      this.ShaguTweaks_border:SetBackdropBorderColor(r, g, b, 1)
      original:SetAlpha(0)
    elseif not original and _G[name] then
      -- tbc buff buttons don't have borders, so we
      -- need to manually add a dark one.
      AddBorder(_G[name], 2, module.config["darkmode.color"])
    end
  end

  TOOLTIP_DEFAULT_COLOR.r = module.config["darkmode.color"].r
  TOOLTIP_DEFAULT_COLOR.g = module.config["darkmode.color"].g
  TOOLTIP_DEFAULT_COLOR.b = module.config["darkmode.color"].b

  TOOLTIP_DEFAULT_BACKGROUND_COLOR.r = module.config["darkmode.color"].r
  TOOLTIP_DEFAULT_BACKGROUND_COLOR.g = module.config["darkmode.color"].g
  TOOLTIP_DEFAULT_BACKGROUND_COLOR.b = module.config["darkmode.color"].b

  DarkenFrame(UIParent)
  DarkenFrame(WorldMapFrame)
  DarkenFrame(DropDownList1)
  DarkenFrame(DropDownList2)
  DarkenFrame(DropDownList3)

  -- align all actionbutton textures
  local bars = { "Action", "BonusAction", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "Shapeshift" }
  for _, prefix in pairs(bars) do
    for i = 1, NUM_ACTIONBAR_BUTTONS do
      local button = _G[prefix .. "Button" .. i]
      local texture = _G[prefix.."Button"..i.."NormalTexture"]

      if button and texture then
        texture:SetWidth(60)
        texture:SetHeight(60)
        texture:SetPoint("CENTER", 0, 0)
        ShaguTweaks.AddBorder(button, 3)
      end
    end
  end

  for _, button in pairs({ MinimapZoomOut, MinimapZoomIn }) do
    for _, func in pairs({ "GetNormalTexture", "GetDisabledTexture", "GetPushedTexture" }) do
      if button[func] then
        local tex = button[func](button)
        if tex then
          tex:SetVertexColor(module.config["darkmode.color"].r+.2, module.config["darkmode.color"].g+.2, module.config["darkmode.color"].b+.2, 1)
        end
      end
    end
  end

  HookAddonOrVariable("Blizzard_AuctionUI", function()
    for i = 1, 15 do
      local tex = _G["AuctionFilterButton"..i]:GetNormalTexture()
      tex:SetVertexColor(module.config["darkmode.color"].r, module.config["darkmode.color"].g, module.config["darkmode.color"].b, 1)
    end

    for i = 1, 8 do
      _G["BrowseButton"..i.."Left"]:SetVertexColor(module.config["darkmode.color"].r, module.config["darkmode.color"].g, module.config["darkmode.color"].b, 1)
      _G["BrowseButton"..i.."Right"]:SetVertexColor(module.config["darkmode.color"].r, module.config["darkmode.color"].g, module.config["darkmode.color"].b, 1)
    end
  end)

  for addon, data in pairs(addonframes) do
    for _, frame in pairs(data) do
      local frame = frame
      HookAddonOrVariable(frame, function()
        DarkenFrame(_G[frame])
      end)
    end
  end

  -- Turtle's inspect talent tree is rebuilt by TWTalentFrame_Update().
  -- Its background textures are assigned during that update, so the initial
  -- InspectTalentsFrame pass may happen too early. Re-darken the parent after
  -- each rebuild; it already contains TWTalentFrame, so one recursive scan is
  -- sufficient and avoids traversing the same tree twice.
  if isTurtle then
    HookAddonOrVariable("TWTalentFrame", function()
      if not _G.TWTalentFrame or not _G.TWTalentFrame_Update then return end

      if not _G.TWTalentFrame.ShaguTweaksDarkHook then
        _G.TWTalentFrame.ShaguTweaksDarkHook = true
        ShaguTweaks.hooksecurefunc("TWTalentFrame_Update", function()
          DarkenFrame(_G.InspectTalentsFrame or _G.TWTalentFrame)
        end)
      end

      DarkenFrame(_G.InspectTalentsFrame or _G.TWTalentFrame)
    end)
  end

  HookAddonOrVariable("Blizzard_TimeManager", function()
    DarkenFrame(TimeManagerClockButton)
  end)

  HookAddonOrVariable("GameTooltipStatusBarBackdrop", function()
    DarkenFrame(_G["GameTooltipStatusBarBackdrop"])
  end)

  -- Prefer BlizzNameplatesPlus' own nameplate provider whenever available.
  -- This is capability-based instead of version-based, so BNP updates keep
  -- working as long as its public libnameplate callback API remains available.
  local bnpNameplates = BNP
    and BNP.libnameplate
    and BNP.libnameplate.OnInit
    and BNP.libnameplate.OnShow

  if bnpNameplates then
    local pending = {}
    local updater = CreateFrame("Frame")

    local function StopUpdaterIfIdle()
      if not next(pending) then
        updater:SetScript("OnUpdate", nil)
      end
    end

    local function ReapplyBNPDarkMode(plate)
      plate = plate or this
      if not plate or not plate:IsShown() then return end
      if plate.darkened then return end

      plate.darkened = true
      DarkenFrame(plate)

      -- Blizzard can restore some nameplate textures immediately after OnShow.
      -- Queue one delayed pass, then stop completely. If BNP's own Shagu
      -- compatibility already darkened the plate first, the marker above makes
      -- this path a no-op and avoids duplicate work.
      pending[plate] = GetTime() + 0.08
      if not updater:GetScript("OnUpdate") then
        updater:SetScript("OnUpdate", function()
          local now = GetTime()
          local current, due
          for current, due in pairs(pending) do
            if now >= due then
              pending[current] = nil
              if current and current:IsShown() then
                current.darkened = nil
                DarkenFrame(current)
                current.darkened = true
              end
            end
          end
          StopUpdaterIfIdle()
        end)
      end
    end

    table.insert(BNP.libnameplate.OnInit, ReapplyBNPDarkMode)
    table.insert(BNP.libnameplate.OnShow, ReapplyBNPDarkMode)
  else
    -- Plain ShaguTweaks / no compatible BNP provider: preserve the original
    -- libnameplate behavior and let the lazy library activate automatically.
    table.insert(ShaguTweaks.libnameplate.OnUpdate, function()
      if not this.darkened then
        this.darkened = true
        DarkenFrame(this)
      end
    end)
  end
end
