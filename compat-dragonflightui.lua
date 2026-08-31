-- Compatibility bridge for DragonflightUI-Reforged.
--
-- DragonflightUI-Reforged currently keeps a hard-coded list of ShaguTweaks
-- modules and also references a couple of legacy module names directly.
-- This bridge keeps those legacy lookups harmless and exposes newer
-- ShaguTweaks / Extras ClassicAPI modules to DragonflightUI's ShaguTweaks tab
-- without modifying DragonflightUI itself.


-- Keep this file completely dormant when DragonflightUI-Reforged is not
-- installed/enabled. This avoids creating compatibility tables, metatables or
-- a polling frame for normal ShaguTweaks users.
local function DragonflightUIEnabled()
  if DFRL then return true end
  if not GetNumAddOns or not GetAddOnInfo then return false end

  for i = 1, GetNumAddOns() do
    local name, _, _, enabled = GetAddOnInfo(i)
    if name == "DragonflightUI-Reforged" then
      return enabled and true or false
    end
  end

  return false
end

if not DragonflightUIEnabled() then return end

local T = ShaguTweaks.T
local mods = ShaguTweaks.mods

ShaguTweaks.DragonflightUICompat = ShaguTweaks.DragonflightUICompat or {}
local Compat = ShaguTweaks.DragonflightUICompat

Compat.active = false
Compat.coreInjected = Compat.coreInjected or 0
Compat.extrasInjected = Compat.extrasInjected or 0
Compat.extrasRecovered = Compat.extrasRecovered or 0
Compat.legacyHits = Compat.legacyHits or 0

-- DragonflightUI still indexes the old Extras energy-tick module name
-- directly. Keep a virtual entry so the legacy lookup stays harmless without
-- adding a fake module to ShaguTweaks' own list or SavedVariables.
local function LegacyStub()
  return {
    enabled = nil,
    expansions = { ["vanilla"] = true },
    enable = function() end,
    disable = function() end,
    dragonflightCompatStub = true,
  }
end

local legacy = {}
legacy[T["Show Energy Ticks"]] = LegacyStub()

local mt = getmetatable(mods) or {}
if not mt.dragonflightUICompat then
  local previousIndex = mt.__index

  mt.__index = function(tab, key)
    local value = legacy[key]
    if value then
      Compat.legacyHits = Compat.legacyHits + 1
      return value
    end

    if type(previousIndex) == "function" then
      return previousIndex(tab, key)
    elseif type(previousIndex) == "table" then
      return previousIndex[key]
    end
  end

  mt.dragonflightUICompat = true
  setmetatable(mods, mt)
end

-- Snapshot the modules belonging to ShaguTweaks itself. Extras loads later
-- because it depends on ShaguTweaks.
Compat.coreTitles = Compat.coreTitles or {}
for title in pairs(mods) do
  Compat.coreTitles[title] = true
end

-- Modules DragonflightUI explicitly suppresses because it replaces the same
-- pieces of UI. Don't re-add them to its settings page.
local blocked = {}
local function Block(name)
  blocked[name] = true
  blocked[T[name]] = true
end

Block("Hide Errors")
Block("Darkened UI")
Block("Hide Gryphons")
Block("MiniMap Clock")
Block("MiniMap Tweaks")
Block("MiniMap Square")
Block("Movable Unit Frames")
-- DragonflightUI replaces the stock player/target bars and provides its own
-- health/power text. Keep the real ShaguTweaks modules disabled there even
-- though Real Health Numbers is once again a genuine core module.
Block("Real Health Numbers")
Block("Unit Frame Big Health")
Block("Reduced Actionbar Size")
Block("Unit Frame Class Colors")
Block("Unit Frame Health Colors")
Block("Unit Frame Class Portraits")
Block("Enemy Castbars")

Block("Show Bags")
Block("Show Micro Menu")
Block("Reagent Counter")
Block("Show Energy Ticks")
Block("Floating Actionbar")
Block("Dragonflight Gryphons")
Block("Center Vertical Actionbar")

-- New name for the old Extras energy-tick feature DragonflightUI suppresses.
Block("Unit Frame Energy & Mana Tick")

local function CleanCategory(category)
  category = tostring(category or "Other")
  category = string.gsub(category, "|c%x%x%x%x%x%x%x%x", "")
  category = string.gsub(category, "|r", "")
  category = string.gsub(category, "^Extras ClassicAPI:%s*", "")
  category = string.gsub(category, "^Mods:%s*", "")
  if category == "" then category = "Other" end
  return category
end

local function CategoryIndexes(target)
  local indexes = {}

  for _, data in pairs(target or {}) do
    local category = data[5] or "Other"
    local index = tonumber(data[6]) or 0
    if not indexes[category] or index > indexes[category] then
      indexes[category] = index
    end
  end

  return indexes
end

local function AddModules(target, predicate)
  if not target then return 0 end

  local titles = {}
  for title, mod in pairs(mods) do
    if type(mod) == "table"
      and not target[title]
      and not blocked[title]
      and predicate(title, mod) then
      table.insert(titles, title)
    end
  end

  table.sort(titles)

  local indexes = CategoryIndexes(target)
  local added = 0

  for _, title in pairs(titles) do
    local mod = mods[title]
    local category = CleanCategory(mod.category)
    indexes[category] = (indexes[category] or 0) + 1

    target[title] = {
      true,
      "checkbox",
      nil,
      nil,
      category,
      indexes[category],
      mod.description or title,
      nil,
      nil,
    }

    added = added + 1
  end

  return added
end

local function IsExtrasModule(title, mod)
  local category = tostring(mod.category or "")
  return string.find(category, "Extras ClassicAPI:", 1, true) ~= nil
end

local function ExtrasLoaded()
  return IsAddOnLoaded
    and IsAddOnLoaded("ShaguTweaks-extras")
    and true or false
end

-- DragonflightUI has two separate ADDON_LOADED listeners: one records that
-- ShaguTweaks-extras is loaded and another builds its Shagu metadata. On some
-- clients the metadata listener can run first, permanently leaving
-- shaguExtras/shaguExtrasData unset even though addon2 becomes true moments
-- later. Recover that state from WoW's authoritative addon-loaded flag before
-- DragonflightUI builds the settings page.
function Compat:RecoverExtrasMetadata()
  if not DFRL or not DFRL.gui or not ExtrasLoaded() then return false end

  DFRL.addon2 = true

  if not DFRL.gui.shaguExtrasData then
    DFRL.gui.shaguExtrasData = {}
    self.extrasRecovered = self.extrasRecovered + 1
  end

  DFRL.gui.shaguExtras = true
  return true
end

function Compat:InjectCore()
  if not DFRL or not DFRL.gui or not DFRL.gui.shaguCoreData then return 0 end

  local added = AddModules(DFRL.gui.shaguCoreData, function(title)
    return self.coreTitles[title] == true
  end)

  self.coreInjected = self.coreInjected + added
  return added
end

function Compat:InjectExtras()
  if not DFRL or not DFRL.gui or not DFRL.gui.shaguExtrasData then return 0 end

  local added = AddModules(DFRL.gui.shaguExtrasData, IsExtrasModule)
  self.extrasInjected = self.extrasInjected + added
  return added
end

function Compat:GrowDragonflightPanel()
  if not DFRL or not DFRL.gui or not DFRL.gui.Base then return end

  local base = DFRL.gui.Base
  local panel = base.scrollChildren and base.scrollChildren[5]
  if not panel then return end

  local items = 0
  local categories = 0

  local function Count(data, prefix)
    if not data then return end

    local seen = {}
    for _, value in pairs(data) do
      items = items + 1
      local category = tostring(value[5] or "Other")
      local key = prefix .. category
      if not seen[key] then
        seen[key] = true
        categories = categories + 1
      end
    end
  end

  Count(DFRL.gui.shaguCoreData, "core:")
  Count(DFRL.gui.shaguExtrasData, "extras:")

  -- Mirrors DragonflightUI's current spacing with some extra room at the end.
  local required = 500 + (items * 45) + (categories * 90)
  if panel:GetHeight() < required then
    panel:SetHeight(required)
  end
end

function Compat:InjectAll()
  self:InjectCore()
  self:InjectExtras()
  self:GrowDragonflightPanel()
end

function Compat:InstallDragonflightHooks()
  if not DFRL or not DFRL.gui then return end
  self.active = true

  -- Repair DragonflightUI's Extras metadata race before any injection attempt.
  self:RecoverExtrasMetadata()

  -- DragonflightUI builds the ShaguTweaks page from its config-ready callback.
  -- Insert our metadata immediately before that page is drawn.
  if DFRL.shagu
    and DFRL.shagu.configCallbacks
    and not DFRL.shagu.configReady
    and not self.configCallbackHooked then

    table.insert(DFRL.shagu.configCallbacks, 1, function()
      Compat:InjectAll()
    end)

    self.configCallbackHooked = true
  end

  -- Extras can be loaded after the core page already exists. DragonflightUI
  -- exposes this builder, so inject the new Extras entries before it appends
  -- that section.
  if DFRL.gui.shaguBuildExtras
    and not self.extrasBuilderHooked then

    local originalBuildExtras = DFRL.gui.shaguBuildExtras
    DFRL.gui.shaguBuildExtras = function()
      Compat:InjectExtras()
      Compat:GrowDragonflightPanel()
      return originalBuildExtras()
    end

    self.extrasBuilderHooked = true
  end

  -- Also covers cases where DragonflightUI already prepared its metadata.
  self:InjectAll()
end

-- DragonflightUI normally loads before ShaguTweaks, but keep the bridge
-- tolerant of other addon load orders as well.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("VARIABLES_LOADED")
watcher.elapsed = 0
watcher.retries = 0

watcher:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "DragonflightUI-Reforged" or arg1 == "ShaguTweaks-extras" then
      Compat:InstallDragonflightHooks()
    end
  elseif event == "VARIABLES_LOADED" then
    Compat:InstallDragonflightHooks()
  end
end)

watcher:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  if this.elapsed < 0.25 then return end

  this.elapsed = 0
  this.retries = this.retries + 1
  Compat:InstallDragonflightHooks()

  -- Newer DragonflightUI versions don't expose configCallbacks or
  -- shaguBuildExtras, so the old hook-based stop condition could poll forever.
  -- Stop once the core metadata exists and Extras is either absent or repaired.
  local coreReady = DFRL and DFRL.gui and DFRL.gui.shaguCoreData
  local extrasReady = not ExtrasLoaded()
    or (DFRL and DFRL.gui and DFRL.gui.shaguExtrasData)

  if Compat.active and coreReady and extrasReady then
    this:SetScript("OnUpdate", nil)
  elseif this.retries >= 40 then
    -- Never leave a permanent compatibility poll running on unusual loadouts.
    this:SetScript("OnUpdate", nil)
  end
end)

Compat:InstallDragonflightHooks()
