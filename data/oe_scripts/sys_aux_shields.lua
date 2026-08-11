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

local systemName = "oe_aux_shields"
mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(systemName)] = mods.multiverse.register_system_icon(systemName)

charge_time_base = 8
charge_time_scaler = 0.5

local boost_duration_base = 5
local boost_duration_add = 5
local boost_charge_time = 0.5

local layers_base = 3
local layers_scaler = 0

local level_string = Hyperspace.Text:GetText("oe_lua_sys_aux_shields")
local function get_level_description_system(systemId, level, tooltip)
	if systemId == Hyperspace.ShipSystem.NameToSystemId(systemName) then
		return string.format(level_string, (boost_duration_base + (boost_duration_add * (level - 1))), (1 + (charge_time_scaler * (level - 1))) )
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

local buttonOffset_x = 37
local buttonOffset_y = -37
local function construct_system_box(systemBox)
	if is_system(systemBox) then
		systemBox.extend.xOffset = 54

		local button_list = {}
		for i = 1, 4 do
			local button = Hyperspace.Button()
			local image = string.format("systemUI/button_cloaking%i", i)
			button:OnInit(image, Hyperspace.Point(buttonOffset_x, buttonOffset_y))
			button.hitbox.x = 10
			button.hitbox.y = 11 + 12 * (i - 1)
			button.hitbox.w = 20
			button.hitbox.h = 55 - 12 * (i - 1)
			button_list[i] = button
		end
		systemBox.table.button_list = button_list
		systemBox.table.button_list[0] = systemBox.table.button_list[1]
	end
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, construct_system_box)

local function mouse_move(systemBox, x, y)
	if is_equaliser(systemBox) then
		local button = systemBox.table.button_list[systemBox.pSystem:GetEffectivePower()]
		button:MouseMove(x - buttonOffset_x, y - buttonOffset_y, false)
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, mouse_move)

local function mouse_click(systemBox, shift)
	if is_equaliser(systemBox) then
		local button = systemBox.table.button_list[systemBox.pSystem:GetEffectivePower()]
		if button.bHover and button.bActive then
			--Activate
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, mouse_click)

local COLOUR_WHITE = Graphics.GL_Color(1, 1, 1, 1)

local button_back = {
	[0] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_base.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[1] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_base.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[2] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking2_base.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[3] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking3_base.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[4] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking4_base.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
}

local button_active_on = {
	[0] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_on.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[1] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_on.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[2] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking2_charging_on.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[3] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking3_charging_on.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[4] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking4_charging_on.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
}

local button_active_off = {
	[0] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_off.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[1] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_off.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[2] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking2_charging_off.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[3] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking3_charging_off.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
	[4] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking4_charging_off.png", 0, 0, 0, COLOUR_WHITE, 1.0, false),
}

local function system_ready(shipSystem)
	return not (shipSystem:GetLocked() and shipSystem.iLockCount ~= -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end