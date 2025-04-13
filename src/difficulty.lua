local header = [[
--
--                                              88                                   88
--                     ,d                       88                                   88
--                     88                       88                                   88
--     ,adPPYba,     MM88MMM     ,adPPYYba,     88   ,d8       ,adPPYba,             88     88       88     ,adPPYYba,
--     I8[    ""       88        ""     `Y8     88 ,a8"       a8P_____88             88     88       88     ""     `Y8
--      `"Y8ba,        88        ,adPPPPP88     8888[         8PP"""""""             88     88       88     ,adPPPPP88
--     aa    ]8I       88,       88,    ,88     88`"Yba,      "8b,   ,aa     888     88     "8a,   ,a88     88,    ,88
--     `"YbbdP"'       "Y888     `"8bbdP"Y8     88   `Y8a      `"Ybbd8"'     888     88      `"YbbdP'Y8     `"8bbdP"Y8
--
--
-- This is the file that allows support for modded stakes.
-- Each entry is a mapping between the vanilla stake that is shown,
-- and the modded one meant to override for that stake.
--
-- You are free to modify this file as you wish.
-- If left untouched, this file does nothing and the standard vanilla checks are used.
--
-- Below are all stakes that can be used. Copy-paste the ID (after each colon)
-- within the quotes of the stake you wish to apply the modded stake to:
]]

--- Creates modded logic, storing it in a file for future access.
---@return table
local function make_new_stakes()
    local vanillas = {
        stake_white = "",
        stake_red = "",
        stake_green = "",
        stake_black = "",
        stake_blue = "",
        stake_purple = "",
        stake_orange = "",
        stake_gold = "",
    }

    local str = header
    local stakes = {}

    for k, v in pairs(G.P_STAKES) do
        stakes[#stakes + 1] = {v.order, k}
    end

    table.sort(stakes, function(x, y) return x[1] < y[1] end)

    for _, v in pairs(stakes) do
        local k = v[2]

        if not vanillas[k] then
            str = str .. "--     - " .. G.localization.descriptions.Stake[k].name .. ": " .. k .. "\n"
        end
    end

    local _, err = NFS.write(SMODS.Mods["Pingo"].path .. "/stake.lua", str .. "return " .. serialize(vanillas))

    if err then
        sendErrorMessage("Failed to write stake.lua: " .. err, "Pingo")
    end

    return vanillas
end

local stakes, err = SMODS.load_file("stake.lua", "Pingo")
return not err and type(stakes) == "function" and stakes() or make_new_stakes()
