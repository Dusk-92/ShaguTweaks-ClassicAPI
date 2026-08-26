local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc
local GetExpansion = ShaguTweaks.GetExpansion
local TimeConvert = ShaguTweaks.TimeConvert

local module = ShaguTweaks:register({
  title = T["Cooldown Numbers"],
  description = T["Display  the remaining duration as text on every cooldown."],
  expansions = { ["vanilla"] = true },
  category = T["Action Bar"],
  enabled = true,
  color = { r = .3, g = .3, b = .3, a = .9}
})

-- GetTime() wraps after 2^32 milliseconds on affected clients. Cooldown start
-- values keep that wrapped clock representation, so normalize negative deltas
-- by one complete clock cycle.
local TIMER_WRAP_SECONDS = (2 ^ 32) / 1000

local function CooldownOnUpdate()
  -- hide frames without parent
  local parent = this:GetParent()
  if not parent then
    this:Hide()
    return
  end

  -- Text only needs tenth-of-a-second precision. Accumulate the frame elapsed
  -- time instead of calling GetTime() several times on every rendered frame.
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed < .1 then return end
  this.elapsed = 0

  local now = GetTime()

  -- fix own alpha value (should be inherited, but somehow isn't always)
  local alpha = parent:GetAlpha()
  if this:GetAlpha() ~= alpha then
    this:SetAlpha(alpha)
  end

  local elapsed = now - this.start
  if elapsed < 0 then
    elapsed = elapsed + TIMER_WRAP_SECONDS
  end

  local remaining = this.duration - elapsed
  if remaining > 0 then
    local text = TimeConvert(remaining)
    if this.lastText ~= text then
      this.lastText = text
      this.text:SetText(text)
    end
  else
    this:Hide()
  end
end

local function CreateCoolDown(cooldown)
  local parent = cooldown:GetParent()
  if not parent then return end

  -- skip already set debuff timers
  if cooldown.readable then return end

  -- These helpers are owned directly by their cooldown and never need global
  -- names. Anonymous objects avoid collisions for cooldowns with anonymous
  -- parents while preserving the exact same visual hierarchy.
  cooldown.cooldowntext = CreateFrame("Frame", nil, cooldown)
  cooldown.cooldowntext:SetAllPoints(cooldown)
  cooldown.cooldowntext:SetFrameLevel(parent:GetFrameLevel() + 1)
  cooldown.cooldowntext.text = cooldown.cooldowntext:CreateFontString(nil, "OVERLAY")

  -- detect dynamic font size
  local size = parent:GetHeight() or 0
  size = size > 0 and size * .64 or 12
  size = size > 14 and 14 or size

  -- set fonts
  cooldown.cooldowntext.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
  cooldown.cooldowntext.text:SetPoint("CENTER", cooldown.cooldowntext, "CENTER", 0, 0)
  cooldown.cooldowntext:SetScript("OnUpdate", CooldownOnUpdate)
end

local function SetCooldown(this, start, duration, enable)
  -- Let OmniCC and ShaguPlates own their cooldown text. Also hide an overlay
  -- that may have been created before either compatibility flag was applied.
  if this.noCooldownCount or this.pfCooldownType then
    if this.cooldowntext then
      this.cooldowntext:Hide()
    end
    return
  end

  -- don't draw global cooldowns
  if not duration or duration < 2 then
    -- hide if already existing
    if this.cooldowntext then
      this.cooldowntext:Hide()
    end

    return
  end

  if not this.cooldowntext then
    CreateCoolDown(this)
  end

  if this.cooldowntext then
    if start > 0 and duration > 0 and (not enable or enable > 0) then
      this.cooldowntext.elapsed = 0
      this.cooldowntext:Show()
    else
      this.cooldowntext:Hide()
    end

    this.cooldowntext.start = start
    this.cooldowntext.duration = duration
  end
end

module.enable = function(self)
  if GetExpansion() == "vanilla" then
    -- vanilla does not have a cooldown frame type, so we hook the
    -- regular SetTimer function that each one is calling.
    hooksecurefunc("CooldownFrame_SetTimer", SetCooldown)
  else
    -- tbc and later expansion have a cooldown frametype, so we can
    -- hook directly into the frame creation and add our function there.
    local methods = getmetatable(CreateFrame('Cooldown', nil, nil, 'CooldownFrameTemplate')).__index
    hooksecurefunc(methods, 'SetCooldown', SetCooldown)
  end
end
