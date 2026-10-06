local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Jackpot: Alle würfeln 1-Einsatz. Der Höchste bekommt von jedem anderen den
-- Einsatz. Optional geht ein Gildenanteil vom Gewinn an die Gildenbank.
local Jackpot = {
    id = "jackpot",
    name = "Jackpot",
    joinCommand = "!roll",
    minPlayers = 2,
    options = {
        { key = "guildCut", label = "Guild cut %", default = 0, min = 0, max = 100 },
    },
}

local Tiebreak = RG.Tiebreak

function Jackpot:Evaluate(session)
    local data = session.data
    local maxValue
    for _, name in ipairs(session:PlayerList()) do
        local roll = data.rolls[name]
        if not roll then
            return
        end
        maxValue = math.max(maxValue or roll, roll)
    end

    local highGroup = {}
    for _, name in ipairs(session:PlayerList()) do
        if data.rolls[name] == maxValue then
            table.insert(highGroup, name)
        end
    end
    if not (data.winner and session:IsPlayer(data.winner) and data.rolls[data.winner] == maxValue) then
        data.winner = Tiebreak.Resolve(session, "HIGH", highGroup, maxValue, session.bet)
        if not data.winner then
            return
        end
    end

    local winner = data.winner
    local pot = (session:PlayerCount() - 1) * session.bet
    local cutPercent = session.options.guildCut or 0
    local cut = math.floor(pot * cutPercent / 100)
    data.net = pot - cut

    local results = {}
    for _, name in ipairs(session:PlayerList()) do
        table.insert(results, { name = name, delta = name == winner and data.net or -session.bet })
    end

    RG:Send(L["%s wins the jackpot with %s! Everyone pays %s %s (pot %s)."]:format(
        RG.Short(winner), BreakUpLargeNumbers(maxValue), RG.Short(winner), RG.Gold(session.bet), RG.Gold(pot)
    ))
    local summary = L["Everyone pays |cff00ff00%s|r |cffffd100%s|r\nPot: %s"]:format(
        RG.Short(winner), RG.Gold(session.bet), RG.Gold(pot)
    )
    if cut > 0 then
        RG:Send(L["%s gives %d%% (%s) to the guild bank."]:format(RG.Short(winner), cutPercent, RG.Gold(cut)))
        summary = summary .. L[" - guild %d%%: %s = %s net"]:format(cutPercent, RG.Gold(cut), RG.Gold(data.net))
    end
    session:Finish(results, summary)
end

-- ---------------------------------------------------------------------------
-- Modul-Callbacks
-- ---------------------------------------------------------------------------

function Jackpot:OnSignupStart(session)
    local text = L["Jackpot for %s started! The highest roll gets the bet from everyone."]:format(RG.Gold(session.bet))
    local cut = session.options.guildCut or 0
    if cut > 0 then
        text = text .. " " .. L["%d%% of the winnings go to the guild bank."]:format(cut)
    end
    RG:Send(text)
    RG:Send(L["Type \"!roll\" in chat to join (type it again to leave)."])
end

function Jackpot:OnStart(session)
    session.data.rolls = {}
    RG:SendList(L["Sign-up closed! %d players: "]:format(session:PlayerCount()), RG.ShortNames(session:PlayerList()))
    RG:Send(L["Pot: %s. Now /roll %d!"]:format(RG.Gold((session:PlayerCount() - 1) * session.bet), session.bet))
end

function Jackpot:OnRoll(session, name, value, min, max)
    if not session:IsPlayer(name) then
        RG:Print(L["Roll by %s ignored: not signed up."]:format(RG.Short(name)))
        return
    end
    if min ~= 1 or max ~= session.bet then
        RG:Print(L["Roll by %s ignored: %d-%d instead of 1-%d."]:format(RG.Short(name), min, max, session.bet))
        RG:Send(L["%s: please /roll %d (not %d-%d)."]:format(RG.Short(name), session.bet, min, max))
        return
    end
    local data = session.data
    if not data.rolls[name] then
        data.rolls[name] = value
    elseif not Tiebreak.Record(session, name, value, min, max) then
        RG:Print(L["Roll by %s ignored: already rolled."]:format(RG.Short(name)))
        return
    end
    RG:Fire("UPDATE")
    self:Evaluate(session)
end

function Jackpot:OnPlayerRemoved(session)
    self:Evaluate(session)
end

function Jackpot:GetPendingPlayers(session)
    local pending = {}
    for _, name in ipairs(session:PlayerList()) do
        if not session.data.rolls[name] then
            table.insert(pending, name)
        end
    end
    if #pending == 0 then
        return Tiebreak.Pending(session)
    end
    return pending
end

function Jackpot:GetExpectedRollMax(session)
    return session.bet
end

function Jackpot:GetRemindHeader(session)
    if session.data.tiebreak then
        return Tiebreak.RemindHeader(session)
    end
    return L["Not rolled yet (/roll %d): "]:format(session.bet)
end

function Jackpot:GetPlayerStatus(session, name)
    local data = session.data
    local roll = data.rolls and data.rolls[name]
    if not roll then
        return session.phase == "RUNNING" and "|cff888888" .. L["pending"] .. "|r" or ""
    end
    local text = BreakUpLargeNumbers(roll) .. Tiebreak.StatusSuffix(session, name)
    if session.phase == "DONE" and data.net then
        if name == data.winner then
            text = "|cff00ff00" .. text .. " +" .. RG.Gold(data.net) .. "|r"
        else
            text = "|cffff3333" .. text .. " -" .. RG.Gold(session.bet) .. "|r"
        end
    end
    return text
end

RG:RegisterGame(Jackpot)
