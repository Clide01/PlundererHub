scriptkey = "keyless"
--https://api.redstoneguard.xyz/api/loader/7c9dae3a-bf19-4057-9e6c-1d8c852bd0b3/init
local ROUTES = {
    [107778070777162] = "https://raw.githubusercontent.com/Clide01/PlundererHub/refs/heads/main/PlundererHub.lua",
}

local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[PlundererLoader] No script for this game")
        return
    end

    scriptkey = "keyless"

    local ok, err = pcall(function()
        local body = game:HttpGet(url)
        if type(body) ~= "string" or #body == 0 then
            error("Empty response")
        end
        local fn = loadstring(body)
        if not fn then error("Compile failed") end
        fn()
    end)

    if not ok then
        warn("[PlundererLoader] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
