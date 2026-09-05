local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Skip Gossip Text"],
  description = T["Skip gossip text when interacting with NPCs unless holding shift."],
  expansions = { ["vanilla"] = true, ["tbc"] = nil },
  category = nil,
  enabled = nil,
})

-- ClassicAPI exposes Vanilla's native gossip option types as numeric icons.
-- Keep the exact historical ShaguTweaks profession set: vendor, taxi, trainer,
-- banker and battlemaster. Healer, binder, petition, tabard and auctioneer are
-- intentionally not auto-selected here.
local professionIcons = {
  [1] = true, -- vendor
  [2] = true, -- taxi
  [3] = true, -- trainer
  [6] = true, -- banker
  [9] = true, -- battlemaster
}

local GOSSIP_ICON_GOSSIP = 0
local GOSSIP_ICON_TRAINER = 3
local GOSSIP_ICON_BINDER = 5

local ignore = {
  ["Goblin Brainwashing Device"] = true,
}

-- Strip spacing and punctuation while preserving non-ASCII letters. Using
-- %W here can erase Cyrillic text entirely on the 1.12 Lua client, causing
-- unrelated ruRU gossip options to compare as the same empty string.
local function NormalizePhrase(text)
  if not text then return end
  return string.gsub(text, "[%s%p]", "")
end

local phrases = {
  -- Bank
  "I would like to check my deposit box",

  -- Vanilla
  "Teleport me to the Molten Core",

  -- Turtle WoW
  -- Alliance
  "Please open a portal to Alah'Thalas",
  "Please open a portal to Stormwind",
  -- Horde
  "Open a portal to Amani'Alor",

  -- ruRU
  "Я хотел бы проверить свою ячейку.", -- Bank
  "*Прикоснуться к нестабильному кристаллу Провала.*", -- MC entrance
  "\\*Положить руку на сферу.\\*", -- BWL entrance
  --"Thank you, Stable Master. Please take the animal.", -- AV quest locales_broadcast_text id6681
  "Благодарю тебя. Пожалуйста, возьми питомца.", -- AV quest locales_broadcast_text id6681
  "С удовольствием. Уж очень они воняют!", -- AV quest
  "Конфета или Жизнь!",
}

local normalizedPhrases = {}
for i = 1, table.getn(phrases) do
  local phrase = NormalizePhrase(phrases[i])
  if phrase and phrase ~= "" then
    normalizedPhrases[phrase] = true
  end
end

module.enable = function(self)
  -- ClassicAPI is a required dependency of this fork. If the installed build
  -- predates the native gossip surface, leave the module inactive rather than
  -- restoring the old GetGossipOptions / SelectGossipOption compatibility path.
  local GossipInfo = _G.C_GossipInfo
  if type(GossipInfo) ~= "table"
    or type(GossipInfo.GetOptions) ~= "function"
    or type(GossipInfo.SelectOptionByIndex) ~= "function" then
    return
  end

  -- Reuse a single event frame so repeated enable() calls cannot stack gossip
  -- handlers and select the same option more than once.
  if not self.actions then
    self.actions = CreateFrame("Frame", nil, UIParent)
  end

  local actions = self.actions

  function actions:Gossip()
    if not actions.gossip then return end

    local name = GossipFrameNpcNameText:GetText()
    if name and ignore[name] then
      return true
    end

    local options = GossipInfo.GetOptions()
    local optionCount = options and table.getn(options) or 0
    if optionCount == 0 then return end

    local first = options[1]
    local rawTitle = first and first.name

    -- Ported from LazyPig: if a "binder" (innkeeper hearthstone) option is
    -- present and we are NOT currently at our bind point, don't auto-skip
    -- anything in this menu at all. ClassicAPI lets us check every native
    -- gossip slot instead of only the first five Vanilla Lua returns.
    local hasBinder
    for i = 1, optionCount do
      local option = options[i]
      if option and option.icon == GOSSIP_ICON_BINDER then
        hasBinder = true
        break
      end
    end

    if hasBinder then
      local bind = GetBindLocation()
      if not (bind == GetSubZoneText() or bind == GetZoneText()
        or bind == GetRealZoneText() or bind == GetMinimapZoneText()) then
        return
      end
    end

    -- Preserve the historical LazyPig behavior: phrase matching is based on
    -- the text of the first gossip option, not on each option independently.
    local normalizedTitle = NormalizePhrase(rawTitle)

    for i = 1, optionCount do
      local option = options[i]
      if option then
        local optionType = option.icon

        if optionType == GOSSIP_ICON_GOSSIP then
          if normalizedTitle and normalizedPhrases[normalizedTitle] then
            GossipInfo.SelectOptionByIndex(option.orderIndex)
            return
          end
        elseif optionType == GOSSIP_ICON_TRAINER and rawTitle == "Reset my talents." then
          -- Never auto-confirm a talent reset; always require a manual click.
        elseif professionIcons[optionType] then
          GossipInfo.SelectOptionByIndex(option.orderIndex)
          return
        end
      end
    end
  end

  actions:RegisterEvent("GOSSIP_SHOW")
  actions:RegisterEvent("GOSSIP_CLOSED")
  actions:SetScript("OnEvent", function()
    if event == "GOSSIP_SHOW" then
      actions.gossip = true
      if not API.IsShiftKeyDown() then
        actions:Gossip()
      end
    elseif event == "GOSSIP_CLOSED" then
      actions.gossip = nil
    end
  end)
end
