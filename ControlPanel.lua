-- ControlPanel.lua v1.0
-- PlundererHub Automation Control Panel
-- Requires AutomationUI.lua (already hosted)

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- Load AutoUI framework
-- =========================================================
local AutoUI_URL = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/AutomationUI.lua"

local AutoUI
local ok, err = pcall(function()
    AutoUI = loadstring(game:HttpGet(AutoUI_URL, true))()
end)

if not ok or type(AutoUI) ~= "table" or type(AutoUI.new) ~= "function" then
    warn("[ControlPanel] Failed to load AutoUI:", tostring(err))
    return
end

-- =========================================================
-- Shared state (exposed for automation modules)
-- =========================================================
local State = _G.PlundererState or {}

State.Automation = State.Automation or {
    AutoJumpToEgg           = false,
    AutoTeleportToEgg       = false,
    AutoCarryEgg            = false,
    AutoPlaceEgg            = false,
    AutoAttackNearbyPlayers = false,
    AutoStealHugeEgg        = false,
    AutoRiftEvent           = false,
    AutoCompleteIndex       = false,
    AutoStealParasiteEgg    = false,
    AutoServerHop           = false,
    AutoUpgrade             = false,
}

State.Player = State.Player or {
    AntiRagdoll      = false,
    AdjustableHeight = 1.0,
    CustomStealArea  = "All",
}

State.Targeting = State.Targeting or {
    TargetEgg     = "Nearest",
    StealPriority = "Nearest First",
    MinRarity     = "Rare",
}

State.Stats = State.Stats or {
    EggsStolen    = 0,
    ParasiteEggs  = 0,
    HugeEggs      = 0,
    ItemsSold     = 0,
    ValueEarned   = 0,
    RunsCompleted = 0,
    StartTime     = tick(),
}

_G.PlundererState = State

-- Filters reference (shared with AutoSteal module)
local Filters = _G.PlundererFilters or { Rarity = "All", Area = "All" }
_G.PlundererFilters = Filters

-- =========================================================
-- Build UI
-- =========================================================
local ui = AutoUI.new(PlayerGui, {
    Title    = "PlundererHub",
    Subtitle = "Steal An Egg · Automation",
})

-- =========================================================
-- TAB: Dashboard
-- =========================================================
local dashTab = ui:addTab("Dashboard", "🏠")
local overviewSection = ui:addSection(dashTab, "Overview")

local statusLabel  = ui:addLabel(overviewSection, "Ready", Color3.fromRGB(128, 255, 160))
local activeLabel  = ui:addLabel(overviewSection, "0 automations active")
local targetLabel  = ui:addLabel(overviewSection, "Target: Nearest · All")
local elapsedLabel = ui:addLabel(overviewSection, "Session: 00:00:00")

local quickSection = ui:addSection(dashTab, "Quick Controls")

ui:addButton(quickSection, "▶  Start All Automation", function()
    for k, _ in pairs(State.Automation) do
        State.Automation[k] = true
    end
    ui:setStatus("Running", "running")
    ui:setBottomStatus("All automations started")
end)

ui:addButton(quickSection, "⏸  Stop All Automation", function()
    for k, _ in pairs(State.Automation) do
        State.Automation[k] = false
    end
    ui:setStatus("Idle", "idle")
    ui:setBottomStatus("All automations stopped")
end)

local safeSection = ui:addSection(dashTab, "Safety")
ui:addButton(safeSection, "🚨 Emergency Stop (Disable Everything)", function()
    for k, _ in pairs(State.Automation) do
        State.Automation[k] = false
    end
    State.Player.AntiRagdoll = false
    ui:setStatus("Stopped", "error")
    ui:setBottomStatus("Emergency stop engaged")
end)

-- =========================================================
-- TAB: Automation
-- =========================================================
local autoTab = ui:addTab("Automation", "⚡")

-- Movement
local movementSection = ui:addSection(autoTab, "Movement")
ui:addToggle(movementSection, "🐇  Auto Jump to Egg", false, function(v)
    State.Automation.AutoJumpToEgg = v
    ui:setBottomStatus(v and "Auto Jump enabled" or "Auto Jump disabled")
end)
ui:addToggle(movementSection, "🌀  Auto Teleport to Egg", false, function(v)
    State.Automation.AutoTeleportToEgg = v
    ui:setBottomStatus(v and "Auto Teleport enabled" or "Auto Teleport disabled")
end)
ui:addToggle(movementSection, "🎒  Auto Carry Egg", false, function(v)
    State.Automation.AutoCarryEgg = v
end)
ui:addToggle(movementSection, "📍  Auto Place Egg", false, function(v)
    State.Automation.AutoPlaceEgg = v
end)

-- Combat & Events
local combatSection = ui:addSection(autoTab, "Combat & Events")
ui:addToggle(combatSection, "⚔  Auto Attack Nearby Players", false, function(v)
    State.Automation.AutoAttackNearbyPlayers = v
end)
ui:addToggle(combatSection, "🌀  Auto Rift Event", false, function(v)
    State.Automation.AutoRiftEvent = v
end)

-- Special Targets
local specialSection = ui:addSection(autoTab, "Special Targets")
ui:addToggle(specialSection, "💎  Auto Steal Huge Egg", false, function(v)
    State.Automation.AutoStealHugeEgg = v
end)
ui:addToggle(specialSection, "🦠  Auto Steal Parasite Egg", false, function(v)
    State.Automation.AutoStealParasiteEgg = v
end)

-- Progress
local progressSection = ui:addSection(autoTab, "Progress")
ui:addToggle(progressSection, "📖  Auto Complete Index", false, function(v)
    State.Automation.AutoCompleteIndex = v
end)
ui:addToggle(progressSection, "⚡  Auto Upgrade", false, function(v)
    State.Automation.AutoUpgrade = v
end)

-- Server
local serverSection = ui:addSection(autoTab, "Server")
ui:addToggle(serverSection, "🔄  Auto Server Hop", false, function(v)
    State.Automation.AutoServerHop = v
end)

-- =========================================================
-- TAB: Player
-- =========================================================
local playerTab = ui:addTab("Player", "👤")

local charSection = ui:addSection(playerTab, "Character")
ui:addToggle(charSection, "🛡  Anti-Ragdoll", false, function(v)
    State.Player.AntiRagdoll = v
    ui:setBottomStatus(v and "Anti-Ragdoll enabled" or "Anti-Ragdoll disabled")
end)
ui:addSlider(charSection, "📏  Character Height", 0.5, 2.0, 1.0, function(v)
    State.Player.AdjustableHeight = v
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local scale = hum:FindFirstChild("BodyHeightScale")
        if scale then pcall(function() scale.Value = v end) end
    end
end)

local targetingSection = ui:addSection(playerTab, "Targeting")
ui:addDropdown(targetingSection, "🎯  Custom Steal Area", {
    "All", "Forest", "Desert", "Prehistoric", "Volcano",
    "Light Dark", "Cherry Blossom", "Cosmic", "Abyss Ocean",
    "Titan Temple", "Monster", "Rift",
}, "All", function(v)
    State.Player.CustomStealArea = v
    Filters.Area = v
    ui:setBottomStatus("Steal area: " .. v)
end)

-- =========================================================
-- TAB: Targets
-- =========================================================
local targetTab = ui:addTab("Targets", "🎯")

local targetSelectSection = ui:addSection(targetTab, "Egg Selection")
ui:addDropdown(targetSelectSection, "Target Priority", {
    "Nearest", "Rarest", "Huge", "Parasite",
    "Secret", "Cosmic", "Divine", "Eternal",
    "Mythic", "Legendary", "Epic", "Rare", "Any",
}, "Nearest", function(v)
    State.Targeting.TargetEgg = v
    Filters.Rarity = v
end)
ui:addDropdown(targetSelectSection, "Steal Order", {
    "Nearest First", "Rarest First", "Highest Value First", "Lowest Contested",
}, "Nearest First", function(v)
    State.Targeting.StealPriority = v
end)

local raritySection = ui:addSection(targetTab, "Rarity Filter")
ui:addDropdown(raritySection, "Minimum Rarity to Steal", {
    "Common", "Uncommon", "Rare", "Epic", "Legendary",
    "Mythic", "Divine", "Eternal", "Cosmic", "Secret",
}, "Rare", function(v)
    State.Targeting.MinRarity = v
end)

-- =========================================================
-- TAB: Stats
-- =========================================================
local statsTab = ui:addTab("Stats", "📊")
local statsSection = ui:addSection(statsTab, "Session Stats")

local eggsLabel     = ui:addLabel(statsSection, "Eggs Stolen: 0")
local parasiteLabel = ui:addLabel(statsSection, "Parasite Eggs: 0")
local hugeLabel     = ui:addLabel(statsSection, "Huge Eggs: 0")
local soldLabel     = ui:addLabel(statsSection, "Items Sold: 0")
local valueLabel    = ui:addLabel(statsSection, "Value Earned: $0")
local runsLabel     = ui:addLabel(statsSection, "Runs Completed: 0")
local timeLabel     = ui:addLabel(statsSection, "Session Time: 00:00:00")

ui:addButton(statsSection, "Reset Session Stats", function()
    State.Stats.EggsStolen    = 0
    State.Stats.ParasiteEggs  = 0
    State.Stats.HugeEggs      = 0
    State.Stats.ItemsSold     = 0
    State.Stats.ValueEarned   = 0
    State.Stats.RunsCompleted = 0
    State.Stats.StartTime     = tick()
    ui:setBottomStatus("Stats reset")
end)

-- =========================================================
-- Public helpers for automation modules
-- =========================================================
function State.BumpStat(key, amount)
    if State.Stats[key] ~= nil then
        State.Stats[key] = State.Stats[key] + (amount or 1)
    end
end

function State.GetActiveCount()
    local count = 0
    for _, v in pairs(State.Automation) do
        if v then count = count + 1 end
    end
    return count
end

function State.SetAutomation(name, value)
    if State.Automation[name] ~= nil then
        State.Automation[name] = value and true or false
    end
end

-- =========================================================
-- Live UI update loop
-- =========================================================
task.spawn(function()
    while ui.screen and ui.screen.Parent do
        local active = State.GetActiveCount()

        activeLabel.Text = string.format("%d automation%s active", active, active == 1 and "" or "s")
        targetLabel.Text = string.format("Target: %s · %s", State.Targeting.TargetEgg, State.Player.CustomStealArea)

        local elapsed = tick() - State.Stats.StartTime
        local hh = math.floor(elapsed / 3600)
        local mm = math.floor((elapsed % 3600) / 60)
        local ss = math.floor(elapsed % 60)
        elapsedLabel.Text = string.format("Session: %02d:%02d:%02d", hh, mm, ss)

        eggsLabel.Text     = "Eggs Stolen: " .. State.Stats.EggsStolen
        parasiteLabel.Text = "Parasite Eggs: " .. State.Stats.ParasiteEggs
        hugeLabel.Text     = "Huge Eggs: " .. State.Stats.HugeEggs
        soldLabel.Text     = "Items Sold: " .. State.Stats.ItemsSold
        valueLabel.Text    = string.format("Value Earned: $%s", tostring(State.Stats.ValueEarned))
        runsLabel.Text     = "Runs Completed: " .. State.Stats.RunsCompleted
        timeLabel.Text     = string.format("Session Time: %02d:%02d:%02d", hh, mm, ss)

        if active > 0 then
            ui:setStatus("Running · " .. active .. " active", "running")
        else
            ui:setStatus("Idle", "idle")
        end

        task.wait(0.5)
    end
end)

-- =========================================================
-- Expose
-- =========================================================
_G.ControlPanel = {
    ui = ui,
    State = State,
}

return _G.ControlPanel
