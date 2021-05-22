local utils = require 'mp.utils'
local msg = require 'mp.msg'
local assdraw = require 'mp.assdraw'

local gallery_mt = {}
gallery_mt.__index = gallery_mt

function gallery_new()
    local gallery = setmetatable({
        -- public, can be modified by user
        items = {},
        item_to_overlay_path = function(index, item) return "" end,
        item_to_thumbnail_params = function(index, item) return "", 0 end,
        item_to_text = function(index, item) return "", true end,
        item_to_border = function(index, item) return 0, "" end,
        ass_show = function(ass) end,
        config = {
            background_color = '333333',
            background_opacity = '33',
            background_roundness = 5,
            scrollbar = true,
            scrollbar_left_side = false,
            scrollbar_min_size = 10,
            overlay_range = 0,
            max_thumbnails = 64,
            show_placeholders = true,
            always_show_placeholders = false,
            placeholder_color = '222222',
            text_size = 28,
            align_text = true,
            accurate = false,
            generate_thumbnails_with_mpv = false,
        },

        -- private, can be read but should not be modified
        active = false,
        geometry = {
            ok = false,
            position = { 0, 0 },
            size = { 0, 0 },
            min_spacing = { 0, 0 },
            thumbnail_size = { 0, 0 },
            rows = 0,
            columns = 0,
            effective_spacing = { 0, 0 },
        },
        view = { -- 1-based indices into the "playlist" array
            first = 0, -- must be equal to N*columns
            last = 0, -- must be > first and <= first + rows*columns
        },
        overlays = {
            active = {}, -- array of <=64 strings indicating the file associated to the current overlay (false if nothing)
            missing = {}, -- associative array of thumbnail path to view index it should be shown at
        },
        selection = nil,
        ass = {
            background = "",
            selection = "",
            scrollbar = "",
            placeholders = "",
        },
        generators = {}, -- list of generator scripts


    }, gallery_mt)

    for i = 1, gallery.config.max_thumbnails do
        gallery.overlays.active[i] = false
    end
    return gallery
end

function gallery_mt.show_overlay(gallery, index_1, thumb_path)
    local g = gallery.geometry
    gallery.overlays.active[index_1] = thumb_path
    local index_0 = index_1 - 1
    local x, y = gallery:view_index_position(index_0)
    mp.commandv("overlay-add",
        tostring(index_0 + gallery.config.overlay_range),
        tostring(math.floor(x + 0.5)),
        tostring(math.floor(y + 0.5)),
        thumb_path,
        "0",
        "bgra",
        tostring(g.thumbnail_size[1]),
        tostring(g.thumbnail_size[2]),
        tostring(4*g.thumbnail_size[1]))
    mp.osd_message(" ", 0.01)
end

function gallery_mt.remove_overlays(gallery)
    for view_index, _ in pairs(gallery.overlays.active) do
        mp.commandv("overlay-remove", gallery.config.overlay_range + view_index - 1)
        gallery.overlays.active[view_index] = false
    end
    gallery.overlays.missing = {}
end

local function file_exists(path)
    local info = utils.file_info(path)
    return info ~= nil and info.is_file
end

function gallery_mt.refresh_overlays(gallery, force)
    local todo = {}
    local o = gallery.overlays
    local g = gallery.geometry
    o.missing = {}
    for view_index = 1, g.rows * g.columns do
        local index = gallery.view.first + view_index - 1
        local active = o.active[view_index]
        if index > 0 and index <= #gallery.items then
            local thumb_path = gallery.item_to_overlay_path(index, gallery.items[index])
            if not force and active == thumb_path then
                -- nothing to do
            elseif file_exists(thumb_path) then
                gallery:show_overlay(view_index, thumb_path)
            else
                -- need to generate that thumbnail
                o.active[view_index] = false
                mp.commandv("overlay-remove", gallery.config.overlay_range + view_index - 1)
                o.missing[thumb_path] = view_index
                todo[#todo + 1] = { index = index, output = thumb_path }
            end
        else
            -- might happen if we're close to the end of gallery.items
            if active ~= false then
                o.active[view_index] = false
                mp.commandv("overlay-remove", gallery.config.overlay_range + view_index - 1)
            end
        end
    end
    if #gallery.generators >= 1 then
        -- reverse iterate so that the first thumbnail is at the top of the stack
        for i = #todo, 1, -1 do
            local generator = gallery.generators[i % #gallery.generators + 1]
            local t = todo[i]
            local input_path, time = gallery.item_to_thumbnail_params(t.index, gallery.items[t.index])
            mp.commandv("script-message-to", generator, "push-thumbnail-front",
                mp.get_script_name(),
                input_path,
                tostring(g.thumbnail_size[1]),
                tostring(g.thumbnail_size[2]),
                time,
                t.output,
                gallery.config.accurate and "true" or "false",
                gallery.config.generate_thumbnails_with_mpv and "true" or "false"
            )
        end
    end
end

function gallery_mt.index_at(gallery, mx, my)
    local g = gallery.geometry
    if mx < g.position[1] or my < g.position[2] then return nil end
    mx = mx - g.position[1]
    my = my - g.position[2]
    if mx > g.size[1] or my > g.size[2] then return nil end
    mx = mx - g.effective_spacing[1]
    my = my - g.effective_spacing[2]
    local on_column = (mx % (g.thumbnail_size[1] + g.effective_spacing[1])) < g.thumbnail_size[1]
    local on_row = (my % (g.thumbnail_size[2] + g.effective_spacing[2])) < g.thumbnail_size[2]
    if on_column and on_row then
        local column = math.floor(mx / (g.thumbnail_size[1] + g.effective_spacing[1]))
        local row = math.floor(my / (g.thumbnail_size[2] + g.effective_spacing[2]))
        local index = gallery.view.first + row * g.columns + column
        if index > 0 and index <= gallery.view.last then
            return index
        end
    end
    return nil
end

function gallery_mt.compute_internal_geometry(gallery)
    local g = gallery.geometry
    g.rows = math.floor((g.size[2] - g.min_spacing[2]) / (g.thumbnail_size[2] + g.min_spacing[2]))
    g.columns = math.floor((g.size[1] - g.min_spacing[1]) / (g.thumbnail_size[1] + g.min_spacing[1]))
    if g.rows <= 0 or g.columns <= 0 then
        g.rows = 0
        g.columns = 0
        g.effective_spacing[1] = g.size[1]
        g.effective_spacing[2] = g.size[2]
        return
    end
    if (g.rows * g.columns > gallery.config.max_thumbnails) then
        local r = math.sqrt(g.rows * g.columns / gallery.config.max_thumbnails)
        g.rows = math.floor(g.rows / r)
        g.columns = math.floor(g.columns / r)
    end
    g.effective_spacing[1] = (g.size[1] - g.columns * g.thumbnail_size[1]) / (g.columns + 1)
    g.effective_spacing[2] = (g.size[2] - g.rows * g.thumbnail_size[2]) / (g.rows + 1)
end

-- makes sure that view.first and view.last are valid with regards to the playlist
-- and that selection is within the view
-- to be called after the playlist, view or selection was modified somehow
function gallery_mt.ensure_view_valid(gallery)
    local g = gallery.geometry
    if #gallery.items == 0 or g.rows == 0 or g.columns == 0 then
        gallery.view.first = 0
        gallery.view.last = 0
        return
    end
    local v = gallery.view
    local selection_row = math.floor((gallery.selection - 1) / g.columns)
    local max_thumbs = g.rows * g.columns
    local changed = false

    if v.last >= #gallery.items then
        v.last = #gallery.items
        if g.rows == 1 then
            v.first = math.max(1, v.last - g.columns + 1)
        else
            local last_row = math.floor((v.last - 1) / g.columns)
            local first_row = math.max(0, last_row - g.rows + 1)
            v.first = 1 + first_row * g.columns
        end
        changed = true
    elseif v.first == 0 or v.last == 0 or v.last - v.first + 1 ~= max_thumbs then
        -- special case: the number of possible thumbnails was changed
        -- just recreate the view such that the selection is in the middle row
        local max_row = (#gallery.items - 1) / g.columns + 1
        local row_first = selection_row - math.floor((g.rows - 1) / 2)
        local row_last = selection_row + math.floor((g.rows - 1) / 2) + g.rows % 2
        if row_first < 0 then
            row_first = 0
        elseif row_last > max_row then
            row_first = max_row - g.rows + 1
        end
        v.first = 1 + row_first * g.columns
        v.last = math.min(#gallery.items, v.first - 1 + max_thumbs)
        return true
    end

    if gallery.selection < v.first then
        -- the selection is now on the first line
        v.first = (g.rows == 1) and gallery.selection or selection_row * g.columns + 1
        v.last = math.min(#gallery.items, v.first + max_thumbs - 1)
        changed = true
    elseif gallery.selection > v.last then
        v.last = (g.rows == 1) and gallery.selection or (selection_row + 1) * g.columns
        v.first = math.max(1, v.last - max_thumbs + 1)
        v.last = math.min(#gallery.items, v.last)
        changed = true
    end
    return changed
end

-- ass related stuff
function gallery_mt.refresh_background(gallery)
    local g = gallery.geometry
    local a = assdraw.ass_new()
    a:new_event()
    a:append('{\\an7}')
    a:append('{\\bord0}')
    a:append('{\\shad0}')
    a:append('{\\1c&' .. gallery.config.background_color .. '}')
    a:append('{\\1a&' .. gallery.config.background_opacity .. '}')
    a:pos(0, 0)
    a:draw_start()
    a:round_rect_cw(g.position[1], g.position[2], g.position[1] + g.size[1], g.position[2] + g.size[2], gallery.config.background_roundness)
    a:draw_stop()
    gallery.ass.background = a.text
end

function gallery_mt.refresh_placeholders(gallery)
    if not gallery.config.show_placeholders then return end
    if gallery.view.first == 0 then
        gallery.ass.placeholders = ""
        return
    end
    local g = gallery.geometry
    local a = assdraw.ass_new()
    a:new_event()
    a:append('{\\an7}')
    a:append('{\\bord0}')
    a:append('{\\shad0}')
    a:append('{\\1c&' .. gallery.config.placeholder_color .. '}')
    a:pos(0, 0)
    a:draw_start()
    for i = 0, gallery.view.last - gallery.view.first do
        if gallery.config.always_show_placeholders or not gallery.overlays.active[i + 1] then
            local x, y = gallery:view_index_position(i)
            a:rect_cw(x, y, x + g.thumbnail_size[1], y + g.thumbnail_size[2])
        end
    end
    a:draw_stop()
    gallery.ass.placeholders = a.text
end

function gallery_mt.refresh_scrollbar(gallery)
    if not gallery.config.scrollbar then return end
    gallery.ass.scrollbar = ""
    if gallery.view.first == 0 then return end
    local g = gallery.geometry
    local before = (gallery.view.first - 1) / #gallery.items
    local after = (#gallery.items - gallery.view.last) / #gallery.items
    -- don't show the scrollbar if everything is visible
    if before + after == 0 then return end
    local p = gallery.config.scrollbar_min_size / 100
    if before + after > 1 - p then
        if before == 0 then
            after = (1 - p)
        elseif after == 0 then
            before = (1 - p)
        else
            before, after =
                before / after * (1 - p) / (1 + before / after),
                after / before * (1 - p) / (1 + after / before)
        end
    end
    local dist_from_edge = g.size[2] * 0.015
    local y1 = g.position[2] + dist_from_edge + before * (g.size[2] - 2 * dist_from_edge)
    local y2 = g.position[2] + g.size[2] - (dist_from_edge + after * (g.size[2] - 2 * dist_from_edge))
    local x1, x2
    if gallery.config.scrollbar_left_side then
        x1 = g.position[1] + g.effective_spacing[1] / 2 - 2
    else
        x1 = g.position[1] + g.size[1] - g.effective_spacing[1] / 2 - 2
    end
    x2 = x1 + 4
    local scrollbar = assdraw.ass_new()
    scrollbar:new_event()
    scrollbar:append('{\\an7}')
    scrollbar:append('{\\bord0}')
    scrollbar:append('{\\shad0}')
    scrollbar:append('{\\1c&AAAAAA&}')
    scrollbar:pos(0, 0)
    scrollbar:draw_start()
    scrollbar:rect_cw(x1, y1, x2, y2)
    scrollbar:draw_stop()
    gallery.ass.scrollbar = scrollbar.text
end

function gallery_mt.refresh_selection(gallery)
    local v = gallery.view
    if v.first == 0 then
        gallery.ass.selection = ""
        return
    end
    local selection_ass = assdraw.ass_new()
    local g = gallery.geometry
    local draw_frame = function(index, size, color)
        local x, y = gallery:view_index_position(index - v.first)
        selection_ass:new_event()
        selection_ass:append('{\\an7}')
        selection_ass:append('{\\bord' .. size ..'}')
        selection_ass:append('{\\3c&'.. color ..'&}')
        selection_ass:append('{\\1a&FF&}')
        selection_ass:pos(0, 0)
        selection_ass:draw_start()
        selection_ass:rect_cw(x, y, x + g.thumbnail_size[1], y + g.thumbnail_size[2])
        selection_ass:draw_stop()
    end
    for i = v.first, v.last do
        local size, color = gallery.item_to_border(i, gallery.items[i])
        if size > 0 then
            draw_frame(i, size, color)
        end
    end

    for index = v.first, v.last do
        local text  = gallery.item_to_text(index, gallery.items[index])
        if text ~= "" then
            selection_ass:new_event()
            local an = 5
            local x, y = gallery:view_index_position(index - v.first)
            x = x + g.thumbnail_size[1] / 2
            y = y + g.thumbnail_size[2] + gallery.config.text_size * 0.75
            if gallery.config.align_text then
                local col = (index - v.first) % g.columns
                if g.columns > 1 then
                    if col == 0 then
                        x = x - g.thumbnail_size[1] / 2
                        an = 4
                    elseif col == g.columns - 1 then
                        x = x + g.thumbnail_size[1] / 2
                        an = 6
                    end
                end
            end
            selection_ass:an(an)
            selection_ass:pos(x, y)
            selection_ass:append(string.format("{\\fs%d}", gallery.config.text_size))
            selection_ass:append("{\\bord0}")
            selection_ass:append(text)
        end
    end
    gallery.ass.selection = selection_ass.text
end

function gallery_mt.ass_refresh(gallery, selection, scrollbar, placeholders, background)
    if not gallery.active then return end
    if selection then gallery:refresh_selection() end
    if scrollbar then gallery:refresh_scrollbar() end
    if placeholders then gallery:refresh_placeholders() end
    if background then gallery:refresh_background() end
    gallery.ass_show(table.concat({
        gallery.ass.background,
        gallery.ass.placeholders,
        gallery.ass.selection,
        gallery.ass.scrollbar
    }, "\n"))
end

function gallery_mt.set_selection(gallery, selection)
    if not selection or selection ~= selection then return end
    local new_selection = math.max(1, math.min(selection, #gallery.items))
    if gallery.selection == new_selection then return end
    gallery.selection = new_selection
    if gallery.active then
        if gallery:ensure_view_valid() then
            gallery:refresh_overlays(false)
            gallery:ass_refresh(true, true, true, false)
        else
            gallery:ass_refresh(true, false, false, false)
        end
    end
end

function gallery_mt.set_geometry(gallery, x, y, w, h, sw, sh, tw, th)
    if w <= 0 or h <= 0 or tw <= 0 or th <= 0 then
        msg.warn("Invalid coordinates")
        return
    end
    gallery.geometry.position = {x, y}
    gallery.geometry.size = {w, h}
    gallery.geometry.min_spacing = {sw, sh}
    gallery.geometry.thumbnail_size = {tw, th}
    gallery.geometry.ok = true
    if not gallery.active then return end
    if not gallery:enough_space() then
        msg.warn("Not enough space to display something")
    end
    local old_total = gallery.geometry.rows * gallery.geometry.columns
    gallery:compute_internal_geometry()
    gallery:ensure_view_valid()
    local new_total = gallery.geometry.rows * gallery.geometry.columns
    for view_index = new_total + 1, old_total do
        if gallery.overlays.active[view_index] then
            mp.commandv("overlay-remove", gallery.config.overlay_range + view_index - 1)
            gallery.overlays.active[view_index] = false
        end
    end
    gallery:refresh_overlays(true)
    gallery:ass_refresh(true, true, true, true)
end

function gallery_mt.items_changed(gallery, new_sel)
    gallery.selection = math.max(1, math.min(new_sel, #gallery.items))
    if not gallery.active then return end
    gallery:ensure_view_valid()
    gallery:refresh_overlays(false)
    gallery:ass_refresh(true, true, true, false)
end

function gallery_mt.thumbnail_generated(gallery, thumb_path)
    if not gallery.active then return end
    local view_index = gallery.overlays.missing[thumb_path]
    if view_index == nil then return end
    gallery:show_overlay(view_index, thumb_path)
    if not gallery.config.always_show_placeholders then
        gallery:ass_refresh(false, false, true, false)
    end
    gallery.overlays.missing[thumb_path] = nil
end

function gallery_mt.add_generator(gallery, generator_name)
    for _, g in ipairs(gallery.generators) do
        if generator_name == g then return end
    end
    gallery.generators[#gallery.generators + 1] = generator_name
end

function gallery_mt.view_index_position(gallery, index_0)
    local g = gallery.geometry
    return math.floor(g.position[1] + g.effective_spacing[1] + (g.effective_spacing[1] + g.thumbnail_size[1]) * (index_0 % g.columns)),
        math.floor(g.position[2] + g.effective_spacing[2] + (g.effective_spacing[2] + g.thumbnail_size[2]) * math.floor(index_0 / g.columns))
end

function gallery_mt.enough_space(gallery)
    if gallery.geometry.size[1] < gallery.geometry.thumbnail_size[1] + 2 * gallery.geometry.min_spacing[1] then return false end
    if gallery.geometry.size[2] < gallery.geometry.thumbnail_size[2] + 2 * gallery.geometry.min_spacing[2] then return false end
    return true
end

function gallery_mt.activate(gallery)
    if gallery.active then return false end
    if not gallery:enough_space() then
        msg.warn("Not enough space, refusing to start")
        return false
    end
    if not gallery.geometry.ok then
        msg.warn("Gallery geometry unitialized, refusing to start")
        return false
    end
    gallery.active = true
    if not gallery.selection then
        gallery:set_selection(1)
    end
    gallery:compute_internal_geometry()
    gallery:ensure_view_valid()
    gallery:refresh_overlays(false)
    gallery:ass_refresh(true, true, true, true)
    return true
end

function gallery_mt.deactivate(gallery)
    if not gallery.active then return end
    gallery.active = false
    gallery:remove_overlays()
    gallery.ass_show("")
end

return {gallery_new = gallery_new}

