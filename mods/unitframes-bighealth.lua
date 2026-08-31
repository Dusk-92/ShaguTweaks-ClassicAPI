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

  -- Darkened UI and Big Health can be enabled in either order because modules
  -- are initialized from an unordered table. If Darkened UI ran first, Big
  -- Health replaces the already-darkened textures with fresh bright ones.
  -- Apply the configured dark tint directly to our replacement textures so the
  -- result is deterministic without adding any permanent OnUpdate work.
  local function ApplyDarkModeTextures()
    if not ShaguTweaks.DarkMode then return end

    local darkModule = ShaguTweaks.mods[T["Darkened UI"]]
    local color = ShaguTweaks_config
      and ShaguTweaks_config.overwrites
      and ShaguTweaks_config.overwrites["darkmode.color"]

    color = color
      or (darkModule and darkModule.config and darkModule.config["darkmode.color"])

    if not color then return end

    local r = tonumber(color.r) or color.r
    local g = tonumber(color.g) or color.g
    local b = tonumber(color.b) or color.b
    local a = tonumber(color.a) or color.a or 1

    if PlayerFrameTexture then PlayerFrameTexture:SetVertexColor(r, g, b, a) end
    if PlayerStatusTexture then PlayerStatusTexture:SetVertexColor(r, g, b, a) end
    if TargetFrameTexture then TargetFrameTexture:SetVertexColor(r, g, b, a) end
  end

  -- Big Health is presentation-only. Numeric health/power values are owned by
  -- the independent Real Health Numbers module.
  PlayerFrameTexture:SetTexture(normalTexture)
  PlayerFrameHealthBar:SetPoint("TOPLEFT", 106, -22)
  PlayerFrameHealthBar:SetHeight(30)

  PlayerStatusTexture:SetTexture(addonpath .. "\\img\\UI-Player-Status")

  TargetFrameTexture:SetTexture(normalTexture)
  TargetFrameHealthBar:SetPoint("TOPRIGHT", -106, -22)
  TargetFrameHealthBar:SetHeight(30)

  ApplyDarkModeTextures()

  local world = CreateFrame("Frame")
  world:RegisterEvent("PLAYER_ENTERING_WORLD")
  world:SetScript("OnEvent", function()
    ApplyDarkModeTextures()
    this:UnregisterAllEvents()
  end)

  -- Delay hook installation by one frame so all enabled unit-frame modules have
  -- finished their setup first. This keeps hooks attached to final handlers.
  local deferred = CreateFrame("Frame")
  deferred:SetScript("OnUpdate", function()
    this:SetScript("OnUpdate", nil)
    this:Hide()

    local function UpdateTargetClassificationTexture()
      local classification = UnitClassification("target")
      if classification == "worldboss"
        or classification == "rareelite"
        or classification == "elite" then
        TargetFrameTexture:SetTexture(eliteTexture)
      elseif classification == "rare" then
        TargetFrameTexture:SetTexture(rareTexture)
      else
        TargetFrameTexture:SetTexture(normalTexture)
      end

      ApplyDarkModeTextures()
    end

    hooksecurefunc("TargetFrame_CheckClassification", UpdateTargetClassificationTexture)

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

    hooksecurefunc("TargetFrame_CheckFaction", ApplyTargetHealthColor)

    UpdateTargetClassificationTexture()
    TargetFrame_CheckFaction()
  end)
end
