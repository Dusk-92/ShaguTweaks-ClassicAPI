local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API or {}

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in pairs(tocs) do
  local current = string.format("ShaguTweaks%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end

local CLASS_ICON_TCOORDS = {
  ["WARRIOR"] = { 0, 0.25, 0, 0.25 },
  ["MAGE"] = { 0.25, 0.49609375, 0, 0.25 },
  ["ROGUE"] = { 0.49609375, 0.7421875, 0, 0.25 },
  ["DRUID"] = { 0.7421875, 0.98828125, 0, 0.25 },
  ["HUNTER"] = { 0, 0.25, 0.25, 0.5 },
  ["SHAMAN"] = { 0.25, 0.49609375, 0.25, 0.5 },
  ["PRIEST"] = { 0.49609375, 0.7421875, 0.25, 0.5 },
  ["WARLOCK"] = { 0.7421875, 0.98828125, 0.25, 0.5 },
  ["PALADIN"] = { 0, 0.25, 0.5, 0.75 },
  ["DEATHKNIGHT"] = { 0.25, .5, 0.5, .75 },
}

local module = ShaguTweaks:register({
  title = T["Unit Frame Class Portraits"],
  description = T["Replace unitframe portraits with class icons."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local function UpdatePortraits(frame)
  if not frame or not frame.unit or not frame.portrait then return end

  -- detect unit class or remove for non-player units
  local _, class = UnitClass(frame.unit)
  class = UnitIsPlayer(frame.unit) and class or nil

  -- Reapply after Blizzard's UnitFrame_Update: that function can replace the
  -- portrait texture even when the new target has the same class.
  if class then
    local iconCoords = CLASS_ICON_TCOORDS[class]
    if iconCoords then
      frame.portrait:SetTexture(addonpath .. "\\img\\UI-Classes-Circles")
      frame.portrait:SetTexCoord(unpack(iconCoords))
    end
  else
    frame.portrait:SetTexCoord(0, 1, 0, 1)
  end
end

module.enable = function(self)
  -- overwrite portraits set by the game
  local original = UnitFrame_Update
  UnitFrame_Update = function(arg1, arg2, arg3)
    original(arg1, arg2, arg3)
    UpdatePortraits(this)
  end

  -- handle portrait update events
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
  events:SetScript("OnEvent", function()
    UpdatePortraits(PlayerFrame)
    UpdatePortraits(TargetFrame)
    UpdatePortraits(PartyMemberFrame1)
    UpdatePortraits(PartyMemberFrame2)
    UpdatePortraits(PartyMemberFrame3)
    UpdatePortraits(PartyMemberFrame4)
  end)

  -- Target-of-target has no reliable vanilla portrait event. The old module
  -- refreshed it every rendered frame. ClassicAPI gives us UnitGUID, so poll
  -- cheaply at 5 Hz and only redraw when the actual unit changes.
  local tot = CreateFrame("Frame", nil, TargetFrame)
  tot.elapsed = 0
  tot.lastguid = nil
  tot:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed < .2 then return end
    this.elapsed = 0

    local guid = API.UnitGUID and API.UnitGUID("targettarget") or UnitName("targettarget")
    if guid ~= this.lastguid then
      this.lastguid = guid
      UpdatePortraits(TargetofTargetFrame)
    end
  end)
end
