-- luacheck configuration for RaidGames (WoW Retail, Lua 5.1)
std = "lua51"
max_line_length = 140
codes = true
self = false

ignore = {
    "212/_.*",  -- unused argument starting with _
    "211/_.*",  -- unused variable starting with _
    "431",      -- shadowing an upvalue
    "542",      -- empty if branch
}

exclude_files = {
    "Libs/**",
    ".release/**",
    "release/**",
    ".luarocks/**",
}

-- Globals this addon defines
globals = {
    "RaidGames",
    "RaidGamesDB",
    "SLASH_RAIDGAMES1",
    "SLASH_RAIDGAMES2",
    "SlashCmdList",
    "StaticPopupDialogs",
    "RaidGames_OnAddonCompartmentClick",
    "RaidGames_OnAddonCompartmentEnter",
    "RaidGames_OnAddonCompartmentLeave",
}

-- WoW API surface actually used; extend as luacheck complains, never dump the whole API.
read_globals = {
    -- Lua extensions provided by the client
    "strsplit", "strjoin", "strtrim", "format", "wipe", "tinsert", "tremove",
    "tContains", "tIndexOf", "CopyTable", "Mixin", "issecretvalue", "hooksecurefunc",
    "BreakUpLargeNumbers",
    -- Frames and UI
    "CreateFrame", "UIParent", "GameTooltip", "UISpecialFrames", "StaticPopup_Show",
    -- Global functions
    "GetBuildInfo", "GetLocale", "GetTime", "UnitName", "GetNormalizedRealmName", "GetRealmName",
    "InCombatLockdown", "print", "SendChatMessage", "IsInRaid", "IsInGroup",
    -- Constants and GlobalStrings
    "LE_PARTY_CATEGORY_HOME", "RANDOM_ROLL_RESULT", "YES", "NO",
    -- Namespaces
    "C_AddOns", "C_Timer", "C_ChatInfo", "Enum",
    -- Libraries
    "LibStub",
}

files["Locales/**"] = { max_line_length = false }

files["spec/**"] = {
    std = "+busted",
}
