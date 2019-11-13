#!/usr/bin/luajit



--apt-get install libvips libvips-dev
--luarocks install --local lua-vips

-- sudo apt-get install libmagickwand-dev
-- sudo luarocks install magick

--luarocks install --local json-lua
--eval $(luarocks path)
--Launch using luajit

local json = require "JSON"
local im = require "magick"

local rgbconv = 255

local file_path_cache = {}
local file_not_found_cache = {}

-- READ JSON FILES PROVIDED BY MOD

local mods, nodes
local file = io.open("modpath.json", "r")
if file then
	mods = json:decode(file:read("*all"))
	file:close()
end

local file = io.open("nodedefs.json", "r")
if file then
	nodes = json:decode(file:read("*all"))
	file:close()
end


-- Find texture file in mods
function find_file(name)
	if type(name)~="string" then return false end

	if file_path_cache[name] then
		return file_path_cache[name]
	end

	if file_not_found_cache[name] then
		return nil
	end

	for _, path in pairs(mods) do
		local f = io.open(path.."/textures/"..name)
		if f then
			f:close()
			file_path_cache[name] = path.."/textures/"..name
			return file_path_cache[name]
		end
	end
	print("File \""..name.."\" not found!")
	file_not_found_cache[name] = true
	return nil
end

local image_colors_cache = {}

local function get_average_image_file_color(name)

	if image_colors_cache[name] then
		return unpack(image_colors_cache[name])
	end

	local path = find_file(name)

	if not path then
		image_colors_cache[name] = {0, 0, 0, 0}
		return unpack(image_colors_cache[name])
	end

	local image = im.load_image(path)
	image:resize(1, 1)
	local r, g, b, a = image:get_pixel(0, 0)
	image_colors_cache[name] = {r, g, b, a}
	return unpack(image_colors_cache[name])
end

local function get_average_overlays_color(overlays, nodename)
	local r, g, b, a = 0, 0, 0, 0
	for _, overlay in ipairs(overlays) do
		if overlay:sub(1,1) == "[" then
			local effect
			local params = {}
			local pos = string.find(overlay, ":")
			if pos then
				effect = string.sub(overlay, 2, pos-1)
				for param in string.gmatch(string.sub(overlay, pos+1), "[^:]+") do
					params[#params+1] = param
				end
			else
				effect = string.sub(overlay, 2)
			end

			-- TODO: Manage effects here
			if effect == "colorize" then
			end
			print(string.format("Node %s, ignored effect %s", nodename, effect))
		else
			local rr, gg, bb, aa = get_average_image_file_color(overlay)
			if aa > 0 then
				-- https://fr.wikipedia.org/wiki/Alpha_blending
				r = (r * a + rr * aa * (1 - a)) / (a + aa * (1 - a))
				g = (g * a + gg * aa * (1 - a)) / (a + aa * (1 - a))
				b = (b * a + bb * aa * (1 - a)) / (a + aa * (1 - a))
				a = a + aa * (1 - a)
			end
		end
	end
	return r, g, b, a
end

local function strip_surrounding_braces(str)
	if #str < 2 then
		return str
	end

	if str:sub(1, 1) == "(" and str:sub(#str, #str) == ")" then
		return strip_surrounding_braces(str:sub(2, #str -1))
	end

	return str
end

local function get_overlays(texture)
	local overlays = {}
	local bracelevel = 0
	local start = 1
	local hasbraces = false
	for i = 1, #texture do
		local char = texture:sub(i,i)
		if char == "(" then
			hasbraces = true
			bracelevel = bracelevel + 1
		end
		if char == ")" then
			if bracelevel > 0 then
				bracelevel = bracelevel - 1
			else
				return nil, "Braces not matching"
			end
		end
		if char == "^" and bracelevel == 0 then
			if hasbraces then
				overlays[#overlays+1] = get_overlays(
					strip_surrounding_braces(texture:sub(start, i - 1)))
			else
				overlays[#overlays+1] = strip_surrounding_braces(texture:sub(start, i - 1))
			end
			start = i + 1
			hasbraces = false
		end
	end
	if bracelevel > 0 then
		return nil, "Braces not matching"
	end
	if start < #texture then
		if hasbraces then
			overlays[#overlays+1] = get_overlays(
				strip_surrounding_braces(texture:sub(start, #texture)))
		else
			overlays[#overlays+1] = strip_surrounding_braces(texture:sub(start, #texture))
		end
	end

	return overlays, nil
end

local function print_table(table, level)
	level = level or 0
	for key, value in pairs(table) do
		if type(value) == "table" then
			print(string.rep("  ", level).."["..key.."]=")
			print_table(value, level + 1)
		else
			print(string.rep("  ", level).."["..key.."]="..value)
		end
	end
end

local outputfile = "colors.txt"
local drawtypes = {}
local count = 0

local file = io.open(outputfile, "w")
if not file then
	print("Unable to open " .. outputfile .. " for writing!")
	return
end

for name, ndef in pairs(nodes) do
	if ndef.drawtype ~= "airlike" then
		local texture
		if type(ndef.tiles) == "string" then
			texture = ndef.tiles
		elseif type(ndef.tiles) == "table" then
			local tile = ndef.tiles[1]
			if type(tile) == "string" then
				texture = tile
			elseif type(tile) == "table" then
				texture = tile.name
			end
		end

		local overlays = nil

		if texture then
			overlays = get_overlays(texture)
		end

		if overlays then
			r, g, b, a = get_average_overlays_color(overlays, name)
			file:write(string.format("%s %d %d %d\n", name, r*rgbconv, g*rgbconv, b*rgbconv))
		end

		count = count + 1
	end
end

file:close()

print(string.format("File %s generated with %d nodes.", outputfile, count))
