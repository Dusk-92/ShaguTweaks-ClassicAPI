local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local module = ShaguTweaks:register({
  title = T["Hide Tracking Icon"],
  description = T["Hides the tracking icon from the minimap."],
  expansions = { ["vanilla"] = true },
  category = T["World & MiniMap"],
  enabled = true,
  order = 74,
})

module.enable = function(self)
  -- Keep the tracking icon hidden without replacing its Show method. This
  -- preserves Blizzard/Turtle and addon behavior while applying our visual
  -- preference after every attempted show.
  hooksecurefunc(MiniMapTrackingFrame, "Show", function()
    MiniMapTrackingFrame:Hide()
  end)

  MiniMapTrackingFrame:Hide()
end
