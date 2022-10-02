local utils = require 'mp.utils'
local msg = require 'mp.msg'

local gallery_utils = {}

function gallery_utils.blend_colors(colors)
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

function gallery_utils.normalize_path(cwd, path)
    if string.find(path, "://") then
        return path
    end
    path = utils.join_path(cwd, path)
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

function gallery_utils.make_gallery_geometry_function(position_formula, size_formula, min_spacing_formula, thumbnail_size_formula)

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
    }]], position_formula, size_formula, min_spacing_formula, thumbnail_size_formula))()

    local formulas = { position_formula, size_formula, min_spacing_formula, thumbnail_size_formula }
    local names = { "gallery_position", "gallery_size", "min_spacing", "thumbnail_size" }
    local order = {} -- the order in which the 4 properties should be computed, based on inter-dependencies

    -- build the dependency matrix
    local patterns = { "g[xy]", "g[wh]", "s[wh]", "t[wh]" }
    local deps = {}
    for i = 1,4 do
        for j = 1,4 do
            local i_depends_on_j = (string.find(formulas[i], patterns[j]) ~= nil)
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

    return function(window_width, window_height, text_size)
        local new_geom = {
             position = {},
             size = {},
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
            if text_size and names[index] == "min_spacing" then
                new_geom.min_spacing[2] = math.max(text_size, new_geom.min_spacing[2])
            elseif names[index] == "thumbnail_size" then
                new_geom.thumbnail_size[1] = math.floor(new_geom.thumbnail_size[1])
                new_geom.thumbnail_size[2] = math.floor(new_geom.thumbnail_size[2])
            end
        end
        return new_geom
    end
end

return gallery_utils
