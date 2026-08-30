local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["MiniMap Clock"],
  description = T["Adds a small 24h clock to the mini map."],
  expansions = { ["vanilla"] = true },
  category = T["Minimap & World Map"],
  enabled = true,
})

MinimapClock = CreateFrame("Frame", "Clock", Minimap)
MinimapClock:Hide()
MinimapClock:SetFrameLevel(64)
MinimapClock:SetPoint("BOTTOM", MinimapCluster, "BOTTOM", 8, 18)
MinimapClock:SetWidth(50)
MinimapClock:SetHeight(23)
MinimapClock:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
MinimapClock:SetBackdropBorderColor(.9,.8,.5,1)
MinimapClock:SetBackdropColor(.4,.4,.4,1)

MinimapTimer = CreateFrame("Button", "MinimapTimer", Minimap)
MinimapTimer:Hide()
MinimapTimer:SetFrameStrata("MEDIUM")
MinimapTimer:SetFrameLevel(65)
MinimapTimer:SetWidth(70)
MinimapTimer:SetHeight(23)
MinimapTimer:SetPoint("TOP", MinimapClock, "BOTTOM")
MinimapTimer:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
MinimapTimer:SetBackdropBorderColor(.9,.8,.5,1)
MinimapTimer:SetBackdropColor(.4,.4,.4,1)
MinimapTimer:SetMovable(true)
MinimapTimer:SetClampedToScreen(true)
MinimapTimer:SetUserPlaced(true)
MinimapTimer:EnableMouse(true)
MinimapTimer:RegisterForDrag("LeftButton")
MinimapTimer:RegisterForClicks("LeftButtonUp", "RightButtonUp")

module.enable = function(self)
  local timermax = 99 * 3600 + 59 * 60 + 59 -- 99:59:59
  local timerstarted = nil
  local timerelapsed = 0
  local timerpaused = nil
  local timerticker = nil

  MinimapClock:Show()
  MinimapClock:EnableMouse(true)

  MinimapClock.text = MinimapClock:CreateFontString("Status", "LOW", "GameFontNormal")
  MinimapClock.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  MinimapClock.text:SetAllPoints(MinimapClock)
  MinimapClock.text:SetFontObject(GameFontWhite)

  local function updateclock()
    MinimapClock.text:SetText(date("%H:%M"))
  end

  updateclock()
  MinimapClock.ticker = C_Timer.NewTicker(1, updateclock)

  local timertext = MinimapTimer:CreateFontString(nil, "LOW", "GameFontNormal")
  timertext:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  timertext:SetFontObject(GameFontWhite)
  timertext:SetAllPoints(MinimapTimer)

  local function formattime(e)
    local t = floor(e or 0)
    local h = floor(t / 3600)
    local m = floor(mod(t, 3600) / 60)
    local s = floor(mod(t, 60))
    return h, m, s
  end

  local function updatetimertext()
    local h, m, s = formattime(timerelapsed)
    timertext:SetText(format("%02d:%02d:%02d", h, m, s))
  end

  local function stopticker()
    if timerticker then
      timerticker:Cancel()
      timerticker = nil
    end
  end

  local function ticktimer()
    timerelapsed = GetTime() - timerstarted
    if timerelapsed >= timermax then
      timerelapsed = timermax
      updatetimertext()
      timerpaused = GetTime()
      stopticker()
      return
    end

    updatetimertext()
  end

  local function startticker()
    stopticker()
    timerticker = C_Timer.NewTicker(1, ticktimer)
  end

  local function starttimer()
    timerstarted = GetTime()
    timerelapsed = 0
    timerpaused = nil
    updatetimertext()
    startticker()
  end

  local function resettimer()
    stopticker()
    timerstarted = nil
    timerelapsed = 0
    timerpaused = nil
    updatetimertext()
  end

  local function pausetimer()
    if not timerstarted then return end

    timerelapsed = GetTime() - timerstarted
    if timerelapsed > timermax then timerelapsed = timermax end
    timerpaused = GetTime()
    stopticker()
    updatetimertext()
  end

  local function continuetimer()
    if not timerstarted or not timerpaused then return end

    timerstarted = timerstarted + (GetTime() - timerpaused)
    timerpaused = nil
    startticker()
  end

  local function toggletimer()
    resettimer()
    if MinimapTimer:IsVisible() then
      MinimapTimer:Hide()
    else
      MinimapTimer:Show()
    end
  end

  local function resetposition()
    MinimapTimer:SetUserPlaced(false)
    MinimapTimer:ClearAllPoints()
    MinimapTimer:SetPoint("TOP", MinimapClock, "BOTTOM")
  end

  MinimapClock:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then toggletimer() end
  end)

  MinimapClock:SetScript("OnEnter", function()
    local h, m = GetGameTime()
    local servertime = string.format("%.2d:%.2d", h, m)
    local time = date("%H:%M")

    GameTooltip:ClearLines()
    GameTooltip:SetOwner(this, ANCHOR_BOTTOMLEFT)

    GameTooltip:AddLine(T["Clock"])
    GameTooltip:AddDoubleLine(T["Localtime"], time, 1,1,1,1,1,1)
    GameTooltip:AddDoubleLine(T["Servertime"], servertime, 1,1,1,1,1,1)
    GameTooltip:Show()
  end)

  MinimapClock:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  MinimapTimer:SetScript("OnDragStart", function()
    if IsShiftKeyDown() and IsControlKeyDown() then
      this:StartMoving()
    end
  end)

  MinimapTimer:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    this:SetUserPlaced(true)
  end)

  MinimapTimer:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
      if timerpaused then
        continuetimer()
      elseif not timerstarted then
        starttimer()
      else
        pausetimer()
      end
    elseif arg1 == "RightButton" then
      if IsShiftKeyDown() and IsControlKeyDown() then
        resettimer()
        MinimapTimer:Hide()
        resetposition()
      else
        resettimer()
      end
    end
  end)

  resettimer()
end
