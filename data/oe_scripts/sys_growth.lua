local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table

local node_child_iter = mods.multiverse.node_child_iter
local node_get_bool_default = mods.multiverse.node_get_bool_default
local node_get_number_default = mods.multiverse.node_get_number_default

local get_room_at_location = mods.oe.get_room_at_location
local xor = mods.oe.xor
local isPointInEllipse = mods.oe.isPointInEllipse
local worldToPlayerLocation = mods.oe.worldToPlayerLocation
local worldToEnemyLocation = mods.oe.worldToEnemyLocation
local get_distance = mods.oe.get_distance
local offset_point_in_direction = mods.oe.offset_point_in_direction
local get_point_local_offset = mods.oe.get_point_local_offset
local get_random_point_in_radius = mods.oe.get_random_point_in_radius
local normalise_angle = mods.oe.normalise_angle
local angle_diff = mods.oe.angle_diff
local get_angle_between_points = mods.oe.get_angle_between_points
local find_closest_slot = mods.oe.find_closest_slot

local systemName = "oe_growth"
mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(systemName)] = mods.multiverse.register_system_icon(systemName)

local energy_base = 200
local energy_scaler = 100
local decay_mult = 0.1
local decay_bud_mult = 0.025
local update_rate = 0.05
local save_rate = 1

local fire_death_mult = 0.25
local fire_start_mult = 1

local fire_damage_rate = 50
local fire_room_damage_rate = 10

local level_string = Hyperspace.Text:GetText("oe_lua_sys_growth_level")
local function get_level_description_system(systemId, level, tooltip)
	if systemId == Hyperspace.ShipSystem.NameToSystemId(systemName) then
		return string.format(level_string, (energy_base + energy_scaler * (level - 1))/100)
	end
end
script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_system)


local function is_system(systemBox)
	local systemNameTemp = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemNameTemp and systemBox.bPlayerUI
end
local function is_system_enemy(systemBox)
	local systemNameTemp = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemNameTemp and not systemBox.bPlayerUI
end

local function system_ready(shipSystem)
	return ((not shipSystem:GetLocked()) or shipSystem.iLockCount == -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end


local table_growth = {[0] = {}, [1] = {} }
local table_map = {[0] = nil, [1] = nil}
mods.oe.table_bud = {[0] = {}, [1] = {}}
local table_bud = mods.oe.table_bud

local function new_bud(i, j)
	return {i = i, j = j}
end

local growth_variable = "save_oe_growth%d_room%d_i%d_j%d"
local bud_variable_i = "save_oe_bud%d_room%d_i"
local bud_variable_j = "save_oe_bud%d_room%d_j"

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipManager)
	table_growth[shipManager.iShipId] = {}
	table_bud[shipManager.iShipId] = {}
	table_map[shipManager.iShipId] = nil
end)

local function save_system(shipManager, system)
	for room in vter(shipManager.ship.vRoomList) do
		Hyperspace.playerVariables[string.format(bud_variable_i, shipManager.iShipId, room.iRoomId)] = (table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].i) or -1
		Hyperspace.playerVariables[string.format(bud_variable_j, shipManager.iShipId, room.iRoomId)] = (table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].j) or -1
		local room_map = table_map[shipManager.iShipId][room.iRoomId]
		local w = room_map.w
		local h = room_map.h
		for i = 0, w - 1 do
			for j = 0, h - 1 do
				Hyperspace.playerVariables[string.format(growth_variable, shipManager.iShipId, room.iRoomId, i, j)] = table_growth[shipManager.iShipId][room.iRoomId][i][j].val
			end
		end
	end
end

local function load_system(shipManager, system)
	for room in vter(shipManager.ship.vRoomList) do
		local bud_i = Hyperspace.playerVariables[string.format(bud_variable_i, shipManager.iShipId, room.iRoomId)]
		local bud_j = Hyperspace.playerVariables[string.format(bud_variable_j, shipManager.iShipId, room.iRoomId)]
		if bud_i >= 0 and bud_j >= 0 then
			table_bud[shipManager.iShipId][room.iRoomId] = new_bud(bud_i, bud_j)
		end
		local room_map = table_map[shipManager.iShipId][room.iRoomId]
		local w = room_map.w
		local h = room_map.h
		for i = 0, w - 1 do
			for j = 0, h - 1 do
				table_growth[shipManager.iShipId][room.iRoomId][i][j].val = Hyperspace.playerVariables[string.format(growth_variable, shipManager.iShipId, room.iRoomId, i, j)]
			end
		end
	end
end

local loadSystems = {[0] = false, [1] = false}
script.on_init(function(newgame)
	if not newgame then
		loadSystems[0] = true
		loadSystems[1] = true
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if loadSystems[1] then
		loadSystems[1] = false
	end
end)

local update_timer = {[0] = 0, [1] = 0}
local save_timer = {[0] = 0, [1] = 0.5}

local function construct_room_connection_map(shipManager)
	for room in vter(shipManager.ship.vRoomList) do
		local w = math.floor(room.rect.w/35)
		local h = math.floor(room.rect.h/35)
		local size = w*h
		table_map[shipManager.iShipId][room.iRoomId] = {x = room.rect.x, y = room.rect.y, w = w, h = h, size = size, slots = {}}
		for i = 0, w - 1 do
			table_map[shipManager.iShipId][room.iRoomId].slots[i] = {}
			for j = 0, h - 1 do
				local adjacent = {}
				if i - 1 >= 0 then table.insert(adjacent, {room = room.iRoomId, i = i - 1, j = j}) end
				if i + 1 < w then table.insert(adjacent, {room = room.iRoomId, i = i + 1, j = j}) end
				if j - 1 >= 0 then table.insert(adjacent, {room = room.iRoomId, i = i, j = j - 1}) end
				if j + 1 < h then table.insert(adjacent, {room = room.iRoomId, i = i, j = j + 1}) end
				local x = room.rect.x + i * 35
				local y = room.rect.y + j * 35
				table_map[shipManager.iShipId][room.iRoomId].slots[i][j] = adjacent
			end
		end
	end
	for door in vter(shipManager.ship.vDoorList) do
		local room_1 = door.iRoom1
		local room_1_i = nil
		local room_1_j = nil
		local room_2 = door.iRoom2
		local room_2_i = nil
		local room_2_j = nil
		if room_1 ~= -1 and room_2 ~= -1 then
			for room in vter(shipManager.ship.vRoomList) do
				local room_map = table_map[shipManager.iShipId][room.iRoomId]
				local w = room_map.w
				local h = room_map.h
				if room.iRoomId == room_1 or room.iRoomId == room_2 then
					if door.bVertical then
						local x = door.x
						local y = door.y - 17
						local i = nil
						if x == room.rect.x then
							i = 0
						elseif x == room.rect.x + room.rect.w then
							i = w - 1
						end
						if i and y >= room.rect.y and y < room.rect.y + room.rect.h then
							local j = (y - room.rect.y) / 35
							if room.iRoomId == room_1 then
								room_1_i = i
								room_1_j = j
							else
								room_2_i = i
								room_2_j = j
							end 
						end
					else
						local x = door.x - 17
						local y = door.y 
						local j = nil
						if y == room.rect.y then
							j = 0
						elseif y == room.rect.y + room.rect.h then
							j = h - 1
						end
						if j and x >= room.rect.x and x < room.rect.x + room.rect.w then
							local i = (x - room.rect.x) / 35
							if room.iRoomId == room_1 then
								room_1_i = i
								room_1_j = j
							else
								room_2_i = i
								room_2_j = j
							end 
						end
					end
				end
				if room_1_i and room_1_j and room_2_i and room_2_j then
					table.insert(table_map[shipManager.iShipId][room_1].slots[room_1_i][room_1_j], {room = room_2, i = room_2_i, j = room_2_j})
					table.insert(table_map[shipManager.iShipId][room_2].slots[room_2_i][room_2_j], {room = room_1, i = room_1_i, j = room_1_j})
					break
				end
			end
		end
		
	end
end

local function generate_slot_anim(shipManager, room, i, j)
	local s = "oe_growth_tile_%d"
	local post_fix = "_udlr"
	local room_map = table_map[shipManager.iShipId][room.iRoomId]
	local slot_map = room_map.slots[i][j]
	for _, adjacent in ipairs(slot_map) do
		--print(string.format("check_adjacent:%d i:%d j:%d", adjacent.room, adjacent.i, adjacent.j))
		if adjacent.room == room.iRoomId then
			if adjacent.i == i + 1 then 
				post_fix = string.gsub(post_fix, "r", "")
			elseif adjacent.i == i - 1 then 
				post_fix = string.gsub(post_fix, "l", "")
			elseif adjacent.j == j + 1 then 
				post_fix = string.gsub(post_fix, "d", "")
			elseif adjacent.j == j - 1 then 
				post_fix = string.gsub(post_fix, "u", "")
			end
		end
	end
	--print(string.format("ship:%d room:%d i:%d j:%d s:%s", shipManager.iShipId, room.iRoomId, i, j, post_fix))
	local image_table = {}
	for n = 1, 5 do
		local anim = Hyperspace.Animations:GetAnimation(string.format(s, n)..post_fix)
		anim.position.x = room.rect.x + i * 35
		anim.position.y = room.rect.y + j * 35
		image_table[n] = anim
	end
	return image_table
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if not table_map[shipManager.iShipId] then
		table_map[shipManager.iShipId] = {}
		construct_room_connection_map(shipManager)
		for room in vter(shipManager.ship.vRoomList) do
			table_bud[shipManager.iShipId][room.iRoomId] = false
			table_growth[shipManager.iShipId][room.iRoomId] = {}
			local room_map = table_map[shipManager.iShipId][room.iRoomId]
			local w = room_map.w
			local h = room_map.h
			for i = 0, w - 1 do
				table_growth[shipManager.iShipId][room.iRoomId][i] = {}
				for j = 0, h - 1 do
					local anim = generate_slot_anim(shipManager, room, i, j)
					--print(string.format("setup:%d, %d, %d, %d", shipManager.iShipId, room.iRoomId, i, j))
					table_growth[shipManager.iShipId][room.iRoomId][i][j] = {val = 0, image = anim}
				end
			end
		end
	end

	if loadSystems[shipManager.iShipId] and Hyperspace.playerVariables.oe_test_variable > 0 then
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
			load_system(shipManager, shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)))
		end
		loadSystems[shipManager.iShipId] = false
	end

	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
		local system_room_id = system.roomId
		local power = system:GetEffectivePower()

		update_timer[shipManager.iShipId] = update_timer[shipManager.iShipId] + time_increment(true)
		if update_timer[shipManager.iShipId] > update_rate then
			
			local map = table_map[shipManager.iShipId]
			local visited = {}
			if power > 0 then
				local current_front = {}
				local energy = (energy_base + energy_scaler * (power - 1)) * update_timer[shipManager.iShipId]

				local system_room_map = map[system_room_id]
				for i = 0, system_room_map.w - 1 do
					for j = 0, system_room_map.h - 1 do
						table.insert(current_front, {room = system_room_id, i = i, j = j})
						visited[system_room_id] = visited[system_room_id] or {}
						visited[system_room_id][i] = visited[system_room_id][i] or {}
						visited[system_room_id][i][j] = true
					end
				end

				while #current_front > 0 do
					local energy_per_cell = energy / #current_front
					local next_front = {}
					local energy_spent = 0
					for _, cell in ipairs(current_front) do
						local current_energy = table_growth[shipManager.iShipId][cell.room][cell.i][cell.j].val
						local energy_needed = 100 - current_energy
						local energy_add = math.min(energy_per_cell, energy_needed)

						local fire = shipManager:GetFireAtPoint(map[cell.room].x + cell.i * 35, map[cell.room].y + cell.j * 35)
						if not fire.bWasOnFire then
							table_growth[shipManager.iShipId][cell.room][cell.i][cell.j].val = current_energy + energy_add
							energy_spent = energy_spent + energy_add
						end

						if table_growth[shipManager.iShipId][cell.room][cell.i][cell.j].val > 0 then
							local slot_map = map[cell.room].slots[cell.i][cell.j]
							for _, adjacent in ipairs(slot_map) do
								if not visited[adjacent.room] or not visited[adjacent.room][adjacent.i] or not visited[adjacent.room][adjacent.i][adjacent.j] then
									table.insert(next_front, {room = adjacent.room, i = adjacent.i, j = adjacent.j})
									visited[adjacent.room] = visited[adjacent.room] or {}
									visited[adjacent.room][adjacent.i] = visited[adjacent.room][adjacent.i] or {}
									visited[adjacent.room][adjacent.i][adjacent.j] = true
								end
							end
						end
					end
					energy = energy - energy_spent
					current_front = next_front
				end
			end
				
			for room in vter(shipManager.ship.vRoomList) do
				local room_map = map[room.iRoomId]
				local w = room_map.w
				local h = room_map.h
				for i = 0, w - 1 do
					for j = 0, h - 1 do
						local slot_map = room_map.slots[i][j]
						local connected = visited[room.iRoomId] and visited[room.iRoomId][i] and visited[room.iRoomId][i][j]
						local current_energy = table_growth[shipManager.iShipId][room.iRoomId][i][j].val
						local decay = 0
						if current_energy > 0 then
							if not (table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].i and table_bud[shipManager.iShipId][room.iRoomId].j) then
								if current_energy > 50 then
									table_bud[shipManager.iShipId][room.iRoomId] = new_bud(i, j)
								end
							elseif table_bud[shipManager.iShipId][room.iRoomId].i == i and table_bud[shipManager.iShipId][room.iRoomId].j == j then
								if not connected then
									decay = decay + decay_bud_mult * energy_base
									shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, 3 * update_timer[shipManager.iShipId])
								elseif current_energy > 50 then
									shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, 3 * update_timer[shipManager.iShipId])
								else
									table_bud[shipManager.iShipId][room.iRoomId] = false
								end
							end

							if not connected then
								local empty_adjacent = 0
								for _, adjacent in ipairs(slot_map) do
									if table_growth[shipManager.iShipId][adjacent.room][adjacent.i][adjacent.j].val <= 0 then
										empty_adjacent = empty_adjacent + 1
									end
								end
								decay = decay + (empty_adjacent/#slot_map) * decay_mult * energy_base
							end

							local fire = shipManager:GetFireAtPoint(room_map.x + i * 35, room_map.y + j * 35)
							if fire and fire.bWasOnFire then
								if fire.fDeathTimer > 0 then
									fire.fDeathTimer = fire.fDeathTimer + time_increment(true) * fire_death_mult
								end
								if current_energy > 0 then 
									fire.fStartTimer = fire.fStartTimer + time_increment(true) * fire_start_mult
								end
								decay = decay + fire_damage_rate
							end

							local fire_room_count = shipManager:GetFireCount(room.iRoomId)
							decay = decay + fire_room_count * fire_room_damage_rate

							table_growth[shipManager.iShipId][room.iRoomId][i][j].val = math.max(0, current_energy - decay * update_timer[shipManager.iShipId])
							if table_growth[shipManager.iShipId][room.iRoomId][i][j].val <= 0 and table_bud[shipManager.iShipId][room.iRoomId] and
								table_bud[shipManager.iShipId][room.iRoomId].i == i and table_bud[shipManager.iShipId][room.iRoomId].j == j then
								table_bud[shipManager.iShipId][room.iRoomId] = false
							end
						end
					end
				end
			end
			update_timer[shipManager.iShipId] = 0
		end

		save_timer[shipManager.iShipId] = save_timer[shipManager.iShipId] + time_increment(true)
		if save_timer[shipManager.iShipId] > save_rate then
			save_system(shipManager, system)
			save_timer[shipManager.iShipId] = 0
		end
	end
end)
			

local COLOUR_WHITE = Graphics.GL_Color(1, 1, 1, 1)
local COLOUR_BLACK = Graphics.GL_Color(0, 0, 0, 1)
local COLOUR_GREEN = Graphics.GL_Color(0, 0.5, 0, 1)
script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function(ship, experimental) return Defines.Chain.CONTINUE end, function(ship, experimental) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local map = table_map[shipManager.iShipId]
		for room in vter(ship.vRoomList) do
			local room_map = map[room.iRoomId]
			local w = room_map.w
			local h = room_map.h
			for i = 0, w - 1 do
				for j = 0, h - 1 do
					local current = table_growth[shipManager.iShipId][room.iRoomId][i][j].val
					local image_table = table_growth[shipManager.iShipId][room.iRoomId][i][j].image
					Graphics.CSurface.GL_SetColor(COLOUR_WHITE)
					if current > 10 then
						local i = math.floor((current - 10)/20) + 1
						image_table[i]:OnRender(1, COLOUR_WHITE, false)
					end
					local x = room.rect.x + i * 35
					local y = room.rect.y + j * 35
					if table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].i == i and table_bud[shipManager.iShipId][room.iRoomId].j == j then
						Graphics.CSurface.GL_SetColor(COLOUR_GREEN)
					else
						Graphics.CSurface.GL_SetColor(COLOUR_BLACK)
					end
					Graphics.freetype.easy_print(5, x+4, y+2, string.format("%.1f", current))
				end
			end
		end
		Graphics.CSurface.GL_SetColor(COLOUR_WHITE)
	end
	return Defines.Chain.CONTINUE 
end)