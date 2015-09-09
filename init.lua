
trees_lib = {}

-- those are helpful for fast lookup (either by name or content id) 
trees_lib.is_tree = {}
trees_lib.is_wood = {}
trees_lib.is_leaf = {}
trees_lib.is_sapling = {}
trees_lib.is_fruit   = {}
trees_lib.ignore     = {};

-- trees are allowed to replace these nodes when growing
-- (in addition to leaves, saplings and fruits from other trees)
trees_lib.ignore_list = {"air","ignore","default:water_source","default:water_flowing","default:snow","default:ice"}

trees_lib.build_lookup_table = function( node_name, node_type, value, allow_removal_by_other_saplings )
	if(   not( node_name )
	   or node_name == ""
	   or not( minetest.registered_nodes[ node_name ])
	   or not( trees_lib[ node_type ])) then
		return;
	end
	local id = minetest.get_content_id( node_name );
	trees_lib[ node_type ][ id        ] = value; 
	trees_lib[ node_type ][ node_name ] = value; 
	-- if this is set, then other saplings can overwrite these nodes during their growth
	-- (i.e. replacing leaves with tree trunks)
	if( allow_removal_by_other_saplings ) then
		trees_lib.ignore[ id        ] = value;
		trees_lib.ignore[ node_name ] = value;
	end
end


-- actually store the information from the ignore list
for _,v in ipairs( trees_lib.ignore_list ) do
	trees_lib.build_lookup_table( v,"ignore", v, 1 );
end


---
--- nodes for the trees: trunk, planks, leaves, sapling and fruit
---
trees_lib.register_tree_nodes_and_crafts = function( nodes )

	-- register the tree trunk
	if( nodes and nodes.tree and nodes.tree.node_name and not( minetest.registered_nodes[ nodes.tree.node_name ])) then
		minetest.register_node( nodes.tree.node_name, {
			description = nodes.tree.description,
			tiles = nodes.tree.tiles,
			paramtype2 = "facedir",
			is_ground_content = false,
			-- moretrees uses snappy=1 here as well
			groups = {tree = 1, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
			sounds = default.node_sound_wood_defaults(),
			on_place = minetest.rotate_node
		})

		-- we need to add the craft receipe for tree -> planks
		if( nodes.wood and nodes.wood.node_name ) then
			minetest.register_craft({
					-- the amount of wood given might be a global config variable
					output = nodes.wood.node_name..' 4',
					recipe = {
						{ nodes.tree.node_name },
					}
				});
		end
	end

	-- register the wooden planks
	if( nodes and nodes.wood and nodes.wood.node_name and not( minetest.registered_nodes[ nodes.wood.node_name ])) then
		minetest.register_node( nodes.wood.node_name, {
			description = nodes.wood.description,
			tiles = nodes.wood.tiles,
			is_ground_content = false,
			-- moretrees uses snappy=1 here
			groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 3, wood = 1},
			sounds = default.node_sound_wood_defaults(),
		})

		-- we need to add the craft receipe for planks -> sticks
		-- (but since there is a default craft receipe for group:wood, that ought to be cover it)
--		if( nodes.wood and nodes.wood.node_name ) then
--		end
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
				sounds = default.node_sound_leaves_defaults(),
				after_place_node = default.after_place_leaves,
	
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
			sounds = default.node_sound_leaves_defaults(),
		})
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
			sounds = default.node_sound_leaves_defaults(),
		
			after_place_node = function(pos, placer, itemstack)
				if placer:is_player() then
					minetest.set_node(pos, {name =  nodes.fruit.node_name, param2 = 1})
				end
			end,
		})
	end

	-- enter all these node names into a table for fast lookup
	-- (without having to resort to checking the group)
	trees_lib.build_lookup_table( nodes.tree.node_name,       "is_tree",    nodes.sapling.node_name, nil );
	trees_lib.build_lookup_table( nodes.wood.node_name,       "is_wood",    nodes.sapling.node_name, nil );
	-- the trees_lib.is_sapling field will later on contain more helpful information
	trees_lib.build_lookup_table( nodes.sapling.node_name,    "is_sapling", {sapling=nodes.sapling.node_name}, 1 );
	trees_lib.build_lookup_table( nodes.fruit.node_name,      "is_fruit",   nodes.sapling.node_name, 1 );
	for _,k in ipairs( leaves_id ) do 
		trees_lib.build_lookup_table( nodes[k].node_name, "is_leaf",    nodes.sapling.node_name, 1 );
	end
end


-- TODO: offer some sample can_grow_function 

---
--- called by the abm running on the saplings
---
trees_lib.tree_abm_called = function( pos, node )
	-- if we don't have further information about that sapling, then abort
	if(   not( node )
	   or not( node.name ) 
	   or not( trees_lib.is_sapling[ node.name ])) then
		-- TODO: turn sapling into dry shrub?
		return;
	end

	-- get information about what we're supposed to do with that sapling
	local data = trees_lib.is_sapling[ nodes.sapling.node_name ];

	-- the tree may come with a function that checks if it can grow there
	if( data.can_grow_function
	   and type( data.can_grow_function)=="function" ) then
		local res = data.can_grow_function( pos, node );
		if( res==false ) then
			-- TODO: turn sapling into dry shrub?
			return;
		end
	end

	-- we also offer a quick check for the ground
end


tree data:
	growth_function = {
		can_grow_function = function( pos, node )
			end,
		grows_on = {"list_of_nodetypes"},

---
--- register a new tree
---
trees_lib.register_tree = function( nodes )
	-- register tree trunk, wood, leaves and fruit (provided they are not defined yet)
	trees_lib.register_tree_nodes_and_crafts( nodes );

	-- a sapling will be needed for growing the tree
	if(   not( nodes.sapling )
	   or not( nodes.sapling.node_name )) then
		return;
	end

	trees_lib.is_sapling[ nodes.sapling.node_name ] = { "TODO" }; -- TODO

	-- now add the abm that lets the tree grow
	-- TODO
end


--- the standard tree; sometimes it turns out to be an apple tree
trees_lib.register_tree( {
	tree = {
		node_name    = "default:tree",
		description  = "Tree",
		tiles        = {"default_tree_top.png", "default_tree_top.png", "default_tree.png"},
	}, wood = {
		node_name    = "default:wood",
		description  = "Wooden Planks",
		tiles        = {"default_wood.png"},
	}, leaves = {
		node_name    = "default:leaves",
		description  = "Leaves",
		tiles        = {"default_leaves.png"},
		special_tiles= {"default_leaves_simple.png"},
	}, sapling = {
		node_name    = "default:sapling",
		description  = "Sapling",
		tiles        = {"default_sapling.png"},
		rarity       = 20,
	}, fruit = {
		node_name    = "default:apple",
		description  = "Apple",
		tiles        = {"default_apple.png"},
		food_points  = 2,
	}});

--- jungletree
trees_lib.register_tree( {
	tree = {
		node_name    = "default:jungletree",
		description  = "Jungle Tree",
		tiles        = {"default_jungletree_top.png", "default_jungletree_top.png", "default_jungletree.png"},
	}, wood = {
		node_name    = "default:junglewood",
		description  = "Junglewood Planks",
		tiles        = {"default_junglewood.png"},
	}, leaves = {
		node_name    = "default:jungleleaves",
		description  = "Jungle Leaves",
		tiles        = {"default_jungleleaves.png"},
		special_tiles= {"default_jungleleaves_simple.png"},
	}, sapling = {
		node_name    = "default:junglesapling",
		description  = "Jungle Sapling",
		tiles        = {"default_junglesapling.png"},
		rarity       = 20,
	}});


--- pine
trees_lib.register_tree( {
	tree = {
		node_name    = "default:pine_tree",
		description  = "Pine Tree",
		tiles        = {"default_pine_tree_top.png", "default_pine_tree_top.png", "default_pine_tree.png"},
	}, wood = {
		node_name    = "default:pine_wood",
		description  = "Pine Wood Planks",
		tiles        = {"default_pine_wood.png"},
	}, leaves = {
		node_name    = "default:pine_needles",
		description  = "Pine Needles",
		tiles        = {"default_pine_needles.png"},
		special_tiles= nil,
	}, sapling = {
		node_name    = "default:pine_sapling",
		description  = "Pine Sapling",
		tiles        = {"default_pine_sapling.png"},
		rarity       = 20,
	}});

--- acacia
trees_lib.register_tree( {
	tree = {
		node_name    = "default:acacia_tree",
		description  = "Acacia Tree",
		tiles        = {"default_acacia_tree_top.png", "default_acacia_tree_top.png", "default_acacia_tree.png"},
	}, wood = {
		node_name    = "default:acacia_wood",
		description  = "Acacia Wood Planks",
		tiles        = {"default_acacia_wood.png"},
	}, leaves = {
		node_name    = "default:acacia_leaves",
		description  = "Acacia Leaves",
		tiles        = {"default_acacia_leaves.png"},
		special_tiles= nil,
	}, sapling = {
		node_name    = "default:acacia_sapling",
		description  = "Acacia Tree Sapling",
		tiles        = {"default_acacia_sapling.png"},
		rarity       = 20,
	}} );

