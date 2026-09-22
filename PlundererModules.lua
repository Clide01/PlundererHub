local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local RS           = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

local Modules = {}
Modules.__index = Modules

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
-- FIELD EGG READER
-- =========================================================
function Modules:getFieldEggs(filterCategory)
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
            local cat = rec.AssetCategory or "Unknown"
            if not filterCategory or filterCategory == "All" or filterCategory == cat then
                table.insert(eggs, {
                    uid      = tostring(rec.NestId or ""),
                    position = rec.BoundsCFrame.Position,
                    cframe   = rec.BoundsCFrame,
                    scale    = rec.NestScale or 1,
                    category = cat,
                })
            end
        end
    end
    return eggs
end

-- =========================================================
-- LIVE PLAYERS READER
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
-- LIST ALL UNIQUE EGG CATEGORIES CURRENTLY IN FIELD
-- =========================================================
function Modules:getEggCategories()
    local eggs = self:getFieldEggs()
    local seen = {}
    local list = { "All" }
    for _, e in ipairs(eggs) do
        if not seen[e.category] then
            seen[e.category] = true
            table.insert(list, e.category)
        end
    end
    table.sort(list, function(a, b)
        if a == "All" then return true end
        if b == "All" then return false end
        return a < b
    end)
    return list
end

-- =========================================================
-- TELEPORT-ASSIST MOVE
-- =========================================================
local function teleportNear(targetPos, offset)
    offset = offset or 5
    local hrp = getHRP()
    if not hrp then return false end
    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, offset, 0))
    return true
end

local function walkTo(targetPos, timeout)
    timeout = timeout or 6
    local hum = getHum()
    local hrp = getHRP()
    if not hum or not hrp then return false end

    local start = tick()
    while tick() - start < timeout do
        hrp = getHRP()
        if not hrp then return false end
        local dist = (targetPos - hrp.Position).Magnitude
        if dist < 5 then return true end
        pcall(function() hum:MoveTo(targetPos) end)
        task.wait(0.15)
    end
    return false
end

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
-- AUTO STEAL STEP
-- =========================================================
function Modules:autoStealStep(category)
    local hrp = getHRP()
    if not hrp then return "no character" end

    local eggs = self:getFieldEggs()
    if #eggs == 0 then return "no eggs in field" end

    local filtered = eggs
    if category and category ~= "All" then
        filtered = {}
        for _, e in ipairs(eggs) do
            if e.category == category then
                table.insert(filtered, e)
            end
        end
        if #filtered == 0 then
            return "no " .. category .. " eggs available"
        end
    end

    local target = getClosest(hrp.Position, filtered)
    if not target then return "no target" end

    -- Fast teleport to target
    teleportNear(target.position, 5)
    task.wait(0.3)

    -- Walk precisely onto the nest
    walkTo(target.position, 4)
    task.wait(0.8)

    -- Wait for FieldEggCarry event
    local carried = false
    local carryConn
    local net = getNetworking()
    if net then
        local carryEvent = net:FindFirstChild("RE/EggWorld/FieldEggCarry")
        if carryEvent then
            carryConn = carryEvent.OnClientEvent:Connect(function(payload)
                if type(payload) == "table" and payload.IsCarrying then
                    carried = true
                end
            end)
        end
    end

    -- Poll for 2 seconds
    local start = tick()
    while tick() - start < 2 and not carried do
        task.wait(0.1)
    end

    if carryConn then carryConn:Disconnect() end

    return carried and ("carried " .. target.category) or ("reached " .. target.category .. " (no carry)")
end

-- =========================================================
-- AUTO ATTACK STEP
-- =========================================================
function Modules:attackStep(maxDistance)
    maxDistance = maxDistance or 20
    local hrp = getHRP()
    if not hrp then return "no character" end

    local net = getNetworking()
    if not net then return "no networking" end
    local swing = net:FindFirstChild("RE/BatSwing/Trigger")
    if not swing then return "no bat remote" end

    local closest, closestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local tHrp = p.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                local d = (tHrp.Position - hrp.Position).Magnitude
                if d < closestDist then closest, closestDist = p, d end
            end
        end
    end

    if not closest or closestDist > maxDistance then return "no target in range" end

    local tHrp = closest.Character:FindFirstChild("HumanoidRootPart")
    if tHrp then
        teleportNear(tHrp.Position, 3)
        task.wait(0.2)
    end

    for _ = 1, 3 do
        pcall(function() swing:FireServer() end)
        task.wait(0.15)
    end

    return "attacked " .. closest.Name
end

-- =========================================================
-- STEAL FROM SPECIFIC USER
-- =========================================================
function Modules:stealFromPlayer(targetUserId)
    local plr = Players:GetPlayerByUserId(tonumber(targetUserId))
    if not plr or not plr.Character then return "player not in server" end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return "player has no HRP" end

    teleportNear(hrp.Position, 3)
    task.wait(0.3)

    local net = getNetworking()
    local swing = net and net:FindFirstChild("RE/BatSwing/Trigger")
    if not swing then return "no bat" end
    for _ = 1, 5 do
        pcall(function() swing:FireServer() end)
        task.wait(0.2)
    end
    return "attacked " .. plr.Name
end

return Modules
