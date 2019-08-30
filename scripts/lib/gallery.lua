local utils = require 'mp.utils'
local assdraw = require 'mp.assdraw'

local gallery_mt = {}
gallery_mt.__index = gallery_mt

function gallery_new()
    return setmetatable({
        active = false,
        items = {},
        geometry = {
            window = { 
                w = 0,
                h = 0,
            },
            draw_area = {
                x = 0,
                y = 0,
                w = 0,
                h = 0,
            },
            item_size = {
                w = 0,
                h = 0,
            },
            min_spacing = {
                w = 0,
                h = 0,
            },
            rows = 0,
            columns = 0,
            effective_spacing = {
                w = 0,
                h = 0,
            }
        },
        view = { -- 1-based indices into the "playlist" array
            first = 0, -- must be equal to N*columns
            last = 0, -- must be > first and <= first + rows*columns
        },
        overlays = {
            active = {}, -- array of <=64 strings indicating the file associated to the current thumbnail (empty if no file)
            missing = {}, -- stuff
        },
        selection = 0,
        pending = {
            selection = nil,
            geometry_changed = false,
            deletion = false,
        },
        config = {
            scrollbar = true,
            scrollbar_left_side = true,
            scrollbar_min_size = 10,
            max_items = 64,
            show_placeholders = true,
            always_show_placeholders = false,
            placeholder_color = "222222",
            frame_roundness = 0,
            show_text = true,
            text_size = 28,
            generate_thumbnails_with_mpv = false,
        },
        ass = {
            background = "",
            selection = "",
            scrollbar = "",
            placeholders = "",
        },
        generators = {}, -- list of generator scripts
        
        too_small = function() return end,
        item_to_overlay_path = function(index, item) return "" end,
        item_to_thumbnail_params = function(index, item) return "", 0 end,
        item_to_text = function(index, item) return "" end,
        item_to_border = function(index, item) return 0, "" end,
        idle
    }, gallery_mt)
end

function gallery_mt.show_overlay(gallery, index_1, thumb_path)
    local g = gallery.geometry
    gallery.overlays.active[index_1] = true
    local index_0 = index_1 - 1
    mp.commandv("overlay-add",
        tostring(index_0),
        tostring(math.floor(g.draw_area.x + 0.5 + g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (index_0 % g.columns))),
        tostring(math.floor(g.draw_area.y + 0.5 + g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(index_0 / g.columns))),
        thumb_path,
        "0",
        "bgra",
        tostring(g.item_size.w),
        tostring(g.item_size.h),
        tostring(4*g.item_size.w))
    mp.osd_message("", 0.01)
end

function gallery_mt.remove_overlay(gallery, index_1)
    gallery.overlays.missing[index_1] = nil
    if not gallery.overlays.active[index_1] then return end
    gallery.overlays.active[index_1] = false
    mp.command("overlay-remove " .. index_1 - 1)
    mp.osd_message("", 0.01)
end

function gallery_mt.remove_overlays(gallery)
    for i = 1, 64 do
        gallery:remove_overlay(i)
    end
end

function file_exists(path)
    if utils.file_info then -- 0.28+
        local info = utils.file_info(path)
        return info ~= nil and info.is_file
    else
        local f = io.open(path, "r")
        if f ~= nil then
            io.close(f)
            return true
        end
        return false
    end
end


function gallery_mt.refresh_overlays(gallery, force)
    local todo = {}
    local o = gallery.overlays
    local g = gallery.geometry
    o.missing = {}
    for i = 1, 64 do
        local index = gallery.view.first + i - 1
        if index <= gallery.view.last then
            local thumb_path = gallery.item_to_overlay_path(index, gallery.items[index])
            if file_exists(thumb_path) then
                gallery:show_overlay(i, thumb_path)
            else
                gallery:remove_overlay(i)
                o.missing[i] = { view_index = i, thumb_path = thumb_path }
                todo[#todo + 1] = { index = index, output = thumb_path }
            end
        else
            gallery:remove_overlay(i)
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
                tostring(g.item_size.w),
                tostring(g.item_size.h),
                time,
                t.output,
                "false", -- accurate
                gallery.config.generate_thumbnails_with_mpv and "true" or "false"
            )
        end
    end
end

function gallery_mt.select_under_cursor(gallery)
    -- TODO fixup
    local g = gallery.geometry
    local mx, my = mp.get_mouse_pos()
    if mx < 0 or my < 0 or mx > g.draw_area.w or my > g.draw_area.h then return end
    mx, my = mx - g.effective_spacing.w, my - g.effective_spacing.h
    local on_column = (mx % (g.item_size.w + g.effective_spacing.w)) < g.item_size.w
    local on_row = (my % (g.item_size.h + g.effective_spacing.h)) < g.item_size.h
    if on_column and on_row then
        local column = math.floor(mx / (g.item_size.w + g.effective_spacing.w))
        local row = math.floor(my / (g.item_size.h + g.effective_spacing.h))
        local new_sel = view.first + row * g.columns + column
        if new_sel > view.last then return end
        if selection == new_sel then
            quit_gallery_view(selection)
        else
            selection = new_sel
            pending.selection = new_sel
            ass_show(true, false, false)
        end
    end
end

function gallery_mt.compute_geometry(gallery)
    local g = gallery.geometry
    g.rows = math.floor((g.draw_area.h - g.min_spacing.h) / (g.item_size.h + g.min_spacing.h))
    g.columns = math.floor((g.draw_area.w - g.min_spacing.w) / (g.item_size.w + g.min_spacing.w))
    if (g.rows * g.columns > gallery.config.max_items) then
        local r = math.sqrt(g.rows * g.columns / gallery.config.max_items)
        g.rows = math.floor(g.rows / r)
        g.columns = math.floor(g.columns / r)
    end
    if g.rows <= 0 or g.columns <= 0 then return false end
    g.effective_spacing.w = (g.draw_area.w - g.columns * g.item_size.w) / (g.columns + 1)
    g.effective_spacing.h = (g.draw_area.h - g.rows * g.item_size.h) / (g.rows + 1)
    return true
end

-- makes sure that view.first and view.last are valid with regards to the playlist
-- and that selection is within the view
-- to be called after the playlist, view or selection was modified somehow
function gallery_mt.ensure_view_valid(gallery)
    local v = gallery.view
    local g = gallery.geometry
    local selection_row = math.floor((gallery.selection - 1) / g.columns)
    local max_thumbs = g.rows * g.columns

    if v.last >= #gallery.items then
        v.last = #gallery.items
        last_row = math.floor((v.last - 1) / g.columns)
        first_row = math.max(0, last_row - g.rows + 1)
        v.first = 1 + first_row * g.columns
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
        return
    end

    if gallery.selection < v.first then
        -- the selection is now on the first line
        v.first = selection_row * g.columns + 1
        v.last = math.min(#gallery.items, v.first + max_thumbs - 1)
    elseif gallery.selection > v.last then
        -- the selection is now on the last line
        v.last = (selection_row + 1) * g.columns
        v.first = math.max(1, v.last - max_thumbs + 1)
        v.last = math.min(#gallery.items, v.last)
    end
end

-- ass related stuff
function gallery_mt.refresh_placeholders(gallery)
    if not gallery.config.show_placeholders then return end
    local g = gallery.geometry
    local a = assdraw.ass_new()
    a:new_event()
    a:append('{\\bord0}')
    a:append('{\\shad0}')
    a:append('{\\1c&' ..'222222' .. '}') -- TODO
    a:pos(0, 0)
    a:draw_start()
    for i = 0, gallery.view.last - gallery.view.first do
        if gallery.config.always_show_placeholders or not gallery.overlays.active[i + 1] then
            local x = g.draw_area.x + g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (i % g.columns)
            local y = g.draw_area.y + g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(i / g.columns)
            a:rect_cw(x, y, x + g.item_size.w, y + g.item_size.h)
        end
    end
    a:draw_stop()
    gallery.ass.placeholders = a.text
end

function gallery_mt.refresh_scrollbar(gallery)
    if not gallery.config.scrollbar then return end
    gallery.ass.scrollbar = ""
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
    local y1 = g.draw_area.y + g.effective_spacing.h + before * (g.draw_area.h - 2 * g.effective_spacing.h)
    local y2 = g.draw_area.y + g.draw_area.h - (g.effective_spacing.h + after * (g.draw_area.h - 2 * g.effective_spacing.h))
    local x1, x2
    if gallery.config.scrollbar_left_side then
        x1, x2 = g.draw_area.x + 4, g.draw_area.x + 8
    else
        x1, x2 = g.draw_area.x + g.draw_area.w - 8, g.draw_area.x + g.draw_area.w - 4
    end
    local scrollbar = assdraw.ass_new()
    scrollbar:new_event()
    scrollbar:append('{\\bord0}')
    scrollbar:append('{\\shad0}')
    scrollbar:append('{\\1c&AAAAAA&}')
    scrollbar:pos(0, 0)
    scrollbar:draw_start()
    scrollbar:round_rect_cw(x1, y1, x2, y2, gallery.config.frame_roundness)
    scrollbar:draw_stop()
    gallery.ass.scrollbar = scrollbar.text
end

function gallery_mt.refresh_selection(gallery)
    local selection_ass = assdraw.ass_new()
    local v = gallery.view
    local g = gallery.geometry
    local draw_frame = function(index, size, color)
        if index < v.first or index > v.last then return end
        local i = index - v.first
        local x = g.draw_area.x + g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (i % g.columns)
        local y = g.draw_area.y + g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(i / g.columns)
        selection_ass:new_event()
        selection_ass:append('{\\bord' .. size ..'}')
        selection_ass:append('{\\3c&'.. color ..'&}')
        selection_ass:append('{\\1a&FF&}')
        selection_ass:pos(0, 0)
        selection_ass:draw_start()
        selection_ass:round_rect_cw(x, y, x + g.item_size.w, y + g.item_size.h, gallery.config.frame_roundness)
        selection_ass:draw_stop()
    end
    for i = v.first, v.last do
        local size, color = gallery.item_to_border(i, gallery.items[i])
        if size > 0 then
            draw_frame(i, size, color)
        end
    end

    local text, align = gallery.item_to_text(gallery.selection, gallery.items[gallery.selection])
    gallery.ass.selection = ""
    if text ~= "" then
        selection_ass:new_event()
        local i = (gallery.selection - v.first)
        local an = 5
        local x = g.draw_area.x + g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (i % g.columns) + g.item_size.w / 2
        local y = g.draw_area.y + g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(i / g.columns) + g.item_size.h + g.effective_spacing.h / 2
        if align then
            local col = i % g.columns
            if g.columns > 1 then
                if col == 0 then
                    x = x - g.item_size.w / 2
                    an = 4
                elseif col == g.columns - 1 then
                    x = x + g.item_size.w / 2
                    an = 6
                end
            end
        end
        selection_ass:an(an)
        selection_ass:pos(x, y)
        selection_ass:append(string.format("{\\fs%d}", gallery.config.text_size))
        selection_ass:append("{\\bord0}")
        selection_ass:append(text)
        gallery.ass.selection = selection_ass.text
    end
end

function gallery_mt.ass_show(gallery, selection, scrollbar, placeholders)
    if selection then gallery:refresh_selection() end
    if scrollbar then gallery:refresh_scrollbar() end
    if placeholders then gallery:refresh_placeholders() end
    local merge = function(a, b)
        return b ~= "" and (a .. "\n" .. b) or a
    end
    mp.set_osd_ass(gallery.geometry.window.w, gallery.geometry.window.h,
        merge(merge(gallery.ass.selection, gallery.ass.scrollbar), gallery.ass.placeholders)
    )
end

function gallery_mt.ass_hide()
    mp.set_osd_ass(1280, 720, "")
end

function gallery_mt.idle_handler(gallery)
    if gallery.pending.selection then
        gallery.selection = gallery.pending.selection
        gallery.pending.selection = nil
        gallery:ensure_view_valid()
        gallery:refresh_overlays(false)
        gallery:ass_show(true, true, true)
    end
    if gallery.pending.geometry_changed then
        gallery.pending.geometry_changed = false
        if not gallery:compute_geometry() then
            --quit_gallery_view(nil)
            -- TODO
            return
        end
        gallery:ensure_view_valid()
        gallery:refresh_overlays(true)
        gallery:ass_show(true, true, true)
    end
end

function gallery_mt.items_changed(gallery)
    gallery:ensure_view_valid()
    gallery:refresh_overlays(false)
    gallery:ass_show(true, true, true)
end

function gallery_mt.thumbnail_generated(gallery, thumb_path)
    if not gallery.active then return end
    for index, missing in pairs(gallery.overlays.missing) do
        if missing.thumb_path == thumb_path then
            gallery:show_overlay(missing.view_index, thumb_path)
            if not gallery.config.always_show_placeholders then
                gallery:ass_show(false, false, true)
            end
            gallery.overlays.missing[index] = nil
            return
        end
    end
end

function gallery_mt.add_generator(gallery, generator_name)
    for _, g in ipairs(gallery.generators) do
        if generator_name == g then return end
    end
    gallery.generators[#gallery.generators + 1] = generator_name
end

function gallery_mt.enough_space(gallery)
    if gallery.geometry.draw_area.w < gallery.geometry.item_size.w + 2 * gallery.geometry.min_spacing.w then return false end
    if gallery.geometry.draw_area.h < gallery.geometry.item_size.h + 2 * gallery.geometry.min_spacing.h then return false end
    return true
end

function gallery_mt.activate(gallery, selection)
    if gallery.active then return false end
    gallery.selection = selection
    if not gallery:compute_geometry() then return false end
    gallery:ensure_view_valid()
    gallery:refresh_overlays(true)
    gallery:ass_show(true, true, true)
    gallery.idle = function() gallery:idle_handler() end
    mp.register_idle(gallery.idle)
    gallery.active = true
    return true
end

function gallery_mt.deactivate(gallery)
    if not gallery.active then return end
    gallery:remove_overlays()
    gallery:ass_hide()
    mp.unregister_idle(gallery.idle)
    gallery.active = false
end

return {gallery_new = gallery_new}

