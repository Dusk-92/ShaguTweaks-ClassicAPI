local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local hooksecurefunc = hooksecurefunc or ShaguTweaks.hooksecurefunc

local FALLBACK_CLASS_COLOR = { r = .5, g = .5, b = .5, a = 1 }

local module = ShaguTweaks:register({
  title = T["Unit Frame Class Colors"],
  description = T["Adds class colors to the player, target and party unit frames."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local function GetUnitClassColor(unit)
  local _, class = UnitClass(unit)
  return RAID_CLASS_COLORS[class] or FALLBACK_CLASS_COLOR
end

local function SetTextColorIfChanged(fontString, r, g, b, a)
  local cr, cg, cb, ca = fontString:GetTextColor()
  if cr ~= r or cg ~= g or cb ~= b or ca ~= a then
    fontString:SetTextColor(r, g, b, a)
  end
end

local function SetVertexColorIfChanged(texture, r, g, b, a)
  local cr, cg, cb, ca = texture:GetVertexColor()
  if cr ~= r or cg ~= g or cb ~= b or ca ~= a then
    texture:SetVertexColor(r, g, b, a)
  end
end

local function UpdatePartyColors()
  for id = 1, MAX_PARTY_MEMBERS do
    local name = _G["PartyMemberFrame" .. id .. "Name"]
    if name then
      local color = GetUnitClassColor("party" .. id)
      SetTextColorIfChanged(name, color.r, color.g, color.b, 1)
    end
  end
end

module.enable = function(self)
  local function UpdateTargetClassColor()
    if not TargetFrameNameBackground then return end

    local reaction = UnitReaction("target", "player")
    if UnitIsPlayer("target") then
      local color = GetUnitClassColor("target")
      SetVertexColorIfChanged(TargetFrameNameBackground,
        color.r, color.g, color.b, 1)
      TargetFrameNameBackground:Show()
    elseif reaction and reaction > 4 then
      TargetFrameNameBackground:Hide()
    else
      TargetFrameNameBackground:Show()
    end
  end

  -- Let Blizzard and other addons finish their target-faction handling first,
  -- then apply the class-color background instead of replacing the global.
  hooksecurefunc("TargetFrame_CheckFaction", UpdateTargetClassColor)

  local playerColor = GetUnitClassColor("player")

  -- add name background to player frame
  PlayerFrameNameBackground = PlayerFrame:CreateTexture(nil, "BACKGROUND")
  PlayerFrameNameBackground:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-LevelBackground")
  PlayerFrameNameBackground:SetWidth(119)
  PlayerFrameNameBackground:SetHeight(19)
  PlayerFrameNameBackground:SetPoint("TOPLEFT", 106, -22)
  PlayerFrameNameBackground:SetVertexColor(playerColor.r, playerColor.g, playerColor.b, 1)

  local wait = CreateFrame("Frame")
  wait:RegisterEvent("PLAYER_ENTERING_WORLD")
  wait:SetScript("OnEvent", function()
    local color = GetUnitClassColor("player")
    SetVertexColorIfChanged(PlayerFrameNameBackground,
      color.r, color.g, color.b, 1)
    this:UnregisterAllEvents()

    -- make sure to keep name background above frame shadow
    PlayerFrameNameBackground:SetDrawLayer("BORDER")
    TargetFrameNameBackground:SetDrawLayer("BORDER")
  end)

  -- add font outline
  local font, size = PlayerFrame.name:GetFont()
  PlayerFrame.name:SetFont(font, size, "NONE")
  TargetFrame.name:SetFont(font, size, "NONE")

  -- Update party name colors after the stock member refresh instead of
  -- replacing PartyMemberFrame_UpdateMember. Cached color writes avoid doing
  -- extra rendering work when the class did not change.
  hooksecurefunc("PartyMemberFrame_UpdateMember", UpdatePartyColors)

  UpdateTargetClassColor()
  UpdatePartyColors()
end
