
-- Note: this file is currently unused
-- It defines the trees from minetest_game/mods/default/ in the way the
-- default mod would be able to register them.

--- the standard tree; sometimes it turns out to be an apple tree
trees_lib.register_tree( "tree", "default",
	{  tree = {
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
		how_to_grow  = {{ use_function = trees_lib.generate_fruit_tree,
				 xoff = 2, zoff = 2, yoff = 0, height = 6,
			       }},
	}, fruit = {
		node_name    = "default:apple",
		description  = "Apple",
		tiles        = {"default_apple.png"},
		food_points  = 2,
	}});

--- jungletree
trees_lib.register_tree( "jungletree", "default",
	{  tree = {
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
		how_to_grow  = {{ use_function = trees_lib.generate_fruit_tree,
				 xoff = 2, zoff = 2, yoff = 0, height = 6,
			       }},
	}});


--- pine
trees_lib.register_tree( "pine", "default",
	{  tree = {
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
		how_to_grow  = {{ use_function = trees_lib.generate_fruit_tree,
				 xoff = 2, zoff = 2, yoff = 0, height = 6,
			       }},
	}});

--- acacia
trees_lib.register_tree( "acacia", "default",
	{  tree = {
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
		how_to_grow  = {{ use_function = trees_lib.generate_fruit_tree,
				 xoff = 2, zoff = 2, yoff = 0, height = 6,
			       }},
	}} );
