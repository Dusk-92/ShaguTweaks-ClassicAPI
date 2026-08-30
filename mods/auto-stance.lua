local T = ShaguTweaks.T
local cmatch = ShaguTweaks.cmatch

local module = ShaguTweaks:register({
  title = T["Auto Stance"],
  description = T["Automatically switch to the required warrior or druid stance on spell cast."],
  expansions = { ["vanilla"] = true },
  category = T["Action Bar"],
  enabled = true,
})

module.enable = function(self)
  local stancedance = CreateFrame("Frame", "ShaguTweaksStancedance")
  stancedance:RegisterEvent("UI_ERROR_MESSAGE")
  stancedance:SetScript("OnEvent", function()
    if not arg1 then return end

    -- Parse the localized Blizzard format through ShaguTweaks' sanitized
    -- formatter instead of building a raw Lua pattern from the locale string.
    local stances = cmatch(arg1, SPELL_FAILED_ONLY_SHAPESHIFT)
    if not stances then return end

    -- The client can return several acceptable forms separated by commas.
    -- Iterate them directly instead of allocating the strsplit result and a
    -- second temporary table for every unrelated UI error message.
    for stance in string.gfind(stances, "[^,]+") do
      stance = string.gsub(stance, "^%s*(.-)%s*$", "%1")
      if stance ~= "" then
        CastSpellByName(stance)
      end
    end
  end)
end
