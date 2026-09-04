local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["No Toggle Auto-Attack"],
  description = T["Keeps Auto Attack, Auto Shot, and Shoot active when re-pressed, preventing accidental cancellation."],
  expansions = { ["vanilla"] = true },
  category = T["Action Bar"],
  enabled = true,
  order = 12,
})

module.enable = function(self)
  -- This fork requires ClassicAPI. Do not retain the old tooltip/action-name
  -- scanners when the engine can identify auto-attack actions directly.
  if not API or not API.autoattack or not API.autoattackbook or not API.actioninfo then return end

  local attacking, shooting

  local attackNames = {
    ["attack"] = "melee",
    ["auto attack"] = "melee",
    ["auto shot"] = "ranged",
    ["shoot"] = "ranged",
  }

  local function AddAttackName(spellID, attackType)
    local name = API.GetSpellInfo(spellID)
    if name then attackNames[strlower(name)] = attackType end
  end

  -- CastSpellByName still receives text rather than a spellbook/action ID.
  -- Resolve the localized names once through ClassicAPI while retaining the
  -- common English aliases used by macros and third-party addons.
  AddAttackName(6603, "melee")
  AddAttackName(75, "ranged")
  AddAttackName(5019, "ranged")

  local combatFrame = CreateFrame("Frame")
  combatFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
  combatFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
  combatFrame:SetScript("OnEvent", function()
    attacking = event == "PLAYER_ENTER_COMBAT"
  end)

  local shootFrame = CreateFrame("Frame")
  shootFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
  shootFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
  shootFrame:SetScript("OnEvent", function()
    shooting = event == "START_AUTOREPEAT_SPELL"
  end)

  local function activeName(name)
    if not name then return false end
    local attackType = attackNames[strlower(name)]
    return (attackType == "melee" and attacking) or
      (attackType == "ranged" and shooting)
  end

  local function activeSpell(spellID)
    if not spellID then return false end
    return (API.IsAutoAttackSpell(spellID) and attacking) or
      (API.IsRangedAutoAttackSpell(spellID) and shooting)
  end

  local function activeSpellBook(index, booktype)
    return (API.IsAutoAttackSpellBookItem(index, booktype) and attacking) or
      (API.IsRangedAutoAttackSpellBookItem(index, booktype) and shooting)
  end

  local origCastSpell = CastSpell
  function _G.CastSpell(index, booktype)
    if activeSpellBook(index, booktype) then return end
    return origCastSpell(index, booktype)
  end

  local origCastSpellByName = CastSpellByName
  function _G.CastSpellByName(text, onself)
    local spellID = tonumber(text)
    if activeSpell(spellID) or activeName(text) then return end
    return origCastSpellByName(text, onself)
  end

  local origUseAction = UseAction
  function _G.UseAction(slot, clicked, onself)
    local actionType, spellID = API.GetActionInfo(slot)
    if actionType == "spell" and activeSpell(spellID) then return end
    return origUseAction(slot, clicked, onself)
  end
end
