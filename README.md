Trees are common. Yet they are all registered manually so far. And plugging
in to their growing mechanism with mods is difficult.

List of files:
init.lua                          Loads all the needed other files (including examples)
trees_lib.lua                     The actual trees_lib.
trees_lib_growing_functions.lua   Some tree growing functions as examples.
example_tree.lua                  A complex example for one tree.
trees.lua                         Replacement for default/trees.lua

Not covered in trees_lib:
* fuel receipes for the tree nodes
* crafting of tree into wood
* leafdecay

If you want to test trees_lib with the default mod, do the following:

1. (optional) remove/comment out all receipes for tree trunk -> 4 wood in default/crafting.lua
2. (optional) remove/comment out all tree, wood, leaves and fruit nodes in default/nodes.lua
3. (optional) rename the file default/trees.lua
4. copy trees_lib/trees.lua to default/trees.lua

If you want to add a new tree using trees_lib, do the following:

1. Create a mod (MODNAME)
2. Find a name for your tree (TREENAME)
3. Create the following textures for your new tree:
     MODNAME/textures/MODNAME_TREENAME_tree_top.png
     MODNAME/textures/MODNAME_TREENAME_tree.png
     MODNAME/textures/MODNAME_TREENAME_wood.png
     MODNAME/textures/MODNAME_TREENAME_sapling.png
     MODNAME/textures/MODNAME_TREENAME_leaves.png
     MODNAME/textures/MODNAME_TREENAME_fruit.png
4. Make your mod depend on trees_lib by adding a line trees_lib to
     MODNAME/depends.txt
5. Actually register the tree somewhere in your mod:
     trees_lib.register_tree( TREENAME )
   All other parameters to trees_lib.register_tree are optional.


Important functions:

register_tree

trees_lib.register_tree(tree_name, nodes, growing_methods, grows_on_node_type_list, can_grow_function, select_how_to_grow_function, interval, chance )
   * tree_name needs to be unique withhin each mod, but not necessarily
     withhin the entire game. This parameter is required.
   * nodes may contain further information about the nodes the tree is composed
     of (tree, wood, leaves, leaves2, leaves3, leaves4, leaves5, sapling, fruit).
     Specify everything you want to override here (i.e. diffrent node name,
     textures, drawtype, ...). Specify node_name = "air" (see trees.lua) if you
     don't want a particular node (mostly used for trees that have no fruit)
   * growing_methods is a list of how the sapling can be grown into a full tree.
     Each entry needs one of the following entries:
         use_function = function_to_grow_the_sapling
     or
         use_schematic = path_to_the_schematic_file
     or
         use_schematic = table_containing_the_schematic
     or
         use_lsystem = table_containing_lsystem_growth_data
     In addition, the following values are usually needed:
         xoff = x_offset, zoff = z_offset, yoff = y_offset (how deep burried),
         height = height (total height of the tree)
     These values describe which area the Voxelmanip needs to load or how
     far away from the sapling's position the schematic ought to be placed.
   * grows_on_node_type_list is a list of nodenames (or groups in the form
     of i.e "group:stone") on which the sapling will grow.
   * can_grow_function will be called when the abm for a sapling fires:
         if can_grow( pos, node, ground_found ) returns
             1, the tree will grow
             0, the tree will try again next time (i.e. too dark)
             -1, the tree really doesn't like this place and fails to grow,
                 usually turning into dry shrub
   * select_how_to_grow_function can modify the way a tree will grow:
         select_how_to_grow( pos, node, growing.how_to_grow, ground_found )
     It can either return a number (thus choosing one of the growing methods
     from the growing_methods parameter), or its own new growing method.
   * interval
     The interval parameter for the abm for the growing of the sapling.
     Default value is 10.
   * chance
     The chance parameter for the abm for the growing of the sapling.
     Default value is 50.


trees_lib.register_on_new_tree_type( new_tree_type_function )
   The function new_tree_type_function will be called once for each registered
   tree with the following parameters:
      new_tree_type_function( tree_name, mod_prefix, nodes )
   This is useful for i.e. adding craft receipes and further nodes. See
   trees.lua for an example.
   If trees have allready been registered when the new function is registered,
   it will be called for each known tree once, and of course for all
   subsequently registered trees.


trees_lib.failed_to_grow( pos, node )
   This function is called when a tree failed to grow (i.e. because it does not
   like the ground it is placed on). The default action is to turn the sapling
   into dry shrub.

trees_lib.a_tree_has_grown( pos, node, how_to_grow )
   Called whenever a tree has successfully grown. Useful i.e. for logging (see
   trees.lua)

trees_lib.tree_abm_grow_tree( pos, node, sapling_data, how_to_grow, force_grow )
   The actual function that lets the tree grow.


