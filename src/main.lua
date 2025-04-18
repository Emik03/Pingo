SMODS.Atlas({
    key = "modicon",
    path = "modicon.png",
    px = 32,
    py = 32,
})

local notify_unlock = assert(SMODS.load_file("src/notify.lua", "Pingo"))()

--- Removes the debuff status from the given card.
---@param set string
---@param key string
local function buff(set, key)
    local g = G[set]

    if not g or not g.cards then
        return
    end

    for _, v in pairs(g.cards) do
        if v and type(v) == "table" and key == v.config.center.key then
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

    if not center then
        return G.localization.descriptions.Other.Pingo_no_check[1]
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

--- Converts the given ID to the respective object.
---@param id string
---@return table
local function to_object(id)
    return G.P_TAGS[id] or G.P_CENTERS[id]
end

--- Updates the lock status of the center.
---@param id string
---@param center table
---@param unlocked boolean
local function update_lock_status(id, center, unlocked)
    if center then
        local unlocked_by_ap = ({Joker = true, Planet = true, Spectral = true, Tarot = true})[center.set]
        center.discovered = unlocked or unlocked_by_ap or false
        center.unlocked = unlocked or unlocked_by_ap or false
        center.ap_unlocked = unlocked
        center.debuff = not unlocked
        center.wip = not unlocked
        return
    end

    -- Should only ever be nil if modded items are set to "Remove"
    if G.AP.this_mod.config.modded ~= 1 then
        sendErrorMessage("Modded object with the following id doesn't exist: " .. id, "Pingo")
    end
end

local mapper, reverse_mapper, stake = {}, {}, {}

--- Gets the stake offset amount.
---@return integer
local function scaling_stakes()
    if type(stake.scaling_stakes) ~= "number" or stake.scaling_stakes == 0 then
        return 0
    end

    local p = G.AP.check_progress() * (1 / stake.scaling_stakes)
    return p > 0 and math.floor(p) or math.ceil(p)
end

--- Finds the modded stake for the correspond vanilla stake, if applicable.
---@param i integer
---@return integer
local function find_stake(i)
    local order = G.P_CENTER_POOLS.Stake[i].order

    for vanilla_key, vanilla_value in pairs(G.P_STAKES) do
        if stake[vanilla_key] and order == vanilla_value.order then
            for modded_key, modded_value in pairs(G.P_STAKES) do
                if modded_key == (type(stake[vanilla_key]) == "string" and #stake[vanilla_key] > 0 and stake[vanilla_key] or vanilla_key) then
                    local scaled_order = scaling_stakes()

                    if scaled_order == 0 then
                        return modded_value.order
                    end

                    for _, scaled_value in pairs(G.P_STAKES) do
                        if scaled_order + modded_value.order == scaled_value.order then
                            return scaled_order + modded_value.order
                        end
                    end

                    local max, min = -1 / 0, 1 / 0

                    for _, value in pairs(G.P_STAKES) do
                        max, min = math.max(max, value.order), math.min(min, value.order)
                    end

                    return scaled_order + modded_value.order > max and max or min
                end
            end
        end
    end

    return order
end

--- Sets the values of modded elements.
---@return true
local function init_item_prototypes()
    for vanilla, mods in pairs(mapper) do
        local vp = to_object(vanilla)

        local unlocked = vp.ap_unlocked or
            vp.ap_unlocked == nil and vp.unlocked or
            vp.set == "Booster" and vp.discovered

        for _, id in pairs(mods) do
            local center = to_object(id)
            local set = (center or {}).set

            if set == "Sleeve" and not center.locked_loc_vars then
                -- Prevents crash in CardSleeves where locked_loc_vars isn't defined.
                center.locked_loc_vars = function(_, _)
                    return {vars = {colours = {}}}
                end
            elseif set == "Voucher" and center.unapply_to_run and not center.Pingo_unapply_to_run then
                center.Pingo_unapply_to_run = true
                local orig_unapply_to_run = center.unapply_to_run

                --- Prevents crash or undesired behavior with Cryptid where vouchser get unredeemed while viewing the collection.
                center.unapply_to_run = function(...)
                    if G.hand then
                        orig_unapply_to_run(...)
                    end
                end
            end

            update_lock_status(id, center, unlocked)
        end
    end

    -- Prevents softlock in CardSleeves when "Modded Items" are set to "Locked"
    if G.P_CENTERS.sleeve_casl_none then
        G.P_CENTERS.sleeve_casl_none.unlocked = true
    end

    return true
end

local orig_generate_card_ui = generate_card_ui

function generate_card_ui(_c, full_UI_table, specific_vars, card_type, ...)
    if not isAPProfileLoaded() then
        return orig_generate_card_ui(_c, full_UI_table, specific_vars, card_type, ...)
    end

    local vanilla_key = reverse_mapper[_c.key]
    local wip_locked = G.localization.descriptions.Other.wip_locked

    if not vanilla_key then
        wip_locked.text_parsed = wip_locked.Pingo_text_parsed or wip_locked.text_parsed
        return orig_generate_card_ui(_c, full_UI_table, specific_vars, card_type, ...)
    end

    local vanilla = to_object(vanilla_key)
    local vars = loc_vars(vanilla, _c)
    wip_locked.Pingo_text_parsed = wip_locked.Pingo_text_parsed or wip_locked.text_parsed
    wip_locked.text_parsed = {}

    for i, v in ipairs(G.localization.descriptions.Other.Pingo_discover) do
        local loc = v:gsub("#1#", vars[1]):gsub("#2#", vars[2]):gsub("#3#", vars[3])
        wip_locked.text_parsed[i] = loc_parse_string(loc)
    end

    local ui = orig_generate_card_ui(_c, full_UI_table, specific_vars, _c.ap_unlocked and card_type or "Locked", ...)
    return G.STATE == G.STATES.MENU and ui or orig_generate_card_ui(vanilla, ui)
end

local orig_unapply_to_run = Card.unapply_to_run

if orig_unapply_to_run then
    function Card:unapply_to_run(...)
        if G.hand then
            orig_unapply_to_run(self, ...)
        end
    end
end

local orig_init_item_prototypes = Game.init_item_prototypes

---@diagnostic disable-next-line: duplicate-set-field
function Game:init_item_prototypes(...)
    local ret = orig_init_item_prototypes(self, ...)
    mapper, reverse_mapper = load()
    stake = assert(SMODS.load_file("src/difficulty.lua", "Pingo"))()

    if isAPProfileLoaded() then
        G.E_MANAGER:add_event(Event {func = init_item_prototypes, trigger = "immediate"})
    end

    return ret
end

local orig_get_stake_col = get_stake_col

---@diagnostic disable-next-line: lowercase-global
function get_stake_col(i, ...)
    return orig_get_stake_col(isAPProfileLoaded() and find_stake(i) or i, ...)
end

local orig_get_stake_sprite = get_stake_sprite

---@diagnostic disable-next-line: lowercase-global
function get_stake_sprite(_stake, _scale, ...)
    if not isAPProfileLoaded() then
        return orig_get_stake_sprite(_stake, _scale, ...)
    end

    local center
    _stake = _stake or 1
    _scale = _scale or 1
    local find = find_stake(_stake)

    for _, v in pairs(G.P_STAKES) do
        if find == v.order then
            center = v
        end
    end

    if not center then
        return orig_get_stake_sprite(_stake, _scale, ...)
    end

    local stake_sprite = Sprite(0, 0, _scale, _scale, G.ASSET_ATLAS[center.atlas], center.pos)

    if center.shiny then
        stake_sprite.draw = function(_sprite)
            _sprite.ARGS.send_to_shader = _sprite.ARGS.send_to_shader or {}

            _sprite.ARGS.send_to_shader[1] =
                math.min(_sprite.VT.r * 3, 1) + G.TIMERS.REAL / (18) + (_sprite.juice and _sprite.juice.r * 20 or 0) + 1

            _sprite.ARGS.send_to_shader[2] = G.TIMERS.REAL

            Sprite.draw_shader(_sprite, "dissolve")
            Sprite.draw_shader(_sprite, "voucher", nil, _sprite.ARGS.send_to_shader)
        end
    end

    return stake_sprite
end

local orig_localize = localize

---@diagnostic disable-next-line: lowercase-global
function localize(args, ...)
    if not isAPProfileLoaded() or type(args) ~= "table" then
        return orig_localize(args, ...)
    end

    local key = type(stake[args.key]) == "string" and #stake[args.key] > 0 and stake[args.key] or args.key

    if scaling_stakes() == 0 then
        args.key = key
    else
        for i, center in ipairs(G.P_CENTER_POOLS.Stake) do
            if key == center.key then
                local order = find_stake(i)

                for k, v in pairs(G.P_STAKES) do
                    if order == v.order then
                        args.key = k
                        break
                    end
                end

                break
            end
        end
    end

    return orig_localize(args, ...)
end

local orig_setup_stake = G.AP.setup_stake

---@diagnostic disable-next-line: duplicate-set-field
function G.AP.setup_stake(i, ...)
    local center
    local find = find_stake(i)

    for _, v in pairs(G.P_STAKES) do
        if find == v.order then
            center = v
        end
    end

    for k, _ in pairs(center and SMODS.build_stake_chain(center) or {}) do
        for _, v in pairs(G.P_STAKES) do
            if k == v.order and v.modifiers then
                v.modifiers()
            end
        end
    end

    return orig_setup_stake(i, ...)
end

local orig_AP_unlock_item = G.FUNCS.AP_unlock_item

---@diagnostic disable-next-line: duplicate-set-field
function G.FUNCS.AP_unlock_item(item, notify, ...)
    ---@diagnostic disable-next-line: redundant-parameter
    local ret = orig_AP_unlock_item(item, notify, ...)

    for _, id in pairs(mapper[item.key] or {}) do
        local center = to_object(id)
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

local orig_locked_loc_vars = ((CardSleeves or {}).Sleeve or {}).locked_loc_vars

if orig_locked_loc_vars then
    ---@diagnostic disable-next-line: duplicate-set-field
    function CardSleeves.Sleeve:locked_loc_vars(...)
        return isAPProfileLoaded() and {
            key = "Pingo_sleeve_discover",
            vars = loc_vars(to_object(reverse_mapper[self.key]), self),
        } or orig_locked_loc_vars(self, ...)
    end
end
