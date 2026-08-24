local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
    title = T["Range Color"],
    description = T["Action buttons will be colored red when out of range."],
    expansions = { ["vanilla"] = true },
    category = T["Action Bar"],
    enabled = nil,
})

local rangeTooltip

local function SpellRange(spellID)
    if not spellID or not API or not API.IsSpellInRange then return end

    local inRange = API.IsSpellInRange(spellID, "target")
    if inRange ~= nil then
        return inRange and 1 or 0
    end
end

local function GetDisplayedActionSpell(action)
    -- GetMacroSpell() only exposes the macro parser's cached primary spell.
    -- For conditional macros (#showtooltip + [stealth]/[behind]/etc.), ask the
    -- action tooltip which spell the client is displaying right now instead.
    -- ClassicAPI's GameTooltip:GetSpell() then gives us the resolved spellID.
    if not _G.GameTooltip or type(_G.GameTooltip.GetSpell) ~= "function" then return end

    if not rangeTooltip then
        rangeTooltip = CreateFrame("GameTooltip", "ShaguTweaksRangeTooltip", UIParent, "GameTooltipTemplate")
        rangeTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    rangeTooltip:ClearLines()
    rangeTooltip:SetAction(action)
    local _, _, spellID = rangeTooltip:GetSpell()
    rangeTooltip:Hide()
    return spellID
end

local function GetActionRange(action)
    -- ClassicAPI resolves the action to its real spell/item/macro descriptor.
    if API and API.GetActionInfo then
        local actionType, id = API.GetActionInfo(action)

        if actionType == "spell" and id then
            local result = SpellRange(id)
            if result ~= nil then return result end
        elseif actionType == "macro" and id then
            -- Macro addons such as SuperCleveRoidMacros override
            -- IsActionInRange() specifically so their own conditional parser
            -- can choose the currently active spell ([behind], [stealth], etc.).
            -- Let that authoritative macro-aware result win before trying
            -- ClassicAPI's generic macro fallbacks.
            local macroRange = IsActionInRange(action, "target")
            if macroRange ~= nil then
                return macroRange
            end

            -- Generic fallback for ordinary macros that are not handled by a
            -- dedicated macro addon: try the currently displayed action spell.
            local spellID = GetDisplayedActionSpell(action)

            -- Macros without a resolvable dynamic tooltip keep the cheaper
            -- primary-spell reader as a compatibility fallback.
            if not spellID and API.GetMacroSpell then
                local _, _, primarySpellID = API.GetMacroSpell(id)
                spellID = primarySpellID
            end

            local result = SpellRange(spellID)
            if result ~= nil then return result end
        elseif actionType == "item" and id and API.IsItemInRange then
            local inRange = API.IsItemInRange(id, "target")
            if inRange ~= nil then
                return inRange and 1 or 0
            end
        end
    end

    -- Unresolved actions and older ClassicAPI versions retain the native
    -- action-slot check as a compatibility fallback.
    return IsActionInRange(action, "target")
end

module.enable = function(self)
    hooksecurefunc("ActionButton_OnUpdate", function(elapsed)
        if this.rangeTimer then
            this.rangeTimer = this.rangeTimer - elapsed
            if this.rangeTimer <= 0.2 then
                local action = ActionButton_GetPagedID(this)
                local inRange = GetActionRange(action)
                local icon = _G[this:GetName() .. "Icon"]

                if icon then
                    if inRange == 0 then
                        if not this.a then
                            this.r, this.g, this.b, this.a = 0.85, 0.18, 0.18, 1
                        end
                        icon:SetVertexColor(this.r, this.g, this.b, this.a)
                    elseif IsUsableAction(action) then
                        icon:SetVertexColor(1, 1, 1, 1)
                    end
                end

                this.rangeTimer = TOOLTIP_UPDATE_TIME
            end
        end
    end, true)
end
