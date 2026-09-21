scriptkey = "keyless"

local ROUTES = {
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/51137926-b4c0-4e30-b6d3-a9d941c82860/init",
}

local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[FusionLoader] No script for this game")
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
        warn("[FusionLoader] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
