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

ON_WINDOWS = (package.config:sub(1,1) ~= "/")

-- global variables

flags = {}
resume = {}
did_pause = false
hash_cache = {}
playlist_pos = 0

bindings = {}
bindings_repeat = {}

compute_geometry = function(ww, wh) end

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
            local args = ON_WINDOWS and { "mkdir", thumbs_dir } or { "mkdir", "-p", thumbs_dir }
            utils.subprocess({ args = args, playback_only = false })
        else
            msg.error(string.format("Thumbnail directory \"%s\" does not exist", thumbs_dir))
        end
    end

    compute_geometry = get_geometry_function()
    reload_bindings()
    if gallery.active then
        local ww, wh = mp.get_osd_size()
        compute_geometry(ww, wh)
        gallery:ass_refresh(true, true, true, true)
    end
end
options.read_options(opts, mp.get_script_name(), reload_config)



local sha256
--[[
minified code below is a combination of:
-sha256 implementation from
http://lua-users.org/wiki/SecureHashAlgorithm
-lua implementation of bit32 (used as fallback on lua5.1) from
https://www.snpedia.com/extensions/Scribunto/engines/LuaCommon/lualib/bit32.lua
both are licensed under the MIT below:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]
do local b,c,d,e,f;if bit32 then b,c,d,e,f=bit32.band,bit32.rrotate,bit32.bxor,bit32.rshift,bit32.bnot else f=function(g)g=math.floor(tonumber(g))%0x100000000;return(-g-1)%0x100000000 end;local h={[0]={[0]=0,0,0,0},[1]={[0]=0,1,0,1},[2]={[0]=0,0,2,2},[3]={[0]=0,1,2,3}}local i={[0]={[0]=0,1,2,3},[1]={[0]=1,0,3,2},[2]={[0]=2,3,0,1},[3]={[0]=3,2,1,0}}local function j(k,l,m,n,o)for p=1,m do l[p]=math.floor(tonumber(l[p]))%0x100000000 end;local q=1;local r=0;for s=0,31,2 do local t=n;for p=1,m do t=o[t][l[p]%4]l[p]=math.floor(l[p]/4)end;r=r+t*q;q=q*4 end;return r end;b=function(...)return j('band',{...},select('#',...),3,h)end;d=function(...)return j('bxor',{...},select('#',...),0,i)end;e=function(g,u)g=math.floor(tonumber(g))%0x100000000;u=math.floor(tonumber(u))u=math.min(math.max(-32,u),32)return math.floor(g/2^u)%0x100000000 end;c=function(g,u)g=math.floor(tonumber(g))%0x100000000;u=-math.floor(tonumber(u))%32;local g=g*2^u;return g%0x100000000+math.floor(g/0x100000000)end end;local v={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}local function w(n)return string.gsub(n,".",function(t)return string.format("%02x",string.byte(t))end)end;local function x(y,z)local n=""for p=1,z do local A=y%256;n=string.char(A)..n;y=(y-A)/256 end;return n end;local function B(n,p)local z=0;for p=p,p+3 do z=z*256+string.byte(n,p)end;return z end;local function C(D,E)local F=-(E+1+8)%64;E=x(8*E,8)D=D.."\128"..string.rep("\0",F)..E;return D end;local function G(H)H[1]=0x6a09e667;H[2]=0xbb67ae85;H[3]=0x3c6ef372;H[4]=0xa54ff53a;H[5]=0x510e527f;H[6]=0x9b05688c;H[7]=0x1f83d9ab;H[8]=0x5be0cd19;return H end;local function I(D,p,H)local J={}for K=1,16 do J[K]=B(D,p+(K-1)*4)end;for K=17,64 do local L=J[K-15]local M=d(c(L,7),c(L,18),e(L,3))L=J[K-2]local N=d(c(L,17),c(L,19),e(L,10))J[K]=J[K-16]+M+J[K-7]+N end;local O,s,t,P,Q,R,S,T=H[1],H[2],H[3],H[4],H[5],H[6],H[7],H[8]for p=1,64 do local M=d(c(O,2),c(O,13),c(O,22))local U=d(b(O,s),b(O,t),b(s,t))local V=M+U;local N=d(c(Q,6),c(Q,11),c(Q,25))local W=d(b(Q,R),b(f(Q),S))local X=T+N+W+v[p]+J[p]T=S;S=R;R=Q;Q=P+X;P=t;t=s;s=O;O=X+V end;H[1]=b(H[1]+O)H[2]=b(H[2]+s)H[3]=b(H[3]+t)H[4]=b(H[4]+P)H[5]=b(H[5]+Q)H[6]=b(H[6]+R)H[7]=b(H[7]+S)H[8]=b(H[8]+T)end;local function Y(H)return w(x(H[1],4)..x(H[2],4)..x(H[3],4)..x(H[4],4)..x(H[5],4)..x(H[6],4)..x(H[7],4)..x(H[8],4))end;local Z={}sha256=function(D)D=C(D,#D)local H=G(Z)for p=1,#D,64 do I(D,p,H)end;return Y(H)end end
-- end of sha code

gallery.ass_show = function(new_ass)
    ass_changed = true
    ass = new_ass
end
gallery.item_to_overlay_path = function(index, item)
    local filename = item.filename
    local filename_hash = hash_cache[filename]
    if filename_hash == nil then
        filename_hash = string.sub(sha256(normalize_path(filename)), 1, 12)
        hash_cache[filename] = filename_hash
    end
    local thumb_filename = string.format("%s_%d_%d_%s", filename_hash, gallery.geometry.thumbnail_size[1], gallery.geometry.thumbnail_size[2], string.gsub(opts.take_thumbnail_at, '%%', 'p'))
    return utils.join_path(thumbs_dir, thumb_filename)
end
gallery.item_to_thumbnail_params = function(index, item)
    return item.filename, opts.take_thumbnail_at
end
function blend_colors(colors)
    if #colors == 1 then return colors[1] end
    local comp1 = 0
    local comp2 = 0
    local comp3 = 0
    for _, val in ipairs(colors) do
        comp1 = comp1 + tonumber(string.sub(val, 1, 2), 16)
        comp2 = comp2 + tonumber(string.sub(val, 3, 4), 16)
        comp3 = comp3 + tonumber(string.sub(val, 5, 6), 16)
    end
    return string.format("%02x%02x%02x", comp1 / #colors, comp2 / #colors, comp3 / #colors)
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
        return size, blend_colors(colors)
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

function get_geometry_function()
    local geometry_functions = loadstring(string.format([[
    return {
    function(ww, wh, gx, gy, gw, gh, sw, sh, tw, th)
        return %s
    end,
    function(ww, wh, gx, gy, gw, gh, sw, sh, tw, th)
        return %s
    end,
    function(ww, wh, gx, gy, gw, gh, sw, sh, tw, th)
        return %s
    end,
    function(ww, wh, gx, gy, gw, gh, sw, sh, tw, th)
        return %s
    end
    }]], opts.gallery_position, opts.gallery_size, opts.min_spacing, opts.thumbnail_size))()

    local names = { "gallery_position", "gallery_size", "min_spacing", "thumbnail_size" }
    local order = {} -- the order in which the 4 properties should be computed, based on inter-dependencies

    -- build the dependency matrix
    local patterns = { "g[xy]", "g[wh]", "s[wh]", "t[wh]" }
    local deps = {}
    for i = 1,4 do
        for j = 1,4 do
            local i_depends_on_j = (string.find(opts[names[i]], patterns[j]) ~= nil)
            if i == j and i_depends_on_j then
                msg.error(names[i] .. " depends on itself")
                return
            end
            deps[i * 4 + j] = i_depends_on_j
        end
    end

    local has_deps = function(index)
        for j = 1,4 do
            if deps[index * 4 + j] then
                return true
            end
        end
        return false
    end
    local num_resolved = 0
    local resolved = { false, false, false, false }
    while true do
        local resolved_one = false
        for i = 1, 4 do
            if resolved[i] then
                -- nothing to do
            elseif not has_deps(i) then
                order[#order + 1] = i
                -- since i has no deps, anything that depends on it might as well not
                for j = 1, 4 do
                    deps[j * 4 + i] = false
                end
                resolved[i] = true
                resolved_one = true
                num_resolved = num_resolved + 1
            end
        end
        if num_resolved == 4 then
            break
        elseif not resolved_one then
            local str = ""
            for index, resolved in ipairs(resolved) do
                if not resolved then
                    str = (str == "" and "" or (str .. ", ")) .. names[index]
                end
            end
            msg.error("Circular dependency between " .. str)
            return
        end
    end

    return function(window_width, window_height)
        local new_geom = {
             gallery_position = {},
             gallery_size = {},
             min_spacing = {},
             thumbnail_size = {},
         }
        for _, index in ipairs(order) do
            new_geom[names[index]] = geometry_functions[index](
                window_width, window_height,
                new_geom.gallery_position[1], new_geom.gallery_position[2],
                new_geom.gallery_size[1], new_geom.gallery_size[2],
                new_geom.min_spacing[1], new_geom.min_spacing[2],
                new_geom.thumbnail_size[1], new_geom.thumbnail_size[2]
            )
            -- extrawuerst
            if opts.show_text and names[index] == "min_spacing" then
                new_geom.min_spacing[2] = math.max(opts.text_size, new_geom.min_spacing[2])
            elseif names[index] == "thumbnail_size" then
                new_geom.thumbnail_size[1] = math.floor(new_geom.thumbnail_size[1])
                new_geom.thumbnail_size[2] = math.floor(new_geom.thumbnail_size[2])
            end
        end
        gallery:set_geometry(
            new_geom.gallery_position[1], new_geom.gallery_position[2],
            new_geom.gallery_size[1], new_geom.gallery_size[2],
            new_geom.min_spacing[1], new_geom.min_spacing[2],
            new_geom.thumbnail_size[1], new_geom.thumbnail_size[2]
        )
    end
end

function normalize_path(path)
    if string.find(path, "://") then
        return path
    end
    path = utils.join_path(utils.getcwd(), path)
    if ON_WINDOWS then
        path = string.gsub(path, "\\", "/")
    end
    path = string.gsub(path, "/%./", "/")
    local n
    repeat
        path, n = string.gsub(path, "/[^/]*/%.%./", "/", 1)
    until n == 0
    return path
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
