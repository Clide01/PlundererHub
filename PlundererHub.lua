print("[PlundererHub] === START ===")

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local RS           = game:GetService("ReplicatedStorage")

print("[PlundererHub] Step 1: services loaded")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
print("[PlundererHub] Step 2: player + gui ready")

local gv = (getgenv and getgenv()) or _G
if gv.__PLUNDERER_RUNNING then
    warn("[PlundererHub] Already running — aborting")
    return
end
gv.__PLUNDERER_RUNNING = true
print("[PlundererHub] Step 3: guard set")

local UI_URL      = "https://raw.githubusercontent.com/Clide01/PlundererHub/refs/heads/main/PlundererUI.lua"
local MODULES_URL = "https://raw.githubusercontent.com/Clide01/PlundererHub/refs/heads/main/PlundererModules.lua"

-- =========================================================
-- TIMED HTTP FETCH
-- =========================================================
local function timedFetch(url, timeout)
    timeout = timeout or 8
    print(("[PlundererHub] Fetching %s (timeout %ds)"):format(url:sub(-40), timeout))
    local start = tick()

    local body = nil
    local done = false
    task.spawn(function()
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if ok then body = res end
        done = true
    end)

    while not done and (tick() - start) < timeout do
        task.wait(0.1)
    end

    if not done then
        warn(("[PlundererHub] TIMEOUT after %ds fetching %s"):format(timeout, url))
        return nil
    end
    print(("[PlundererHub] Fetched in %.2fs (%d bytes)"):format(tick() - start, type(body) == "string" and #body or 0))
    return body
end

-- =========================================================
-- LOAD MODULES FIRST (smaller, faster)
-- =========================================================
print("[PlundererHub] Step 4: loading Modules...")
local Modules = nil
do
    local body = timedFetch(MODULES_URL, 6)
    if body then
        local fn, err = loadstring(body)
        if fn then
            local ok, mod = pcall(fn)
            if ok and type(mod) == "table" and type(mod.getFieldEggs) == "function" then
                Modules = mod
                print("[PlundererHub] Modules loaded OK")
            else
                warn("[PlundererHub] Modules table invalid:", tostring(mod))
            end
        else
            warn("[PlundererHub] Modules compile failed:", err)
        end
    else
        warn("[PlundererHub] Modules fetch timed out — continuing without")
    end
end

-- =========================================================
-- LOAD UI
-- =========================================================
print("[PlundererHub] Step 5: loading UI...")
local PlundererUI = nil
do
    local body = timedFetch(UI_URL, 8)
    if body then
        local fn, err = loadstring(body)
        if fn then
            local ok, mod = pcall(fn)
            if ok and type(mod) == "table" and type(mod.new) == "function" then
                PlundererUI = mod
                print("[PlundererHub] UI loaded OK")
            else
                warn("[PlundererHub] UI table invalid:", tostring(mod))
            end
        else
            warn("[PlundererHub] UI compile failed:", err)
        end
    else
        warn("[PlundererHub] UI fetch timed out")
    end
end

if not PlundererUI then
    warn("[PlundererHub] Cannot continue without UI")
    gv.__PLUNDERER_RUNNING = false
    return
end

print("[PlundererHub] Step 6: building UI window...")
local ui = PlundererUI.new(PlayerGui, { Title = "PlundererHub" })
print("[PlundererHub] Step 7: UI built")

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
    HeightScale      = 1.0,
    WalkSpeed        = 115,
    AttackRange      = 20,
    AreaFilter       = "All",
    StealDelay       = 3,
}

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getNetworking()
    return RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
end

print("[PlundererHub] Step 8: defining modules...")

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

-- =========================================================
-- NEW MODULES (guarded by Modules being loaded)
-- =========================================================
local stealThread
local function setAutoSteal(on)
    State.AutoSteal = on
    if stealThread then task.cancel(stealThread); stealThread = nil end
    if not on then return end
    if not Modules then
        warn("[AutoSteal] Modules not loaded")
        return
    end
    stealThread = task.spawn(function()
        while State.AutoSteal do
            local ok, result = pcall(function()
                return Modules:autoStealStep(State.AreaFilter, "Common")
            end)
            print("[AutoSteal]", tostring(result))
            if not ok then
                ui:setBottomStatus("[Steal] error: " .. tostring(result))
            else
                ui:setBottomStatus("[Steal] " .. tostring(result))
            end
            task.wait(State.StealDelay)
        end
    end)
end

local attackThread
local function setAutoAttack(on)
    State.AutoAttack = on
    if attackThread then task.cancel(attackThread); attackThread = nil end
    if not on then return end
    if not Modules then
        warn("[AutoAttack] Modules not loaded")
        return
    end
    attackThread = task.spawn(function()
        while State.AutoAttack do
            local ok, result = pcall(function()
                return Modules:attackStep(State.AttackRange)
            end)
            print("[AutoAttack]", tostring(result))
            task.wait(1)
        end
    end)
end

print("[PlundererHub] Step 9: wiring UI tabs...")

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

local autoTab = ui:addTab("Auto", "⚡")
local stealSection = ui:addSection(autoTab, "Egg Stealing")
ui:addToggle(stealSection, "Auto Steal Field Eggs", false, function(v)
    setAutoSteal(v)
end)
ui:addSlider(stealSection, "Steal Delay (seconds)", 1, 10, 3, function(v)
    State.StealDelay = v
end)

local attackSection = ui:addSection(autoTab, "Combat")
ui:addToggle(attackSection, "Auto Attack Players", false, function(v)
    setAutoAttack(v)
end)
ui:addSlider(attackSection, "Attack Range (studs)", 5, 50, 20, function(v)
    State.AttackRange = v
end)

local sellTab = ui:addTab("Selling", "💰")
local sellSection = ui:addSection(sellTab, "Auto Sell")
ui:addToggle(sellSection, "Auto Sell (every 3s)", false, function(v)
    setAutoSell(v)
end)
ui:addButton(sellSection, "Sell Now", fireSellAll)

ui:setStatus("Ready", "idle")
ui:setBottomStatus("PlundererHub v1.1 loaded")

print("[PlundererHub] === READY ===")
print("[PlundererHub] 10 modules active")
