local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local RS           = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Re-entry guard
local gv = (getgenv and getgenv()) or _G
if gv.__PLUNDERER_RUNNING then
    warn("[PlundererHub] Already running.")
    return
end
gv.__PLUNDERER_RUNNING = true

-- URLs
local UI_URL = "https://raw.githubusercontent.com/Clide01/PlundererHub/refs/heads/main/PlundererUI.lua"

-- Load UI
local PlundererUI
do
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(UI_URL, true))()
    end)
    if not ok or type(mod) ~= "table" or type(mod.new) ~= "function" then
        warn("[PlundererHub] UI failed to load:", tostring(mod))
        gv.__PLUNDERER_RUNNING = false
        return
    end
    PlundererUI = mod
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
    HeightScale      = 1.0,
    WalkSpeed        = 115,
}

-- =========================================================
-- HELPERS
-- =========================================================
local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getNetworking()
    return RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
end

-- =========================================================
-- MODULE 1: ANTI-RAGDOLL
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
    print("[PlundererHub] Anti-Ragdoll:", on)
end

-- =========================================================
-- MODULE 2: GOD MODE
-- =========================================================
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
    print("[PlundererHub] God Mode:", on)
end

-- =========================================================
-- MODULE 3: AUTO JUMP
-- =========================================================
local jumpConn

local function setAutoJump(on)
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if on then
        jumpConn = RunService.Heartbeat:Connect(function()
            local hum = getHum()
            if hum then pcall(function() hum.Jump = true end) end
        end)
    end
    print("[PlundererHub] Auto Jump:", on)
end

-- =========================================================
-- MODULE 4: CHARACTER HEIGHT
-- =========================================================
local function setHeight(scale)
    scale = math.clamp(tonumber(scale) or 1.0, 0.5, 2.0)
    State.HeightScale = scale
    local hum = getHum()
    if not hum then return end
    for _, name in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
        local obj = hum:FindFirstChild(name)
        if obj then pcall(function() obj.Value = scale end) end
    end
    print(("[PlundererHub] Height: %.2f"):format(scale))
end

-- =========================================================
-- MODULE 5: WALKSPEED
-- =========================================================
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
    print(("[PlundererHub] WalkSpeed: %d"):format(target))
end

-- =========================================================
-- MODULE 6: AUTO SELL
-- =========================================================
local sellThread = nil

local function fireSellAll()
    local net = getNetworking()
    if not net then return end
    local sell = net:FindFirstChild("RE/PetSatchel/SellEveryPet")
    if sell then pcall(function() sell:FireServer() end) end
end

local function setAutoSell(on)
    State.AutoSell = on
    if sellThread then
        task.cancel(sellThread)
        sellThread = nil
    end
    if on then
        sellThread = task.spawn(function()
            while State.AutoSell do
                fireSellAll()
                task.wait(3)
            end
        end)
    end
    print("[PlundererHub] Auto Sell:", on)
end

-- Reapply on respawn
LP.CharacterAdded:Connect(function()
    task.wait(2)
    if State.AntiRagdoll then setAntiRagdoll(true) end
    if State.WalkSpeedBoost then applyWalkSpeed(State.WalkSpeed) end
    if State.HeightScale ~= 1.0 then setHeight(State.HeightScale) end
end)

-- =========================================================
-- UI
-- =========================================================
local charTab = ui:addTab("Character", "🛡")

local defenseSection = ui:addSection(charTab, "Defense")
ui:addToggle(defenseSection, "Anti-Ragdoll", false, function(v)
    State.AntiRagdoll = v
    setAntiRagdoll(v)
end)
ui:addToggle(defenseSection, "God Mode", false, function(v)
    State.GodMode = v
    setGodMode(v)
end)

local bodySection = ui:addSection(charTab, "Body")
ui:addToggle(bodySection, "Auto Jump", false, function(v)
    State.AutoJump = v
    setAutoJump(v)
end)
ui:addSlider(bodySection, "Character Height", 0.5, 2.0, 1.0, function(v)
    setHeight(v)
end)

local moveSection = ui:addSection(charTab, "Movement")
ui:addToggle(moveSection, "WalkSpeed Boost", false, function(v)
    State.WalkSpeedBoost = v
    applyWalkSpeed(State.WalkSpeed)
end)
ui:addSlider(moveSection, "WalkSpeed Value", 16, 500, 115, function(v)
    State.WalkSpeed = v
    if State.WalkSpeedBoost then applyWalkSpeed(v) end
end)

local farmTab = ui:addTab("Farming", "⚡")
local sellSection = ui:addSection(farmTab, "Selling")
ui:addToggle(sellSection, "Auto Sell (every 3s)", false, function(v)
    setAutoSell(v)
end)
ui:addButton(sellSection, "Sell Now", function()
    fireSellAll()
end)

local infoTab = ui:addTab("Info", "ℹ")
local infoSection = ui:addSection(infoTab, "About")
ui:addLabel(infoSection, "PlundererHub v1.0")
ui:addLabel(infoSection, "6 verified modules")
ui:addLabel(infoSection, "More features coming soon")

ui:setStatus("Ready", "idle")
ui:setBottomStatus("PlundererHub v1.0 loaded")

print("[PlundererHub] Loaded. Re-entry guard active.")
