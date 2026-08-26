local T = ShaguTweaks.T
local Abbreviate = ShaguTweaks.Abbreviate
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local module = ShaguTweaks:register({
  title = T["Real Health Numbers"],
  description = T["Estimates health numbers, and shows numbers on player, pet and target unit frames."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = false,
})

local function SetStatusText(fontString, text)
  if fontString:GetText() ~= text then
    fontString:SetText(text)
  end
  fontString:Show()
end

local function HideStatusText(fontString)
  fontString:Hide()
  if fontString:GetText() ~= "" then
    fontString:SetText("")
  end
end

module.enable = function(self)
  TargetFrame.StatusTexts = CreateFrame("Frame", nil, TargetFrame)
  TargetFrame.StatusTexts:SetAllPoints(TargetFrame)

  TargetFrameHealthBar.TextString = TargetFrame.StatusTexts:CreateFontString("TargetFrameHealthBarText", "OVERLAY")
  TargetFrameHealthBar.TextString:SetPoint("TOP", TargetFrameHealthBar, "BOTTOM", -2, 23)

  TargetFrameManaBar.TextString = TargetFrame.StatusTexts:CreateFontString("TargetFrameManaBarText", "OVERLAY")
  TargetFrameManaBar.TextString:SetPoint("TOP", TargetFrameManaBar, "BOTTOM", -2, 22)

  PetFrameHealthBar.TextString:SetPoint("CENTER", PetFrameHealthBar, "CENTER", -2, 0)
  PetFrameManaBar.TextString:SetPoint("CENTER", PetFrameManaBar, "CENTER", -2, -2)

  local largeBars = { TargetFrameHealthBar, TargetFrameManaBar, PlayerFrameHealthBar, PlayerFrameManaBar }
  for i = 1, table.getn(largeBars) do
    local frame = largeBars[i]
    frame.TextString:SetFontObject("GameFontWhite")
    frame.TextString:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    frame.TextString:SetHeight(32)
  end

  local petBars = { PetFrameHealthBar, PetFrameManaBar }
  for i = 1, table.getn(petBars) do
    local frame = petBars[i]
    frame.TextString:SetFontObject("GameFontWhite")
    frame.TextString:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    frame.TextString:SetHeight(32)
    frame.TextString:SetJustifyH("LEFT")
  end

  local function UpdateHealthText(sb)
    if not sb then sb = this end
    if not sb or not sb.TextString or not sb.unit then return end

    sb.lockShow = 42
    sb:Show()

    local min, max = sb:GetMinMaxValues()
    local cur = sb:GetValue()
    local percent = max > 0 and floor(cur / max * 100) or 0
    local name = sb:GetName() or ""

    if name == "TargetFrameHealthBar" then
      cur, max = ShaguTweaks.libhealth:GetUnitHealth(sb.unit)
    end

    local text
    if cur == percent and strfind(name, "Health") then
      text = percent .. "/" .. percent
    elseif name == "TargetFrameHealthBar" and cur < max then
      text = Abbreviate(cur) .. "/" .. Abbreviate(max) .. " - " .. percent .. "%"
    else
      text = Abbreviate(cur) .. "/" .. Abbreviate(max)
    end

    if max == 0 or
      (sb.unit == "target" and (UnitIsDead("target") or UnitIsGhost("target"))) then
      HideStatusText(sb.TextString)
    else
      SetStatusText(sb.TextString, text)
    end
  end

  -- Append our custom text update instead of replacing the global Blizzard
  -- function. This keeps the module cooperative with other UI addons that also
  -- hook TextStatusBar_UpdateTextString.
  hooksecurefunc("TextStatusBar_UpdateTextString", UpdateHealthText)
end
