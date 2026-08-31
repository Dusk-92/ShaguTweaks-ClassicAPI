local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Blue Shaman Class Colors"],
  description = T["Changes the class color code of shamans to blue, as known from TBC+."],
  expansions = { ["vanilla"] = true },
  category = T["Chat & Social"],
  enabled = nil,
})

module.enable = function(self)
  -- Keep the existing RAID_CLASS_COLORS table and SHAMAN entry whenever
  -- possible. Replacing the whole table, as the original module did, can break
  -- addons that cached either table reference before VARIABLES_LOADED.
  RAID_CLASS_COLORS = RAID_CLASS_COLORS or {}

  local color = RAID_CLASS_COLORS["SHAMAN"]
  if not color then
    color = {}
    RAID_CLASS_COLORS["SHAMAN"] = color
  end

  color.r = 0.14
  color.g = 0.35
  color.b = 1.0
  color.colorStr = "ff2459ff"
end
