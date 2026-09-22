local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local RS           = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

local Modules = {}
Modules.__index = Modules

-- =========================================================
-- INTERNAL HELPERS
-- =========================================================
local function getNetworking()
    return RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
end

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- =========================================================
-- EGG SNAPSHOT READER
-- =========================================================
function Modules:getFieldEggs()
    local net = getNetworking()
    if not net then return {} end
    local rf = net:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
    if not rf then return {} end

    local ok, res = pcall(function() return rf:InvokeServer() end)
    if not ok or type(res) ~= "table" or type(res.Records) ~= "table" then
        return {}
    end

    local eggs = {}
    for _, rec in pairs(res.Records) do
        if type(rec) == "table" and rec.State == "Slot" and rec.BoundsCFrame then
            table.insert(eggs, {
                uid       = tostring(rec.NestId or ""),
                position  = rec.BoundsCFrame.Position,
                cframe    = rec.BoundsCFrame,
                scale     = rec.NestScale or 1,
                category  = rec.AssetCategory,
                rarity    = rec.Rarity,
            })
        end
    end
    return eggs
end

-- =========================================================
-- PLAYER SNAPSHOT READER
-- =========================================================
function Modules:getLivePlayers()
    local net = getNetworking()
    if not net then return {} end
    local rf = net:FindFirstChild("RF/EggWorld/AskLiveSnapshot")
    if not rf then return {} end

    local ok, res = pcall(function() return rf:InvokeServer() end)
    if not ok or type(res) ~= "table" then return {} end

    local out = {}
    for _, entry in ipairs(res) do
        if type(entry) == "table" and entry.OwnerUserId then
            local pets = {}
            if type(entry.Records) == "table" then
                for uid, pet in pairs(entry.Records) do
                    table.insert(pets, {
                        uid      = tostring(uid),
                        category = pet.AssetCategory or "Unknown",
                        scale    = pet.AssetScale or 1,
                        hasParasite = pet.HasParasite == true,
                    })
                end
            end
            table.insert(out, {
                userId = tonumber(entry.OwnerUserId),
                pets = pets,
                petCount = #pets,
            })
        end
    end
    return out
end

-- =========================================================
-- DISTANCE UTILS
-- =========================================================
local function getClosest(originPos, list)
    if not originPos or #list == 0 then return nil end
    local best, bestDist = nil, math.huge
    for _, item in ipairs(list) do
        if item.position then
            local d = (item.position - originPos).Magnitude
            if d < bestDist then best, bestDist = item, d end
        end
    end
    return best, bestDist
end

-- =========================================================
-- MOVE: WALK-TO with MoveTo
-- =========================================================
function Modules:moveTo(targetPos, timeout)
    timeout = timeout or 8
    local hum = getHum()
    local hrp = getHRP()
    if not hum or not hrp then return false end

    local start = tick()
    while tick() - start < timeout do
        hrp = getHRP()
        if not hrp then return false end
        local dist = (targetPos - hrp.Position).Magnitude
        if dist < 4 then return true end

        pcall(function() hum:MoveTo(targetPos) end)
        task.wait(0.15)
    end
    return false
end

-- =========================================================
-- MODULE: AUTO STEAL FIELD EGGS
-- =========================================================
function Modules:autoStealStep(areaFilter, minRarity)
    local hrp = getHRP()
    if not hrp then return "no character" end

    local eggs = self:getFieldEggs()
    if #eggs == 0 then return "no eggs in field" end

    -- Filter by area if needed (uid contains area)
    local filtered = eggs
    if areaFilter and areaFilter ~= "All" then
        filtered = {}
        for _, e in ipairs(eggs) do
            if string.find(string.lower(e.uid), string.lower(areaFilter), 1, true) then
                table.insert(filtered, e)
            end
        end
        if #filtered == 0 then return "no eggs in " .. areaFilter end
    end

    local target = getClosest(hrp.Position, filtered)
    if not target then return "no target" end

    local ok = self:moveTo(target.position, 6)
    if not ok then return "could not reach" end

    -- Wait for server to detect carry
    task.wait(1.5)
    return "stolen: " .. tostring(target.category or target.uid)
end

-- =========================================================
-- MODULE: AUTO ATTACK NEARBY PLAYERS
-- =========================================================
local function getBatSwing()
    local net = getNetworking()
    return net and net:FindFirstChild("RE/BatSwing/Trigger")
end

function Modules:attackStep(maxDistance)
    maxDistance = maxDistance or 20
    local hrp = getHRP()
    if not hrp then return "no character" end

    local swing = getBatSwing()
    if not swing then return "no bat swing remote" end

    -- Find closest other player within range
    local closest, closestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local tHrp = p.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                local d = (tHrp.Position - hrp.Position).Magnitude
                if d < closestDist then
                    closest, closestDist = p, d
                end
            end
        end
    end

    if not closest or closestDist > maxDistance then
        return "no target in range"
    end

    -- Walk toward them
    local tHrp = closest.Character:FindFirstChild("HumanoidRootPart")
    if tHrp then
        self:moveTo(tHrp.Position, 2)
    end

    -- Swing bat 3 times
    for _ = 1, 3 do
        pcall(function() swing:FireServer() end)
        task.wait(0.15)
    end

    return "attacked: " .. closest.Name .. " (" .. math.floor(closestDist) .. "m)"
end

-- =========================================================
-- MODULE: AUTO TREADMILL
-- =========================================================
local treadmillConn

function Modules:setAutoTreadmill(on)
    local net = getNetworking()
    if not net then return end

    if treadmillConn then
        treadmillConn:Disconnect()
        treadmillConn = nil
    end

    if not on then return end

    local speedGained = net:FindFirstChild("RE/Treadmill/SpeedGained")
    local renderState = net:FindFirstChild("RE/Treadmill/RenderStateShifted")
    local beltShifted = net:FindFirstChild("RE/Treadmill/AssignedBeltShifted")
    local conns = {}

    if speedGained then
        table.insert(conns, speedGained.OnClientEvent:Connect(function(speed, source)
            if source == "Treadmill" then
                print(("[AutoTreadmill] +%d speed"):format(speed))
            end
        end))
    end
    if beltShifted then
        table.insert(conns, beltShifted.OnClientEvent:Connect(function(treadmillName, tier)
            if treadmillName == "FlameTreadmill" then
                print(("[AutoTreadmill] On %s tier %s"):format(treadmillName, tostring(tier)))
            end
        end))
    end

    -- Fire base remote to request placement (game auto-sends belt shift)
    local rf = net:FindFirstChild("RF/Treadmill/AskWearStill")
    if rf then
        pcall(function() rf:InvokeServer() end)
    end

    treadmillConn = {
        Disconnect = function()
            for _, c in ipairs(conns) do c:Disconnect() end
        end,
    }
end

-- =========================================================
-- MODULE: STEAL FROM SPECIFIC PLAYER
-- =========================================================
function Modules:stealFromPlayer(targetUserId)
    local players = self:getLivePlayers()
    local target = nil
    for _, p in ipairs(players) do
        if p.userId == targetUserId then target = p; break end
    end
    if not target then return "player not found in snapshot" end
    if target.petCount == 0 then return "player has no pets" end

    local plr = Players:GetPlayerByUserId(targetUserId)
    if not plr or not plr.Character then return "player not in server" end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return "player has no HRP" end

    -- Walk to them
    self:moveTo(hrp.Position, 5)
    task.wait(0.3)

    -- Swing bat
    local swing = getBatSwing()
    if not swing then return "no bat" end
    for _ = 1, 5 do
        pcall(function() swing:FireServer() end)
        task.wait(0.2)
    end

    return "attacked " .. plr.Name
end

return Modules
