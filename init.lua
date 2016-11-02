-- Terrain erosion mechanics using moreblocks' slope blocks

if not rawget(_G,"stairsplus") then
	minetest.log("info", "erosion: stairsplus not found")
	return
end
local nntbl,eroding_nodes = {},{--mod defining sloped nodes of this type, materials produced by erosion
	stone = {"moreblocks:","gravel"},
	cobble = {"moreblocks:","gravel"},
	mossycobble = {"moreblocks:","gravel"},
	desert_stone = {"moreblocks:","desert_sand"},
	desert_cobble = {"moreblocks:","desert_sand"},
	sandstone = {"moreblocks:","sand"},
	dirt = {"erosion:","dirt"},
	dirt_with_grass = {"erosion:","dirt"},
	dirt_with_grass_footsteps = {"erosion:","dirt"},
	dirt_with_dry_grass = {"erosion:","dirt"},
	dirt_with_snow = {"erosion:","dirt"},
	sand = {"erosion:","sand"},
	desert_sand = {"erosion:","desert_sand"},
	gravel = {"erosion:","gravel"},
	clay = {"erosion:","clay"},
	snowblock = {"erosion:","snowblock"},
	ice = {"erosion:","snowblock"},
}
for k,v in pairs(eroding_nodes) do nntbl[#nntbl+1] = "default:"..k end
local lntbl,erosion_materials = {},{--erosion products to define
	sand = {
		description = "Sand",
		tiles = {"default_sand.png"},
		groups = {sand = 1},
		sounds = default.node_sound_sand_defaults(),
	},
	desert_sand = {
		description = "Desert Sand",
		tiles = {"default_desert_sand.png"},
		groups = {sand = 1},
		sounds = default.node_sound_sand_defaults(),
	},
	gravel = {
		description= "Gravel",
		groups = {},
		tiles={"default_gravel.png"},
		sounds = default.node_sound_gravel_defaults(),
	},
	dirt = {
		description = "Dirt",
		tiles = {"default_dirt.png"},
		groups = {},
		sounds = default.node_sound_dirt_defaults(),
	},
	dirt_with_grass = {
		description = "Grass Turf",
		tiles = {"default_grass.png", "default_dirt.png",
			{name = "default_dirt.png^default_grass_side.png",
				tileable_vertical = false}},
		groups = {},
		sounds = default.node_sound_dirt_defaults({footstep = {name = "default_grass_footstep", gain = 0.25},}),
	},
	dirt_with_dry_grass = {
		description = "Dry Turf",
		tiles = {"default_dry_grass.png",
			"default_dirt.png",
			{name = "default_dirt.png^default_dry_grass_side.png",
				tileable_vertical = false}},
		groups = {},
		drop = 'default:dirt',
		sounds = default.node_sound_dirt_defaults({footstep = {name = "default_grass_footstep", gain = 0.4},}),
	},
	dirt_with_snow = {
		description = "Snow Turf",
		tiles = {"default_snow.png", "default_dirt.png",
			{name = "default_dirt.png^default_snow_side.png",
				tileable_vertical = false}},
		groups = {},
		drop = 'default:dirt',
		sounds = default.node_sound_dirt_defaults({footstep = {name = "default_snow_footstep", gain = 0.15},}),
	},
	clay = {
		description = "Clay",
		tiles = {"default_clay.png"},
		groups = {},
		drop = 'default:clay_lump 4',
		sounds = default.node_sound_dirt_defaults(),
	},
	snowblock = {
		description = "Drifted Snow",
		tiles = {"default_snow.png"},
		groups = {puts_out_fire = 1},
		sounds = default.node_sound_dirt_defaults({footstep = {
			name = "default_snow_footstep", gain = 0.15},
			dug = {name = "default_snow_footstep", gain = 0.2},
			dig = {name = "default_snow_footstep", gain = 0.2}
		}),
	},
	ice = {
		description = "Ice",
		tiles = {"default_ice.png"},
		is_ground_content = false,
		paramtype = "light",
		groups = {cracky = 3, puts_out_fire = 1},
		sounds = default.node_sound_glass_defaults(),
	}
}
for k,v in pairs(erosion_materials) do lntbl[#lntbl+1] = "default:"..k end
local sntbl,snt1,snt2,slopes = {},{},{},{
	[""] = 2,
	_half = 1,
	_half_raised = 3,
	_inner = 1,
	_inner_half = 1,
	_inner_half_raised = 3,
	_inner_cut = 3,
	_inner_cut_half = 2,
	_inner_cut_half_raised = 3,
	_outer = 1,
	_outer_half = 1,
	_outer_half_raised = 3,
	_outer_cut = 1,
	_outer_cut_half = 1,
	_outer_cut_half_raised = 2,
	_cut = 2,
}
local bstbl = {{"_half","","_half_raised"},{"_outer_cut_half","_cut","_inner_cut_half_raised"}}
for k,v in pairs(eroding_nodes) do if string.find(k,"cobble") then
	for s,d in pairs(slopes) do
		minetest.register_craft({
			output = v[1].."micro_"..k.." "..slopes[s]*2-1,
			recipe = {{v[1].."slope_"..k..s}}
		})
	end
end end
local function slope_type(s)
	local n = string.find(s,"_inner") or string.find(s,"_outer") or string.find(s,"_cut") or string.find(s,"_half")
	return n and string.sub(s,n) or "",n
end
local function get_adjacent_nodes(p,nlst)
	local xsr,nvt = minetest.find_nodes_in_area({x=p.x-1,y=p.y,z=p.z-1},{x=p.x+1,y=p.y,z=p.z+1},nlst),{}
	for i=1,#xsr do
		nvt[xsr[i].x] = nvt[xsr[i].x] or {}
		nvt[xsr[i].x][xsr[i].z] = i
	end
	return xsr,nvt
end
local function orient_pile(p) local _,t0 = get_adjacent_nodes(p,{"air"})
	local _,t1 = get_adjacent_nodes(p,snt1)
	local _,t2 = get_adjacent_nodes(p,snt2)
	local x1,z1,x2,z2 =
	t0[p.x-1] and t0[p.x-1][p.z] and 0 or t1[p.x-1] and t1[p.x-1][p.z] and 1 or t2[p.x-1] and t2[p.x-1][p.z] and 2 or 3,
	t0[p.x] and t0[p.x][p.z-1] and 0 or t1[p.x] and t1[p.x][p.z-1] and 1 or t2[p.x] and t2[p.x][p.z-1] and 2 or 3,
	t0[p.x+1] and t0[p.x+1][p.z] and 0 or t1[p.x+1] and t1[p.x+1][p.z] and 1 or t2[p.x+1] and t2[p.x+1][p.z] and 2 or 3,
	t0[p.x] and t0[p.x][p.z+1] and 0 or t1[p.x] and t1[p.x][p.z+1] and 1 or t2[p.x] and t2[p.x][p.z+1] and 2 or 3
	return z2 > z1 and x1 == x2 and 0
	or x2 > x1 and z1 == z2 and 1
	or z1 > z2 and x1 == x2 and 2
	or x1 > x2 and z1 == z2 and 3
	or z2 > z1 and x1 > x2 and 4
	or x2 > x1 and z2 > z1 and 5
	or z1 > z2 and x2 > x1 and 6
	or x1 > x2 and z1 > z2 and 7 or 4
end
local function pile_up(s,m,p)
	p.y = p.y-1
	local un,p1,n = minetest.get_node(p),"erosion:slope_"
	if erosion_materials[string.sub(un.name,9)] then erosionCL(p,un) un = minetest.get_node(p) end
	if un.name == "air" or un.name == "default:water_source" then
	elseif string.find(un.name,p1) then
		local p2 = slope_type(un.name)
		n = orient_pile(p)
		p1 = slopes[p2] and slopes[p2]+m<4 and p1..s..bstbl[n<4 and 1 or 2][slopes[p2]+m] or "default:"..s
		minetest.swap_node(p,{name=p1,param2=n<4 and n or n-4})
		p.y = p.y+1
		minetest.set_node(p,{name="air"})
	else p.y = p.y+1
		n = orient_pile(p)
		p1 = p1..s..bstbl[n<4 and 1 or 2][m]
		minetest.swap_node(p,{name=p1,param2=n<4 and n or n-4})
	end
end
for k,v in pairs(erosion_materials) do local drt = eroding_nodes[k][2] == "dirt"
	v.groups.crumbly,v.groups.falling_node,v.groups.not_in_creative_inventory = 3,1,1
	if not drt or k == "dirt" then
		minetest.register_node("erosion:fall_"..k, {
			description = "Loose "..v.description,
			tiles = v.tiles,
			groups = v.groups,
			sounds = v.sounds,
			on_construct = function(pos) pile_up(k,1,pos) end,
		})
		minetest.register_craft({
			type="shapeless",
			output = "default:"..k,
			recipe = {"erosion:fall_"..k,"erosion:fall_"..k,"erosion:fall_"..k,"erosion:fall_"..k,},
		})
	end
	stairsplus:register_slope("erosion",k,"erosion:"..k,v)
	if drt then minetest.override_item("default:"..k,{groups = {crumbly=3,falling_node=1,soil=1}}) end
	for s,d in pairs(slopes) do sntbl[#sntbl+1] = "erosion:slope_"..k..s
		if d<3 then snt1[#snt1+1] = "erosion:slope_"..k..s
		else snt2[#snt2+1] = "erosion:slope_"..k..s end
		minetest.override_item("erosion:slope_"..k..s,
			{drop = "erosion:fall_"..(not drt and k or "dirt").." "..d,
			on_construct = function(pos) pile_up(k,d,pos) end
		})
	end
end

function erosionCL(p,node) local ntyp = string.sub(node.name,9)
	if not eroding_nodes[ntyp] then return end
	local rmnn,flmt = eroding_nodes[ntyp][1].."slope_"..ntyp,"erosion:fall_"..eroding_nodes[ntyp][2]
	local xpsr,nvtbl = get_adjacent_nodes(p,{"air"})
	if xpsr[1] then
		local xr,zr = 0,0
		if nvtbl[p.x] and nvtbl[p.x][p.z-1] then xr = 5
			minetest.place_node({x=p.x,y=p.y,z=p.z-1},{name=flmt})
		elseif nvtbl[p.x] and nvtbl[p.x][p.z+1] then xr = 3
			minetest.place_node({x=p.x,y=p.y,z=p.z+1},{name=flmt})
		end
		if nvtbl[p.x-1] and nvtbl[p.x-1][p.z] then zr = 6
			minetest.place_node({x=p.x-1,y=p.y,z=p.z},{name=flmt})
		elseif nvtbl[p.x+1] and nvtbl[p.x+1][p.z] then zr = 4
			minetest.place_node({x=p.x+1,y=p.y,z=p.z},{name=flmt})
		end
		if xr+zr < 1 then xr,zr = p.x-xpsr[1].x,p.z-xpsr[1].z+15
			minetest.place_node(xpsr[1],{name=flmt})
		end
		if xr+zr < 7 then minetest.swap_node(p,{name=rmnn.."_half_raised",param2=math.mod(xr+zr-1,4)})
		elseif xr+zr < 13 then minetest.swap_node(p,{name=rmnn.."_cut",param2=math.mod(xr>4 and zr/2-2 or 5-zr/2,4)})
		else minetest.swap_node(p,{name=rmnn.."_inner_cut_half_raised",param2=math.mod(xr>0 and 9-zr/2 or zr/2,4)}) end
	end
end

minetest.register_on_generated(function(minp, maxp)--function that affects generated mapblockchunks
	if minp.y > 256 then return end
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data,prm2 = vm:get_data(),vm:get_param2_data()
	local vxa = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local dpstn,cube3,box,vpos = {},{},{}
	for x=-1,1 do cube3[x]={} for y=-1,1 do cube3[x][y]={}
		for z=-1,1 do cube3[x][y][z]=x+y*vxa.ystride+z*vxa.zstride end
	end end
	for k,v in pairs(erosion_materials) do dpstn[k] = minetest.get_content_id("default:"..k)
		for s,_ in pairs(slopes) do dpstn["slp_"..k..s] = minetest.get_content_id("erosion:slope_"..k..s) end
	end
	for s,_ in pairs(slopes) do dpstn["slp_stone"..s] = minetest.get_content_id("moreblocks:slope_stone"..s) end
	dpstn.stone,dpstn.air = minetest.get_content_id("default:stone"),minetest.get_content_id("air")
	local function place_slope(vpos,m) if data[vpos] == dpstn.air then
		box.w = data[vpos+cube3[-1][0][0]] == dpstn[m]
		box.e = data[vpos+cube3[1][0][0]] == dpstn[m]
		box.d = data[vpos+cube3[0][-1][0]] == dpstn[m]
		box.u = data[vpos+cube3[0][1][0]] == dpstn[m]
		box.s = data[vpos+cube3[0][0][-1]] == dpstn[m]
		box.n = data[vpos+cube3[0][0][1]] == dpstn[m]
		if box.w or	box.e or box.d or box.u or box.s or box.n then
			box.t = (box.w and 1 or 0)+(box.e and 1 or 0)+(box.d and 1 or 0)+(box.u and 1 or 0)+(box.s and 1 or 0)+(box.n and 1 or 0)
			if box.t == 2 then
				box.f = box.d and box.n and 0
				or box.d and box.e and 1
				or box.d and box.s and 2
				or box.d and box.w and 3
				or box.u and box.n and 20
				or box.u and box.w and 21
				or box.u and box.s and 22
				or box.u and box.e and 23
				or box.w and box.s and 7
				or box.e and box.n and 9
				or box.w and box.n and 12
				or box.e and box.s and 18
				if box.f then data[vpos],prm2[vpos] = dpstn["slp_"..m],box.f end
			elseif box.t == 3 then
				box.f = box.d and box.n and box.w and 0
				or box.d and box.e and box.n and 1
				or box.d and box.s and box.e and 2
				or box.d and box.w and box.s and 3
				or box.u and box.n and box.e and 20
				or box.u and box.w and box.n and 21
				or box.u and box.s and box.w and 22
				or box.u and box.e and box.s and 23
				if box.f then data[vpos],prm2[vpos] = dpstn["slp_"..m.."_inner_cut"],box.f
					if box.u and data[vpos+cube3[0][-1][0]] == dpstn.air then
						data[vpos+cube3[0][-1][0]],prm2[vpos+cube3[0][-1][0]] = dpstn["slp_"..m.."_outer_cut"],box.f
					end
				end
			end
		end
	end end
	for vpos=vxa:index(minp.x,minp.y,minp.z),vxa:index(maxp.x,maxp.y,maxp.z) do place_slope(vpos,"stone") end
	if maxp.y > 1 then
		local heightmap,hndx = minetest.get_mapgen_object("heightmap"),1
		for z=minp.z,maxp.z do for x=minp.x,maxp.x do
			vpos = vxa:index(x,heightmap[hndx]+1,z)
			for k,_ in pairs(erosion_materials) do place_slope(vpos,k) end
			hndx = hndx+1
		end end
	end
	vm:set_data(data)--set altered data to the vm
	vm:set_param2_data(prm2)--set altered param2 data
	vm:calc_lighting()--recalculate lighting
	vm:write_to_map(data) --save altered data in vm
end)

local function wwthrngCL(p,n) p.y = p.y+1
	local k = minetest.get_node(p).name
	if k == "air" then
		p.y = p.y-1
		erosionCL(p,n)
	end
end

minetest.register_abm({
	nodenames = nntbl,
	neighbors = {"air"},
	interval = 9,
	chance = 37,
	action = wwthrngCL,
})

minetest.register_abm({
	nodenames = lntbl,
	neighbors = {"air"},
	interval = 7,
	chance = 13,
	action = wwthrngCL,
})

minetest.register_on_punchnode(wwthrngCL)
