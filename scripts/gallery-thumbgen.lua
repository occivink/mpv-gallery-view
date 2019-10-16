local utils = require 'mp.utils'
local msg = require 'mp.msg'

local jobs_queue = {} -- queue of thumbnail jobs
local failed = {} -- list of failed output paths, to avoid redoing them
local script_id = mp.get_script_name() .. utils.getpid()

local opts = {
    ytdl_exclude = "",
}
(require 'mp.options').read_options(opts, "gallery_worker")

local ytdl = {
    path = "youtube-dl",
    searched = false,
    blacklisted = {} -- Add patterns of URLs you want blacklisted from youtube-dl,
                     -- see gallery_worker.conf or ytdl_hook-exclude in the mpv manpage for more info
}

function append_table(lhs, rhs)
    for i = 1,#rhs do
        lhs[#lhs+1] = rhs[i]
    end
    return lhs
end

local function file_exists(path)
    local info = utils.file_info(path)
    return info ~= nil and info.is_file
end

local video_extensions = { "mkv", "webm", "mp4", "avi", "wmv" }

function is_video(input_path)
    local extension = string.match(input_path, "%.([^.]+)$")
    if extension then
        extension = string.lower(extension)
        for _, ext in ipairs(video_extensions) do
            if extension == ext then
                return true
            end
        end
    end
    return false
end

function is_blacklisted(url)
    if opts.ytdl_exclude == "" then return false end
    if #ytdl.blacklisted == 0 then
        local joined = opts.ytdl_exclude
        while joined:match('%|?[^|]+') do
            local _, e, substring = joined:find('%|?([^|]+)')
            table.insert(ytdl.blacklisted, substring)
            joined = joined:sub(e+1)
        end
    end
    if #ytdl.blacklisted > 0 then
        url = url:match('https?://(.+)')
        for _, exclude in ipairs(ytdl.blacklisted) do
            if url:match(exclude) then
                msg.verbose('URL matches excluded substring. Skipping.')
                return true
            end
        end
    end
    return false
end


function ytdl_thumbnail_url(input_path)
    local function exec(args)
        local ret = utils.subprocess({args = args, cancellable=false})
        return ret.status, ret.stdout, ret
    end
    local function first_non_nil(x, ...)
        if x ~= nil then return x end
        return first_non_nil(...)
    end

    -- if input_path is youtube, generate our own URL
    youtube_id1 = string.match(input_path, "https?://youtu%.be/([%a%d%-_]+).*")
    youtube_id2 = string.match(input_path, "https?://w?w?w?%.?youtube%.com/v/([%a%d%-_]+).*")
    youtube_id3 = string.match(input_path, "https?://w?w?w?%.?youtube%.com/watch%?v=([%a%d%-_]+).*")
    youtube_id4 = string.match(input_path, "https?://w?w?w?%.?youtube%.com/embed/([%a%d%-_]+).*")
    youtube_id = youtube_id1 or youtube_id2 or youtube_id3 or youtube_id4

    if youtube_id then
        -- the hqdefault.jpg thumbnail should always exist, since it's used on the search result page
        return "https://i.ytimg.com/vi/" .. youtube_id ..  "/hqdefault.jpg"
    end

    --otherwise proceed with the slower `youtube-dl -J` method
    if not (ytdl.searched) then --search for youtude-dl in mpv's config directory
        local exesuf = (package.config:sub(1,1) == '\\') and '.exe' or ''
        local ytdl_mcd = mp.find_config_file("youtube-dl")
        if not (ytdl_mcd == nil) then
            msg.error("found youtube-dl at: " .. ytdl_mcd)
            ytdl.path = ytdl_mcd
        end
        ytdl.searched = true
    end
    local command = {ytdl.path, "--no-warnings", "--no-playlist", "-J", input_path}
    local es, json, result = exec(command)

    if (es < 0) or (json == nil) or (json == "") then
        msg.error("fetching thumbnail url with youtube-dl failed for" .. input_path)
        return input_path
    end
    local json, err = utils.parse_json(json)
    if (json == nil) then
        msg.error("failed to parse json for youtube-dl thumbnail: " .. err)
        return input_path
    end

    if (json.thumbnail == nil) or (json.thumbnail == "") then
        msg.error("no thumbnail url from youtube-dl.")
        return input_path
    end
    return json.thumbnail
end

function thumbnail_command(input_path, width, height, take_thumbnail_at, output_path, accurate, with_mpv)
    local vf = string.format("%s,%s",
        string.format("scale=iw*min(1\\,min(%d/iw\\,%d/ih)):-2", width, height),
        string.format("pad=%d:%d:(%d-iw)/2:(%d-ih)/2:color=0x00000000", width, height, width, height)
    )
    local out = {}
    local add = function(table) out = append_table(out, table) end


    if input_path:find("^https?://") and not is_blacklisted(input_path) then
        -- returns the original input_path on failure
        input_path = ytdl_thumbnail_url(input_path)
    end

    if input_path:find("^archive://") or input_path:find("^edl://") then
        with_mpv = true
    end


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
                        add({ "-ss", start })
                    end
                end
            else
                add({ "-ss", take_thumbnail_at })
            end
        end
        if not accurate then
            add({"-noaccurate_seek"})
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
            if not accurate then
                add({ "--hr-seek=no"})
            end
            add({ "--start", take_thumbnail_at })
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
    local tmp_output_path = utils.join_path(dir, script_id)

    local command = thumbnail_command(
        thumbnail_job.input_path,
        thumbnail_job.width,
        thumbnail_job.height,
        thumbnail_job.take_thumbnail_at,
        tmp_output_path,
        thumbnail_job.accurate,
        thumbnail_job.with_mpv
    )

    local res = utils.subprocess({ args = command, cancellable = false })
    --"atomically" generate the output to avoid loading half-generated thumbnails (results in crashes)
    if res.status == 0 then
        local info = utils.file_info(tmp_output_path)
        if not info or not info.is_file or info.size == 0 then
            return false
        end
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
                    accurate = (e.args[8] == "true"),
                    with_mpv = (e.args[9] == "true"),
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
