local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Eine Spielrunde. Phasen: SIGNUP -> RUNNING -> DONE
-- Spielspezifischer Zustand liegt in session.data.
local Session = {}
Session.__index = Session

function Session:IsPlayer(name)
    return self.players[name] == true
end

function Session:PlayerList()
    return self.order
end

function Session:PlayerCount()
    return #self.order
end

function Session:AddPlayer(name)
    if self.players[name] then
        return
    end
    self.players[name] = true
    table.insert(self.order, name)
    RG:Print(L["%s joined (%d)"]:format(RG.Short(name), #self.order))
    if RG.db.settings.announceJoins then
        RG:Send(L["%s joined (%d players)"]:format(RG.Short(name), #self.order))
    end
    RG:Fire("UPDATE")
end

function Session:RemovePlayer(name, silent)
    if not self.players[name] then
        return
    end
    self.players[name] = nil
    for i, player in ipairs(self.order) do
        if player == name then
            table.remove(self.order, i)
            break
        end
    end
    if not silent then
        RG:Print(L["%s left (%d)"]:format(RG.Short(name), #self.order))
        if RG.db.settings.announceJoins and self.phase == "SIGNUP" then
            RG:Send(L["%s left (%d players)"]:format(RG.Short(name), #self.order))
        end
    end
    if self.phase == "RUNNING" then
        if #self.order < self.game.minPlayers then
            RG:Send(L["Not enough players left, game cancelled."])
            self:End()
            return
        end
        if self.game.OnPlayerRemoved then
            self.game:OnPlayerRemoved(self, name)
        end
    end
    RG:Fire("UPDATE")
end

function Session:TogglePlayer(name)
    if self.phase ~= "SIGNUP" then
        return
    end
    if self.players[name] then
        self:RemovePlayer(name)
    else
        self:AddPlayer(name)
    end
end

function Session:GetPendingPlayers()
    if self.phase ~= "RUNNING" or not self.game.GetPendingPlayers then
        return {}
    end
    return self.game:GetPendingPlayers(self)
end

-- results: { { name, delta }, ... } – wird in die Statistik gebucht.
-- summary: optionaler Ergebnistext für das UI.
function Session:Finish(results, summary)
    self.summary = summary
    RG:BookResults(self.game.id, results)
    self:End()
end

function Session:End()
    self.phase = "DONE"
    RG:Fire("UPDATE")
end

-- ---------------------------------------------------------------------------
-- Steuerung durch den Host (UI)
-- ---------------------------------------------------------------------------

function RG:IsSessionActive()
    return self.session ~= nil and self.session.phase ~= "DONE"
end

-- Wert einer Spieloption (game.options) aus den Einstellungen, begrenzt auf min/max.
function RG:GetOption(gameId, option)
    local value = tonumber(self:GameSettings(gameId)[option.key]) or option.default
    if option.min then
        value = math.max(value, option.min)
    end
    if option.max then
        value = math.min(value, option.max)
    end
    return value
end

function RG:SetOption(gameId, option, value)
    self:GameSettings(gameId)[option.key] = tonumber(value)
end

function RG:StartSignup(gameId, bet)
    if self:IsSessionActive() then
        self:Print(L["A game is already running."])
        return
    end
    local game = self:GetGame(gameId)
    if not game then
        return
    end
    bet = tonumber(bet)
    if not bet or bet < 2 or bet ~= math.floor(bet) then
        self:Print(L["Invalid bet."])
        return
    end
    self.db.settings.lastGame = gameId
    self:GameSettings(gameId).lastBet = bet

    local options = {}
    for _, option in ipairs(game.options or {}) do
        options[option.key] = self:GetOption(gameId, option)
    end

    self.session = setmetatable({
        game = game,
        bet = bet,
        options = options,
        phase = "SIGNUP",
        players = {},
        order = {},
        data = {},
    }, Session)
    if game.OnSignupStart then
        game:OnSignupStart(self.session)
    end
    self:Fire("UPDATE")
end

function RG:StartGame()
    local session = self.session
    if not session or session.phase ~= "SIGNUP" then
        return
    end
    if session:PlayerCount() < session.game.minPlayers then
        self:Print(L["At least %d players needed."]:format(session.game.minPlayers))
        return
    end
    session.phase = "RUNNING"
    session.game:OnStart(session)
    self:Fire("UPDATE")
end

function RG:RemindPending()
    local session = self.session
    if not session or session.phase ~= "RUNNING" then
        return
    end
    local pending = session:GetPendingPlayers()
    if #pending == 0 then
        return
    end
    local names = {}
    for i, name in ipairs(pending) do
        names[i] = RG.Short(name)
    end
    local header = session.game.GetRemindHeader and session.game:GetRemindHeader(session) or L["Still pending: "]
    self:SendList(header, names)
end

function RG:CancelSession()
    if not self:IsSessionActive() then
        return
    end
    self:Send(L["%s cancelled."]:format(L[self.session.game.name]))
    self.session:End()
end

-- ---------------------------------------------------------------------------
-- Testmodus
-- ---------------------------------------------------------------------------

local FAKE_NAMES = { "Arthas", "Jaina", "Thrall", "Sylvanas", "Anduin", "Illidan", "Tyrande", "Garrosh" }

function RG.IsFake(name)
    return name:match("%-Testrealm$") ~= nil
end

function RG:AddFakePlayers(count)
    if not self.testMode then
        self:Print(L["Only in test mode (/rg test)."])
        return
    end
    local session = self.session
    if not session or session.phase ~= "SIGNUP" then
        self:Print(L["Start a new game first."])
        return
    end
    for i = 1, math.min(count, #FAKE_NAMES) do
        session:AddPlayer(FAKE_NAMES[i] .. "-Testrealm")
    end
end

function RG:FakeRolls(fixedValue)
    if not self.testMode then
        self:Print(L["Only in test mode (/rg test)."])
        return
    end
    local session = self.session
    if not session or session.phase ~= "RUNNING" then
        return
    end
    local game = session.game
    for _, name in ipairs(session:GetPendingPlayers()) do
        if RG.IsFake(name) then
            if game.FakeAction then
                game:FakeAction(session, name, fixedValue)
            else
                local max = RG.Tiebreak.IsIn(session, name) and session.data.tiebreak.rollMax
                    or (game.GetExpectedRollMax and game:GetExpectedRollMax(session, name))
                    or session.bet
                self:HandleRoll(name, fixedValue or math.random(1, max), 1, max)
            end
            if session.phase ~= "RUNNING" then
                return
            end
        end
    end
end
