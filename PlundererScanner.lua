local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local BUFFER = {}
local function log(fmt, ...)
    local line = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    table.insert(BUFFER, line)
    print(line)
end

local function sep(t) log(""); log("═══ " .. t .. " ═══") end

log("PlundererHub Action Scanner")
log("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))

local Networking = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
if not Networking then
    warn("Networking folder missing")
    return
end

-- ═══════════════════════════════════════════════════════════
-- HOOK ALL MATCHING REMOTES
-- ═══════════════════════════════════════════════════════════
local captures = {}

local function serialize(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    local t = typeof(v)
    if t == "Instance" then
        return string.format("<%s:%s>", v.ClassName, v.Name)
    elseif t == "table" then
        local parts = {}
        for k, vv in pairs(v) do
            table.insert(parts, tostring(k) .. "=" .. serialize(vv, depth + 1))
        end
        return "{" .. table.concat(parts, ", "):sub(1, 300) .. "}"
    elseif t == "string" then
        return string.format("%q", v:sub(1, 100))
    else
        return tostring(v)
    end
end

local conns = {}
local function hook(name, label)
    local remote = Networking:FindFirstChild(name)
    if not remote then
        log("  MISSING: %s", name)
        return
    end
    if remote:IsA("RemoteEvent") then
        local c = remote.OnClientEvent:Connect(function(...)
            local args = { ... }
            local parts = {}
            for _, v in ipairs(args) do
                table.insert(parts, serialize(v))
            end
            local line = string.format("[%s] IN: %s", label, table.concat(parts, " | "))
            table.insert(captures, line)
            log(line)
        end)
        table.insert(conns, c)
    end
end

sep("HOOKING REMOTES")

-- Field egg flow
hook("RE/EggWorld/FieldEggShifted",   "FieldEggShifted")
hook("RE/EggWorld/FieldEggBatchShifted", "FieldEggBatch")
hook("RE/EggWorld/FieldEggCarry",     "FieldEggCarry")
hook("RE/EggWorld/OwnerShifted",      "OwnerShifted")
hook("RE/EggWorld/OwnerDropped",      "OwnerDropped")
hook("RE/EggWorld/FieldEggGone",      "FieldEggGone")
hook("RE/EggWorld/FieldEggCycleCountdown", "CycleCountdown")

-- Attack flow
hook("RE/BatSwing/Trigger",           "BatSwing")
hook("RE/ToolTrigger/Trigger",        "ToolTrigger")

-- Treadmill flow
hook("RE/Treadmill/SpeedGained",      "SpeedGained")
hook("RE/Treadmill/RenderStateShifted","RenderState")
hook("RE/Treadmill/AssignedBeltShifted","BeltShifted")

-- Level up / upgrade notifications
hook("RE/Payouts/Shower",             "Payout")
hook("RE/Toasts/Line",                "Toast")
hook("RE/RewardScreen/Show",          "Reward")
hook("RE/ChatFeed/ShowPlain",         "ChatPlain")

sep("READY — ACT IN-GAME")
log("Perform these actions over 120 seconds:")
log("  1. Walk to the shrine area")
log("  2. Steal a field egg (get close, hold E)")
log("  3. Swing your bat (equip bat, click)")
log("  4. Walk onto the treadmill")
log("  5. Do anything that causes an upgrade popup")
log("")
log("Waiting 120 seconds...")

task.wait(120)

for _, c in ipairs(conns) do c:Disconnect() end

sep("CAPTURED EVENTS")
if #captures == 0 then
    log("  (none captured — try again, act more)")
else
    for i, c in ipairs(captures) do
        log("  [%d] %s", i, c)
    end
end

-- ═══════════════════════════════════════════════════════════
-- CALL REMOTE FUNCTIONS WITH NIL TO SEE WHAT THEY RETURN
-- ═══════════════════════════════════════════════════════════
sep("PROBING RF ARGUMENTS")

local testRF = {
    "RF/EggWorld/AskFieldEggSnapshot",
    "RF/EggWorld/AskFieldEggCarry",
    "RF/EggWorld/AskFieldEggDrop",
    "RF/EggWorld/AskLiveSnapshot",
    "RF/EggWorld/AskPlaceEgg",
    "RF/Haul/FetchAutoSell",
    "RF/Haul/FetchWearBestStatus",
    "RF/PenRoster/AskLiveSnapshot",
    "RF/Treadmill/AskRenderSnapshot",
}

for _, name in ipairs(testRF) do
    local remote = Networking:FindFirstChild(name)
    if remote then
        local ok, res = pcall(function() return remote:InvokeServer() end)
        log("[%s]", name)
        log("  ok: %s", tostring(ok))
        log("  type: %s", typeof(res))
        if type(res) == "table" then
            for k, v in pairs(res) do
                log("  [%s] = %s", tostring(k), serialize(v))
            end
        else
            log("  value: %s", serialize(res))
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- WRITE FILE
-- ═══════════════════════════════════════════════════════════
sep("WRITE")

local fileName = string.format("plundererhub_action_%d.txt", os.time())
local content = table.concat(BUFFER, "\n")
local ok = pcall(function() writefile(fileName, content) end)
if ok then
    log("✓ %s (%d bytes)", fileName, #content)
else
    log("writefile unavailable — copy from console")
end
