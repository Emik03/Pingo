--- Sets the state of the sprite.
---@param s Sprite?
local function state(s)
    if s then
        local states = s["states"]
        states.collide.can = false
        states.hover.can = false
        states.drag.can = false
    end
end

--- Creates the notification table for highlighting the specific center being unlocked.
---@param center SMODS.Center
---@return table
local function create(center)
    local c = G.P_CENTERS[center]
    local atlas = c and G.ASSET_ATLAS[c.atlas]
    local name = (c and ((G.localization.descriptions[c.set] or {})[c.key] or {}).name) or "ERROR"
    local ts = c and Sprite(0, 0, 1.5 * (atlas.px / atlas.py), 1.5, atlas, c and c.pos or {x = 0, y = 0})
    local soul_ts = (c or {}).soul_pos and Sprite(0, 0, 1.5 * (atlas.px / atlas.py), 1.5, atlas, c.soul_pos)
    state(ts)
    state(soul_ts)

    return {
        n = G.UIT.ROOT,
        config = {align = "cl", r = 0.1, padding = 0.06, colour = G.C.UI.TRANSPARENT_DARK},
        nodes = {{
            n = G.UIT.R,
            config = {
                align = "cl",
                padding = 0.3,
                minw = 20,
                r = 0.1,
                colour = G.C.BLACK,
                outline = 1.5,
                outline_colour = G.C.GREY,
            },
            nodes = {{
                n = G.UIT.R,
                config = {align = "cm", r = 0.1, padding = 0.7},
                nodes = {{
                    n = G.UIT.R,
                    config = {align = "cm", r = 0.1, padding = -1.1},
                    nodes = {
                        ts and {n = G.UIT.O, config = {object = ts}},
                        soul_ts and {n = G.UIT.O, config = {object = soul_ts}},
                    },
                }, {
                    n = G.UIT.R,
                    config = {align = "bm", padding = 0.2},
                    nodes = {
                        {
                            n = G.UIT.R,
                            config = {align = "bm", maxw = 3.4},
                            nodes = {{
                                n = G.UIT.T,
                                config = {
                                    text = name:gsub("#b%{%}", ""):gsub("%b##", ""),
                                    scale = 0.5,
                                    colour = G.C.FILTER,
                                    shadow = true,
                                },
                            }},
                        },
                        {
                            n = G.UIT.R,
                            config = {align = "bm", maxw = 3.4},
                            nodes = {{
                                n = G.UIT.T,
                                config = {
                                    text = localize("k_unlocked_ex"),
                                    scale = 0.35,
                                    colour = G.C.FILTER,
                                    shadow = true,
                                },
                            }},
                        },
                    },
                }},
            }},
        }},
    }
end

--- Aligns the notification.
---@return true
local function align()
    G.achievement_notification.alignment.offset.x = G.ROOM.T.x -
        G.achievement_notification.UIRoot.children[1].children[1].T.w - 0.8

    return true
end

--- Plays the sound effect for unlocking an item.
---@return true
local function play()
    play_sound("highlight1", nil, 0.5)
    play_sound("foil2", 0.5, 0.4)
    return true
end

--- Realigns the notification.
---@return true
local function realign()
    G.achievement_notification.alignment.offset.x = 20
    return true
end

--- Removes the notification.
---@return true
local function remove()
    if G.achievement_notification then
        G.achievement_notification:remove()
        G.achievement_notification = nil
    end

    return true
end

--- Displays the notification to highlight the specific center being unlocked.
---@param center SMODS.Center
local function notify(center)
    --- Removes the existing notification to be replaced with the new one.
    ---@return true
    local function capture()
        if G.achievement_notification then
            G.achievement_notification:remove()
            G.achievement_notification = nil
        end

        G.achievement_notification = G.achievement_notification or UIBox {
            definition = create(center),
            config = {align = "cr", offset = {x = 20, y = 0}, major = G.ROOM_ATTACH, bond = "Weak"},
        }

        return true
    end

    G.E_MANAGER:add_event(Event({
        func = capture,
        timer = "UPTIME",
        no_delete = true,
        pause_force = true,
    }), "achievement")

    G.E_MANAGER:add_event(Event({
        delay = 0.1,
        func = align,
        no_delete = true,
        trigger = "after",
        pause_force = true,
        timer = "UPTIME",
    }), "achievement")

    G.E_MANAGER:add_event(Event({
        func = play,
        delay = 0.1,
        no_delete = true,
        timer = "UPTIME",
        trigger = "after",
        pause_force = true,
    }), "achievement")

    G.E_MANAGER:add_event(Event({
        delay = 3,
        func = realign,
        timer = "UPTIME",
        no_delete = true,
        trigger = "after",
        pause_force = true,
    }), "achievement")

    G.E_MANAGER:add_event(Event({
        delay = 0.5,
        func = remove,
        no_delete = true,
        timer = "UPTIME",
        trigger = "after",
        pause_force = true,
    }), "achievement")
end

return notify
