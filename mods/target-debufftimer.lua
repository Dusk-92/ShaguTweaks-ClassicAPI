local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Debuff Timer"],
  description = T["Show debuff durations on the target unit frame."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = true,
})

local libdebuff = ShaguTweaks.libdebuff
local TimeConvert = ShaguTweaks.TimeConvert

local function GetLegacyDebuff(index)
  if libdebuff and libdebuff.UnitDebuff then
    return libdebuff:UnitDebuff("target", index)
  end
end

local function NormalizeAuraString(value)
  return value and value ~= "" and value or nil
end

local function ResolveDebuffTiming(name, icon, stacks, dtype, duration, expirationTime, index, now)
  icon = NormalizeAuraString(icon)
  dtype = NormalizeAuraString(dtype)
  duration = duration and duration > 0 and duration or nil

  if duration and expirationTime and expirationTime > 0 then
    local timeleft = expirationTime - now
    if timeleft < 0 then timeleft = 0 end
    return name, nil, icon, stacks, dtype, duration, timeleft
  end

  -- ClassicAPI always knows the aura metadata, but expiration can be unknown
  -- when the client did not observe its application. Keep ShaguTweaks' old
  -- estimate only for that missing-timing case.
  if duration then
    local effect, rank, texture, legacyStacks, legacyType,
      legacyDuration, legacyTimeleft = GetLegacyDebuff(index)
    if effect then
      return name or effect, rank, icon or texture, stacks or legacyStacks,
        dtype or legacyType, legacyDuration, legacyTimeleft
    end
  end

  -- Duration 0 is a permanent/indefinite aura. Keep its metadata visible but
  -- do not create a fake cooldown.
  return name, nil, icon, stacks, dtype, nil, -1
end

local function GetTargetDebuff(index, now)
  -- Prefer ClassicAPI's positional accessor: same useful aura/timing data as
  -- AuraData, but no temporary Lua table allocation for every debuff button.
  if API and API.aurapositional and API.UnitDebuff then
    local name, icon, stacks, dtype, duration, expirationTime =
      API.UnitDebuff("target", index)
    if name then
      return ResolveDebuffTiming(name, icon, stacks, dtype, duration,
        expirationTime, index, now)
    end
    return
  end

  -- Compatibility with older ClassicAPI builds that only expose AuraData.
  local aura = API and API.GetDebuffDataByIndex and
    API.GetDebuffDataByIndex("target", index)
  if aura then
    return ResolveDebuffTiming(aura.name, aura.icon, aura.applications,
      aura.dispelName, aura.duration, aura.expirationTime, index, now)
  end

  return GetLegacyDebuff(index)
end

local function CreateTextCooldown(cooldown)
  if cooldown.readable then return cooldown.readable end

  -- These overlays never need global frame names. Keeping them anonymous
  -- avoids collisions when several target debuffs are visible at once.
  cooldown.readable = CreateFrame("Frame", nil, cooldown:GetParent())
  cooldown.readable:SetAllPoints(cooldown)
  cooldown.readable:SetFrameLevel(cooldown:GetParent():GetFrameLevel() + 1)
  cooldown.readable.text = cooldown.readable:CreateFontString(nil, "OVERLAY")

  cooldown.readable.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
  cooldown.readable.text:SetPoint("CENTER", cooldown.readable, "CENTER", 0, 0)
  cooldown.readable:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + arg1
    if this.elapsed < .1 then return end
    this.elapsed = 0

    local parent = this:GetParent()
    if not parent then this:Hide() return end

    -- fix own alpha value (should be inherited, but somehow isn't always)
    this:SetAlpha(parent:GetAlpha())

    local remaining = this.duration - (GetTime() - this.start)
    if remaining >= 0 then
      this.text:SetText(TimeConvert(remaining))
    else
      this:Hide()
    end
  end)

  return cooldown.readable
end

module.enable = function(self)
  local HookTargetDebuffButton_Update = TargetDebuffButton_Update
  TargetDebuffButton_Update = function()
    HookTargetDebuffButton_Update()

    -- All buttons in this refresh share the same clock sample. Besides being
    -- cheaper, this keeps their displayed countdowns perfectly aligned.
    local now = GetTime()

    for i=1, MAX_TARGET_DEBUFFS do
      local effect, rank, texture, stacks, dtype, duration, timeleft =
        GetTargetDebuff(i, now)
      local button = _G["TargetFrameDebuff"..i]

      if button and not button.cd then
        button.cd = CreateFrame("Model", "TargetFrameDebuff"..i.."Cooldown", button, "CooldownFrameTemplate")
        button.cd.noCooldownCount = true
        button.cd:SetAllPoints()
        button.cd:SetScale(.6)
        button.cd:SetAlpha(.8)
      end

      local dCount = _G["TargetFrameDebuff" .. i .. "Count"]
      if button and dCount then
        if not dCount.fixup then
          dCount.fixup = true
          dCount:SetPoint("BOTTOMRIGHT", "TargetFrameDebuff" .. i, "BOTTOMRIGHT", 6, -3)
        end
        if stacks and stacks > 1 then
          dCount:SetText("|c0000ff3b" .. stacks)
          dCount:Show()
        else
          dCount:Hide()
        end
      end

      local dBorder = _G["TargetFrameDebuff" .. i .. "Border"]
      if button and dBorder then
        local color = dtype and DebuffTypeColor[dtype] or DebuffTypeColor["none"]
        dBorder:SetVertexColor(color.r, color.g, color.b)
      end

      if button and effect and duration and timeleft and timeleft >= 0 then
        local start = now + timeleft - duration
        local readable = CreateTextCooldown(button.cd)
        CooldownFrame_SetTimer(button.cd, start, duration, 1)
        readable.start = start
        readable.duration = duration
        readable.elapsed = 0
        readable.text:SetText(TimeConvert(timeleft))
        readable:Show()
        button.cd:Show()
      elseif button then
        CooldownFrame_SetTimer(button.cd,0,0,0)
        if button.cd.readable then button.cd.readable:Hide() end
      end
    end
  end
end
