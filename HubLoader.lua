

local ROUTES = {
    -- Steal An Egg
    [107778070777162] = "https://luasnapper.xyz/files/loaders/ec7cea9c6d4640d7837d8bdbb7077cd9.lua",
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

loadScriptForPlace()
