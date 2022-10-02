--[[
mpv-gallery-view | https://github.com/occivink/mpv-gallery-view

This mpv script generates and displays an overview of the current playlist with thumbnails.

File placement: scripts/playlist-view.lua
Settings: script-opts/playlist_view.conf
Requires: script-modules/gallery-module.lua
Default keybinding: g script-binding playlist-view-toggle
]]

local utils = require 'mp.utils'
local msg = require 'mp.msg'
local options = require 'mp.options'

package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path
require 'gallery'
local sha256 = require 'sha256'
local gallery_utils = require 'gallery-utils'

ON_WINDOWS = (package.config:sub(1,1) ~= "/")

-- global variables

flags = {}
resume = {}
did_pause = false
hash_cache = {}
playlist_pos = 0

bindings = {}
bindings_repeat = {}

compute_geometry = nil -- function used to compute based on options

ass_changed = false
ass = ""
geometry_changed = false
pending_selection = nil

thumb_dir = ""

gallery = gallery_new()
gallery.config.always_show_placeholders = true
gallery.config.accurate = false

opts = {
    thumbs_dir = ON_WINDOWS and "%APPDATA%\\mpv\\gallery-thumbs-dir" or "~/.cache/thumbnails/mpv-gallery/",
    generate_thumbnails_with_mpv = ON_WINDOWS,
    mkdir_thumbs = true,

    gallery_position = "{ (ww - gw) / 2, (wh - gh) / 2}",
    gallery_size = "{ 9 * ww / 10, 9 * wh / 10 }",
    min_spacing = "{ 15, 15 }",
    thumbnail_size = "(ww * wh <= 1366 * 768) and {192, 108} or {288, 162}",
    max_thumbnails = 64,

    take_thumbnail_at = "20%",

    load_file_on_toggle_off = false,
    close_on_load_file = true,
    pause_on_start = true,
    resume_on_stop = "only-if-did-pause",
    follow_playlist_position = false,
    remember_time_position = true,

    start_on_mpv_startup = false,
    start_on_file_end = true,

    show_text = true,
    show_title = true,
    strip_directory = true,
    strip_extension = true,
    text_size = 28,

    background_color = "333333",
    background_opacity = "33",
    normal_border_color = "BBBBBB",
    normal_border_size = 1,
    selected_border_color = "E5E4E5",
    selected_border_size = 6,
    highlight_active = true,
    active_border_color = "EBC5A7",
    active_border_size = 4,
    flagged_border_color = "96B58D",
    flagged_border_size = 4,
    placeholder_color = "222222",

    command_on_open = "",
    command_on_close = "",

    flagged_file_path = "./mpv_gallery_flagged",

    mouse_support = true,
    UP        = "UP",
    DOWN      = "DOWN",
    LEFT      = "LEFT",
    RIGHT     = "RIGHT",
    PAGE_UP   = "PGUP",
    PAGE_DOWN = "PGDWN",
    FIRST     = "HOME",
    LAST      = "END",
    RANDOM    = "r",
    ACCEPT    = "ENTER",
    CANCEL    = "ESC",
    REMOVE    = "DEL",
    FLAG      = "SPACE",
}
function reload_config()
    gallery.config.background_color = opts.background_color
    gallery.config.background_opacity = opts.background_opacity
    gallery.config.max_thumbnails = math.min(opts.max_thumbnails, 64)
    gallery.config.placeholder_color = opts.placeholder_color
    gallery.config.text_size = opts.text_size
    gallery.config.generate_thumbnails_with_mpv = opts.generate_thumbnails_with_mpv
    if ON_WINDOWS then
        thumbs_dir = string.gsub(opts.thumbs_dir, "^%%APPDATA%%", os.getenv("APPDATA") or "%APPDATA%")
    else
        thumbs_dir = string.gsub(opts.thumbs_dir, "^~", os.getenv("HOME") or "~")
    end
    local res = utils.file_info(thumbs_dir)
    if not res or not res.is_dir then
        if opts.mkdir_thumbs then
            utils.subprocess({ args = { "mkdir", thumbs_dir } })
        else
            msg.error(string.format("Thumbnail directory \"%s\" does not exist", thumbs_dir))
        end
    end

    compute_geometry = make_gallery_geometry_function(opts.gallery_position, opts.gallery_size, opts.min_spacing, opts.thumbnail_size)
    reload_bindings()
    if gallery.active then
        apply_geometry()
        gallery:ass_refresh(true, true, true, true)
    end
end
options.read_options(opts, mp.get_script_name(), reload_config)

function apply_geometry()
    if compute_geometry == nil then return end
    local ww, wh = mp.get_osd_size()
    local new_geom = compute_geometry(ww, wh, opts.show_text and opts.text_size)
    gallery:set_geometry(
        new_geom.position[1], new_geom.position[2],
        new_geom.size[1], new_geom.size[2],
        new_geom.min_spacing[1], new_geom.min_spacing[2],
        new_geom.thumbnail_size[1], new_geom.thumbnail_size[2]
    )
end


gallery.ass_show = function(new_ass)
    ass_changed = true
    ass = new_ass
end
gallery.item_to_overlay_path = function(index, item)
    local filename = item.filename
    local filename_hash = hash_cache[filename]
    if filename_hash == nil then
        local norm = gallery_utils.normalize_path(utils.getcwd(), filename)
        filename_hash = string.sub(sha256.hash(norm), 1, 12)
        hash_cache[filename] = filename_hash
    end
    local thumb_filename = string.format("%s_%d_%d_%s", filename_hash, gallery.geometry.thumbnail_size[1], gallery.geometry.thumbnail_size[2], string.gsub(opts.take_thumbnail_at, '%%', 'p'))
    return utils.join_path(thumbs_dir, thumb_filename)
end
gallery.item_to_thumbnail_params = function(index, item)
    return item.filename, opts.take_thumbnail_at
end
gallery.item_to_border = function(index, item)
    local size = 0
    colors = {}
    if flags[item.filename] then
        colors[#colors + 1] = opts.flagged_border_color
        size = math.max(size, opts.flagged_border_size)
    end
    if index == gallery.selection then
        colors[#colors + 1] = opts.selected_border_color
        size = math.max(size, opts.selected_border_size)
    end
    if opts.highlight_active and index == playlist_pos then
        colors[#colors + 1] = opts.active_border_color
        size = math.max(size, opts.active_border_size)
    end
    if #colors == 0 then
        return opts.normal_border_size, opts.normal_border_color
    else
        return size, gallery_utils.blend_colors(colors)
    end
end
gallery.item_to_text = function(index, item)
    if not opts.show_text or index ~= gallery.selection then return "", false end
    local f
    if opts.show_title and item.title then
        f = item.title
    else
        f = item.filename
        if opts.strip_directory then
            if ON_WINDOWS then
                f = string.match(f, "([^\\/]+)$") or f
            else
                f = string.match(f, "([^/]+)$") or f
            end
        end
        if opts.strip_extension then
            f = string.match(f, "(.+)%.[^.]+$") or f
        end
    end
    return f, true
end


function setup_ui_handlers()
    for key, func in pairs(bindings_repeat) do
        mp.add_forced_key_binding(key, "playlist-view-"..key, func, {repeatable = true})
    end
    for key, func in pairs(bindings) do
        mp.add_forced_key_binding(key, "playlist-view-"..key, func)
    end
end

function teardown_ui_handlers()
    for key, _ in pairs(bindings_repeat) do
        mp.remove_key_binding("playlist-view-"..key)
    end
    for key, _ in pairs(bindings) do
        mp.remove_key_binding("playlist-view-"..key)
    end
end

function reload_bindings()
    if gallery.active then
        teardown_ui_handlers()
    end

    bindings = {}
    bindings_repeat = {}

    local increment_func = function(increment, clamp)
        local new = (pending_selection or gallery.selection) + increment
        if new <= 0 or new > #gallery.items then
            if not clamp then return end
            new = math.max(1, math.min(new, #gallery.items))
        end
        pending_selection = new
    end

    bindings[opts.FIRST]  = function() pending_selection = 1 end
    bindings[opts.LAST]   = function() pending_selection = #gallery.items end
    bindings[opts.ACCEPT] = function()
        load_selection()
        if opts.close_on_load_file then stop() end
    end
    bindings[opts.CANCEL] = function() stop() end
    bindings[opts.FLAG]   = function()
        local name = gallery.items[gallery.selection].filename
        if flags[name] == nil then
            flags[name] = true
        else
            flags[name] = nil
        end
        gallery:ass_refresh(true, false, false, false)
    end
    if opts.mouse_support then
        bindings["MBTN_LEFT"]  = function()
            local index = gallery:index_at(mp.get_mouse_pos())
            if not index then return end
            if index == gallery.selection then
                load_selection()
                if opts.close_on_load_file then stop() end
            else
                pending_selection= index
            end
        end
        bindings["WHEEL_UP"]   = function() increment_func(- gallery.geometry.columns, false) end
        bindings["WHEEL_DOWN"] = function() increment_func(  gallery.geometry.columns, false) end
    end

    bindings_repeat[opts.UP]        = function() increment_func(- gallery.geometry.columns, false) end
    bindings_repeat[opts.DOWN]      = function() increment_func(  gallery.geometry.columns, false) end
    bindings_repeat[opts.LEFT]      = function() increment_func(- 1, false) end
    bindings_repeat[opts.RIGHT]     = function() increment_func(  1, false) end
    bindings_repeat[opts.PAGE_UP]   = function() increment_func(- gallery.geometry.columns * gallery.geometry.rows, true) end
    bindings_repeat[opts.PAGE_DOWN] = function() increment_func(  gallery.geometry.columns * gallery.geometry.rows, true) end
    bindings_repeat[opts.RANDOM]    = function() pending_selection = math.random(1, #gallery.items) end
    bindings_repeat[opts.REMOVE]    = function()
        local s = gallery.selection
        mp.commandv("playlist-remove", s - 1)
        gallery:set_selection(s + (s == #gallery.items and -1 or 1))
    end

    if gallery.active then
        setup_ui_handlers()
    end
end

function playlist_changed(key, playlist)
    if not gallery.active then return end
    local did_change = function()
        if #gallery.items ~= #playlist then return true end
        for i = 1, #gallery.items do
            if gallery.items[i].filename ~= playlist[i].filename then return true end
        end
        return false
    end
    if not did_change() then return end
    if #playlist == 0 then
        stop()
        return
    end
    local selection_filename = gallery.items[gallery.selection].filename
    gallery.items = playlist
    local new_selection = math.max(1, math.min(gallery.selection, #gallery.items))
    for i, f in ipairs(gallery.items) do
        if selection_filename == f.filename then
            new_selection = i
            break
        end
    end
    gallery:items_changed(new_selection)
end

function playlist_pos_changed(_, val)
    playlist_pos = val
    if opts.highlight_active then
        gallery:ass_refresh(true, false, false, false)
    end
    if opts.follow_playlist_position then
        pending_selection = val
    end
end

function idle()
    if pending_selection then
        gallery:set_selection(pending_selection)
        pending_selection = nil
    end
    if ass_changed or geometry_changed then
        local ww, wh = mp.get_osd_size()
        if geometry_changed then
            geometry_changed = false
            compute_geometry(ww, wh)
        end
        if ass_changed then
            ass_changed = false
            mp.set_osd_ass(ww, wh, ass)
        end
    end
end

function mark_geometry_stale()
    geometry_changed = true
end

function start()
    if gallery.active then return end
    playlist = mp.get_property_native("playlist")
    if #playlist == 0 then return end
    gallery.items = playlist

    local ww, wh = mp.get_osd_size()
    compute_geometry(ww, wh)

    playlist_pos = mp.get_property_number("playlist-pos-1")
    gallery:set_selection(playlist_pos or 1)
    if not gallery:activate() then return end

    did_pause = false
    if opts.pause_on_start and not mp.get_property_bool("pause", false) then
        mp.set_property_bool("pause", true)
        did_pause = true
    end
    if opts.command_on_open ~= "" then
        mp.command(opts.command_on_open)
    end
    mp.observe_property("playlist-pos-1", "native", playlist_pos_changed)
    mp.observe_property("playlist", "native", playlist_changed)
    mp.observe_property("osd-width", "native", mark_geometry_stale)
    mp.observe_property("osd-height", "native", mark_geometry_stale)
    mp.register_idle(idle)
    idle()

    setup_ui_handlers()
end

function load_selection()
    local sel = mp.get_property_number("playlist-pos-1", -1)
    if sel == gallery.selection then return end
    if opts.remember_time_position then
        if sel then
            local time = mp.get_property_number("time-pos")
            if time and time > 1 then
                resume[gallery.items[sel].filename] = time
            end
        end
        mp.set_property("playlist-pos-1", gallery.selection)
        local time = resume[gallery.items[gallery.selection].filename]
        if not time then return end
        local func
        func = function()
            mp.commandv("osd-msg-bar", "seek", time, "absolute")
            mp.unregister_event(func)
        end
        mp.register_event("file-loaded", func)
    else
        mp.set_property("playlist-pos-1", gallery.selection)
    end
end

function stop()
    if not gallery.active then return end
    if opts.resume_on_stop == "yes" or (opts.resume_on_stop == "only-if-did-pause" and did_pause) then
        mp.set_property_bool("pause", false)
    end
    if opts.command_on_close ~= "" then
        mp.command(opts.command_on_close)
    end
    mp.unobserve_property(playlist_pos_changed)
    mp.unobserve_property(playlist_changed)
    mp.unobserve_property(mark_geometry_stale)
    mp.unregister_idle(idle)
    teardown_ui_handlers()
    gallery:deactivate()
    idle()
end

function toggle()
    if not gallery.active then
        start()
    else
        if opts.load_file_on_toggle_off then load_selection() end
        stop()
    end
end

mp.register_script_message("thumbnail-generated", function(thumb_path)
     gallery:thumbnail_generated(thumb_path)
end)

mp.register_script_message("thumbnails-generator-broadcast", function(generator_name)
     gallery:add_generator(generator_name)
end)

function write_flag_file()
    if next(flags) == nil then return end
    local out = io.open(opts.flagged_file_path, "w")
    for f, _ in pairs(flags) do
        out:write(f .. "\n")
    end
    out:close()
end
mp.register_event("shutdown", write_flag_file)

reload_config()

if opts.start_on_file_end then
    mp.observe_property("eof-reached", "bool", function(_, val)
        if val and mp.get_property_number("playlist-count") > 1 then
            start()
        end
    end)
end

if opts.start_on_mpv_startup then
    local autostart
    autostart = function()
        if mp.get_property_number("playlist-count") == 0 then return end
        if mp.get_property_number("osd-width") <= 0 then return end
        start()
        mp.unobserve_property(autostart)
    end
    mp.observe_property("playlist-count", "number", autostart)
    mp.observe_property("osd-width", "number", autostart)
end

mp.add_key_binding(nil, "playlist-view-open", function() start() end)
mp.add_key_binding(nil, "playlist-view-close", stop)
mp.add_key_binding('g', "playlist-view-toggle", toggle)
mp.add_key_binding(nil, "playlist-view-load-selection", load_selection)
mp.add_key_binding(nil, "playlist-view-write-flag-file", write_flag_file)
