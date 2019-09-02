local utils = require 'mp.utils'
local msg = require 'mp.msg'
local gallery = require 'lib/gallery'

local ON_WINDOWS = (package.config:sub(1,1) ~= "/")

local opts = {
    thumbs_dir = ON_WINDOWS and "%APPDATA%\\mpv\\gallery-thumbs-dir" or ".",
    generate_thumbnails_with_mpv = false,

    gallery_position = "{ww / 30, 30}",
    gallery_size = "{ww / 3, wh - 60}",
    min_spacing = "{15, 15}",
    thumbnail_size = "(ww * wh <= 1280 * 720) and {192, 108} or (ww * wh <= 1920 * 1080) and {288, 162} or {384,216}",

    toggle_behaves_as_accept = true,

    max_thumbnails = 64,

    time_distance = "1%",

    show_text = "selection",
    text_size = 28,

    normal_frame_color = "BBBBBB",
    normal_border_size = 1,
    selected_frame_color = "DDDDDD",
    selected_border_size = 6,

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
}
(require 'mp.options').read_options(opts)

function split(input)
    local ret = {}
    for str in string.gmatch(input, "([^,]+)") do
        ret[#ret + 1] = str
    end
    return ret
end

local res = utils.file_info(opts.thumbs_dir)
if not res or not res.is_dir then
    msg.error(string.format("Thumbnail directory \"%s\" does not exist", opts.thumbs_dir))
    return
end

if ON_WINDOWS then
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

path = ""
path_hash = ""
duration = 0

gallery.config.accurate = true
gallery.config.generate_thumbnails_with_mpv = false
gallery.config.always_show_placeholders = true
gallery.config.align_text = false

gallery.too_small = function()
    stop()
end
gallery.item_to_overlay_path = function(index, item)
    local thumb_filename = string.format("%s_%u_%d_%d",
        path_hash,
        item * 100,
        gallery.geometry.item_size.w,
        gallery.geometry.item_size.h)
    return utils.join_path(opts.thumbs_dir, thumb_filename)
end
gallery.item_to_thumbnail_params = function(index, item)
    return path, item
end
gallery.item_to_border = function(index, item)
    if index == gallery.selection then
        return opts.selected_border_size, opts.selected_frame_color
    else
        return opts.normal_border_size, opts.normal_frame_color
    end
end
gallery.item_to_text = function(index, item)
    if opts.show_text == "everywhere" or opts.show_text == "selection" and index == gallery.selection then
        local str
        if duration > 3600 then
            str = string.format("%d:%02d:%02d", item / 3600, (item / 60) % 60, item % 60)
        else
            str = string.format("%02d:%02d", (item / 60) % 60, item % 60)
        end
        local dec = tostring(math.floor(item * 1000 % 1000))
        if dec:len() < 3 then
            dec = dec .. string.rep("0", 3 - dec:len())
        end
        str = str .. "." .. dec
        return str
    else
        return ""
    end
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

    local bindings = {}
        bindings[opts.FIRST]  = function() gallery.pending.selection = 1 end
        bindings[opts.LAST]   = function() gallery.pending.selection = #gallery.items end
        bindings[opts.ACCEPT] = function() seek_to(gallery.selection); stop() end
        bindings[opts.CANCEL] = function() stop() end
        bindings["MBTN_LEFT"]  = function()
            local index = gallery:index_at(mp.get_mouse_pos())
            if not index then return end
            if index == gallery.selection then
                seek_to(gallery.selection)
                stop()
            else
                gallery.pending.selection = index
            end
        end
        bindings["WHEEL_UP"]   = function() increment_func(- gallery.geometry.columns, false) end
        bindings["WHEEL_DOWN"] = function() increment_func(  gallery.geometry.columns, false) end

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

local define_functions, err = loadstring("" ..
"function geom_gallery_position(ww, wh)" ..
"\n    return unpack(" .. opts.gallery_position .. ")" ..
"\nend" ..
"\nfunction geom_gallery_size(ww, wh)" ..
"\n    return unpack(" .. opts.gallery_size .. ")" ..
"\nend" ..
"\nfunction geom_min_spacing(ww, wh)" ..
"\n    return unpack(" .. opts.min_spacing .. ")" ..
"\nend" ..
"\nfunction geom_thumbnail_size(ww, wh)" ..
"\n    return unpack(" .. opts.thumbnail_size .. ")" ..
"\nend")
if not define_functions then
    msg.error("Error") -- TODO
    return
end
define_functions()

function set_geometry()
    local ww, wh = mp.get_osd_size()
    gallery.geometry.window.w = ww
    gallery.geometry.window.h = wh
    gallery.geometry.draw_area.x, gallery.geometry.draw_area.y = geom_gallery_position(ww, wh)
    gallery.geometry.draw_area.w, gallery.geometry.draw_area.h = geom_gallery_size(ww, wh)
    gallery.geometry.min_spacing.w, gallery.geometry.min_spacing.h = geom_min_spacing(ww, wh)
    if opts.show_text == "selection" or opts.show_text == "everywhere" then
        gallery.geometry.min_spacing.h = math.max(opts.text_size, gallery.geometry.min_spacing.h)
    end
    gallery.geometry.item_size.w, gallery.geometry.item_size.h = geom_thumbnail_size(ww, wh)
end

function window_size_changed()
    set_geometry()
    gallery.pending.geometry_changed = true
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

function start()
    if not mp.get_property_bool("seekable") then return end

    path = mp.get_property("path")
    path_hash = string.sub(sha256(normalize_path(path)), 1, 12)
    duration = mp.get_property_number("duration")
    local time_pos = mp.get_property_number("time-pos")
    if not duration then return end
    local effective_time_distance
    if string.sub(opts.time_distance, -1) == "%" then
        effective_time_distance = tonumber(string.sub(opts.time_distance, 1, -2)) / 100 * duration
    else
        effective_time_distance = tonumber(opts.time_distance)
    end
    local time = 0
    local times = {}
    local selection = 0
    while time < duration do
        if time < time_pos + 0.1 then
            selection = selection + 1
        end
        times[#times + 1] = time
        time = time + effective_time_distance
    end
    gallery.items = times

    set_geometry()
    if not gallery:enough_space() then return end
    for _, prop in ipairs({ "osd-width", "osd-height" }) do
        mp.observe_property(prop, "native", window_size_changed)
    end
    --mp.set_property_bool("pause", true)
    mp.register_event("end-file", stop)

    setup_ui_handlers()
    gallery:activate(selection)
end

function seek_to(index)
    local time = gallery.items[index]
    if not time then return end
    mp.commandv("seek", time, "absolute")
end

function stop()
    mp.unobserve_property(window_size_changed)
    mp.unregister_event(stop)
    --mp.set_property_bool("pause", false)
    gallery:deactivate()
    teardown_ui_handlers()
end

function toggle()
    if not gallery.active then
        start()
    else
        stop()
    end
end

mp.register_script_message("thumbnail-generated", function(thumb_path)
     gallery:thumbnail_generated(thumb_path)
end)

mp.register_script_message("thumbnails-generator-broadcast", function(generator_name)
     gallery:add_generator(generator_name)
end)

mp.add_key_binding(nil, "open-contact-sheet", start)
mp.add_key_binding(nil, "close-contact-sheet", stop)
mp.add_key_binding(nil, "toggle-contact-sheet", toggle)
