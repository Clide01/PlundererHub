-- PlundererHub v1.0 — verified features only
-- Loads ControlPanel UI, wires 6 tested modules.

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local HttpService     = game:GetService("HttpService")
local RS              = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Re-entry guard
local gv = (getgenv and getgenv()) or _G
if gv.__PLUNDERER_RUNNING then return end
gv.__PLUNDERER_RUNNING = true

-- Module URLs (edit these if you rename files)
local AUTOMATION_UI_URL = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/AutomationUI.lua"
local LOADER_UI_URL     = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/LoaderUI.lua"
local ENDPOINTS_URL     = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/endpoints.json"

-- Fetch counter URL
local COUNTER_URL = nil
do
    local ok, res = pcall(function() return game:HttpGet(ENDPOINTS_URL, true) end)
    if ok and type(res) == "string" and #res > 0 then
        local dOk, data = pcall(function() return HttpService:JSONDecode(res) end)
        if dOk and type(data) == "table" and type(data.counter) == "string" then
            COUNTER_URL = data.counter
            print("[PlundererHub] Counter URL:", COUNTER_URL)
        end
    end
end

-- Load UI framework
local AutoUI
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(AUTOMATION_UI_URL, true))()
    end)
    if ok and type(mod) == "table" and type(mod.new) == "function" then
        AutoUI = mod
    else
        warn("[PlundererHub] Failed to load AutoUI")
        return
    end
end

-- Load full-screen boot UI
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
    Title = "PlundererHub",
    Subtitle = "Steal An Egg",
})

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
-- SHARED STATE
-- =========================================================
local State = _G.PlundererState or {}

State.Automation = State.Automation or {
    AntiRagdoll      = false,
    GodMode          = false,
    AutoJump         = false,
    AutoSell         = false,
    CharacterHeight  = false,
    WalkSpeedBoost   = false,
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
local function getChar()
    return LP.Character
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- =========================================================
-- MODULE 1: ANTI-RAGDOLL
-- =========================================================
-- Blocks the humanoid from entering Ragdoll / FallingDown / Physics states.
local ANTI_RAGDOLL_STATES = {
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Physics,
    Enum.HumanoidStateType.PlatformStanding,
}

local function setAntiRagdoll(enabled)
    local hum = getHum()
    if not hum then return end

    if enabled then
        for _, state in ipairs(ANTI_RAGDOLL_STATES) do
            pcall(function() hum:SetStateEnabled(state, false) end)
        end
        print("[PlundererHub] Anti-Ragdoll: ON")
    else
        for _, state in ipairs(ANTI_RAGDOLL_STATES) do
            pcall(function() hum:SetStateEnabled(state, true) end)
        end
        print("[PlundererHub] Anti-Ragdoll: OFF")
    end
end

-- =========================================================
-- MODULE 2: GOD MODE
-- =========================================================
local godConn = nil

local function setGodMode(enabled)
    if godConn then
        godConn:Disconnect()
        godConn = nil
    end

    if enabled then
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum.Health < hum.MaxHealth then
                pcall(function()
                    hum.Health = hum.MaxHealth
                end)
            end
        end)
        print("[PlundererHub] God Mode: ON")
    else
        print("[PlundererHub] God Mode: OFF")
    end
end

-- =========================================================
-- MODULE 3: AUTO JUMP
-- =========================================================
local jumpConn = nil

local function setAutoJump(enabled)
    if jumpConn then
        jumpConn:Disconnect()
        jumpConn = nil
    end

    if enabled then
        jumpConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                pcall(function()
                    hum.Jump = true
                end)
            end
        end)
        print("[PlundererHub] Auto Jump: ON")
    else
        print("[PlundererHub] Auto Jump: OFF")
    end
end

-- =========================================================
-- MODULE 4: CHARACTER HEIGHT
-- =========================================================
local function setHeight(scale)
    scale = math.clamp(tonumber(scale) or 1.0, 0.5, 2.0)
    State.Values.CharacterHeight = scale

    local hum = getHum()
    if not hum then return end

    for _, name in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
        local obj = hum:FindFirstChild(name)
        if obj then
            pcall(function() obj.Value = scale end)
        end
    end
    print(("[PlundererHub] Character Height: %.2f"):format(scale))
end

-- =========================================================
-- MODULE 5: WALKSPEED BOOST
-- =========================================================
local wsConn = nil

local function setWalkSpeed(target)
    target = math.clamp(tonumber(target) or 115, 16, 500)
    State.Values.WalkSpeed = target

    if wsConn then
        wsConn:Disconnect()
        wsConn = nil
    end

    if State.Automation.WalkSpeedBoost then
        wsConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum.WalkSpeed < target then
                pcall(function() hum.WalkSpeed = target end)
            end
        end)
    end
    print(("[PlundererHub] WalkSpeed: %d"):format(target))
end

-- =========================================================
-- MODULE 6: AUTO SELL
-- =========================================================
local sellConn = nil

local function fireSellAll()
    local Networking = RS:FindFirstChild("Packages")
        and RS.Packages:FindFirstChild("Networking")
    if not Networking then return end

    local sell = Networking:FindFirstChild("RE/PetSatchel/SellEveryPet")
    if not sell then return end

    pcall(function()
        sell:FireServer()
    end)
end

local function setAutoSell(enabled)
    if sellConn then
        sellConn:Disconnect()
        sellConn = nil
    end

    if enabled then
        sellConn = task.spawn(function()
            while State.Automation.AutoSell do
                fireSellAll()
                task.wait(3)
            end
        end)
        print("[PlundererHub] Auto Sell: ON (every 3s)")
    else
        print("[PlundererHub] Auto Sell: OFF")
    end
end

-- Auto-reapply anti-ragdoll after respawn
LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.Automation.AntiRagdoll then setAntiRagdoll(true) end
    if State.Automation.WalkSpeedBoost then setWalkSpeed(State.Values.WalkSpeed) end
    if State.Automation.CharacterHeight then setHeight(State.Values.CharacterHeight) end
end)

-- =========================================================
-- BUILD UI
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
ui:addSlider(charSection, "📏  Character Height", 0.5, 2.0, 1.0, function(v)
    State.Automation.CharacterHeight = true
    setHeight(v)
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

local farmSection = ui:addSection(autoTab, "Selling")
ui:addToggle(farmSection, "💰  Auto Sell (every 3s)", false, function(v)
    State.Automation.AutoSell = v
    setAutoSell(v)
end)

ui:setStatus("Ready", "idle")
ui:setBottomStatus("PlundererHub v1.0 — 6 modules ready")

print("[PlundererHub] Loaded. 6 modules active.")
