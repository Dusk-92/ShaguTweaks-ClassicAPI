local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local Abbreviate = ShaguTweaks.Abbreviate
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local module = ShaguTweaks:register({
  title = T["Real Health Numbers"],
  description = T["Shows health and power numbers on player, pet and target unit frames. On Vanilla servers, target health may be estimated when exact values are unavailable."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

module.enable = function(self)
  if ShaguTweaks.RealHealthNumbersInstalled then return end
  ShaguTweaks.RealHealthNumbersInstalled = true

  if ShaguTweaks.libhealth and ShaguTweaks.libhealth.Enable then
    ShaguTweaks.libhealth:Enable()
  end

  local function HideNativeText(text)
    if text and text.SetAlpha then
      text:SetAlpha(0)
    end
  end

  local nativeTexts = {
    PlayerFrameHealthBar and PlayerFrameHealthBar.TextString,
    PlayerFrameManaBar and PlayerFrameManaBar.TextString,
    TargetFrameHealthBar and TargetFrameHealthBar.TextString,
    TargetFrameManaBar and TargetFrameManaBar.TextString,
    PetFrameHealthBar and PetFrameHealthBar.TextString,
    PetFrameManaBar and PetFrameManaBar.TextString,
    _G.PlayerFrameAlternatePowerBarText,
    _G.TargetHPText,
    _G.TargetHPPercText,
  }

  for _, text in pairs(nativeTexts) do
    HideNativeText(text)
  end

  self.valueTexts = self.valueTexts or {}

  local function CreateValueText(parent, fontSize)
    if not parent then return end

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    text:SetFont(STANDARD_TEXT_FONT, fontSize or 10, "OUTLINE")
    text:SetHeight(32)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 1, 1, 1)
    return text
  end

  local function AnchorText(text, bar, y)
    if not text or not bar then return end

    text:ClearAllPoints()
    text:SetPoint("CENTER", bar, "CENTER", 0, y or 0)
  end

  if not self.valueTexts.playerHealth then
    self.valueTexts.playerHealth = CreateValueText(PlayerFrameHealthBar, 10)
    self.valueTexts.playerMana = CreateValueText(PlayerFrameManaBar, 10)
    self.valueTexts.targetHealth = CreateValueText(TargetFrameHealthBar, 10)
    self.valueTexts.targetMana = CreateValueText(TargetFrameManaBar, 10)

    if PetFrameHealthBar then
      self.valueTexts.petHealth = CreateValueText(PetFrameHealthBar, 9)
    end

    if PetFrameManaBar then
      self.valueTexts.petMana = CreateValueText(PetFrameManaBar, 9)
    end

    if _G.PlayerFrameAlternatePowerBar then
      self.valueTexts.playerAlternatePower =
        CreateValueText(_G.PlayerFrameAlternatePowerBar, 10)
    end
  end

  local function PositionTexts()
    local playerHealthY = PlayerFrameHealthBar:GetHeight() >= 20 and -7 or 0
    local targetHealthY = TargetFrameHealthBar:GetHeight() >= 20 and -7 or 0

    AnchorText(self.valueTexts.playerHealth, PlayerFrameHealthBar, playerHealthY)
    AnchorText(self.valueTexts.playerMana, PlayerFrameManaBar, 0)
    AnchorText(self.valueTexts.targetHealth, TargetFrameHealthBar, targetHealthY)
    AnchorText(self.valueTexts.targetMana, TargetFrameManaBar, 0)
    AnchorText(self.valueTexts.petHealth, PetFrameHealthBar, 0)
    AnchorText(self.valueTexts.petMana, PetFrameManaBar, -2)

    if _G.PlayerFrameAlternatePowerBar then
      AnchorText(
        self.valueTexts.playerAlternatePower,
        _G.PlayerFrameAlternatePowerBar,
        0
      )
    end
  end

  local function SetValue(text, value)
    if not text then return end

    if value == nil then
      text:SetText("")
      text:Hide()
      return
    end

    text:SetText(tostring(Abbreviate(value)))
    text:Show()
  end

  local function UpdateHealth(text, unit, useEstimator)
    if not text then return end

    if not UnitExists(unit) then
      text:SetText("")
      text:Hide()
      return
    end

    if unit == "target" and (UnitIsDead("target") or UnitIsGhost("target")) then
      text:SetText("")
      text:Hide()
      return
    end

    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    local known = true

    if useEstimator and ShaguTweaks.libhealth
      and ShaguTweaks.libhealth.GetUnitHealth then
      cur, max, known = ShaguTweaks.libhealth:GetUnitHealth(unit)
    end

    if not max or max <= 0 then
      text:SetText("")
      text:Hide()
      return
    end

    if useEstimator and not known and max == 100 then
      text:SetText(tostring(cur or 0) .. "%")
      text:Show()
      return
    end

    SetValue(text, cur or 0)
  end

  local function UpdatePower(text, unit)
    if not text then return end

    if not UnitExists(unit) then
      text:SetText("")
      text:Hide()
      return
    end

    local max = UnitManaMax(unit)
    if not max or max <= 0 then
      text:SetText("")
      text:Hide()
      return
    end

    SetValue(text, UnitMana(unit) or 0)
  end

  local function UpdatePlayer()
    UpdateHealth(self.valueTexts.playerHealth, "player", false)
    UpdatePower(self.valueTexts.playerMana, "player")
  end

  local function UpdateTarget()
    UpdateHealth(self.valueTexts.targetHealth, "target", true)
    UpdatePower(self.valueTexts.targetMana, "target")
  end

  local function UpdatePet()
    UpdateHealth(self.valueTexts.petHealth, "pet", false)
    UpdatePower(self.valueTexts.petMana, "pet")
  end

  local function UpdateAlternatePower()
    local bar = _G.PlayerFrameAlternatePowerBar
    local text = self.valueTexts.playerAlternatePower
    if not bar or not text then return end

    if not bar:IsShown() then
      text:SetText("")
      text:Hide()
      return
    end

    local _, max = bar:GetMinMaxValues()
    if not max or max <= 0 then
      text:SetText("")
      text:Hide()
      return
    end

    local value = bar:GetValue() or 0
    SetValue(text, math.floor(value + 0.5))
  end

  self.valueEvents = self.valueEvents or CreateFrame("Frame")
  local events = self.valueEvents

  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PET_UI_UPDATE")
  events:RegisterEvent("UNIT_HEALTH")
  events:RegisterEvent("UNIT_MAXHEALTH")
  events:RegisterEvent("UNIT_MANA")
  events:RegisterEvent("UNIT_MAXMANA")
  events:RegisterEvent("UNIT_RAGE")
  events:RegisterEvent("UNIT_MAXRAGE")
  events:RegisterEvent("UNIT_ENERGY")
  events:RegisterEvent("UNIT_MAXENERGY")
  events:RegisterEvent("UNIT_FOCUS")
  events:RegisterEvent("UNIT_MAXFOCUS")
  events:RegisterEvent("UNIT_HAPPINESS")
  events:RegisterEvent("UNIT_MAXHAPPINESS")
  events:RegisterEvent("UNIT_DISPLAYPOWER")

  events:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      PositionTexts()
      UpdatePlayer()
      UpdateTarget()
      UpdatePet()
      UpdateAlternatePower()
    elseif event == "PLAYER_TARGET_CHANGED" then
      UpdateTarget()
    elseif event == "PET_UI_UPDATE" then
      UpdatePet()
    elseif arg1 == "player" then
      UpdatePlayer()
      UpdateAlternatePower()
    elseif arg1 == "target" then
      UpdateTarget()
    elseif arg1 == "pet" then
      UpdatePet()
    end
  end)

  local alternatePowerBar = _G.PlayerFrameAlternatePowerBar
  if alternatePowerBar and self.valueTexts.playerAlternatePower then
    hooksecurefunc(alternatePowerBar, "SetValue", UpdateAlternatePower)
    hooksecurefunc(alternatePowerBar, "Show", UpdateAlternatePower)
    hooksecurefunc(alternatePowerBar, "Hide", UpdateAlternatePower)
  end

  -- All enabled modules are initialized during VARIABLES_LOADED in an
  -- unspecified table order. Reposition once on the next frame so this module
  -- automatically fits either the stock bars or Unit Frame Big Health.
  local deferred = CreateFrame("Frame")
  deferred:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    this:Hide()

    PositionTexts()

    for _, text in pairs(nativeTexts) do
      HideNativeText(text)
    end

    UpdatePlayer()
    UpdateTarget()
    UpdatePet()
    UpdateAlternatePower()
  end)
end
