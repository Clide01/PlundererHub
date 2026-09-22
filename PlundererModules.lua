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
-- FIELD EGG READER (still used for the category list)
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
-- LIVE PLAYERS
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
-- SMART PROMPT FINDER
-- =========================================================
local function findSmartPrompt()
    local found = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") and parent.Name == "SmartPromptPart" then
                if obj.ActionText == "Steal" and obj.Enabled then
                    table.insert(found, {
                        prompt = obj,
                        part   = parent,
                        position = parent.Position,
                    })
                end
            end
        end
    end
    return found
end

local function getClosestPrompt(originPos, prompts)
    if not originPos or #prompts == 0 then return nil end
    local best, bestDist = nil, math.huge
    for _, p in ipairs(prompts) do
        local d = (p.position - originPos).Magnitude
        if d < bestDist then
            best, bestDist = p, d
        end
    end
    return best, bestDist
end

local function triggerPrompt(prompt)
    if not prompt or not prompt.Enabled then return false end
    local okB = pcall(function() prompt:InputHoldBegin() end)
    if not okB then return false end
    task.wait(math.max(0.5, prompt.HoldDuration or 1.2) + 0.15)
    pcall(function() prompt:InputHoldEnd() end)
    return true
end

-- =========================================================
-- WAIT FOR SHARED SMART PROMPT TO APPEAR
-- The game spawns SmartPromptPart when the player is near
-- a stealable egg, and removes it when they leave.
-- =========================================================
local function waitForSmartPrompt(timeout)
    timeout = timeout or 3
    local t0 = tick()

    while tick() - t0 < timeout do
        -- Check if it already exists
        local existing = workspace:FindFirstChild("SmartPromptPart")
        if existing and existing:IsA("BasePart") then
            local prompt = existing:FindFirstChildOfClass("ProximityPrompt")
            if prompt and prompt.Enabled and prompt.ActionText == "Steal" then
                return prompt
            end
        end
        task.wait(0.1)
    end
    return nil
end

-- =========================================================
-- FIND SMART PROMPTS ANYWHERE (fallback for nested parents)
-- =========================================================
local function findSmartPromptAnywhere()
    local found = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") and string.find(parent.Name, "SmartPrompt", 1, true) then
                if obj.ActionText == "Steal" and obj.Enabled then
                    table.insert(found, {
                        prompt = obj,
                        part   = parent,
                        position = parent.Position,
                    })
                end
            end
        end
    end
    return found
end

-- =========================================================
-- AUTO STEAL STEP (revised)
-- =========================================================
print("[AutoSteal] Cycle start | SafePosition:", tostring(safePosition))
function Modules:autoStealStep(category, safePosition)
    local hrp = getHRP()
    if not hrp then return "no character" end

    -- 1) Try to find an existing SmartPromptPart
    local prompts = findSmartPromptAnywhere()

    -- 2) If none exist, teleport to the closest egg in the snapshot
    if #prompts == 0 then
        local eggs = self:getFieldEggs()
        if #eggs == 0 then
            return "no eggs in field"
        end

        -- Filter by category
        local filtered = eggs
        if category and category ~= "All" then
            filtered = {}
            for _, e in ipairs(eggs) do
                if e.category == category then
                    table.insert(filtered, e)
                end
            end
            if #filtered == 0 then
                return "no " .. category .. " eggs"
            end
        end

        -- Find closest egg
        local closestEgg, closestDist = nil, math.huge
        for _, e in ipairs(filtered) do
            local d = (e.position - hrp.Position).Magnitude
            if d < closestDist then
                closestEgg, closestDist = e, d
            end
        end
        if not closestEgg then return "no egg target" end

        -- Teleport onto the egg
        hrp.CFrame = CFrame.new(closestEgg.position + Vector3.new(0, 3, 0))
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
        task.wait(0.35)

        -- Wait for SmartPromptPart to spawn (server-side logic)
        local prompt = waitForSmartPrompt(3)
        if not prompt then
            -- Return to safe position and report failure
            if safePosition then
                local newHrp = getHRP()
                if newHrp then
                    newHrp.CFrame = CFrame.new(safePosition + Vector3.new(0, 3, 0))
                end
            end
            return "no prompt spawned at " .. closestEgg.category
        end

        -- Fire the newly spawned prompt
        local okB = pcall(function() prompt:InputHoldBegin() end)
        task.wait(math.max(0.5, prompt.HoldDuration or 1.2) + 0.15)
        pcall(function() prompt:InputHoldEnd() end)
        task.wait(0.5)

        -- Wait for carry confirmation
        local carried = false
        local net = getNetworking()
        local carryConn
        if net then
            local ev = net:FindFirstChild("RE/EggWorld/FieldEggCarry")
            if ev then
                carryConn = ev.OnClientEvent:Connect(function(payload)
                    if type(payload) == "table" and payload.IsCarrying then
                        carried = true
                    end
                end)
            end
        end

        local t0 = tick()
        while tick() - t0 < 2 and not carried do
            task.wait(0.1)
        end
        if carryConn then carryConn:Disconnect() end

        -- Return to safe position
        if safePosition then
            local newHrp = getHRP()
            if newHrp then
                newHrp.CFrame = CFrame.new(safePosition + Vector3.new(0, 3, 0))
                task.wait(0.35)
            end
        end

        return carried
            and ("stole " .. closestEgg.category)
            or  ("no confirm at " .. closestEgg.category)
    end

    -- 3) Prompts exist — pick closest and fire
    local closest, closestDist = nil, math.huge
    for _, p in ipairs(prompts) do
        local d = (p.position - hrp.Position).Magnitude
        if d < closestDist then
            closest, closestDist = p, d
        end
    end
    if not closest then return "no prompt reachable" end

    -- Teleport to prompt and fire
    hrp.CFrame = CFrame.new(closest.position + Vector3.new(0, 3, 0))
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    task.wait(0.25)

    local okB = pcall(function() closest.prompt:InputHoldBegin() end)
    task.wait(math.max(0.5, closest.prompt.HoldDuration or 1.2) + 0.15)
    pcall(function() closest.prompt:InputHoldEnd() end)
    task.wait(0.5)

    -- Wait for carry confirmation
    local carried = false
    local net = getNetworking()
    local carryConn
    if net then
        local ev = net:FindFirstChild("RE/EggWorld/FieldEggCarry")
        if ev then
            carryConn = ev.OnClientEvent:Connect(function(payload)
                if type(payload) == "table" and payload.IsCarrying then
                    carried = true
                end
            end)
        end
    end

    local t0 = tick()
    while tick() - t0 < 2 and not carried do
        task.wait(0.1)
    end
    if carryConn then carryConn:Disconnect() end

    -- Return to safe
    if safePosition then
        local newHrp = getHRP()
        if newHrp then
            newHrp.CFrame = CFrame.new(safePosition + Vector3.new(0, 3, 0))
            task.wait(0.35)
        end
    end

    return carried
        and ("stole at " .. string.format("%.1f", closestDist) .. "m")
        or  ("no confirm at " .. string.format("%.1f", closestDist) .. "m")
end

-- =========================================================
-- AUTO ATTACK
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
        hrp.CFrame = CFrame.new(tHrp.Position + Vector3.new(0, 3, 0))
        task.wait(0.2)
    end

    for _ = 1, 3 do
        pcall(function() swing:FireServer() end)
        task.wait(0.15)
    end

    return "attacked " .. closest.Name
end

function Modules:stealFromPlayer(targetUserId)
    local plr = Players:GetPlayerByUserId(tonumber(targetUserId))
    if not plr or not plr.Character then return "player not in server" end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return "player has no HRP" end

    local myHrp = getHRP()
    if myHrp then
        myHrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
        task.wait(0.3)
    end

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
