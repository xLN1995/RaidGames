local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Gold-Roll: Alle würfeln 1-Einsatz. Der Niedrigste zahlt dem Höchsten die Differenz.
-- Gleichstand oben/unten wird per Reroll der Betroffenen entschieden; die
-- Differenz bleibt die der ursprünglichen Würfe.
local GoldRoll = {
    id = "goldroll",
    name = "Gold Roll",
    joinCommand = "!roll",
    minPlayers = 2,
}

local Tiebreak = RG.Tiebreak

function GoldRoll:Evaluate(session)
    local data = session.data
    local maxValue, minValue
    for _, name in ipairs(session:PlayerList()) do
        local roll = data.rolls[name]
        if not roll then
            return
        end
        maxValue = math.max(maxValue or roll, roll)
        minValue = math.min(minValue or roll, roll)
    end

    local results = {}
    for _, name in ipairs(session:PlayerList()) do
        table.insert(results, { name = name, delta = 0 })
    end

    if maxValue == minValue then
        RG:Send(L["Everyone rolled %s. It's a draw, nobody pays."]:format(BreakUpLargeNumbers(maxValue)))
        session:Finish(results, L["Draw, nobody pays."])
        return
    end

    local highGroup, lowGroup = {}, {}
    for _, name in ipairs(session:PlayerList()) do
        if data.rolls[name] == maxValue then
            table.insert(highGroup, name)
        elseif data.rolls[name] == minValue then
            table.insert(lowGroup, name)
        end
    end

    if not (data.winner and session:IsPlayer(data.winner) and data.rolls[data.winner] == maxValue) then
        data.winner = Tiebreak.Resolve(session, "HIGH", highGroup, maxValue, session.bet)
        if not data.winner then
            return
        end
    end
    if not (data.loser and session:IsPlayer(data.loser) and data.rolls[data.loser] == minValue) then
        data.loser = Tiebreak.Resolve(session, "LOW", lowGroup, minValue, session.bet)
        if not data.loser then
            return
        end
    end

    local diff = maxValue - minValue
    for _, result in ipairs(results) do
        if result.name == data.winner then
            result.delta = diff
        elseif result.name == data.loser then
            result.delta = -diff
        end
    end

    RG:Send(L["Winner: %s (%s) - loser: %s (%s). %s pays %s %s!"]:format(
        RG.Short(data.winner), BreakUpLargeNumbers(maxValue),
        RG.Short(data.loser), BreakUpLargeNumbers(minValue),
        RG.Short(data.loser), RG.Short(data.winner), RG.Gold(diff)
    ))
    session:Finish(results, L["|cffff3333%s|r pays |cff00ff00%s|r |cffffd100%s|r\nDifference: %s - %s = %s"]:format(
        RG.Short(data.loser), RG.Short(data.winner), RG.Gold(diff),
        BreakUpLargeNumbers(maxValue), BreakUpLargeNumbers(minValue), BreakUpLargeNumbers(diff)
    ))
end

-- ---------------------------------------------------------------------------
-- Modul-Callbacks
-- ---------------------------------------------------------------------------

function GoldRoll:OnSignupStart(session)
    RG:Send(L["Gold roll for %s started!"]:format(RG.Gold(session.bet))
        .. " " .. L["Type \"!roll\" in chat to join (type it again to leave)."])
end

function GoldRoll:OnStart(session)
    session.data.rolls = {}
    RG:SendList(L["Sign-up closed! %d players: "]:format(session:PlayerCount()), RG.ShortNames(session:PlayerList()))
    RG:Send(L["Now /roll %d!"]:format(session.bet))
end

function GoldRoll:OnRoll(session, name, value, min, max)
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

function GoldRoll:OnPlayerRemoved(session)
    self:Evaluate(session)
end

function GoldRoll:GetPendingPlayers(session)
    local data = session.data
    local pending = {}
    for _, name in ipairs(session:PlayerList()) do
        if not data.rolls[name] then
            table.insert(pending, name)
        end
    end
    if #pending == 0 then
        return Tiebreak.Pending(session)
    end
    return pending
end

function GoldRoll:GetExpectedRollMax(session)
    return session.bet
end

function GoldRoll:GetRemindHeader(session)
    if session.data.tiebreak then
        return Tiebreak.RemindHeader(session)
    end
    return L["Not rolled yet (/roll %d): "]:format(session.bet)
end

-- Text für die Teilnehmerliste im UI
function GoldRoll:GetPlayerStatus(session, name)
    local data = session.data
    local roll = data.rolls and data.rolls[name]
    if not roll then
        return session.phase == "RUNNING" and "|cff888888" .. L["pending"] .. "|r" or ""
    end
    local text = BreakUpLargeNumbers(roll)
    text = text .. Tiebreak.StatusSuffix(session, name)
    if session.phase == "DONE" then
        if name == data.winner then
            text = "|cff00ff00" .. text .. "|r"
        elseif name == data.loser then
            text = "|cffff3333" .. text .. "|r"
        end
    end
    return text
end

RG:RegisterGame(GoldRoll)
