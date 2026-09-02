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
local initialized = 0
local parentcount, childs, plate
local libnameplate = CreateFrame("Frame", nil, UIParent)
ShaguTweaks.libnameplate = libnameplate
libnameplate.OnInit = {}
libnameplate.OnShow = {}
libnameplate.OnUpdate = {}

local onInit = libnameplate.OnInit
local onShow = libnameplate.OnShow
local onUpdate = libnameplate.OnUpdate

local function ScanNameplates()
  parentcount = WorldFrame:GetNumChildren()
  if initialized < parentcount then
    childs = { WorldFrame:GetChildren() }
    for i = initialized + 1, parentcount do
      plate = childs[i]

      if IsNamePlate(plate) and not registry[plate] then
        plate.healthbar = plate:GetChildren()

        local regions = { plate:GetRegions() }
        for index = 1, table.getn(regions) do
          local key = NAMEPLATE_OBJECTORDER[index]
          if key then
            plate[key] = regions[index]
          end
        end

        -- Callback lists are arrays populated with table.insert(). Iterate them
        -- numerically: OnUpdate runs once per rendered frame on every visible
        -- nameplate, so avoid the generic pairs() iterator in this hot path.
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
      end
    end

    initialized = parentcount
  end
end

function libnameplate:HasConsumers()
  return table.getn(onInit) > 0
    or table.getn(onShow) > 0
    or table.getn(onUpdate) > 0
end

function libnameplate:Enable()
  if self.enabled then return end
  self.enabled = true
  self:SetScript("OnUpdate", ScanNameplates)
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
