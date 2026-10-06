local _, ns = ...
local RG = ns.RG
local L = RG.L

-- results: { { name = "Name-Realm", delta = 1234 }, ... } – alle Teilnehmer, auch mit delta 0
function RG:BookResults(gameId, results)
    local stats = self.db.stats
    for _, result in ipairs(results) do
        local entry = stats[result.name]
        if not entry then
            entry = { net = 0, games = 0, won = 0, lost = 0, byGame = {} }
            stats[result.name] = entry
        end
        entry.net = entry.net + result.delta
        entry.games = entry.games + 1
        if result.delta > 0 then
            entry.won = entry.won + 1
        elseif result.delta < 0 then
            entry.lost = entry.lost + 1
        end
        local perGame = entry.byGame[gameId] or { net = 0, games = 0 }
        perGame.net = perGame.net + result.delta
        perGame.games = perGame.games + 1
        entry.byGame[gameId] = perGame
    end
    self:Fire("UPDATE")
end

-- Liefert { { name, net, games, won, lost }, ... } sortiert (absteigend = Top).
function RG:GetRanking(descending, limit)
    local list = {}
    for name, entry in pairs(self.db.stats) do
        table.insert(list, {
            name = name,
            net = entry.net,
            games = entry.games,
            won = entry.won,
            lost = entry.lost,
        })
    end
    table.sort(list, function(a, b)
        if a.net == b.net then
            return a.name < b.name
        end
        if descending then
            return a.net > b.net
        end
        return a.net < b.net
    end)
    if limit and #list > limit then
        for i = #list, limit + 1, -1 do
            list[i] = nil
        end
    end
    return list
end

function RG:AnnounceRanking(top, count)
    local list = self:GetRanking(top, count)
    if #list == 0 then
        self:Send(L["No statistics yet."])
        return
    end
    local items = {}
    for i, entry in ipairs(list) do
        items[i] = ("%d. %s %s"):format(i, RG.Short(entry.name), RG.SignedGold(entry.net))
    end
    local header = (top and L["Top %d: "] or L["Bottom %d: "]):format(#list)
    self:SendList(header, items, " / ")
end

function RG:ResetStats()
    wipe(self.db.stats)
    self:Print(L["Statistics reset."])
    self:Fire("UPDATE")
end

function RG:ConfirmResetStats()
    StaticPopupDialogs.RAIDGAMES_RESET_STATS.text = L["RaidGames: really reset all statistics?"]
    StaticPopup_Show("RAIDGAMES_RESET_STATS")
end

StaticPopupDialogs.RAIDGAMES_RESET_STATS = {
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        RG:ResetStats()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
