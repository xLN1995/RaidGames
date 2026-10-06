local ADDON_NAME, ns = ...

local RG = {}
ns.RG = RG
_G.RaidGames = RG

RG.games = {}
RG.gameOrder = {}
RG.testMode = false

-- ---------------------------------------------------------------------------
-- Übersetzung: Schlüssel sind die englischen Texte. Locales/*.lua registrieren
-- Übersetzungen; fehlt ein Eintrag, erscheint der englische Text.
-- Texte immer erst bei Verwendung über L[...] holen, nie beim Laden der Datei,
-- sonst greift die gewählte Sprache nicht.
-- ---------------------------------------------------------------------------

local translations = {}
local active = {}

RG.L = setmetatable({}, {
    __index = function(_, key)
        return active[key] or key
    end,
})

function RG:RegisterLocale(locale, strings)
    translations[locale] = strings
end

-- settings.language: "auto" (Client-Sprache), "de" oder "en"
function RG:ApplyLanguage()
    local setting = self.db.settings.language
    local locale = (setting == "de" and "deDE") or (setting == "en" and "enUS") or GetLocale()
    active = translations[locale] or {}
    self:Fire("LANGUAGE")
    self:Fire("UPDATE")
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local L = RG.L

function RG:Print(msg)
    print("|cff33ff99RaidGames|r: " .. tostring(msg))
end

-- Midnight (12.x): Chat-Payloads können in Instanzen "Secret Values" sein.
function RG.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Vereinheitlicht Namen auf "Name-Realm" (Realm ohne Leerzeichen/Bindestriche),
-- damit Chat-Absender und /roll-Systemmeldungen übereinstimmen.
function RG.FullName(name)
    if not name or name == "" then
        return nil
    end
    local short, realm = name:match("^([^%-]+)%-(.+)$")
    if not short then
        short = name
        realm = GetNormalizedRealmName() or GetRealmName() or ""
    end
    realm = realm:gsub("[%s%-]", "")
    return short .. "-" .. realm
end

-- Anzeigename: Realm nur, wenn er vom eigenen abweicht.
function RG.Short(fullName)
    if not fullName then
        return "?"
    end
    local short, realm = fullName:match("^([^%-]+)%-(.+)$")
    if short and realm == (GetNormalizedRealmName() or "") then
        return short
    end
    return fullName
end

function RG.ShortNames(names)
    local list = {}
    for i, name in ipairs(names) do
        list[i] = RG.Short(name)
    end
    return list
end

function RG.Gold(amount)
    local sign = amount < 0 and "-" or ""
    return sign .. BreakUpLargeNumbers(math.abs(amount)) .. "g"
end

function RG.SignedGold(amount)
    if amount > 0 then
        return "+" .. RG.Gold(amount)
    end
    return RG.Gold(amount)
end

-- ---------------------------------------------------------------------------
-- Interne Callbacks (UI-Refresh etc.)
-- ---------------------------------------------------------------------------

local callbacks = {}

function RG:On(event, fn)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], fn)
end

function RG:Fire(event, ...)
    for _, fn in ipairs(callbacks[event] or {}) do
        fn(...)
    end
end

-- ---------------------------------------------------------------------------
-- Spiel-Registry
-- ---------------------------------------------------------------------------

function RG:RegisterGame(game)
    -- game.name und option.label sind Übersetzungsschlüssel (L[game.name])
    assert(game.id and game.name and game.joinCommand, "RaidGames: game needs id, name and joinCommand")
    game.minPlayers = game.minPlayers or 2
    self.games[game.id] = game
    table.insert(self.gameOrder, game.id)
end

function RG:GetGame(id)
    return self.games[id]
end

function RG:GameSettings(id)
    local settings = self.db.settings
    settings[id] = settings[id] or {}
    return settings[id]
end

-- ---------------------------------------------------------------------------
-- SavedVariables & Events
-- ---------------------------------------------------------------------------

local defaults = {
    stats = {},
    settings = {
        lastGame = "goldroll",
        announceJoins = false,
        language = "auto",
        minimap = { hide = false },
    },
}

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local eventFrame = CreateFrame("Frame")
RG.eventFrame = eventFrame
local eventHandlers = {}

function RG:RegisterEvent(event, fn)
    eventHandlers[event] = eventHandlers[event] or {}
    table.insert(eventHandlers[event], fn)
    eventFrame:RegisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(eventHandlers[event] or {}) do
        fn(event, ...)
    end
end)

RG:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then
        return
    end
    RaidGamesDB = RaidGamesDB or {}
    ApplyDefaults(RaidGamesDB, defaults)
    RG.db = RaidGamesDB
    if not RG.games[RG.db.settings.lastGame] then
        RG.db.settings.lastGame = RG.gameOrder[1]
    end
    RG:ApplyLanguage()
    RG:Fire("LOADED")
end)

-- ---------------------------------------------------------------------------
-- Slash-Befehle
-- ---------------------------------------------------------------------------

local function OnOff(value)
    return value and L["on"] or L["off"]
end

local function PrintHelp()
    RG:Print(L["Commands:"])
    print("  /rg – " .. L["open or close the window"])
    print("  /rg reset – " .. L["reset the statistics"])
    print("  /rg joins – " .. L["announce sign-ups in raid chat on/off"])
    print("  /rg lang de|en|auto – " .. L["language (auto = client language)"])
    print("  /rg minimap – " .. L["show or hide the minimap button"])
    print("  /rg debug on|off – " .. L["diagnose roll detection (also without a game)"])
    print("  /rg test – " .. L["test mode on/off (also reads /say)"])
    print("  /rg fake <n> – " .. L["(test) sign up n fake players"])
    print("  /rg fakeroll [value] – " .. L["(test) let pending fake players roll"])
end

SLASH_RAIDGAMES1 = "/rg"
SLASH_RAIDGAMES2 = "/raidgames"
SlashCmdList.RAIDGAMES = function(input)
    local cmd, rest = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" then
        RG:ToggleUI()
    elseif cmd == "reset" then
        RG:ConfirmResetStats()
    elseif cmd == "joins" then
        RG.db.settings.announceJoins = not RG.db.settings.announceJoins
        RG:Print(L["Announce sign-ups in raid chat:"] .. " " .. OnOff(RG.db.settings.announceJoins))
    elseif cmd == "lang" then
        if rest == "de" or rest == "en" or rest == "auto" then
            RG.db.settings.language = rest
            RG:ApplyLanguage()
        end
        RG:Print(L["Language:"] .. " " .. RG.db.settings.language)
    elseif cmd == "minimap" then
        RG:SetMinimapShown(RG.db.settings.minimap.hide)
    elseif cmd == "debug" then
        if rest == "on" then
            RG.debug = true
        elseif rest == "off" then
            RG.debug = false
        else
            RG.debug = not RG.debug
        end
        RG:Print("Debug: " .. OnOff(RG.debug))
        if RG.debug then
            RG:PrintRollDebugInfo()
        end
    elseif cmd == "test" then
        RG.testMode = not RG.testMode
        RG:Print(L["Test mode:"] .. " " .. OnOff(RG.testMode))
    elseif cmd == "fake" then
        RG:AddFakePlayers(tonumber(rest) or 3)
    elseif cmd == "fakeroll" then
        RG:FakeRolls(tonumber(rest))
    else
        PrintHelp()
    end
end
