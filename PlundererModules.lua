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
-- EGG SNAPSHOT
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
                uid      = tostring(rec.NestId or ""),
                position = rec.BoundsCFrame.Position,
                cframe   = rec.BoundsCFrame,
                scale    = rec.NestScale or 1,
                category = rec.AssetCategory,
                rarity   = rec.Rarity,
                rarityNum= rec.RarityNumber or 0,
                area     = rec.AreaId or "Unknown",
            })
        end
    end
    return eggs
end

-- =========================================================
-- LIVE PLAYERS (for steal-from-players)
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
                        uid = tostring(uid),
                        category = pet.AssetCategory or "Unknown",
                        scale = pet.AssetScale or 1,
                        hasParasite = pet.HasParasite == true,
                    })
                end
            end
            table.insert(out, { userId = tonumber(entry.OwnerUserId), pets = pets, petCount = #pets })
        end
    end
    return out
end

-- =========================================================
-- SCAN FOR NEST PROMPTS
-- =========================================================
local function findNestPrompt(eggPos)
    local objFolder = workspace:FindFirstChild("__OBJECTS")
    if not objFolder then return nil end
    local areas = objFolder:FindFirstChild("Areas")
    if not areas then return nil end
    local guard = areas:FindFirstChild("GuardAreas")
    if not guard then return nil end

    local bestPrompt, bestDist = nil, math.huge
    for _, area in ipairs(guard:GetChildren()) do
        local nests = area:FindFirstChild("Nests")
        if nests then
            for _, nest in ipairs(nests:GetChildren()) do
                local nestModel = nest:FindFirstChild("Model")
                if nestModel then
                    local pp = nestModel.PrimaryPart or nestModel:FindFirstChildWhichIsA("BasePart", true)
                    if pp then
                        local d = (pp.Position - eggPos).Magnitude
                        if d < 15 then
                            for _, descendant in ipairs(nest:GetDescendants()) do
                                if descendant:IsA("ProximityPrompt") then
                                    if d < bestDist then
                                        bestPrompt, bestDist = descendant, d
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPrompt, bestDist
end

-- =========================================================
-- FAST MOVE (CFrame step)
-- =========================================================
local function fastMove(targetPos, timeout)
    timeout = timeout or 3
    local hrp = getHRP()
    if not hrp then return false end

    local start = tick()
    while tick() - start < timeout do
        hrp = getHRP()
        if not hrp then return false end
        local delta = targetPos - hrp.Position
        local dist = delta.Magnitude
        if dist < 3 then return true end
        local step = math.min(15, dist)
        hrp.CFrame = CFrame.new(hrp.Position + delta.Unit * step)
        hrp.AssemblyLinearVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
    return false
end

-- =========================================================
-- AUTO STEAL with filters
-- =========================================================
function Modules:autoStealStep(filters)
    filters = filters or {}
    local areaFilter = filters.area or "All"
    local rarityFilter = filters.rarity or "All"
    local nameFilter = filters.petName or "All"

    local hrp = getHRP()
    if not hrp then return "no character" end

    local eggs = self:getFieldEggs()
    if #eggs == 0 then return "no eggs in field" end

    -- Filter by area
    local filtered = eggs
    if areaFilter ~= "All" then
        local next = {}
        for _, e in ipairs(filtered) do
            if e.area == areaFilter or string.find(e.uid, areaFilter, 1, true) then
                table.insert(next, e)
            end
        end
        filtered = next
    end

    -- Filter by rarity
    if rarityFilter ~= "All" then
        local next = {}
        for _, e in ipairs(filtered) do
            if e.rarity == rarityFilter or tostring(e.rarityNum) == tostring(rarityFilter) then
                table.insert(next, e)
            end
        end
        filtered = next
    end

    -- Filter by name
    if nameFilter ~= "All" then
        local next = {}
        for _, e in ipairs(filtered) do
            if e.category == nameFilter then
                table.insert(next, e)
            end
        end
        filtered = next
    end

    if #filtered == 0 then return "no eggs match filters" end

    -- Sort by distance
    table.sort(filtered, function(a, b)
        return (a.position - hrp.Position).Magnitude < (b.position - hrp.Position).Magnitude
    end)

    local target = filtered[1]
    local dist = (target.position - hrp.Position).Magnitude

    -- Fast move to egg
    fastMove(target.position, 3)
    task.wait(0.15)

    -- Find and fire nest prompt if present
    local prompt, promptDist = findNestPrompt(target.position)
    if prompt and promptDist and promptDist < 12 then
        pcall(function() prompt:InputHoldBegin() end)
        task.wait(math.max(0.1, prompt.HoldDuration or 0.4))
        pcall(function() prompt:InputHoldEnd() end)
    end

    -- Wait for carry
    task.wait(0.4)

    -- Verify
    local eggsAfter = self:getFieldEggs()
    local stillThere = false
    for _, e in ipairs(eggsAfter) do
        if e.uid == target.uid then stillThere = true; break end
    end

    if not stillThere then
        return "stolen: " .. tostring(target.category or target.uid)
    end
    return "attempted: " .. tostring(target.category or target.uid)
end

-- =========================================================
-- AUTO ATTACK
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

    if not closest or closestDist > maxDistance then return "no target" end

    local tHrp = closest.Character:FindFirstChild("HumanoidRootPart")
    if tHrp then fastMove(tHrp.Position, 2) end

    for _ = 1, 3 do
        pcall(function() swing:FireServer() end)
        task.wait(0.15)
    end

    return "attacked " .. closest.Name
end

-- =========================================================
-- GET ALL PET NAMES (for filter dropdown)
-- =========================================================
function Modules:getPetNames()
    local assets = RS:FindFirstChild("Data") and RS.Data:FindFirstChild("Assets")
    if not assets then return {} end
    local ok, mod = pcall(require, assets)
    if not ok or type(mod) ~= "table" or not mod.Directory then return {} end
    local names = {}
    for _, entry in pairs(mod.Directory) do
        local name = entry.DisplayName or entry.Name
        if name then table.insert(names, name) end
    end
    table.sort(names)
    return names
end

-- =========================================================
-- GET ALL AREAS (for filter dropdown)
-- =========================================================
function Modules:getAreas()
    local objFolder = workspace:FindFirstChild("__OBJECTS")
    if not objFolder then return { "All" } end
    local areas = objFolder:FindFirstChild("Areas")
    if not areas then return { "All" } end
    local guard = areas:FindFirstChild("GuardAreas")
    if not guard then return { "All" } end
    local list = { "All" }
    for _, area in ipairs(guard:GetChildren()) do
        table.insert(list, area.Name)
    end
    table.sort(list)
    return list
end

return Modules
