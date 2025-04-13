local header = [[
--
--     88                                     88                            88
--     88                                     ""                            88
--     88                                                                   88
--     88      ,adPPYba,       ,adPPYb,d8     88      ,adPPYba,             88     88       88     ,adPPYYba,
--     88     a8"     "8a     a8"    `Y88     88     a8"     ""             88     88       88     ""     `Y8
--     88     8b       d8     8b       88     88     8b                     88     88       88     ,adPPPPP88
--     88     "8a,   ,a8"     "8a,   ,d88     88     "8a,   ,aa     888     88     "8a,   ,a88     88,    ,88
--     88      `"YbbdP"'       `"YbbdP"Y8     88      `"Ybbd8"'     888     88      `"YbbdP'Y8     `"8bbdP"Y8
--                             aa,    ,88
--                              "Y8bbdP"
--
--
-- This is the file containing your modded checks.
-- Each entry is a mapping between a vanilla check, and a modded one.
-- This is also what is shown in-game when you hover over a locked modded item.
--
-- You are free to modify this file to manipulate the unlock conditions,
-- such as moving all modded legendaries behind c_soul (The Soul).
--
-- If a modded check is placed behind multiple checks,
-- only one is shown in-game but both of them will unlock the modded item.
--
-- Every string consists of 3 parts, separated by underscores:
--     1. The general type of item. Here are the base game examples relevant:
--         - c_ - Consumable, this includes Tarots and Spectrals
--         - j_ - Joker
--         - p_ - Booster Packs
--         - v_ - Voucher
--     2. The mod that it comes from, or nothing if it's from the base game.
--     3. The ID of the item.
--
-- It is recommended to only cut and paste within this file instead of adding new IDs,
-- which also decreases the chance of introducing typos. If you have added new mods,
-- delete this file to force the mod to regenerate a new set to include the new IDs.
]]

--- Gets the random table that is also the shortest in length.
---@param tbl table?
---@param center SMODS.Center
---@param p table
---@return table?
local function pseudorandom_smallest_table(tbl, center, p)
    if not tbl then
        return nil
    end

    local smallest_groups = {}
    local same_rarity = {}
    local min = 1 / 0

    for k, v in pairs(tbl) do
        if min > #v then
            smallest_groups = {}
            min = #v
        end

        if min == #v then
            smallest_groups[k] = v
        end
    end

    local rarity = center["rarity"]

    if rarity then
        for k, v in pairs(smallest_groups) do
            if p[k].rarity == rarity then
                same_rarity[#same_rarity + 1] = v
            end
        end
    end

    local ret, _ = pseudorandom_element(next(same_rarity) and same_rarity or smallest_groups)
    return ret
end

--- Fills the provided table with entries from the other table.
---@param data table
---@param p table
local function populate(data, p)
    for _, v in pairs(p) do
        if v.set and not v.original_mod then
            local tbl = data[v.set] or {}
            local key = tbl[v.key] or {}
            tbl[v.key] = key
            data[v.set] = tbl
        end
    end

    -- Custom Decks cannot be played.
    -- Unenhanced and enhanced playing cards are simply not checks.
    -- Editions are currently not supported by the randomizer.
    -- Tags aren't permanent checks.
    local unsupported_sets = {Back = true, Default = true, Enhanced = true, Edition = true, Tag = true}

    -- Locking these checks will crash the game.
    local unsupported_keys = {sleeve_casl_none = true}

    for k, _ in pairs(unsupported_sets) do
        data[k] = nil
    end

    for _, v in pairs(p) do
        if v.original_mod and
            v.original_mod.id ~= "Rando" and
            v.set and not
            unsupported_sets[v.set] and not
            unsupported_keys[v.key] then
            local tbl = data[v.set]
            local key = pseudorandom_smallest_table(tbl or pseudorandom_element(data), v, p)

            if key then
                key[#key + 1] = v.key
            end
        end
    end
end

--- Creates modded logic, storing it in a file for future access.
---@return table
local function make_new_logic()
    local builder, array = {}, {}
    populate(builder, G.P_TAGS)
    populate(builder, G.P_CENTERS)

    for _, tbl in pairs(builder) do
        for k, v in pairs(tbl) do
            if next(v) then
                array[k] = v
            end
        end
    end

    local _, err = NFS.write(SMODS.Mods["Pingo"].path .. "/logic.lua", header .. "return " .. serialize(array))

    if err then
        sendErrorMessage("Failed to write logic.lua: " .. err, "Pingo")
    end

    return array
end

local logic, err = SMODS.load_file("logic.lua", "Pingo")
return not err and type(logic) == "function" and logic() or make_new_logic()
