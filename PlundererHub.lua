local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local RS           = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local gv = (getgenv and getgenv()) or _G
if gv.__PLUNDERER_RUNNING then
    warn("[PlundererHub] Already running")
    return
end
gv.__PLUNDERER_RUNNING = true

local UI_URL      = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/PlundererUI.lua"
local MODULES_URL = "https://raw.githubusercontent.com/Clide01/PlundererHub/main/PlundererModules.lua"

local function timedFetch(url, timeout)
    timeout = timeout or 8
    local body, done
    task.spawn(function()
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if ok then body = res end
        done = true
    end)
    local t0 = tick()
    while not done and (tick() - t0) < timeout do task.wait(0.1) end
    return body
end

print("[PlundererHub] Loading UI...")
local PlundererUI
do
    local body = timedFetch(UI_URL, 8)
    if body then
        local fn = loadstring(body)
        if fn then
            local ok, mod = pcall(fn)
            if ok and type(mod) == "table" and type(mod.new) == "function" then
                PlundererUI = mod
            end
        end
    end
end

if not PlundererUI then
    warn("[PlundererHub] UI failed")
    gv.__PLUNDERER_RUNNING = false
    return
end

print("[PlundererHub] Loading modules...")
local Modules
do
    local body = timedFetch(MODULES_URL, 8)
    if body then
        local fn = loadstring(body)
        if fn then
            local ok, mod = pcall(fn)
            if ok and type(mod) == "table" and type(mod.getFieldEggs) == "function" then
                Modules = mod
            end
        end
    end
end

if not Modules then
    warn("[PlundererHub] Modules failed")
    gv.__PLUNDERER_RUNNING = false
    return
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
    HeightScale      = 1.0,
    WalkSpeed        = 115,
    AttackRange      = 20,
    StealDelay       = 3,
    TargetCategory   = "All",
    AttackMode       = "Any Nearby",
    SpecificTarget   = nil,
}

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getNetworking()
    return RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
end

-- =========================================================
-- BASELINE MODULES
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

local stealThread
local function setAutoSteal(on)
    State.AutoSteal = on
    if stealThread then task.cancel(stealThread); stealThread = nil end
    if not on then return end
    stealThread = task.spawn(function()
        while State.AutoSteal do
            local ok, result = pcall(function()
                return Modules:autoStealStep(State.TargetCategory)
            end)
            local msg = ok and tostring(result) or ("error: " .. tostring(result))
            ui:setBottomStatus("[Steal] " .. msg)
            print("[AutoSteal]", msg)
            task.wait(State.StealDelay)
        end
    end)
end

local attackThread
local function setAutoAttack(on)
    State.AutoAttack = on
    if attackThread then task.cancel(attackThread); attackThread = nil end
    if not on then return end
    attackThread = task.spawn(function()
        while State.AutoAttack do
            local result
            if State.AttackMode == "Specific Player" and State.SpecificTarget then
                local ok, res = pcall(function()
                    return Modules:stealFromPlayer(State.SpecificTarget)
                end)
                result = ok and res or ("error " .. tostring(res))
            else
                local ok, res = pcall(function()
                    return Modules:attackStep(State.AttackRange)
                end)
                result = ok and res or ("error " .. tostring(res))
            end
            print("[AutoAttack]", result)
            ui:setBottomStatus("[Attack] " .. tostring(result))
            task.wait(1)
        end
    end)
end

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

-- Dynamic egg category dropdown (fetched from field snapshot)
local categoryList = Modules:getEggCategories()
local categoryDropdown = ui:addDropdown(stealSection, "Target Egg", categoryList, "All", function(v)
    State.TargetCategory = v
    ui:setBottomStatus("Target egg: " .. v)
end)

ui:addButton(stealSection, "🔄 Refresh Egg List", function()
    local fresh = Modules:getEggCategories()
    categoryDropdown.set(State.TargetCategory)
    ui:setBottomStatus("Egg list refreshed (" .. #fresh - 1 .. " categories)")
    print("[PlundererHub] Egg categories:", table.concat(fresh, ", "))
end)

ui:addToggle(stealSection, "Auto Steal", false, function(v)
    setAutoSteal(v)
end)
ui:addSlider(stealSection, "Steal Delay (s)", 1, 10, 3, function(v)
    State.StealDelay = v
end)

-- COMBAT TAB
local combatSection = ui:addSection(autoTab, "Combat")
ui:addDropdown(combatSection, "Attack Mode", {
    "Any Nearby", "Specific Player",
}, "Any Nearby", function(v)
    State.AttackMode = v
    ui:setBottomStatus("Attack mode: " .. v)
end)
ui:addSlider(combatSection, "Attack Range (studs)", 5, 50, 20, function(v)
    State.AttackRange = v
end)
ui:addToggle(combatSection, "Auto Attack", false, function(v)
    setAutoAttack(v)
end)
ui:addButton(combatSection, "Attack Nearest Now", function()
    local ok, res = pcall(function() return Modules:attackStep(State.AttackRange) end)
    ui:setBottomStatus("[Attack] " .. tostring(res))
    print("[AutoAttack]", res)
end)

-- SELL TAB
local sellTab = ui:addTab("Selling", "💰")
local sellSection = ui:addSection(sellTab, "Auto Sell")
ui:addToggle(sellSection, "Auto Sell (every 3s)", false, function(v)
    setAutoSell(v)
end)
ui:addButton(sellSection, "Sell Now", function()
    fireSellAll()
    ui:setBottomStatus("Sold all pets")
end)

-- INFO TAB
local infoTab = ui:addTab("Info", "ℹ")
local infoSection = ui:addSection(infoTab, "PlundererHub v1.2")
ui:addLabel(infoSection, "Character: 6 modules")
ui:addLabel(infoSection, "Auto Steal: 1 module")
ui:addLabel(infoSection, "Combat: 2 modules")
ui:addLabel(infoSection, "Selling: 1 module")
ui:addLabel(infoSection, "Total: 10 modules")

ui:setStatus("Ready", "idle")
ui:setBottomStatus("PlundererHub v1.2 loaded")

print("[PlundererHub] === READY ===")
print("[PlundererHub] v1.2 loaded — 10 modules active")
