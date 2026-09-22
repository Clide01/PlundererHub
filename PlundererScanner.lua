local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer

local BUFFER = {}
local function log(fmt, ...)
    local line = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    table.insert(BUFFER, line)
    print(line)
end
local function sep(t) log(""); log("═══ " .. t .. " ═══") end

log("PlundererHub Deep Scanner")
log("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
log("Player: " .. LP.Name)

local Networking = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")

-- A) Probe EggWorld functions
sep("A) EGGWORLD STATE")
if Networking then
    local snap = Networking:FindFirstChild("RF/EggWorld/AskLiveSnapshot")
    if snap then
        local ok, res = pcall(function() return snap:InvokeServer() end)
        log("AskLiveSnapshot ok: %s | type: %s", tostring(ok), typeof(res))
        if type(res) == "table" then
            for k, v in pairs(res) do
                log("  [%s] = %s", tostring(k), typeof(v))
            end
        end
    end

    local field = Networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
    if field then
        local ok, res = pcall(function() return field:InvokeServer() end)
        log("AskFieldEggSnapshot ok: %s | type: %s", tostring(ok), typeof(res))
        if type(res) == "table" then
            for k, v in pairs(res) do
                log("  [%s] = %s", tostring(k), typeof(v))
            end
        end
    end
end

-- B) Character state
sep("B) CHARACTER")
local char = LP.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
if hum then
    log("WalkSpeed: %d", hum.WalkSpeed)
    log("Health: %d/%d", hum.Health, hum.MaxHealth)
    for _, name in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
        local obj = hum:FindFirstChild(name)
        if obj then log("%s = %.2f", name, obj.Value) end
    end
end

-- C) Other players holding pets
sep("C) OTHER PLAYERS HELD ITEMS")
for _, p in ipairs(Players:GetPlayers()) do
    if p == LP then continue end
    local c = p.Character
    if not c then continue end
    local held = {}
    for _, child in ipairs(c:GetChildren()) do
        if child:IsA("Tool") or child:IsA("Model") then
            table.insert(held, child.ClassName .. ":" .. child.Name)
        end
    end
    if #held > 0 then log("%s → %s", p.Name, table.concat(held, ", ")) end
end

-- D) Treadmill remotes inventory
sep("D) TREADMILL REMOTES")
if Networking then
    for _, c in ipairs(Networking:GetChildren()) do
        if string.find(c.Name, "Treadmill", 1, true) then
            log("  [%s] %s", c.ClassName, c.Name)
        end
    end
end

-- E) Bat / attack remotes
sep("E) BAT / ATTACK REMOTES")
if Networking then
    for _, c in ipairs(Networking:GetChildren()) do
        if string.find(c.Name, "BatSwing", 1, true)
           or string.find(c.Name, "ToolTrigger", 1, true)
           or string.find(c.Name, "FieldBat", 1, true) then
            log("  [%s] %s", c.ClassName, c.Name)
        end
    end
end

-- F) Upgrade prompts
sep("F) UPGRADE MACHINES")
local machines = workspace:FindFirstChild("__OBJECTS") and workspace.__OBJECTS:FindFirstChild("Machines")
if machines then
    for _, m in ipairs(machines:GetChildren()) do
        log("%s", m:GetFullName())
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                log("  Prompt: Action=%q Object=%q MaxDist=%.1f", d.ActionText, d.ObjectText, d.MaxActivationDistance)
            end
        end
    end
end

-- G) Index / Assets module structure
sep("G) ASSETS MODULE")
local assets = RS:FindFirstChild("Data") and RS.Data:FindFirstChild("Assets")
if assets then
    local ok, mod = pcall(require, assets)
    if ok and type(mod) == "table" then
        local keys = {}
        for k in pairs(mod) do table.insert(keys, tostring(k)) end
        table.sort(keys)
        log("keys: %s", table.concat(keys, ", "):sub(1, 300))
        if mod.Directory then
            local count, sample = 0, {}
            for k, v in pairs(mod.Directory) do
                count = count + 1
                if #sample < 3 then
                    table.insert(sample, tostring(k) .. " => " .. (v.DisplayName or v.Name or "?"))
                end
            end
            log("Directory: %d entries", count)
            for _, s in ipairs(sample) do log("  %s", s) end
        end
    end
end

-- Write file
sep("WRITE")
local fileName = string.format("plundererhub_deepscan_%d.txt", os.time())
local content = table.concat(BUFFER, "\n")
local ok = pcall(function() writefile(fileName, content) end)
if ok then
    log("✓ %s (%d bytes)", fileName, #content)
else
    log("writefile unavailable — copy from console")
end
