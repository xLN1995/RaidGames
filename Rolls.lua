local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Baut aus der lokalisierten Vorlage RANDOM_ROLL_RESULT ("%s würfelt. Ergebnis: %d (%d-%d)")
-- ein Lua-Pattern. Positionsangaben wie "%1$s" werden berücksichtigt.
local function BuildRollParser()
    local order, count = {}, 0
    local pattern = RANDOM_ROLL_RESULT:gsub("%%(%d?)%$?([sd])", function(index, kind)
        count = count + 1
        order[count] = tonumber(index) or count
        return kind == "s" and "\001" or "\002"
    end)
    pattern = pattern:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
    pattern = pattern:gsub("\001", "(.-)")
    pattern = pattern:gsub("\002", "(%%d+)")
    pattern = "^" .. pattern .. "$"

    return function(msg)
        local captures = { msg:match(pattern) }
        if #captures ~= count then
            return nil
        end
        local values = {}
        for i, value in ipairs(captures) do
            values[order[i]] = value
        end
        return values[1], tonumber(values[2]), tonumber(values[3]), tonumber(values[4])
    end, pattern
end

local ParseRoll, rollPattern = BuildRollParser()

function RG:PrintRollDebugInfo()
    self:Print(L["Template:"] .. " " .. RANDOM_ROLL_RESULT:gsub("|", "||"))
    self:Print("Pattern: " .. rollPattern:gsub("|", "||"))
    local lockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    self:Print("Chat lockdown: " .. (lockdown and tostring(lockdown()) or L["API not available"]))
end

local secretWarned = false

-- Die Würfelmeldung zeigt Spieler verbundener Realms oft ohne Realm ("Kimalia"),
-- der Chat-Absender hat ihn aber ("Kimalia-Thrall"). Daher über den Kurznamen
-- den passenden Teilnehmer suchen. Bei Mehrdeutigkeit gewinnt der eigene Realm.
local function ResolveRollName(name)
    local fullName = RG.FullName(name)
    local session = RG.session
    if name:find("-", 1, true) or not session or session:IsPlayer(fullName) then
        return fullName
    end
    local match
    for _, player in ipairs(session:PlayerList()) do
        if player:match("^[^%-]+") == name then
            if match then
                return fullName
            end
            match = player
        end
    end
    return match or fullName
end

function RG:HandleRoll(name, value, min, max)
    local session = self.session
    if session and session.phase == "RUNNING" and session.game.OnRoll then
        session.game:OnRoll(session, name, value, min, max)
    elseif self.debug then
        self:Print(L["Roll by %s not counted: the game is not in the rolling phase (%s)."]:format(
            RG.Short(name), session and session.phase or L["no game"]))
    end
end

RG:RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg)
    local active = RG:IsSessionActive()
    if not active and not RG.debug then
        return
    end
    if RG.IsSecret(msg) then
        if RG.debug or not secretWarned then
            secretWarned = true
            RG:Print("|cffff3333" .. L["System messages (/roll) are currently locked for addons (Midnight instance restriction)."] .. "|r")
        end
        return
    end
    local name, value, min, max = ParseRoll(msg)
    if RG.debug then
        RG:Print(("System: \"%s\" -> %s"):format(msg:gsub("|", "||"), name
            and L["Name=%s (%s), roll=%s, range=%s-%s"]:format(name, ResolveRollName(name), tostring(value), tostring(min), tostring(max))
            or "|cffff3333" .. L["no roll result detected"] .. "|r"))
    end
    if active and name and value then
        RG:HandleRoll(ResolveRollName(name), value, min, max)
    end
end)
