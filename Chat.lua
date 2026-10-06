local _, ns = ...
local RG = ns.RG
local L = RG.L

local PREFIX = "[RaidGames] "
local MAX_LEN = 255
local COMMAND_THROTTLE = 5

local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

-- ---------------------------------------------------------------------------
-- Ausgabe mit Queue (Chat-Lockdown in Midnight + Server-Throttle)
-- ---------------------------------------------------------------------------

local queue = {}
local ticker

local function InLockdown()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        return ok and locked == true
    end
    return false
end

local function GetChannel()
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then
        return "RAID"
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    end
    return nil
end

local function Deliver(msg)
    local channel = GetChannel()
    if not channel then
        print("|cffff7f00" .. msg .. "|r")
        return
    end
    -- pcall: ein Fehler beim Senden darf die Queue nicht blockieren
    local ok, err = pcall(SendChat, msg, channel)
    if not ok then
        RG:Print("|cffff3333" .. L["Sending failed:"] .. "|r " .. tostring(err))
    elseif RG.debug then
        RG:Print(L["Sent to %s: %s"]:format(channel, msg))
    end
end

local function Flush()
    while #queue > 0 and not InLockdown() do
        Deliver(table.remove(queue, 1))
    end
    if #queue == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- Sendet sofort; nur während eines Chat-Lockdowns wird gepuffert und
-- sekündlich erneut versucht.
function RG:Send(msg)
    -- "|" leitet in WoW Escape-Codes ein und lässt SendChatMessage scheitern
    msg = msg:gsub("|", "/")
    table.insert(queue, PREFIX .. msg)
    Flush()
    if #queue > 0 and not ticker then
        if RG.debug then
            RG:Print(L["Chat lockdown active, the message will be sent later."])
        end
        ticker = C_Timer.NewTicker(1, Flush)
    end
end

-- Packt Einträge in möglichst wenige Nachrichten (max. 255 Zeichen).
function RG:SendList(header, items, separator)
    separator = separator or ", "
    local limit = MAX_LEN - #PREFIX
    local line = header
    local first = true
    for _, item in ipairs(items) do
        local piece = (first and "" or separator) .. item
        if #line + #piece > limit then
            self:Send(line)
            line = item
        else
            line = line .. piece
        end
        first = false
    end
    if line ~= "" then
        self:Send(line)
    end
end

-- ---------------------------------------------------------------------------
-- Eingehende Chat-Befehle
-- ---------------------------------------------------------------------------

local lastCommandTime = {}

local function Throttled(key)
    local now = GetTime()
    if lastCommandTime[key] and now - lastCommandTime[key] < COMMAND_THROTTLE then
        return true
    end
    lastCommandTime[key] = now
    return false
end

local function OnChatMessage(event, msg, sender)
    if RG.IsSecret(msg) or RG.IsSecret(sender) then
        return
    end
    local text = msg:lower():match("^%s*(.-)%s*$")
    if text:sub(1, 1) ~= "!" then
        return
    end
    if RG.debug then
        local session = RG.session
        RG:Print(L["Chat %s from %s: \"%s\" (game phase: %s)"]:format(
            event, RG.FullName(sender), text, session and session.phase or L["no game"]))
    end
    if event == "CHAT_MSG_SAY" and not RG.testMode then
        if RG.debug then
            RG:Print(L["/say is only read in test mode (/rg test)."])
        end
        return
    end
    -- "!top 5" und "!top5" erlauben
    local cmd, args = text:match("^(![%a]+)%s*(.*)$")
    if not cmd then
        return
    end
    local name = RG.FullName(sender)
    local session = RG.session

    if session and session.phase == "SIGNUP" and cmd == session.game.joinCommand then
        session:TogglePlayer(name)
        return
    end

    if cmd == "!top" or cmd == "!bottom" then
        if Throttled(cmd) then
            if RG.debug then
                RG:Print(L["%s throttled (at most once every %d s)."]:format(cmd, COMMAND_THROTTLE))
            end
            return
        end
        local count = math.min(math.max(tonumber(args) or 5, 1), 10)
        RG:AnnounceRanking(cmd == "!top", count)
        return
    end

    if session and session.game.OnChatCommand then
        session.game:OnChatCommand(session, name, cmd, args)
    end
end

for _, event in ipairs({
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_SAY",
}) do
    RG:RegisterEvent(event, OnChatMessage)
end
