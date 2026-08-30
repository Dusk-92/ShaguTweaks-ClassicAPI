local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local module = ShaguTweaks:register({
  title = T["Unit Frame Big Health"],
  description = T["Increases the healthbar of the player and target unitframe."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for i = 1, table.getn(tocs) do
  local current = string.format("ShaguTweaks%s", tocs[i])
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end
addonpath = addonpath or "Interface\\AddOns\\ShaguTweaks"

module.enable = function(self)
  local normalTexture = addonpath .. "\\img\\UI-TargetingFrame"
  local eliteTexture = addonpath .. "\\img\\UI-TargetingFrame-Elite"
  local rareTexture = addonpath .. "\\img\\UI-TargetingFrame-Rare"

  PlayerFrameTexture:SetTexture(normalTexture)
  PlayerFrameHealthBar:SetPoint("TOPLEFT", 106, -22)
  PlayerFrameHealthBar:SetHeight(30)

  PlayerStatusTexture:SetTexture(addonpath .. "\\img\\UI-Player-Status")

  TargetFrameTexture:SetTexture(normalTexture)
  TargetFrameHealthBar:SetPoint("TOPRIGHT", -106, -22)
  TargetFrameHealthBar:SetHeight(30)

  -- Dark mode is applied after the world has loaded. Keep this event separate
  -- from the one-frame deferred setup so the event cannot be unregistered early.
  local world = CreateFrame("Frame")
  world:RegisterEvent("PLAYER_ENTERING_WORLD")
  world:SetScript("OnEvent", function()
    ShaguTweaks.DarkenFrame(PlayerFrameTexture)
    ShaguTweaks.DarkenFrame(TargetFrameTexture)
    this:UnregisterAllEvents()
  end)

  -- Delay hook installation by one frame so all enabled unit-frame modules have
  -- finished their setup first. This keeps hooks attached to the final handlers.
  local deferred = CreateFrame("Frame")
  deferred:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    this:Hide()

    local function UpdateTargetClassificationTexture()
      local classification = UnitClassification("target")
      if classification == "worldboss" or classification == "rareelite" or classification == "elite" then
        TargetFrameTexture:SetTexture(eliteTexture)
      elseif classification == "rare" then
        TargetFrameTexture:SetTexture(rareTexture)
      else
        TargetFrameTexture:SetTexture(normalTexture)
      end
    end

    -- Let Blizzard and other addons finish classification handling, then apply
    -- the matching Big Health texture instead of replacing the global function.
    hooksecurefunc("TargetFrame_CheckClassification", UpdateTargetClassificationTexture)

    -- Big Health owns the compact value display while enabled. Keep Blizzard /
    -- Turtle status texts alive for compatibility, but make them invisible so
    -- their current/max or percent formats cannot overlap our centered values.
    local nativeTexts = {
      PlayerFrameHealthBar.TextString,
      PlayerFrameManaBar.TextString,
      TargetFrameHealthBar.TextString,
      TargetFrameManaBar.TextString,
      _G.TargetHPText,
      _G.TargetHPPercText,
    }

    for _, text in pairs(nativeTexts) do
      if text then text:SetAlpha(0) end
    end

    if not self.valueTexts then
      self.valueTexts = {}

      local function CreateValueText(parent, anchor, y)
        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        -- Match the compact unit-frame number style used by the former
        -- health-numbers module: Friz Quadrata, 10px, outlined.
        text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        text:SetHeight(32)
        text:ClearAllPoints()
        text:SetPoint("CENTER", anchor, "CENTER", 0, y or 0)
        text:SetJustifyH("CENTER")
        text:SetTextColor(1, 1, 1, 1)
        return text
      end

      self.valueTexts.playerHealth = CreateValueText(PlayerFrameHealthBar, PlayerFrameHealthBar, -7)
      self.valueTexts.playerMana = CreateValueText(PlayerFrameManaBar, PlayerFrameManaBar, 0)
      self.valueTexts.targetHealth = CreateValueText(TargetFrameHealthBar, TargetFrameHealthBar, -7)
      self.valueTexts.targetMana = CreateValueText(TargetFrameManaBar, TargetFrameManaBar, 0)
    end

    local function UpdateValueText(text, unit, power)
      if unit == "target" and not UnitExists("target") then
        text:Hide()
        return
      end

      local value
      local max
      if power == "health" then
        value = UnitHealth(unit)
        max = UnitHealthMax(unit)
      else
        value = UnitMana(unit)
        max = UnitManaMax(unit)
      end

      if not max or max <= 0 then
        text:Hide()
        return
      end

      text:SetText(tostring(value or 0))
      text:Show()
    end

    local function UpdateUnitValues(unit)
      if unit == "player" then
        UpdateValueText(self.valueTexts.playerHealth, "player", "health")
        UpdateValueText(self.valueTexts.playerMana, "player", "power")
      elseif unit == "target" then
        UpdateValueText(self.valueTexts.targetHealth, "target", "health")
        UpdateValueText(self.valueTexts.targetMana, "target", "power")
      end
    end

    if not self.valueEvents then
      self.valueEvents = CreateFrame("Frame")
      self.valueEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
      self.valueEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
      self.valueEvents:RegisterEvent("UNIT_HEALTH")
      self.valueEvents:RegisterEvent("UNIT_MAXHEALTH")
      self.valueEvents:RegisterEvent("UNIT_MANA")
      self.valueEvents:RegisterEvent("UNIT_MAXMANA")
      self.valueEvents:RegisterEvent("UNIT_RAGE")
      self.valueEvents:RegisterEvent("UNIT_MAXRAGE")
      self.valueEvents:RegisterEvent("UNIT_ENERGY")
      self.valueEvents:RegisterEvent("UNIT_MAXENERGY")
      self.valueEvents:RegisterEvent("UNIT_FOCUS")
      self.valueEvents:RegisterEvent("UNIT_MAXFOCUS")
      self.valueEvents:RegisterEvent("UNIT_HAPPINESS")
      self.valueEvents:RegisterEvent("UNIT_MAXHAPPINESS")
      self.valueEvents:RegisterEvent("UNIT_DISPLAYPOWER")

      self.valueEvents:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" then
          UpdateUnitValues("player")
          UpdateUnitValues("target")
        elseif arg1 == "player" or arg1 == "target" then
          UpdateUnitValues(arg1)
        end
      end)
    end

    UpdateUnitValues("player")
    UpdateUnitValues("target")

    -- DruidManaBar is a separate TextStatusBar used while shapeshifted.
    -- Its own update path writes "current / max". Post-hook the shared text
    -- formatter and only alter that one named bar, so load order does not matter.
    local function UpdateDruidManaBarText(bar)
      if not bar or not bar.GetName or bar:GetName() ~= "DruidManaBar" then return end

      local text = bar.text or bar.TextString
      if not text then return end

      if not bar.ShaguTweaksBigHealthText then
        bar.ShaguTweaksBigHealthText = true
        text:SetAlpha(1)
        text:SetFontObject("GameFontWhite")
        text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        text:SetHeight(32)
        text:ClearAllPoints()
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        text:SetTextColor(1, 1, 1, 1)
      end

      local value = bar:GetValue() or 0
      text:SetText(tostring(math.floor(value + 0.5)))
      text:Show()
    end

    hooksecurefunc("TextStatusBar_UpdateTextString", function(textStatusBar)
      UpdateDruidManaBarText(textStatusBar or this)
    end)

    -- Apply immediately when the bar already exists; otherwise its first normal
    -- TextStatusBar update will be caught by the hook above.
    local druidManaBar = getglobal and getglobal("DruidManaBar") or nil
    if druidManaBar then
      UpdateDruidManaBarText(druidManaBar)
    end

    local playerSetStatusBarColor = PlayerFrameHealthBar.SetStatusBarColor
    local targetSetStatusBarColor = TargetFrameHealthBar.SetStatusBarColor

    local function ApplyPlayerHealthColor()
      if not PlayerFrameNameBackground or not playerSetStatusBarColor then return end
      local r, g, b, a = PlayerFrameNameBackground:GetVertexColor()
      playerSetStatusBarColor(PlayerFrameHealthBar, r, g, b, a)
    end

    local function ApplyTargetHealthColor()
      if not TargetFrameNameBackground or not targetSetStatusBarColor then return end
      local r, g, b, a = TargetFrameNameBackground:GetVertexColor()
      targetSetStatusBarColor(TargetFrameHealthBar, r, g, b, a)
    end

    -- Keep the Big Health colors without replacing SetStatusBarColor with a
    -- no-op. Other addons may still call the original method normally.
    if PlayerFrameNameBackground then
      hooksecurefunc(PlayerFrameHealthBar, "SetStatusBarColor", ApplyPlayerHealthColor)
      hooksecurefunc(PlayerFrameNameBackground, "Show", function()
        PlayerFrameNameBackground:Hide()
      end)
      PlayerFrameNameBackground:Hide()
      ApplyPlayerHealthColor()
    end

    if TargetFrameNameBackground then
      hooksecurefunc(TargetFrameHealthBar, "SetStatusBarColor", ApplyTargetHealthColor)
      hooksecurefunc(TargetFrameNameBackground, "Show", function()
        TargetFrameNameBackground:Hide()
      end)
      TargetFrameNameBackground:Hide()
      ApplyTargetHealthColor()
    end

    -- Reapply the target health color after faction/class-color updates.
    hooksecurefunc("TargetFrame_CheckFaction", ApplyTargetHealthColor)

    -- Refresh once because the target frame may already have been initialized
    -- before this deferred setup ran.
    UpdateTargetClassificationTexture()
    TargetFrame_CheckFaction()
  end)
end
