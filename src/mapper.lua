--- Gets the random table that is also the shortest in length.
---@param tbl table?
---@param center SMODS.Center
---@param p table
---@return table?
local function pseudorandom_smallest_table(tbl, center, p)
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
        if v.set and not
            unsupported_sets[v.set] and not
            unsupported_keys[v.key] and
            v.original_mod then
            local tbl = data[v.set]
            local key = pseudorandom_smallest_table(tbl or pseudorandom_element(data), v, p)
            key[#key + 1] = v.key
        end
    end
end

--- Creates modded logic, storing it in a file for future access.
---@return table
local function make_new_checks()
    local builder, array = {}, {}
    populate(builder, G.P_TAGS)
    populate(builder, G.P_CENTERS)

    local function TableConcat(t1, t2)
        for i = 1, #t2 do
            t1[#t1 + 1] = t2[i]
        end

        return t1
    end

    for _, tbl in pairs(builder) do
        for k, v in pairs(tbl) do
            if next(v) then
                array[k] = v
                -- array["v_nacho_tong"] = TableConcat(array["v_nacho_tong"] or {}, v)
            end
        end
    end

    local _, err = NFS.write(SMODS.Mods["Pingo"].path .. "/logic.lua", "return " .. serialize(array))

    if err then
        sendErrorMessage("Failed to write checks.lua: " .. err, "Pingo")
    end

    return array
end

local checks, err = SMODS.load_file("logic.lua", "Pingo")
return not err and type(checks) == "function" and checks() or make_new_checks()
