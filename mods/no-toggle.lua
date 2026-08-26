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
  local attacking, shooting

  local attackNames = {
    ["attack"] = "melee",
    ["auto attack"] = "melee",
    ["auto shot"] = "ranged",
    ["shoot"] = "ranged",
  }

  local function AddAttackName(spellID, attackType)
    if not API or not API.GetSpellInfo then return end
    local name = API.GetSpellInfo(spellID)
    if name then attackNames[strlower(name)] = attackType end
  end

  -- Add the current client's localized spell names while retaining the
  -- original English aliases for the legacy fallback.
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
    if not API or not API.autoattack or not spellID then return false end
    return (API.IsAutoAttackSpell(spellID) and attacking) or
      (API.IsRangedAutoAttackSpell(spellID) and shooting)
  end

  local function activeSpellBook(index, booktype)
    if API and API.autoattackbook then
      return (API.IsAutoAttackSpellBookItem(index, booktype) and attacking) or
        (API.IsRangedAutoAttackSpellBookItem(index, booktype) and shooting)
    end

    return activeName(GetSpellName(index, booktype))
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

  local tt
  local function GetLegacyTooltip()
    if tt then return tt end
    tt = CreateFrame("GameTooltip", "ShaguTweaksNoToggleTT", nil, "GameTooltipTemplate")
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    return tt
  end

  local origUseAction = UseAction
  function _G.UseAction(slot, clicked, onself)
    if API and API.actioninfo and API.autoattack then
      local actionType, spellID = API.GetActionInfo(slot)
      if actionType == "spell" and activeSpell(spellID) then return end
      if actionType then return origUseAction(slot, clicked, onself) end
    end

    -- Legacy clients have no action descriptor API. Keep the tooltip scan as
    -- a fallback only, instead of paying for it on every spell/item action.
    if HasAction(slot) and not GetActionText(slot) then
      local tt = GetLegacyTooltip()
      tt:SetOwner(UIParent, "ANCHOR_NONE")
      tt:SetAction(slot)
      local label = _G["ShaguTweaksNoToggleTTTextLeft1"]
      if label and activeName(label:GetText()) then return end
    end
    return origUseAction(slot, clicked, onself)
  end
end
