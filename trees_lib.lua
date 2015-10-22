
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

-- generalized function called after placing fruits
trees_lib.after_place_fruit = function(pos, placer, itemstack, pointed_thing)
	if placer:is_player() then
		-- find out the node name (this function is for all fruits that do not override it)
		local node = minetest.get_node( pos );
		if( node and node.name) then
			minetest.set_node(pos, {name =  node.name, param2 = 1})
		end
	end
end


-----------------------------------------------------------------------------
-- the various node definitions that are common to all nodes of that type
-- (unless overriden)
-----------------------------------------------------------------------------
trees_lib.node_def_tree = {
		--description = "TREENAME Tree",
		--tiles = nodes.tree.tiles,
		paramtype2 = "facedir",
		is_ground_content = false,
		-- moretrees uses snappy=1 here as well
		groups = {tree = 1, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
		sounds = trees_lib.sound_wood,
		on_place = minetest.rotate_node
	}

trees_lib.node_def_wood = {
		--description = "TREENAME Wood Planks",
		--tiles = nodes.wood.tiles,
		is_ground_content = false,
		-- moretrees uses snappy=1 here
		groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 3, wood = 1},
		sounds = trees_lib.sound_wood,
	}

trees_lib.node_def_leaves = {
		--description = "TREENAME Leaves",
		--tiles = nodes[k].tiles,
		--special_tiles = nodes[k].special_tiles,

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
		-- the drop part of the node definition needs to be constructed
		-- for each leaf individually
	}


trees_lib.node_def_fruit = {
		--description = "TREENAME Fruit",
		drawtype = "plantlike",
		visual_scale = 1.0,
		--tiles = nodes.fruit.tiles,
		--inventory_image =  nodes.fruit.tiles[1],
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
		sounds = trees_lib.sound_leaves,
		-- store that this fruit has been placed manually
		after_place_node = trees_lib.after_place_fruit,
		-- a fruit that wants to be eatable ought to supply the following line in
		-- its fruit definition:
		--on_use = minetest.item_eat(food_points),
	}

trees_lib.node_def_sapling = {
		--description = "TREENAME sapling",
		drawtype = "plantlike",
		visual_scale = 1.0,
		--tiles = nodes.sapling.tiles,
		--inventory_image = nodes.sapling.tiles[1],
		--wield_image = nodes.sapling.tiles[1],
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
	}

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

-- the function new_tree_type_function will be called once for each tree type;
-- use this for adding the 1 tree -> 4 wood craft receipe
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
-- mix basic node definition (see below), default constructed values (which
-- are derived from modname and treename) as fallback and user (=user of the
-- trees_lib) specified node defintion up into one node definition and
-- register the node (provided it does not exist yet)
-----------------------------------------------------------------------------
trees_lib.register_one_node = function( def_common, def_default, def_user, node_type, sapling_node_name, cid )
	if( not( def_user)) then
		def_user = {};
	end
	-- find out which node we are supposed to register
	local node_name = def_user.node_name;
	if( not( node_name )) then
		node_name = def_default.node_name;
	end
	-- if the node is alrady registered, then abort
	if( minetest.registered_nodes[ node_name ]) then
		-- store the content id of this node for this type
		cid[ node_type ] = minetest.get_content_id( node_name );
		def_user.node_name = node_name;
		return def_user;
	end

	-- create the new node definition
	local node_def = {};
	-- first, add all entries from def_common
	for k,v in pairs( def_common ) do
		node_def[ k ] = v;
	end
	-- then try the default values
	for k,v in pairs( def_default) do
		node_def[ k ] = v;
	end
	-- last, apply all user supplied node definitions and thus overwrite
	-- common and default definitions
	for k,v in pairs( def_user ) do
		node_def[ k ] = v;
	end

	-- set inventory_image and wield_image for plantlike nodes
	if(    node_def.drawtype
	   and node_def.drawtype=="plantlike"
	   and not( node_def.inventory_image )) then
		node_def.inventory_image = node_def.tiles[1];
		node_def.wield_image = node_def.tiles[1];
	end

	-- the node name does not belong into the node definition
	node_def.node_name = nil;

	-- actually register the new node
	minetest.register_node( node_name, node_def );


	-- make sure the node name gets saved
	def_user.node_name = node_name;

	-- can this node (in theory) be overwritten by other trees?
	local allow_overwrite = nil;
	if( node_type=="leaf" or node_type=="fruit" or node_type=="sapling") then
		allow_overwrite = 1;
	end
	-- enter all these node names into a table for fast lookup
	-- (without having to resort to checking the group)
	-- the trees_lib.is_sapling field will later on contain more helpful information;
	-- the sapling needs to be the first node registered for this to work reliably
	trees_lib.build_lookup_table( node_name, "is_"..node_type, sapling_node_name, allow_overwrite );

	-- store the content id of the newly registered node
	cid[ node_type ] = minetest.get_content_id( node_name );
	return def_user;
end



-----------------------------------------------------------------------------
-- nodes for the trees: trunk, planks, leaves, sapling and fruit
-----------------------------------------------------------------------------
-- (internal function)
-- * there can be up to 5 diffrent leaves types
-- * Note: craft receipes for fuel (tree, wood, leaves) do not need to be
--         added because default already contains general craft receipes
--         based on the respective groups.
-- * Note: The craft receipe for 1 tree -> 4 wood can be done via
--         trees_lib.register_on_new_tree_type
trees_lib.register_tree_nodes = function( tree_name, mod_prefix, nodes )

	-- gather all the relevant content ids
	local cid = {};

	local tree_name_upcase = tree_name:gsub("^%l", string.upper);
	local texture_prefix = mod_prefix.."_"..tree_name;

	if( not( nodes )) then
		nodes = {};
	end

	-- the sapling node name will act as a reference in the lookup table later on;
	-- therefore, we need to determine how the node will be called early enough
	local sapling_node_name = mod_prefix..':'..tree_name..'_sapling';
	if( nodes.sapling and nodes.sapling.node_name ) then
		sapling_node_name = nodes.sapling.node_name;
	end

	-- register the sapling
	nodes.sapling = trees_lib.register_one_node( trees_lib.node_def_sapling,
		{
			node_name = sapling_node_name,
			description = tree_name_upcase.." Sapling",
			tiles = { texture_prefix.."_sapling.png",
				},
		}, nodes.sapling, "sapling", sapling_node_name, cid );


	-- register the tree trunk
	nodes.tree = trees_lib.register_one_node( trees_lib.node_def_tree,
		{
			node_name = mod_prefix..':'..tree_name..'_tree',
			description = tree_name_upcase.." Tree",
			tiles = { texture_prefix.."_tree_top.png",
				  texture_prefix.."_tree_top.png",
				  texture_prefix.."_tree.png",
				},
		}, nodes.tree, "tree", sapling_node_name, cid );

	-- register the wood that belongs to the tree
	nodes.wood = trees_lib.register_one_node( trees_lib.node_def_wood,
		{
			node_name = mod_prefix..':'..tree_name..'_wood',
			description = tree_name_upcase.." Planks",
			tiles = { texture_prefix.."_wood.png",
				},
		}, nodes.wood, "wood", sapling_node_name, cid );


	-- default drop rate for the sapling (1/20)
	local sapling_rarity = 20;
	if( nodes.sapling and nodes.sapling.rarity ) then
		sapling_rarity = nodes.sapling.rarity;
	end

	-- register the leaves; some trees may have more than one type of leaves (i.e. moretrees jungletrees)
	local leaves_id = {'leaves','leaves2','leaves3','leaves4','leaves5'};
	for _,k in ipairs( leaves_id ) do
		-- not all leaf types need to exist; we just expect at least one type of leaves to be there
		if( nodes[ k ] or k=='leaves') then
			-- we need to determine the node name now as leaves tend to drop themshelves sometimes
			local leaves_node_name = mod_prefix..':'..tree_name..'_'..k;
			if( nodes[ k ] and nodes[ k ].node_name ) then
				leaves_node_name = nodes[ k ].node_name;
			end
			nodes[ k ] = trees_lib.register_one_node( trees_lib.node_def_leaves,
			{
				node_name = leaves_node_name,
				description = tree_name_upcase.." Leaves",
				tiles = { texture_prefix.."_"..k..".png",
					},
--				special_tiles = { texture_prefix.."_"..k.."_simple.png", },
				drop = {
					max_items = 1,
					items = {
						{
							-- player will get sapling with 1/20 chance
							items = { sapling_node_name},
							rarity = sapling_rarity,
						},
						{
							-- player will get leaves only if he get no saplings,
							-- this is because max_items is 1
							items = { leaves_node_name},
						}
					}
				},
			}, nodes[ k ], "leaf", sapling_node_name, cid);

			-- also store the content ids of all leaf types
			cid[ k ] = cid[ "leaf" ];
		end
	end

	-- register the fruit
	nodes.fruit = trees_lib.register_one_node( trees_lib.node_def_fruit,
		{
			node_name = mod_prefix..':'..tree_name..'_fruit',
			description = tree_name_upcase.." Fruit",
			tiles = { texture_prefix.."_fruit.png",
				},
		}, nodes.fruit, "fruit", sapling_node_name, cid );

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
		local ret = sapling_data.can_grow( pos, node, ground_found );
		if( ret < 1 ) then
			-- trun into dry shrub if growing failed finally (and was not just delayed)
			if( ret==0 ) then
				trees_lib.failed_to_grow( pos, node, ground_found );
			end
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

	-- actually grow the tree in a seperate function
	trees_lib.tree_abm_grow_tree( pos, node, sapling_data, how_to_grow, force_grow );
end


-- actually grow the tree from a sapling
trees_lib.tree_abm_grow_tree = function( pos, node, sapling_data, how_to_grow, force_grow )
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

		how_to_grow.use_function( data, a, pos, sapling_data, how_to_grow.extra_params );

		-- write the data back
		vm:set_data(data)
		vm:write_to_map()
		vm:update_map()


	-- grow the tree using a schematic
	elseif( how_to_grow.use_schematic
	   and (type(how_to_grow.use_schematic)=="string"
	     or type(how_to_grow.use_schematic)=="table")) then
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
trees_lib.register_tree = function( tree_name, nodes, growing_methods, grows_on_node_type_list, can_grow_function, select_how_to_grow_function, interval, chance )
	-- the tree name is the minimum needed in order to register a new tree
	if( not( tree_name )) then
		return;
	end

	-- we may have to register nodes - and those have to be registered under the name of whichever mod called this function and is the "current" mod
	local mod_prefix = minetest.get_current_modname();


	-- register tree trunk, wood, leaves and fruit (provided they are not defined yet)
	local cid_list = trees_lib.register_tree_nodes( tree_name, mod_prefix, nodes );

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
		-- returns a value >0; if 0 is returned, the sapling will fail to grow
		-- and be turned into dry shrub; if a value <0 is returned, nothing will
		-- happen (the sapling can try again later on)
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

	-- set default values for the tree-growing abm if none are set
	if( not( interval)) then
		interval = 10;
	end
	if( not( chance )) then
		chance = 50;
	end
	-- now add the abm that lets the tree grow
	minetest.register_abm({
		nodenames = { nodes.sapling.node_name },
		interval = interval,
		chance = chance,
		action = trees_lib.tree_abm_called,
	});
end
