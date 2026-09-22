local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local RS           = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local gv = (getgenv and getgenv()) or _G
if gv.__PLUNDERER_RUNNING then return end
gv.__PLUNDERER_RUNNING = true

local UI_URL      = "https://raw.githubusercontent.com/Clide01/PlundererHub/refs/heads/main/PlundererUI.lua"
local MODULES_URL = "https://raw.githubusercontent.com/Clide01/PlundererHub/refs/heads/main/PlundererModules.lua"

local PlundererUI
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(UI_URL, true))()
    end)
    if not ok or type(mod) ~= "table" then
        warn("[PlundererHub] UI failed")
        gv.__PLUNDERER_RUNNING = false
        return
    end
    PlundererUI = mod
end

local Modules
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(MODULES_URL, true))()
    end)
    if ok and type(mod) == "table" and type(mod.getFieldEggs) == "function" then
        Modules = mod
    else
        warn("[PlundererHub] Modules failed")
        gv.__PLUNDERER_RUNNING = false
        return
    end
end

local ui = PlundererUI.new(PlayerGui, { Title = "PlundererHub" })

-- =========================================================
-- STATE
-- =========================================================
local State = {
    AntiRagdoll      = false,
    GodMode          = false,
    AutoJump         = false,
    AutoSell         = false,
    WalkSpeedBoost   = false,
    AutoSteal        = false,
    AutoAttack       = false,
    AutoTreadmill    = false,
    StealFromTarget  = nil,
    HeightScale      = 1.0,
    WalkSpeed        = 115,
    AttackRange      = 20,
    AreaFilter       = "All",
    StealDelay       = 2,
}

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getNetworking()
    return RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
end

-- =========================================================
-- BASELINE MODULES (same as v1.0)
-- =========================================================
local ANTI_STATES = {
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Physics,
    Enum.HumanoidStateType.PlatformStanding,
}

local function setAntiRagdoll(on)
    local hum = getHum()
    if not hum then return end
    for _, s in ipairs(ANTI_STATES) do
        pcall(function() hum:SetStateEnabled(s, not on) end)
    end
end

local godConn
local function setGodMode(on)
    if godConn then godConn:Disconnect(); godConn = nil end
    if on then
        godConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum.Health < hum.MaxHealth then
                pcall(function() hum.Health = hum.MaxHealth end)
            end
        end)
    end
end

local jumpConn
local function setAutoJump(on)
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if on then
        jumpConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum then pcall(function() hum.Jump = true end) end
        end)
    end
end

local function setHeight(scale)
    scale = math.clamp(tonumber(scale) or 1.0, 0.5, 2.0)
    State.HeightScale = scale
    local hum = getHum()
    if not hum then return end
    for _, name in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
        local obj = hum:FindFirstChild(name)
        if obj then pcall(function() obj.Value = scale end) end
    end
end

local wsConn
local function applyWalkSpeed(target)
    target = math.clamp(tonumber(target) or 115, 16, 500)
    State.WalkSpeed = target
    if wsConn then wsConn:Disconnect(); wsConn = nil end
    if State.WalkSpeedBoost then
        wsConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum and hum.WalkSpeed < target then
                pcall(function() hum.WalkSpeed = target end)
            end
        end)
    end
end

local sellThread
local function fireSellAll()
    local net = getNetworking()
    if not net then return end
    local sell = net:FindFirstChild("RE/PetSatchel/SellEveryPet")
    if sell then pcall(function() sell:FireServer() end) end
end

local function setAutoSell(on)
    State.AutoSell = on
    if sellThread then task.cancel(sellThread); sellThread = nil end
    if on then
        sellThread = task.spawn(function()
            while State.AutoSell do
                fireSellAll()
                task.wait(3)
            end
        end)
    end
end

-- =========================================================
-- NEW MODULE THREADS
-- =========================================================
local stealThread
local function setAutoSteal(on)
    State.AutoSteal = on
    if stealThread then task.cancel(stealThread); stealThread = nil end
    if on then
        stealThread = task.spawn(function()
            while State.AutoSteal do
                local ok, result = pcall(function()
                    return Modules:autoStealStep(State.AreaFilter, "Common")
                end)
                if ok then
                    ui:setBottomStatus("[Steal] " .. tostring(result))
                    print("[AutoSteal]", result)
                else
                    print("[AutoSteal] Error:", result)
                end
                task.wait(State.StealDelay)
            end
        end)
    end
end

local attackThread
local function setAutoAttack(on)
    State.AutoAttack = on
    if attackThread then task.cancel(attackThread); attackThread = nil end
    if on then
        attackThread = task.spawn(function()
            while State.AutoAttack do
                local ok, result = pcall(function()
                    return Modules:attackStep(State.AttackRange)
                end)
                if ok then
                    ui:setBottomStatus("[Attack] " .. tostring(result))
                    print("[AutoAttack]", result)
                end
                task.wait(1)
            end
        end)
    end
end

LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.AntiRagdoll then setAntiRagdoll(true) end
    if State.WalkSpeedBoost then applyWalkSpeed(State.WalkSpeed) end
    if State.HeightScale ~= 1.0 then setHeight(State.HeightScale) end
end)

-- =========================================================
-- UI TABS
-- =========================================================
local charTab = ui:addTab("Character", "🛡")
local defenseSection = ui:addSection(charTab, "Defense")
ui:addToggle(defenseSection, "Anti-Ragdoll", false, function(v)
    State.AntiRagdoll = v; setAntiRagdoll(v)
end)
ui:addToggle(defenseSection, "God Mode", false, function(v)
    State.GodMode = v; setGodMode(v)
end)

local bodySection = ui:addSection(charTab, "Body")
ui:addToggle(bodySection, "Auto Jump", false, function(v)
    State.AutoJump = v; setAutoJump(v)
end)
ui:addSlider(bodySection, "Character Height", 0.5, 2.0, 1.0, setHeight)

local moveSection = ui:addSection(charTab, "Movement")
ui:addToggle(moveSection, "WalkSpeed Boost", false, function(v)
    State.WalkSpeedBoost = v; applyWalkSpeed(State.WalkSpeed)
end)
ui:addSlider(moveSection, "WalkSpeed Value", 16, 500, 115, function(v)
    State.WalkSpeed = v
    if State.WalkSpeedBoost then applyWalkSpeed(v) end
end)

-- AUTO TAB
local autoTab = ui:addTab("Auto", "⚡")

local stealSection = ui:addSection(autoTab, "Egg Stealing")
ui:addToggle(stealSection, "Auto Steal Field Eggs", false, function(v)
    setAutoSteal(v)
end)
ui:addSlider(stealSection, "Steal Delay (seconds)", 1, 10, 2, function(v)
    State.StealDelay = v
end)

local attackSection = ui:addSection(autoTab, "Combat")
ui:addToggle(attackSection, "Auto Attack Players", false, function(v)
    setAutoAttack(v)
end)
ui:addSlider(attackSection, "Attack Range (studs)", 5, 50, 20, function(v)
    State.AttackRange = v
end)

local treadmillSection = ui:addSection(autoTab, "Treadmill")
ui:addToggle(treadmillSection, "Auto Treadmill", false, function(v)
    State.AutoTreadmill = v
    Modules:setAutoTreadmill(v)
end)

-- SELL TAB
local sellTab = ui:addTab("Selling", "💰")
local sellSection = ui:addSection(sellTab, "Auto Sell")
ui:addToggle(sellSection, "Auto Sell (every 3s)", false, function(v)
    setAutoSell(v)
end)
ui:addButton(sellSection, "Sell Now", fireSellAll)

local infoTab = ui:addTab("Info", "ℹ")
local infoSection = ui:addSection(infoTab, "PlundererHub v1.1")
ui:addLabel(infoSection, "Character: 6 modules")
ui:addLabel(infoSection, "Auto: 4 modules")
ui:addLabel(infoSection, "Total: 10 working modules")

ui:setStatus("Ready", "idle")
ui:setBottomStatus("PlundererHub v1.1 loaded")

print("[PlundererHub] v1.1 loaded — 10 modules active")
