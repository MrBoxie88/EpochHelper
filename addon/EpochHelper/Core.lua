-- EpochHelper v2.1: Core.lua
-- Now with unknown quest capture and persistent UserDB
EpochHelper = {}
local EH = EpochHelper
EH.version = "2.1"
EH.activeQuests = {}
EH.currentQuest = nil
EH.currentStep  = 1
EH.Waypoint = {}
local WP = EH.Waypoint
WP.targetX = nil
WP.targetY = nil

local ARRIVE_DIST = 20  -- yards before auto-advancing

-- -------------------------------------------------------
-- USER DATABASE
-- Persists to disk via SavedVariables (EpochHelperDB.userDB)
-- Stores quests the player has captured themselves
-- -------------------------------------------------------
local function GetUserDB()
    return EH.db and EH.db.userDB
end

local function GetQuestData(title)
    -- Check built-in data first, then user DB
    if EH.QuestData and EH.QuestData[title] then
        return EH.QuestData[title], "builtin"
    end
    local udb = GetUserDB()
    if udb and udb[title] then
        return udb[title], "user"
    end
    return nil, nil
end

local function SaveUserQuest(title, data)
    local udb = GetUserDB()
    if not udb then return end
    udb[title] = data
    print("|cff9370DBEpochHelper|r |cff44ff44Saved|r: " .. title)
end

local function IsQuestKnown(title)
    local data = GetQuestData(title)
    return data ~= nil
end

-- -------------------------------------------------------
-- CAPTURE POPUP
-- Shown when player accepts an unknown quest
-- -------------------------------------------------------
local captureQuest = nil  -- quest being captured
local captureSteps = {}   -- steps collected so far
local capturingStep = false

local captureFrame

local function CreateCaptureFrame()
    local f = CreateFrame("Frame", "EpochHelperCapture", UIParent)
    f:SetWidth(300)
    f:SetHeight(120)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture(0, 0, 0, 0.85)

    local border = CreateFrame("Frame", nil, f)
    border:SetPoint("TOPLEFT",     f, "TOPLEFT",     -1,  1)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left=2, right=2, top=2, bottom=2 },
    })
    border:SetBackdropBorderColor(1, 0.5, 0, 0.9)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.7, 0, 1)
    title:SetText("New quest detected!")
    f.title = title

    -- Quest name
    local questName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    questName:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -26)
    questName:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -26)
    questName:SetJustifyH("LEFT")
    questName:SetTextColor(1, 1, 0, 1)
    questName:SetText("")
    f.questName = questName

    -- Info text
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -42)
    info:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -42)
    info:SetJustifyH("LEFT")
    info:SetTextColor(0.8, 0.8, 0.8, 1)
    info:SetText("Add waypoints for this quest?")
    f.info = info

    -- "Add Waypoint" button
    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetWidth(110)
    addBtn:SetHeight(22)
    addBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    addBtn:SetText("Add Waypoint")
    addBtn:SetScript("OnClick", function()
        f:Hide()
        -- Enter map import mode for this quest
        capturingStep = true
        captureSteps = {}
        ShowUIPanel(WorldMapFrame)
        print("|cff9370DBEpochHelper|r Click the world map to add a waypoint for:")
        print("|cffffff00" .. (captureQuest or "Unknown") .. "|r")
        print("Type |cffffcc00/eh capture done|r when finished, or |cffffcc00/eh capture cancel|r to cancel.")
    end)

    -- "Skip" button
    local skipBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    skipBtn:SetWidth(80)
    skipBtn:SetHeight(22)
    skipBtn:SetPoint("BOTTOMLEFT", addBtn, "BOTTOMRIGHT", 6, 0)
    skipBtn:SetText("Skip")
    skipBtn:SetScript("OnClick", function()
        -- Save quest with no waypoint so we don't prompt again
        local udb = GetUserDB()
        if udb and captureQuest then
            udb[captureQuest] = { steps = {}, captured = true, noWaypoint = true }
        end
        captureQuest = nil
        f:Hide()
        print("|cff9370DBEpochHelper|r Quest skipped — won't prompt again.")
    end)

    -- "Never ask" button
    local neverBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    neverBtn:SetWidth(80)
    neverBtn:SetHeight(22)
    neverBtn:SetPoint("BOTTOMLEFT", skipBtn, "BOTTOMRIGHT", 6, 0)
    neverBtn:SetText("Never Ask")
    neverBtn:SetScript("OnClick", function()
        EH.db.neverCapture = true
        captureQuest = nil
        f:Hide()
        print("|cff9370DBEpochHelper|r Auto-capture disabled. Re-enable with /eh capture on.")
    end)

    -- Close
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetWidth(18)
    close:SetHeight(18)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        captureQuest = nil
        f:Hide()
    end)

    f:Hide()
    captureFrame = f
end

local function ShowCapturePrompt(questTitle)
    if not captureFrame then return end
    if EH.db.neverCapture then return end
    captureQuest = questTitle
    captureSteps = {}
    captureFrame.questName:SetText(questTitle)
    captureFrame.info:SetText("Not in database. Add waypoints?")
    captureFrame:Show()
end

-- -------------------------------------------------------
-- MAP CLICK CAPTURE (reused for import mode too)
-- -------------------------------------------------------
local importMode = false
local importFrame

local function CreateImportFrame()
    local f = CreateFrame("Button", "EpochHelperImport", WorldMapFrame)
    f:SetAllPoints(WorldMapDetailFrame)
    f:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 10)
    f:Hide()

    f:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            local cx, cy  = GetCursorPosition()
            local scale   = WorldMapDetailFrame:GetEffectiveScale()
            local left    = WorldMapDetailFrame:GetLeft()
            local top     = WorldMapDetailFrame:GetTop()
            local width   = WorldMapDetailFrame:GetWidth()
            local height  = WorldMapDetailFrame:GetHeight()
            local x = ((cx / scale) - left)  / width
            local y = (top - (cy / scale))   / height
            x = math.max(0, math.min(1, x))
            y = math.max(0, math.min(1, y))

            if capturingStep and captureQuest then
                -- Add step to capture buffer
                table.insert(captureSteps, { x=x, y=y, hint="" })
                print("|cff9370DBEpochHelper|r Step " .. #captureSteps ..
                    " added: " .. string.format("x=%.4f, y=%.4f", x, y))
                print("Click again to add another step, or type |cffffcc00/eh capture done|r to save.")
                -- Set live waypoint so player can verify
                WP:SetWaypoint(x, y, captureQuest .. " (capturing)")
                arrowFrame:Show()
            else
                -- Plain import mode
                print("|cff9370DBEpochHelper|r Coords: |cffffff00" ..
                    string.format("x=%.4f, y=%.4f", x, y) .. "|r")
                WP:SetWaypoint(x, y, "Imported")
                arrowFrame:Show()
                importMode = false
                f:Hide()
                print("|cff9370DBEpochHelper|r Import mode off.")
            end

        elseif button == "RightButton" then
            if capturingStep then
                print("|cff9370DBEpochHelper|r Step capture cancelled.")
                capturingStep = false
                captureQuest = nil
            else
                importMode = false
                print("|cff9370DBEpochHelper|r Import mode cancelled.")
            end
            f:Hide()
        end
    end)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    importFrame = f
end

local function ToggleImportMode()
    if importMode or capturingStep then
        importMode = false
        capturingStep = false
        importFrame:Hide()
        print("|cff9370DBEpochHelper|r Import mode |cffff4444OFF|r.")
    else
        importMode = true
        importFrame:Show()
        ShowUIPanel(WorldMapFrame)
        print("|cff9370DBEpochHelper|r Import mode |cff44ff44ON|r — click world map to capture coords.")
        print("Right-click to cancel.")
    end
end

local function FinishCapture()
    if not captureQuest or #captureSteps == 0 then
        print("|cff9370DBEpochHelper|r No steps captured. Add at least one waypoint first.")
        return
    end

    -- Build hint prompts from empty strings — player can edit the file later
    local entry = { steps = captureSteps, captured = true }
    SaveUserQuest(captureQuest, entry)

    -- Immediately start tracking
    EH.currentStep = 1
    local step = captureSteps[1]
    WP:SetWaypoint(step.x, step.y, captureQuest)
    UpdateHints(captureQuest, step.hint or "Captured waypoint.", 1, #captureSteps)

    capturingStep = false
    importFrame:Hide()

    print("|cff9370DBEpochHelper|r |cff44ff44Saved " .. #captureSteps ..
        " step(s)|r for: |cffffff00" .. captureQuest .. "|r")
    print("Edit hints in SavedVariables\\EpochHelper.lua if desired.")
    captureQuest = nil
    captureSteps = {}
end

-- -------------------------------------------------------
-- STEP MANAGEMENT
-- -------------------------------------------------------
local function GetCurrentStepData()
    if not EH.currentQuest then return nil end
    local data = GetQuestData(EH.currentQuest)
    if not data then return nil end
    if data.steps then
        return data.steps[EH.currentStep]
    else
        return data
    end
end

local function GetTotalSteps()
    if not EH.currentQuest then return 0 end
    local data = GetQuestData(EH.currentQuest)
    if not data then return 0 end
    if data.steps then return #data.steps end
    return 1
end

local function AdvanceStep()
    local total = GetTotalSteps()
    if EH.currentStep < total then
        EH.currentStep = EH.currentStep + 1
        local step = GetCurrentStepData()
        if step then
            WP:SetWaypoint(step.x, step.y, EH.currentQuest)
            UpdateHints(EH.currentQuest, step.hint, EH.currentStep, total)
            print("|cff9370DBEpochHelper|r Step " .. EH.currentStep .. "/" .. total)
        end
    else
        print("|cff9370DBEpochHelper|r |cff00ff00All steps complete:|r " .. (EH.currentQuest or ""))
        WP:ClearWaypoint()
        UpdateHints(nil)
    end
end

-- -------------------------------------------------------
-- ARROW FRAME
-- -------------------------------------------------------
local arrowFrame

local function CreateArrowFrame()
    local f = CreateFrame("Frame", "EpochHelperArrow", UIParent)
    f:SetWidth(56)
    f:SetHeight(66)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture(0, 0, 0, 0.75)

    local border = CreateFrame("Frame", nil, f)
    border:SetPoint("TOPLEFT",     f, "TOPLEFT",     -1,  1)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left=2, right=2, top=2, bottom=2 },
    })
    border:SetBackdropBorderColor(0.8, 0.7, 0.0, 0.9)

    local arrow = f:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
    arrow:SetWidth(36)
    arrow:SetHeight(36)
    arrow:SetPoint("TOP", f, "TOP", 0, -6)
    f.arrow = arrow

    local dist = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dist:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
    dist:SetJustifyH("CENTER")
    dist:SetTextColor(0.6, 1.0, 0.6, 1)
    dist:SetText("---")
    f.dist = dist

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", f, "BOTTOM", 0, -3)
    title:SetWidth(160)
    title:SetJustifyH("CENTER")
    title:SetTextColor(1, 0.82, 0, 1)
    title:SetText("")
    f.title = title

    f:Hide()
    arrowFrame = f
end

local function WaypointOnUpdate(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    if not WP.targetX then return end
    local px, py = GetPlayerMapPosition("player")
    if not px or px == 0 then return end
    local dx = WP.targetX - px
    local dy = WP.targetY - py
    local dist = math.sqrt(dx * dx + dy * dy) * 10000
    local angle = math.atan2(-dx, dy) - GetPlayerFacing()
    arrowFrame.arrow:SetRotation(angle)
    if dist < ARRIVE_DIST then
        arrowFrame.dist:SetText("|cff00ff00Here!|r")
        arrowFrame.arrow:Hide()
        AdvanceStep()
    else
        arrowFrame.arrow:Show()
        if dist > 1000 then
            arrowFrame.dist:SetText(string.format("%.1fkm", dist / 1000))
        else
            arrowFrame.dist:SetText(string.format("%dyds", math.floor(dist)))
        end
    end
end

function WP:SetWaypoint(x, y, title)
    self.targetX = x
    self.targetY = y
    arrowFrame.title:SetText(title or "")
    arrowFrame.dist:SetText("...")
    arrowFrame.arrow:Show()
    arrowFrame:SetScript("OnUpdate", WaypointOnUpdate)
    arrowFrame:Show()
end

function WP:ClearWaypoint()
    self.targetX = nil
    self.targetY = nil
    arrowFrame:SetScript("OnUpdate", nil)
    arrowFrame:Hide()
end

-- -------------------------------------------------------
-- HINTS PANEL
-- -------------------------------------------------------
local hintsFrame

UpdateHints = function(questTitle, hintText, step, total)
    if not hintsFrame then return end
    if questTitle then
        local stepStr = ""
        if step and total and total > 1 then
            stepStr = "|cffaaaaaa[" .. step .. "/" .. total .. "]|r "
        end
        hintsFrame.hint:SetText(stepStr .. (hintText or "No hint. Use /eh capture to add one."))
        hintsFrame:Show()
    else
        hintsFrame.hint:SetText("No quest tracked.")
        hintsFrame:Hide()
    end
end

local function CreateHintsFrame()
    local f = CreateFrame("Frame", "EpochHelperHints", UIParent)
    f:SetWidth(240)
    f:SetHeight(62)
    f:SetPoint("TOP", arrowFrame, "BOTTOM", 0, -24)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture(0, 0, 0, 0.75)

    local border = CreateFrame("Frame", nil, f)
    border:SetPoint("TOPLEFT",     f, "TOPLEFT",     -1,  1)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left=2, right=2, top=2, bottom=2 },
    })
    border:SetBackdropBorderColor(0.8, 0.7, 0.0, 0.9)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    label:SetTextColor(1, 0.82, 0, 1)
    label:SetText("|cffff9370Epoch|rHelper")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT",  f, "TOPLEFT",  8, -22)
    hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -22)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.85, 0.85, 0.85, 1)
    hint:SetText("No quest tracked.")
    f.hint = hint

    -- Prev button
    local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prev:SetWidth(42)
    prev:SetHeight(16)
    prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 4)
    prev:SetText("< Prev")
    prev:SetScript("OnClick", function()
        if EH.currentStep > 1 then
            EH.currentStep = EH.currentStep - 1
            local step = GetCurrentStepData()
            if step then
                WP:SetWaypoint(step.x, step.y, EH.currentQuest)
                UpdateHints(EH.currentQuest, step.hint, EH.currentStep, GetTotalSteps())
            end
        end
    end)

    -- Next button
    local next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    next:SetWidth(42)
    next:SetHeight(16)
    next:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 4, 0)
    next:SetText("Next >")
    next:SetScript("OnClick", function() AdvanceStep() end)

    -- Add step button (capture new step for current quest)
    local addStep = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addStep:SetWidth(60)
    addStep:SetHeight(16)
    addStep:SetPoint("BOTTOMLEFT", next, "BOTTOMRIGHT", 4, 0)
    addStep:SetText("+ Step")
    addStep:SetScript("OnClick", function()
        if EH.currentQuest then
            captureQuest = EH.currentQuest
            capturingStep = true
            captureSteps = {}
            importFrame:Show()
            ShowUIPanel(WorldMapFrame)
            print("|cff9370DBEpochHelper|r Click the map to add a step for: |cffffff00" .. EH.currentQuest .. "|r")
            print("Type |cffffcc00/eh capture done|r when finished.")
        end
    end)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetWidth(18)
    close:SetHeight(18)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        f:Hide()
        arrowFrame:Hide()
    end)

    f:Hide()
    hintsFrame = f
end

-- -------------------------------------------------------
-- MINIMAP BUTTON
-- -------------------------------------------------------
local minimapButton

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "EpochHelperMinimapBtn", Minimap)
    btn:SetWidth(24)
    btn:SetHeight(24)
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 6)

    local angle = math.rad(220)
    local radius = 80
    btn:SetPoint("CENTER", Minimap, "CENTER",
        radius * math.cos(angle),
        radius * math.sin(angle))

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    bg:SetAllPoints(btn)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("EpochHelper v" .. EH.version)
        GameTooltip:AddLine("Left: toggle frames", 1, 1, 1)
        GameTooltip:AddLine("Right: clear waypoint", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if arrowFrame:IsShown() then
                arrowFrame:Hide()
                hintsFrame:Hide()
            else
                if WP.targetX then arrowFrame:Show() end
                hintsFrame:Show()
            end
        elseif button == "RightButton" then
            WP:ClearWaypoint()
            UpdateHints(nil)
            print("|cff9370DBEpochHelper|r Waypoint cleared.")
        end
    end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton = btn
end

-- -------------------------------------------------------
-- QUEST TRACKER
-- -------------------------------------------------------
local function FindQuestDataByID(questID)
    if not EH.QuestData then return nil end
    for title, data in pairs(EH.QuestData) do
        if data.id and data.id == questID then return title end
    end
    return nil
end

local function ScanQuestLog()
    wipe(EH.activeQuests)
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            EH.activeQuests[title] = { logIndex = i, isComplete = isComplete == 1 }
        end
    end
    EH:OnQuestLogChanged()
end

function EH:OnQuestLogChanged()
    if not self.db or not self.db.enabled then return end
    local matched = nil
    for title, info in pairs(self.activeQuests) do
        if not info.isComplete then
            local data = GetQuestData(title)
            if data and not data.noWaypoint then
                matched = title
                break
            end
        end
    end
    if matched ~= self.currentQuest then
        self.currentQuest = matched
        self.currentStep  = 1
        self:OnTrackedQuestChanged(matched)
    end
end

function EH:OnTrackedQuestChanged(questTitle)
    if questTitle then
        local data = GetQuestData(questTitle)
        if data and not data.noWaypoint then
            local step  = GetCurrentStepData()
            local total = GetTotalSteps()
            print("|cff9370DBEpochHelper|r Tracking: |cffffff00" .. questTitle ..
                "|r (" .. total .. " step" .. (total ~= 1 and "s" or "") .. ")")
            if step and step.x and step.y then
                WP:SetWaypoint(step.x, step.y, questTitle)
            else
                WP:ClearWaypoint()
            end
            UpdateHints(questTitle, step and step.hint, EH.currentStep, total)
        end
    else
        print("|cff9370DBEpochHelper|r No tracked quest.")
        WP:ClearWaypoint()
        UpdateHints(nil)
    end
end

-- Called when player accepts a quest — check if unknown
local function OnQuestAccepted(questTitle)
    if not questTitle then return end
    if EH.db.neverCapture then return end
    local data = GetQuestData(questTitle)
    if not data then
        -- Unknown quest — prompt player to capture it
        local delay = CreateFrame("Frame")
        delay:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            if self.t > 1.5 then  -- wait 1.5s so quest accept UI clears first
                self:SetScript("OnUpdate", nil)
                ShowCapturePrompt(questTitle)
            end
        end)
    end
end

local function DelayedScan(questTitle)
    local delay = CreateFrame("Frame")
    delay:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + elapsed
        if self.t > 0.1 then
            self:SetScript("OnUpdate", nil)
            ScanQuestLog()
            OnQuestAccepted(questTitle)
        end
    end)
end


-- -------------------------------------------------------
-- MERGE COMMUNITY DATA
-- QuestData.lua sets EH_CommunityData; we merge it here
-- -------------------------------------------------------
local function MergeCommunityData()
    if not EH_CommunityData then return end
    if not EH.QuestData then EH.QuestData = {} end
    local count = 0
    for title, data in pairs(EH_CommunityData) do
        if not EH.QuestData[title] then
            EH.QuestData[title] = data
            count = count + 1
        end
    end
    -- Also merge user DB
    local udb = GetUserDB()
    if udb then
        for title, data in pairs(udb) do
            if not EH.QuestData[title] then
                EH.QuestData[title] = data
            end
        end
    end
    if count > 0 then
        print("|cff9370DBEpochHelper|r Loaded " .. count .. " community quests.")
    end
end

-- -------------------------------------------------------
-- EXPORT COMMAND
-- Generates a Lua block ready to paste into a GitHub issue
-- -------------------------------------------------------
local function ExportCurrentQuest()
    if not EH.currentQuest then
        print("|cff9370DBEpochHelper|r No quest currently tracked. Accept a quest first.")
        return
    end
    local udb = GetUserDB()
    local data = udb and udb[EH.currentQuest]
    if not data then
        print("|cff9370DBEpochHelper|r No captured data for: " .. EH.currentQuest)
        print("Use /eh import or the capture popup to add waypoints first.")
        return
    end

    -- Get quest ID if possible
    local questID = "nil"
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title = GetQuestLogTitle(i)
        if title == EH.currentQuest then
            local id = GetQuestLogIndexByID and GetQuestLogIndexByID(i)
            if id then questID = tostring(id) end
            break
        end
    end

    -- Build export string
    local lines = {}
    table.insert(lines, "-- Paste into GitHub issue:")
    table.insert(lines, '["' .. EH.currentQuest .. '"] = {')
    table.insert(lines, "    id   = " .. questID .. ",")
    table.insert(lines, '    zone = "' .. (GetRealZoneText() or "Unknown") .. '",')

    if data.steps and #data.steps > 0 then
        table.insert(lines, "    steps = {")
        for i, step in ipairs(data.steps) do
            table.insert(lines, string.format(
                '        { x=%.4f, y=%.4f, hint="%s" },',
                step.x, step.y, step.hint or ""))
        end
        table.insert(lines, "    },")
    elseif data.x then
        table.insert(lines, string.format("    x    = %.4f,", data.x))
        table.insert(lines, string.format("    y    = %.4f,", data.y))
        table.insert(lines, '    hint = "' .. (data.hint or "") .. '",')
    end
    table.insert(lines, "},")

    print("|cff9370DBEpochHelper|r Copy the following and paste into a GitHub issue:")
    print(" ")
    for _, line in ipairs(lines) do
        print(line)
    end
    print(" ")
    print("GitHub: https://github.com/YOUR_USERNAME/EpochHelper/issues/new?template=quest_submission.md")
end

-- -------------------------------------------------------
-- SLASH COMMANDS
-- -------------------------------------------------------
SLASH_EPOCHHELPER1 = "/eh"
SlashCmdList["EPOCHHELPER"] = function(msg)
    msg = string.lower(string.trim(msg))
    if msg == "show" then
        if WP.targetX then arrowFrame:Show() end
        hintsFrame:Show()
    elseif msg == "hide" then
        arrowFrame:Hide()
        hintsFrame:Hide()
    elseif msg == "clear" then
        WP:ClearWaypoint()
        UpdateHints(nil)
        print("|cff9370DBEpochHelper|r Waypoint cleared.")
    elseif msg == "import" then
        ToggleImportMode()
    elseif msg == "next" then
        AdvanceStep()
    elseif msg == "prev" then
        if EH.currentStep > 1 then
            EH.currentStep = EH.currentStep - 1
            local step = GetCurrentStepData()
            if step then
                WP:SetWaypoint(step.x, step.y, EH.currentQuest)
                UpdateHints(EH.currentQuest, step.hint, EH.currentStep, GetTotalSteps())
            end
        end
    elseif msg == "capture done" then
        FinishCapture()
    elseif msg == "capture cancel" then
        capturingStep = false
        captureQuest  = nil
        captureSteps  = {}
        importFrame:Hide()
        print("|cff9370DBEpochHelper|r Capture cancelled.")
    elseif msg == "capture on" then
        EH.db.neverCapture = false
        print("|cff9370DBEpochHelper|r Auto-capture enabled.")
    elseif msg == "capture off" then
        EH.db.neverCapture = true
        print("|cff9370DBEpochHelper|r Auto-capture disabled.")
    elseif msg == "export" then
        ExportCurrentQuest()
    elseif msg == "list" then
        print("|cff9370DBEpochHelper|r User-captured quests:")
        local udb = GetUserDB()
        if udb then
            local count = 0
            for title, data in pairs(udb) do
                local steps = data.steps and #data.steps or 0
                print("  |cffffff00" .. title .. "|r — " .. steps .. " step(s)")
                count = count + 1
            end
            if count == 0 then print("  (none yet)") end
        end
    else
        print("|cff9370DBEpochHelper|r v" .. EH.version .. " — /eh commands:")
        print("  show / hide / clear")
        print("  import          — click map to set waypoint")
        print("  next / prev     — change step")
        print("  capture done    — save captured steps")
        print("  capture cancel  — cancel capture")
        print("  capture on/off  — toggle auto-capture prompt")
        print("  list            — show user-captured quests")
  print("  export          — export quest data for GitHub submission")
    end
end

-- -------------------------------------------------------
-- CORE EVENT FRAME
-- -------------------------------------------------------
local lastAcceptedQuest = nil

local frame = CreateFrame("Frame", "EpochHelperFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("QUEST_DETAIL_SHOW")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "EpochHelper" then
        if not EpochHelperDB then
            EpochHelperDB = { enabled=true, showHints=true, userDB={} }
        end
        if not EpochHelperDB.userDB then
            EpochHelperDB.userDB = {}
        end
        EH.db = EpochHelperDB

    elseif event == "PLAYER_LOGIN" then
        print("|cff9370DBEpochHelper|r v" .. EH.version .. " loaded! Type /eh for help.")
        CreateArrowFrame()
        CreateHintsFrame()
        CreateMinimapButton()
        CreateImportFrame()
        CreateCaptureFrame()

        MergeCommunityData()
        self:RegisterEvent("QUEST_LOG_UPDATE")
        self:RegisterEvent("QUEST_ACCEPTED")
        self:RegisterEvent("QUEST_TURNED_IN")
        ScanQuestLog()

    elseif event == "QUEST_DETAIL_SHOW" then
        -- Capture the quest title from the offer dialog before accept
        lastAcceptedQuest = GetTitleText and GetTitleText() or nil
    end

    if event == "QUEST_LOG_UPDATE" then
        ScanQuestLog()
    elseif event == "QUEST_ACCEPTED" then
        DelayedScan(lastAcceptedQuest)
    elseif event == "QUEST_TURNED_IN" then
        EH.currentQuest = nil
        EH.currentStep  = 1
        EH:OnTrackedQuestChanged(nil)
    end
end)

-- -------------------------------------------------------
