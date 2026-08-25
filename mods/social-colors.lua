local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local L = ShaguTweaks.L
local gfind = string.gmatch or string.gfind
local GetUnitData = ShaguTweaks.GetUnitData
local hooksecurefunc = ShaguTweaks.hooksecurefunc
local GetExpansion = ShaguTweaks.GetExpansion
local cmatch = ShaguTweaks.cmatch
local rgbhex = ShaguTweaks.rgbhex
local strsplit = ShaguTweaks.strsplit
local friendinfo = gsub(gsub(FRIENDS_LEVEL_TEMPLATE,"%%s","%%s %%s"),"%%d","%%s")

local module = ShaguTweaks:register({
  title = T["Social Colors"],
  description = T["Show class colors in Who, Guild, Friends and Chat."],
  expansions = { ["vanilla"] = true },
  category = T["Social & Chat"],
  enabled = true,
})

local function ChatTweaksOwnsSocialColors()
  local configured = ShaguTweaks_config and ShaguTweaks_config[T["Chat Tweaks"]]
  if configured ~= nil then return configured == 1 end

  -- On a fresh install config defaults are initialized while modules are
  -- enabled, so fall back to the registered module default when needed.
  local chat = ShaguTweaks.mods and ShaguTweaks.mods[T["Chat Tweaks"]]
  return chat and chat.enabled or false
end

local function GetPlayerDB()
  ShaguTweaks_cache = ShaguTweaks_cache or {}
  ShaguTweaks_cache["players"] = ShaguTweaks_cache["players"] or {}
  return ShaguTweaks_cache["players"]
end

local function CacheVisibleOnlineFriends(playerdb)
  if GetNumFriends() == 0 then return end

  local off = FauxScrollFrame_GetOffset(FriendsFrameFriendsScrollFrame)
  for i=1, FRIENDS_TO_DISPLAY do
    local name, level, class, _, connected = GetFriendInfo(off + i)
    if not name or name == _G.UNKNOWN then break end

    if connected then
      local classToken = class and class ~= _G.UNKNOWN and L["class"][class] or GetUnitData(name)
      local ccolor = classToken and RAID_CLASS_COLORS[classToken]
      local lcolor = GetDifficultyColor(tonumber(level))

      if ccolor and lcolor then
        playerdb[name] = playerdb[name] or {}
        playerdb[name].lastseen = date("%a %d-%b-%Y")
        playerdb[name].cname = rgbhex(ccolor) .. name .. "|r"
        playerdb[name].clevel = rgbhex(lcolor) .. level .. "|r"
        playerdb[name].cclass = ccolor
      end
    end
  end
end

module.enable = function(self)
  local playerdb = GetPlayerDB()

  -- Chat Tweaks contains the same social-color rendering hooks in this fork.
  -- When it owns the UI, keep Social Colors limited to a tiny local cache hook
  -- so friends retain their known class color while offline. This does not
  -- issue /who requests, add timers, or perform any extra server query.
  if ChatTweaksOwnsSocialColors() then
    hooksecurefunc("FriendsList_Update", function()
      CacheVisibleOnlineFriends(playerdb)
    end)
    return
  end

do -- add class colors to chat
    for i=1,NUM_CHAT_WINDOWS do
      local chatFrame = _G["ChatFrame"..i]
      if chatFrame and not chatFrame.HookAddMessageColor and not Prat then
        chatFrame.HookAddMessageColor = chatFrame.AddMessage
        chatFrame.AddMessage = function(frame, text, a1, a2, a3, a4, a5)
          if frame.ShaguTweaksChatTweaksHooked then
            frame.HookAddMessageColor(frame, text, a1, a2, a3, a4, a5)
            return
          end

          if text then
            for name in gfind(text, "|Hplayer:(.-)|h") do
              local real = strsplit(":", name)
              local class = GetUnitData(real)
              if class and class ~= UNKNOWN then
                local color = rgbhex(RAID_CLASS_COLORS[class])
                text = string.gsub(text,
                  "|Hplayer:"..name.."|h%["..real.."%]|h(.-:-)",
                  "|r["..color.."|Hplayer:"..name.."|h"..color..real.."|h|r]|r%1")
              end
            end
          end
          frame.HookAddMessageColor(frame, text, a1, a2, a3, a4, a5)
        end
      end
    end
  end

  local socialmod = CreateFrame("Frame", "ShaguTweaksSocialMod", UIParent)
  socialmod:RegisterEvent("CHAT_MSG_SYSTEM")
  socialmod:SetScript("OnEvent", function()
    local name = cmatch(arg1, _G.ERR_FRIEND_ONLINE_SS) or cmatch(arg1, _G.ERR_FRIEND_OFFLINE_S)
    if name and playerdb[name] and playerdb[name].cname then
      playerdb[name].lastseen = date("%a %d-%b-%Y")
    end
  end)

  do -- add colors to guild list
    hooksecurefunc("GuildStatus_Update", function()
      local playerzone = GetRealZoneText()
      local off = FauxScrollFrame_GetOffset(GuildListScrollFrame)
      local _, _, playerrankindex = GetGuildInfo("player")

      for i=1, GUILDMEMBERS_TO_DISPLAY, 1 do
        local name, _, rankindex, level, class, zone, _, _, online = GetGuildRosterInfo(off + i)

        class = L["class"][class]

        if name then
          if class then
            local color = RAID_CLASS_COLORS[class]
            if online then
              _G["GuildFrameButton"..i.."Name"]:SetTextColor(color.r,color.g,color.b,1)
              _G["GuildFrameButton"..i.."Class"]:SetTextColor(color.r,color.g,color.b,1)
              _G["GuildFrameGuildStatusButton"..i.."Name"]:SetTextColor(color.r,color.g,color.b,1)
            else
              _G["GuildFrameButton"..i.."Name"]:SetTextColor(color.r,color.g,color.b,.5)
              _G["GuildFrameButton"..i.."Class"]:SetTextColor(color.r,color.g,color.b,.5)
              _G["GuildFrameGuildStatusButton"..i.."Name"]:SetTextColor(color.r,color.g,color.b,.5)
            end
          end

          if level then
            local color = GetDifficultyColor(level)
            if online then
              _G["GuildFrameButton"..i.."Level"]:SetTextColor(color.r + .2, color.g + .2, color.b + .2, 1)
            else
              _G["GuildFrameButton"..i.."Level"]:SetTextColor(color.r + .2, color.g + .2, color.b + .2, .5)
            end
          end

          if zone and zone == playerzone then
            if online then
              _G["GuildFrameButton"..i.."Zone"]:SetTextColor(.5, 1, 1, 1)
            else
              _G["GuildFrameButton"..i.."Zone"]:SetTextColor(.5, 1, 1, .5)
            end
          end

          if rankindex and rankindex == playerrankindex then
            if online then
              _G["GuildFrameGuildStatusButton"..i.."Rank"]:SetTextColor(.5, 1, 1, 1)
            else
              _G["GuildFrameGuildStatusButton"..i.."Rank"]:SetTextColor(.5, 1, 1, .5)
            end
          end
        end
      end
    end)
  end

  do -- add colors to friend list
    local FRIENDS_NAME_LOCATION = GetExpansion() == "vanilla" and "ButtonTextNameLocation" or "ButtonTextLocation"
    hooksecurefunc("FriendsList_Update", function()
      if GetNumFriends() == 0 then return end

      local playerzone = GetRealZoneText()
      local off = FauxScrollFrame_GetOffset(FriendsFrameFriendsScrollFrame)

      for i=1, FRIENDS_TO_DISPLAY do
        local name, level, class, zone, connected, status = GetFriendInfo(off + i)
        if not name or name == _G.UNKNOWN then break end
        local friendName = _G["FriendsFrameFriendButton"..i.."ButtonTextName"]
        local friendLoc = _G["FriendsFrameFriendButton"..i..FRIENDS_NAME_LOCATION]
        local friendInfo = _G["FriendsFrameFriendButton"..i.."ButtonTextInfo"]
        local caption = friendName or friendLoc

        if connected then
          local classToken = class and class ~= _G.UNKNOWN and L["class"][class] or GetUnitData(name)
          local ccolor = classToken and RAID_CLASS_COLORS[classToken]
          local lcolor = GetDifficultyColor(tonumber(level)) or { 1, 1, 1 }
          local displayZone = zone or ""

          displayZone = (displayZone == playerzone and "|cffffffff" or "|cffcccccc") .. displayZone .. "|r"
          local cname = ccolor and (rgbhex(ccolor) .. name .. "|r") or name
          local clevel = rgbhex(lcolor) .. level .. "|r"
          local classLabel = class and class ~= _G.UNKNOWN and class or _G.UNKNOWN

          if ccolor then
            playerdb[name] = playerdb[name] or {}
            playerdb[name].lastseen = date("%a %d-%b-%Y")
            playerdb[name].cname = cname
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
  end

  do -- add colors to who list
    hooksecurefunc("WhoList_Update", function()
      local num, max = GetNumWhoResults()
      local off = FauxScrollFrame_GetOffset(WhoListScrollFrame)

      local playerzone = GetRealZoneText()
      local playerrace = UnitRace("player")
      local playerguild = GetGuildInfo("player")

      for i=1, WHOS_TO_DISPLAY do
        local name, guild, level, race, class, zone = GetWhoInfo(off + i)
        local displayedText = ""

        if num + 1 >= MAX_WHOS_FROM_SERVER then
          displayedText = format(WHO_FRAME_SHOWN_TEMPLATE, MAX_WHOS_FROM_SERVER)
          WhoFrameTotals:SetText("|cffffffff" .. format(GetText("WHO_FRAME_TOTAL_TEMPLATE", nil, num), max).."  |cffaaaaaa"..displayedText)
        else
          displayedText = format(WHO_FRAME_SHOWN_TEMPLATE, num)
          WhoFrameTotals:SetText("|cffffffff" .. format(GetText("WHO_FRAME_TOTAL_TEMPLATE", nil, num), num).."  |cffaaaaaa"..displayedText)
        end

        local classToken = class and L["class"][class] or (name and GetUnitData(name))
        local nameButton = _G["WhoFrameButton"..i.."Name"]
        local classButton = _G["WhoFrameButton"..i.."Class"]

        nameButton:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        classButton:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

        if (UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 1) then
          if (zone == playerzone) then
            _G["WhoFrameButton"..i.."Variable"]:SetTextColor(.5, 1, 1)
          else
            _G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
          end

        elseif (UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 2) then
          if (guild == playerguild) then
            _G["WhoFrameButton"..i.."Variable"]:SetTextColor(.5, 1, 1)
          else
            _G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
          end

        elseif (UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 3) then
          if (race == playerrace) then
            _G["WhoFrameButton"..i.."Variable"]:SetTextColor(.5, 1, 1)
          else
            _G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
          end
        end

        if classToken then
          local color = RAID_CLASS_COLORS[classToken]
          nameButton:SetTextColor(color.r,color.g,color.b,1)
          classButton:SetTextColor(color.r,color.g,color.b,1)
        end

        if level then
          local color = GetDifficultyColor(level)
          _G["WhoFrameButton"..i.."Level"]:SetTextColor(color.r, color.g, color.b)
        end
      end
    end)
  end
end
