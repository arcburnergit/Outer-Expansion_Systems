local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
local string_starts = mods.multiverse.string_starts

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

local energy_base = 50
local energy_scaler = 25
local decay_base = 20
local decay_bud_base = 10
local update_rate = 0.05
local save_rate = 1

local out_of_combat_mult = 2
local trapping_mult = 0.5

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

local bud_types = {
	{name = "Oxygen", colour = "blue", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_oxygen"), count = 0},
	{name = "Floral", colour = "green", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_floral"), count = 0},
	{name = "Vampweed", colour = "red", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_vampweed"), count = 0},
	{name = "Praetor", req="OE_GROWTH_BUD_PRAETOR", colour = "praetor", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_praetor"), count = 0, max_count = 1},
	{name = "Cultivator", req="OE_GROWTH_BUD_CULTIVATOR", colour = "cultivator", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_cultivator"), count = 0, max_count = 3},
	{name = "Acidic", req="OE_GROWTH_BUD_ACIDIC", colour = "acidic", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_acidic"), count = 0},
	{name = "Suffocating", req="OE_GROWTH_BUD_SUFFOCATING", colour = "grey", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_suffocating"), count = 0},
	{name = "Entangling", req="OE_GROWTH_BUD_ENTANGLING", colour = "orange", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_entangling"), count = 0},
	{name = "Trapping", req="OE_GROWTH_BUD_TRAPPING", colour = "brown", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_trapping"), count = 0},
	{name = "Electrified", req="OE_GROWTH_BUD_ELECTRIFIED", colour = "electric", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_electrified"), count = 0, max_count = 1},
	{name = "Soulplagued", req="OE_GROWTH_BUD_DD_SOULPLAGUED", colour = "soulplagued", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_dd_soulplagued"), count = 0},
}
table.insert(bud_types, {name = "Root", req="UPG_OE_GROWTH_ROOT", colour = "brown", desc = Hyperspace.Text:GetText("oe_lua_sys_growth_effect_root")})

local bud_types_indexed = {}
for i, bud in ipairs(bud_types) do
	bud_types_indexed[bud.name] = i
end

--Handles initialization of custom system box
local buttonOffset_x = 37
local buttonOffset_y = -50
local function construct_system_box(systemBox)
	if is_system(systemBox) then
		systemBox.extend.xOffset = 54

		local button = Hyperspace.Button()
		button:OnInit("systemUI/button_oe_growth", Hyperspace.Point(buttonOffset_x, buttonOffset_y))
		button.hitbox.x = 10
		button.hitbox.y = 47
		button.hitbox.w = 20
		button.hitbox.h = 19
		systemBox.table.button = button

		local effectButtonTable = {}
		for i = 1, #bud_types do
			local effectButton = Hyperspace.Button()
			effectButton:OnInit("systemUI/oe_grease_box_button_blank", Hyperspace.Point(0, 0))
			effectButton.hitbox.x = 0
			effectButton.hitbox.y = 0
			effectButton.hitbox.w = 22
			effectButton.hitbox.h = 22
			table.insert(effectButtonTable, {b = effectButton, position = {x = 0, y = 0}})
		end
		systemBox.table.effectButtonTable = effectButtonTable

		systemBox.pSystem.bBoostable = false
	elseif is_system_enemy(systemBox) then
		systemBox.pSystem.bBoostable = false
	end
end

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, construct_system_box)

local function mouse_move(systemBox, x, y)
	if is_system(systemBox) then
		local button = systemBox.table.button
		button:MouseMove(x - buttonOffset_x, y - buttonOffset_y, false)
		local effectButtonTable = systemBox.table.effectButtonTable
		for _, effectButton in ipairs(effectButtonTable) do
			effectButton.b:MouseMove(x - effectButton.position.x, y - effectButton.position.y, false)
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, mouse_move)

local displayOptions = false
local buttonHover = false
local active_target_bud = false
--Handles click events 
local function system_click(systemBox, shift)
	if is_system(systemBox) then
		local button = systemBox.table.button
		if button.bHover and button.bActive then
			displayOptions = not displayOptions
			active_target_bud = false
		end

		local effectButtonTable = systemBox.table.effectButtonTable
		for i, effectButton in ipairs(effectButtonTable) do
			if effectButton.b.bHover and effectButton.b.bActive then
				active_target_bud = i
			end
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, system_click)

local table_growth = {[0] = {}, [1] = {} }
local table_map = {[0] = nil, [1] = nil}
local table_bud = {[0] = {}, [1] = {}}
local table_bud_2 = {[0] = {}, [1] = {}}
local table_bud_set = {[0] = {}, [1] = {}}
local table_bud_set_2 = {[0] = {}, [1] = {}}

local function new_bud(i, j)
	return {i = i, j = j}
end

local growth_variable = "save_oe_growth%d_room%d_i%d_j%d"
local root_variable = "save_oe_root%d"
local bud_variable_i = "save_oe_bud%d_room%d_i"
local bud_variable_j = "save_oe_bud%d_room%d_j"
local bud_variable_2_i = "save_oe_bud%d_room%d_2_i"
local bud_variable_2_j = "save_oe_bud%d_room%d_2_j"
local bud_variable_setting = "save_oe_bud%d_room%d_setting"
local bud_variable_setting_2 = "save_oe_bud%d_room%d_setting_2"

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipManager)
	table_growth[shipManager.iShipId] = {}
	table_bud[shipManager.iShipId] = {}
	table_bud_2[shipManager.iShipId] = {}
	table_bud_set[shipManager.iShipId] = {}
	table_bud_set_2[shipManager.iShipId] = {}
	table_map[shipManager.iShipId] = nil
end)

script.on_game_event("START_BEACON", false, function()
	table_growth[0] = {}
	table_bud[0] = {}
	table_bud_2[0] = {}
	table_bud_set[0] = {}
	table_bud_set_2[0] = {}
	table_map[0] = nil
end)

local function save_system(shipManager, system)
	for room in vter(shipManager.ship.vRoomList) do
		Hyperspace.playerVariables[string.format(bud_variable_i, shipManager.iShipId, room.iRoomId)] = (table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].i) or -1
		Hyperspace.playerVariables[string.format(bud_variable_j, shipManager.iShipId, room.iRoomId)] = (table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].j) or -1
		Hyperspace.playerVariables[string.format(bud_variable_2_i, shipManager.iShipId, room.iRoomId)] = (table_bud_2[shipManager.iShipId][room.iRoomId] and table_bud_2[shipManager.iShipId][room.iRoomId].i) or -1
		Hyperspace.playerVariables[string.format(bud_variable_2_j, shipManager.iShipId, room.iRoomId)] = (table_bud_2[shipManager.iShipId][room.iRoomId] and table_bud_2[shipManager.iShipId][room.iRoomId].j) or -1
		Hyperspace.playerVariables[string.format(bud_variable_setting, shipManager.iShipId, room.iRoomId)] = (table_bud_set[shipManager.iShipId][room.iRoomId] and table_bud_set[shipManager.iShipId][room.iRoomId].index) or 1
		Hyperspace.playerVariables[string.format(bud_variable_setting_2, shipManager.iShipId, room.iRoomId)] = (table_bud_set_2[shipManager.iShipId][room.iRoomId] and table_bud_set_2[shipManager.iShipId][room.iRoomId].index) or 1
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
		local bud_2_i = Hyperspace.playerVariables[string.format(bud_variable_2_i, shipManager.iShipId, room.iRoomId)]
		local bud_2_j = Hyperspace.playerVariables[string.format(bud_variable_2_j, shipManager.iShipId, room.iRoomId)]
		local bud_set = Hyperspace.playerVariables[string.format(bud_variable_setting, shipManager.iShipId, room.iRoomId)]
		local bud_set_2 = Hyperspace.playerVariables[string.format(bud_variable_setting_2, shipManager.iShipId, room.iRoomId)]
		if bud_i >= 0 and bud_j >= 0 then
			table_bud[shipManager.iShipId][room.iRoomId] = new_bud(bud_i, bud_j)
		end
		if bud_2_i >= 0 and bud_2_j >= 0 then
			table_bud_2[shipManager.iShipId][room.iRoomId] = new_bud(bud_2_i, bud_2_j)
		end
		for _, bud in ipairs(bud_types) do
			bud.count = 0
		end
		if bud_set > 0 then
			bud_types[bud_set].count = bud_types[bud_set].count + 1
			table_bud_set[shipManager.iShipId][room.iRoomId].index = bud_set
		else
			bud_types[1].count = bud_types[1].count + 1
			table_bud_set[shipManager.iShipId][room.iRoomId].index = 1
		end
		if bud_set_2 > 0 then
			bud_types[bud_set_2].count = bud_types[bud_set_2].count + 1
			table_bud_set_2[shipManager.iShipId][room.iRoomId].index = bud_set_2
		else
			bud_types[1].count = bud_types[1].count + 1
			table_bud_set_2[shipManager.iShipId][room.iRoomId].index = 1
		end
		local room_map = table_map[shipManager.iShipId][room.iRoomId]
		local w = room_map.w
		local h = room_map.h
		for i = 0, w - 1 do
			for j = 0, h - 1 do
				table_growth[shipManager.iShipId][room.iRoomId][i][j].val = Hyperspace.playerVariables[string.format(growth_variable, shipManager.iShipId, room.iRoomId, i, j)]
			end
		end
		if Hyperspace.playerVariables[string.format(root_variable, shipManager.iShipId)] > -1 then
			system.table.growth_root = Hyperspace.playerVariables[string.format(root_variable, shipManager.iShipId)]
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
				if i - 1 >= 0 then table.insert(adjacent, {room = room.iRoomId, dir="l", i = i - 1, j = j}) end
				if i + 1 < w then table.insert(adjacent, {room = room.iRoomId, dir="r", i = i + 1, j = j}) end
				if j - 1 >= 0 then table.insert(adjacent, {room = room.iRoomId, dir="u", i = i, j = j - 1}) end
				if j + 1 < h then table.insert(adjacent, {room = room.iRoomId, dir="d", i = i, j = j + 1}) end
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
		local room_1_d = nil

		local room_2 = door.iRoom2
		local room_2_i = nil
		local room_2_j = nil
		local room_2_d = nil
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
						local d = nil
						if x == room.rect.x then
							i = 0
							d = "l"
						elseif x == room.rect.x + room.rect.w then
							i = w - 1
							d = "r"
						end
						if i and y >= room.rect.y and y < room.rect.y + room.rect.h then
							local j = (y - room.rect.y) / 35
							if room.iRoomId == room_1 then
								room_1_i = i
								room_1_j = j
								room_1_d = d
							else
								room_2_i = i
								room_2_j = j
								room_2_d = d
							end 
						end
					else
						local x = door.x - 17
						local y = door.y 
						local j = nil
						local d = nil
						if y == room.rect.y then
							j = 0
							d = "u"
						elseif y == room.rect.y + room.rect.h then
							j = h - 1
							d = "d"
						end
						if j and x >= room.rect.x and x < room.rect.x + room.rect.w then
							local i = (x - room.rect.x) / 35
							if room.iRoomId == room_1 then
								room_1_i = i
								room_1_j = j
								room_1_d = d
							else
								room_2_i = i
								room_2_j = j
								room_2_d = d
							end 
						end
					end
				end
				if room_1_i and room_1_j and room_2_i and room_2_j then
					table.insert(table_map[shipManager.iShipId][room_1].slots[room_1_i][room_1_j], {room = room_2, dir = room_1_d, i = room_2_i, j = room_2_j})
					table.insert(table_map[shipManager.iShipId][room_2].slots[room_2_i][room_2_j], {room = room_1, dir = room_2_d, i = room_1_i, j = room_1_j})
					break
				end
			end
		end
		
	end
end

local flower_colour_list_random = {
	"red",
	"orange",
	"yellow",
	"green",
	"cyan",
	"blue",
	"magenta",
}

local flower_colour_list = {
	red = Graphics.GL_Color(208/255, 86/255, 86/255, 1),
	orange = Graphics.GL_Color(221/255, 145/255, 73/255, 1),
	yellow = Graphics.GL_Color(221/255, 217/255, 78/255, 1),
	green = Graphics.GL_Color(96/255, 208/255, 90/255, 1),
	cyan = Graphics.GL_Color(78/255, 221/255, 208/255, 1),
	blue = Graphics.GL_Color(79/255, 157/255, 210/255, 1),
	magenta = Graphics.GL_Color(223/255, 92/255, 202/255, 1),
	acidic = Graphics.GL_Color(54/255, 255/255, 53/255, 1),
	grey = Graphics.GL_Color(149/255, 149/255, 149/255, 1),
	white = Graphics.GL_Color(255/255, 255/255, 255/255, 1),
	praetor = Graphics.GL_Color(187/255, 255/255, 253/255, 1),
	cultivator = Graphics.GL_Color(91/255, 127/255, 0/255, 1),
	electric = Graphics.GL_Color(255/255, 247/255, 0/255, 1),
	brown = Graphics.GL_Color(80/255, 67/255, 59/255, 1),
	soulplagued = Graphics.GL_Color(34/255, 12/255, 107/255, 1),
}
local flower_dark_colour_list = {
	red = Graphics.GL_Color(156/255, 57/255, 83/255, 1),
	orange = Graphics.GL_Color(171/255, 101/255, 61/255, 1),
	yellow = Graphics.GL_Color(169/255, 134/255, 66/255, 1),
	green = Graphics.GL_Color(53/255, 156/255, 55/255, 1),
	cyan = Graphics.GL_Color(57/255, 152/255, 148/255, 1),
	blue = Graphics.GL_Color(57/255, 81/255, 152/255, 1),
	magenta = Graphics.GL_Color(119/255, 58/255, 161/255, 1),
	acidic = Graphics.GL_Color(0/255, 209/255, 4/255, 1),
	grey = Graphics.GL_Color(105/255, 105/255, 105/255, 1),
	white = Graphics.GL_Color(200/255, 200/255, 200/255, 1),
	praetor = Graphics.GL_Color(69/255, 106/255, 123/255, 1),
	cultivator = Graphics.GL_Color(60/255, 74/255, 0/255, 1),
	electric = Graphics.GL_Color(169/255, 134/255, 66/255, 1),
	brown = Graphics.GL_Color(33/255, 28/255, 28/255, 1),
	soulplagued = Graphics.GL_Color(0, 0, 0, 1),
}

local function generate_slot_anim(shipManager, room, i, j)
	local s = "oe_growth_tile_%d"
	local spc = "oe_growth_tile_primary_colour_%d"
	local sdpc = "oe_growth_tile_dark_primary_colour_%d"
	local ssc = "oe_growth_tile_secondary_colour_%d"
	local sdsc = "oe_growth_tile_dark_secondary_colour_%d"
	local b = "oe_growth_bud_%d"
	local bc = "oe_growth_bud_colour_%d"
	local bdc = "oe_growth_bud_dark_colour_%d"
	local post_fix = "_udlr"
	local room_map = table_map[shipManager.iShipId][room.iRoomId]
	local slot_map = room_map.slots[i][j]
	for _, adjacent in ipairs(slot_map) do
		--print(string.format("check_adjacent:%d i:%d j:%d", adjacent.room, adjacent.i, adjacent.j))
		if adjacent.room == room.iRoomId then
			post_fix = string.gsub(post_fix, adjacent.dir, "")
		end
	end
	--print(string.format("ship:%d room:%d i:%d j:%d s:%s", shipManager.iShipId, room.iRoomId, i, j, post_fix))
	local tile_image_table = {}
	local tile_colour_primary_table = {}
	local tile_colour_dark_primary_table = {}
	local tile_colour_secondary_table = {}
	local tile_colour_dark_secondary_table = {}
	for n = 1, 5 do
		local anim = Hyperspace.Animations:GetAnimation(string.format(s, n)..post_fix)
		anim.position.x = room.rect.x + i * 35
		anim.position.y = room.rect.y + j * 35
		tile_image_table[n] = anim
		if n >= 4 then
			local anim_colour_dark_primary = Hyperspace.Animations:GetAnimation(string.format(sdpc, n)..post_fix)
			anim_colour_dark_primary.position.x = room.rect.x + i * 35
			anim_colour_dark_primary.position.y = room.rect.y + j * 35
			tile_colour_dark_primary_table[n] = anim_colour_dark_primary
			local anim_colour_dark_secondary = Hyperspace.Animations:GetAnimation(string.format(sdsc, n)..post_fix)
			anim_colour_dark_secondary.position.x = room.rect.x + i * 35
			anim_colour_dark_secondary.position.y = room.rect.y + j * 35
			tile_colour_dark_secondary_table[n] = anim_colour_dark_secondary
			if n >= 5 then
				local anim_colour_primary = Hyperspace.Animations:GetAnimation(string.format(spc, n)..post_fix)
				anim_colour_primary.position.x = room.rect.x + i * 35
				anim_colour_primary.position.y = room.rect.y + j * 35
				tile_colour_primary_table[n] = anim_colour_primary
				local anim_colour_secondary = Hyperspace.Animations:GetAnimation(string.format(ssc, n)..post_fix)
				anim_colour_secondary.position.x = room.rect.x + i * 35
				anim_colour_secondary.position.y = room.rect.y + j * 35
				tile_colour_secondary_table[n] = anim_colour_secondary
			end
		end
	end
	local bud_image_table = {}
	local bud_colour_table = {}
	local bud_colour_dark_table = {}
	for n = 1, 3 do
		local anim = Hyperspace.Animations:GetAnimation(string.format(b, n)..post_fix)
		anim.position.x = room.rect.x + i * 35
		anim.position.y = room.rect.y + j * 35
		bud_image_table[n] = anim
		local anim_dark_colour = Hyperspace.Animations:GetAnimation(string.format(bdc, n)..post_fix)
		anim_dark_colour.position.x = room.rect.x + i * 35
		anim_dark_colour.position.y = room.rect.y + j * 35
		bud_colour_dark_table[n] = anim_dark_colour
		local anim_colour = Hyperspace.Animations:GetAnimation(string.format(bc, n)..post_fix)
		anim_colour.position.x = room.rect.x + i * 35
		anim_colour.position.y = room.rect.y + j * 35
		bud_colour_table[n] = anim_colour
	end
	local colour_primary_index = math.random(#flower_colour_list_random)
	local colour_secondary_index = math.random(#flower_colour_list_random - 1)
	if colour_secondary_index >= colour_primary_index then colour_secondary_index = colour_secondary_index + 1 end
	local colour_primary = flower_colour_list_random[colour_primary_index]
	local colour_secondary = flower_colour_list_random[colour_secondary_index]
	return {
		tile = tile_image_table, 
		tile_p =  tile_colour_primary_table, 
		tile_d_p =  tile_colour_dark_primary_table, 
		tile_s = tile_colour_secondary_table, 
		tile_d_s = tile_colour_dark_secondary_table, 
		bud =  bud_image_table, 
		bud_c = bud_colour_table, 
		bud_d_c = bud_colour_dark_table, 
		colour_p = colour_primary, 
		colour_s = colour_secondary
	}
end

local acidic_ships_check = {}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if not table_map[shipManager.iShipId] then
		table_map[shipManager.iShipId] = {}
		construct_room_connection_map(shipManager)
		for room in vter(shipManager.ship.vRoomList) do
			table_bud[shipManager.iShipId][room.iRoomId] = false
			table_bud_2[shipManager.iShipId][room.iRoomId] = false
			table_bud_set[shipManager.iShipId][room.iRoomId] = {index = 1, active = false}
			table_bud_set_2[shipManager.iShipId][room.iRoomId] = {index = 1, active = false}
			if acidic_ships_check[shipManager.myBlueprint.blueprintName] and not shipManager:GetSystemInRoom(room.iRoomId) then
				bud_types[6].count = bud_types[6].count + 1
				table_bud_set[shipManager.iShipId][room.iRoomId].index = 6
			elseif shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
				bud_types[1].count = bud_types[1].count + 1
				if not loadSystems[shipManager.iShipId] then
					shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, 100)
				end
			end
			table_growth[shipManager.iShipId][room.iRoomId] = {}
			local room_map = table_map[shipManager.iShipId][room.iRoomId]
			local w = room_map.w
			local h = room_map.h
			for i = 0, w - 1 do
				table_growth[shipManager.iShipId][room.iRoomId][i] = {}
				for j = 0, h - 1 do
					local image = generate_slot_anim(shipManager, room, i, j)
					--print(string.format("setup:%d, %d, %d, %d", shipManager.iShipId, room.iRoomId, i, j))
					table_growth[shipManager.iShipId][room.iRoomId][i][j] = {val = 100, image = image}
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
		if not system.table.growth_root then 
			system.table.growth_root = system.roomId 
			Hyperspace.playerVariables[string.format(root_variable, shipManager.iShipId)] = system.table.growth_root
		end
		local system_room_id = (shipManager:HasAugmentation("UPG_OE_GROWTH_ROOT") > 0 and system.table.growth_root) or system.roomId
		local power = system:GetEffectivePower()

		update_timer[shipManager.iShipId] = update_timer[shipManager.iShipId] + time_increment(true)
		if update_timer[shipManager.iShipId] > update_rate then
			
			local map = table_map[shipManager.iShipId]
			local visited = {}
			if power > 0 then
				local current_front = {}
				local current_front_number = 0
				local energy = (energy_base + energy_scaler * (power - 1)) * update_timer[shipManager.iShipId]
				if Hyperspace.App.gui.upgradeButton.bActive then
					energy = energy * out_of_combat_mult
				end

				local system_room_map = map[system_room_id]
				for i = 0, system_room_map.w - 1 do
					for j = 0, system_room_map.h - 1 do
						local needs_energy = table_growth[shipManager.iShipId][system_room_id][i][j].val <= 99
						if needs_energy then current_front_number = current_front_number + 1 end
						table.insert(current_front, {room = system_room_id, i = i, j = j, needs_energy})
						visited[system_room_id] = visited[system_room_id] or {}
						visited[system_room_id][i] = visited[system_room_id][i] or {}
						visited[system_room_id][i][j] = true
					end
				end

				while #current_front > 0 do
					if current_front_number <= 0 then current_front_number = 1 end
					local energy_per_cell = energy / current_front_number
					local next_front = {}
					local next_front_number = 0
					local energy_spent = 0
					for _, cell in ipairs(current_front) do
						local current_energy = table_growth[shipManager.iShipId][cell.room][cell.i][cell.j].val
						local energy_needed = 100 - current_energy
						local energy_add = math.min(energy_per_cell, energy_needed)
						if table_bud[shipManager.iShipId][cell.room] and table_bud[shipManager.iShipId][cell.room].i == cell.i and table_bud[shipManager.iShipId][cell.room].j == cell.j and
								table_bud_set[shipManager.iShipId][cell.room].index == bud_types_indexed["Trapping"] then
							energy_add = energy_add * trapping_mult
						elseif table_bud_2[shipManager.iShipId][cell.room] and table_bud_2[shipManager.iShipId][cell.room].i == cell.i and table_bud_2[shipManager.iShipId][cell.room].j == cell.j and
								table_bud_set_2[shipManager.iShipId][cell.room].index == bud_types_indexed["Trapping"] then
							energy_add = energy_add * trapping_mult
						end

						local fire_room_count = shipManager:GetFireCount(cell.room)
						if fire_room_count <= 0 then
							table_growth[shipManager.iShipId][cell.room][cell.i][cell.j].val = current_energy + energy_add
							energy_spent = energy_spent + energy_add
						end

						if table_growth[shipManager.iShipId][cell.room][cell.i][cell.j].val > 0 then
							local slot_map = map[cell.room].slots[cell.i][cell.j]
							for _, adjacent in ipairs(slot_map) do
								if not visited[adjacent.room] or not visited[adjacent.room][adjacent.i] or not visited[adjacent.room][adjacent.i][adjacent.j] then
									local needs_energy = table_growth[shipManager.iShipId][adjacent.room][adjacent.i][adjacent.j].val <= 99
									if needs_energy then next_front_number = current_front_number + 1 end
									table.insert(next_front, {room = adjacent.room, i = adjacent.i, j = adjacent.j, needs_energy = needs_energy})
									visited[adjacent.room] = visited[adjacent.room] or {}
									visited[adjacent.room][adjacent.i] = visited[adjacent.room][adjacent.i] or {}
									visited[adjacent.room][adjacent.i][adjacent.j] = true
								end
							end
						end
					end
					energy = math.max(0, energy - energy_spent)
					current_front = next_front
					current_front_number = next_front_number
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
						local active_bud_index = table_bud_set[shipManager.iShipId][room.iRoomId].index
						local active_bud_index_2 = table_bud_set_2[shipManager.iShipId][room.iRoomId].index
						--local active_bud = bud_types[active_bud_index]
						local current_energy = table_growth[shipManager.iShipId][room.iRoomId][i][j].val
						local decay = 0
						if current_energy > 0 then
							if not (table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].i and table_bud[shipManager.iShipId][room.iRoomId].j) then
								if current_energy > 50 and not (table_bud_2[shipManager.iShipId][room.iRoomId] and table_bud_2[shipManager.iShipId][room.iRoomId].i == i and table_bud_2[shipManager.iShipId][room.iRoomId].j == j) then
									table_bud[shipManager.iShipId][room.iRoomId] = new_bud(i, j)
								end
							elseif table_bud[shipManager.iShipId][room.iRoomId].i == i and table_bud[shipManager.iShipId][room.iRoomId].j == j then
								if not connected then
									decay = decay + decay_bud_base
									table_bud_set[shipManager.iShipId][room.iRoomId].active = false
								end
								if current_energy > 50 then
									table_bud_set[shipManager.iShipId][room.iRoomId].active = true
									if active_bud_index == bud_types_indexed["Oxygen"] then
										shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, 5 * update_timer[shipManager.iShipId])
									elseif active_bud_index == bud_types_indexed["Acidic"] then
										mods.oe.acid.setAcid(shipManager.iShipId, room.iRoomId, 0.5)
									elseif active_bud_index == bud_types_indexed["Suffocating"] then
										shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, -5 * update_timer[shipManager.iShipId])
									end
								elseif connected then
									table_bud_set[shipManager.iShipId][room.iRoomId].active = false
									table_bud[shipManager.iShipId][room.iRoomId] = false
								end
							end

							if shipManager:HasAugmentation("UPG_OE_GROWTH_EXTRA_BUD") > 0 then
								if not (table_bud_2[shipManager.iShipId][room.iRoomId] and table_bud_2[shipManager.iShipId][room.iRoomId].i and table_bud_2[shipManager.iShipId][room.iRoomId].j) then
									if current_energy > 50 and not (table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].i == i and table_bud[shipManager.iShipId][room.iRoomId].j == j) then
										table_bud_2[shipManager.iShipId][room.iRoomId] = new_bud(i, j)
									end
								elseif table_bud_2[shipManager.iShipId][room.iRoomId].i == i and table_bud_2[shipManager.iShipId][room.iRoomId].j == j then
									if not connected then
										decay = decay + decay_bud_base
										table_bud_set_2[shipManager.iShipId][room.iRoomId].active = false
									end
									if current_energy > 50 then
										table_bud_set_2[shipManager.iShipId][room.iRoomId].active = true
										if active_bud_index_2 == bud_types_indexed["Oxygen"] then
											shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, 5 * update_timer[shipManager.iShipId])
										elseif active_bud_index_2 == bud_types_indexed["Acidic"] then
											mods.oe.acid.setAcid(shipManager.iShipId, room.iRoomId, 0.5)
										elseif active_bud_index_2 == bud_types_indexed["Suffocating"] then
											shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, -5 * update_timer[shipManager.iShipId])
										end
									elseif connected then
										table_bud_set_2[shipManager.iShipId][room.iRoomId].active = false
										table_bud_2[shipManager.iShipId][room.iRoomId] = false
									end
								end
							else
								table_bud_2[shipManager.iShipId][room.iRoomId] = false
								table_bud_set_2[shipManager.iShipId][room.iRoomId].active = false
							end

							if not connected then
								local empty_adjacent = 0
								for _, adjacent in ipairs(slot_map) do
									if table_growth[shipManager.iShipId][adjacent.room][adjacent.i][adjacent.j].val <= 0 then
										empty_adjacent = empty_adjacent + 1
									end
								end
								decay = decay + (empty_adjacent/#slot_map) * decay_base
							end

							local fire = shipManager:GetFireAtPoint(room_map.x + i * 35, room_map.y + j * 35)
							if fire and fire.bWasOnFire then
								if fire.fDeathTimer > 0 then
									fire.fDeathTimer = fire.fDeathTimer + update_timer[shipManager.iShipId] * fire_death_mult
								end
								if current_energy > 0 then 
									fire.fStartTimer = fire.fStartTimer + update_timer[shipManager.iShipId] * fire_start_mult
								end
								decay = decay + fire_damage_rate
								shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, 20 * update_timer[shipManager.iShipId])
							end

							local fire_room_count = shipManager:GetFireCount(room.iRoomId)
							decay = decay + fire_room_count * fire_room_damage_rate

							table_growth[shipManager.iShipId][room.iRoomId][i][j].val = math.max(0, current_energy - decay * update_timer[shipManager.iShipId])
							if table_growth[shipManager.iShipId][room.iRoomId][i][j].val <= 0 and table_bud[shipManager.iShipId][room.iRoomId] and
									table_bud[shipManager.iShipId][room.iRoomId].i == i and table_bud[shipManager.iShipId][room.iRoomId].j == j then
								table_bud[shipManager.iShipId][room.iRoomId] = false
								table_bud_set[shipManager.iShipId][room.iRoomId].active = false
							end
							if table_growth[shipManager.iShipId][room.iRoomId][i][j].val <= 0 and table_bud_2[shipManager.iShipId][room.iRoomId] and
									table_bud_2[shipManager.iShipId][room.iRoomId].i == i and table_bud_2[shipManager.iShipId][room.iRoomId].j == j then
								table_bud_2[shipManager.iShipId][room.iRoomId] = false
								table_bud_set_2[shipManager.iShipId][room.iRoomId].active = false
							end
							if table_bud[shipManager.iShipId][room.iRoomId] and table_bud_2[shipManager.iShipId][room.iRoomId] and 
									table_bud[shipManager.iShipId][room.iRoomId].i == table_bud_2[shipManager.iShipId][room.iRoomId].i and 
									table_bud[shipManager.iShipId][room.iRoomId].j == table_bud_2[shipManager.iShipId][room.iRoomId].j then
								table_bud_2[shipManager.iShipId][room.iRoomId] = false
								table_bud_set_2[shipManager.iShipId][room.iRoomId].active = false
							end
						end
					end
				end
			end
			for breach in vter(shipManager.ship:GetHullBreaches(true)) do
				if table_bud_set[shipManager.iShipId] and table_bud_set[shipManager.iShipId][breach.roomId] and table_bud_set[shipManager.iShipId][breach.roomId].active then
					local active_bud_index = table_bud_set[shipManager.iShipId][breach.roomId].index
					local active_bud = bud_types[active_bud_index]
					if active_bud.name == "Acidic" then
						breach.fDamage = breach.fDamage - 10 * update_timer[shipManager.iShipId]
					end
				end	
				if table_bud_set_2[shipManager.iShipId] and table_bud_set_2[shipManager.iShipId][breach.roomId] and table_bud_set_2[shipManager.iShipId][breach.roomId].active then
					local active_bud_index = table_bud_set_2[shipManager.iShipId][breach.roomId].index
					local active_bud = bud_types[active_bud_index]
					if active_bud.name == "Acidic" then
						breach.fDamage = breach.fDamage - 10 * update_timer[shipManager.iShipId]
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
local COLOUR_RED = Graphics.GL_Color(1, 0, 0, 1)
local COLOUR_BLACK = Graphics.GL_Color(0, 0, 0, 1)
local COLOUR_GREEN = Graphics.GL_Color(0, 0.5, 0, 1)
local IMAGE_ROOT = Hyperspace.Resources:CreateImagePrimitiveString( "effects/oe_growth_roots.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 0.75, false)
script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship, experimental) return Defines.Chain.CONTINUE end, function(ship, experimental) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
		local map = table_map[shipManager.iShipId]
		for room in vter(ship.vRoomList) do
			local room_map = map[room.iRoomId]
			local active_bud_index = table_bud_set[shipManager.iShipId][room.iRoomId].index
			local active_bud_index_2 = table_bud_set_2[shipManager.iShipId][room.iRoomId].index
			local active_bud = bud_types[active_bud_index]
			local active_bud_2 = bud_types[active_bud_index_2]
			local w = room_map.w
			local h = room_map.h
			if (not room.bBlackedOut) or Hyperspace.ships.player:GetAugmentationValue("LIFE_SCANNER") > 0 then
				for i = 0, w - 1 do
					for j = 0, h - 1 do
						local current = table_growth[shipManager.iShipId][room.iRoomId][i][j].val
						local image_table = table_growth[shipManager.iShipId][room.iRoomId][i][j].image
						Graphics.CSurface.GL_SetColor(COLOUR_WHITE)
						local back_colour = COLOUR_WHITE
						if Hyperspace.ships.player:GetAugmentationValue("LIFE_SCANNER") > 0 and room.bBlackedOut then
							back_colour = COLOUR_RED
						end
						if current > 10 then
							local i = math.floor((current - 10)/20) + 1
							image_table.tile[i]:OnRender(1, back_colour, false)
							if i >= 4 then
								image_table.tile_d_p[i]:OnRender(1, flower_dark_colour_list[image_table.colour_p], false)
								image_table.tile_d_s[i]:OnRender(1, flower_dark_colour_list[image_table.colour_s], false)
								if i >= 5 then
									image_table.tile_p[i]:OnRender(1, flower_colour_list[image_table.colour_p], false)
									image_table.tile_s[i]:OnRender(1, flower_colour_list[image_table.colour_s], false)
								end
							end
						end
						if table_bud[shipManager.iShipId][room.iRoomId] and table_bud[shipManager.iShipId][room.iRoomId].i == i and table_bud[shipManager.iShipId][room.iRoomId].j == j then
							if current > 90 then
								image_table.bud[3]:OnRender(1, back_colour, false)
								image_table.bud_d_c[3]:OnRender(1, flower_dark_colour_list[active_bud.colour], false)
								image_table.bud_c[3]:OnRender(1, flower_colour_list[active_bud.colour], false)
							elseif current > 70 then
								image_table.bud[2]:OnRender(1, back_colour, false)
								image_table.bud_d_c[2]:OnRender(1, flower_dark_colour_list[active_bud.colour], false)
								image_table.bud_c[2]:OnRender(1, flower_colour_list[active_bud.colour], false)
							elseif current > 50 then
								image_table.bud[1]:OnRender(1, back_colour, false)
								image_table.bud_d_c[1]:OnRender(1, flower_dark_colour_list[active_bud.colour], false)
								image_table.bud_c[1]:OnRender(1, flower_colour_list[active_bud.colour], false)
							end
						end
						if table_bud_2[shipManager.iShipId][room.iRoomId] and table_bud_2[shipManager.iShipId][room.iRoomId].i == i and table_bud_2[shipManager.iShipId][room.iRoomId].j == j then
							if current > 90 then
								image_table.bud[3]:OnRender(1, back_colour, false)
								image_table.bud_d_c[3]:OnRender(1, flower_dark_colour_list[active_bud_2.colour], false)
								image_table.bud_c[3]:OnRender(1, flower_colour_list[active_bud_2.colour], false)
							elseif current > 70 then
								image_table.bud[2]:OnRender(1, back_colour, false)
								image_table.bud_d_c[2]:OnRender(1, flower_dark_colour_list[active_bud_2.colour], false)
								image_table.bud_c[2]:OnRender(1, flower_colour_list[active_bud_2.colour], false)
							elseif current > 50 then
								image_table.bud[1]:OnRender(1, back_colour, false)
								image_table.bud_d_c[1]:OnRender(1, flower_dark_colour_list[active_bud_2.colour], false)
								image_table.bud_c[1]:OnRender(1, flower_colour_list[active_bud_2.colour], false)
							end
						end
					end
				end
			end

			if shipManager.iShipId == 0 and (displayOptions or buttonHover) then
				if active_target_bud and Hyperspace.App.gui.combatControl.selectedSelfRoom == room.iRoomId then
					Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive)
					Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive2)
				else
					local colour_outline = flower_colour_list[active_bud.colour]
					local colour_outline_dark = flower_dark_colour_list[active_bud.colour]
					Graphics.CSurface.GL_PushStencilMode()
					Graphics.CSurface.GL_SetStencilMode(1,1,1)
					Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive)
					Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive2)
					Graphics.CSurface.GL_SetStencilMode(2,1,1)
					if shipManager:HasAugmentation("UPG_OE_GROWTH_EXTRA_BUD") > 0 then
						local colour_outline_2 = flower_colour_list[active_bud_2.colour]
						local colour_outline_dark_2 = flower_dark_colour_list[active_bud_2.colour]
						Graphics.CSurface.GL_DrawRect(
							room.rect.x, 
							room.rect.y,
							room.rect.w, 
							room.rect.h/2, 
							colour_outline)
						Graphics.CSurface.GL_DrawRect(
							room.rect.x+5, 
							room.rect.y+5,
							room.rect.w-10, 
							(room.rect.h/2)-5, 
							colour_outline_dark)
						Graphics.CSurface.GL_DrawRect(
							room.rect.x, 
							room.rect.y+(room.rect.h/2),
							room.rect.w, 
							(room.rect.h/2), 
							colour_outline_2)
						Graphics.CSurface.GL_DrawRect(
							room.rect.x+5, 
							room.rect.y+(room.rect.h/2),
							room.rect.w-10, 
							(room.rect.h/2)-5, 
							colour_outline_dark_2)
					else
						Graphics.CSurface.GL_DrawRect(
							room.rect.x, 
							room.rect.y,
							room.rect.w, 
							room.rect.h, 
							colour_outline)
						Graphics.CSurface.GL_DrawRect(
							room.rect.x+5, 
							room.rect.y+5,
							room.rect.w-10, 
							room.rect.h-10, 
							colour_outline_dark)
					end
					Graphics.CSurface.GL_SetStencilMode(0,1,1)
					Graphics.CSurface.GL_PopStencilMode()
				end
			end
		end
	end
	return Defines.Chain.CONTINUE 
end)
script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function(ship, experimental) return Defines.Chain.CONTINUE end, function(ship, experimental) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
		local root_room = (shipManager:HasAugmentation("UPG_OE_GROWTH_ROOT") > 0 and system.table.growth_root) or system.roomId
		local map = table_map[shipManager.iShipId]
		for room in vter(ship.vRoomList) do
			local room_map = map[room.iRoomId]
			local w = room_map.w
			local h = room_map.h
			if room.iRoomId == root_room then
				for i = 0, w - 1 do
					for j = 0, h - 1 do
						local x = room.rect.x + i * 35
						local y = room.rect.y + j * 35
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(x, y, 0)
						Graphics.CSurface.GL_RenderPrimitiveWithColor(IMAGE_ROOT, COLOUR_WHITE)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
				break
			end
		end
	end
	return Defines.Chain.CONTINUE 
end)

local baseImage = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_oe_growth_base.png", buttonOffset_x, buttonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local rootIcon = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_growth_root_icon.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local buttonIcon = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_growth_button_icon.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local boxImages = {
	arrow = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_arrow.png" , -7, 3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	top = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_top.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	bottom = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_bottom.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	left = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_left.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	right = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_right.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	top_left = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_top_left.png" , 4, 4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	top_right = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_top_right.png" , 0, 4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	bottom_left = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_bottom_left.png" , 4, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	bottom_right = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_bottom_right.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	middle = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/oe_grease_box_middle.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
}

local maxButtonWidth = 3
local boxButton_w = 22
local boxButton_h = 22
local function renderOptions(originPos_x, originPos_y, effectButtonTable)
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(originPos_x, originPos_y, 0)

	local activeEffectButtons = {}
	for i, effectButton in ipairs(effectButtonTable) do
		local currentEffect = bud_types[i]
		if (currentEffect.req and Hyperspace.ships.player:HasEquipment(currentEffect.req) > 0) or not currentEffect.req then
			table.insert(activeEffectButtons, effectButton)
			effectButton.index = i
			if active_target_bud == i or (currentEffect.count and currentEffect.count >= (currentEffect.max_count or 9999)) then
				effectButton.b.bActive = false
			else
				effectButton.b.bActive = true
			end
		else
			effectButton.b.bActive = false
		end
	end
	local boxNumber = #activeEffectButtons

	local boxWidthNumber = math.min(maxButtonWidth, boxNumber)
	local boxHeightNumber = math.ceil(boxNumber/maxButtonWidth)
	local boxWidth = boxButton_w * boxWidthNumber
	local boxHeight = boxButton_h * boxHeightNumber
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(-0.5 * boxWidth, -1 * boxHeight, 0)

	--Render Corners
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(-(boxButton_w/2), -(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.top_left)
	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(boxWidth-(boxButton_w/2), -(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.top_right)
	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(-(boxButton_w/2), boxHeight-(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.bottom_left)
	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(boxWidth-(boxButton_w/2), boxHeight-(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.bottom_right)
	Graphics.CSurface.GL_PopMatrix()

	if boxWidthNumber > 1 then
		for n = 1, boxWidthNumber - 1 do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-(boxButton_w/2)+boxButton_w*n, -(boxButton_h/2), 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.top)
			Graphics.CSurface.GL_PopMatrix()
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-(boxButton_w/2)+boxButton_w*n, boxHeight-(boxButton_h/2), 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.bottom)
			Graphics.CSurface.GL_PopMatrix()
			if boxHeightNumber > 1 then
				for m = 1, boxHeightNumber - 1 do
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(-(boxButton_w/2)+boxButton_w*n, -(boxButton_h/2)+boxButton_h*m, 0)
					Graphics.CSurface.GL_RenderPrimitive(boxImages.middle)
					Graphics.CSurface.GL_PopMatrix()
				end
			end
		end
	end
	if boxHeightNumber > 1 then
		for m = 1, boxHeightNumber - 1 do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-(boxButton_w/2), -(boxButton_h/2)+boxButton_h*m, 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.left)
			Graphics.CSurface.GL_PopMatrix()
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(boxWidth-(boxButton_w/2), -(boxButton_h/2)+boxButton_h*m, 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.right)
			Graphics.CSurface.GL_PopMatrix()
		end
	end

	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_RenderPrimitive(boxImages.arrow)
	Graphics.CSurface.GL_PopMatrix()
	for i = 1, boxNumber do
		if activeEffectButtons[i] then
			effectButton = activeEffectButtons[i]
			local buttonX = originPos_x - 0.5 * boxWidth + ((i - 1) % maxButtonWidth) * boxButton_w
			local buttonY = originPos_y - 1 * boxHeight + math.floor((i - 1) / maxButtonWidth) * boxButton_h
			effectButton.position = {x = buttonX, y = buttonY}
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(effectButton.position.x, effectButton.position.y, 0)
			effectButton.b:OnRender()
			local effect = bud_types[effectButton.index]
			local effectColour = flower_colour_list[effect.colour]
			if effect.name == "Root" then
				Graphics.CSurface.GL_RenderPrimitiveWithColor(rootIcon, effectColour)
			else
				Graphics.CSurface.GL_RenderPrimitiveWithColor(buttonIcon, effectColour)
			end
			Graphics.CSurface.GL_PopMatrix()
			if effectButton.b.bHover then
				Hyperspace.Mouse.bForceTooltip = true
				Hyperspace.Mouse:SetTooltip(effect.name.."\n"..effect.desc)
			end
		end
	end
end

local mouse_tooltip_string_hover = Hyperspace.Text:GetText("oe_lua_sys_growth_button_hover")
local mouse_tooltip_string_disabled_hover = Hyperspace.Text:GetText("oe_lua_sys_growth_button_disabled_hover")
local function system_render(systemBox, ignoreStatus)
	if is_system(systemBox) then
		local system = systemBox.pSystem
		local effectivePower = system:GetEffectivePower()
		local maxPower = system:GetMaxPower()
		local mousePos = Hyperspace.Mouse.position

		Graphics.CSurface.GL_RenderPrimitive(baseImage)

		local button = systemBox.table.button
		button.bActive = Hyperspace.App.gui.upgradeButton.bActive
		button:OnRender()
		buttonHover = button.bHover
		if button.bHover and button.bActive then
			Hyperspace.Mouse.bForceTooltip = true
			Hyperspace.Mouse:SetTooltip(string.format(mouse_tooltip_string_hover))
		elseif button.bHover then
			Hyperspace.Mouse.bForceTooltip = true
			Hyperspace.Mouse:SetTooltip(string.format(mouse_tooltip_string_disabled_hover))
		end
		local effectButtonTable = systemBox.table.effectButtonTable
		if button.bActive and displayOptions then
			renderOptions(buttonOffset_x + 20, buttonOffset_y+30, effectButtonTable)
		elseif displayOptions then
			displayOptions = false
			active_target_bud = false
		end
	end
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, 
function(systemBox, ignoreStatus) 
	return Defines.Chain.CONTINUE
end, system_render)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if active_target_bud then
		local gui = Hyperspace.App.gui
		gui.crewControl.selectedCrew:clear()
		gui.crewControl.potentialSelectedCrew:clear()
		if gui.crewControl.selectedDoor then
			gui.crewControl.selectedDoor._selectable.selectedState = 0
		end
		gui.crewControl.selectedDoor = nil
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y) 
	if active_target_bud and Hyperspace.App.gui.combatControl.selectedSelfRoom >= 0 then
		if bud_types[active_target_bud].name == "Root" then
			local system = Hyperspace.ships.player:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
			system.table.growth_root = Hyperspace.App.gui.combatControl.selectedSelfRoom
			active_target_bud = false
			Hyperspace.playerVariables[string.format(root_variable, 0)] = system.table.growth_root
		else
			if Hyperspace.ships.player:HasAugmentation("UPG_OE_GROWTH_EXTRA_BUD") > 0 then
				local current_index = table_bud_set_2[0][Hyperspace.App.gui.combatControl.selectedSelfRoom].index
				bud_types[current_index].count = bud_types[current_index].count - 1
				table_bud_set_2[0][Hyperspace.App.gui.combatControl.selectedSelfRoom].index = table_bud_set[0][Hyperspace.App.gui.combatControl.selectedSelfRoom].index
				table_bud_set[0][Hyperspace.App.gui.combatControl.selectedSelfRoom].index = active_target_bud
				bud_types[active_target_bud].count = bud_types[active_target_bud].count + 1
				if bud_types[active_target_bud].count and bud_types[active_target_bud].count >= (bud_types[active_target_bud].max_count or 9999) then
					active_target_bud = false
				end
			else
				local current_index = table_bud_set[0][Hyperspace.App.gui.combatControl.selectedSelfRoom].index
				bud_types[current_index].count = bud_types[current_index].count - 1
				table_bud_set[0][Hyperspace.App.gui.combatControl.selectedSelfRoom].index = active_target_bud
				bud_types[active_target_bud].count = bud_types[active_target_bud].count + 1
				if bud_types[active_target_bud].count and bud_types[active_target_bud].count >= (bud_types[active_target_bud].max_count or 9999) then
					active_target_bud = false
				end
			end
		end
	elseif active_target_bud then
		active_target_bud = false
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y) 
	if active_target_bud then
		active_target_bud = false
	end
	return Defines.Chain.CONTINUE
end)

local floral_buff = Hyperspace.Animations:GetAnimation("spores_buff")
floral_buff.position.x = -floral_buff.info.frameWidth/2
floral_buff.position.y = -floral_buff.info.frameHeight/2
floral_buff.tracker.loop = true
floral_buff:Start(true)
local vampweed_buff = Hyperspace.Animations:GetAnimation("spores_debuff")
vampweed_buff.position.x = -vampweed_buff.info.frameWidth/2
vampweed_buff.position.y = -vampweed_buff.info.frameHeight/2
vampweed_buff.tracker.loop = true
vampweed_buff:Start(true)
local praetor_buff = Hyperspace.Animations:GetAnimation("spores_buff_elite")
praetor_buff.position.x = -praetor_buff.info.frameWidth/2
praetor_buff.position.y = -praetor_buff.info.frameHeight/2
praetor_buff.tracker.loop = true
praetor_buff:Start(true)
local cultivator = Hyperspace.Animations:GetAnimation("spores_debuff_elite")
cultivator.position.x = -cultivator.info.frameWidth/2
cultivator.position.y = -cultivator.info.frameHeight/2
cultivator.tracker.loop = true
cultivator:Start(true)
local suffocating = Hyperspace.Animations:GetAnimation("spores_oe_suffocating_debuff")
suffocating.position.x = -suffocating.info.frameWidth/2
suffocating.position.y = -suffocating.info.frameHeight/2
suffocating.tracker.loop = true
suffocating:Start(true)

script.on_render_event(Defines.RenderEvents.CREW_MEMBER_HEALTH, function(crewmem)
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) and table_bud_set[shipManager.iShipId][crewmem.iRoomId].active then
		local active_bud_index = table_bud_set[shipManager.iShipId][crewmem.iRoomId].index
		local active_bud = bud_types[active_bud_index]
		local position = crewmem:GetPosition()
		local boarder = crewmem.iShipId ~= crewmem.currentShipId
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(position.x, position.y, 0)
		if active_bud.name == "Floral" and not boarder then
			floral_buff:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Vampweed" and boarder then
			vampweed_buff:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Praetor" and not boarder then
			praetor_buff:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Cultivator" and boarder then
			cultivator:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Suffocating" and boarder then
			suffocating:OnRender(1, COLOUR_WHITE, false)
		end
		Graphics.CSurface.GL_PopMatrix()
	end
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].active then
		local active_bud_index = table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].index
		local active_bud = bud_types[active_bud_index]
		local position = crewmem:GetPosition()
		local boarder = crewmem.iShipId ~= crewmem.currentShipId
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(position.x, position.y, 0)
		if active_bud.name == "Floral" and not boarder then
			floral_buff:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Vampweed" and boarder then
			vampweed_buff:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Praetor" and not boarder then
			praetor_buff:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Cultivator" and boarder then
			cultivator:OnRender(1, COLOUR_WHITE, false)
		elseif active_bud.name == "Suffocating" and boarder then
			suffocating:OnRender(1, COLOUR_WHITE, false)
		end
		Graphics.CSurface.GL_PopMatrix()
	end
	return Defines.Chain.CONTINUE
end, function() return Defines.Chain.CONTINUE end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 then
		floral_buff:Update()
		vampweed_buff:Update()
		praetor_buff:Update()
		cultivator:Update()
		suffocating:Update()
	end
end)

local crewTarget = {
	ALLIES = 1,
	ENEMIES = -1,
	ALL = 0,
}

local stat_effect_table = {}
stat_effect_table["Floral"] = {
	[Hyperspace.CrewStat.MAX_HEALTH] = {type = crewTarget.ALLIES, mult = 1.2},
	[Hyperspace.CrewStat.REPAIR_SPEED_MULTIPLIER] = {type = crewTarget.ALLIES, mult = 1.2},
	[Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER] = {type = crewTarget.ALLIES, mult = 1.2},
}
stat_effect_table["Vampweed"] = {
	[Hyperspace.CrewStat.MAX_HEALTH] = {type = crewTarget.ENEMIES, mult = 0.85}, 
	[Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER] = {type = crewTarget.ENEMIES, mult = 0.75},
}
stat_effect_table["Praetor"] = {
	[Hyperspace.CrewStat.MAX_HEALTH] = {type = crewTarget.ALLIES, mult = 2},
	[Hyperspace.CrewStat.REPAIR_SPEED_MULTIPLIER] = {type = crewTarget.ALLIES, mult = 2},
	[Hyperspace.CrewStat.BONUS_POWER] = {type = crewTarget.ALLIES, mult = 2},
}
stat_effect_table["Cultivator"] = {
	[Hyperspace.CrewStat.ALL_DAMAGE_TAKEN_MULTIPLIER] = {type = crewTarget.ENEMIES, mult = 1.6}, 
	[Hyperspace.CrewStat.STUN_MULTIPLIER] = {type = crewTarget.ENEMIES, mult = 1.5},
	[Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER] = {type = crewTarget.ENEMIES, mult = 0.75},
}
stat_effect_table["Suffocating"] = {
	[Hyperspace.CrewStat.SUFFOCATION_MODIFIER] = {type = crewTarget.ENEMIES, mult = 1.5}, 
}

script.on_internal_event(Defines.InternalEvents.CALCULATE_STAT_POST, function(crewmem, stat, def, amount, value)
	if not (crewmem and crewmem.currentShipId and crewmem.currentShipId >= 0 and crewmem.iRoomId) then return Defines.Chain.CONTINUE, amount, value end
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	if shipManager and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) and table_bud_set[shipManager.iShipId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId].active then
		local active_bud_index = table_bud_set[shipManager.iShipId][crewmem.iRoomId].index
		local active_bud = bud_types[active_bud_index]
		local stat_table = stat_effect_table[active_bud.name] and stat_effect_table[active_bud.name][stat]
		if stat_table and ((stat_table.type >= crewTarget.ALL and crewmem.iShipId == crewmem.currentShipId) or
						(stat_table.type <= crewTarget.ALL and crewmem.iShipId ~= crewmem.currentShipId)) then
			if stat_table.mult then
				amount = amount * stat_table.mult
			elseif stat_table.add then
				amount = amount + stat_table.add
			end
		end
	end	
	if shipManager and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) and table_bud_set_2[shipManager.iShipId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].active then
		local active_bud_index = table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].index
		local active_bud = bud_types[active_bud_index]
		local stat_table = stat_effect_table[active_bud.name] and stat_effect_table[active_bud.name][stat]
		if stat_table and ((stat_table.type >= crewTarget.ALL and crewmem.iShipId == crewmem.currentShipId) or
						(stat_table.type <= crewTarget.ALL and crewmem.iShipId ~= crewmem.currentShipId)) then
			if stat_table.mult then
				amount = amount * stat_table.mult
			elseif stat_table.add then
				amount = amount + stat_table.add
			end
		end
	end	
	return Defines.Chain.CONTINUE, amount, value
end)

local defNOMOVE = Hyperspace.StatBoostDefinition()
defNOMOVE.stat = Hyperspace.CrewStat.CAN_MOVE
defNOMOVE.value = false
defNOMOVE.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOMOVE.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOMOVE.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOMOVE.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOMOVE.duration = 1
defNOMOVE.priority = 9999
defNOMOVE.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOMOVE)

local defNOMOVESPEED = Hyperspace.StatBoostDefinition()
defNOMOVESPEED.stat = Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER
defNOMOVESPEED.amount = 0
defNOMOVESPEED.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOMOVESPEED.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOMOVESPEED.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOMOVESPEED.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOMOVESPEED.duration = 1
defNOMOVESPEED.boostAnim = "oe_growth_root"
defNOMOVESPEED.priority = 9999
defNOMOVESPEED.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOMOVESPEED)

local defROOTDAMAGE = Hyperspace.StatBoostDefinition()
defROOTDAMAGE.stat = Hyperspace.CrewStat.TRUE_HEAL_AMOUNT 
defROOTDAMAGE.amount = -15
defROOTDAMAGE.boostType = Hyperspace.StatBoostDefinition.BoostType.ADD
defROOTDAMAGE.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defROOTDAMAGE.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defROOTDAMAGE.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defROOTDAMAGE.duration = 1
defROOTDAMAGE.priority = 9999
defROOTDAMAGE.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defROOTDAMAGE)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	if not (crewmem and crewmem.currentShipId and crewmem.currentShipId >= 0 and crewmem.iRoomId) then return  end
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	if shipManager and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local bud_1_exists = table_bud_set[shipManager.iShipId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId].active and table_bud_set[shipManager.iShipId][crewmem.iRoomId].index == bud_types_indexed["Entangling"]
		local bud_2_exists = table_bud_set_2[shipManager.iShipId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].active and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].index == bud_types_indexed["Entangling"]
		if (not crewmem:AtFinalGoal()) and (bud_1_exists or bud_2_exists) and crewmem.iShipId ~= crewmem.currentShipId then
			if not crewmem.table.oe_growth_root_timer then
				crewmem.table.oe_growth_root_timer = 0
			end
			crewmem.table.oe_growth_root_timer = crewmem.table.oe_growth_root_timer - time_increment(true)
			if crewmem.table.oe_growth_root_timer <= 0 then
				crewmem.table.oe_growth_root_timer = 1.5
				--Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOMOVE), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOMOVESPEED), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defROOTDAMAGE), crewmem)
			end
		elseif crewmem.table.oe_growth_root_timer and not (bud_1_exists or bud_2_exists) then
			crewmem.table.oe_growth_root_timer = nil
		end	
	end
end)

script.on_internal_event(Defines.InternalEvents.SET_BONUS_POWER, function(system, amount)
	local shipManager = Hyperspace.ships(system._shipObj.iShipId)
	if shipManager and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local bud_1_exists = table_bud_set[shipManager.iShipId] and table_bud_set[shipManager.iShipId][system.roomId] and table_bud_set[shipManager.iShipId][system.roomId].active and table_bud_set[shipManager.iShipId][system.roomId].index == bud_types_indexed["Electrified"]
		local bud_2_exists = table_bud_set_2[shipManager.iShipId] and table_bud_set_2[shipManager.iShipId][system.roomId] and table_bud_set_2[shipManager.iShipId][system.roomId].active and table_bud_set_2[shipManager.iShipId][system.roomId].index == bud_types_indexed["Electrified"]
		if bud_1_exists then
			amount = amount + 1 
		elseif bud_2_exists then
			amount = amount + 1
		end	
	end
	return Defines.Chain.CONTINUE, amount
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local otherManager = Hyperspace.ships(1 - shipManager.iShipId)
	if otherManager and otherManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) and shipManager:HasSystem(15) then
		local system = shipManager.hackingSystem.currentSystem
		if system and shipManager.hackingSystem.effectTimer.first >= shipManager.hackingSystem.effectTimer.second then
			local bud_1_exists = table_bud_set[otherManager.iShipId] and table_bud_set[otherManager.iShipId][system.roomId] and table_bud_set[otherManager.iShipId][system.roomId].active and table_bud_set[otherManager.iShipId][system.roomId].index == bud_types_indexed["Electrified"]
			local bud_2_exists = table_bud_set_2[otherManager.iShipId] and table_bud_set_2[otherManager.iShipId][system.roomId] and table_bud_set_2[otherManager.iShipId][system.roomId].active and table_bud_set_2[otherManager.iShipId][system.roomId].index == bud_types_indexed["Electrified"]
			if bud_1_exists or bud_2_exists then
				shipManager.hackingSystem:BlowHackingDrone()
			end
		end
	end
end)

local acidic_ships = {
	"PLAYER_SHIP_OE_ACID_ARTY",
	"PLAYER_SHIP_OE_ACID_ARTY_2",
	"PLAYER_SHIP_OE_ACID_LONG",
	"PLAYER_SHIP_OE_ACID_LONG_2",
	"PLAYER_SHIP_OE_ACID_LONG_3",
	"PLAYER_SHIP_OE_ACID_CREW1",
	"OET_BOSS_ACID_NORMAL",
	"OET_BOSS_ACID_CHALLENGE",
	"OET_BOSS_ACID_EXTREME",
	"OET_BOSS_ACID_CHAOS",
	"OE_ACID_CEALAFORMER",
}
for name in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_SHIPS_OE_ACID_ALL")) do
	table.insert(acidic_ships, name) 
end
for name in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_SHIPS_OE_ACID_ELITE_ALL")) do
	table.insert(acidic_ships, name)
end
for _, blueprintName in ipairs(acidic_ships) do
	acidic_ships_check[blueprintName] = true
end

--[[for _, blueprintName in ipairs(acidic_ships) do
	acidic_ships_check[blueprintName] = true
	local blueprint = Hyperspace.Blueprints:GetShipBlueprint(blueprintName, 0)
	local i = -1
	for systemId in vter(blueprint.systems) do
		i = i + 1
		if systemId == 2 then
			blueprint.systems[i] = Hyperspace.ShipSystem.NameToSystemId(systemName)
		end
	end
	--[[if not string_starts(blueprint.blueprintName, "PLAYER_SHIP") then
		local sysInfo = blueprint.systemInfo
		if sysInfo:has_key(2) then
			if sysInfo[2].systemId == 2 then
				local swapId = Hyperspace.ShipSystem.NameToSystemId(systemName)
				sysInfo[swapId] = sysInfo[2]
				sysInfo[swapId].systemId = swapId
				sysInfo:del(2)
			end
		end
	end]]
--end]]

local bud_lock = Hyperspace.CustomLockdownDefinition()
bud_lock.duration = 5
bud_lock.health = 4
bud_lock.anims:clear()
bud_lock.anims:push_back("oe_growth_lockdown1")
bud_lock.anims:push_back("oe_growth_lockdown2")

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	if not (crewmem and crewmem.currentShipId and crewmem.currentShipId >= 0 and crewmem.iRoomId) then return  end
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	if shipManager and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local bud_1_exists = table_bud_set[shipManager.iShipId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId].active and table_bud_set[shipManager.iShipId][crewmem.iRoomId].index == bud_types_indexed["Trapping"]
		local bud_2_exists = table_bud_set_2[shipManager.iShipId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].active and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].index == bud_types_indexed["Trapping"]
		if bud_1_exists and crewmem.iShipId ~= crewmem.currentShipId then
			local bud = table_bud[shipManager.iShipId][crewmem.iRoomId]
			if (not shipManager.ship:RoomLocked(crewmem.iRoomId)) and table_growth[shipManager.iShipId][crewmem.iRoomId][bud.i][bud.j].val > 99 then
				table_growth[shipManager.iShipId][crewmem.iRoomId][bud.i][bud.j].val = 51
				local point = Hyperspace.Pointf(crewmem:GetPosition().x, crewmem:GetPosition().y)
				shipManager.ship:LockdownRoom(crewmem.iRoomId, point, bud_lock)
			end
		end
		if bud_2_exists and crewmem.iShipId ~= crewmem.currentShipId then
			local bud = table_bud_2[shipManager.iShipId][crewmem.iRoomId]
			if (not shipManager.ship:RoomLocked(crewmem.iRoomId)) and table_growth[shipManager.iShipId][crewmem.iRoomId][bud.i][bud.j].val > 99 then
				table_growth[shipManager.iShipId][crewmem.iRoomId][bud.i][bud.j].val = 51
				local point = Hyperspace.Pointf(crewmem:GetPosition().x, crewmem:GetPosition().y)
				shipManager.ship:LockdownRoom(crewmem.iRoomId, point, bud_lock)
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.ship.lockdowns:size() > 0 then
		for shard in vter(shipManager.ship:GetShards()) do
			if shard.lifeTime < 0 and not shard.bArrived then
				shard.bArrived = true
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	if not (crewmem and crewmem.currentShipId and crewmem.currentShipId >= 0 and crewmem.iRoomId) then return  end
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	if crewmem.table.oe_growth_dd_soulplague_timer then crewmem.table.oe_growth_dd_soulplague_timer = crewmem.table.oe_growth_dd_soulplague_timer - time_increment(true) end
	if shipManager and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local bud_1_exists = table_bud_set[shipManager.iShipId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId] and table_bud_set[shipManager.iShipId][crewmem.iRoomId].active and table_bud_set[shipManager.iShipId][crewmem.iRoomId].index == bud_types_indexed["Soulplagued"]
		local bud_2_exists = table_bud_set_2[shipManager.iShipId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId] and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].active and table_bud_set_2[shipManager.iShipId][crewmem.iRoomId].index == bud_types_indexed["Soulplagued"]
		if (bud_1_exists or bud_2_exists) and crewmem.iShipId ~= crewmem.currentShipId then
			if not crewmem.table.oe_growth_dd_soulplague_timer then
				crewmem.table.oe_growth_dd_soulplague_timer = 0
			end
			if crewmem.table.oe_growth_dd_soulplague_timer <= 0 then
				crewmem.table.oe_growth_dd_soulplague_timer = 15
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_REPAIR"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_HEAL"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_1"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_2"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_3"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_4"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_5"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_6"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_7"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_8"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_9"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_10"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_11"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_12"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_13"]), crewmem)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(Hyperspace.StatBoostDefinition.savedStatBoostDefs["OE_DD_SOULPLAGUE_DEATH_14"]), crewmem)
			end
		elseif crewmem.table.oe_growth_dd_soulplague_timer and crewmem.table.oe_growth_dd_soulplague_timer <= 0 then
			crewmem.table.oe_growth_dd_soulplague_timer = nil
		end	
	end
end)