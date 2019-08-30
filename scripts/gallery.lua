local utils = require 'mp.utils'
local msg = require 'mp.msg'
local gallery = require 'lib/gallery'

local on_windows = (package.config:sub(1,1) ~= "/")

local opts = {
    thumbs_dir = on_windows and "%APPDATA%\\mpv\\gallery-thumbs-dir" or ".",
    generate_thumbnails_with_mpv = false,

    thumbnail_width = 192,
    thumbnail_height = 108,
    dynamic_thumbnail_size = "",

    take_thumbnail_at = "20%",

    resume_when_picking = true,
    start_gallery_on_startup = false,
    start_gallery_on_file_end = false,
    toggle_behaves_as_accept = true,

    margin_x = 15,
    margin_y = 15,
    max_thumbnails = 64,

    show_scrollbar = true,
    scrollbar_side = "left",
    scrollbar_min_size = 10,

    show_placeholders = true,
    placeholder_color = "222222",
    always_show_placeholders = false,
    background = "0.1",

    show_filename = true,
    show_title = true,
    strip_directory = true,
    strip_extension = true,
    text_size = 28,

    selected_frame_color = "DDDDDD",
    frame_roundness = 5,
    flagged_frame_color = "5B9769",
    selected_flagged_frame_color = "BAFFCA",
    flagged_file_path = "./mpv_gallery_flagged",

    max_generators = 8,

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
(require 'mp.options').read_options(opts)

function split(input, char, tonum)
    local ret = {}
    for str in string.gmatch(input, "([^" .. char .. "]+)") do
        ret[#ret + 1] = (not tonum and str) or tonumber(str)
    end
    return ret
end
opts.dynamic_thumbnail_size = split(opts.dynamic_thumbnail_size, ";", false)
for i = 1, #opts.dynamic_thumbnail_size do
    local preset = split(opts.dynamic_thumbnail_size[i], ",", true)
    if (#preset ~= 3) or not (preset[1] and preset[2] and preset[3]) then
        msg.error(opts.dynamic_thumbnail_size[i] .. " is not a valid preset")
        return
    end
    opts.dynamic_thumbnail_size[i] = preset
end

if on_windows then
    opts.thumbs_dir = string.gsub(opts.thumbs_dir, "^%%APPDATA%%", os.getenv("APPDATA") or "%APPDATA%")
else
    opts.thumbs_dir = string.gsub(opts.thumbs_dir, "^~", os.getenv("HOME") or "~")
end
opts.max_thumbnails = math.min(opts.max_thumbnails, 64)

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

gallery = gallery_new()

flags = {}
resume = {}
hash_cache = {}
misc = {
    old_force_window = "",
    old_geometry = "",
    old_osd_level = "",
    old_background = "",
    old_idle = "",
}

gallery.geometry.item_size.w = opts.thumbnail_width
gallery.geometry.item_size.h = opts.thumbnail_height
gallery.geometry.min_spacing.h = opts.show_filename and math.max(opts.text_size, opts.margin_y) or opts.margin_y
gallery.geometry.min_spacing.w = opts.margin_x
gallery.item_to_overlay_path = function(index, item)
    local filename = item.filename
    local filename_hash = hash_cache[filename]
    if filename_hash == nil then
        filename_hash = string.sub(sha256(normalize_path(filename)), 1, 12)
        hash_cache[filename] = filename_hash
    end
    local thumb_filename = string.format("%s_%d_%d", filename_hash, gallery.geometry.item_size.w, gallery.geometry.item_size.h)
    return utils.join_path(opts.thumbs_dir, thumb_filename)
end
gallery.item_to_thumbnail_params = function(index, item)
    return item.filename, opts.take_thumbnail_at
end
gallery.item_to_border = function(index, item)
    local flagged = flags[item.filename]
    local selected = index == gallery.selection
    if not flagged and not selected then
        return 0, ""
    elseif flagged and selected then
        return 5, opts.selected_flagged_frame_color
    elseif flagged then
        return 5, opts.flagged_frame_color
    elseif selected then
        return 5, opts.selected_frame_color
    end
end
gallery.item_to_text = function(index, item)
    if index ~= gallery.selection then return "", false end
    local f
    if opts.show_title and item.title then
        f = item.title
    else
        f = item.filename
        if opts.strip_directory then
            if on_windows then
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

do
    local function increment_func(increment, clamp)
        local new = (gallery.pending.selection or gallery.selection) + increment
        if new <= 0 or new > #gallery.items then
            if not clamp then return end
            new = math.max(1, math.min(new, #gallery.items))
        end
        gallery.pending.selection = new
    end

    local bindings_repeat = {}
        bindings_repeat[opts.UP]        = function() increment_func(- gallery.geometry.columns, false) end
        bindings_repeat[opts.DOWN]      = function() increment_func(  gallery.geometry.columns, false) end
        bindings_repeat[opts.LEFT]      = function() increment_func(- 1, false) end
        bindings_repeat[opts.RIGHT]     = function() increment_func(  1, false) end
        bindings_repeat[opts.PAGE_UP]   = function() increment_func(- gallery.geometry.columns * gallery.geometry.rows, true) end
        bindings_repeat[opts.PAGE_DOWN] = function() increment_func(  gallery.geometry.columns * gallery.geometry.rows, true) end
        bindings_repeat[opts.RANDOM]    = function() gallery.pending.selection = math.random(1, #gallery.items) end
        bindings_repeat[opts.REMOVE]    = function() gallery.pending.deletion = true end

    local bindings = {}
        bindings[opts.FIRST]  = function() gallery.pending.selection = 1 end
        bindings[opts.LAST]   = function() gallery.pending.selection = #gallery.items end
        bindings[opts.ACCEPT] = function() quit_gallery_view(gallery.selection) end
        bindings[opts.CANCEL] = function() quit_gallery_view(nil) end
        bindings[opts.FLAG]   = toggle_selection_flag
        bindings["MBTN_LEFT"]  = select_under_cursor
        bindings["WHEEL_UP"]   = function() increment_func(- gallery.geometry.columns, true) end
        bindings["WHEEL_DOWN"] = function() increment_func(  gallery.geometry.columns, true) end

     function setup_ui_handlers()
        for key, func in pairs(bindings_repeat) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func, {repeatable = true})
        end
        for key, func in pairs(bindings) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func)
        end
    end
 
    function teardown_ui_handlers()
        for key, _ in pairs(bindings_repeat) do
            mp.remove_key_binding("gallery-view-"..key)
        end
        for key, _ in pairs(bindings) do
            mp.remove_key_binding("gallery-view-"..key)
        end
    end
end

function toggle_selection_flag()
    local name = playlist[selection].filename
    if flags[name] == nil then
        flags[name] = true
    else
        flags[name] = nil
    end
    ass_show(true, false, false)
end

function resume_playback(select)
    -- what a mess
    local s = resume[playlist[select].filename]
    local pos = mp.get_property_number("playlist-pos-1")
    if pos == select then
        if s and opts.resume_when_picking then
            mp.commandv("seek", s.time, "absolute")
        end
        mp.set_property("vid", s and s.vid or "1")
        mp.set_property("aid", s and s.aid or "1")
        mp.set_property("sid", s and s.sid or "1")
        mp.set_property_bool("pause", false)
    else
        if s then
            local func
            func = function()
                local change_maybe = function(prop, val)
                    if val ~= mp.get_property(prop) then
                        mp.set_property(prop,val)
                    end
                end
                change_maybe("vid", s.vid)
                change_maybe("aid", s.aid)
                change_maybe("sid", s.sid)
                if opts.resume_when_picking then
                    mp.commandv("seek", s.time, "absolute")
                end
                mp.unregister_event(func)
            end
            mp.register_event("file-loaded", func)
        end
        mp.set_property("playlist-pos-1", select)
        mp.set_property("vid", "1")
        mp.set_property("aid", "1")
        mp.set_property("sid", "1")
        mp.set_property_bool("pause", false)
    end
end

function restore_properties()
    mp.set_property("force-window", misc.old_force_window)
    mp.set_property("track-auto-selection", misc.old_track_auto_selection)
    mp.set_property("geometry", misc.old_geometry)
    mp.set_property("osd-level", misc.old_osd_level)
    mp.set_property("background", misc.old_background)
    mp.set_property("idle", misc.old_idle)
    mp.commandv("script-message", "osc-visibility", "auto", "true")
end

function save_properties()
    misc.old_force_window = mp.get_property("force-window")
    misc.old_track_auto_selection = mp.get_property("track-auto-selection")
    misc.old_geometry = mp.get_property("geometry")
    misc.old_osd_level = mp.get_property("osd-level")
    misc.old_background = mp.get_property("background")
    misc.old_idle = mp.get_property("idle")
    mp.set_property_bool("force-window", true)
    mp.set_property_bool("track-auto-selection", false)
    mp.set_property_number("osd-level", 0)
    mp.set_property("background", opts.background)
    mp.set_property_bool("idle", true)
    mp.commandv("no-osd", "script-message", "osc-visibility", "never", "true")
    mp.set_property("geometry", gallery.geometry.window.w .. "x" .. gallery.geometry.window.h)
end

function normalize_path(path)
    if string.find(path, "://") then
        return path
    end
    path = utils.join_path(utils.getcwd(), path)
    if on_windows then
        path = string.gsub(path, "\\", "/")
    end
    path = string.gsub(path, "/%./", "/")
    local n
    repeat
        path, n = string.gsub(path, "/[^/]*/%.%./", "/", 1)
    until n == 0
    return path
end

do
    local inited = false
    function init()
        if not inited then
            inited = true
            if utils.file_info then -- 0.28+
                local res = utils.file_info(opts.thumbs_dir)
                if not res or not res.is_dir then
                    msg.error(string.format("Thumbnail directory \"%s\" does not exist", opts.thumbs_dir))
                end
            end
        end
    end
end

function playlist_changed(key, value)
    if not active then return end
    local did_change = function()
        if #gallery.items ~= #value then return true end
        for i = 1, #gallery.items do
            if gallery.items[i].filename ~= value[i].filename then return true end
        end
        return false
    end
    if not did_change() then return end
    if #value == 0 then
        quit_gallery_view()
        return
    end
    local sel_old_file = gallery.items[selection.old].filename
    local sel_new_file = gallery.items[gallery.selection].filename
    gallery.items = value
    gallery.selection = math.max(1, math.min(gallery.selection, #gallery.items))
    for i, f in ipairs(gallery.items) do
        if sel_new_file == f.filename then
            gallery.selection = i
        end
    end
    gallery:items_changed()
end

function start_gallery_view(record_time)
    init()
    playlist = mp.get_property_native("playlist")
    if #playlist == 0 then return end
    local ww, wh = mp.get_osd_size()

    gallery.items = playlist
    gallery.geometry.window.w = ww
    gallery.geometry.window.h = wh
    gallery.geometry.draw_area.x = 1 * ww / 4
    gallery.geometry.draw_area.y = 0
    gallery.geometry.draw_area.w = 2 * ww / 4
    gallery.geometry.draw_area.h = wh
    

    if not gallery:enough_space() then return end

    save_properties()

    local pos = mp.get_property_number("playlist-pos-1")
    if pos then
        local s = {}
        mp.set_property_bool("pause", true)
        if opts.resume_when_picking then
            s.time = record_time and mp.get_property_number("time-pos") or 0
        end
        s.vid = mp.get_property_number("vid") or "1"
        s.aid = mp.get_property_number("aid") or "1"
        s.sid = mp.get_property_number("sid") or "1"
        resume[playlist[pos].filename] = s
        mp.set_property("vid", "no")
        mp.set_property("aid", "no")
        mp.set_property("sid", "no")
    else
        -- this may happen if we enter the gallery too fast
        local func
        func = function()
            mp.set_property_bool("pause", true)
            mp.set_property("vid", "no")
            mp.set_property("aid", "no")
            mp.set_property("sid", "no")
            mp.unregister_event(func)
        end
        mp.register_event("file-loaded", func)
    end
    gallery:activate(pos or 1)
    setup_ui_handlers()
end

function quit_gallery_view(select)
    gallery:deactivate()
    restore_properties()
    resume_playback(select)
    teardown_ui_handlers()
end

function toggle_gallery()
    if not gallery.active then
        start_gallery_view(true)
    else
        quit_gallery_view(opts.toggle_behaves_as_accept and gallery.selection or nil)
    end
end

mp.register_script_message("thumbnail-generated", function(thumb_path)
     gallery:thumbnail_generated(thumb_path)
end)

function thumbnail_size_from_presets(window_w, window_h)
    local size = window_w * window_h
    local picked = nil
    for _, preset in ipairs(opts.dynamic_thumbnail_size) do
        picked = { preset[2], preset[3] }
        if size <= preset[1] then
            break
        end
    end
    return picked
end

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

if opts.start_gallery_on_file_end then
    mp.observe_property("eof-reached", "bool", function(_, val)
        if val and mp.get_property_number("playlist-count") > 1 then
            start_gallery_view(false)

        end
    end)
end
if opts.start_gallery_on_startup then
    local autostart
    autostart = function()
        if mp.get_property_number("playlist-count") == 0 then return end
        if mp.get_property_number("osd-width") <= 0 then return end
        start_gallery_view(false)
        mp.unobserve_property(autostart)
    end
    mp.observe_property("playlist-count", "number", autostart)
    mp.observe_property("osd-width", "number", autostart)
end

-- workaround for mpv bug #6823
mp.observe_property("playlist", "native", playlist_changed)

mp.add_key_binding("g", "gallery-view", toggle_gallery)
mp.add_key_binding(nil, "gallery-write-flag-file", write_flag_file)
