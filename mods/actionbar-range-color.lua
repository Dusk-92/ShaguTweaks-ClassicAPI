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

local function GetActionRange(action)
    -- ClassicAPI can resolve a real spell/item action and run the same
    -- range-only engine test directly against the target unit. This avoids
    -- relying on the old action-slot heuristic for normal spell buttons.
    if API and API.GetActionInfo then
        local actionType, id = API.GetActionInfo(action)

        if actionType == "spell" and id and API.IsSpellInRange then
            local inRange = API.IsSpellInRange(id, "target")
            if inRange ~= nil then
                return inRange and 1 or 0
            end
        elseif actionType == "item" and id and API.IsItemInRange then
            local inRange = API.IsItemInRange(id, "target")
            if inRange ~= nil then
                return inRange and 1 or 0
            end
        end
    end

    -- Macros, unresolved bag-item actions and older ClassicAPI versions keep
    -- Vanilla's native action-slot range check as the compatibility fallback.
    return IsActionInRange(action)
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
