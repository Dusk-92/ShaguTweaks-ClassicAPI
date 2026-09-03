local _G = ShaguTweaks.GetGlobalEnv()
local API = ShaguTweaks.API
local GetExpansion = ShaguTweaks.GetExpansion

local NAMEPLATE_OBJECTORDER = { "border", "glow", "name", "level", "levelicon", "raidicon" }
local NAMEPLATE_TYPE = "Button"
if GetExpansion() == "tbc" then
  NAMEPLATE_OBJECTORDER = { "border", "castborder", "casticon", "glow", "name", "level", "levelicon", "raidicon" }
  NAMEPLATE_TYPE = "Frame"
end

local function IsNamePlate(frame)
  if frame:GetObjectType() ~= NAMEPLATE_TYPE then return nil end
  local regions = frame:GetRegions()

  if not regions then return nil end
  if not regions.GetObjectType then return nil end
  if not regions.GetTexture then return nil end

  if regions:GetObjectType() ~= "Texture" then return nil end
  return regions:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" or nil
end

local registry = {}
local lastParentCount = -1
local libnameplate = CreateFrame("Frame", nil, UIParent)
ShaguTweaks.libnameplate = libnameplate
libnameplate.OnInit = {}
libnameplate.OnShow = {}
libnameplate.OnUpdate = {}

local onInit = libnameplate.OnInit
local onShow = libnameplate.OnShow
local onUpdate = libnameplate.OnUpdate

local function InitializePlate(plate)
  if not plate or registry[plate] or not IsNamePlate(plate) then return nil end

  plate.healthbar = plate:GetChildren()

  local regions = { plate:GetRegions() }
  for index = 1, table.getn(regions) do
    local key = NAMEPLATE_OBJECTORDER[index]
    if key then
      plate[key] = regions[index]
    end
  end

  for index = 1, table.getn(onInit) do
    onInit[index](plate)
  end

  -- Preserve the native/addon scripts and append ShaguTweaks callbacks.
  local oldUpdate = plate:GetScript("OnUpdate")
  plate:SetScript("OnUpdate", function(self, elapsed)
    if oldUpdate then oldUpdate(self, elapsed) end
    for index = 1, table.getn(onUpdate) do
      onUpdate[index](self, elapsed)
    end
  end)

  local oldShow = plate:GetScript("OnShow")
  plate:SetScript("OnShow", function(self)
    if oldShow then oldShow(self) end
    for index = 1, table.getn(onShow) do
      onShow[index](self)
    end
  end)

  registry[plate] = true
  return true
end

-- Event-driven discovery still obtains the real native frame through
-- WorldFrame:GetChildren(). ClassicAPI's C_NamePlate getters can return fresh
-- wrapper tables for default engine plates, so caching those wrappers would be
-- unsafe. The NAME_PLATE_UNIT_ADDED event is used only as a precise wake-up.
local function DiscoverNameplates()
  local count = WorldFrame:GetNumChildren()
  local children = { WorldFrame:GetChildren() }
  local added = 0

  for index = 1, count do
    if InitializePlate(children[index]) then
      added = added + 1
    end
  end

  lastParentCount = count
  return added
end

-- Older ClassicAPI builds without nameplate events retain the historical
-- polling fallback. Only enumerate children when the WorldFrame child count
-- changes; registry checks keep repeated frames idempotent.
local function ScanNameplatesLegacy()
  local count = WorldFrame:GetNumChildren()
  if count == lastParentCount then return end
  DiscoverNameplates()
end

local eventDriver = CreateFrame("Frame")
local retryDriver = CreateFrame("Frame")
retryDriver:SetScript("OnUpdate", nil)

local function ScheduleDiscoveryRetry()
  if retryDriver:GetScript("OnUpdate") then return end
  retryDriver:SetScript("OnUpdate", function()
    DiscoverNameplates()
    this:SetScript("OnUpdate", nil)
  end)
end

local function HasClassicNameplateEvents()
  return API and API.nameplates and API.eventutils and _G.C_EventUtils
    and _G.C_EventUtils.IsEventValid("NAME_PLATE_UNIT_ADDED")
end

function libnameplate:HasConsumers()
  return table.getn(onInit) > 0
    or table.getn(onShow) > 0
    or table.getn(onUpdate) > 0
end

function libnameplate:Enable()
  if self.enabled then return end
  self.enabled = true

  if HasClassicNameplateEvents() then
    -- Discover plates that were already visible when a consumer was enabled.
    DiscoverNameplates()

    eventDriver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventDriver:SetScript("OnEvent", function()
      -- In current ClassicAPI the nameplate normally exists by event dispatch
      -- time. Scan immediately, then do one next-frame retry to tolerate engine
      -- ordering differences without leaving a permanent OnUpdate running.
      DiscoverNameplates()
      ScheduleDiscoveryRetry()
    end)

    self:SetScript("OnUpdate", nil)
  else
    self:SetScript("OnUpdate", ScanNameplatesLegacy)
  end
end

function libnameplate:EnableIfNeeded()
  if self:HasConsumers() then
    self:Enable()
  end
end

-- Stay completely dormant until an enabled ShaguTweaks module (or an
-- external addon) actually registers a nameplate callback.
libnameplate.enabled = false
libnameplate:SetScript("OnUpdate", nil)

-- Load-on-demand addons can register callbacks after the normal ShaguTweaks
-- initialization pass. ADDON_LOADED is enough to catch those without keeping
-- a polling OnUpdate alive while the library is unused.
local activation = CreateFrame("Frame")
activation:RegisterEvent("ADDON_LOADED")
activation:SetScript("OnEvent", function()
  libnameplate:EnableIfNeeded()
end)
