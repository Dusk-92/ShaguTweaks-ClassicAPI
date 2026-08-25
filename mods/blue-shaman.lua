local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Blue Shaman Class Colors"],
  description = T["Changes the class color code of shamans to blue, as known from TBC+."],
  expansions = { ["vanilla"] = true },
  category = T["Social & Chat"],
  enabled = true,
})

local BLUE_SHAMAN = { r = 0.14, g = 0.35, b = 1.0, colorStr = "ff2459ff" }
local UNKNOWN_CLASS_COLOR = { r = 0.6, g = 0.6, b = 0.6, colorStr = "ff999999" }

local function ChatTweaksOwnsClassColors()
  local configured = ShaguTweaks_config and ShaguTweaks_config[T["Chat Tweaks"]]
  if configured ~= nil then return configured == 1 end

  -- On a fresh install config defaults are initialized while modules are
  -- enabled, so fall back to the registered module default when needed.
  local chat = ShaguTweaks.mods and ShaguTweaks.mods[T["Chat Tweaks"]]
  return chat and chat.enabled or false
end

module.enable = function(self)
  -- The current enhanced Chat Tweaks module already applies the same shaman
  -- color. Avoid touching the global table twice while keeping this module
  -- independent when Chat Tweaks is disabled.
  if ChatTweaksOwnsClassColors() then return end

  -- Keep Blizzard/Turtle's RAID_CLASS_COLORS table (and any references held by
  -- other addons) intact. Only change the SHAMAN entry instead of replacing
  -- the complete table just to alter one class color.
  RAID_CLASS_COLORS = RAID_CLASS_COLORS or {}
  local shaman = RAID_CLASS_COLORS["SHAMAN"]
  if shaman then
    shaman.r = BLUE_SHAMAN.r
    shaman.g = BLUE_SHAMAN.g
    shaman.b = BLUE_SHAMAN.b
    shaman.colorStr = BLUE_SHAMAN.colorStr
  else
    RAID_CLASS_COLORS["SHAMAN"] = {
      r = BLUE_SHAMAN.r,
      g = BLUE_SHAMAN.g,
      b = BLUE_SHAMAN.b,
      colorStr = BLUE_SHAMAN.colorStr,
    }
  end

  -- Preserve any metatable installed by Turtle or another addon. The original
  -- module supplied a gray fallback for unknown class keys, so retain that
  -- behavior only when no owner already provides one.
  if not getmetatable(RAID_CLASS_COLORS) then
    setmetatable(RAID_CLASS_COLORS, { __index = function()
      return UNKNOWN_CLASS_COLOR
    end })
  end
end
