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
        if
