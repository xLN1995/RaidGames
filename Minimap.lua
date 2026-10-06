local _, ns = ...
local RG = ns.RG
local L = RG.L

-- Minimap-Button (LibDataBroker + LibDBIcon) und Eintrag im Addon-Compartment.
local LDB_NAME = "RaidGames"
local ICON = "Interface\\AddOns\\RaidGames\\Media\\raidgames_icon_64"

function RG:OnLauncherClick(mouseButton)
    if mouseButton == "RightButton" then
        self:OpenUI("stats")
    else
        self:ToggleUI()
    end
end

local function FillTooltip(tooltip)
    tooltip:AddLine("RaidGames", 1, 0.82, 0)
    local session = RG.session
    if RG:IsSessionActive() then
        tooltip:AddLine(("%s - %s"):format(L[session.game.name], RG.Gold(session.bet)), 1, 1, 1)
        tooltip:AddLine(L["Players (%d)"]:format(session:PlayerCount()), 0.8, 0.8, 0.8)
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(L["Left-click: open or close"], 0.6, 0.6, 0.6)
    tooltip:AddLine(L["Right-click: statistics"], 0.6, 0.6, 0.6)
end

function RG:SetMinimapShown(shown)
    self.db.settings.minimap.hide = not shown
    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then
        if shown then
            icon:Show(LDB_NAME)
        else
            icon:Hide(LDB_NAME)
        end
    end
    self:Print(L["Minimap button:"] .. " " .. (shown and L["on"] or L["off"]))
end

RG:RegisterEvent("PLAYER_LOGIN", function()
    local broker = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)
    if not broker or not icon or icon:IsRegistered(LDB_NAME) then
        return
    end
    local launcher = broker:NewDataObject(LDB_NAME, {
        type = "launcher",
        label = "RaidGames",
        icon = ICON,
        OnClick = function(_, mouseButton)
            RG:OnLauncherClick(mouseButton)
        end,
        OnTooltipShow = FillTooltip,
    })
    icon:Register(LDB_NAME, launcher, RG.db.settings.minimap)
end)

-- TOC: AddonCompartmentFunc / FuncOnEnter / FuncOnLeave
function RaidGames_OnAddonCompartmentClick(_, mouseButton)
    RG:OnLauncherClick(mouseButton)
end

function RaidGames_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    FillTooltip(GameTooltip)
    GameTooltip:Show()
end

function RaidGames_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
