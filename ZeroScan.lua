local RS = game:GetService("RS")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local BUF = {}
local function log(fmt, ...)
    local line = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt)
    table.insert(BUF, line)
    print(line)
end
local function sep(t) log(""); log("═══ " .. t .. " ═══") end

log("ZeroScan v1 · " .. os.date("%Y-%m-%d %H:%M:%S"))

-- A) Held pets — own character
sep("A) OWN CHARACTER CHILDREN")
if LP.Character then
    for _, c in ipairs(LP.Character:GetChildren()) do
        local attrs = ""
        for k, v in pairs(c:GetAttributes()) do
            attrs = attrs .. string.format(" [%s=%s]", k, tostring(v))
        end
        log("  [%s] %s%s", c.ClassName, c.Name, attrs)
    end
else
    log("  no character")
end

-- B) Held pets — other players
sep("B) OTHER PLAYERS' CHARACTERS")
for _, p in ipairs(Players:GetPlayers()) do
    if p == LP then continue end
    if not p.Character then continue end
    log("  --- %s ---", p.Name)
    for _, c in ipairs(p.Character:GetChildren()) do
        if c:IsA("Tool") or c:IsA("Model") then
            log("    [%s] %s", c.ClassName, c.Name)
        end
    end
end

-- C) Save structure
sep("C) SAVE DATA STRUCTURE")
local Save = require(RS.Shared.Save)
local save = Save.Get(LP, true) or Save.Get(LP) or Save.Get()
if save then
    for k, v in pairs(save) do
        log("  %s = %s", tostring(k), typeof(v))
    end
    if type(save.Inventory) == "table" then
        local n = 0
        for _ in pairs(save.Inventory) do n = n + 1 end
        log("  Inventory count: %d", n)
        local first = true
        for uid, rec in pairs(save.Inventory) do
            if first then
                first = false
                local AssetItems = require(RS.Shared.Util.AssetItems)
                local ok, item = pcall(AssetItems.Decode, rec)
                if ok and item then
                    log("  Sample item fields:")
                    for ik, iv in pairs(item) do
                        log("    %s = %s", tostring(ik), tostring(iv))
                    end
                end
            end
        end
    end
end

-- D) Treadmill scan
sep("D) TREADMILL CANDIDATES IN WORKSPACE")
local treadmillCount = 0
for _, d in ipairs(workspace:GetDescendants()) do
    local n = string.lower(d.Name)
    if string.find(n, "tread", 1, true) or string.find(n, "mill", 1, true) then
        treadmillCount = treadmillCount + 1
        if treadmillCount <= 10 then
            log("  [%s] %s", d.ClassName, d:GetFullName())
            if d:IsA("BasePart") then
                log("    pos: %s", tostring(d.Position))
                for _, child in ipairs(d:GetChildren()) do
                    if child:IsA("ProximityPrompt") then
                        log("    prompt: %s | action=%q object=%q", child.Name, child.ActionText, child.ObjectText)
                    end
                end
            end
        end
    end
end
log("  Total treadmill-named instances: %d", treadmillCount)

-- E) Shrine prompt check
sep("E) SHRINE PROMPT")
local spp = workspace:FindFirstChild("SmartPromptPart")
if spp then
    local prompt = spp:FindFirstChild("CarryAreaEgg")
    if prompt then
        log("  found: %s", prompt:GetFullName())
        log("  Enabled: %s | HoldDuration: %s | MaxDist: %s",
            tostring(prompt.Enabled), tostring(prompt.HoldDuration), tostring(prompt.MaxActivationDistance))
    end
end

-- F) Egg counts by area
sep("F) LIVE EGGS BY AREA")
local root = workspace:FindFirstChild("__OBJECTS")
    and workspace.__OBJECTS:FindFirstChild("Areas")
    and workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")
if root then
    for _, area in ipairs(root:GetChildren()) do
        local nests = area:FindFirstChild("Nests")
        if nests then
            local count = 0
            for _, nest in ipairs(nests:GetChildren()) do
                local m = nest:FindFirstChild("Model")
                if m and m:IsA("Model") then count = count + 1 end
            end
            log("  %s: %d eggs", area.Name, count)
        end
    end
end

-- G) Character scripts
sep("G) CHARACTER SCRIPTS")
if LP.Character then
    for _, c in ipairs(LP.Character:GetDescendants()) do
        if c:IsA("LocalScript") or c:IsA("Script") then
            log("  [%s] %s", c.ClassName, c.Name)
        end
    end
end

-- Write file
sep("WRITING")
local fname = "zerroscan_" .. os.time() .. ".txt"
local content = table.concat(BUF, "\n")
local ok, err = pcall(function()
    if writefile then writefile(fname, content) else error("no writefile") end
end)
if ok then
    log("  ✓ File: %s (%d bytes)", fname, #content)
    log("  Find it in your executor workspace folder")
else
    log("  ✗ writefile failed: %s", tostring(err))
    log("  Dumping to console:")
    for _, l in ipairs(BUF) do print(l) end
end
