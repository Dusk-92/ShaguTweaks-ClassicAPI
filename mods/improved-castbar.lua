local T = ShaguTweaks.T

local module = ShaguTweaks:register({
    title = T["Improved Castbar"],
    description = T["Adds a spell icon and remaining cast time to the cast bar."],
    expansions = { ["vanilla"] = true },
    category = T["General"],
    enabled = nil,
})

module.enable = function(self)
    local _G = ShaguTweaks.GetGlobalEnv()
    local API = ShaguTweaks.API
    local LegacyCastingInfo = ShaguTweaks.UnitCastingInfo
    local LegacyChannelInfo = ShaguTweaks.UnitChannelInfo

    local castbar = CreateFrame("FRAME", "STImprovedCastbar", CastingBarFrame)
    castbar:Hide()

    castbar.texture = CreateFrame("Frame", nil, castbar)
    castbar.texture:SetPoint("RIGHT", CastingBarFrame, "LEFT", -10, 2)
    castbar.texture:SetWidth(28)
    castbar.texture:SetHeight(28)

    castbar.texture.icon = castbar.texture:CreateTexture(nil, "BACKGROUND")
    castbar.texture.icon:SetPoint("CENTER", 0, 0)
    castbar.texture.icon:SetWidth(24)
    castbar.texture.icon:SetHeight(24)
    castbar.texture:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    if ShaguTweaks.DarkMode then
        castbar.texture:SetBackdropBorderColor(.3, .3, .3, .9)
    end

    castbar.spellText = castbar:CreateFontString(nil, "HIGH", "GameFontWhite")
    castbar.spellText:SetPoint("CENTER", CastingBarFrame, "CENTER", 0, 3)
    local font, size, opts = castbar.spellText:GetFont()
    castbar.spellText:SetFont(font, size, "THINOUTLINE")

    castbar.timerText = castbar:CreateFontString(nil, "HIGH", "GameFontWhite")
    castbar.timerText:SetPoint("RIGHT", CastingBarFrame, "RIGHT", -5, 3)
    castbar.timerText:SetFont(font, size, "THINOUTLINE")

    CastingBarText:Hide()

    local function QueryPlayerCast()
        if API and API.casts then
            local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = API.GetCastInfo("player")
            if cast then
                return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
            end

            local channel
            channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill = API.GetChannelInfo("player")
            if channel then
                return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
            end
        end

        local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill = LegacyCastingInfo("player")
        if cast then
            return cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, false
        end

        local channel
        channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill = LegacyChannelInfo("player")
        if channel then
            return channel, nameSubtext, text, texture, startTime, endTime, isTradeSkill, true
        end
    end

    local function UpdateTimer()
        castbar:SetAlpha(CastingBarFrame:GetAlpha())

        local startTime = castbar.startTime
        local endTime = castbar.endTime
        if not startTime or not endTime or endTime <= startTime then
            if CastingBarFrame:GetAlpha() == 0 then
                castbar:Hide()
            end
            return
        end

        local now = GetTime()
        local max = endTime - startTime
        local cur
        if castbar.isChannel then
            cur = endTime - now
        else
            cur = now - startTime
        end

        cur = cur > max and max or cur
        cur = cur < 0 and 0 or cur
        local rem = castbar.isChannel and cur or (max - cur)
        rem = rem < 0 and 0 or rem
        castbar.timerText:SetText(string.format("%.1f"..T["s"], rem))

        if now >= endTime then
            castbar.startTime = nil
            castbar.endTime = nil
        end
    end

    local function RefreshCast()
        local cast, nameSubtext, text, texture, startTime, endTime, isTradeSkill, isChannel = QueryPlayerCast()

        if not cast or not startTime or not endTime or endTime <= startTime then
            -- Preserve Blizzard's normal fade-out: keep our last icon/text
            -- attached until the native castbar has finished fading.
            castbar.startTime = nil
            castbar.endTime = nil
            castbar.isChannel = nil
            if CastingBarFrame:GetAlpha() == 0 then
                castbar:Hide()
            end
            return
        end

        castbar.startTime = startTime / 1000
        castbar.endTime = endTime / 1000
        castbar.isChannel = isChannel
        castbar.spellText:SetText(cast)

        if texture then
            castbar.texture.icon:SetTexture(texture)
            castbar.texture.icon:Show()
        else
            castbar.texture.icon:Hide()
        end

        castbar.elapsed = 0
        castbar:Show()
        UpdateTimer()
    end

    -- The expensive cast/channel query now runs only on state-change events.
    -- While visible, OnUpdate only animates the remaining-time text and alpha.
    castbar.elapsed = 0
    castbar:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < .05 then return end
        this.elapsed = 0
        UpdateTimer()
    end)

    local events = CreateFrame("Frame", nil, UIParent)
    events:RegisterEvent("PLAYER_ENTERING_WORLD")

    local classicEvents = {
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_CHANNEL_UPDATE",
    }

    local hasClassicEvents = false
    if API and API.eventutils and _G.C_EventUtils and _G.C_EventUtils.IsEventValid then
        for _, eventName in pairs(classicEvents) do
            if _G.C_EventUtils.IsEventValid(eventName) then
                events:RegisterEvent(eventName)
                hasClassicEvents = true
            end
        end
    end

    if not hasClassicEvents then
        -- Compatibility with older ClassicAPI/plain 1.12: use the original
        -- player spellcast events as state-change triggers, not as a poller.
        events:RegisterEvent("SPELLCAST_START")
        events:RegisterEvent("SPELLCAST_STOP")
        events:RegisterEvent("SPELLCAST_FAILED")
        events:RegisterEvent("SPELLCAST_INTERRUPTED")
        events:RegisterEvent("SPELLCAST_DELAYED")
        events:RegisterEvent("SPELLCAST_CHANNEL_START")
        events:RegisterEvent("SPELLCAST_CHANNEL_STOP")
        events:RegisterEvent("SPELLCAST_CHANNEL_UPDATE")
    end

    events:SetScript("OnEvent", function()
        if event == "PLAYER_ENTERING_WORLD" then
            RefreshCast()
            return
        end

        if hasClassicEvents and arg1 ~= "player" then return end
        RefreshCast()
    end)
end
