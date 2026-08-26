-- SuperWoW compatibility
--
-- https://github.com/balakethelock/SuperWoW
--
-- This module adds GUID based cast and channel data to the
-- libcast library that is used to query enemy casting infos.

-- Skip module initialization if SuperWoW is not running.
if not GetPlayerBuffID or not CombatLogAdd or not SpellInfo then return end

local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Super WoW Compatibility"],
  description = T["Adds compatibility for the SuperWoW client mod."],
  expansions = { ["vanilla"] = true },
  category = T["General"],
  enabled = true,
})

module.enable = function(self)
  local libcast = ShaguTweaks.libcast

  local function ClearCast(cast)
    cast.cast = nil
    cast.rank = nil
    cast.start = nil
    cast.casttime = nil
    cast.icon = nil
    cast.channel = nil
    cast.spellID = nil
  end

  local unitcast = CreateFrame("Frame")
  unitcast:RegisterEvent("UNIT_CASTEVENT")
  unitcast:SetScript("OnEvent", function()
    local guid = arg1
    local event_type = arg3
    local spellID = arg4

    if not guid then return end

    if event_type == "START" or event_type == "CAST" or event_type == "CHANNEL" then
      -- human readable argument list
      local timer = arg5

      -- get spell info from spell id
      local spell, icon, _
      spell, _, icon = SpellInfo(spellID)

      -- set fallback values
      spell = spell or UNKNOWN
      icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"

      -- add cast action to the database
      local cast = libcast.db[guid]
      if not cast then
        cast = {}
        libcast.db[guid] = cast
      end

      cast.cast = spell
      cast.rank = nil
      cast.start = GetTime()
      cast.casttime = timer
      cast.icon = icon
      cast.channel = event_type == "CHANNEL" or false
      cast.spellID = spellID

      -- write state variable
      ShaguTweaks.superwow_active = true
    elseif event_type == "FAIL" then
      local cast = libcast.db[guid]

      -- Ignore a delayed FAIL for an older spell. Otherwise it can erase a
      -- newer cast from the same GUID that already replaced it in the cache.
      if cast and cast.spellID == spellID then
        ClearCast(cast)
      end
    end
  end)
end
