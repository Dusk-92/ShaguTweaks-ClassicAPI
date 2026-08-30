local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Auto Dismount"],
  description = T["Automatically dismounts whenever a spell is casted."],
  expansions = { ["vanilla"] = true },
  category = T["Action Bar"],
  enabled = true,
})

module.enable = function(self)
  local dismount = CreateFrame("Frame")
  ShaguTweaks.dismount = dismount

  -- Keep the legacy detection data as a compatibility fallback for custom
  -- mounts/forms that ClassicAPI does not identify as one of the known forms.
  dismount.strings = {
    -- deDE
    "^Erhöht Tempo um (.+)%%",
    -- enUS
    "^Increases speed by (.+)%%",
    -- esES
    "^Aumenta la velocidad en un (.+)%%",
    -- frFR
    "^Augmente la vitesse de (.+)%%",
    -- ruRU
    "^Скорость увеличена на (.+)%%",
    -- koKR
    "^이동 속도 (.+)%%만큼 증가",
    -- zhCN
    "^速度提高(.+)%%",
    -- turtle-wow
    "speed based on", "Slow and steady...", "Riding",
    "Lento y constante...", "Aumenta la velocidad según tu habilidad de Montar.",
    "根据您的骑行技能提高速度。", "根据骑术技能提高速度。", "又慢又稳......",
  }

  -- shapeshift buff icons (legacy/custom fallback)
  dismount.shapeshifts = {
    "ability_racial_bearform", "ability_druid_catform", "ability_druid_travelform",
    "spell_nature_forceofnature", "ability_druid_aquaticform", "spell_nature_spiritwolf"
  }

  -- ClassicAPI SpellShapeshiftForm.dbc IDs matching the forms the original
  -- module intentionally cancelled. Do not include Moonkin/Shadowform/Stealth.
  local removableForms = {
    [1] = true,  -- Cat
    [2] = true,  -- Tree (vanilla DBC)
    [3] = true,  -- Travel
    [4] = true,  -- Aquatic
    [5] = true,  -- Bear
    [8] = true,  -- Dire Bear
    [9] = true,  -- Tree of Life (Turtle WoW)
    [11] = true, -- Swift Travel (Turtle WoW)
    [16] = true, -- Ghost Wolf
  }

  -- errors that indicate mount/shapeshift
  dismount.errors = { SPELL_FAILED_NOT_MOUNTED, ERR_ATTACK_MOUNTED, ERR_TAXIPLAYERALREADYMOUNTED,
    SPELL_FAILED_NOT_SHAPESHIFT, SPELL_FAILED_NO_ITEMS_WHILE_SHAPESHIFTED, SPELL_NOT_SHAPESHIFTED,
    SPELL_NOT_SHAPESHIFTED_NOSPACE, ERR_CANT_INTERACT_SHAPESHIFTED, ERR_NOT_WHILE_SHAPESHIFTED,
    ERR_NO_ITEMS_WHILE_SHAPESHIFTED, ERR_TAXIPLAYERSHAPESHIFTED,ERR_MOUNT_SHAPESHIFTED }

  dismount.scanner = ShaguTweaks.libtipscan:GetScanner("dismount")

  local function LegacyCancel()
    for i=0, 31 do
      -- detect mounts based on tooltip text
      dismount.scanner:SetPlayerBuff(i)
      for _, str in pairs(dismount.strings) do
        if dismount.scanner:Find(str) then
          CancelPlayerBuff(i)
          return true
        end
      end

      -- detect shapeshift based on texture
      local buff = GetPlayerBuffTexture(i)
      if buff then
        for _, bufftype in pairs(dismount.shapeshifts) do
          if string.find(string.lower(buff), bufftype) then
            CancelPlayerBuff(i)
            return true
          end
        end
      end
    end
  end

  dismount:RegisterEvent("UI_ERROR_MESSAGE")
  dismount:SetScript("OnEvent", function()
    -- stand up
    if arg1 == SPELL_FAILED_NOT_STANDING then
      SitOrStand()
      return
    end

    for _, errorstring in pairs(dismount.errors) do
      if arg1 == errorstring then
        -- ClassicAPI reads the real mounted/form state directly, avoiding a
        -- 32-buff tooltip scan in the normal case.
        if API.IsMounted() then
          API.Dismount()
          return
        end

        local formID = API.GetShapeshiftFormID()
        if removableForms[formID] then
          API.CancelShapeshiftForm()
          return
        end

        -- Preserve compatibility with custom private-server auras/forms.
        LegacyCancel()
        return
      end
    end
  end)
end
