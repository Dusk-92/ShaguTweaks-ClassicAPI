local _G = ShaguTweaks.GetGlobalEnv()
local libtipscan = {}
local baseName = "ShaguTweaksTooltip"
local methods = {
  "SetBagItem", "SetAction", "SetAuctionItem", "SetAuctionSellItem", "SetBuybackItem",
  "SetCraftItem", "SetCraftSpell", "SetHyperlink", "SetInboxItem", "SetInventoryItem",
  "SetLootItem", "SetLootRollItem", "SetMerchantItem", "SetPetAction", "SetPlayerBuff",
  "SetQuestItem", "SetQuestLogItem", "SetQuestRewardSpell", "SetSendMailItem", "SetShapeshift",
  "SetSpell", "SetTalent", "SetTrackingSpell", "SetTradePlayerItem", "SetTradeSkillItem", "SetTradeTargetItem",
  "SetTrainerService", "SetUnit", "SetUnitBuff", "SetUnitDebuff",
}
local extra_methods = {
  "Find", "Line", "Text", "List",
}

-- GameTooltipTemplate creates named FontStrings that persist for the lifetime
-- of the scanner. Cache each side once it exists instead of rebuilding the
-- global name and looking it up for every tooltip read.
local function getLine(obj, side, index)
  local cache = side == "Left" and obj.ShaguTweaksLeftLines or obj.ShaguTweaksRightLines
  local line = cache[index]
  if line then return line end

  line = _G[obj.ShaguTweaksScannerName .. "Text" .. side .. index]
  if line then cache[index] = line end
  return line
end

local getFontString = function(obj)
  local r, g, b, a
  local text, segment

  for i=1, obj:NumLines() do
    local left = getLine(obj, "Left", i)
    segment = left and left:IsVisible() and left:GetText()
    segment = segment and segment ~= "" and segment or nil
    if segment then
      r, g, b, a = left:GetTextColor()
      segment = rgbhex(r,g,b) .. segment .. "|r"
      text = text and text .. "\n" .. segment or segment
    end
  end
  return text
end

local getText = function(obj)
  local text = {}
  for i=1, obj:NumLines() do
    local left, right = getLine(obj, "Left", i), getLine(obj, "Right", i)
    left = left and left:IsVisible() and left:GetText()
    right = right and right:IsVisible() and right:GetText()
    left = left and left ~= "" and left or nil
    right = right and right ~= "" and right or nil
    if left or right then
      text[i] = {left, right}
    end
  end
  return text
end

local findText = function(obj, text, exact)
  for i=1, obj:NumLines() do
    local left, right = getLine(obj, "Left", i), getLine(obj, "Right", i)
    left = left and left:IsVisible() and left:GetText()
    right = right and right:IsVisible() and right:GetText()
    if exact then
      if (left and left == text) or (right and right == text) then
        return i, text
      end
    else
      if left then
        local found,_,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10 = string.find(left, text)
        if found then
          return i, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10
        end
      end
      if right then
        local found,_,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10 = string.find(right, text)
        if found then
          return i, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10
        end
      end
    end
  end
end

local lineText = function(obj, line)
  if line <= obj:NumLines() then
    local left, right = getLine(obj, "Left", line), getLine(obj, "Right", line)
    left = left and left:IsVisible() and left:GetText()
    right = right and right:IsVisible() and right:GetText()

    if left or right then
      return left, right
    end
  end
end

local findColor = function(obj, r,g,b)
  if type(r) == "table" then
    r,g,b = r.r or r[1], r.g or r[2], r.b or r[3]
  end
  for i=1, obj:NumLines() do
    local tr, tg, tb
    local left, right = getLine(obj, "Left", i), getLine(obj, "Right", i)
    if left and left:IsVisible() then
      tr, tg, tb = left:GetTextColor()
      tr, tg, tb = round(tr,1), round(tg,1), round(tb,1)
    end
    if tr and (tr == r and tg == g and tb == b) then
      return i
    end
    if right and right:IsVisible() then
      tr, tg, tb = right:GetTextColor()
      tr, tg, tb = round(tr,1), round(tg,1), round(tb,1)
    end
    if tr and (tr == r and tg == g and tb == b) then
      return i
    end
  end
end

libtipscan._registry = setmetatable({},{__index = function(t,k)
  local v = CreateFrame("GameTooltip", string.format("%s%s",baseName,k), nil, "GameTooltipTemplate")
  v.ShaguTweaksScannerName = v:GetName()
  v.ShaguTweaksLeftLines = {}
  v.ShaguTweaksRightLines = {}
  v:SetOwner(WorldFrame,"ANCHOR_NONE")
  v:SetScript("OnHide", function ()
    this:SetOwner(WorldFrame,"ANCHOR_NONE")
  end)
  function v:Text()
    return getText(self)
  end
  function v:FontString()
    return getFontString(self)
  end
  function v:Find(text, exact)
    return findText(self, text, exact)
  end
  function v:Color(r,g,b)
    return findColor(self,r,g,b)
  end
  function v:Line(line)
    return lineText(self, line)
  end
  for i = 1, table.getn(methods) do
    local method = methods[i]
    local old = v[method]
    if type(old) == "function" then
      v[method] = function(v, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
        v:ClearLines()
        return old(v, a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
      end
    end
  end
  function v:List()
    table.sort(methods)
    for i = 1, table.getn(methods) do
      print(methods[i])
    end
    for i = 1, table.getn(extra_methods) do
      print(extra_methods[i])
    end
  end
  rawset(t,k,v)
  return v
end})

function libtipscan:GetScanner(key)
  local scanner = self._registry[key]
  scanner:ClearLines()
  return scanner
end

function libtipscan:List()
  for name, scanner in pairs(self._registry) do
    print(name)
  end
end

ShaguTweaks.libtipscan = libtipscan
