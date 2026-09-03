local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local GetUnitData = ShaguTweaks.GetUnitData
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Nameplate Class Colors"],
  description = T["Changes the nameplate health bar color to the class color."],
  expansions = { ["vanilla"] = true },
  category = T["Nameplates"],
  enabled = true,
})

module.enable = function(self)
  if ShaguPlates then return end

  local colorsByName = {}
  local colorsVersion = 0
  local useClassicTokens = API and API.nameplateevents

  if useClassicTokens then
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    listener:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    listener:SetScript("OnEvent", function()
      local unit = arg1
      if not unit then return end

      -- Use only the exact nameplateN unit token here. Do not request or
      -- decorate ClassicAPI's Lua frame wrapper: the legacy libnameplate
      -- discovery path is deliberately kept isolated after native crashes.
      local name = UnitName(unit)
      if not name then return end

      if event == "NAME_PLATE_UNIT_ADDED" then
        local color
        if UnitIsPlayer(unit) then
          local _, class = UnitClass(unit)
          color = class and RAID_CLASS_COLORS[class] or nil
        end
        colorsByName[name] = color or false
        colorsVersion = colorsVersion + 1
      elseif event == "NAME_PLATE_UNIT_REMOVED" then
        colorsByName[name] = nil
        colorsVersion = colorsVersion + 1
      end
    end)
  end

  table.insert(ShaguTweaks.libnameplate.OnUpdate, function()
    if useClassicTokens then
      -- Refresh the cached desired color only when ClassicAPI reports a
      -- nameplate identity/class change. Turtle/Blizzard can still restore the
      -- hostile red statusbar color later, so compare the actual bar color each
      -- frame and write only when it drifted from the cached class color.
      if this.ShaguTweaksClassColorVersion ~= colorsVersion then
        this.ShaguTweaksClassColorVersion = colorsVersion
        local name = this.name and this.name:GetText()
        this.ShaguTweaksClassColor = name and colorsByName[name] or false
      end

      local color = this.ShaguTweaksClassColor
      if color then
        local r, g, b = this.healthbar:GetStatusBarColor()
        if not r
          or math.abs(r - color.r) > .01
          or math.abs(g - color.g) > .01
          or math.abs(b - color.b) > .01
        then
          this.healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
        end
      end
      return
    end

    -- Plain Vanilla / old ClassicAPI compatibility path.
    local name = this.name:GetText()
    local class, _, _, player = GetUnitData(name, true)
    if class and player then
      local color = RAID_CLASS_COLORS[class] or { r = .5, g = .5, b = .5, a = 1 }
      this.healthbar:SetStatusBarColor(color.r, color.g, color.b, 1)
    end
  end)
end
