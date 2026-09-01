local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local gfind = string.gmatch or string.gfind
local rgbhex = ShaguTweaks.rgbhex
local strsplit = ShaguTweaks.strsplit
local GetPlayerCache = ShaguTweaks.GetPlayerCache

local module = ShaguTweaks:register({
    title = T["Chat Levels"],
    description = T["Shows player levels in chat."],
    expansions = { ["vanilla"] = true },
    category = T["Chat & Social"],
    enabled = nil,
})

module.enable = function(self)
  local events = CreateFrame("Frame", nil, UIParent)
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", function()
    if this.loaded then return end
    this.loaded = true

    local playerdb = GetPlayerCache()

    for i=1, NUM_CHAT_WINDOWS do
      local frame = _G["ChatFrame"..i]
      if frame and not frame.HookAddMessageLevel and not Prat then
        frame.HookAddMessageLevel = frame.AddMessage
        frame.AddMessage = function(f, text, a1, a2, a3, a4, a5)
          if text and playerdb then
            for linkName in gfind(text, "|Hplayer:(.-)|h") do
              -- Turtle/other chat handlers may append metadata after the
              -- actual player name in the hyperlink payload. Keep the full
              -- payload in the link, but use only the real name for our cache.
              local real = strsplit(":", linkName)
              local data = real and playerdb[real]
              if data and data.level then
                local level = data.level
                local color = rgbhex(GetDifficultyColor(level))
                text = string.gsub(text,
                  "|Hplayer:" .. linkName .. "|h%[" .. real .. "%]|h|r",
                  "|Hplayer:" .. linkName .. "|h[" .. real .. "]|h|r " .. color .. level .. "|r")
              end
            end
          end

          -- Call the wrapper owned by the frame being invoked. This keeps the
          -- hook chain correct even if another chat addon wraps frames later.
          f.HookAddMessageLevel(f, text, a1, a2, a3, a4, a5)
        end
      end
    end
  end)
end
