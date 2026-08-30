local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local module = ShaguTweaks:register({
  title = T["Unit Frame Big Health"],
  description = T["Increases the healthbar of the player and target unitframe."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for i = 1, table.getn(tocs) do
  local current = string.format("ShaguTweaks%s", tocs[i])
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end
addonpath = addonpath or "Interface\\AddOns\\ShaguTweaks"

module.enable = function(self)
  local normalTexture = addonpath .. "\\img\\UI-TargetingFrame"
  local eliteTexture = addonpath .. "\\img\\UI-TargetingFrame-Elite"
  local rareTexture = addonpath .. "\\img\\UI-TargetingFrame-Rare"

  PlayerFrameTexture:SetTexture(normalTexture)
  PlayerFrameHealthBar:SetPoint("TOPLEFT", 106, -22)
  PlayerFrameHealthBar:SetHeight(30)

  PlayerStatusTexture:SetTexture(addonpath .. "\\img\\UI-Player-Status")

  TargetFrameTexture:SetTexture(normalTexture)
  TargetFrameHealthBar:SetPoint("TOPRIGHT", -106, -22)
  TargetFrameHealthBar:SetHeight(30)

  -- Dark mode is applied after the world has loaded. Keep this event separate
  -- from the one-frame deferred setup so the event cannot be unregistered early.
  local world = CreateFrame("Frame")
  world:RegisterEvent("PLAYER_ENTERING_WORLD")
  world:SetScript("OnEvent", function()
    ShaguTweaks.DarkenFrame(PlayerFrameTexture)
    ShaguTweaks.DarkenFrame(TargetFrameTexture)
    this:UnregisterAllEvents()
  end)

  -- Delay hook installation by one frame so all enabled unit-frame modules have
  -- finished their setup first. This keeps hooks attached to the final handlers.
  local deferred = CreateFrame("Frame")
  deferred:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    this:Hide()

    local function UpdateTargetClassificationTexture()
      local classification = UnitClassification("target")
      if classification == "worldboss" or classification == "rareelite" or classification == "elite" then
        TargetFrameTexture:SetTexture(eliteTexture)
      elseif classification == "rare" then
        TargetFrameTexture:SetTexture(rareTexture)
      else
        TargetFrameTexture:SetTexture(normalTexture)
      end
    end

    -- Let Blizzard and other addons finish classification handling, then apply
    -- the matching Big Health texture instead of replacing the global function.
    hooksecurefunc("TargetFrame_CheckClassification", UpdateTargetClassificationTexture)

    -- Keep status-bar text inside the lower half of the enlarged health bars.
    -- The stock Turtle-style text position sits too high once Big Health grows
    -- the bars upward and can overlap the unit name.
    if PlayerFrameHealthBar.TextString then
      PlayerFrameHealthBar.TextString:ClearAllPoints()
      PlayerFrameHealthBar.TextString:SetPoint("CENTER", PlayerFrameHealthBar, "CENTER", 0, -7)
    end

    if TargetFrameHealthBar.TextString then
      TargetFrameHealthBar.TextString:ClearAllPoints()
      TargetFrameHealthBar.TextString:SetPoint("CENTER", TargetFrameHealthBar, "CENTER", -2, -7)
    end

    local playerSetStatusBarColor = PlayerFrameHealthBar.SetStatusBarColor
    local targetSetStatusBarColor = TargetFrameHealthBar.SetStatusBarColor

    local function ApplyPlayerHealthColor()
      if not PlayerFrameNameBackground or not playerSetStatusBarColor then return end
      local r, g, b, a = PlayerFrameNameBackground:GetVertexColor()
      playerSetStatusBarColor(PlayerFrameHealthBar, r, g, b, a)
    end

    local function ApplyTargetHealthColor()
      if not TargetFrameNameBackground or not targetSetStatusBarColor then return end
      local r, g, b, a = TargetFrameNameBackground:GetVertexColor()
      targetSetStatusBarColor(TargetFrameHealthBar, r, g, b, a)
    end

    -- Keep the Big Health colors without replacing SetStatusBarColor with a
    -- no-op. Other addons may still call the original method normally.
    if PlayerFrameNameBackground then
      hooksecurefunc(PlayerFrameHealthBar, "SetStatusBarColor", ApplyPlayerHealthColor)
      hooksecurefunc(PlayerFrameNameBackground, "Show", function()
        PlayerFrameNameBackground:Hide()
      end)
      PlayerFrameNameBackground:Hide()
      ApplyPlayerHealthColor()
    end

    if TargetFrameNameBackground then
      hooksecurefunc(TargetFrameHealthBar, "SetStatusBarColor", ApplyTargetHealthColor)
      hooksecurefunc(TargetFrameNameBackground, "Show", function()
        TargetFrameNameBackground:Hide()
      end)
      TargetFrameNameBackground:Hide()
      ApplyTargetHealthColor()
    end

    -- Reapply the target health color after faction/class-color updates.
    hooksecurefunc("TargetFrame_CheckFaction", ApplyTargetHealthColor)

    -- Refresh once because the target frame may already have been initialized
    -- before this deferred setup ran.
    UpdateTargetClassificationTexture()
    TargetFrame_CheckFaction()
  end)
end
