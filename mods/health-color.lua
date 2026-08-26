local T = ShaguTweaks.T
local GetColorGradient = ShaguTweaks.GetColorGradient
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local module = ShaguTweaks:register({
  title = T["Unit Frame Health Colors"],
  description = T["Change health text color based on its value."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local function SetTextColorIfChanged(fontString, r, g, b, a)
  local cr, cg, cb, ca = fontString:GetTextColor()
  if cr ~= r or cg ~= g or cb ~= b or ca ~= a then
    fontString:SetTextColor(r, g, b, a)
  end
end

module.enable = function(self)
  local function UpdateManaTextColor(uf)
    if not uf then uf = this end
    if not uf or not uf.manabar or not uf.manabar.TextString then return end

    local name = uf.manabar:GetName()
    if name and not strfind(name, "Health") then
      local r, g, b = uf.manabar:GetStatusBarColor()
      SetTextColorIfChanged(uf.manabar.TextString,
        (r + 2) / 3, (g + 2) / 3, (b + 2) / 3, 1)
    end
  end

  local function UpdateHealthTextColor(sb)
    if not sb then sb = this end
    if not sb or not sb.TextString or not sb.unit then return end

    local name = sb:GetName()
    if not name or not strfind(name, "Health") then return end

    local _, max = sb:GetMinMaxValues()
    local cur = sb:GetValue()
    local percent = max > 0 and floor(cur / max * 100) or 0
    local r, g, b = GetColorGradient(percent / 100)

    SetTextColorIfChanged(sb.TextString,
      (r + 1) / 2, (g + 1) / 2, (b + 1) / 2, .75)
  end

  -- Append our color adjustments instead of replacing Blizzard's global
  -- functions. This keeps the module cooperative with other UI addons.
  hooksecurefunc("UnitFrame_UpdateManaType", UpdateManaTextColor)
  hooksecurefunc("TextStatusBar_UpdateTextString", UpdateHealthTextColor)
end
