local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["XP Bar Text"],
  description = T["Shows current XP and rested bonus percentage while hovering over the experience bar."],
  expansions = { ["vanilla"] = true },
  category = T["Interface"],
  enabled = true,
  order = 70,
})

module.enable = function(self)
  -- Reuse the overlay if enable() is called again instead of stacking another
  -- frame and another event handler on top of the experience bar.
  if not self.exp then
    self.exp = CreateFrame("Frame", nil, UIParent)
    self.exp:SetAllPoints(MainMenuExpBar)
    self.exp:SetFrameStrata("HIGH")

    self.exp.text = self.exp:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    self.exp.text:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
    self.exp.text:SetPoint("CENTER", MainMenuExpBar, "CENTER", 0, 1)
    self.exp.text:SetJustifyH("CENTER")
    self.exp.text:SetTextColor(1, 1, 1)
  end

  local exp = self.exp
  exp.hovered = false
  exp.text:Hide()

  local function UpdateXPText()
    local curr = UnitXP("player")
    local max = UnitXPMax("player")
    if not max or max == 0 then
      if exp.text:IsShown() then exp.text:Hide() end
      self.lastText = nil
      return
    end

    local rest = GetXPExhaustion() or 0
    local xpPct = math.floor(curr / max * 100)

    local text
    if rest > 0 then
      -- Turtle WoW 1.18.1 reduced rested creature XP from +100% to +50%.
      -- The effective GetXPExhaustion full-rest threshold is about 112.5% of
      -- the current level XP, so normalize that pool to a 0-100% display.
      local restPct = math.floor(math.min(rest / (max * 1.125) * 100, 100))
      text = "|cffffffff" .. xpPct .. "%|r |cffaaaaaa(|cffa78aca" .. restPct .. "%|cffaaaaaa)|r"
    else
      text = "|cffffffff" .. xpPct .. "%|r"
    end

    if self.lastText ~= text then
      exp.text:SetText(text)
      self.lastText = text
    end

    if exp.hovered then
      if not exp.text:IsShown() then exp.text:Show() end
    elseif exp.text:IsShown() then
      exp.text:Hide()
    end
  end

  if not self.events then
    self.events = CreateFrame("Frame", nil, UIParent)
    self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.events:RegisterEvent("PLAYER_XP_UPDATE")
    self.events:RegisterEvent("UPDATE_EXHAUSTION")
    self.events:RegisterEvent("PLAYER_LEVEL_UP")
  end

  self.events:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      -- Hide Blizzard's default overlay that renders the original XP text.
      MainMenuBarOverlayFrame:Hide()
    end

    UpdateXPText()
  end)

  -- Reuse the XP bar's existing mouse handling instead of adding a permanent
  -- OnUpdate or a mouse-enabled overlay on top of it.
  if not self.mouseoverHooked then
    self.mouseoverHooked = true

    ShaguTweaks.HookScript(MainMenuExpBar, "OnEnter", function()
      exp.hovered = true
      UpdateXPText()
    end)

    ShaguTweaks.HookScript(MainMenuExpBar, "OnLeave", function()
      exp.hovered = false
      if exp.text:IsShown() then exp.text:Hide() end
    end)
  end

  -- Refresh immediately in case the module is enabled after entering the world.
  MainMenuBarOverlayFrame:Hide()
  UpdateXPText()
end
