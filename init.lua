
trees_lib = {}

-- place this node if a sapling does not like the environment and refuses
-- to grow into a tree there
trees_lib.place_when_tree_cant_grow = {name="default:dry_shrub"};

-----------------------------------------------------------------------------
-- compatibility functions so that trees_lib can work without default mod
-----------------------------------------------------------------------------
trees_lib.sound_leaves = function()
	if( default and default.node_sound_leaves_defaults) then
		return default.node_sound_leaves_defaults(table)
	else
		return nil
	end
end

trees_lib.sound_wood = function()
	if( default and default.node_sound_wood_defaults) then
		return default.node_sound_wood_defaults(table)
	else
		return nil
	end
end

-- copy of default.after_place_leaves
trees_lib.after_place_leaves = function(pos, placer, itemstack, pointed_thing)
	local node = minetest.get_node(pos)
	node.param2 = 1
	minetest.set_node(pos, node)
end


-----------------------------------------------------------------------------
-- internal functions for handling identification of nodes (i.e. what is a
-- trunk, what is a leaf, which nodes can be replaced by new trees)
-----------------------------------------------------------------------------
-- those are helpful for fast lookup (either by name or content id) 
trees_lib.is_tree = {}
trees_lib.is_wood = {}
trees_lib.is_leaf = {}
trees_lib.is_sapling = {}
trees_lib.is_fruit   = {}
trees_lib.ignore     = {}

-- trees are allowed to replace these nodes when growing
-- (in addition to leaves, saplings and fruits from other trees)
trees_lib.ignore_list = {
	"air","ignore",
	"default:water_source","default:water_flowing",
	"default:snow","default:ice"}

trees_lib.build_lookup_table = function( node_name, node_type, value, allow_removal_by_other_saplings )
	if(   not( node_name )
	   or node_name == ""
	   or not( minetest.registered_nodes[ node_name ])
	   or not( trees_lib[ node_type ])) then
		return;
	end
	local id = minetest.get_content_id( node_name );
	-- we store by id and nodename both for faster lookup
	trees_lib[ node_type ][ id        ] = value; 
	trees_lib[ node_type ][ node_name ] = value; 
	-- if this is set, then other saplings can overwrite these nodes during
	-- their growth (i.e. replacing leaves with tree trunks)
	if( allow_removal_by_other_saplings ) then
		trees_lib.ignore[ id        ] = value;
		trees_lib.ignore[ node_name ] = value;
	end
end

-- actually store the information from the ignore list
for _,v in ipairs( trees_lib.ignore_list ) do
	trees_lib.build_lookup_table( v,"ignore", v, 1 );
end



-----------------------------------------------------------------------------
-- allow to call a function whenever a new tree has been registered
-----------------------------------------------------------------------------
-- contains a list of all functions that need to be called whenever a new tree
-- type is registered using trees_lib.register_tree(..)
trees_lib.register_on_new_tree_type_function_list = {}

-- the function new_tree_type_function will be called once for each tree type
trees_lib.register_on_new_tree_type = function( new_tree_type_function )

	-- call the function for all tree types that have been registered up
	-- until now
	for k,v in pairs( trees_lib.is_sapling) do
		new_tree_type_function( v.tree_name, v.mod_prefix, v.nodes );
	end

	-- store the function so that it will get called at all subsequent
	-- registrations of new trees
	table.insert( trees_lib.register_on_new_tree_type_function_list,
		new_tree_type_function );

end


-----------------------------------------------------------------------------
-- nodes for the trees: trunk, planks, leaves, sapling and fruit
-----------------------------------------------------------------------------
-- (internal function)
-- * if nodes.wood.dont_add_craft_receipe is set, no craft receipe
--   for 1 tree -> 4 wood will be added
-- * there can be up to 5 diffrent leaves types
trees_lib.register_tree_nodes_and_crafts = function( tree_name, mod_prefix, nodes )

	-- gather all the relevant content ids
	local cid = {};

	-- register the tree trunk
	if( nodes and nodes.tree and nodes.tree.node_name and not( minetest.registered_nodes[ nodes.tree.node_name ])) then
		minetest.register_node( nodes.tree.node_name, {
			description = nodes.tree.description,
			tiles = nodes.tree.tiles,
			paramtype2 = "facedir",
			is_ground_content = false,
			-- moretrees uses snappy=1 here as well
			groups = {tree = 1, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
			sounds = trees_lib.sound_wood,
			on_place = minetest.rotate_node
		})

		-- we need to add the craft receipe for tree -> planks;
		-- if this receipe is not desired, nodes.wood needs to contain a field dont_add_craft_receipe that is not nil
		if( nodes.wood and nodes.wood.node_name and not( nodes.wood.dont_add_craft_receipe)) then
			minetest.register_craft({
					-- the amount of wood given might be a global config variable
					output = nodes.wood.node_name..' 4',
					recipe = {
						{ nodes.tree.node_name },
					}
				});
		end
	end
	if( nodes and nodes.tree and nodes.tree.node_name and minetest.registered_nodes[ nodes.tree.node_name ]) then
		cid[ 'tree' ] = minetest.get_content_id( nodes.tree.node_name );
		trees_lib.build_lookup_table( nodes.tree.node_name,       "is_tree",    nodes.sapling.node_name, nil );
	end

	-- register the wooden planks
	if( nodes and nodes.wood and nodes.wood.node_name and not( minetest.registered_nodes[ nodes.wood.node_name ])) then
		minetest.register_node( nodes.wood.node_name, {
			description = nodes.wood.description,
			tiles = nodes.wood.tiles,
			is_ground_content = false,
			-- moretrees uses snappy=1 here
			groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 3, wood = 1},
			sounds = trees_lib.sound_wood,
		})
		-- we need to add the craft receipe for planks -> sticks
		-- (but since there is a default craft receipe for group:wood, that ought to be cover it)
	end
	if( nodes and nodes.wood and nodes.wood.node_name and minetest.registered_nodes[ nodes.wood.node_name ]) then
		cid[ 'wood' ] = minetest.get_content_id( nodes.wood.node_name );
		trees_lib.build_lookup_table( nodes.wood.node_name,       "is_wood",    nodes.sapling.node_name, nil );
	end

	-- register the leaves; some trees may have more than one type of leaves (i.e. moretrees jungletrees)
	local leaves_id = {'leaves','leaves2','leaves3','leaves4','leaves5'};
	for _,k in ipairs( leaves_id ) do 
		if( nodes and nodes[k]  and nodes[k].node_name and not( minetest.registered_nodes[ nodes[k].node_name ])) then
			minetest.register_node( nodes[k].node_name, {
				description = nodes[k].description,
				tiles = nodes[k].tiles,
				special_tiles = nodes[k].special_tiles,
			
				-- moretrees has some options for this
				drawtype = "allfaces_optional",
				waving = 1,
				visual_scale = 1.3,
				paramtype = "light",
				is_ground_content = false,
				-- moretrees sets moretrees_leaves=1, leafdecay = decay
				groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1},
				sounds = trees_lib.sound_leaves,
				after_place_node = trees_lib.after_place_leaves,
	
				drop = {
					max_items = 1,
					items = {
						{
							-- player will get sapling with 1/20 chance
							items = { nodes.sapling.node_name},
							rarity = nodes.sapling.rarity,
						},
						{
							-- player will get leaves only if he get no saplings,
							-- this is because max_items is 1
							items = { nodes[k].node_name},
						}
					}
				},
			})
		end
		if( nodes and nodes[k]  and nodes[k].node_name and minetest.registered_nodes[ nodes[k].node_name ]) then
			cid[k] = minetest.get_content_id( nodes[k].node_name );
			trees_lib.build_lookup_table( nodes[k].node_name, "is_leaf",    nodes.sapling.node_name, 1 );
		end
	end

	-- register the sapling
	if( nodes and nodes.sapling and nodes.sapling.node_name and not( minetest.registered_nodes[ nodes.sapling.node_name ])) then
		minetest.register_node( nodes.sapling.node_name, {
			description = nodes.sapling.description,
			drawtype = "plantlike",
			visual_scale = 1.0,
			tiles = nodes.sapling.tiles,
			inventory_image = nodes.sapling.tiles[1],
			wield_image = nodes.sapling.tiles[1],
			paramtype = "light",
			sunlight_propagates = true,
			walkable = false,
			selection_box = {
				type = "fixed",
				fixed = {-0.3, -0.5, -0.3, 0.3, 0.35, 0.3}
			},
			groups = {snappy = 2, dig_immediate = 3, flammable = 2,
				attached_node = 1, sapling = 1},
			sounds = trees_lib.sound_leaves,
		})
	end
	if( nodes and nodes.sapling and nodes.sapling.node_name and minetest.registered_nodes[ nodes.sapling.node_name ]) then
		cid[ 'sapling' ] = minetest.get_content_id( nodes.sapling.node_name );
		-- enter all these node names into a table for fast lookup
		-- (without having to resort to checking the group)
		-- the trees_lib.is_sapling field will later on contain more helpful information
		trees_lib.build_lookup_table( nodes.sapling.node_name,    "is_sapling", {
			sapling = nodes.sapling.node_name,
			},1);
	end

	-- register the fruit (it may be needed in order to grow the tree)
	if( nodes and nodes.fruit and nodes.fruit.node_name and not( minetest.registered_nodes[ nodes.fruit.node_name ])) then
		minetest.register_node( nodes.fruit.node_name, {
			description = nodes.fruit.description,
			drawtype = "plantlike",
			visual_scale = 1.0,
			tiles = nodes.fruit.tiles,
			inventory_image =  nodes.fruit.tiles[1],
			paramtype = "light",
			sunlight_propagates = true,
			walkable = false,
			is_ground_content = false,
			selection_box = {
				type = "fixed",
				fixed = {-0.2, -0.5, -0.2, 0.2, 0, 0.2}
			},
			groups = {fleshy = 3, dig_immediate = 3, flammable = 2,
				leafdecay = 3, leafdecay_drop = 1},
			-- TODO: what about fruits that cannot be eaten? a callback might be good
			on_use = minetest.item_eat(nodes.fruit.food_points),
			sounds = trees_lib.sound_leaves,
		
			after_place_node = function(pos, placer, itemstack)
				if placer:is_player() then
					minetest.set_node(pos, {name =  nodes.fruit.node_name, param2 = 1})
				end
			end,
		})
	end
	if( nodes and nodes.fruit and nodes.fruit.node_name and minetest.registered_nodes[ nodes.fruit.node_name ]) then
		cid[ 'fruit' ] = minetest.get_content_id( nodes.fruit.node_name );
		trees_lib.build_lookup_table( nodes.fruit.node_name,      "is_fruit",   nodes.sapling.node_name, 1 );
	end

	-- return the ids we've gathered
	return cid;
end


-----------------------------------------------------------------------------
-- growing of the trees from saplings
-----------------------------------------------------------------------------
-- turn saplings that failed to grow (because they don't like the ground or
-- environment) into dry shrub, thus allowing dry shrub farming;
-- override this function if you don't like this feature
trees_lib.failed_to_grow = function( pos, node )
	minetest.set_node( pos, trees_lib.place_when_tree_cant_grow);
end

-- this function is called just before a tree actually grows;
-- the function ought to return how_to_grow for normal tree growth;
-- returning another way of growing is also possible (i.e. diffrent
-- model when growing in flower pots/on stone)
trees_lib.change_tree_growth = function( pos, node, how_to_grow )
	return how_to_grow;
end


-- this function is called whenever a sapling of type node has grown
-- into a tree using how_to_grow at position pos
trees_lib.a_tree_has_grown = function( pos, node, how_to_grow )
	return;
end

-- called by the abm running on the saplings;
-- if force is set, the tree will grow even if it usually wouldn't in that
-- environment
trees_lib.tree_abm_called = function( pos, node, active_object_count, active_object_count_wider, force_grow)
	-- if we don't have further information about that sapling, then abort
	if(   not( node )
	   or not( node.name ) 
	   or not( trees_lib.is_sapling[ node.name ])) then
		-- turn into dry shrub (because we don't know what to do with
		-- this sapling)
		trees_lib.failed_to_grow( pos, node );
		return;
	end

	-- get information about what we're supposed to do with that sapling
	local sapling_data = trees_lib.is_sapling[ node.name ];

	-- the type of ground might be of intrest for further functions (i.e. can_grow, select_how_to_grow)
	local ground_found = nil;
	-- a quick check of the ground; sapling_data.grows_on has to be a list of all
	-- ground types acceptable for the tree
	if( not(force_grow) and sapling_data.grows_on and type( sapling_data.grows_on )=="table") then
		local node_under = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z});
		-- abort if this check cannot be done
		if( not(node_under) or node_under.name=="ignore") then
			return;
		end
		-- search all acceptable ground names
		for _,g in ipairs( sapling_data.grows_on ) do
			if( g==node_under.name ) then
				ground_found = g;
			elseif( not( ground_found)
			    and string.sub(g,1,6)=="group:"
			    and minetest.get_item_group( node_under.name, string.sub(g,7))~=0 ) then
				ground_found = g;
			end
		end
		-- abort if the tree does not like this type of ground
		if( not( ground_found )) then
			-- trun into dry shrub
			trees_lib.failed_to_grow( pos, node );
			return;
		end
	end

	-- the tree may come with a more complex function that checks if it can grow there
	if( not(force_grow) and sapling_data.can_grow and type( sapling_data.can_grow)=="function" ) then
		-- the parameter ground_found is nil if the tree did not specify any demands for a particular ground
		if( not( sapling_data.can_grow( pos, node, ground_found ))) then
			-- trun into dry shrub
			trees_lib.failed_to_grow( pos, node, ground_found );
			return;
		end
	end

	-- each tree can have several ways of growing
	local how_to_grow = nil;
	-- the sapling may - depending on the circumstances - choose a specific growth function
	-- instead of a random one
	if( sapling_data.select_how_to_grow and type( sapling_data.select_how_to_grow)=="function") then
		-- ground_found is nil if the tree did not specify any demands for a particular ground
		how_to_grow = sapling_data.select_how_to_grow( pos, node, sapling_data.how_to_grow, ground_found );
		-- the select_how_to_grow function may either return a table or a number indicating which
		-- growth method to select
		if( how_to_grow and type(how_to_grow)=="number" and sapling_data.how_to_grow[ how_to_grow ]) then
			how_to_grow = sapling_data.how_to_grow[ how_to_grow ];
		end
	else -- else select a random one
		how_to_grow = sapling_data.how_to_grow[ math.random( 1, #sapling_data.how_to_grow )];
	end

	-- this function may change the way the tree grows (i.e. select a special method for trees growing in flower pots or on stone ground)
	how_to_grow = trees_lib.change_tree_growth( pos, node, how_to_grow );

	-- abort if no way was found to grow the tree
	if( not( how_to_grow ) or type(how_to_grow)~="table") then
		trees_lib.failed_to_grow( pos, node );
		return;

	-- grow the tree using a function (like the old apple trees did)
	elseif( how_to_grow.use_function and type(how_to_grow.use_function)=="function") then

		-- get the voxelmanip data
		local vm = minetest.get_voxel_manip()
		local minp, maxp = vm:read_from_map(
			{x = pos.x - how_to_grow.xoff, y = pos.y - how_to_grow.yoff,   z = pos.z - how_to_grow.zoff},
			{x = pos.x + how_to_grow.xoff, y = pos.y + how_to_grow.height, z = pos.z + how_to_grow.zoff}
		)
		local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
		local data = vm:get_data()

		how_to_grow.use_function( data, a, pos, sapling_data );

		-- write the data back
		vm:set_data(data)
		vm:write_to_map()
		vm:update_map()


	-- grow the tree using a schematic
	elseif( how_to_grow.use_schematic and type(how_to_grow.use_schematic)=="string") then
		-- TODO: use voxelmanip
		-- remove the sapling
		minetest.set_node( pos, {name="air"});
		-- TODO: determine xoff, yoff and zoff when registering the tree
		--       (if yoff is not given, then use 0)
		minetest.place_schematic(
			{x = pos.x - how_to_grow.xoff,
			 y = pos.y - how_to_grow.yoff,
			 z = pos.z - how_to_grow.zoff},
			how_to_grow.use_schematic, -- full path to the .mts file
			"random", -- rotation
			how_to_grow.use_replacements, -- use the same schematic for diffrent trees
			false --  no overwriting of existing nodes
			);

	-- grow the tree using L-system
	elseif( how_to_grow.use_lsystem and type(how_to_grow.use_lsystem)=="table") then
		-- remove the sapling
		minetest.set_node( pos, {name="air"});
		-- spawn the l-system tree
		minetest.spawn_tree(pos, how_to_grow.use_lsystem );

	-- else prevent call of success function below
	else
		return;
	end

	trees_lib.a_tree_has_grown( pos, node, how_to_grow );
end


-----------------------------------------------------------------------------
-- register a new tree
-----------------------------------------------------------------------------
trees_lib.register_tree = function( tree_name, mod_prefix, nodes, growing_methods, grows_on_node_type_list, can_grow_function, select_how_to_grow_function )
	-- register tree trunk, wood, leaves and fruit (provided they are not defined yet)
	local cid_list = trees_lib.register_tree_nodes_and_crafts( tree_name, mod_prefix, nodes );

	-- a sapling will be needed for growing the tree
	if(   not( nodes.sapling )
	   or not( nodes.sapling.node_name )
	   or not( growing_methods )) then
		return;
	end

	-- store information about the new tree type in the sapling table
	trees_lib.is_sapling[ nodes.sapling.node_name ] = {

		-- minetest.get_content_id for tree, wood, leaves1..n, sapling, fruit
		cid           = cid_list,

		-- node name of the sapling
		sapling       = nodes.sapling.node_name,

		-- values passed on to all functions registered via
		--      trees_lib.register_on_new_tree_type = function( new_tree_type_function )
		tree_name     = tree_name,
		mod_prefix    = mod_prefix,
		nodes         = nodes,

		-- list of node names (can contain groups, i.e. "group:soil")
		-- on which the sapling will grow;
		-- note: the parameter ground_found to the functions below can only be
		--       passed on if grows_on has been specified (else the sapling does
		--       not do any ground checks on its own)
		grows_on      = grows_on_node_type_list,

		-- are all the requirements met for growing at pos?
		-- sapling will only grow if
		--      growing.can_grow( pos, node, ground_found )
		-- returns true
		-- (usful for i.e. requiring water nearby, or other
		-- more complex requirements)
		can_grow      = can_grow_function,

		-- has to be either nil (for selecting a random way)
		-- or return a specific growth function like the ones in
		-- the list how_to_grow (see below) when called with
		--      growing.select_how_to_grow( pos, node, growing.how_to_grow, ground_found )
		select_how_to_grow = select_how_to_grow_function,

		-- list of all methods that can turn the sapling into a
		-- tree; can be a function, a file name containing a schematic
		-- or a table for L-system trees;
		-- this table/list is REQUIRED
		how_to_grow   = growing_methods,
	};

	-- a new tree was registered - call all functions that want to be told about new trees
	for i,new_tree_type_function in ipairs( trees_lib.register_on_new_tree_type_function_list ) do
		new_tree_type_function( tree_name, mod_prefix, nodes );
	end

	-- now add the abm that lets the tree grow
	minetest.register_abm({
		nodenames = { nodes.sapling.node_name },
		interval = 10,
		chance = 1,
		action = trees_lib.tree_abm_called,
	});
end


--[[ the version from mg_villages
-- this is more or less the code to grow an apple tree with v6
trees_lib.generate_fruit_tree = function(data, a, pos,     is_apple_tree, seed, snow)
    local leaves_type = c_leaves;
    if(  snow
      or data[ a:index(pos.x, pos.y,   pos.z) ] == c_snow
      or data[ a:index(pos.x, pos.y+1, pos.z) ] == c_snow ) then
       leaves_type = c_msnow_leaves2; 
    end

    local hight = math.random(4, 5)
    for x_area = -2, 2 do
    for y_area = -1, 2 do
    for z_area = -2, 2 do
        if math.random(1,30) < 23 then  --randomize leaves
            local area_l = a:index(pos.x+x_area, pos.y+hight+y_area-1, pos.z+z_area)  --sets area for leaves
            if data[area_l] == c_air or data[area_l] == c_ignore or data[area_l]== c_snow then    --sets if it's air or ignore 
		if( snow and c_msnow_leaves1 and math.random( 1,5 )==1) then
			data[area_l] = c_msnow_leaves1;
		else
	                data[area_l] = leaves_type    --add leaves now
		end
            end
            -- put a snow top on some leaves
            if ( snow and math.random(1,3)==1 )then
               mg_villages.trees_add_snow(data, a:index(pos.x+x_area, pos.y+hight+y_area, pos.z+z_area), c_air, c_ignore, c_snow)
            end
         end       
    end
    end
    end
    for tree_h = 0, hight-1 do  -- add the trunk
        local area_t = a:index(pos.x, pos.y+tree_h, pos.z)  --set area for tree
        if data[area_t] == c_air or data[area_t] == c_leaves or data[area_t] == c_sapling or data[area_t] == c_snow or data[area_t] == c_msnow_top or data[area_t] == c_msnow_leaves1 or data[area_t] == c_msnow_leaves2 then    --sets if air
            data[area_t] = c_tree    --add tree now
        end
    end
end

--]]

-- Apple tree and jungle tree trunk and leaves function

trees_lib.generate_fruit_tree = function(data, a, pos, sapling_data )

	local tree_cid   = sapling_data.cid.tree;
	local leaves_cid = sapling_data.cid.leaves;
	local fruit_cid  = sapling_data.cid.fruit;

	local height = math.random(3,7);
	local size   = 2; --math.random(1,3);
	local iters  = 8;

	local x, y, z = pos.x, pos.y, pos.z
	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")

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
				if fruit_cid and fruit_cid ~= leaves_cid and math.random(1, 8) == 1 then
					data[vi] = fruit_cid
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
		local clust_x = x + math.random(-size, size - 1)
		local clust_y = y + height + math.random(-size, 0)
		local clust_z = z + math.random(-size, size - 1)

		for xi = 0, 1 do
		for yi = 0, 1 do
		for zi = 0, 1 do
			local vi = a:index(clust_x + xi, clust_y + yi, clust_z + zi)
			if data[vi] == c_air or data[vi] == c_ignore then
				if fruit_cid and fruit_cid ~= leaves_cid and math.random(1, 8) == 1 then
					data[vi] = fruit_cid
				else
					data[vi] = leaves_cid
				end
			end
		end
		end
		end
	end
end


--- the standard tree; sometimes it turns out to be an apple tree
trees_lib.register_tree( "silly", "trees_lib",
	{  tree = {
		node_name    = "trees_lib:silly_tree",
		description  = "Silly Tree",
		tiles        = {"default_tree_top.png^[colorize:#015dbb70", "default_tree_top.png^[colorize:#015dbb70", "default_tree.png^[colorize:#015dbb70"},
	}, wood = {
		node_name    = "trees_lib:silly_wood",
		description  = "Silly Wooden Planks",
		tiles        = {"default_wood.png"},
	}, leaves = {
		node_name    = "trees_lib:silly_leaves",
		description  = "Silly Leaves",
		tiles        = {"default_leaves.png^[colorize:#01ffd870"},
		special_tiles= {"default_leaves_simple.png^[colorize:#01ffd870"},
	}, sapling = {
		node_name    = "trees_lib:silly_sapling",
		description  = "Silly Tree Sapling",
		tiles        = {"default_sapling.png^[colorize:#ff840170"},

		rarity       = 20,
	}, fruit = {
		node_name    = "trees_lib:cfruit",
		description  = "Yellow Copper Fruit",
		tiles        = {"default_copper_lump.png^[colorize:#e3ff0070"},
		food_points  = 2,
	}},
	-- the diffrent ways of how a tree can be grown
	{
		-- one of these methods will be choosen randomly
		{
			-- a function - like that used to create the trees/apple trees in mapgen v6
			use_function = trees_lib.generate_fruit_tree,
			-- How far will the tree reach in each direction? We need to load a
			-- sufficiently large voxelmanip area.
			xoff = 2, zoff = 2, yoff = 0, height = 12,
		}, {
			-- schematics can be used as well
			use_schematic = minetest.get_modpath("default").."/schematics/acacia_tree_from_sapling.mts",
			-- TODO: determine these values automaticly
			xoff = 4, zoff = 4, yoff = 0, height = 10,
			-- use a schematic with diffrent nodes
			use_replacements = {
				{"default:acacia_tree",  "trees_lib:silly_tree"},
				{"default:acacia_leaves","trees_lib:silly_leaves"},
			}
		}, {
			-- this is moretrees.birch_model1
			use_lsystem = {
				axiom="FFFFFdddccA/FFFFFFcA/FFFFFFcB",
				rules_a="[&&&dddd^^ddddddd][&&&---dddd^^ddddddd][&&&+++dddd^^ddddddd][&&&++++++dddd^^ddddddd]",
				rules_b="[&&&ddd^^ddddd][&&&---ddd^^ddddd][&&&+++ddd^^ddddd][&&&++++++ddd^^ddddd]",
				rules_c="/",
				rules_d="F",
				trunk="trees_lib:silly_tree", --"moretrees:birch_trunk",
				leaves="trees_lib:silly_leaves", --"moretrees:birch_leaves",
				angle=30,
				iterations=2,
				random_level=0,
				trunk_type="single",
				thin_branches=true
			}
		},{
			-- this is moretrees.birch_model2
			use_lsystem = {
				axiom="FFFdddccA/FFFFFccA/FFFFFccB",
				rules_a="[&&&dFFF^^FFFdd][&&&---dFFF^^FFFdd][&&&+++dFFF^^FFFdd][&&&++++++dFFF^^FFFdd]",
				rules_b="[&&&dFF^^FFFd][&&&---dFFF^^FFFd][&&&+++dFF^^FFFd][&&&++++++dFF^^FFFd]",
				rules_c="/",
				rules_d="F",
				trunk="trees_lib:silly_tree", --"moretrees:birch_trunk",
				leaves="trees_lib:silly_leaves", --"moretrees:birch_leaves",
				angle=30,
				iterations=2,
				random_level=0,
				trunk_type="single",
				thin_branches=true
			}
		},
	},
	-- grows_on_node_type_list - the tree only grows on nodes of this type
	{"default:cobble", "group:soil"},
	-- no limits as to where the tree can grow (no can_grow_function)
	nil,
	-- no select_how_to_grow_function - the tree uses the same method everywhere
	nil
	);


--[[
tree data:
	growth_function = {
		grows_on = {"group:soil", "default:desert_sand", "homedecor:flower_pot_green"}, -- etc.
		-- can the sapling in node grow at pos?
		can_grow_function = function( pos, node )
				return true;
			end,
		-- which of the various growth functions shall be used for this sapling?
		-- if select_how_to_grow is not provided, a random one will be selected
		select_how_to_grow = function( pos, node )
				return 1;
		end,
		-- list of tables of all methods known for spawning this tree
		how_to_grow = {}
--]]
