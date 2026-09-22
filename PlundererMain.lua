-- PlundererMain.lua v1.0
-- Standalone Steal An Egg automation script.
-- Separate from the troll/sell pipeline. No D1, no router, no counter.

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInput    = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")
local HttpService  = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Re-entry guard
local gv = (getgenv and getgenv()) or _G
if gv.__PLUNDERERMAIN_RUNNING then
    warn("[PlundererMain] Already running.")
    return
end
gv.__PLUNDERERMAIN_RUNNING = true

-- URLs (edit if you rename files)
local AUTOMATION_UI_URL = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/AutomationUI.lua"
local LOADER_UI_URL     = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/LoaderUI.lua"

-- Load AutomationUI
local AutoUI
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(AUTOMATION_UI_URL, true))()
    end)
    if ok and type(mod) == "table" and type(mod.new) == "function" then
        AutoUI = mod
    else
        warn("[PlundererMain] Failed to load AutoUI:", tostring(mod))
        return
    end
end

-- Load LoaderUI (boot screen)
local LoaderUI
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(LOADER_UI_URL, true))()
    end)
    if ok and type(mod) == "table" and type(mod.new) == "function" then
        LoaderUI = mod
    end
end

local ui = AutoUI.new(PlayerGui, {
    Title    = "PlundererHub",
    Subtitle = "Steal An Egg · Automation",
    BubbleIcon = "⚡",
})

-- Boot animation
if LoaderUI then
    local bootUI = LoaderUI.new(PlayerGui, {
        MEME_IMAGE_ID  = "rbxassetid://82403642047427",
        LAUGH_SOUND_ID = "rbxassetid://133312610824902",
        MEME_SIZE      = 380,
    })
    bootUI:boot()
    task.delay(3, function()
        pcall(function() bootUI:fadeOutAndCleanup() end)
    end)
end

-- =========================================================
-- STATE
-- =========================================================
local State = _G.PlundererState or {}

State.Automation = State.Automation or {
    AntiRagdoll     = false,
    GodMode         = false,
    AutoJump        = false,
    WalkSpeedBoost  = false,
}

State.Values = State.Values or {
    CharacterHeight = 1.0,
    WalkSpeed       = 115,
}

State.Stats = State.Stats or {
    StartTime = tick(),
}

_G.PlundererState = State

-- =========================================================
-- HELPERS
-- =========================================================
local function getHum()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- =========================================================
-- MODULE 1 — ANTI-RAGDOLL
-- =========================================================
local ANTI_RAGDOLL_STATES = {
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Physics,
    Enum.HumanoidStateType.PlatformStanding,
}

local function setAntiRagdoll(enabled)
    local hum = getHum()
    if not hum then return end
    for _, state in ipairs(ANTI_RAGDOLL_STATES) do
        pcall(function() hum:SetStateEnabled(state, not enabled) end)
    end
    print("[PlundererMain] Anti-Ragdoll:", enabled and "ON" or "OFF")
end

-- =========================================================
-- MODULE 2 — GOD MODE
-- =========================================================
local godConn = nil

local function setGodMode(enabled)
    if godConn then godConn:Disconnect(); godConn = nil end
    if enabled then
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum.Health < hum.MaxHealth then
                pcall(function() hum.Health = hum.MaxHealth end)
            end
        end)
    end
    print("[PlundererMain] God Mode:", enabled and "ON" or "OFF")
end

-- =========================================================
-- MODULE 3 — AUTO JUMP
-- =========================================================
local jumpConn = nil

local function setAutoJump(enabled)
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if enabled then
        jumpConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                pcall(function() hum.Jump = true end)
            end
        end)
    end
    print("[PlundererMain] Auto Jump:", enabled and "ON" or "OFF")
end

-- =========================================================
-- MODULE 4 — CHARACTER HEIGHT
-- =========================================================
local function setHeight(scale)
    scale = math.clamp(tonumber(scale) or 1.0, 0.5, 2.0)
    State.Values.CharacterHeight = scale
    local hum = getHum()
    if not hum then return end
    for _, name in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
        local obj = hum:FindFirstChild(name)
        if obj then pcall(function() obj.Value = scale end) end
    end
end

-- =========================================================
-- MODULE 5 — WALKSPEED BOOST
-- =========================================================
local wsConn = nil

local function setWalkSpeed(target)
    target = math.clamp(tonumber(target) or 115, 16, 500)
    State.Values.WalkSpeed = target

    if wsConn then wsConn:Disconnect(); wsConn = nil end

    if State.Automation.WalkSpeedBoost then
        wsConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum.WalkSpeed < target then
                pcall(function() hum.WalkSpeed = target end)
            end
        end)
    end
end

-- =========================================================
-- SPAWN HANDLER — reapply after respawn
-- =========================================================
LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.Automation.AntiRagdoll then setAntiRagdoll(true) end
    if State.Automation.WalkSpeedBoost then setWalkSpeed(State.Values.WalkSpeed) end
    if State.Values.CharacterHeight ~= 1.0 then setHeight(State.Values.CharacterHeight) end
end)

-- =========================================================
-- UI — Dashboard
-- =========================================================
local dashTab = ui:addTab("Dashboard", "🏠")
local overviewSection = ui:addSection(dashTab, "Overview")

local statusLabel  = ui:addLabel(overviewSection, "Ready", Color3.fromRGB(128, 255, 160))
local activeLabel  = ui:addLabel(overviewSection, "0 modules active")
local elapsedLabel = ui:addLabel(overviewSection, "Session: 00:00:00")

local quickSection = ui:addSection(dashTab, "Quick Controls")

ui:addButton(quickSection, "▶  Enable All", function()
    State.Automation.AntiRagdoll = true
    State.Automation.GodMode = true
    State.Automation.WalkSpeedBoost = true
    setAntiRagdoll(true)
    setGodMode(true)
    setWalkSpeed(State.Values.WalkSpeed)
    ui:setStatus("Running", "running")
end)

ui:addButton(quickSection, "⏸  Disable All", function()
    State.Automation.AntiRagdoll = false
    State.Automation.GodMode = false
    State.Automation.AutoJump = false
    State.Automation.WalkSpeedBoost = false
    setAntiRagdoll(false)
    setGodMode(false)
    setAutoJump(false)
    setWalkSpeed(State.Values.WalkSpeed)
    ui:setStatus("Idle", "idle")
end)

local safeSection = ui:addSection(dashTab, "Safety")
ui:addButton(safeSection, "🚨  Emergency Stop", function()
    State.Automation.AntiRagdoll = false
    State.Automation.GodMode = false
    State.Automation.AutoJump = false
    State.Automation.WalkSpeedBoost = false
    setAntiRagdoll(false)
    setGodMode(false)
    setAutoJump(false)
    if wsConn then wsConn:Disconnect(); wsConn = nil end
    ui:setStatus("Stopped", "error")
    ui:setBottomStatus("Emergency stop engaged")
end)

-- =========================================================
-- UI — Automation Tab
-- =========================================================
local autoTab = ui:addTab("Automation", "⚡")

local charSection = ui:addSection(autoTab, "Character")
ui:addToggle(charSection, "🛡  Anti-Ragdoll", false, function(v)
    State.Automation.AntiRagdoll = v
    setAntiRagdoll(v)
end)
ui:addToggle(charSection, "❤️  God Mode", false, function(v)
    State.Automation.GodMode = v
    setGodMode(v)
end)
ui:addToggle(charSection, "🐇  Auto Jump", false, function(v)
    State.Automation.AutoJump = v
    setAutoJump(v)
end)

local moveSection = ui:addSection(autoTab, "Movement")
ui:addToggle(moveSection, "🏃  WalkSpeed Boost", false, function(v)
    State.Automation.WalkSpeedBoost = v
    setWalkSpeed(State.Values.WalkSpeed)
end)
ui:addSlider(moveSection, "👟  WalkSpeed Value", 16, 500, 115, function(v)
    State.Values.WalkSpeed = v
    if State.Automation.WalkSpeedBoost then setWalkSpeed(v) end
end)
ui:addSlider(moveSection, "📏  Character Height", 0.5, 2.0, 1.0, function(v)
    setHeight(v)
end)

-- =========================================================
-- UI — Player Tab
-- =========================================================
local playerTab = ui:addTab("Player", "👤")
local infoSection = ui:addSection(playerTab, "Character Info")

local hpLabel    = ui:addLabel(infoSection, "Health: —")
local wsLabel    = ui:addLabel(infoSection, "WalkSpeed: —")
local stateLabel = ui:addLabel(infoSection, "State: —")

-- =========================================================
-- LIVE UPDATE LOOP
-- =========================================================
task.spawn(function()
    while ui.screen and ui.screen.Parent do
        local active = 0
        for _, v in pairs(State.Automation) do if v then active = active + 1 end end

        activeLabel.Text = string.format("%d module%s active", active, active == 1 and "" or "s")

        local elapsed = tick() - State.Stats.StartTime
        local hh = math.floor(elapsed / 3600)
        local mm = math.floor((elapsed % 3600) / 60)
        local ss = math.floor(elapsed % 60)
        elapsedLabel.Text = string.format("Session: %02d:%02d:%02d", hh, mm, ss)

        local hum = getHum()
        if hum then
            hpLabel.Text = string.format("Health: %d / %d", hum.Health, hum.MaxHealth)
            wsLabel.Text = string.format("WalkSpeed: %d", hum.WalkSpeed)
            pcall(function() stateLabel.Text = "State: " .. tostring(hum:GetState()):gsub("Enum.HumanoidStateType.", "") end)
        end

        if active > 0 then
            ui:setStatus("Running · " .. active .. " active", "running")
            if ui.setBubbleBadge then ui:setBubbleBadge(true) end
        else
            ui:setStatus("Idle", "idle")
            if ui.setBubbleBadge then ui:setBubbleBadge(false) end
        end

        task.wait(0.5)
    end
end)

ui:setStatus("Ready", "idle")
ui:setBottomStatus("PlundererMain v1.0 — 4 modules ready")

print("[PlundererMain] Loaded. Separate from the troll pipeline.")
