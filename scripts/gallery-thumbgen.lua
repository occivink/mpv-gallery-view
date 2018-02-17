local utils = require 'mp.utils'

local jobs_queue = {} -- queue of thumbnail jobs
local failed = {} -- list of failed output paths, to avoid redoing them

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

function thumbnail_command(input_path, width, height, take_thumbnail_at, output_path, with_mpv)
    local vf = string.format("%s,%s",
        string.format("scale=iw*min(1\\,min(%d/iw\\,%d/ih)):-2", width, height),
        string.format("pad=%d:%d:(%d-iw)/2:(%d-ih)/2:color=0x00000000", width, height, width, height)
    )
    local out = {}
    local add = function(table) out = append_table(out, table) end
    if not with_mpv then
        out = { "ffmpeg" }
        if is_video(input_path) then
            if string.sub(take_thumbnail_at, -1) == "%" then
                --if only fucking ffmpeg supported percent-style seeking
                local res = utils.subprocess({ args = {
                    "ffprobe", "-v", "error",
                    "-show_entries", "format=duration", "-of",
                    "default=noprint_wrappers=1:nokey=1", input_path
                }, cancellable = false })
                if res.status == 0 then
                    local duration = tonumber(string.match(res.stdout, "^%s*(.-)%s*$"))
                    if duration then
                        local percent = tonumber(string.sub(take_thumbnail_at, 1, -2))
                        local start = tostring(duration * percent / 100)
                        add({ "-ss", start, "-noaccurate_seek" })
                    end
                end
            else
                add({ "-ss", tonumber(take_thumbnail_at), "-noaccurate_seek" })
            end
        end
        add({
            "-i", input_path,
            "-vf", vf,
            "-map", "v:0",
            "-f", "rawvideo",
            "-pix_fmt", "bgra",
            "-c:v", "rawvideo",
            "-frames:v", "1",
            "-y", "-loglevel", "quiet",
            output_path
        })
    else
        out = { "mpv", input_path }
        if take_thumbnail_at ~= "0" and is_video(input_path) then
            add({ "--hr-seek=no", "--start", take_thumbnail_at })
        end
        add({
            "--no-config", "--msg-level=all=no",
            "--vf", "lavfi=[" .. vf .. ",format=bgra]",
            "--audio", "no",
            "--sub", "no",
            "--frames", "1",
            "--image-display-duration", "0",
            "--of", "rawvideo", "--ovc", "rawvideo",
            "--o", output_path
        })
    end
    return out
end

function generate_thumbnail(thumbnail_job)
    if file_exists(thumbnail_job.output_path) then return true end

    local dir, _ = utils.split_path(thumbnail_job.output_path)
    local tmp_output_path = utils.join_path(dir, mp.get_script_name())

    local command = thumbnail_command(
        thumbnail_job.input_path,
        thumbnail_job.width,
        thumbnail_job.height,
        thumbnail_job.take_thumbnail_at,
        tmp_output_path,
        thumbnail_job.with_mpv
    )

    local res = utils.subprocess({ args = command, cancellable = false })
    --"atomically" generate the output to avoid loading half-generated thumbnails (results in crashes)
    if res.status == 0 then
        if os.rename(tmp_output_path, thumbnail_job.output_path) then
            return true
        end
    end
    return false
end

function handle_events(wait)
    e = mp.wait_event(wait)
    while e.event ~= "none" do
        if e.event == "shutdown" then
            return false
        elseif e.event == "client-message" then
            if e.args[1] == "push-thumbnail-front" or e.args[1] == "push-thumbnail-back" then
                local thumbnail_job = {
                    requester = e.args[2],
                    input_path = e.args[3],
                    width = tonumber(e.args[4]),
                    height = tonumber(e.args[5]),
                    take_thumbnail_at = e.args[6],
                    output_path = e.args[7],
                    with_mpv = (e.args[8] == "true"),
                }
                if e.args[1] == "push-thumbnail-front" then
                    jobs_queue[#jobs_queue + 1] = thumbnail_job
                else
                    table.insert(jobs_queue, 1, thumbnail_job)
                end
            end
        end
        e = mp.wait_event(0)
    end
    return true
end

local registration_timeout = 2 -- seconds
local registration_period = 0.2

-- shitty custom event loop because I can't figure out a better way
-- works pretty well though
function mp_event_loop()
    local start_time = mp.get_time()
    local sleep_time = registration_period
    local last_broadcast_time = -registration_period
    local broadcast_func
    broadcast_func = function()
        local now = mp.get_time()
        if now >= start_time + registration_timeout then
            mp.commandv("script-message", "thumbnails-generator-broadcast", mp.get_script_name())
            sleep_time = 1e20
            broadcast_func = function() end
        elseif now >= last_broadcast_time + registration_period then
            mp.commandv("script-message", "thumbnails-generator-broadcast", mp.get_script_name())
            last_broadcast_time = now
        end
    end

    while true do
        if not handle_events(sleep_time) then return end
        broadcast_func()
        while #jobs_queue > 0 do
            local thumbnail_job = jobs_queue[#jobs_queue]
            if not failed[thumbnail_job.output_path] then
                if generate_thumbnail(thumbnail_job) then
                    mp.commandv("script-message-to", thumbnail_job.requester, "thumbnail-generated", thumbnail_job.output_path)
                else
                    failed[thumbnail_job.output_path] = true
                end
            end
            jobs_queue[#jobs_queue] = nil
            if not handle_events(0) then return end
            broadcast_func()
        end
    end
end
