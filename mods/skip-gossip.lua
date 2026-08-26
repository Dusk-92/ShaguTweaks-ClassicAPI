local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Skip Gossip Text"],
  description = T["Skip gossip text when interacting with NPCs unless holding shift."],
  expansions = { ["vanilla"] = true, ["tbc"] = nil },
  category = nil,
  enabled = nil,
})

local professions = {
  battlemaster = true,
  taxi = true,
  trainer = true,
  vendor = true,
  banker = true,
}

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

    local title, option1, _, option2, _, option3, _, option4, _, option5 = GetGossipOptions()
    local rawTitle = title

    -- Ported from LazyPig: if a "binder" (innkeeper hearthstone) option is
    -- present and we are NOT currently at our bind point, don't auto-skip
    -- anything in this menu at all.
    local bind
    if option1 == "binder" or option2 == "binder" or option3 == "binder"
      or option4 == "binder" or option5 == "binder" then
      bind = GetBindLocation()
      if not (bind == GetSubZoneText() or bind == GetZoneText()
        or bind == GetRealZoneText() or bind == GetMinimapZoneText()) then
        return
      end
    end

    -- "title" is the text of the first gossip option. Keep this historical
    -- LazyPig behavior, but normalize it once instead of once per option and
    -- once per configured phrase.
    local normalizedTitle = NormalizePhrase(title)

    local function HandleOption(optionType, index)
      if not optionType then return end

      if optionType == "gossip" then
        if normalizedTitle and normalizedPhrases[normalizedTitle] then
          SelectGossipOption(index)
          return true
        end
      elseif optionType == "trainer" and rawTitle == "Reset my talents." then
        -- Never auto-confirm a talent reset; always require a manual click.
        return
      elseif professions[optionType] then
        SelectGossipOption(index)
        return true
      end
    end

    if HandleOption(option1, 1) then return end
    if HandleOption(option2, 2) then return end
    if HandleOption(option3, 3) then return end
    if HandleOption(option4, 4) then return end
    HandleOption(option5, 5)
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
