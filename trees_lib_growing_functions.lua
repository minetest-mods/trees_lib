


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

trees_lib.generate_fruit_tree = function(data, a, pos, sapling_data, extra_params )

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


-- a very small tree
trees_lib.generate_unhappy_tree = function(data, a, pos, sapling_data, extra_params )

	local tree_cid   = sapling_data.cid.tree;
	local leaves_cid = sapling_data.cid.leaves;

	local x, y, z = pos.x, pos.y, pos.z
	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")

	-- Trunk
	data[a:index(x, y, z)] = tree_cid;
	local found = data[a:index(x, y+1, z )];
	if( found==c_air or found==c_ignore ) then
		data[a:index(x, y+1, z)] = tree_cid;
	end
	for xv=-1,1 do
		for zv=-1,1 do
			if( math.random(1,2)==1 ) then
				local found = data[a:index(x+xv, y+1, z+zv )]
				if( found==c_air or found==c_ignore ) then
					data[a:index(x+xv, y+1, z+zv )] = leaves_cid;
				end
			end
		end
	end
end

