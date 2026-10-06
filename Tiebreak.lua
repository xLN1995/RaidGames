local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Gemeinsamer Reroll bei Gleichstand. Zustand liegt in session.data.tiebreak.
local Tiebreak = {}
RG.Tiebreak = Tiebreak

local function Start(session, kind, players, value, rollMax)
    session.data.tiebreak = { kind = kind, players = players, rolls = {}, rollMax = rollMax }
    local header = kind == "HIGH" and L["Tie at the top at %s: "] or L["Tie at the bottom at %s: "]
    RG:SendList(header:format(BreakUpLargeNumbers(value)), RG.ShortNames(players))
    RG:Send(L["Only these players please /roll %d again!"]:format(rollMax))
    RG:Fire("UPDATE")
end

-- Ermittelt aus einer Gruppe Gleichplatzierter genau einen Spieler,
-- ggf. über mehrere Reroll-Runden. Gibt nil zurück, solange gewartet wird.
-- kind: "HIGH" (höchster Reroll gewinnt) oder "LOW" (niedrigster Reroll "gewinnt")
function Tiebreak.Resolve(session, kind, group, value, rollMax)
    local data = session.data
    local tiebreak = data.tiebreak

    if #group == 1 then
        if tiebreak and tiebreak.kind == kind then
            data.tiebreak = nil
        end
        return group[1]
    end

    if not tiebreak or tiebreak.kind ~= kind then
        Start(session, kind, group, value, rollMax)
        return nil
    end

    -- Entfernte Spieler aus dem laufenden Tiebreak streichen
    local remaining = {}
    for _, name in ipairs(tiebreak.players) do
        if session:IsPlayer(name) then
            table.insert(remaining, name)
        end
    end
    tiebreak.players = remaining
    if #remaining == 0 then
        Start(session, kind, group, value, rollMax)
        return nil
    elseif #remaining == 1 then
        data.tiebreak = nil
        return remaining[1]
    end

    local best
    for _, name in ipairs(remaining) do
        local roll = tiebreak.rolls[name]
        if not roll then
            return nil
        end
        if not best or (kind == "HIGH" and roll > best) or (kind == "LOW" and roll < best) then
            best = roll
        end
    end

    local tied = {}
    for _, name in ipairs(remaining) do
        if tiebreak.rolls[name] == best then
            table.insert(tied, name)
        end
    end
    if #tied == 1 then
        data.tiebreak = nil
        return tied[1]
    end
    Start(session, kind, tied, value, rollMax)
    return nil
end

function Tiebreak.IsIn(session, name)
    local tiebreak = session.data.tiebreak
    return tiebreak ~= nil and tContains(tiebreak.players, name)
end

-- Übernimmt einen Reroll-Wurf. true, wenn der Wurf zum Tiebreak gehörte.
function Tiebreak.Record(session, name, value, min, max)
    local tiebreak = session.data.tiebreak
    if not Tiebreak.IsIn(session, name) or tiebreak.rolls[name] then
        return false
    end
    if min ~= 1 or max ~= tiebreak.rollMax then
        RG:Send(L["%s: please /roll %d (not %d-%d)."]:format(RG.Short(name), tiebreak.rollMax, min, max))
        return true
    end
    tiebreak.rolls[name] = value
    RG:Fire("UPDATE")
    return true
end

function Tiebreak.Pending(session)
    local pending = {}
    local tiebreak = session.data.tiebreak
    if tiebreak then
        for _, name in ipairs(tiebreak.players) do
            if session:IsPlayer(name) and not tiebreak.rolls[name] then
                table.insert(pending, name)
            end
        end
    end
    return pending
end

-- Zusatz für die Teilnehmerliste, z. B. " (Reroll 42)"
function Tiebreak.StatusSuffix(session, name)
    if not Tiebreak.IsIn(session, name) then
        return ""
    end
    local reroll = session.data.tiebreak.rolls[name]
    return " |cffffff00(" .. (reroll and L["Reroll %d"]:format(reroll) or L["Reroll pending"]) .. ")|r"
end

function Tiebreak.RemindHeader(session)
    return L["Reroll pending (/roll %d): "]:format(session.data.tiebreak.rollMax)
end
