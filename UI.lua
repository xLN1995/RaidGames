local _, ns = ...
local RG = ns.RG
local L = RG.L

local WIDTH, HEIGHT = 360, 520
local ROW_HEIGHT = 18

local frame, gamePanel, statsPanel
local widgets = {}

-- ---------------------------------------------------------------------------
-- Bausteine
-- ---------------------------------------------------------------------------

-- Feste Beschriftungen merken sich ihren Setter und werden bei einem
-- Sprachwechsel (/rg lang) neu gesetzt.
local localizers = {}

local function Localize(apply)
    table.insert(localizers, apply)
    apply()
end

RG:On("LANGUAGE", function()
    for _, apply in ipairs(localizers) do
        apply()
    end
end)

-- key: Übersetzungsschlüssel der Beschriftung
local function CreateButton(parent, key, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    Localize(function()
        button:SetText(L[key])
    end)
    button:SetScript("OnClick", onClick)
    return button
end

-- key: Übersetzungsschlüssel oder nil für dynamischen Text
local function CreateLabel(parent, key, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    if key then
        Localize(function()
            label:SetText(L[key])
        end)
    end
    return label
end

-- Scrollbare Liste mit wiederverwendeten Zeilen.
-- Zeile: name (links), value (rechts), optional Entfernen-Button.
local function CreateList(parent, withRemoveButton)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
    end)

    local list = { scroll = scroll, rows = {} }

    function list:GetRow(index)
        local row = self.rows[index]
        if row then
            return row
        end
        row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", content, "RIGHT")

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetJustifyH("LEFT")

        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.value:SetJustifyH("RIGHT")

        if withRemoveButton then
            row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remove:SetSize(20, 16)
            row.remove:SetText("x")
            row.remove:SetPoint("RIGHT", -2, 0)
            row.value:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
        else
            row.value:SetPoint("RIGHT", -4, 0)
        end
        self.rows[index] = row
        return row
    end

    function list:SetData(count, fill)
        for i = 1, count do
            local row = self:GetRow(i)
            fill(row, i)
            row:Show()
        end
        for i = count + 1, #self.rows do
            self.rows[i]:Hide()
        end
        content:SetHeight(math.max(count * ROW_HEIGHT, 1))
    end

    return list
end

-- ---------------------------------------------------------------------------
-- Spiel-Panel
-- ---------------------------------------------------------------------------

local PHASE_TEXT = {
    SIGNUP = "|cff00ccff%s|r",
    RUNNING = "|cffffff00%s|r",
    DONE = "|cff888888%s|r",
}
local PHASE_KEY = {
    SIGNUP = "Sign-up open",
    RUNNING = "Rolling",
    DONE = "Finished",
}

local function SelectedGameId()
    return RG.db.settings.lastGame
end

-- Zahlenfelder für game.options, eine Zeile pro Spiel (wird bei Bedarf erzeugt)
local optionFrames = {}

local function GetOptionsFrame(game)
    if optionFrames[game.id] then
        return optionFrames[game.id]
    end
    local container = CreateFrame("Frame", nil, gamePanel)
    container:SetPoint("TOPLEFT", 0, -62)
    container:SetSize(WIDTH - 24, 24)
    container.fields = {}

    local anchor
    for _, option in ipairs(game.options or {}) do
        local label = CreateLabel(container)
        Localize(function()
            label:SetText(L[option.label] .. ":")
        end)
        if anchor then
            label:SetPoint("LEFT", anchor, "RIGHT", 16, 0)
        else
            label:SetPoint("LEFT", 0, 0)
        end

        local field = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
        field:SetSize(50, 20)
        field:SetPoint("LEFT", label, "RIGHT", 10, 0)
        field:SetAutoFocus(false)
        field:SetNumeric(true)
        field:SetMaxLetters(6)
        field:SetScript("OnEnterPressed", field.ClearFocus)
        field:SetScript("OnEscapePressed", field.ClearFocus)
        field:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                RG:SetOption(game.id, option, self:GetNumber())
            end
        end)
        field:SetScript("OnEditFocusLost", function(self)
            self:SetNumber(RG:GetOption(game.id, option))
        end)
        field.option = option
        table.insert(container.fields, field)
        anchor = field
    end

    optionFrames[game.id] = container
    return container
end

local function RefreshOptions(game, active)
    for id, container in pairs(optionFrames) do
        container:SetShown(id == game.id)
    end
    for _, field in ipairs(GetOptionsFrame(game).fields) do
        if not field:HasFocus() then
            local value = RG:IsSessionActive() and RG.session.options[field.option.key]
                or RG:GetOption(game.id, field.option)
            field:SetNumber(value)
        end
        field:SetEnabled(not active)
    end
    GetOptionsFrame(game):Show()
end

local function BuildGamePanel()
    gamePanel = CreateFrame("Frame", nil, frame)
    gamePanel:SetPoint("TOPLEFT", 12, -60)
    gamePanel:SetPoint("BOTTOMRIGHT", -12, 12)

    local gameLabel = CreateLabel(gamePanel, "Game:")
    gameLabel:SetPoint("TOPLEFT", 0, -6)

    local dropdown = CreateFrame("DropdownButton", nil, gamePanel, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", gameLabel, "LEFT", 70, 0)
    dropdown:SetWidth(180)
    dropdown:SetupMenu(function(_, root)
        for _, id in ipairs(RG.gameOrder) do
            root:CreateRadio(L[RG.games[id].name], function()
                return SelectedGameId() == id
            end, function()
                if RG:IsSessionActive() then
                    return
                end
                RG.db.settings.lastGame = id
                RG:Fire("UPDATE")
            end)
        end
    end)
    widgets.dropdown = dropdown

    local betLabel = CreateLabel(gamePanel, "Bet:")
    betLabel:SetPoint("TOPLEFT", 0, -40)

    local bet = CreateFrame("EditBox", nil, gamePanel, "InputBoxTemplate")
    bet:SetSize(120, 20)
    bet:SetPoint("LEFT", betLabel, "LEFT", 75, 0)
    bet:SetAutoFocus(false)
    bet:SetNumeric(true)
    bet:SetMaxLetters(9)
    bet:SetScript("OnEnterPressed", bet.ClearFocus)
    bet:SetScript("OnEscapePressed", bet.ClearFocus)
    widgets.bet = bet

    local goldSuffix = CreateLabel(gamePanel, "gold", "GameFontHighlight")
    goldSuffix:SetPoint("LEFT", bet, "RIGHT", 6, 0)

    local status = CreateLabel(gamePanel, nil, "GameFontHighlight")
    status:SetPoint("TOPLEFT", 0, -96)
    status:SetPoint("RIGHT", gamePanel, "RIGHT")
    status:SetJustifyH("LEFT")
    widgets.status = status

    local buttonWidth = 160
    widgets.newGame = CreateButton(gamePanel, "New game", buttonWidth, function()
        bet:ClearFocus()
        RG:StartSignup(SelectedGameId(), bet:GetNumber())
    end)
    widgets.newGame:SetPoint("TOPLEFT", 0, -120)

    widgets.start = CreateButton(gamePanel, "Start roll", buttonWidth, function()
        RG:StartGame()
    end)
    widgets.start:SetPoint("LEFT", widgets.newGame, "RIGHT", 8, 0)

    widgets.remind = CreateButton(gamePanel, "Remind", buttonWidth, function()
        RG:RemindPending()
    end)
    widgets.remind:SetPoint("TOPLEFT", widgets.newGame, "BOTTOMLEFT", 0, -4)

    widgets.cancel = CreateButton(gamePanel, "Cancel", buttonWidth, function()
        RG:CancelSession()
    end)
    widgets.cancel:SetPoint("LEFT", widgets.remind, "RIGHT", 8, 0)

    local result = CreateLabel(gamePanel, nil, "GameFontHighlight")
    result:SetPoint("TOPLEFT", 0, -178)
    result:SetPoint("RIGHT", gamePanel, "RIGHT")
    result:SetJustifyH("LEFT")
    result:SetSpacing(2)
    widgets.result = result

    local header = CreateLabel(gamePanel)
    header:SetPoint("TOPLEFT", 0, -214)
    widgets.playerHeader = header

    local list = CreateList(gamePanel, true)
    list.scroll:SetPoint("TOPLEFT", 0, -232)
    list.scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    widgets.playerList = list
end

local function RefreshGamePanel()
    local session = RG.session
    local active = RG:IsSessionActive()
    local game = RG:GetGame(SelectedGameId())

    if not widgets.bet:HasFocus() then
        local current = session and active and session.bet or RG:GameSettings(game.id).lastBet or 10000
        widgets.bet:SetNumber(current)
    end
    widgets.bet:SetEnabled(not active)
    RefreshOptions(game, active)
    widgets.dropdown:SetEnabled(not active)
    widgets.dropdown:GenerateMenu()

    widgets.newGame:SetEnabled(not active)
    widgets.start:SetEnabled(session ~= nil and session.phase == "SIGNUP"
        and session:PlayerCount() >= session.game.minPlayers)
    widgets.remind:SetEnabled(session ~= nil and session.phase == "RUNNING")
    widgets.cancel:SetEnabled(active)

    widgets.result:SetText(session and session.phase == "DONE" and session.summary or "")

    if not session then
        widgets.status:SetText(L["No game active. Players join in chat with \"%s\"."]:format(game.joinCommand))
        widgets.playerHeader:SetText(L["Players"])
        widgets.playerList:SetData(0)
        return
    end

    local phase = PHASE_TEXT[session.phase]:format(L[PHASE_KEY[session.phase]])
    widgets.status:SetText(L["%s for %s: %s"]:format(L[session.game.name], RG.Gold(session.bet), phase))
    local players = session:PlayerList()
    widgets.playerHeader:SetText(L["Players (%d)"]:format(#players))
    widgets.playerList:SetData(#players, function(row, i)
        local name = players[i]
        row.name:SetText(RG.Short(name))
        row.value:SetText(session.game.GetPlayerStatus and session.game:GetPlayerStatus(session, name) or "")
        row.remove:SetShown(active)
        row.remove:SetScript("OnClick", function()
            session:RemovePlayer(name)
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Statistik-Panel
-- ---------------------------------------------------------------------------

local function BuildStatsPanel()
    statsPanel = CreateFrame("Frame", nil, frame)
    statsPanel:SetPoint("TOPLEFT", 12, -60)
    statsPanel:SetPoint("BOTTOMRIGHT", -12, 12)

    local header = CreateLabel(statsPanel, "Balance of all games")
    header:SetPoint("TOPLEFT", 0, -6)

    local list = CreateList(statsPanel, false)
    list.scroll:SetPoint("TOPLEFT", 0, -26)
    list.scroll:SetPoint("BOTTOMRIGHT", -24, 60)
    widgets.statsList = list

    local postTop = CreateButton(statsPanel, "Post top 5", 160, function()
        RG:AnnounceRanking(true, 5)
    end)
    postTop:SetPoint("BOTTOMLEFT", 0, 30)

    local postBottom = CreateButton(statsPanel, "Post bottom 5", 160, function()
        RG:AnnounceRanking(false, 5)
    end)
    postBottom:SetPoint("LEFT", postTop, "RIGHT", 8, 0)

    local reset = CreateButton(statsPanel, "Reset statistics", 328, function()
        RG:ConfirmResetStats()
    end)
    reset:SetPoint("BOTTOMLEFT", 0, 4)
end

local function RefreshStatsPanel()
    local ranking = RG:GetRanking(true)
    widgets.statsList:SetData(#ranking, function(row, i)
        local entry = ranking[i]
        row.name:SetText(("%d. %s |cff888888%s|r"):format(i, RG.Short(entry.name), L["(%d games)"]:format(entry.games)))
        local color = entry.net > 0 and "|cff00ff00" or (entry.net < 0 and "|cffff3333" or "|cffffffff")
        row.value:SetText(color .. RG.SignedGold(entry.net) .. "|r")
    end)
end

-- ---------------------------------------------------------------------------
-- Hauptfenster
-- ---------------------------------------------------------------------------

local function Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    if gamePanel:IsShown() then
        RefreshGamePanel()
    else
        RefreshStatsPanel()
    end
end

local function ShowTab(tab)
    gamePanel:SetShown(tab == "game")
    statsPanel:SetShown(tab == "stats")
    widgets.gameTab:SetEnabled(tab ~= "game")
    widgets.statsTab:SetEnabled(tab ~= "stats")
    Refresh()
end

local function BuildFrame()
    frame = CreateFrame("Frame", "RaidGamesFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        RG.db.framePos = { point, relativePoint, x, y }
    end)
    local pos = RG.db.framePos
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER")
    end
    frame:Hide()
    table.insert(UISpecialFrames, "RaidGamesFrame")

    local title = CreateLabel(frame, nil, "GameFontHighlight")
    title:SetText("RaidGames")
    title:SetPoint("TOP", 0, -5)

    widgets.gameTab = CreateButton(frame, "Game", 100, function()
        ShowTab("game")
    end)
    widgets.gameTab:SetPoint("TOPLEFT", 12, -30)

    widgets.statsTab = CreateButton(frame, "Statistics", 100, function()
        ShowTab("stats")
    end)
    widgets.statsTab:SetPoint("LEFT", widgets.gameTab, "RIGHT", 6, 0)

    BuildGamePanel()
    BuildStatsPanel()
    frame:SetScript("OnShow", Refresh)
    ShowTab("game")
end

function RG:ToggleUI()
    if not frame then
        BuildFrame()
    end
    frame:SetShown(not frame:IsShown())
end

-- tab: "game" oder "stats"
function RG:OpenUI(tab)
    if not frame then
        BuildFrame()
    end
    frame:Show()
    ShowTab(tab or "game")
end

RG:On("UPDATE", Refresh)
