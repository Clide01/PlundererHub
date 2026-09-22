scriptkey = "keyless"

local ROUTES = {
    [107778070777162] = "PASTE_YOUR_REDSTONEGUARD_URL_HERE",
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
