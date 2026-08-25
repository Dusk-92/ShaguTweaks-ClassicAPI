local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API or {}
local rgbhex = ShaguTweaks.rgbhex
local strsplit = ShaguTweaks.strsplit

local scrollspeed = 1

local module = ShaguTweaks:register({
  title = T["Chat Tweaks"],
  description = T["Improves chat with mouse wheel scrolling, sticky channels, arrow-up repeat, shortened names, item link preview, Alt/Ctrl-click to invite/target, chat history, and clickable URLs."],
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
      if API.IsShiftKeyDown and API.IsShiftKeyDown() then this:ScrollToTop()
      else for i=1,scrollspeed do this:ScrollUp() end end
    elseif arg1 < 0 then
      if API.IsShiftKeyDown and API.IsShiftKeyDown() then this:ScrollToBottom()
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
  -- Per-frame hooks: history + CLINK cleanup + URLs
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

        SaveChatHistory(frame:GetID(), text, a1, a2, a3)
        frame:ShaguTweaksBaseAddMessage(text, a1, a2, a3, a4, a5)
      end

      local chatFrame = _G["ChatFrame"..i]
      local baseHyperlinkEnter = chatFrame:GetScript("OnHyperlinkEnter")
      local baseHyperlinkLeave = chatFrame:GetScript("OnHyperlinkLeave")
      local baseHyperlinkClick = chatFrame:GetScript("OnHyperlinkClick")

      -- Add the item-link preview without discarding Turtle or addon handlers.
      chatFrame:SetScript("OnHyperlinkEnter", function()
        local _, _, linktype = string.find(arg1, "^(.-):(.+)$")
        if linktype == "item" then
          this.ShaguTweaksItemTooltip = true
          GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
          GameTooltip:SetHyperlink(arg1)
          GameTooltip:Show()
        elseif baseHyperlinkEnter then
          baseHyperlinkEnter()
        end
      end)

      chatFrame:SetScript("OnHyperlinkLeave", function()
        if this.ShaguTweaksItemTooltip then
          this.ShaguTweaksItemTooltip = nil
          GameTooltip:Hide()
        elseif baseHyperlinkLeave then
          baseHyperlinkLeave()
        end
      end)

      -- Keep Chat Tweaks-specific actions local to the chat frame. All other
      -- hyperlinks, including Turtle quest links, stay owned by the native
      -- handler so their full tooltip data and difficulty colors are preserved.
      chatFrame:SetScript("OnHyperlinkClick", function()
        local _, _, playerLink = string.find(arg1, "(player:.+)")
        if playerLink then
          local _, pname = strsplit(":", playerLink)
          if API.IsAltKeyDown and API.IsAltKeyDown() then
            InviteByName(pname)
            return
          elseif API.IsControlKeyDown and API.IsControlKeyDown() then
            TargetByName(pname, true)
            return
          elseif API.IsShiftKeyDown and API.IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert("|cffffffff|Hplayer:"..pname.."|h["..pname.."]|h|r")
            return
          end
        elseif strsub(arg1,1,3) == "url" then
          if string.len(arg1) > 4 and string.sub(arg1,1,4) == "url:" then
            CopyLinkDialog.CopyText(string.sub(arg1, 5))
          end
          return
        end

        if baseHyperlinkClick then
          baseHyperlinkClick()
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
end