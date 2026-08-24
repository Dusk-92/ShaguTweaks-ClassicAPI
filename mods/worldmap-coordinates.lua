local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["WorldMap Coordinates"],
  description = T["Adds coordinates to the bottom of the World Map."],
  expansions = { ["vanilla"] = true },
  category = T["World & MiniMap"],
  enabled = true,
})

module.enable = function(self)
  local delay = CreateFrame("Frame")
  delay:RegisterEvent("PLAYER_ENTERING_WORLD")
  delay:SetScript("OnEvent", function()
    -- do not load if other map addon is loaded
    if Cartographer then return end
    if METAMAP_TITLE then return end

    -- coordinates
    if not WorldMapButton.coords then
      -- These helper frames are only accessed through WorldMapButton fields and
      -- never need global names. The old code gave both frames the exact same
      -- global name, which can collide in Vanilla's global frame registry.
      WorldMapButton.coords = CreateFrame("Frame", nil, WorldMapButton)
      WorldMapButton.coords.text = WorldMapButton.coords:CreateFontString(nil, "OVERLAY")
      WorldMapButton.coords.text:SetPoint("BOTTOMLEFT", WorldMapButton, "BOTTOMLEFT", 3, -21)
      WorldMapButton.coords.text:SetFontObject(GameFontWhite)
      WorldMapButton.coords.text:SetTextColor(1, 1, 1)
      WorldMapButton.coords.text:SetJustifyH("RIGHT")

      -- move coordinates in case of other addons already taking the space
      if Gatherer_WorldMapDisplay then
        WorldMapButton.coords.text:SetPoint("LEFT", Gatherer_WorldMapDisplay, "RIGHT", 3, -21)
      end

      WorldMapButton.player = CreateFrame("Frame", nil, WorldMapButton)
      WorldMapButton.player.text = WorldMapButton.player:CreateFontString(nil, "OVERLAY")
      WorldMapButton.player.text:SetPoint("BOTTOMRIGHT", WorldMapButton, "BOTTOMRIGHT", -3, -21)
      WorldMapButton.player.text:SetFontObject(GameFontWhite)
      WorldMapButton.player.text:SetTextColor(1, 1, 1)
      WorldMapButton.player.text:SetJustifyH("RIGHT")

      WorldMapButton.coords.elapsed = 0
      WorldMapButton.coords:SetScript("OnUpdate", function()
        -- Coordinates do not need a full render-frame refresh. 10 Hz keeps the
        -- display responsive while avoiding repeated map/cursor queries and
        -- string formatting on every frame while the world map is open.
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < .1 then return end
        this.elapsed = 0

        local width  = WorldMapButton:GetWidth()
        local height = WorldMapButton:GetHeight()
        local mx, my = WorldMapButton:GetCenter()
        local scale  = WorldMapButton:GetEffectiveScale()
        local x, y   = GetCursorPosition()

        if mx and my then
          mx = (( x / scale ) - ( mx - width / 2)) / width * 100
          my = (( my + height / 2 ) - ( y / scale )) / height * 100
        end

        local px, py = GetPlayerMapPosition("player")
        if px > 0 and py > 0 then
          WorldMapButton.player.text:SetText(string.format("|cffffcc00" .. T["Player"] .. ": |r%.1f / %.1f", px*100, py*100))
        else
          WorldMapButton.player.text:SetText(string.format("|cffffcc00" .. T["Player"] .. ": |r" .. T["N/A"]))
        end

        if mx and my and MouseIsOver(WorldMapButton) then
          WorldMapButton.coords.text:SetText(string.format("|cffffcc00" .. T["Cursor"] .. ": |r%.1f / %.1f", mx, my))
        else
          WorldMapButton.coords.text:SetText(string.format("|cffffcc00" .. T["Cursor"] .. ": |r" .. T["N/A"]))
        end
      end)
    end
  end)
end
