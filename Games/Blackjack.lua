local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Blackjack ohne Bank: Karten per /roll 13, "!stand" zum Stehenbleiben.
-- Wer am nächsten an 21 ist, bekommt von jedem anderen den Einsatz.
-- Blackjack (21 mit 2 Karten) schlägt 21 mit mehr Karten.
local Blackjack = {
    id = "blackjack",
    name = "Blackjack",
    joinCommand = "!roll",
    minPlayers = 2,
}

local Tiebreak = RG.Tiebreak
local CARD_ROLL = 13
local TIEBREAK_ROLL = 100
-- Schlüssel sind die englischen Kartenkürzel (Ass, Bube, Dame, König)
local CARD_NAMES = { [1] = "A", [11] = "J", [12] = "Q", [13] = "K" }

local function CardName(card)
    return CARD_NAMES[card] and L[CARD_NAMES[card]] or tostring(card)
end

-- Summe mit Ass als 11, solange es nicht über 21 geht
local function HandTotal(hand)
    local total, hasAce = 0, false
    for _, card in ipairs(hand.cards) do
        total = total + math.min(card, 10)
        if card == 1 then
            hasAce = true
        end
    end
    if hasAce and total + 10 <= 21 then
        total = total + 10
    end
    return total
end

local function IsBlackjack(hand)
    return #hand.cards == 2 and HandTotal(hand) == 21
end

local function HandText(hand)
    local names = {}
    for i, card in ipairs(hand.cards) do
        names[i] = CardName(card)
    end
    return ("%s = %d"):format(table.concat(names, " "), HandTotal(hand))
end

local function IsDone(hand)
    return hand.stood or hand.bust
end

-- Wertung: Blackjack zählt 21.5, damit es 21 mit mehr Karten schlägt
local function Score(hand)
    if hand.bust then
        return nil
    end
    return HandTotal(hand) + (IsBlackjack(hand) and 0.5 or 0)
end

function Blackjack:Evaluate(session)
    local data = session.data
    local best
    for _, name in ipairs(session:PlayerList()) do
        local hand = data.hands[name]
        if not IsDone(hand) then
            return
        end
        local score = Score(hand)
        if score and (not best or score > best) then
            best = score
        end
    end

    local results = {}
    for _, name in ipairs(session:PlayerList()) do
        table.insert(results, { name = name, delta = 0 })
    end

    if not best then
        RG:Send(L["Everyone is bust. Nobody pays."])
        session:Finish(results, L["Everyone bust, nobody pays."])
        return
    end

    local group = {}
    for _, name in ipairs(session:PlayerList()) do
        if Score(data.hands[name]) == best then
            table.insert(group, name)
        end
    end
    if not (data.winner and session:IsPlayer(data.winner) and Score(data.hands[data.winner]) == best) then
        data.winner = Tiebreak.Resolve(session, "HIGH", group, math.floor(best), TIEBREAK_ROLL)
        if not data.winner then
            return
        end
    end

    local winner = data.winner
    data.net = (session:PlayerCount() - 1) * session.bet
    for _, result in ipairs(results) do
        result.delta = result.name == winner and data.net or -session.bet
    end

    local how = IsBlackjack(data.hands[winner]) and "Blackjack" or tostring(HandTotal(data.hands[winner]))
    RG:Send(L["%s wins with %s! Everyone pays %s %s."]:format(
        RG.Short(winner), how, RG.Short(winner), RG.Gold(session.bet)
    ))
    session:Finish(results, L["|cff00ff00%s|r wins with %s\nEveryone pays %s (+%s)"]:format(
        RG.Short(winner), how, RG.Gold(session.bet), RG.Gold(data.net)
    ))
end

local function Stand(session, name)
    local hand = session.data.hands[name]
    hand.stood = true
    RG:Send(L["%s stands on %d."]:format(RG.Short(name), HandTotal(hand)))
    RG:Fire("UPDATE")
    Blackjack:Evaluate(session)
end

-- ---------------------------------------------------------------------------
-- Modul-Callbacks
-- ---------------------------------------------------------------------------

function Blackjack:OnSignupStart(session)
    RG:Send(L["Blackjack for %s started! Whoever is closest to 21 gets the bet from everyone."]:format(RG.Gold(session.bet)))
    RG:Send(L["Type \"!roll\" in chat to join (type it again to leave)."])
end

function Blackjack:OnStart(session)
    local data = session.data
    data.hands = {}
    for _, name in ipairs(session:PlayerList()) do
        data.hands[name] = { cards = {} }
    end
    RG:SendList(L["Sign-up closed! %d players: "]:format(session:PlayerCount()), RG.ShortNames(session:PlayerList()))
    RG:Send(L["Every /roll 13 is a card (A=1/11, J/Q/K=10). Your first 2 rolls are your starting hand, each further /roll 13 draws a card. \"!stand\" to stand."]) -- luacheck: ignore 631
end

function Blackjack:OnRoll(session, name, value, min, max)
    if not session:IsPlayer(name) then
        RG:Print(L["Roll by %s ignored: not signed up."]:format(RG.Short(name)))
        return
    end
    if Tiebreak.Record(session, name, value, min, max) then
        self:Evaluate(session)
        return
    end
    local hand = session.data.hands[name]
    if IsDone(hand) then
        RG:Print(L["Roll by %s ignored: hand is already finished."]:format(RG.Short(name)))
        return
    end
    if min ~= 1 or max ~= CARD_ROLL then
        RG:Print(L["Roll by %s ignored: %d-%d instead of 1-%d."]:format(RG.Short(name), min, max, CARD_ROLL))
        RG:Send(L["%s: please /roll %d (not %d-%d)."]:format(RG.Short(name), CARD_ROLL, min, max))
        return
    end

    table.insert(hand.cards, value)
    if #hand.cards < 2 then
        RG:Fire("UPDATE")
        return
    end

    local total = HandTotal(hand)
    if total > 21 then
        hand.bust = true
        RG:Send(("%s: %s - bust!"):format(RG.Short(name), HandText(hand)))
    elseif total == 21 then
        hand.stood = true
        RG:Send(("%s: %s - %s!"):format(RG.Short(name), HandText(hand), IsBlackjack(hand) and "BLACKJACK" or L["21, stands"]))
    else
        RG:Send(("%s: %s"):format(RG.Short(name), HandText(hand)))
    end
    RG:Fire("UPDATE")
    self:Evaluate(session)
end

function Blackjack:OnChatCommand(session, name, cmd)
    if cmd ~= "!stand" or session.phase ~= "RUNNING" or not session:IsPlayer(name) then
        return
    end
    local hand = session.data.hands[name]
    if IsDone(hand) then
        return
    end
    if #hand.cards < 2 then
        RG:Send(L["%s: draw 2 cards first (/roll 13)."]:format(RG.Short(name)))
        return
    end
    Stand(session, name)
end

function Blackjack:OnPlayerRemoved(session)
    self:Evaluate(session)
end

function Blackjack:GetPendingPlayers(session)
    local pending = {}
    for _, name in ipairs(session:PlayerList()) do
        if not IsDone(session.data.hands[name]) then
            table.insert(pending, name)
        end
    end
    if #pending == 0 then
        return Tiebreak.Pending(session)
    end
    return pending
end

function Blackjack:GetRemindHeader(session)
    if session.data.tiebreak then
        return Tiebreak.RemindHeader(session)
    end
    return L["Still playing (/roll 13 or !stand): "]
end

-- Testmodus: Fake-Spieler ziehen bis mindestens 17
function Blackjack:FakeAction(session, name, fixedValue)
    if Tiebreak.IsIn(session, name) then
        RG:HandleRoll(name, fixedValue or math.random(1, TIEBREAK_ROLL), 1, TIEBREAK_ROLL)
        return
    end
    local hand = session.data.hands[name]
    if #hand.cards >= 2 and HandTotal(hand) >= 17 then
        Stand(session, name)
    else
        RG:HandleRoll(name, fixedValue or math.random(1, CARD_ROLL), 1, CARD_ROLL)
    end
end

function Blackjack:GetPlayerStatus(session, name)
    local data = session.data
    local hand = data.hands and data.hands[name]
    if not hand then
        return ""
    end
    if #hand.cards == 0 then
        return session.phase == "RUNNING" and "|cff888888" .. L["no cards"] .. "|r" or ""
    end
    local text = HandText(hand)
    if hand.bust then
        text = text .. " |cffff3333bust|r"
    elseif IsBlackjack(hand) then
        text = text .. " |cffffd100Blackjack|r"
    elseif hand.stood then
        text = text .. " " .. L["stands"]
    end
    text = text .. Tiebreak.StatusSuffix(session, name)
    if session.phase == "DONE" and data.net then
        if name == data.winner then
            text = "|cff00ff00" .. text .. " +" .. RG.Gold(data.net) .. "|r"
        else
            text = text .. " |cffff3333-" .. RG.Gold(session.bet) .. "|r"
        end
    end
    return text
end

RG:RegisterGame(Blackjack)
