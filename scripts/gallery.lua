local utils = require 'mp.utils'
local msg = require 'mp.msg'
local assdraw = require 'mp.assdraw'

local opts = {
    thumbs_dir = "~/.mpv_thumbs_dir",
    auto_generate_thumbnails = true,
    generate_thumbnails_with_mpv = false,

    thumbnail_width = 192,
    thumbnail_height = 108,

    margin = 20,
    scrollbar = true,
    scrollbar_side = "left",
    scrollbar_min_size = 10,

    start_gallery_on_file_end = true,
    max_generators = 64,

    UP        = "UP",
    DOWN      = "DOWN",
    LEFT      = "LEFT",
    RIGHT     = "RIGHT",
    PAGE_UP   = "PGUP",
    PAGE_DOWN = "PGDWN",
    FIRST     = "HOME",
    LAST      = "END",
    ACCEPT    = "ENTER",
    CANCEL    = "ESC",
    REMOVE    = "DEL",
}
(require 'mp.options').read_options(opts)
opts.thumbs_dir = string.gsub(opts.thumbs_dir, "^~", os.getenv("HOME") or "~")

--sha256 code below from http://lua-users.org/wiki/SecureHashAlgorithm
--licensed under MIT
--Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local sha256
do
    local band, rrotate, bxor, rshift, bnot
    if bit32 then
        band, rrotate, bxor, rshift, bnot =  bit32.band, bit32.rrotate, bit32.bxor, bit32.rshift, bit32.bnot
    else
        -- lua implementation of bit32 from https://www.snpedia.com/extensions/Scribunto/engines/LuaCommon/lualib/bit32.lua
        -- licensed under MIT too
        bnot = function(x)
            x = math.floor(tonumber(x)) % 0x100000000
            return ( -x - 1 ) % 0x100000000
        end
        local logic_and = {
            [0] = { [0] = 0, 0, 0, 0},
            [1] = { [0] = 0, 1, 0, 1},
            [2] = { [0] = 0, 0, 2, 2},
            [3] = { [0] = 0, 1, 2, 3},
        }
        local logic_xor = {
            [0] = { [0] = 0, 1, 2, 3},
            [1] = { [0] = 1, 0, 3, 2},
            [2] = { [0] = 2, 3, 0, 1},
            [3] = { [0] = 3, 2, 1, 0},
        }
        local function comb( name, args, nargs, s, t )
            for i = 1, nargs do
                args[i] = math.floor(tonumber(args[i])) % 0x100000000
            end
            local pow = 1
            local ret = 0
            for b = 0, 31, 2 do
                local c = s
                for i = 1, nargs do
                    c = t[c][args[i] % 4]
                    args[i] = math.floor( args[i] / 4 )
                end
                ret = ret + c * pow
                pow = pow * 4
            end
            return ret
        end
        band = function( ... )
            return comb( 'band', { ... }, select( '#', ... ), 3, logic_and )
        end
        bxor = function( ... )
            return comb( 'bxor', { ... }, select( '#', ... ), 0, logic_xor )
        end
        rshift = function(x, disp)
            x = math.floor(tonumber(x)) % 0x100000000
            disp = math.floor(tonumber(disp))
            disp = math.min( math.max( -32, disp ), 32)
            return math.floor( x / 2^disp ) % 0x100000000
        end
        rrotate = function(x, disp)
            x = math.floor(tonumber(x)) % 0x100000000
            disp = -math.floor(tonumber(disp)) % 32
            local x = x * 2^disp
            return ( x % 0x100000000 ) + math.floor( x / 0x100000000 )
        end
    end
    local k = {
       0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
       0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
       0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
       0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
       0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
       0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
       0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
       0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
       0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
       0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
       0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
       0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
       0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
       0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
       0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
       0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }
    local function str2hexa(s)
        return string.gsub(s, ".", function(c) return string.format("%02x", string.byte(c)) end)
    end
    local function num2s(l, n)
        local s = ""
        for i = 1, n do
            local rem = l % 256
            s = string.char(rem) .. s
            l = (l - rem) / 256
        end
        return s
    end
    local function s232num(s, i)
        local n = 0
        for i = i, i + 3 do
            n = n*256 + string.byte(s, i)
        end
        return n
    end
    local function preproc(msg, len)
        local extra = -(len + 1 + 8) % 64
        len = num2s(8 * len, 8)
        msg = msg .. "\128" .. string.rep("\0", extra) .. len
        return msg
    end
    local function initH256(H)
        H[1] = 0x6a09e667
        H[2] = 0xbb67ae85
        H[3] = 0x3c6ef372
        H[4] = 0xa54ff53a
        H[5] = 0x510e527f
        H[6] = 0x9b05688c
        H[7] = 0x1f83d9ab
        H[8] = 0x5be0cd19
        return H
    end
    local function digestblock(msg, i, H)
        local w = {}
        for j = 1, 16 do
            w[j] = s232num(msg, i + (j - 1)*4)
        end
        for j = 17, 64 do
            local v = w[j - 15]
            local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
            v = w[j - 2]
            local s1 = bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
            w[j] = w[j - 16] + s0 + w[j - 7] + s1
        end
        local a, b, c, d, e, f, g, h =
            H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        for i = 1, 64 do
            local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local t2 = s0 + maj
            local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor (band(e, f), band(bnot(e), g))
            local t1 = h + s1 + ch + k[i] + w[i]
            h = g
            g = f
            f = e
            e = d + t1
            d = c
            c = b
            b = a
            a = t1 + t2
        end
        H[1] = band(H[1] + a)
        H[2] = band(H[2] + b)
        H[3] = band(H[3] + c)
        H[4] = band(H[4] + d)
        H[5] = band(H[5] + e)
        H[6] = band(H[6] + f)
        H[7] = band(H[7] + g)
        H[8] = band(H[8] + h)
    end
    local function finalresult256(H)
        return
            str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..num2s(H[3], 4)..num2s(H[4], 4)..
                     num2s(H[5], 4)..num2s(H[6], 4)..num2s(H[7], 4)..num2s(H[8], 4))
    end
    local HH = {}
    sha256 = function(msg)
        msg = preproc(msg, #msg)
        local H = initH256(HH)
        for i = 1, #msg, 64 do
            digestblock(msg, i, H)
        end
        return finalresult256(H)
    end
end

-- end of sha code

active = false
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
playlist = {}
view = { -- 1-based indices into the "playlist" array
    first = 0, -- must be equal to N*columns
    last = 0, -- must be > first_visible and <= first_visible + rows*columns
}
overlays = {
    active = {}, -- array of 64 booleans indicated whether the corresponding overlay is shown
    missing = {}, -- maps hashes of missing thumbnails to the index they should be shown at
}
selection = {
    old = 0, -- the playlist element selected when entering the gallery
    now = 0, -- the currently selected element
}
pending = {
    selection_increment = 0,
    mouse_moved = false,
    window_size_chaned = false,
    deletion = false,
}
misc = {
    old_idle = "",
    old_force_window = "",
    old_geometry = "",
    old_osc = "",
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
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

do
    local bindings_repeat = {}
        bindings_repeat[opts.UP]        = function() pending.selection_increment = - geometry.columns end
        bindings_repeat[opts.DOWN]      = function() pending.selection_increment =   geometry.columns end
        bindings_repeat[opts.LEFT]      = function() pending.selection_increment = - 1 end
        bindings_repeat[opts.RIGHT]     = function() pending.selection_increment =   1 end
        bindings_repeat[opts.PAGE_UP]   = function() pending.selection_increment = - geometry.columns * geometry.rows end
        bindings_repeat[opts.PAGE_DOWN] = function() pending.selection_increment =   geometry.columns * geometry.rows end
        bindings_repeat[opts.REMOVE]    = function() pending.deletion = true end

    local bindings = {}
        bindings[opts.FIRST]  = function() pending.selection_increment = -100000000 end
        bindings[opts.LAST]   = function() pending.selection_increment =  100000000 end
        bindings[opts.ACCEPT] = function() quit_gallery_view(selection.now) end
        bindings[opts.CANCEL] = function() quit_gallery_view(selection.old) end

    local function window_size_changed()
        pending.window_size_changed = true
    end

    function setup_handlers()
        for key, func in pairs(bindings_repeat) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func, {repeatable = true})
        end
        for key, func in pairs(bindings) do
            mp.add_forced_key_binding(key, "gallery-view-"..key, func)
        end
        for _, prop in ipairs({ "osd-width", "osd-height" }) do
            mp.observe_property(prop, bool, window_size_changed)
        end
        mp.register_idle(idle_handler)
    end

    function teardown_handlers()
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

function save_and_clear_playlist()
    playlist = {}
    local cwd = utils.getcwd()
    for _, f in ipairs(mp.get_property_native("playlist")) do
        playlist[#playlist + 1]  = utils.join_path(cwd, string.gsub(f.filename, "^%./", ""))
    end
    mp.command("playlist-clear")
    mp.command("playlist-remove current")
end

function restore_playlist_and_select(select)
    mp.commandv("loadfile", playlist[select], "replace")
    for i = 1, select - 1 do
        mp.commandv("loadfile", playlist[i], "append")
    end
    for i = select + 1, #playlist do
        mp.commandv("loadfile", playlist[i], "append")
    end
    mp.commandv("playlist-move", 0, select)
end

function restore_properties()
    mp.set_property("idle", misc.old_idle)
    mp.set_property("force-window", misc.old_force_window)
    mp.set_property("geometry", misc.old_geometry)
    mp.set_property("osc", misc.old_osc)
end

function save_properties()
    misc.old_idle = mp.get_property("idle")
    misc.old_force_window = mp.get_property("force-window")
    misc.old_osc = mp.get_property("osc")
    misc.old_geometry = mp.get_property("geometry")
    mp.set_property_bool("idle", true)
    mp.set_property_bool("force-window", true)
    mp.set_property_bool("osc", false)
    mp.set_property("geometry", geometry.window_w .. "x" .. geometry.window_h)
end

function get_geometry(window_w, window_h)
    geometry.window_w, geometry.window_h = window_w, window_h
    geometry.size_x = opts.thumbnail_width
    geometry.size_y = opts.thumbnail_height
    geometry.rows = math.floor((geometry.window_h - opts.margin) / (geometry.size_y + opts.margin))
    geometry.columns = math.floor((geometry.window_w - opts.margin) / (geometry.size_x + opts.margin))
    if (geometry.rows * geometry.columns > 64) then
        if (geometry.rows > 8 and geometry.columns > 8) then
            geometry.rows = 8
            geometry.columns = 8
        else
            local r = math.sqrt(geometry.rows * geometry.columns / 64)
            geometry.rows = math.floor(geometry.rows / r)
            geometry.columns = math.floor(geometry.columns / r)
        end
    end
    geometry.margin_x = (geometry.window_w - geometry.columns * geometry.size_x) / (geometry.columns + 1)
    geometry.margin_y = (geometry.window_h - geometry.rows * geometry.size_y) / (geometry.rows + 1)
end

function idle_handler()
    if pending.selection_increment ~= 0 then
        selection.now = math.max(1, math.min(selection.now + pending.selection_increment, #playlist))
        pending.selection_increment = 0
        max_thumbs = geometry.rows * geometry.columns
        if selection.now < view.first or selection.now > view.last then
            if selection.now < view.first then
                view.first = math.floor((selection.now - 1) / geometry.columns) * geometry.columns + 1
                view.last = math.min(view.first + max_thumbs - 1, #playlist)
            else
                view.last = (math.floor((selection.now - 1) / geometry.columns) + 1) * geometry.columns
                view.first = view.last - max_thumbs + 1
                if view.last > #playlist then
                    remove_overlays(max_thumbs - (view.last - #playlist) + 1, max_thumbs)
                    view.last = #playlist
                end
            end
            show_overlays(1, view.last - view.first + 1)
        end
        show_selection_ass()
    end
    if pending.window_size_changed then
        pending.window_size_chaned = false
        local window_w, window_h = mp.get_osd_size()
        if window_w ~= geometry.window_w or window_h ~= geometry.window_h then
            local old_max_thumbs = geometry.rows * geometry.columns
            get_geometry(window_w, window_h)
            local max_thumbs = geometry.rows * geometry.columns
            if geometry.rows <= 0 or geometry.columns <= 0 then
                quit_gallery_view(selection.old)
                return
            elseif max_thumbs ~= old_max_thumbs then
                center_view_on_selection()
                remove_overlays(view.last - view.first + 2, old_max_thumbs)
            end
            show_selection_ass()
            show_overlays(1, view.last - view.first + 1)
        end
    end
    if pending.deletion then
        pending.deletion = false
        if #playlist < 2 then return end
        table.remove(playlist, selection.now)
        selection.old = math.min(selection.old, #playlist)
        view.last = math.min(view.last, #playlist)
        selection.now = math.min(selection.now, #playlist)
        show_overlays(selection.now - view.first + 1, view.last - view.first + 1)
        if view.last - view.first + 1 < geometry.rows * geometry.columns then
            remove_overlay(view.last - view.first + 2)
        end
        show_selection_ass()
    end
end

function center_view_on_selection()
    view.first = math.floor((selection.now - 1) / geometry.columns) * geometry.columns + 1
    view.last = view.first + geometry.rows * geometry.columns - 1
    if view.last > #playlist then
        local last_row = math.floor((#playlist - 1) / geometry.columns)
        view.last = #playlist
        view.first = math.max(1, (last_row - geometry.rows + 1) * geometry.columns + 1)
    end
end

function show_selection_ass()
    -- TODO refactor
    local ass = assdraw.ass_new()
    ass:new_event()
    ass:append('{\\bord6}')
    ass:append('{\\3c&DDDDDD&}')
    ass:append('{\\1a&FF&}')
    ass:pos(0, 0)
    ass:draw_start()
    local s, g, v = selection, geometry, view
    local i = s.now - v.first
    local x = g.margin_x + (g.margin_x + g.size_x) * (i % g.columns)
    local y = g.margin_y + (g.margin_y + g.size_y) * math.floor(i / g.columns)
    ass:round_rect_cw(x + 1, y + 1, x + g.size_x - 1, y + g.size_y - 1, 2)
    ass:draw_stop()
    if opts.scrollbar then
        local before = (v.first - 1) / #playlist
        local after = (#playlist - v.last) / #playlist
        if before + after > 0 then
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
            local y1 = g.margin_y + before * (g.window_h - 2 * g.margin_y)
            local y2 = g.window_h - (g.margin_y + after * (g.window_h - 2 * g.margin_y))
            local x1, x2
            if opts.scrollbar_side == "left" then
                x1, x2 = 3, 7
            else
                x1, x2 = g.window_w - 7, g.window_w - 3
            end
            ass:new_event()
            ass:append('{\\bord0}')
            ass:append('{\\shad0}')
            ass:append('{\\1c&AAAAAA&}')
            ass:pos(0, 0)
            ass:draw_start()
            ass:round_rect_cw(x1, y1, x2, y2, 2)
            ass:draw_stop()
        end
    end
    mp.set_osd_ass(geometry.window_w, geometry.window_h, ass.text)
end

function remove_selection_ass()
    mp.set_osd_ass(1280, 720, "")
end

-- 1-based indices
function show_overlays(from, to)
    local todo = {}
    overlays.missing = {}
    for i = from, to do
        local filename = playlist[view.first + i - 1]
        local filename_hash = string.sub(sha256(filename), 1, 12)
        local thumb_filename = filename_hash .. "_" .. geometry.size_x .. "_" .. geometry.size_y
        local thumb_path = utils.join_path(opts.thumbs_dir, thumb_filename)
        if file_exists(thumb_path) then
            show_overlay(i, thumb_path)
        else
            remove_overlay(i)
            todo[#todo + 1] = { index = i, path = filename, hash = filename_hash }
        end
    end
    -- reverse iterate so that the first thumbnail is at the top of the stack
    if opts.auto_generate_thumbnails and #generators >= 1 then
        for i = #todo, 1, -1 do
            local generator = generators[i % #generators + 1]
            local t = todo[i]
            overlays.missing[t.hash] = t.index
            mp.commandv("script-message-to", generator, "push-thumbnail-to-stack", t.path, t.hash)
        end
    end
end

function show_overlay(index_1, thumb_path)
    local g = geometry
    local index_0 = index_1 - 1
    overlays.active[index_1] = true
    mp.command(string.format("overlay-add %i %i %i %s 0 bgra %i %i %i;",
        index_0,
        g.margin_x + (g.margin_x + g.size_x) * (index_0 % g.columns),
        g.margin_y + (g.margin_y + g.size_y) * math.floor(index_0 / g.columns),
        thumb_path,
        g.size_x, g.size_y, 4*g.size_x
    ))
    mp.osd_message("", 0.01)
end

-- 1-based indices
function remove_overlays(from, to)
    for i = to, from, -1 do
        remove_overlay(i)
    end
end

function remove_overlay(index_1)
    if overlays.active[index_1] then
        overlays.active[index_1] = false
        mp.command("overlay-remove " .. index_1 - 1)
        mp.osd_message("", 0.01)
    end
end

function start_gallery_view()
    init()
    local old_max_thumbs = geometry.rows * geometry.columns
    get_geometry(mp.get_osd_size())
    local max_thumbs = geometry.rows * geometry.columns
    if geometry.rows <= 0 or geometry.columns <= 0 then return end
    save_properties()
    selection.old = mp.get_property_number("playlist-pos-1") or 1
    selection.now = selection.old
    save_and_clear_playlist()
    local selection_row = math.floor((selection.now - 1) / geometry.columns)
    if max_thumbs ~= old_max_thumbs then
        center_view_on_selection()
    elseif selection.now < view.first then
        -- the selection is now on the first line
        view.first = selection_row * geometry.columns + 1
        view.last = math.min(#playlist, view.first + max_thumbs - 1)
    elseif selection.now > view.last then
        -- the selection is now on the last line
        view.last = (selection_row + 1) * geometry.columns
        view.first = math.max(1, view.last - max_thumbs + 1)
        view.last = math.min(#playlist, view.last)
    end
    setup_handlers()
    show_selection_ass()
    show_overlays(1, view.last - view.first + 1)
    active = true
end

function quit_gallery_view(select)
    teardown_handlers()
    remove_overlays(1, view.last - view.first + 1)
    remove_selection_ass()
    restore_playlist_and_select(select)
    restore_properties()
    active = false
end

function toggle_gallery()
    if not active then
        start_gallery_view()
    else
        quit_gallery_view(selection.old)
    end
end

mp.register_script_message("thumbnail-generated", function(hash)
    if not active then return end
    local missing = overlays.missing[hash]
    if missing == nil then return end
    local thumb_filename = hash .. "_" .. geometry.size_x .. "_" .. geometry.size_y
    local thumb_path = utils.join_path(opts.thumbs_dir, thumb_filename)
    show_overlay(missing, thumb_path)
    overlays.missing[hash] = nil
end)

mp.register_script_message("gallery-thunbnails-generator-registered", function(generator_name)
    if #generators >= opts.max_generators then return end
    for _, g in ipairs(generators) do
        if generator_name == g then return end
    end
    generators[#generators + 1] = generator_name
    mp.commandv("script-message-to", generator_name, "init-thumbnails-generator",
        mp.get_script_name(),
        opts.thumbs_dir,
        tostring(opts.thumbnail_width),
        tostring(opts.thumbnail_height),
        tostring(opts.generate_thumbnails_with_mpv)
    )
end)

if opts.start_gallery_on_file_end then
    mp.register_event("end-file", function()
        if not active and mp.get_property_number("playlist-count") > 1 then
            start_gallery_view()
        end
    end)
end

mp.add_key_binding("g", "gallery-view", toggle_gallery)
