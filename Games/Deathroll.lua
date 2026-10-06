local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Deathroll: Reihum würfelt jeder 1 bis zum vorherigen Ergebnis (Start: Einsatz).
-- Wer die 1 würfelt, zahlt den Einsatz an den Spieler direkt vor ihm.
local Deathroll = {
    id = "deathroll",
    name = "Deathroll",
    joinCommand = "!roll",
    minPlayers = 2,
}

-- data.order ist die Reihenfolge beim Start; entfernte Spieler bleiben drin
-- und werden übersprungen.
local function Step(session, name, direction)
    local order = session.data.order
    local count = #order
    local index = tIndexOf(order, name)
    for _ = 1, count do
        index = (index - 1 + direction) % count + 1
        if session:IsPlayer(order[index]) then
            return order[index]
        end
    end
    return nil
end

local function AnnounceTurn(session, prefix)
    local data = session.data
    RG:Send((prefix or "") .. L["%s's turn: /roll %d"]:format(RG.Short(data.current), data.max))
    RG:Fire("UPDATE")
end

function Deathroll:OnSignupStart(session)
    RG:Send(L["Deathroll for %s started!"]:format(RG.Gold(session.bet))
        .. " " .. L["Type \"!roll\" in chat to join (type it again to leave)."])
end

function Deathroll:OnStart(session)
    local data = session.data
    data.order = CopyTable(session:PlayerList())
    data.rolls = {}
    data.current = data.order[1]
    data.max = session.bet
    RG:SendList(L["Sign-up closed! Order: "], RG.ShortNames(data.order))
    RG:Send(L["Whoever rolls a 1 pays %s to the player before them."]:format(RG.Gold(session.bet)))
    AnnounceTurn(session)
end

function Deathroll:OnRoll(session, name, value, min, max)
    local data = session.data
    if name ~= data.current then
        local reason = session:IsPlayer(name) and L["Roll by %s ignored: not their turn."] or L["Roll by %s ignored: not signed up."]
        RG:Print(reason:format(RG.Short(name)))
        return
    end
    if min ~= 1 or max ~= data.max then
        RG:Print(L["Roll by %s ignored: %d-%d instead of 1-%d."]:format(RG.Short(name), min, max, data.max))
        RG:Send(L["%s: please /roll %d (not %d-%d)."]:format(RG.Short(name), data.max, min, max))
        return
    end

    data.rolls[name] = value
    if value > 1 then
        data.max = value
        data.current = Step(session, name, 1)
        AnnounceTurn(session, L["%s rolls %s. "]:format(RG.Short(name), BreakUpLargeNumbers(value)))
        return
    end

    data.loser = name
    data.winner = Step(session, name, -1)
    data.current = nil
    local results = {}
    for _, player in ipairs(session:PlayerList()) do
        local delta = 0
        if player == data.winner then
            delta = session.bet
        elseif player == data.loser then
            delta = -session.bet
        end
        table.insert(results, { name = player, delta = delta })
    end
    RG:Send(L["%s rolls the 1! %s pays %s %s."]:format(
        RG.Short(data.loser), RG.Short(data.loser), RG.Short(data.winner), RG.Gold(session.bet)
    ))
    session:Finish(results, L["|cffff3333%s|r pays |cff00ff00%s|r |cffffd100%s|r\n%s rolled the 1."]:format(
        RG.Short(data.loser), RG.Short(data.winner), RG.Gold(session.bet), RG.Short(data.loser)
    ))
end

function Deathroll:OnPlayerRemoved(session, name)
    local data = session.data
    if name == data.current then
        data.current = Step(session, name, 1)
        AnnounceTurn(session)
    end
end

function Deathroll:GetPendingPlayers(session)
    return { session.data.current }
end

function Deathroll:GetExpectedRollMax(session)
    return session.data.max
end

function Deathroll:GetRemindHeader(session)
    return L["Turn (/roll %d): "]:format(session.data.max)
end

function Deathroll:GetPlayerStatus(session, name)
    local data = session.data
    local roll = data.rolls and data.rolls[name]
    local text = roll and BreakUpLargeNumbers(roll) or ""
    if session.phase == "RUNNING" and name == data.current then
        text = text .. " |cffffff00" .. L["turn (%s)"]:format(BreakUpLargeNumbers(data.max)) .. "|r"
    elseif session.phase == "DONE" then
        if name == data.winner then
            text = "|cff00ff00" .. text .. " +" .. RG.Gold(session.bet) .. "|r"
        elseif name == data.loser then
            text = "|cffff3333" .. text .. " -" .. RG.Gold(session.bet) .. "|r"
        end
    end
    return text
end

RG:RegisterGame(Deathroll)
