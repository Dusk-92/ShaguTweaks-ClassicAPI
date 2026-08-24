local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local L = ShaguTweaks.L
local gfind = string.gmatch or string.gfind
local GetUnitData = ShaguTweaks.GetUnitData
local GetExpansion = ShaguTweaks.GetExpansion
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local cmatch = ShaguTweaks.cmatch
local rgbhex = ShaguTweaks.rgbhex
local strsplit = ShaguTweaks.strsplit

local scrollspeed = 1
local friendinfo = gsub(gsub(FRIENDS_LEVEL_TEMPLATE,"%%s","%%s %%s"),"%%d","%%s")

local module = ShaguTweaks:register({
  title = T["Chat Tweaks"],
  description = T["Improves chat with mouse wheel scrolling, sticky channels, arrow-up repeat, shortened names, item link preview, Alt/Ctrl-click to invite/target, right-click ignore, chat history, and class colors."],
  expansions = { ["vanilla"] = true },
  category = T["Social & Chat"],
  enabled = true,
  order = 60,
})

-- ============================================================
-- URL pattern helpers (from chat-links)
-- ============================================================
local URLPattern = {
  WWW      = { ["rx"]=" (www%d-)%.([_A-Za-z0-9-]+)%.(%S+)%s?",                                     ["fm"]="%s.%s.%s" },
  PROTOCOL = { ["rx"]=" (%a+)://(%S+)%s?",                                                          ["fm"]="%s://%s" },
  EMAIL    = { ["rx"]=" ([_A-Za-z0-9-%.:]+)@([_A-Za-z0-9-]+)(%.)([_A-Za-z0-9-]+%.?[_A-Za-z0-9-]*)%s?", ["fm"]="%s@%s%s%s" },
  PORTIP   = { ["rx"]=" (%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?):(%d%d?%d?%d?%d?)%s?",     ["fm"]="%s.%s.%s.%s:%s" },
  IP       = { ["rx"]=" (%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%s?",                       ["fm"]="%s.%s.%s.%s" },
  SHORTURL = { ["rx"]=" (%a+)%.(%a+)/(%S+)%s?",                                                    ["fm"]="%s.%s/%s" },
  URLIP    = { ["rx"]=" ([_A-Za-z0-9-]+)%.([_A-Za-z0-9-]+)%.(%S+)%:([_0-9-]+)%s?",               ["fm"]="%s.%s.%s:%s" },
  URL      = { ["rx"]=" ([_A-Za-z0-9-]+)%.([_A-Za-z0-9-]+)%.(%S+)%s?",                            ["fm"]="%s.%s.%s" },
}

local function FormatLink(formatter,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  if not (formatter and a1) then return end
  local newtext = string.format(formatter,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  local invalidtld
  for _, arg in pairs({a10,a9,a8,a7,a6,a5,a4,a3,a2,a1}) do
    if arg then invalidtld = string.find(arg, "(%.%.)$") break end
  end
  if (invalidtld) then return newtext end
  if formatter == URLPattern.EMAIL.fm then
    local colon = string.find(a1,":")
    if (colon) and string.len(a1) > colon then
      if not (string.sub(a1,1,6) == "mailto") then
        local prefix,address = string.sub(newtext,1,colon),string.sub(newtext,colon+1)
        return string.format(" %s|cffccccff|Hurl:%s|h[%s]|h|r ",prefix,address,address)
      end
    end
  end
  return " |cffccccff|Hurl:" .. newtext .. "|h[" .. newtext .. "]|h|r "
end

local URLFuncs = {
  ["WWW"]      = function(a1,a2,a3)        return FormatLink(URLPattern.WWW.fm,a1,a2,a3) end,
  ["PROTOCOL"] = function(a1,a2)           return FormatLink(URLPattern.PROTOCOL.fm,a1,a2) end,
  ["EMAIL"]    = function(a1,a2,a3,a4)     return FormatLink(URLPattern.EMAIL.fm,a1,a2,a3,a4) end,
  ["PORTIP"]   = function(a1,a2,a3,a4,a5)  return FormatLink(URLPattern.PORTIP.fm,a1,a2,a3,a4,a5) end,
  ["IP"]       = function(a1,a2,a3,a4)     return FormatLink(URLPattern.IP.fm,a1,a2,a3,a4) end,
  ["SHORTURL"] = function(a1,a2,a3)        return FormatLink(URLPattern.SHORTURL.fm,a1,a2,a3) end,
  ["URLIP"]    = function(a1,a2,a3,a4)     return FormatLink(URLPattern.URLIP.fm,a1,a2,a3,a4) end,
  ["URL"]      = function(a1,a2,a3)        return FormatLink(URLPattern.URL.fm,a1,a2,a3) end,
}

local function HandleLink(text)
  text = string.gsub(text, URLPattern.WWW.rx,      URLFuncs.WWW)
  text = string.gsub(text, URLPattern.PROTOCOL.rx,  URLFuncs.PROTOCOL)
  text = string.gsub(text, URLPattern.EMAIL.rx,     URLFuncs.EMAIL)
  text = string.gsub(text, URLPattern.PORTIP.rx,    URLFuncs.PORTIP)
  text = string.gsub(text, URLPattern.IP.rx,        URLFuncs.IP)
  text = string.gsub(text, URLPattern.SHORTURL.rx,  URLFuncs.SHORTURL)
  text = string.gsub(text, URLPattern.URLIP.rx,     URLFuncs.URLIP)
  text = string.gsub(text, URLPattern.URL.rx,       URLFuncs.URL)
  return text
end

-- URL copy dialog
local CopyLinkDialog = CreateFrame("Frame", "ShaguTweaksURLCopy", UIParent)
CopyLinkDialog:Hide()
CopyLinkDialog:SetWidth(300)
CopyLinkDialog:SetHeight(90)
CopyLinkDialog:SetFrameStrata("FULLSCREEN")
CopyLinkDialog:SetPoint("CENTER", 0, 0)
CopyLinkDialog:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
CopyLinkDialog:SetScript("OnShow", function() this.text:HighlightText() end)

CopyLinkDialog.text = CreateFrame("EditBox", "ShaguTweaksURLCopyEditBox", CopyLinkDialog)
CopyLinkDialog.text:SetTextColor(1,.8,0)
CopyLinkDialog.text:SetJustifyH("CENTER")
CopyLinkDialog.text:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
CopyLinkDialog.text:SetBackdropColor(0,0,0,.8)
CopyLinkDialog.text:SetBackdropBorderColor(.8,.8,.8,1)
CopyLinkDialog.text:SetWidth(260)
CopyLinkDialog.text:SetHeight(25)
CopyLinkDialog.text:SetPoint("TOP", CopyLinkDialog, "TOP", 0, -20)
CopyLinkDialog.text:SetFontObject(GameFontNormal)
CopyLinkDialog.text:SetScript("OnEscapePressed", function() CopyLinkDialog:Hide() end)
CopyLinkDialog.text:SetScript("OnEditFocusLost",  function() CopyLinkDialog:Hide() end)

CopyLinkDialog.close = CreateFrame("Button", "ShaguTweaksURLCopyClose", CopyLinkDialog, "UIPanelButtonTemplate")
CopyLinkDialog.close:SetPoint("BOTTOMRIGHT", CopyLinkDialog, "BOTTOMRIGHT", -20, 20)
CopyLinkDialog.close:SetWidth(70)
CopyLinkDialog.close:SetHeight(18)
CopyLinkDialog.close:SetText(CLOSE)
CopyLinkDialog.close:SetScript("OnClick", function() CopyLinkDialog:Hide() end)
CopyLinkDialog.CopyText = function(text)
  CopyLinkDialog.text:SetText(text)
  CopyLinkDialog:Show()
end

-- ============================================================
-- Module enable
-- ============================================================
module.enable = function(self)

  -- --------------------------------------------------------
  -- Blue Shaman class colors (vanilla only)
  -- --------------------------------------------------------
  if GetExpansion() == "vanilla" then
    RAID_CLASS_COLORS = {
      ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
      ["MAGE"]    = { r = 0.41, g = 0.8,  b = 0.94, colorStr = "ff69ccf0" },
      ["ROGUE"]   = { r = 1,    g = 0.96, b = 0.41, colorStr = "fffff569" },
      ["DRUID"]   = { r = 1,    g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
      ["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
      ["SHAMAN"]  = { r = 0.14, g = 0.35, b = 1.0,  colorStr = "ff2459ff" },
      ["PRIEST"]  = { r = 1,    g = 1,    b = 1,    colorStr = "ffffffff" },
      ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
      ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
    }
    RAID_CLASS_COLORS = setmetatable(RAID_CLASS_COLORS, { __index = function(tab,key)
      return { r = 0.6, g = 0.6, b = 0.6, colorStr = "ff999999" }
    end})
  end

  -- --------------------------------------------------------
  -- Sticky channels & arrow-up repeat
  -- --------------------------------------------------------
  ChatTypeInfo.WHISPER.sticky      = 1
  ChatTypeInfo.OFFICER.sticky      = 1
  ChatTypeInfo.RAID_WARNING.sticky = 1
  ChatTypeInfo.CHANNEL.sticky      = 1
  ChatFrameEditBox:SetAltArrowKeyMode(false)

  -- --------------------------------------------------------
  -- Mouse wheel scrolling
  -- --------------------------------------------------------
  local function ChatOnMouseWheel()
    if arg1 > 0 then
      if IsShiftKeyDown() then this:ScrollToTop()
      else for i=1,scrollspeed do this:ScrollUp() end end
    elseif arg1 < 0 then
      if IsShiftKeyDown() then this:ScrollToBottom()
      else for i=1,scrollspeed do this:ScrollDown() end end
    end
    if this:AtBottom() then
      _G[this:GetName().."BottomButton"]:Hide()
      this.scroll = nil
    else
      this.scroll = true
      _G[this:GetName().."BottomButton"]:Show()
    end
  end

  for i=1, NUM_CHAT_WINDOWS do
    _G["ChatFrame"..i]:EnableMouseWheel(true)
    _G["ChatFrame"..i].scroll = nil
    _G["ChatFrame"..i]:SetScript("OnMouseWheel", ChatOnMouseWheel)
  end

  -- --------------------------------------------------------
  -- Chat history save/restore
  -- --------------------------------------------------------
  local realm  = GetRealmName()
  local player = UnitName("player")

  local function SaveChatHistory(id, msg, r, g, b)
    ShaguTweaks_cache = ShaguTweaks_cache or {}
    ShaguTweaks_cache["chathistory"] = ShaguTweaks_cache["chathistory"] or {}
    ShaguTweaks_cache["chathistory"][realm] = ShaguTweaks_cache["chathistory"][realm] or {}
    ShaguTweaks_cache["chathistory"][realm][player] = ShaguTweaks_cache["chathistory"][realm][player] or {}
    ShaguTweaks_cache["chathistory"][realm][player][id] = ShaguTweaks_cache["chathistory"][realm][player][id] or {}
    if r and g and b then
      local color = rgbhex(r*.5+.2, g*.5+.2, b*.5+.2)
      msg = string.gsub(msg, "^", color)
      msg = string.gsub(msg, "|r", "|r"..color)
    end
    local history = ShaguTweaks_cache["chathistory"][realm][player][id]
    table.insert(history, 1, msg)
    if history[30] then table.remove(history, 30) end
  end

  local function GetChatHistory(id)
    ShaguTweaks_cache = ShaguTweaks_cache or {}
    ShaguTweaks_cache["chathistory"] = ShaguTweaks_cache["chathistory"] or {}
    ShaguTweaks_cache["chathistory"][realm] = ShaguTweaks_cache["chathistory"][realm] or {}
    ShaguTweaks_cache["chathistory"][realm][player] = ShaguTweaks_cache["chathistory"][realm][player] or {}
    ShaguTweaks_cache["chathistory"][realm][player][id] = ShaguTweaks_cache["chathistory"][realm][player][id] or {}
    return ShaguTweaks_cache["chathistory"][realm][player][id]
  end

  -- --------------------------------------------------------
  -- Per-frame hooks: history + CLINK cleanup + URLs + class colors
  -- --------------------------------------------------------
  for i=1, NUM_CHAT_WINDOWS do
    local isCombat = 0
    if _G["ChatFrame"..i] and _G["ChatFrame"..i].messageTypeList then
      for _, msg in pairs(_G["ChatFrame"..i].messageTypeList) do
        if strfind(msg,"SPELL",1) or strfind(msg,"COMBAT",1) then
          isCombat = isCombat + 1
        end
      end
    end

    if isCombat <= 5 and _G["ChatFrame"..i] and not _G["ChatFrame"..i].ShaguTweaksChatTweaksHooked then
      _G["ChatFrame"..i].ShaguTweaksChatTweaksHooked = true

      -- restore history
      local history = GetChatHistory(i)
      for j=30,0,-1 do
        if history[j] then _G["ChatFrame"..i]:AddMessage(history[j], .7,.7,.7) end
      end

      _G["ChatFrame"..i].ShaguTweaksBaseAddMessage = _G["ChatFrame"..i].AddMessage
      _G["ChatFrame"..i].AddMessage = function(frame, text, a1, a2, a3, a4, a5)
        if not text then return end

        -- Remove prat/chatter CLINKs
        text = gsub(text, "{CLINK:(%x+):([%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-):([^}]-)}", "|c%1|Hitem:%2|h[%3]|h|r")
        text = gsub(text, "{CLINK:(%x+):([%d-]-:[%d-]-:[%d-]-:[%d-]-):([^}]-)}", "|c%1|Hitem:%2|h[%3]|h|r")
        text = gsub(text, "{CLINK:item:(%x+):([%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-:[%d-]-):([^}]-)}", "|c%1|Hitem:%2|h[%3]|h|r")
        text = gsub(text, "{CLINK:enchant:(%x+):([%d-]-):([^}]-)}", "|c%1|Henchant:%2|h[%3]|h|r")
        text = gsub(text, "{CLINK:spell:(%x+):([%d-]-):([^}]-)}", "|c%1|Hspell:%2|h[%3]|h|r")
        text = gsub(text, "{CLINK:quest:(%x+):([%d-]-):([%d-]-):([^}]-)}", "|c%1|Hquest:%2:%3|h[%4]|h|r")

        -- Reduce channel number (e.g. [1. General] -> [1])
        local channel = string.gsub(text, ".*%[(.-)%]%s+(.*|Hplayer).+", "%1")
        if string.find(channel, "%d+%. ") then
          channel = string.gsub(channel, "(%d+)%..*", "%1")
          text = string.gsub(text, "%[%d+%..-%]%s+(.*|Hplayer)", "[" .. channel .. "] %1")
        end

        -- URL detection
        text = HandleLink(text)

        -- Class colors on player links
        for name in gfind(text, "|Hplayer:(.-)|h") do
          local real, _ = strsplit(":", name)
          local color = "|cffaaaaaa"
          local class = GetUnitData(real)
          if class and class ~= UNKNOWN then
            color = rgbhex(RAID_CLASS_COLORS[class])
          end
          text = string.gsub(text, "|Hplayer:"..name.."|h%["..real.."%]|h(.-:-)",
            "|r["..color.."|Hplayer:"..name.."|h"..color..real.."|h|r".."]|r".."%1")
        end

        SaveChatHistory(frame:GetID(), text, a1, a2, a3)
        frame:ShaguTweaksBaseAddMessage(text, a1, a2, a3, a4, a5)
      end

      -- Item link tooltip on mouseover
      _G["ChatFrame"..i]:SetScript("OnHyperlinkEnter", function()
        local _, _, linktype = string.find(arg1, "^(.-):(.+)$")
        if linktype == "item" then
          GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
          GameTooltip:SetHyperlink(arg1)
          GameTooltip:Show()
        end
      end)
      _G["ChatFrame"..i]:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
      end)

      -- Alt/Ctrl-click player names; URL copy
      _G["ChatFrame"..i]:SetScript("OnHyperlinkClick", function()
        local _, _, playerLink = string.find(arg1, "(player:.+)")
        if playerLink then
          local _, pname = strsplit(":", playerLink)
          if IsAltKeyDown() then
            InviteByName(pname)
          elseif IsControlKeyDown() then
            TargetByName(pname, true)
          else
            ChatFrame_OnHyperlinkShow(arg1, arg2, arg3)
          end
        elseif strsub(arg1,1,3) == "url" then
          if string.len(arg1) > 4 and string.sub(arg1,1,4) == "url:" then
            CopyLinkDialog.CopyText(string.sub(arg1, 5))
          end
        else
          ChatFrame_OnHyperlinkShow(arg1, arg2, arg3)
        end
      end)
    end
  end

  -- --------------------------------------------------------
  -- Shorten channel names
  -- --------------------------------------------------------
  local left, right = "[", "]"
  local default = " " .. "%s" .. "|r:" .. "\32"
  _G.CHAT_CHANNEL_GET             = "%s"               .. "|r:" .. "\32"
  _G.CHAT_GUILD_GET               = left.."G"..right   .. default
  _G.CHAT_OFFICER_GET             = left.."O"..right   .. default
  _G.CHAT_PARTY_GET               = left.."P"..right   .. default
  _G.CHAT_RAID_GET                = left.."R"..right   .. default
  _G.CHAT_RAID_LEADER_GET         = left.."RL"..right  .. default
  _G.CHAT_RAID_WARNING_GET        = left.."RW"..right  .. default
  _G.CHAT_BATTLEGROUND_GET        = left.."BG"..right  .. default
  _G.CHAT_BATTLEGROUND_LEADER_GET = left.."BL"..right  .. default
  _G.CHAT_SAY_GET                 = left.."S"..right   .. default
  _G.CHAT_YELL_GET                = left.."Y"..right   .. default
  _G.CHAT_WHISPER_GET             = "[From]"           .. default
  _G.CHAT_WHISPER_INFORM_GET      = "[To]"             .. default

  -- --------------------------------------------------------
  -- SetItemRef hook for URL/quest/player links
  -- --------------------------------------------------------
  local HookSetItemRef = SetItemRef
  function _G.SetItemRef(link, text, button)
    if (strsub(link,1,3) == "url") then
      if string.len(link) > 4 and string.sub(link,1,4) == "url:" then
        CopyLinkDialog.CopyText(string.sub(link, 5))
      end
      return
    end
    local questlink, _, quest_id = string.find(link, "quest:(%d+):.*")
    local playerlink = strsub(link,1,6) == "player"
    if ShaguQuest or pfQuest or Questie then questlink = nil end
    if questlink then
      local _, _, quest_title = string.find(text, ".*|h%[(.*)%]|h.*")
      if quest_title then
        HideUIPanel(ItemRefTooltip)
        ShowUIPanel(ItemRefTooltip)
        ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
        ItemRefTooltip:AddLine(quest_title, 1,1,0)
        ItemRefTooltip:AddDoubleLine("Quest ID", quest_id, .6,.6,.6, 1,1,1)
        ItemRefTooltip:Show()
      end
      return
    elseif playerlink then
      local name = strsub(link, 8)
      if name and strlen(name) > 0 then
        local n, _ = strsplit(":", name)
        n = gsub(n, "([^%s]*)%s+([^%s]*)%s+([^%s]*)", "%3")
        n = gsub(n, "([^%s]*)%s+([^%s]*)", "%2")
        if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
          ChatFrameEditBox:Insert("|cffffffff|Hplayer:"..n.."|h["..n.."]|h|r")
          return
        end
      end
    end
    HookSetItemRef(link, text, button)
  end

  -- --------------------------------------------------------
  -- Right-click ignore
  -- --------------------------------------------------------
  UnitPopupButtons["IGNORE_PLAYER"] = { text = "Ignore", dist = 0 }
  for index, value in ipairs(UnitPopupMenus["FRIEND"]) do
    if value == "GUILD_LEAVE" then
      table.insert(UnitPopupMenus["FRIEND"], index+1, "IGNORE_PLAYER")
    end
  end
  hooksecurefunc("UnitPopup_OnClick", function(self)
    if this.value == "IGNORE_PLAYER" then
      AddIgnore(_G[UIDROPDOWNMENU_INIT_MENU].name)
    end
  end)

  -- --------------------------------------------------------
  -- Social colors: guild, friends, who lists
  -- --------------------------------------------------------
  ShaguTweaks_cache = ShaguTweaks_cache or {}
  ShaguTweaks_cache["players"] = ShaguTweaks_cache["players"] or {}
  local playerdb = ShaguTweaks_cache["players"]

  local socialmod = CreateFrame("Frame", "ShaguTweaksSocialMod", UIParent)
  socialmod:RegisterEvent("CHAT_MSG_SYSTEM")
  socialmod:SetScript("OnEvent", function()
    local name = cmatch(arg1, _G.ERR_FRIEND_ONLINE_SS) or cmatch(arg1, _G.ERR_FRIEND_OFFLINE_S)
    if name and playerdb[name] and playerdb[name].cname then
      playerdb[name].lastseen = date("%a %d-%b-%Y")
    end
  end)

  hooksecurefunc("GuildStatus_Update", function()
    local playerzone = GetRealZoneText()
    local off = FauxScrollFrame_GetOffset(GuildListScrollFrame)
    local _, _, playerrankindex = GetGuildInfo("player")
    for i=1, GUILDMEMBERS_TO_DISPLAY do
      local name, _, rankindex, level, class, zone, _, _, online = GetGuildRosterInfo(off + i)
      class = L["class"][class]
      if name then
        if class then
          local color = RAID_CLASS_COLORS[class]
          local alpha = online and 1 or .5
          _G["GuildFrameButton"..i.."Name"]:SetTextColor(color.r, color.g, color.b, alpha)
          _G["GuildFrameButton"..i.."Class"]:SetTextColor(color.r, color.g, color.b, alpha)
          _G["GuildFrameGuildStatusButton"..i.."Name"]:SetTextColor(color.r, color.g, color.b, alpha)
        end
        if level then
          local color = GetDifficultyColor(level)
          local alpha = online and 1 or .5
          _G["GuildFrameButton"..i.."Level"]:SetTextColor(color.r+.2, color.g+.2, color.b+.2, alpha)
        end
        if zone and zone == playerzone then
          local alpha = online and 1 or .5
          _G["GuildFrameButton"..i.."Zone"]:SetTextColor(.5, 1, 1, alpha)
        end
        if rankindex and rankindex == playerrankindex then
          local alpha = online and 1 or .5
          _G["GuildFrameGuildStatusButton"..i.."Rank"]:SetTextColor(.5, 1, 1, alpha)
        end
      end
    end
  end)

  local FRIENDS_NAME_LOCATION = GetExpansion() == "vanilla" and "ButtonTextNameLocation" or "ButtonTextLocation"
  hooksecurefunc("FriendsList_Update", function()
    if GetNumFriends() == 0 then return end
    local playerzone = GetRealZoneText()
    local off = FauxScrollFrame_GetOffset(FriendsFrameFriendsScrollFrame)
    for i=1, FRIENDS_TO_DISPLAY do
      local name, level, class, zone, connected, status = GetFriendInfo(off + i)
      if not name or name == _G.UNKNOWN then break end
      local friendName = _G["FriendsFrameFriendButton"..i.."ButtonTextName"]
      local friendLoc  = _G["FriendsFrameFriendButton"..i..FRIENDS_NAME_LOCATION]
      local friendInfo = _G["FriendsFrameFriendButton"..i.."ButtonTextInfo"]
      local caption    = friendName or friendLoc
      if connected then
        local classToken = class and class ~= _G.UNKNOWN and L["class"][class] or GetUnitData(name)
        local ccolor = classToken and RAID_CLASS_COLORS[classToken]
        local lcolor = GetDifficultyColor(tonumber(level)) or { 1,1,1 }
        local displayZone = zone or ""
        displayZone = (displayZone == playerzone and "|cffffffff" or "|cffcccccc") .. displayZone .. "|r"
        local cname  = ccolor and (rgbhex(ccolor) .. name .. "|r") or name
        local clevel = rgbhex(lcolor) .. level .. "|r"
        local classLabel = class and class ~= _G.UNKNOWN and class or _G.UNKNOWN
        if ccolor then
          playerdb[name] = playerdb[name] or {}
          playerdb[name].lastseen = date("%a %d-%b-%Y")
          playerdb[name].cname  = cname
          playerdb[name].clevel = clevel
          playerdb[name].cclass = ccolor
        end
        if friendName then
          friendName:SetText(cname)
          friendLoc:SetText(format(TEXT(FRIENDS_LIST_TEMPLATE), displayZone, status))
        else
          friendLoc:SetText(format(TEXT(FRIENDS_LIST_TEMPLATE), cname, displayZone, status))
        end
        friendInfo:SetText(format(TEXT(friendinfo), clevel, classLabel, ""))
        caption:SetVertexColor(1,1,1,.9)
        friendInfo:SetVertexColor(1,1,1,.9)
      else
        if playerdb[name] and playerdb[name].cname and playerdb[name].clevel and playerdb[name].lastseen then
          caption:SetText(format(TEXT(FRIENDS_LIST_OFFLINE_TEMPLATE), playerdb[name].cname))
          friendInfo:SetText(format(TEXT(friendinfo), playerdb[name].clevel, playerdb[name].lastseen, ""))
        else
          caption:SetText(format(TEXT(FRIENDS_LIST_OFFLINE_TEMPLATE), name.."|r"))
          friendInfo:SetText(TEXT(UNKNOWN))
        end
        caption:SetVertexColor(1,1,1,.4)
        friendInfo:SetVertexColor(1,1,1,.4)
      end
    end
  end)

  hooksecurefunc("WhoList_Update", function()
    local num, max = GetNumWhoResults()
    local off = FauxScrollFrame_GetOffset(WhoListScrollFrame)
    local playerzone  = GetRealZoneText()
    local playerrace  = UnitRace("player")
    local playerguild = GetGuildInfo("player")
    for i=1, WHOS_TO_DISPLAY do
      local name, guild, level, race, class, zone = GetWhoInfo(off + i)
      local displayedText = ""
      if num + 1 >= MAX_WHOS_FROM_SERVER then
        displayedText = format(WHO_FRAME_SHOWN_TEMPLATE, MAX_WHOS_FROM_SERVER)
        WhoFrameTotals:SetText("|cffffffff"..format(GetText("WHO_FRAME_TOTAL_TEMPLATE",nil,num),max).."  |cffaaaaaa"..displayedText)
      else
        displayedText = format(WHO_FRAME_SHOWN_TEMPLATE, num)
        WhoFrameTotals:SetText("|cffffffff"..format(GetText("WHO_FRAME_TOTAL_TEMPLATE",nil,num),num).."  |cffaaaaaa"..displayedText)
      end
      local classToken = class and L["class"][class] or (name and GetUnitData(name))
      local nameButton = _G["WhoFrameButton"..i.."Name"]
      local classButton = _G["WhoFrameButton"..i.."Class"]
      nameButton:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
      classButton:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
      if UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 1 then
        _G["WhoFrameButton"..i.."Variable"]:SetTextColor(zone == playerzone and .5 or 1, 1, 1)
      elseif UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 2 then
        _G["WhoFrameButton"..i.."Variable"]:SetTextColor(guild == playerguild and .5 or 1, 1, 1)
      elseif UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 3 then
        _G["WhoFrameButton"..i.."Variable"]:SetTextColor(race == playerrace and .5 or 1, 1, 1)
      end
      if classToken then
        local color = RAID_CLASS_COLORS[classToken]
        nameButton:SetTextColor(color.r, color.g, color.b, 1)
        classButton:SetTextColor(color.r, color.g, color.b, 1)
      end
      if level then
        local color = GetDifficultyColor(level)
        _G["WhoFrameButton"..i.."Level"]:SetTextColor(color.r, color.g, color.b)
      end
    end
  end)

end
