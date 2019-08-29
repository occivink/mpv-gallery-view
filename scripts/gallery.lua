local utils = require 'mp.utils'
local msg = require 'mp.msg'
local assdraw = require 'mp.assdraw'

local on_windows = (package.config:sub(1,1) ~= "/")

local opts = {
    thumbs_dir = on_windows and "%APPDATA%\\mpv\\gallery-thumbs-dir" or "~/.mpv_thumbs_dir/",
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

----------------------------------
-- GENERIC-ISH
----------------------------------

local gallery = {
    active = false,
    items = {},
    geometry = {
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
        desired_spacing = {
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
        missing = {}, -- maps hashes of missing thumbnails to the index they should be shown at
    },
    selection = 0,
    pending = {
        selection = nil,
        geometry_changed = false,
        deletion = false,
    },
    flags = {
        scrollbar = true,
        can_delete = true,
        mouse_support = true,
    },
    ass = {
        background = "",
        selection = "",
        scrollbar = "",
        placeholders = "",
    },
    item_to_overlay_path = function(item) return nil end,
    item_to_text = function(item) return "" end,
    item_to_border = function(item) return nil end,
    generators = {} -- list of generator scripts
}

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
    if opts.mouse_support then
        bindings["MBTN_LEFT"]  = select_under_cursor
        bindings["WHEEL_UP"]   = function() increment_func(- gallery.geometry.columns, true) end
        bindings["WHEEL_DOWN"] = function() increment_func(  gallery.geometry.columns, true) end
    end

    local function geometry_changed()
        gallery.pending.geometry_changed = true
    end

    local function idle_handler()
        if gallery.pending.selection then
            gallery.selection = gallery.pending.selection
            gallery.pending.selection = nil
            ensure_view_valid()
            refresh_overlays(false)
            ass_show(true, true, true)
        end
        if gallery.pending.geometry_changed then
            gallery.pending.geometry_changed = false
            local ww, wh = mp.get_osd_size()
            gallery.geometry.draw_area.x = 0
            gallery.geometry.draw_area.y = 0
            gallery.geometry.draw_area.w = ww
            gallery.geometry.draw_area.h = wh
            compute_geometry()
            if geometry.rows <= 0 or geometry.columns <= 0 then
                quit_gallery_view(nil)
                return
            end
            ensure_view_valid()
            refresh_overlays(true)
            ass_show(true, true, true)
        end
        if gallery.pending.deletion then
            gallery.pending.deletion = false
            -- TODO
            --mp.commandv("playlist-remove", gallery.selection - 1)
            --gallery.selection = gallery.selection + (gallery.selection == #gallery.items and -1 or 1)
        end
    end

    function setup_ui_handlers()
        for key, func in pairs(bindings_repeat) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func, {repeatable = true})
        end
        for key, func in pairs(bindings) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func)
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
        mp.unobserve_property(geometry_changed)
        mp.unregister_idle(idle_handler)
    end
end

function refresh_overlays(force)
    local todo = {}
    local o = gallery.overlays
    local g = gallery.geometry
    o.missing = {}
    for i = 1, 64 do
        local index = gallery.view.first + i - 1
        if index <= gallery.view.last then
            local filename = gallery.items[index].filename
            if force or o.active[i] ~= filename then
                --local filename_hash = hash_cache[filename]
                --if filename_hash == nil then
                --    filename_hash = string.sub(sha256(normalize_path(filename)), 1, 12)
                --    hash_cache[filename] = filename_hash
                --end
                
                local filename_hash = string.sub(sha256(normalize_path(filename)), 1, 12)
                local thumb_filename = string.format("%s_%d_%d", filename_hash, g.item_size.w, g.item_size.h)
                local thumb_path = utils.join_path(opts.thumbs_dir, thumb_filename)
                if file_exists(thumb_path) then
                    show_overlay(i, thumb_path)
                    o.active[i] = filename
                else
                    o.missing[thumb_path] = { index = i, input = filename }
                    remove_overlay(i)
                    todo[#todo + 1] = { input = filename, output = thumb_path }
                end
            end
        else
            remove_overlay(i)
        end
    end
    if #gallery.generators >= 1 then
        -- reverse iterate so that the first thumbnail is at the top of the stack
        for i = #todo, 1, -1 do
            local generator = gallery.generators[i % #gallery.generators + 1]
            local t = todo[i]
            mp.commandv("script-message-to", generator, "push-thumbnail-front",
                mp.get_script_name(),
                t.input,
                tostring(g.item_size.w),
                tostring(g.item_size.h),
                opts.take_thumbnail_at,
                t.output,
                "false", -- accurate
                opts.generate_thumbnails_with_mpv and "true" or "false"
            )
        end
    end
end

function show_overlay(index_1, thumb_path)
    local g = gallery.geometry
    local index_0 = index_1 - 1
    mp.commandv("overlay-add",
        tostring(index_0),
        tostring(math.floor(0.5 + g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (index_0 % g.columns))),
        tostring(math.floor(0.5 + g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(index_0 / g.columns))),
        thumb_path,
        "0",
        "bgra",
        tostring(g.item_size.w),
        tostring(g.item_size.h),
        tostring(4*g.item_size.w))
    mp.osd_message("", 0.01)
end

function remove_overlays()
    for i = 1, 64 do
        remove_overlay(i)
    end
    gallery.overlays.missing = {}
end

function remove_overlay(index_1)
    if gallery.overlays.active[index_1] == "" then return end
    gallery.overlays.active[index_1] = ""
    mp.command("overlay-remove " .. index_1 - 1)
    mp.osd_message("", 0.01)
end

function select_under_cursor()
    local g = gallery.geometry
    local mx, my = mp.get_mouse_pos()
    if mx < 0 or my < 0 or mx > g.draw_area.w or my > g.draw_area.h then return end
    local mx, my = mx - g.effective_spacing.w, my - g.margin_y
    local on_column = (mx % (g.item_size.w + g.effective_spacing.w)) < g.item_size.w
    local on_row = (my % (g.item_size.h + g.margin_y)) < g.item_size.h
    if on_column and on_row then
        local column = math.floor(mx / (g.item_size.w + g.effective_spacing.w))
        local row = math.floor(my / (g.item_size.h + g.margin_y))
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

function compute_geometry()
    local g = gallery.geometry
    local spacing_y = opts.show_filename and math.max(opts.text_size, g.desired_spacing.h) or g.desired_spacing.h
    g.rows = math.floor((g.draw_area.h - spacing_y) / (g.item_size.h + spacing_y))
    g.columns = math.floor((g.draw_area.w- g.desired_spacing.w) / (g.item_size.w + g.desired_spacing.w))
    if (g.rows * g.columns > opts.max_thumbnails) then
        local r = math.sqrt(g.rows * g.columns / opts.max_thumbnails)
        g.rows = math.floor(g.rows / r)
        g.columns = math.floor(g.columns / r)
    end
    g.effective_spacing.w = (g.draw_area.w - g.columns * g.item_size.w) / (g.columns + 1)
    g.effective_spacing.h = (g.draw_area.h - g.rows * g.item_size.h) / (g.rows + 1)
end

-- makes sure that view.first and view.last are valid with regards to the playlist
-- and that selection is within the view
-- to be called after the playlist, view or selection was modified somehow
function ensure_view_valid()
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
do
    local function refresh_placeholders()
        if not opts.show_placeholders then return end
        local g = gallery.geometry
        local a = assdraw.ass_new()
        a:new_event()
        a:append('{\\bord0}')
        a:append('{\\shad0}')
        a:append('{\\1c&' ..'222222' .. '}') -- TODO
        a:pos(0, 0)
        a:draw_start()
        for i = 0, gallery.view.last - gallery.view.first do
            if opts.always_show_placeholders or gallery.overlays.active[i + 1] == "" then
                local x = g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (i % g.columns)
                local y = g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(i / g.columns)
                a:rect_cw(x, y, x + g.item_size.w, y + g.item_size.h)
            end
        end
        a:draw_stop()
        gallery.ass.placeholders = a.text
    end

    local function refresh_scrollbar()
        if not opts.show_scrollbar then return end
        gallery.ass.scrollbar = ""
        local g = gallery.geometry
        local before = (gallery.view.first - 1) / #gallery.items
        local after = (#gallery.items - gallery.view.last) / #gallery.items
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
        local y1 = g.effective_spacing.h + before * (g.draw_area.h - 2 * g.effective_spacing.h)
        local y2 = g.draw_area.h - (g.effective_spacing.h + after * (g.draw_area.h - 2 * g.effective_spacing.h))
        local x1, x2
        if opts.scrollbar_side == "left" then
            x1, x2 = 4, 8
        else
            x1, x2 = g.draw_area.w - 8, g.draw_area.w - 4
        end
        local scrollbar = assdraw.ass_new()
        scrollbar:new_event()
        scrollbar:append('{\\bord0}')
        scrollbar:append('{\\shad0}')
        scrollbar:append('{\\1c&AAAAAA&}')
        scrollbar:pos(0, 0)
        scrollbar:draw_start()
        scrollbar:round_rect_cw(x1, y1, x2, y2, opts.frame_roundness)
        scrollbar:draw_stop()
        gallery.ass.scrollbar = scrollbar.text
    end

    local function refresh_selection()
        local selection_ass = assdraw.ass_new()
        local v = gallery.view
        local g = gallery.geometry
        local draw_frame = function(index, color)
            if index < v.first or index > v.last then return end
            local i = index - v.first
            local x = g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (i % g.columns)
            local y = g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(i / g.columns)
            selection_ass:new_event()
            selection_ass:append('{\\bord5}')
            selection_ass:append('{\\3c&'.. color ..'&}')
            selection_ass:append('{\\1a&FF&}')
            selection_ass:pos(0, 0)
            selection_ass:draw_start()
            selection_ass:round_rect_cw(x, y, x + g.item_size.w, y + g.item_size.h, opts.frame_roundness)
            selection_ass:draw_stop()
        end
        for i = v.first, v.last do
            local name = playlist[i].filename
            if flags[name] then
                if i == gallery.selection then
                    draw_frame(i, opts.selected_flagged_frame_color)
                else
                    draw_frame(i, opts.flagged_frame_color)
                end
            elseif i == gallery.selection then
                draw_frame(i, opts.selected_frame_color)
            end
        end

        if opts.show_filename or opts.show_title then
            selection_ass:new_event()
            local i = (gallery.selection - v.first)
            local an = 5
            local x = g.effective_spacing.w + (g.effective_spacing.w + g.item_size.w) * (i % g.columns) + g.item_size.w / 2
            local y = g.effective_spacing.h + (g.effective_spacing.h + g.item_size.h) * math.floor(i / g.columns) + g.item_size.h + g.effective_spacing.h / 2
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
            selection_ass:an(an)
            selection_ass:pos(x, y)
            selection_ass:append(string.format("{\\fs%d}", opts.text_size))
            selection_ass:append("{\\bord0}")
            local f
            local element = playlist[gallery.selection]
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
        gallery.ass.selection = selection_ass.text
    end

    function ass_show(selection, scrollbar, placeholders)
        if selection then refresh_selection() end
        if scrollbar then refresh_scrollbar() end
        if placeholders then refresh_placeholders() end
        local merge = function(a, b)
            return b ~= "" and (a .. "\n" .. b) or a
        end
        mp.set_osd_ass(1280, 720,
            merge(merge(gallery.ass.selection, gallery.ass.scrollbar), gallery.ass.placeholders)
        )
    end

    function ass_hide()
        mp.set_osd_ass(1280, 720, "")
    end
end

----------------------------------
-- NOT GENERIC
----------------------------------

flags = {}
resume = {} -- maps filenames to a {time=,vid=,aid=,sid=} tuple
misc = {
    old_force_window = "",
    old_geometry = "",
    old_osd_level = "",
    old_background = "",
    old_idle = "",
}


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
    mp.set_property("geometry", gallery.geometry.draw_area.w .. "x" .. gallery.geometry.draw_area.h)
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
    ensure_view_valid()
    refresh_overlays(false)
    ass_show(true, true, true)
end

function start_gallery_view(record_time)
    if gallery.active then return end
    init()
    playlist = mp.get_property_native("playlist")
    if #playlist == 0 then return end
    gallery.items = playlist

    local ww, wh = mp.get_osd_size()
    gallery.geometry.draw_area.x = 0
    gallery.geometry.draw_area.y = 0
    gallery.geometry.draw_area.w = ww
    gallery.geometry.draw_area.h = wh
    gallery.geometry.item_size.h = opts.thumbnail_width
    gallery.geometry.item_size.w = opts.thumbnail_height
    gallery.geometry.desired_spacing.h = opts.margin_y
    gallery.geometry.desired_spacing.w = opts.margin_x
    compute_geometry()
    if gallery.geometry.rows <= 0 or gallery.geometry.columns <= 0 then return end

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
    gallery.selection = pos or 1
    ensure_view_valid()
    setup_ui_handlers()
    refresh_overlays(true)
    ass_show(true, true, true)
    gallery.active = true
end

function quit_gallery_view(select)
    if not gallery.active then return end
    teardown_ui_handlers()
    remove_overlays()
    ass_hide()
    if select then
        resume_playback(select)
    end
    restore_properties()
    gallery.active = false
end

function toggle_gallery()
    if not gallery.active then
        start_gallery_view(true)
    else
        quit_gallery_view(opts.toggle_behaves_as_accept and gallery.selection or nil)
    end
end

mp.register_script_message("thumbnail-generated", function(thumbnail_path)
    if not gallery.active then return end
    local missing = overlays.missing[thumbnail_path]
    if missing == nil then return end
    show_overlay(missing.index, thumbnail_path)
    overlays.active[missing.index] = missing.input
    if not opts.always_show_placeholders then
        ass_show(false, false, true)
    end
    overlays.missing[thumbnail_path] = nil
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
    if #gallery.generators >= opts.max_generators then return end
    for _, g in ipairs(gallery.generators) do
        if generator_name == g then return end
    end
    gallery.generators[#gallery.generators + 1] = generator_name
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
