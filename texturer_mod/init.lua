minetest.register_chatcommand("dump_node_info", {
	params = "",
	description = "Dump node info to json files for mapper",
	func = function(name, param)
		local mods = {}
		local nodes = {}
		for name, ndef in pairs(minetest.registered_nodes) do
			mods[ndef.mod_origin] = minetest.get_modpath(ndef.mod_origin)
			nodes[name] = {
				name = ndef.name,
				drawtype = ndef.drawtype,
				node_box = ndef.node_box,
				tiles = ndef.tiles,
				use_texture_alpha = ndef.use_texture_alpha,
				alpha = ndef.alpha,
				post_effect_color = ndef.alpha,
				sunlight_propagates = ndef.sunlight_propagates,
			}
		end

		local file = io.open(minetest.get_worldpath().."/modpath.json", "w")
		if file then
			file:write(minetest.write_json(mods))
			file:close()
		end

		local file = io.open(minetest.get_worldpath().."/nodedefs.json", "w")
		if file then
			file:write(minetest.write_json(nodes))
			file:close()
		end
	end,
})
