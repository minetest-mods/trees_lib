--
-- Grow trees from saplings
--

-- add craft receipes for turning 1 tree into 4 corresponding wood;
-- this function will be called for each registered tree
local default_craft_wood_from_tree = function( tree_name, mod_prefix, nodes )
	if( not( nodes )
	  or not( nodes.tree ) or not( nodes.tree.node_name )
	  or not( nodes.wood ) or not( nodes.wood.node_name )) then
		return;
	end

	minetest.register_craft({
		-- the amount of wood given might be a global config variable
		output = nodes.wood.node_name..' 2',
		recipe = {
			{ nodes.tree.node_name },
		}
	});
end

trees_lib.register_on_new_tree_type( default_craft_wood_from_tree );



-- 'Can grow' function

local random = math.random

local function can_grow(pos)
	local ll = minetest.get_node_light(pos)
	-- return -1 - no final abort, just don't grow yet
	if not ll or ll < 13 then -- Minimum light level for growth
		return -1          -- matches grass, wheat and cotton
	end
	return 1; -- the tree can grow
end



-- default trees grow using a function if they detect mapgen v6 - and a schematic otherwise
local default_select_how_to_grow = function( pos, node, how_to_grow, ground_found )
	local mapgen = minetest.get_mapgen_params().mgname
	if mapgen == "v6" then
		-- select growing method 1 (previously set to a function)
		return 1;
	else
		-- select growing method 2 (previously set to a schematic)
		return 2;
	end
end


-- log successful growth; for that, we override the a_tree_has_grown function
local old_a_tree_has_grown = trees_lib.a_tree_has_grown;
trees_lib.a_tree_has_grown = function( pos, node, how_to_grow )
	minetest.log("action", "A "..tostring( node.name ).." grows into a tree at "..
				minetest.pos_to_string(pos))
	old_a_tree_has_grown( pos, node, how_to_grow );
end


--
-- Tree generation
--

-- Apple tree and jungle tree trunk and leaves function

local function add_trunk_and_leaves(data, a, pos, tree_cid, leaves_cid,
		height, size, iters, is_apple_tree)
	local x, y, z = pos.x, pos.y, pos.z
	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")
	local c_apple = minetest.get_content_id("default:apple")

	-- Trunk
	data[a:index(x, y, z)] = tree_cid -- Force-place lowest trunk node to replace sapling
	for yy = y + 1, y + height - 1 do
		local vi = a:index(x, yy, z)
		local node_id = data[vi]
		if node_id == c_air or node_id == c_ignore or node_id == leaves_cid then
			data[vi] = tree_cid
		end
	end

	-- Force leaves near the trunk
	for z_dist = -1, 1 do
	for y_dist = -size, 1 do
		local vi = a:index(x - 1, y + height + y_dist, z + z_dist)
		for x_dist = -1, 1 do
			if data[vi] == c_air or data[vi] == c_ignore then
				if is_apple_tree and random(1, 8) == 1 then
					data[vi] = c_apple
				else
					data[vi] = leaves_cid
				end
			end
			vi = vi + 1
		end
	end
	end

	-- Randomly add leaves in 2x2x2 clusters.
	for i = 1, iters do
		local clust_x = x + random(-size, size - 1)
		local clust_y = y + height + random(-size, 0)
		local clust_z = z + random(-size, size - 1)

		for xi = 0, 1 do
		for yi = 0, 1 do
		for zi = 0, 1 do
			local vi = a:index(clust_x + xi, clust_y + yi, clust_z + zi)
			if data[vi] == c_air or data[vi] == c_ignore then
				if is_apple_tree and random(1, 8) == 1 then
					data[vi] = c_apple
				else
					data[vi] = leaves_cid
				end
			end
		end
		end
		end
	end
end


-- Apple tree

function default.grow_apple_tree( data, a, pos, sapling_data, extra_params )

	-- translate parameter names
        local c_tree   = sapling_data.cid.tree;
        local c_leaves = sapling_data.cid.leaves;
	-- about every 4th tree is an apple tree
	local is_apple_tree = (random(1, 4) == 1);
	local height = random(4, 5)

	-- call the actual tree generation function
	add_trunk_and_leaves(data, a, pos, c_tree, c_leaves, height, 2, 8, is_apple_tree)
end


-- Jungle tree

function default.grow_jungle_tree(data, a, pos, sapling_data, extra_params )
	--[[
		NOTE: Jungletree-placing code is currently duplicated in the engine
		and in games that have saplings; both are deprecated but not
		replaced yet
	--]]

	-- translate parameter names
        local c_jungletree   = sapling_data.cid.tree;
        local c_jungleleaves = sapling_data.cid.leaves;

	local height = random(8, 12)

	add_trunk_and_leaves(data, a, pos, c_jungletree, c_jungleleaves, height, 3, 30, false)

	-- further parameters for the roots
	local x, y, z = pos.x, pos.y, pos.z
	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")
	-- Roots
	for z_dist = -1, 1 do
		local vi_1 = a:index(x - 1, y - 1, z + z_dist)
		local vi_2 = a:index(x - 1, y, z + z_dist)
		for x_dist = -1, 1 do
			if random(1, 3) >= 2 then
				if data[vi_1] == c_air or data[vi_1] == c_ignore then
					data[vi_1] = c_jungletree
				elseif data[vi_2] == c_air or data[vi_2] == c_ignore then
					data[vi_2] = c_jungletree
				end
			end
			vi_1 = vi_1 + 1
			vi_2 = vi_2 + 1
		end
	end
end


-- Pine tree from mg mapgen mod, design by sfan5, pointy top added by paramat

local function add_pine_needles(data, vi, c_air, c_ignore, c_snow, c_pine_needles)
	local node_id = data[vi]
	if node_id == c_air or node_id == c_ignore or node_id == c_snow then
		data[vi] = c_pine_needles
	end
end

local function add_snow(data, vi, c_air, c_ignore, c_snow)
	local node_id = data[vi]
	if node_id == c_air or node_id == c_ignore then
		data[vi] = c_snow
	end
end

function default.grow_pine_tree(data, a, pos, sapling_data, extra_params )

	-- translate parameter names
        local c_pine_tree    = sapling_data.cid.tree;
        local c_pine_needles = sapling_data.cid.leaves;

	-- other internal parameters
	local x, y, z = pos.x, pos.y, pos.z
	local maxy = y + random(9, 13) -- Trunk top

	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")
	local c_snow = minetest.get_content_id("default:snow")
	local c_snowblock = minetest.get_content_id("default:snowblock")
	local c_dirtsnow = minetest.get_content_id("default:dirt_with_snow")

	-- Scan for snow nodes near sapling to enable snow on branches
	local snow = false
	for yy = y - 1, y + 1 do
	for zz = z - 1, z + 1 do
		local vi  = a:index(x - 1, yy, zz)
		for xx = x - 1, x + 1 do
			local nodid = data[vi]
			if nodid == c_snow or nodid == c_snowblock or nodid == c_dirtsnow then
				snow = true
			end
			vi  = vi + 1
		end
	end
	end

	-- Upper branches layer
	local dev = 3
	for yy = maxy - 1, maxy + 1 do
		for zz = z - dev, z + dev do
			local vi = a:index(x - dev, yy, zz)
			local via = a:index(x - dev, yy + 1, zz)
			for xx = x - dev, x + dev do
				if random() < 0.95 - dev * 0.05 then
					add_pine_needles(data, vi, c_air, c_ignore, c_snow,
						c_pine_needles)
					if snow then
						add_snow(data, via, c_air, c_ignore, c_snow)
					end
				end
				vi  = vi + 1
				via = via + 1
			end
		end
		dev = dev - 1
	end

	-- Centre top nodes
	add_pine_needles(data, a:index(x, maxy + 1, z), c_air, c_ignore, c_snow,
		c_pine_needles)
	add_pine_needles(data, a:index(x, maxy + 2, z), c_air, c_ignore, c_snow,
		c_pine_needles) -- Paramat added a pointy top node
	if snow then
		add_snow(data, a:index(x, maxy + 3, z), c_air, c_ignore, c_snow)
	end

	-- Lower branches layer
	local my = 0
	for i = 1, 20 do -- Random 2x2 squares of needles
		local xi = x + random(-3, 2)
		local yy = maxy + random(-6, -5)
		local zi = z + random(-3, 2)
		if yy > my then
			my = yy
		end
		for zz = zi, zi+1 do
			local vi = a:index(xi, yy, zz)
			local via = a:index(xi, yy + 1, zz)
			for xx = xi, xi + 1 do
				add_pine_needles(data, vi, c_air, c_ignore, c_snow,
					c_pine_needles)
				if snow then
					add_snow(data, via, c_air, c_ignore, c_snow)
				end
				vi  = vi + 1
				via = via + 1
			end
		end
	end

	local dev = 2
	for yy = my + 1, my + 2 do
		for zz = z - dev, z + dev do
			local vi = a:index(x - dev, yy, zz)
			local via = a:index(x - dev, yy + 1, zz)
			for xx = x - dev, x + dev do
				if random() < 0.95 - dev * 0.05 then
					add_pine_needles(data, vi, c_air, c_ignore, c_snow,
						c_pine_needles)
					if snow then
						add_snow(data, via, c_air, c_ignore, c_snow)
					end
				end
				vi  = vi + 1
				via = via + 1
			end
		end
		dev = dev - 1
	end

	-- Trunk
	data[a:index(x, y, z)] = c_pine_tree -- Force-place lowest trunk node to replace sapling
	for yy = y + 1, maxy do
		local vi = a:index(x, yy, z)
		local node_id = data[vi]
		if node_id == c_air or node_id == c_ignore or
				node_id == c_pine_needles or node_id == c_snow then
			data[vi] = c_pine_tree
		end
	end
end




--
-- Trees
--

-- the normal tree does not have a special name and no space after it
trees_lib.register_tree( "normal",
	{ tree = {
		node_name = "default:tree",
		tiles = {"default_tree_top.png", "default_tree_top.png", "default_tree.png"},
		paramtype2 = "facedir",
	}, wood = {
		node_name = "default:wood",
		description = "Wooden Planks",
		tiles = {"default_wood.png"},
	}, sapling = {
		node_name = "default:sapling",
		description = "Sapling",
		tiles = {"default_sapling.png"},
	}, leaves = {
		node_name = "default:leaves",
		description = "Leaves",
		tiles = {"default_leaves.png"},
		special_tiles = {"default_leaves_simple.png"},
	}, fruit = {
		node_name = "default:apple",
		description = "Apple",
		tiles = {"default_apple.png"},
		on_use = minetest.item_eat(2),
	}},
	-- growing methods:
	{
		   { -- the first growing method uses a function
			use_function = default.grow_apple_tree,
			xoff = 2, zoff = 2, yoff = 8, height = 15,
		}, { -- the second growing method (when mapgen is not v6) uses a schematic
			use_schematic = minetest.get_modpath("default") .. "/schematics/apple_tree_from_sapling.mts",
			xoff = 2, zoff = 2, yoff = 1, height = 10,
		}
	},
	-- grows on nodes of this type:
	{"group:soil"},
	-- can_grow_function: (in this case, checks if there is enough light)
	can_grow,
	-- select_how_to_grow_function:
	default_select_how_to_grow,
	-- interval (for the abm)
	10,
	-- chance (for the abm)
	50
	);

-- the jungletree has no space between tree name and fruther parts of the name
trees_lib.register_tree( "jungle",
	{ tree = {
		node_name = "default:jungletree",
		description = "Jungle Tree",
		tiles = {"default_jungletree_top.png", "default_jungletree_top.png",
			"default_jungletree.png"},
	}, wood = {
		node_name = "default:junglewood",
		description = "Junglewood Planks",
		tiles = {"default_junglewood.png"},
	}, sapling = {
		node_name = "default:junglesapling",
		description = "Jungle Sapling",
		tiles = {"default_junglesapling.png"},
	}, leaves = {
		node_name = "default:jungleleaves",
		description = "Jungle Leaves",
		tiles = {"default_jungleleaves.png"},
		special_tiles = {"default_jungleleaves_simple.png"},
	-- the jungletree has no fruit
	}, fruit = {
		node_name = "air",
	}},
	{	  { -- the first growing method uses a function
			use_function = default.grow_jungle_tree,
			xoff = 3, zoff = 3, yoff = 1, height = 15,
		},{ -- new jungle tree (grown from schematic)
			use_schematic = minetest.get_modpath("default") .. "/schematics/jungle_tree_from_sapling.mts",
			xoff = 2, zoff = 2, yoff = 1, height = 10,
		}
	},
	{"group:soil"},
	can_grow,
	default_select_how_to_grow,
	10, 50);


-- the pine tree mostly follows naming conventions
trees_lib.register_tree( "pine",
	-- ...except for the leaves, which are needles
	{  leaves = {
		node_name = "default:pine_needles",
		description = "Pine Needles",
		tiles = {"default_pine_needles.png"},
	-- the pine tree also has no fruit
	}, fruit = {
		node_name = "air",
	}},
	{
		   { -- the old pine tree (in mapgen v6) grows using a function
			use_function = default.grow_pine_tree,
			-- we need to know how much space will have to be loaded into voxelmanip
			xoff = 3, zoff = 3, yoff = 1, height = 18,
		}, { -- new pine tree (grown from schematic)
			use_schematic = minetest.get_modpath("default") .. "/schematics/pine_tree_from_sapling.mts",
			xoff = 2, zoff = 2, yoff = 1, height = 10,
		}
	},
	{"group:soil"},
	can_grow,
	default_select_how_to_grow,
	10, 50);


-- the acacia tree follows naming conventions
trees_lib.register_tree( "acacia",
	-- the acacia tree has no fruit
	{ fruit = {
		node_name = "air",
	}},
	-- the acacia only knows to grow from a schematic
	{
		   { -- new acacia tree (grown from schematic)
			use_schematic = minetest.get_modpath("default") .. "/schematics/acacia_tree_from_sapling.mts",
			xoff = 4, zoff = 4, yoff = 1, height = 10,
		}
	},
	{"group:soil","group:sand"},
	can_grow,
	-- the acacia only has the schematic version - there is no other growing method to select
	nil,
	10, 50);

