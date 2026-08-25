-- TurtleWoW decided to change and add QoL features to their
-- default client, which they consider to be wanted by everyone.
-- This modules lets you disable the target-healthpoints again.
--
-- Depending on the amount of changes in future, this might move
-- from "Unit Frames" to a more general "Revert TWoW Changes" module.

-- Skip module initialization on every other client than TurtleWoW.
if not TargetHPText or not TargetHPPercText then return end

local T = ShaguTweaks.T
local L = ShaguTweaks.L

local module = ShaguTweaks:register({
  title = T["Turtle WoW Compatibility"],
  description = T["Adds compatibility to Turtle WoW's custom changes."],
  expansions = { ["vanilla"] = true },
  enabled = true,
})

module.enable = function(self)
  -- hide turtle-wow's target status texts
  if ShaguTweaks_config[T["Real Health Numbers"]] == 1 then
    TargetHPText:Hide()
    TargetHPText.Show = function() return end

    TargetHPPercText:Hide()
    TargetHPPercText.Show  = function() return end
  end

  if ShaguTweaks_config[T["MiniMap Clock"]] == 1 then
    MinimapClock:SetScript("OnEnter", function()
      -- read game time
      local zh, zm = GetGameTime()
      local sh, sm = zh, zm

      -- convert custom zonetime to servertime
      SetMapToCurrentZone()
      if GetCurrentMapContinent() == 1 then
        sh = sh + 12
        sh = sh >= 24 and sh - 24 or sh
      end

      -- format time to strings
      local zonetime = string.format("%.2d:%.2d", zh, zm)
      local servertime = string.format("%.2d:%.2d", sh, sm)
      local time = date("%H:%M")

      -- create the tooltip
      GameTooltip:ClearLines()
      GameTooltip:SetOwner(this, ANCHOR_BOTTOMLEFT)

      GameTooltip:AddLine(T["Clock"])
      GameTooltip:AddDoubleLine(T["Localtime"], time, 1,1,1,1,1,1)
      GameTooltip:AddDoubleLine(T["Servertime"], servertime, 1,1,1,1,1,1)
      GameTooltip:AddDoubleLine(T["Zonetime"], zonetime, 1,1,1,1,1,1)
      GameTooltip:Show()
    end)
  end

  -- compatibility for turtle-wow's worldmap window
  local HookWorldMapFrame_Maximize = WorldMapFrame_Maximize
  WorldMapFrame_Maximize = function()
    -- run original function
    HookWorldMapFrame_Maximize()

    -- re-apply worldmap window
    if ShaguTweaks_config[T["WorldMap Window"]] == 1 then
      WorldMapFrame:SetMovable(true)
      WorldMapFrame:EnableMouse(true)

      WorldMapFrame:SetScale(.85)
      WorldMapFrame:ClearAllPoints()
      WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
      WorldMapFrame:SetWidth(WorldMapButton:GetWidth() + 15)
      WorldMapFrame:SetHeight(WorldMapButton:GetHeight() + 55)

      -- overwrite wrong title position set by turtlewow
      WorldMapFrameTitle:SetPoint("TOP", WorldMapFrame, 0, 17)

      BlackoutWorld:Hide()
    end
  end

  -- trigger once to avoid graphical glitches
  WorldMapFrame_Maximize()

  -- Vendor Values already owns the fallback sell-price database in this fork.
  -- ClassicAPI is queried first there, so keep a single static database instead
  -- of allocating a second Turtle-specific copy during addon load.

  -- add druids tree of life and fast travel form to autoshift
  if ShaguTweaks.dismount then
    table.insert(ShaguTweaks.dismount.shapeshifts, "ability_druid_treeoflife")
    table.insert(ShaguTweaks.dismount.shapeshifts, "ability_druid_stagform")
  end

  -- update debuff durations
  L["debuffs"]["Hand of Reckoning"] = {[0]=3.0}
  L["debuffs"]['Insect Swarm'] = {[0]=18.0}
  L["debuffs"]['Moonfire'] = {[1]=9.0,[2]=18.0,[3]=18.0,[4]=18.0,[5]=18.0,[6]=18.0,[7]=18.0,[8]=18.0,[9]=18.0,[10]=18.0,[0]=18.0}
end

-- Turtle WoW specific libdebuff patches
local libdebuff = ShaguTweaks.libdebuff
local libdebuff_twow = CreateFrame("Frame")
libdebuff_twow:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
libdebuff_twow:SetScript("OnEvent", function()
  -- Break early on invalid data
  if not arg1 or not arg2 then return end

  -- Holy Strike is a spell, but can refresh paladin judgements
  -- Credits to @geojak
  if string.find(arg1, "Holy Strike") then
    for seal in ShaguTweaks.L["judgements"] do
      local name = UnitName("target")
      local level = UnitLevel("target")
      if name and libdebuff.objects[name] then
        if level and libdebuff.objects[name][level] and libdebuff.objects[name][level][seal] then
          libdebuff:AddEffect(name, level, seal)
        elseif libdebuff.objects[name][0] and libdebuff.objects[name][0][seal] then
          libdebuff:AddEffect(name, 0, seal)
        end
      end
    end
  end

  -- refresh Immolate duration after cast Conflagrate
  if string.find(arg1, "Conflagrate") then
    local name = UnitName("target")
    local level = UnitLevel("target")
    if libdebuff.objects[name] and libdebuff.objects[name][level] and libdebuff.objects[name][level]["Immolate"] then
      local duration = libdebuff.objects[name][level]["Immolate"].duration
      libdebuff:UpdateDuration(name, level, "Immolate", duration - 3)
    end
  end
end)
