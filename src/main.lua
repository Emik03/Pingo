SMODS.Atlas({
    key = "modicon",
    path = "modicon.png",
    px = 32,
    py = 32,
})

local notify_unlock = assert(SMODS.load_file("src/notify.lua", "Pingo"))()

local orig_unapply_to_run = Card.unapply_to_run

if orig_unapply_to_run then
    function Card:unapply_to_run(...)
        if G.hand then
            orig_unapply_to_run(self, ...)
        end
    end
end

--- Removes the debuff status from the given card.
---@param set string
---@param key string
local function buff(set, key)
    local g = G[set]

    if not g or not g.cards then
        return
    end

    for _, v in pairs(g.cards) do
        if v and type(v) == "table" and v.config.center.key == key then
            v:set_debuff(false)
        end
    end
end

-- Finds the localized name of the given center.
---@param center SMODS.Center
---@return string
local function find_loc_name(center)
    --- Traverses all values of localization descriptions to find the object matching the key provided.
    ---@param key string
    ---@return string?
    local function traverse(key)
        for _, v in pairs(G.localization.descriptions) do
            local name = (v[key] or {}).name

            if name then
                return name
            end
        end
    end

    local name = ((G.localization.descriptions[center.set] or {})[center.key] or {}).name

    if name then
        return name
    end

    name = (center.loc_txt or {}).name

    if name then
        return name
    end

    return traverse(center.key) or traverse(center.key:gsub("_%d+$", ""):gsub("%d+$", "")) or "ERROR"
end

--- Retrieves the logic, or creates it if it doesn't already exist.
---@return table
---@return table
local function load()
    local mapper, reverse_mapper = assert(SMODS.load_file("src/mapper.lua", "Pingo"))(), {}

    for k, tbl in pairs(mapper) do
        for _, v in pairs(tbl) do
            reverse_mapper[v] = k
        end
    end

    return mapper, reverse_mapper
end

--- Updates the lock status of the center.
---@param id string
---@param center table
---@param unlocked boolean
local function update_lock_status(id, center, unlocked)
    if not center then
        -- Should only ever be nil if modded items are set to "Remove"
        if G.AP.this_mod.config.modded == 1 then
            return
        end

        sendErrorMessage("Cannot find modded object with the id: " .. id, "Pingo")

        sendWarnMessage(
            "Ensure 'Modded Items' is not set to 'Remove' and make sure mapper.lua has all modded items, or delete the file to force it to refresh!",
            "Pingo"
        )
    end

    center.hidden = not unlocked and G.AP.this_mod.config.modded == 2
    center.ap_unlocked = unlocked
    center.discovered = unlocked
    center.unlocked = unlocked
    center.wip = not unlocked
end

--- Creates the localization variables for the locked check.
---@param vanilla SMODS.Center
---@param modded SMODS.Center
---@return table
local function loc_vars(vanilla, modded)
    return {
        modded.key,
        find_loc_name(vanilla),
        find_loc_name(modded):gsub("#b%{%}", ""):gsub("%b##", ""),
    }
end

--- Initializes the mod.
---@return true
local function init()
    local mapper, reverse_mapper = load()
    local orig_init_item_prototypes = Game.init_item_prototypes

    ---@diagnostic disable-next-line: duplicate-set-field
    function Game:init_item_prototypes(...)
        local ret = orig_init_item_prototypes(self, ...)
        mapper, reverse_mapper = load()

        if not isAPProfileLoaded() then
            return ret
        end

        for vanilla, mods in pairs(mapper) do
            local vp = G.P_TAGS[vanilla] or G.P_CENTERS[vanilla]

            local unlocked = vp.ap_unlocked or
                vp.ap_unlocked == nil and vp.unlocked or
                vp.set == "Booster" and vp.discovered

            for _, id in pairs(mods) do
                local center = G.P_CENTERS[id]
                local set = (center or {}).set

                if set == "Sleeve" and not center.locked_loc_vars then
                    -- Prevents crash in CardSleeves where locked_loc_vars isn't defined.
                    center.locked_loc_vars = function(_, _)
                        return {vars = {colours = {}}}
                    end
                elseif set == "Voucher" and center.unapply_to_run and not center.Pingo_unapply_to_run then
                    center.Pingo_unapply_to_run = true
                    local orig_unapply_to_run = center.unapply_to_run

                    --- Prevents crash or undesired behavior with Cryptid where vouchers get unredeemed while viewing the collection.
                    center.unapply_to_run = function(...)
                        if G.hand then
                            orig_unapply_to_run(...)
                        end
                    end
                end

                update_lock_status(id, G.P_TAGS[id] or G.P_CENTERS[id], unlocked)
            end
        end

        return ret
    end

    local orig_generate_card_ui = generate_card_ui

    function generate_card_ui(_c, ...)
        local vanilla_key = reverse_mapper[_c.key]

        if not isAPProfileLoaded() or not vanilla_key then
            return orig_generate_card_ui(_c, ...)
        end

        G.localization.descriptions.Other.wip_locked.text_parsed = {}
        local vanilla = G.P_TAGS[vanilla_key] or G.P_CENTERS[vanilla_key]
        local vars = loc_vars(vanilla, _c)

        for i, v in ipairs(G.localization.descriptions.Other.Pingo_discover) do
            local loc = v:gsub("#1#", vars[1]):gsub("#2#", vars[2]):gsub("#3#", vars[3])
            G.localization.descriptions.Other.wip_locked.text_parsed[i] = loc_parse_string(loc)
        end

        _c.Pingo_info_queue = {vanilla}
        local ret = orig_generate_card_ui(_c, ...)
        _c.Pingo_info_queue = nil
        return ret
    end

    local orig_locked_loc_vars = (((CardSleeves or {}).Sleeve or {}) or {}).locked_loc_vars

    if orig_locked_loc_vars then
        function CardSleeves.Sleeve:locked_loc_vars(info_queue, card)
            if not isAPProfileLoaded() then
                return orig_locked_loc_vars(self, info_queue, card)
            end

            local vanilla = reverse_mapper[self.key]

            return {
                key = "Pingo_sleeve_discover",
                vars = loc_vars(G.P_TAGS[vanilla] or G.P_CENTERS[vanilla], self),
            }
        end
    end

    local orig_AP_unlock_item = G.FUNCS.AP_unlock_item

    ---@diagnostic disable-next-line: duplicate-set-field
    function G.FUNCS.AP_unlock_item(item, notify, ...)
        ---@diagnostic disable-next-line: redundant-parameter
        local ret = orig_AP_unlock_item(item, notify, ...)

        for _, id in pairs(mapper[item.key] or {}) do
            local center = G.P_TAGS[id] or G.P_CENTERS[id]
            update_lock_status(id, center, true)

            for _, v in pairs({"jokers", "consumeables", "shop_jokers", "pack_cards"}) do
                buff(v, center.key)
            end

            if notify then
                notify_unlock(center.key)
            end
        end

        return ret
    end

    return true
end

G.E_MANAGER:add_event(Event {func = init, trigger = "immediate"})
