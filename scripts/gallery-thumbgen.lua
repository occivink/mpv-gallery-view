local utils = require 'mp.utils'

local globals = {
    registered = false,
    main_script_name = "",
    thumbs_dir = "",
    thumbnail_width = 0,
    thumbnail_height = 0,
    take_thumbnail_at = 0,
    generate_thumbnails_with_mpv = false,
    tmp_path = "", -- temporary name for generated thumbnails
    vf = "",
}

local thumbnail_stack = {} -- stack of { path, hash } objects
local failed = {} -- hashes of failed thumbnails, to avoid redoing them

function append_table(lhs, rhs)
    for i = 1,#rhs do
        lhs[#lhs+1] = rhs[i]
    end
    return lhs
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

function is_video(input_path)
    local extension = string.match(input_path, "%.([^.]+)$")
    if extension then
        extension = string.lower(extension)
        if extension == "mkv" or extension == "webm" or extension == "mp4" or extension == "avi" then
            return true
        end
    end
    return false
end

function thumbnail_command(input_path)
    local video = is_video(input_path)
    local out = {}
    local add = function(table) out = append_table(out, table) end
    if not globals.generate_thumbnails_with_mpv then
        out = { "ffmpeg" }
        if video and globals.take_thumbnail_at ~= 0 then
            --if only fucking ffmpeg supported percent-style seeking
            local res = utils.subprocess({cancellable = false, args = {
                "ffprobe", "-v", "error",
                "-show_entries", "format=duration", "-of",
                "default=noprint_wrappers=1:nokey=1", input_path
            }})
            if res.status == 0 then
                local duration = tonumber(string.match(res.stdout, "^%s*(.-)%s*$"))
                if duration then
                    start = tostring(duration * globals.take_thumbnail_at / 100)
                    add({"-ss", start, "-noaccurate_seek"})
                end
            end
        end
        add({
            "-i", input_path,
            "-vf", globals.vf,
            "-map", "v:0",
            "-f", "rawvideo",
            "-pix_fmt", "bgra",
            "-c:v", "rawvideo",
            "-frames:v", "1",
            "-y", "-loglevel", "quiet",
            globals.tmp_path
        })
    else
        out = { "mpv", input_path }
        if video and globals.take_thumbnail_at ~= 0 then
            add({"--hr-seek=no", "--start", globals.take_thumbnail_at .. "%"})
        end
        add({
            "--no-config", "--msg-level=all=no",
            "--vf", "lavfi=[" .. globals.vf .. ",format=bgra]",
            "--audio", "no",
            "--sub", "no",
            "--frames", "1",
            "--image-display-duration", "0",
            "--of", "rawvideo", "--ovc", "rawvideo",
            "--o", globals.tmp_path
        })
    end
    return out
end

function init_thumbnails_generator(main_script_name, thumbs_dir,
    thumbnail_width, tumbnail_height, take_thumbnail_at,
    generate_thumbnails_with_mpv
)
    globals.registered = true
    globals.main_script_name = main_script_name
    globals.thumbs_dir = thumbs_dir
    globals.thumbnail_width = tonumber(thumbnail_width)
    globals.thumbnail_height = tonumber(tumbnail_height)
    globals.take_thumbnail_at = tonumber(take_thumbnail_at)
    globals.generate_thumbnails_with_mpv = (generate_thumbnails_with_mpv == "true")
    globals.tmp_path = utils.join_path(globals.thumbs_dir, mp.get_script_name())
    local w, h = globals.thumbnail_width, globals.thumbnail_height
    local scale = string.format("scale=iw*min(1\\,min(%d/iw\\,%d/ih)):-2", w, h)
    local pad = string.format("pad=%d:%d:(%d-iw)/2:(%d-ih)/2:color=0x00000000", w, h, w, h)
    globals.vf = string.format("%s,%s", scale, pad)
end

function generate_thumbnail(input_path, hash)
    local output_path = utils.join_path(globals.thumbs_dir,
        string.format("%s_%d_%d", hash, globals.thumbnail_width, globals.thumbnail_height)
    )
    if file_exists(output_path) then return true end
    local res = utils.subprocess({ args = thumbnail_command(input_path), cancellable = false })
    --"atomically" generate the output to avoid loading half-generated thumbnails (results in crashes)
    if res.status == 0 then
        if os.rename(globals.tmp_path, output_path) then
            return true
        end
    end
    return false
end

function handle_events(wait, full)
    local start_time = mp.get_time()
    e = mp.wait_event(wait)
    while e.event ~= "none" do
        if e.event == "shutdown" then
            return false
        elseif e.event == "client-message" then
            if e.args[1] == "push-thumbnail-to-stack" then
                thumbnail_stack[#thumbnail_stack + 1] = { path = e.args[2], hash = e.args[3] }
            elseif e.args[1] == "init-thumbnails-generator" then
                init_thumbnails_generator(e.args[2], e.args[3], e.args[4], e.args[5], e.args[6], e.args[7])
                return true
            end
        end
        e = mp.wait_event(full and (start_time + wait - mp.get_time()) or 0)
    end
    return true
end

local registration_timeout = 3 -- seconds
local registration_period = 0.1

-- shitty custom event loop because I can't figure out a better way
-- works pretty well though
function mp_event_loop()
    local start_time = mp.get_time()
    while not globals.registered do
        if mp.get_time() > start_time + registration_timeout then return end
        mp.commandv("script-message", "gallery-thunbnails-generator-registered", mp.get_script_name())
        if not handle_events(registration_period, true) then return end
    end
    while true do
        if not handle_events(1e20) then return end
        while #thumbnail_stack > 0 do
            local input = thumbnail_stack[#thumbnail_stack]
            if not failed[input.hash] then
                local res = generate_thumbnail(input.path, input.hash)
                if res then
                    mp.commandv("script-message-to", "gallery", "thumbnail-generated", input.hash)
                else
                    failed[input.hash] = true
                end
            end
            thumbnail_stack[#thumbnail_stack] = nil
            if not handle_events(0) then return end
        end
    end
end

-- broadcast to every script in case the user modified the "gallery" script filename
mp.commandv("script-message", "gallery-thunbnails-generator-registered", mp.get_script_name())
