local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Unit Frame Energy & Mana Tick"],
  description = T["Adds an energy & mana tick to the player frame."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

module.enable = function(self)
  local energytick = CreateFrame("Frame", nil, PlayerFrameManaBar)
  energytick:SetAllPoints(PlayerFrameManaBar)
  energytick:RegisterEvent("PLAYER_ENTERING_WORLD")
  energytick:RegisterEvent("UNIT_DISPLAYPOWER")
  energytick:RegisterEvent("UNIT_ENERGY")
  energytick:RegisterEvent("UNIT_MANA")
  energytick:SetScript("OnEvent", function()
    -- This module only tracks the player. Ignore unrelated unit events before
    -- doing any power queries or visibility work.
    if arg1 and arg1 ~= "player" then return end

    if UnitPowerType("player") == 0 then
      this.mode = "MANA"
      -- hide if full mana and not in combat
      if (UnitMana("player") == UnitManaMax("player")) and (not UnitAffectingCombat("player")) then
        this:Hide()
      else
        this:Show()
      end
    elseif UnitPowerType("player") == 3 then
      this.mode = "ENERGY"
      this:Show()
    else
      this:Hide()
    end

    if event == "PLAYER_ENTERING_WORLD" then
      this.lastMana = UnitMana("player")
    end

    if (this.mode == "ENERGY") or ((event == "UNIT_MANA" or event == "UNIT_ENERGY") and arg1 == "player") then
      this.currentMana = UnitMana("player")
      local diff = 0
      if this.lastMana then
        diff = this.currentMana - this.lastMana
      end

      if this.mode == "MANA" and diff < 0 then
        this.target = 5
      elseif this.mode == "MANA" and diff > 0 then
        if this.max ~= 5 and diff > (this.badtick and this.badtick*1.2 or 5) then
          this.target = 2
        else
          this.badtick = diff
        end
      elseif this.mode == "ENERGY" and diff >= 0 then
        this.target = 2
      end
      this.lastMana = this.currentMana
    end
  end)

  local pheight, pwidth = PlayerFrameManaBar:GetHeight(), PlayerFrameManaBar:GetWidth()
  energytick:SetScript("OnUpdate", function()
    if this.target then
      this.max = this.target
      this.current = 0
      this.target = nil
    end

    if not this.max then return end

    -- OnUpdate already provides the exact elapsed frame time. Accumulating arg1
    -- keeps the spark just as smooth without querying GetTime() every frame.
    this.current = (this.current or 0) + arg1

    if this.current > this.max then
      this.max, this.current = 2, 0
    end

    local pos = (pwidth ~= "-1" and pwidth or width) * (this.current / this.max)
    if not pheight then return end
    this.spark:SetPoint("LEFT", pos-((pheight+5)/2), 0)
  end)

  energytick.spark = energytick:CreateTexture(nil, 'OVERLAY')
  energytick.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  energytick.spark:SetHeight(pheight + 10)
  energytick.spark:SetWidth(pheight + 4)
  energytick.spark:SetBlendMode('ADD')
end
