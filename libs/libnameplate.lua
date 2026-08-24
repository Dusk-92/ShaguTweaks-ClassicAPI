local _G = ShaguTweaks.GetGlobalEnv()
local GetExpansion = ShaguTweaks.GetExpansion
local API = ShaguTweaks.API

local NAMEPLATE_OBJECTORDER = { "border", "glow", "name", "level", "levelicon", "raidicon" }
local NAMEPLATE_TYPE = "Button"
if GetExpansion() == "tbc" then
  NAMEPLATE_OBJECTORDER = { "border", "castborder", "casticon", "glow", "name", "level", "levelicon", "raidicon" }
  NAMEPLATE_TYPE = "Frame"
end

local function IsNamePlate(frame)
  if not frame or frame:GetObjectType() ~= NAMEPLATE_TYPE then return nil end
  local regions = frame:GetRegions()

  if not regions then return nil end
  if not regions.GetObjectType then return nil end
  if not regions.GetTexture then return nil end

  if regions:GetObjectType() ~= "Texture" then return nil end
  return regions:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" or nil
end

local registry = {}
ShaguTweaks.libnameplate = CreateFrame("Frame", nil, UIParent)
ShaguTweaks.libnameplate.OnInit = {}
ShaguTweaks.libnameplate.OnShow = {}
ShaguTweaks.libnameplate.OnUpdate = {}

local function InitializePlate(plate)
  if not plate or registry[plate] or not IsNamePlate(plate) then return end

  plate.healthbar = plate:GetChildren()
  for i, object in pairs({plate:GetRegions()}) do
    if plate and NAMEPLATE_OBJECTORDER[i] then
      plate[NAMEPLATE_OBJECTORDER[i]] = object
    end
  end

  -- Run one-time decorators after the native plate objects are exposed.
  for _, func in pairs(ShaguTweaks.libnameplate.OnInit) do
    func(plate)
  end

  -- Keep the historical callback surface for modules that genuinely need
  -- per-frame plate work. ClassicAPI only replaces plate discovery below.
  local oldUpdate = plate:GetScript("OnUpdate")
  plate:SetScript("OnUpdate", function(self, elapsed)
    if oldUpdate then oldUpdate(self, elapsed) end
    for _, func in pairs(ShaguTweaks.libnameplate.OnUpdate) do
      func(self, elapsed)
    end
  end)

  local oldShow = plate:GetScript("OnShow")
  plate:SetScript("OnShow", function(self)
    if oldShow then oldShow(self) end
    for _, func in pairs(ShaguTweaks.libnameplate.OnShow) do
      func(self)
    end
  end)

  registry[plate] = plate
end

-- ClassicAPI exposes the native nameplate lifecycle directly. Prefer its
-- NAME_PLATE_CREATED event so Lua no longer walks every WorldFrame child on
-- every rendered frame just to discover newly allocated nameplates.
local useCreatedEvent = API and API.eventutils and _G.C_EventUtils
  and _G.C_EventUtils.IsEventValid("NAME_PLATE_CREATED")

if useCreatedEvent then
  ShaguTweaks.libnameplate:RegisterEvent("NAME_PLATE_CREATED")
  ShaguTweaks.libnameplate:SetScript("OnEvent", function()
    if event == "NAME_PLATE_CREATED" then
      InitializePlate(arg1)
    end
  end)
else
  -- Legacy fallback for plain 1.12 / older ClassicAPI builds. Preserve the
  -- original WorldFrame scan exactly where no lifecycle event exists.
  local initialized = 0
  local parentcount, childs, plate

  ShaguTweaks.libnameplate:SetScript("OnUpdate", function()
    parentcount = WorldFrame:GetNumChildren()
    if initialized < parentcount then
      childs = { WorldFrame:GetChildren() }
      for i = initialized + 1, parentcount do
        plate = childs[i]
        InitializePlate(plate)
      end

      initialized = parentcount
    end
  end)
end
