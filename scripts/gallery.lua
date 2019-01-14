local utils = require 'mp.utils'
local msg = require 'mp.msg'
local assdraw = require 'mp.assdraw'

local on_windows = (package.config:sub(1,1) ~= "/")

local opts = {
    thumbs_dir = on_windows and "%APPDATA%\\mpv\\gallery-thumbs-dir" or "~/.mpv_thumbs_dir/",
    auto_generate_thumbnails = true,
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

active = false
playlist = {} -- copy of the current "playlist" property
geometry = {
    window_w = 0,
    window_h = 0,
    rows = 0,
    columns = 0,
    size_x = 0,
    size_y = 0,
    margin_x = 0,
    margin_y = 0,
}
view = { -- 1-based indices into the "playlist" array
    first = 0, -- must be equal to N*columns
    last = 0, -- must be > first and <= first + rows*columns
}
overlays = {
    active = {}, -- array of 64 strings indicating the file associated to the current thumbnail (empty if no file)
    missing = {}, -- maps hashes of missing thumbnails to the index they should be shown at
}
selection = {
    old = 0, -- the playlist element selected when entering the gallery
    now = 0, -- the currently selected element
}
pending = {
    selection = -1,
    window_size_changed = false,
    deletion = false,
}
ass = {
    selection = "",
    scrollbar = "",
    placeholders = "",
}
flags = {}
resume = {} -- maps filename to the time-pos it was at when starting the gallery
misc = {
    old_idle = "",
    old_force_window = "",
    old_geometry = "",
    old_osd_level = "",
    old_background = "",
    old_vid = "",
}
generators = {} -- list of generator scripts that have registered themselves

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
            if opts.auto_generate_thumbnails and #generators == 0 then
                msg.error("Auto-generation on, but no generators registered")
            end
        end
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

function select_under_cursor()
    local g = geometry
    local mx, my = mp.get_mouse_pos()
    if mx < 0 or my < 0 or mx > g.window_w or my > g.window_h then return end
    local mx, my = mx - g.margin_x, my - g.margin_y
    local on_column = (mx % (g.size_x + g.margin_x)) < g.size_x
    local on_row = (my % (g.size_y + g.margin_y)) < g.size_y
    if on_column and on_row then
        local column = math.floor(mx / (g.size_x + g.margin_x))
        local row = math.floor(my / (g.size_y + g.margin_y))
        local new_sel = view.first + row * g.columns + column
        if new_sel > view.last then return end
        if selection.now == new_sel then
            quit_gallery_view(selection.now)
        else
            selection.now = new_sel
            pending.selection = new_sel
            ass_show(true, false, false)
        end
    end
end

function toggle_selection_flag()
    local name = playlist[selection.now].filename
    if flags[name] == nil then
        flags[name] = true
    else
        flags[name] = nil
    end
    ass_show(true, false, false)
end

do
    local function increment_func(increment, clamp)
        local new = pending.selection == -1 and selection.now or pending.selection
        new = new + increment
        if new <= 0 or new > #playlist then
            if not clamp then return end
            new = math.max(1, math.min(new, #playlist))
        end
        pending.selection = new
    end

    local bindings_repeat = {}
        bindings_repeat[opts.UP]        = function() increment_func(- geometry.columns, false) end
        bindings_repeat[opts.DOWN]      = function() increment_func(  geometry.columns, false) end
        bindings_repeat[opts.LEFT]      = function() increment_func(- 1, false) end
        bindings_repeat[opts.RIGHT]     = function() increment_func(  1, false) end
        bindings_repeat[opts.PAGE_UP]   = function() increment_func(- geometry.columns * geometry.rows, true) end
        bindings_repeat[opts.PAGE_DOWN] = function() increment_func(  geometry.columns * geometry.rows, true) end
        bindings_repeat[opts.RANDOM]    = function() pending.selection = math.random(1, #playlist) end
        bindings_repeat[opts.REMOVE]    = function() pending.deletion = true end

    local bindings = {}
        bindings[opts.FIRST]  = function() pending.selection = 1 end
        bindings[opts.LAST]   = function() pending.selection = #playlist end
        bindings[opts.ACCEPT] = function() quit_gallery_view(selection.now) end
        bindings[opts.CANCEL] = function() quit_gallery_view(selection.old) end
        bindings[opts.FLAG]   = toggle_selection_flag
    if opts.mouse_support then
        bindings["MBTN_LEFT"]  = select_under_cursor
        bindings["WHEEL_UP"]   = function() increment_func(- geometry.columns, true) end
        bindings["WHEEL_DOWN"] = function() increment_func(  geometry.columns, true) end
    end

    local function window_size_changed()
        pending.window_size_changed = true
    end

    local function idle_handler()
        if pending.selection ~= -1 then
            selection.now = pending.selection
            pending.selection = -1
            ensure_view_valid()
            refresh_overlays(false)
            ass_show(true, true, true)
        end
        if pending.window_size_changed then
            pending.window_size_changed = false
            local window_w, window_h = mp.get_osd_size()
            if window_w ~= geometry.window_w or window_h ~= geometry.window_h then
                compute_geometry(window_w, window_h)
                if geometry.rows <= 0 or geometry.columns <= 0 then
                    quit_gallery_view(selection.old)
                    return
                end
                ensure_view_valid()
                refresh_overlays(true)
                ass_show(true, true, true)
            end
        end
        if pending.deletion then
            pending.deletion = false
            mp.commandv("playlist-remove", selection.now - 1)
            selection.now = selection.now + (selection.now == #playlist and -1 or 1)
        end
    end

    function setup_ui_handlers()
        for key, func in pairs(bindings_repeat) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func, {repeatable = true})
        end
        for key, func in pairs(bindings) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func)
        end
        for _, prop in ipairs({ "osd-width", "osd-height" }) do
            mp.observe_property(prop, "native", window_size_changed)
        end
        mp.register_idle(idle_handler)
    end

    function teardown_ui_handlers()
        for key, _ in pairs(bindings_repeat) do
            mp.remove_key_binding("gallery-view-"..key)
        end
        for key, _ in pairs(bindings) do
            mp.remove_key_binding("gallery-view-"..key)
        end
        mp.unobserve_property(window_size_changed)
        mp.unregister_idle(idle_handler)
    end
end

function restore_playlist_and_select(select)
    mp.set_property_number("playlist-pos-1", select)
    if opts.resume_when_picking then
        local time = resume[playlist[select].filename]
        if time then
            local tmp
            local func = function()
                mp.commandv("seek", time, "absolute")
                mp.unregister_event(tmp)
            end
            tmp = func
            mp.register_event("file-loaded", func)
        end
    end
end

function restore_properties()
    mp.set_property("idle", misc.old_idle)
    mp.set_property("force-window", misc.old_force_window)
    mp.set_property("geometry", misc.old_geometry)
    mp.set_property("osd-level", misc.old_osd_level)
    mp.set_property("background", misc.old_background)
    mp.set_property("vid", misc.old_vid)
    mp.set_property_bool("pause", false)
    mp.commandv("script-message", "osc-visibility", "auto", "true")
end

function save_properties()
    misc.old_idle = mp.get_property("idle")
    misc.old_force_window = mp.get_property("force-window")
    misc.old_geometry = mp.get_property("geometry")
    misc.old_osd_level = mp.get_property("osd-level")
    misc.old_background = mp.get_property("background")
    misc.old_vid = mp.get_property("vid")
    mp.set_property_bool("pause", true)
    mp.set_property_bool("idle", true)
    mp.set_property_bool("force-window", true)
    mp.set_property_number("osd-level", 0)
    mp.set_property("background", opts.background)
    mp.set_property("vid", "no")
    mp.commandv("no-osd", "script-message", "osc-visibility", "never", "true")
    mp.set_property("geometry", geometry.window_w .. "x" .. geometry.window_h)
end

function compute_geometry(ww, wh)
    geometry.window_w, geometry.window_h = ww, wh

    local dyn_thumb_size = thumbnail_size_from_presets(ww, wh)
    if dyn_thumb_size then
        geometry.size_x = dyn_thumb_size[1]
        geometry.size_y = dyn_thumb_size[2]
    else
        geometry.size_x = opts.thumbnail_width
        geometry.size_y = opts.thumbnail_height
    end

    local margin_y = opts.show_filename and math.max(opts.text_size, opts.margin_y) or opts.margin_y
    geometry.rows = math.floor((wh - margin_y) / (geometry.size_y + margin_y))
    geometry.columns = math.floor((ww - opts.margin_x) / (geometry.size_x + opts.margin_x))
    if (geometry.rows * geometry.columns > opts.max_thumbnails) then
        local r = math.sqrt(geometry.rows * geometry.columns / opts.max_thumbnails)
        geometry.rows = math.floor(geometry.rows / r)
        geometry.columns = math.floor(geometry.columns / r)
    end
    geometry.margin_x = (ww - geometry.columns * geometry.size_x) / (geometry.columns + 1)
    geometry.margin_y = (wh - geometry.rows * geometry.size_y) / (geometry.rows + 1)
end

-- makes sure that view.first and view.last are valid with regards to the playlist
-- and that selection.now is within the view
-- to be called after the playlist, view or selection was modified somehow
function ensure_view_valid()
    local selection_row = math.floor((selection.now - 1) / geometry.columns)
    local max_thumbs = geometry.rows * geometry.columns

    if view.last >= #playlist then
        view.last = #playlist
        last_row = math.floor((view.last - 1) / geometry.columns)
        first_row = math.max(0, last_row - geometry.rows + 1)
        view.first = 1 + first_row * geometry.columns
    elseif view.first == 0 or view.last == 0 or view.last - view.first + 1 ~= max_thumbs then
        -- special case: the number of possible thumbnails was changed
        -- just recreate the view such that the selection is in the middle row
        local max_row = (#playlist - 1) / geometry.columns + 1
        local row_first = selection_row - math.floor((geometry.rows - 1) / 2)
        local row_last = selection_row + math.floor((geometry.rows - 1) / 2) + geometry.rows % 2
        if row_first < 0 then
            row_first = 0
        elseif row_last > max_row then
            row_first = max_row - geometry.rows + 1
        end
        view.first = 1 + row_first * geometry.columns
        view.last = math.min(#playlist, view.first - 1 + max_thumbs)
        return
    end

    if selection.now < view.first then
        -- the selection is now on the first line
        view.first = selection_row * geometry.columns + 1
        view.last = math.min(#playlist, view.first + max_thumbs - 1)
    elseif selection.now > view.last then
        -- the selection is now on the last line
        view.last = (selection_row + 1) * geometry.columns
        view.first = math.max(1, view.last - max_thumbs + 1)
        view.last = math.min(#playlist, view.last)
    end
end

-- ass related stuff
do
    local function refresh_placeholders()
        if not opts.show_placeholders then return end
        local a = assdraw.ass_new()
        a:new_event()
        a:append('{\\bord0}')
        a:append('{\\shad0}')
        a:append('{\\1c&' .. opts.placeholder_color .. '}')
        a:pos(0, 0)
        a:draw_start()
        for i = 0, view.last - view.first do
            if opts.always_show_placeholders or overlays.active[i + 1] == "" then
                local x = geometry.margin_x + (geometry.margin_x + geometry.size_x) * (i % geometry.columns)
                local y = geometry.margin_y + (geometry.margin_y + geometry.size_y) * math.floor(i / geometry.columns)
                a:rect_cw(x, y, x + geometry.size_x, y + geometry.size_y)
            end
        end
        a:draw_stop()
        ass.placeholders = a.text
    end

    local function refresh_scrollbar()
        if not opts.show_scrollbar then return end
        ass.scrollbar = ""
        local before = (view.first - 1) / #playlist
        local after = (#playlist - view.last) / #playlist
        -- don't show the scrollbar if everything is visible
        if before + after == 0 then return end
        local p = opts.scrollbar_min_size / 100
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
        local y1 = geometry.margin_y + before * (geometry.window_h - 2 * geometry.margin_y)
        local y2 = geometry.window_h - (geometry.margin_y + after * (geometry.window_h - 2 * geometry.margin_y))
        local x1, x2
        if opts.scrollbar_side == "left" then
            x1, x2 = 4, 8
        else
            x1, x2 = geometry.window_w - 8, geometry.window_w - 4
        end
        local scrollbar = assdraw.ass_new()
        scrollbar:new_event()
        scrollbar:append('{\\bord0}')
        scrollbar:append('{\\shad0}')
        scrollbar:append('{\\1c&AAAAAA&}')
        scrollbar:pos(0, 0)
        scrollbar:draw_start()
        scrollbar:round_rect_cw(x1, y1, x2, y2, 2)
        scrollbar:draw_stop()
        ass.scrollbar = scrollbar.text
    end

    local function refresh_selection()
        local selection_ass = assdraw.ass_new()
        local draw_frame = function(index, color)
            if index < view.first or index > view.last then return end
            local i = index - view.first
            local x = geometry.margin_x + (geometry.margin_x + geometry.size_x) * (i % geometry.columns)
            local y = geometry.margin_y + (geometry.margin_y + geometry.size_y) * math.floor(i / geometry.columns)
            selection_ass:new_event()
            selection_ass:append('{\\bord5}')
            selection_ass:append('{\\3c&'.. color ..'&}')
            selection_ass:append('{\\1a&FF&}')
            selection_ass:pos(0, 0)
            selection_ass:draw_start()
            selection_ass:round_rect_cw(x, y, x + geometry.size_x, y + geometry.size_y, 2)
            selection_ass:draw_stop()
        end
        for i = view.first, view.last do
            local name = playlist[i].filename
            if flags[name] then
                if i == selection.now then
                    draw_frame(i, opts.selected_flagged_frame_color)
                else
                    draw_frame(i, opts.flagged_frame_color)
                end
            elseif i == selection.now then
                draw_frame(i, opts.selected_frame_color)
            end
        end

        if opts.show_filename or opts.show_title then
            selection_ass:new_event()
            local i = (selection.now - view.first)
            local an = 5
            local x = geometry.margin_x + (geometry.margin_x + geometry.size_x) * (i % geometry.columns) + geometry.size_x / 2
            local y = geometry.margin_y + (geometry.margin_y + geometry.size_y) * math.floor(i / geometry.columns) + geometry.size_y + geometry.margin_y / 2
            local col = i % geometry.columns
            if geometry.columns > 1 then
                if col == 0 then
                    x = x - geometry.size_x / 2
                    an = 4
                elseif col == geometry.columns - 1 then
                    x = x + geometry.size_x / 2
                    an = 6
                end
            end
            selection_ass:an(an)
            selection_ass:pos(x, y)
            selection_ass:append(string.format("{\\fs%d}", opts.text_size))
            selection_ass:append("{\\bord0}")
            local f
            local element = playlist[selection.now]
            if opts.show_title and element.title then
                f = element.title
            else
                f = element.filename
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
            selection_ass:append(f)
        end
        ass.selection = selection_ass.text
    end

    function ass_show(selection, scrollbar, placeholders)
        if selection then refresh_selection() end
        if scrollbar then refresh_scrollbar() end
        if placeholders then refresh_placeholders() end
        local merge = function(a, b)
            return b ~= "" and (a .. "\n" .. b) or a
        end
        mp.set_osd_ass(geometry.window_w, geometry.window_h,
            merge(merge(ass.selection, ass.scrollbar), ass.placeholders)
        )
    end

    function ass_hide()
        mp.set_osd_ass(1280, 720, "")
    end
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

function refresh_overlays(force)
    local todo = {}
    overlays.missing = {}
    for i = 1, 64 do
        local index = view.first + i - 1
        if index <= view.last then
            local filename = playlist[index].filename
            if force or overlays.active[i] ~= filename then
                local filename_hash = string.sub(sha256(normalize_path(filename)), 1, 12)
                local thumb_filename = string.format("%s_%d_%d", filename_hash, geometry.size_x, geometry.size_y)
                local thumb_path = utils.join_path(opts.thumbs_dir, thumb_filename)
                if file_exists(thumb_path) then
                    show_overlay(i, thumb_path)
                    overlays.active[i] = filename
                else
                    remove_overlay(i)
                    overlays.missing[thumb_path] = { index = i, input = filename }
                    todo[#todo + 1] = { input = filename, output = thumb_path }
                end
            end
        else
            remove_overlay(i)
        end
    end
    -- reverse iterate so that the first thumbnail is at the top of the stack
    if opts.auto_generate_thumbnails and #generators >= 1 then
        for i = #todo, 1, -1 do
            local generator = generators[i % #generators + 1]
            local t = todo[i]
            mp.commandv("script-message-to", generator, "push-thumbnail-front",
                mp.get_script_name(),
                t.input,
                tostring(geometry.size_x),
                tostring(geometry.size_y),
                opts.take_thumbnail_at,
                t.output,
                opts.generate_thumbnails_with_mpv and "true" or "false"
            )
        end
    end
end

function show_overlay(index_1, thumb_path)
    local g = geometry
    local index_0 = index_1 - 1
    mp.command(string.format("overlay-add %i %i %i %s 0 bgra %i %i %i;",
        index_0,
        g.margin_x + (g.margin_x + g.size_x) * (index_0 % g.columns),
        g.margin_y + (g.margin_y + g.size_y) * math.floor(index_0 / g.columns),
        thumb_path,
        g.size_x, g.size_y, 4*g.size_x
    ))
    mp.osd_message("", 0.01)
end

function remove_overlays()
    for i = 1, 64 do
        remove_overlay(i)
    end
    overlays.missing = {}
end

function remove_overlay(index_1)
    if overlays.active[index_1] == "" then return end
    overlays.active[index_1] = ""
    mp.command("overlay-remove " .. index_1 - 1)
    mp.osd_message("", 0.01)
end

function playlist_changed(key, value)
    local did_change = function()
        if #playlist ~= #value then return true end
        for i = 1, #playlist do
            if playlist[i].filename ~= value[i].filename then return true end
        end
        return false
    end
    if not did_change() then return end
    if #value == 0 then
        quit_gallery_view()
        return
    end
    local sel_old_file = playlist[selection.old].filename
    local sel_new_file = playlist[selection.now].filename
    playlist = value
    selection.old = math.max(1, math.min(selection.old, #playlist))
    selection.now = math.max(1, math.min(selection.now, #playlist))
    for i, f in ipairs(playlist) do
        if sel_old_file == f.filename then
            selection.old = i
        end
        if sel_new_file == f.filename then
            selection.now = i
        end
    end
    ensure_view_valid()
    refresh_overlays(false)
    ass_show(true, true, true)
end

function start_gallery_view()
    init()
    playlist = mp.get_property_native("playlist")
    if #playlist == 0 then return end
    mp.observe_property("playlist", "native", playlist_changed)

    local ww, wh = mp.get_osd_size()
    compute_geometry(ww, wh)
    if geometry.rows <= 0 or geometry.columns <= 0 then return end

    save_properties()

    local pos = mp.get_property_number("playlist-pos-1")
    if opts.resume_when_picking and pos then
        resume[playlist[pos].filename] = mp.get_property_number("time-pos") or 0
    end
    selection.old = pos or 1
    selection.now = selection.old
    ensure_view_valid()
    setup_ui_handlers()
    refresh_overlays(true)
    ass_show(true, true, true)
    active = true
end

function quit_gallery_view(select)
    teardown_ui_handlers()
    remove_overlays()
    mp.unobserve_property(playlist_changed)
    ass_hide()
    if select then
        restore_playlist_and_select(select)
    end
    restore_properties()
    active = false
end

function toggle_gallery()
    if not active then
        start_gallery_view()
    else
        quit_gallery_view(opts.toggle_behaves_as_accept and selection.now or selection.old)
    end
end

mp.register_script_message("thumbnail-generated", function(thumbnail_path)
    if not active then return end
    local missing = overlays.missing[thumbnail_path]
    if missing == nil then return end
    show_overlay(missing.index, thumbnail_path)
    overlays.active[missing.index] = missing.input
    if not opts.always_show_placeholders then
        ass_show(false, false, true)
    end
    overlays.missing[thumbnail_path] = nil
end)

mp.register_script_message("thumbnails-generator-broadcast", function(generator_name)
    if #generators >= opts.max_generators then return end
    for _, g in ipairs(generators) do
        if generator_name == g then return end
    end
    generators[#generators + 1] = generator_name
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
    mp.register_event("end-file", function()
        if not active and mp.get_property_number("playlist-count") > 1 then
            start_gallery_view()
        end
    end)
end
if opts.start_gallery_on_startup then
    local autostart
    autostart = function()
        if mp.get_property_number("playlist-count") == 0 then return end
        if mp.get_property_number("osd-width") <= 0 then return end
        start_gallery_view()
        mp.unobserve_property(autostart)
    end
    mp.observe_property("playlist-count", "number", autostart)
    mp.observe_property("osd-width", "number", autostart)
end

mp.add_key_binding("g", "gallery-view", toggle_gallery)
mp.add_key_binding(nil, "gallery-write-flag-file", write_flag_file)
