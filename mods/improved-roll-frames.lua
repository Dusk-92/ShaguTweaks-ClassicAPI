local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Improved Roll Frames"],
  description = T["Smaller roll frames with roll tracking."],
  expansions = { ["vanilla"] = true },
  category = T["Loot"],
  enabled = nil,
})

module.enable = function(self)
  if not API.loothistoryevents or not API.modifierkeys then return end

  local _G = ShaguTweaks.GetGlobalEnv()
  local font_default, font_size = "Fonts\\skurri.TTF", 15
  local ROLL_FRAME_COUNT = 4

  ShaguTweaks.roll = CreateFrame("Frame", "STLootRoll", UIParent)
  ShaguTweaks.roll.frames = {}

  local function FindHistoryIndex(historyRollID)
    if not historyRollID then return end

    local numItems = API.GetLootHistoryNumItems()
    for i=1,numItems do
      local rollID = API.GetLootHistoryItem(i)
      if rollID == historyRollID then
        return i
      end
    end
  end

  local function LinksMatch(nativeLink, historyLink)
    if not nativeLink or not historyLink then return false end
    if nativeLink == historyLink then return true end
    return string.find(nativeLink, historyLink, 1, true) and true or false
  end

  local function FindUnclaimedHistory(nativeLink, claimed)
    local numItems = API.GetLootHistoryNumItems()

    -- New group rolls are appended to C_LootHistory. Search newest first so
    -- the frame opened by the current START_ROLL binds to that new entry.
    for i=numItems,1,-1 do
      local historyRollID, historyLink = API.GetLootHistoryItem(i)
      if historyRollID and not claimed[historyRollID]
        and LinksMatch(nativeLink, historyLink) then
        return historyRollID, i
      end
    end
  end

  local function GetRollPlayers(frame, wantedType)
    local players = {}
    local itemIndex = FindHistoryIndex(frame.historyRollID)
    if not itemIndex then return players end

    local _, _, numPlayers = API.GetLootHistoryItem(itemIndex)
    for i=1,(numPlayers or 0) do
      local name, class, rollType, roll, isWinner, isMe =
        API.GetLootHistoryPlayerInfo(itemIndex, i)
      if name and not isMe and rollType == wantedType then
        table.insert(players, name)
      end
    end

    return players
  end

  local function RefreshHistory(frame, itemIndex)
    if not frame or not frame.historyRollID then return end

    itemIndex = itemIndex or FindHistoryIndex(frame.historyRollID)
    if not itemIndex then return end

    local historyRollID, _, numPlayers = API.GetLootHistoryItem(itemIndex)
    if historyRollID ~= frame.historyRollID then return end

    local need, greed, pass = 0, 0, 0

    for i=1,(numPlayers or 0) do
      local name, class, rollType, roll, isWinner, isMe =
        API.GetLootHistoryPlayerInfo(itemIndex, i)

      -- The original chat parser deliberately ignored "You"; preserve that
      -- behavior by not counting the local player's own roll.
      if name and not isMe then
        if rollType == 1 then
          need = need + 1
        elseif rollType == 2 then
          greed = greed + 1
        elseif rollType == 0 then
          pass = pass + 1
        end
      end
    end

    frame.need.count:SetText(need > 0 and need or "")
    frame.greed.count:SetText(greed > 0 and greed or "")
    frame.pass.count:SetText(pass > 0 and pass or "")
  end

  local function BindVisibleFrames()
    local claimed = {}

    for i=1,ROLL_FRAME_COUNT do
      local frame = ShaguTweaks.roll.frames[i]
      if frame and frame.historyRollID then
        claimed[frame.historyRollID] = true
      end
    end

    for i=1,ROLL_FRAME_COUNT do
      local frame = ShaguTweaks.roll.frames[i]
      if frame and frame:IsVisible() and frame.rollID
        and not frame.historyRollID then
        local nativeLink = frame.historyLink or GetLootRollItemLink(frame.rollID)
        local historyRollID, itemIndex =
          FindUnclaimedHistory(nativeLink, claimed)

        if historyRollID then
          frame.historyRollID = historyRollID
          claimed[historyRollID] = true
          RefreshHistory(frame, itemIndex)
        end
      end
    end
  end

  local function RefreshAllHistory()
    for i=1,ROLL_FRAME_COUNT do
      local frame = ShaguTweaks.roll.frames[i]
      if frame and frame:IsVisible() then
        RefreshHistory(frame)
      end
    end
  end

  function ShaguTweaks.roll:CreateLootRoll(id)
    local size = 22
    local border = 4
    local esize = 22
    local f = CreateFrame("Frame", "STLootRollFrame" .. id, UIParent)

    local function CreateBackdrop(frame, b, a)
      if not frame then return end
      frame.backdrop = CreateFrame("Frame", nil, frame)
      frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -b, b)
      frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", b, -b)
      frame.backdrop:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
      })

      frame.backdrop:SetBackdropColor(0, 0, 0, a)
      frame.backdrop:SetBackdropBorderColor(1, 1, 1, a)
    end

    CreateBackdrop(f, border, .1)
    f.backdrop:SetFrameStrata("BACKGROUND")
    f.hasItem = 1

    f:SetWidth(385)
    f:SetHeight(size)

    f.icon = CreateFrame("Button", "STLootRollFrame" .. id .. "Icon", f)
    CreateBackdrop(f.icon, border, .1)
    f.icon:SetPoint("LEFT", f, "LEFT", -30, 0)
    f.icon:SetWidth(esize*1.2)
    f.icon:SetHeight(esize*1.2)

    f.icon.tex = f.icon:CreateTexture("OVERLAY")
    f.icon.tex:SetTexCoord(.08, .92, .08, .92)
    f.icon.tex:SetAllPoints(f.icon)

    f.icon:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetLootRollItem(this:GetParent().rollID)
      CursorUpdate()
    end)

    f.icon:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.icon:SetScript("OnClick", function()
      local parent = this:GetParent()
      local link = parent and parent.rollID
        and GetLootRollItemLink(parent.rollID)

      if link and API.IsControlKeyDown() then
        DressUpItemLink(link)
      elseif link and API.IsShiftKeyDown() then
        if ChatEdit_InsertLink then
          ChatEdit_InsertLink(link)
        elseif ChatFrameEditBox:IsVisible() then
          ChatFrameEditBox:Insert(link)
        end
      end
    end)

    f.need = CreateFrame("Button", "STLootRollFrame" .. id .. "Need", f)
    f.need:SetPoint("LEFT", f.icon, "RIGHT", border*3, -1)
    f.need:SetWidth(esize)
    f.need:SetHeight(esize)
    f.need:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
    f.need:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")

    f.need.count = f.need:CreateFontString("NEED")
    f.need.count:SetPoint("CENTER", f.need, "CENTER", 0, 0)
    f.need.count:SetJustifyH("CENTER")
    f.need.count:SetFont(font_default, font_size, "OUTLINE")

    f.need:SetScript("OnClick", function()
      RollOnLoot(this:GetParent().rollID, 1)
    end)
    f.need:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff33ffcc" .. NEED)
      for _, player in pairs(GetRollPlayers(f, 1)) do
        GameTooltip:AddLine(player)
      end
      GameTooltip:Show()
    end)
    f.need:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.greed = CreateFrame("Button", "STLootRollFrame" .. id .. "Greed", f)
    f.greed:SetPoint("LEFT", f.icon, "RIGHT", border*5+esize, -2)
    f.greed:SetWidth(esize)
    f.greed:SetHeight(esize)
    f.greed:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    f.greed:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")

    f.greed.count = f.greed:CreateFontString("GREED")
    f.greed.count:SetPoint("CENTER", f.greed, "CENTER", 0, 1)
    f.greed.count:SetJustifyH("CENTER")
    f.greed.count:SetFont(font_default, font_size, "OUTLINE")

    f.greed:SetScript("OnClick", function()
      RollOnLoot(this:GetParent().rollID, 2)
    end)
    f.greed:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff33ffcc" .. GREED)
      for _, player in pairs(GetRollPlayers(f, 2)) do
        GameTooltip:AddLine(player)
      end
      GameTooltip:Show()
    end)
    f.greed:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.pass = CreateFrame("Button", "STLootRollFrame" .. id .. "Pass", f)
    f.pass:SetPoint("LEFT", f.icon, "RIGHT", border*7+esize*2, 0)
    f.pass:SetWidth(esize)
    f.pass:SetHeight(esize)
    f.pass:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    f.pass:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")

    f.pass.count = f.pass:CreateFontString("PASS")
    f.pass.count:SetPoint("CENTER", f.pass, "CENTER", 0, -1)
    f.pass.count:SetJustifyH("CENTER")
    f.pass.count:SetFont(font_default, font_size, "OUTLINE")

    f.pass:SetScript("OnClick", function()
      RollOnLoot(this:GetParent().rollID, 0)
    end)
    f.pass:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("|cff33ffcc" .. PASS)
      for _, player in pairs(GetRollPlayers(f, 0)) do
        GameTooltip:AddLine(player)
      end
      GameTooltip:Show()
    end)
    f.pass:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    f.boe = CreateFrame("Frame", "STLootRollFrame" .. id .. "BOE", f)
    f.boe:SetPoint("LEFT", f.icon, "RIGHT", border*9+esize*3, 0)
    f.boe:SetWidth(esize*2)
    f.boe:SetHeight(esize)
    f.boe.text = f.boe:CreateFontString("BOE")
    f.boe.text:SetAllPoints(f.boe)
    f.boe.text:SetJustifyH("LEFT")
    f.boe.text:SetFont(font_default, font_size, "OUTLINE")

    f.name = CreateFrame("Frame", "STLootRollFrame" .. id .. "Name", f)
    f.name:SetPoint("LEFT", f.icon, "RIGHT", border*11+esize*4, 0)
    f.name:SetPoint("RIGHT", f, "RIGHT", border*2, 0)
    f.name:SetHeight(esize)
    f.name.text = f.name:CreateFontString("NAME")
    f.name.text:SetAllPoints(f.name)
    f.name.text:SetJustifyH("LEFT")
    f.name.text:SetFont(font_default, font_size, "OUTLINE")

    f.time = CreateFrame("Frame", "STLootRollFrame" .. id .. "Time", f)
    f.time:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.time:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.time:SetFrameStrata("LOW")
    f.time.bar = CreateFrame(
      "StatusBar", "STLootRollFrame" .. id .. "TimeBar", f.time)
    f.time.bar:SetAllPoints(f.time)
    f.time.bar:SetStatusBarTexture(
      "Interface\\TargetingFrame\\UI-StatusBar")
    f.time.bar:SetMinMaxValues(0, 100)
    f.time.bar:SetStatusBarColor(1, 210/255, 0)
    f.time.bar:SetValue(20)

    return f
  end

  -- One shared updater drives every visible countdown bar. The original
  -- module installed one OnUpdate on every roll frame.
  ShaguTweaks.roll.timer = CreateFrame("Frame")
  ShaguTweaks.roll.timer:Hide()
  ShaguTweaks.roll.timer:SetScript("OnUpdate", function()
    local anyVisible = false

    for i=1,ROLL_FRAME_COUNT do
      local frame = ShaguTweaks.roll.frames[i]
      if frame and frame:IsVisible() and frame.rollID then
        anyVisible = true
        local left = GetLootRollTimeLeft(frame.rollID)
        if left < 0 or left > frame.rollTime then left = 0 end
        frame.time.bar:SetValue(left)
      end
    end

    if not anyVisible then
      this:Hide()
    end
  end)

  ShaguTweaks.roll:RegisterEvent("CANCEL_LOOT_ROLL")
  ShaguTweaks.roll:RegisterEvent("LOOT_HISTORY_ROLL_CHANGED")
  ShaguTweaks.roll:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE")
  ShaguTweaks.roll:RegisterEvent("LOOT_HISTORY_FULL_UPDATE")
  ShaguTweaks.roll:SetScript("OnEvent", function()
    if event == "CANCEL_LOOT_ROLL" then
      for i=1,ROLL_FRAME_COUNT do
        local frame = ShaguTweaks.roll.frames[i]
        if frame.rollID == arg1 then
          frame:Hide()
          frame.rollID = nil
          frame.historyRollID = nil
          frame.historyLink = nil
          frame.need.count:SetText("")
          frame.greed.count:SetText("")
          frame.pass.count:SetText("")
          return
        end
      end
    elseif event == "LOOT_HISTORY_FULL_UPDATE" then
      BindVisibleFrames()
      RefreshAllHistory()
    elseif event == "LOOT_HISTORY_ROLL_CHANGED"
      or event == "LOOT_HISTORY_ROLL_COMPLETE" then
      local itemIndex = arg1
      local historyRollID = itemIndex and API.GetLootHistoryItem(itemIndex)

      if historyRollID then
        for i=1,ROLL_FRAME_COUNT do
          local frame = ShaguTweaks.roll.frames[i]
          if frame and frame.historyRollID == historyRollID then
            RefreshHistory(frame, itemIndex)
            return
          end
        end
      end

      -- A structural update normally binds first; this also self-heals if an
      -- addon changed the native roll-frame opening order.
      BindVisibleFrames()
      RefreshAllHistory()
    end
  end)

  function _G.GroupLootFrame_OpenNewFrame(id, rollTime)
    local available

    for i=1,ROLL_FRAME_COUNT do
      if not ShaguTweaks.roll.frames[i]:IsVisible() and not available then
        available = i
      end
    end

    if available then
      local frame = ShaguTweaks.roll.frames[available]
      frame.rollID = id
      frame.rollTime = rollTime
      frame.historyRollID = nil
      frame.historyLink = GetLootRollItemLink(id)
      ShaguTweaks.roll:UpdateLootRoll(available)
    end
  end

  function ShaguTweaks.roll:UpdateLootRoll(id)
    local frame = ShaguTweaks.roll.frames[id]
    local texture, name, count, quality, bop =
      GetLootRollItemInfo(frame.rollID)
    local color = ITEM_QUALITY_COLORS[quality]

    frame.itemname = name
    frame.need.count:SetText("")
    frame.greed.count:SetText("")
    frame.pass.count:SetText("")

    frame.name.text:SetText(name)
    frame.name.text:SetTextColor(color.r, color.g, color.b, 1)
    frame.icon.tex:SetTexture(texture)
    frame.backdrop:SetBackdropBorderColor(color.r, color.g, color.b)
    frame.time.bar:SetMinMaxValues(0, frame.rollTime)
    frame.time.bar:SetStatusBarColor(color.r, color.g, color.b, .5)

    if bop then
      frame.boe.text:SetText("BoP")
      frame.boe.text:SetTextColor(1,.3,.3,1)
    else
      frame.boe.text:SetText("BoE")
      frame.boe.text:SetTextColor(.3,1,.3,1)
    end

    frame:Show()
    ShaguTweaks.roll.timer:Show()

    -- ClassicAPI records the new history row after the native START_ROLL
    -- handler returns. Binding happens on the ensuing FULL_UPDATE; doing it
    -- here could accidentally attach a repeated item to an older history row.
  end

  for i=1,ROLL_FRAME_COUNT do
    if not ShaguTweaks.roll.frames[i] then
      ShaguTweaks.roll.frames[i] = ShaguTweaks.roll:CreateLootRoll(i)
      ShaguTweaks.roll.frames[i]:SetPoint("CENTER", 15, i*35)
      ShaguTweaks.roll.frames[i]:Hide()
    end
  end
end
