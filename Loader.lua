local HttpGet = game:HttpGet

local ROUTES = {
    -- Steal An Egg
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/e09ad35e-e8be-4066-8592-9b79bf2666cb/init",
}

local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[PlundererHub] No script for this game (PlaceId: " .. tostring(game.PlaceId) .. ")")
        return
    end

    local ok, err = pcall(function()
        loadstring(HttpGet(url))()
    end)

    if not ok then
        warn("[PlundererHub] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
