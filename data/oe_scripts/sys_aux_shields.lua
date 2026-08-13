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

local charge_time_base = 8
local charge_time_scaler = 0.5

local boost_duration_base = 5
local boost_duration_add = 5
local boost_charge_time = 0.5
local boost_cooldown = 4

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
local buttonOffset_y = -50
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

		systemBox.pSystem.table.charge_time = 0
		systemBox.pSystem.table.boost_active = false
	end
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, construct_system_box)

local function mouse_move(systemBox, x, y)
	if is_system(systemBox) then
		local button = systemBox.table.button_list[systemBox.pSystem:GetEffectivePower()]
		button:MouseMove(x - buttonOffset_x, y - buttonOffset_y, false)
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, mouse_move)

local function system_activate(system)
	system.table.boost_active = 1
	system:LockSystem(-1)
end

local function mouse_click(systemBox, shift)
	if is_system(systemBox) then
		local button = systemBox.table.button_list[systemBox.pSystem:GetEffectivePower()]
		if button.bHover and button.bActive then
			system_activate(systemBox.pSystem)
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, mouse_click)

local function key_down(systemBox, key, shift)
	if key == Hyperspace.Settings:GetHotkey("activate_cloak") and is_system(systemBox) then
		local button = systemBox.table.button_list[systemBox.pSystem:GetEffectivePower()]
		if button.bHover and button.bActive then
			system_activate(systemBox.pSystem)
		end
	end
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_KEY_DOWN, key_down)

local COLOUR_WHITE = Graphics.GL_Color(1, 1, 1, 1)

local button_back = {
	[0] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_base.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[1] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_base.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[2] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking2_base.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[3] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking3_base.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[4] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking4_base.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
}

local button_active_on = {
	[0] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_on.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[1] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_on.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[2] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking2_charging_on.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[3] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking3_charging_on.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[4] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking4_charging_on.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
}

local button_active_off = {
	[0] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_off.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[1] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking1_charging_off.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[2] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking2_charging_off.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[3] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking3_charging_off.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
	[4] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_cloaking4_charging_off.png", buttonOffset_x, buttonOffset_y, 0, COLOUR_WHITE, 1.0, false),
}

local function system_ready(shipSystem)
	return ((not shipSystem:GetLocked()) or shipSystem.iLockCount == -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end


local boost_string = Hyperspace.Text:GetText("oe_lua_sys_aux_shields_boost")
local function system_render(systemBox, ignoreStatus)
	if is_system(systemBox) then
		for i = 1, 4 do
			systemBox.table.button_list[i].bActive = false
		end
		local power = systemBox.pSystem:GetEffectivePower()
		Graphics.CSurface.GL_RenderPrimitive(button_back[power])
		if system_ready(systemBox.pSystem) and systemBox.pSystem.iLockCount ~= -1 then
			local button = systemBox.table.button_list[systemBox.pSystem:GetEffectivePower()]
			button.bActive = true
			if button.bHover then
				local button_keybind = Hyperspace.Settings:GetHotkeyName("activate_cloak")
				Hyperspace.Mouse.bForceTooltip = true
				Hyperspace.Mouse:SetTooltip(string.format(boost_string, (boost_cooldown * 5)), button_keybind)
			end
			button:OnRender()
		elseif system_ready(systemBox.pSystem) and systemBox.pSystem.iLockCount == -1 then
			local boost_value = systemBox.pSystem.table.boost_active
			--local boost_duration = boost_duration_base + (boost_duration_add * (power - 1))
			local height = math.ceil(boost_value * (5 + 3 * (power - 1))) * 4
			Graphics.CSurface.GL_SetStencilMode(1,1,1)
			Graphics.CSurface.GL_DrawRect(
				buttonOffset_x + 10, 
				buttonOffset_y + 11 + (56 - height),
				20, 
				height, 
				COLOUR_WHITE)
			Graphics.CSurface.GL_SetStencilMode(2,1,1)
			Graphics.CSurface.GL_RenderPrimitive(button_active_on[power])
			Graphics.CSurface.GL_SetStencilMode(0,1,1)
		else
			local button = systemBox.table.button_list[systemBox.pSystem:GetEffectivePower()]
			button:OnRender()
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, 
function(systemBox, ignoreStatus) 
	return Defines.Chain.CONTINUE
end, system_render)


local shield_ui = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/top_oe_aux_on.png", 25, 86, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local shield_ui_off = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/top_oe_aux_off.png", 25, 86, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
script.on_render_event(Defines.RenderEvents.SPACE_STATUS, function() end, function()
	if Hyperspace.ships.player:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		if Hyperspace.ships.player.shieldSystem.shields.power.second == 0 then
			Graphics.CSurface.GL_RenderPrimitive(shield_ui_off)
		else
			Graphics.CSurface.GL_RenderPrimitive(shield_ui)
		end
		local system = Hyperspace.ships.player:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
		Graphics.CSurface.GL_DrawRect(25+7, 87+2, (system.table.charge_time or 0) * 94, 4, Graphics.GL_Color(1, 1, 1, 1))
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
		local manningCrew = system.table.manningCrew
		if system.bManned then
			if not manningCrew then
				for crew in vter(shipManager.vCrewList) do
					if crew.bActiveManning and tostring(crew.currentSystem) == tostring(system) then
						system.iActiveManned = crew:GetSkillLevel(2)
						manningCrew = crew
						system.table.manningCrew = crew
						break
					end
				end
			elseif not (manningCrew.bActiveManning and tostring(manningCrew.currentSystem) == tostring(system)) then
				system.table.manningCrew = nil
				manningCrew = nil
			end
		elseif manningCrew then
			system.table.manningCrew = nil
			manningCrew = nil
		end


		local power = system:GetEffectivePower()
		local charge_time = charge_time_base + charge_time_scaler * (power - 1)

		if system.table.boost_active and system_ready(system) then
			charge_time = boost_charge_time
			local boost_duration = boost_duration_base + (boost_duration_add * (power - 1))
			system.table.boost_active = system.table.boost_active - (time_increment(true)/boost_duration)
			if system.table.boost_active <= 0 then
				system.table.boost_active = false
				system:LockSystem(boost_cooldown)
			end 
		elseif system.table.boost_active then
			system.table.boost_active = false
			system:LockSystem(boost_cooldown)
		elseif power > 0 then
			charge_time = charge_time / (1 + charge_time_scaler * (power - 1))
		end

		local maxLayers = layers_base
		if shipManager:HasAugmentation("UPG_OE_AUX_SHIELD_CAPACITY") > 0 then maxLayers = false end

		if system_ready(system) and shipManager.shieldSystem.shields.power.super.first < (maxLayers or math.max(shipManager.shieldSystem.shields.power.super.second, 5)) then
			local charge_mult = 1
			if system.bManned then
				charge_mult = charge_mult + system.iActiveManned * 0.1
			end
			if shipManager:HasSystem(0) and shipManager:GetSystem(0).bManned and shipManager:GetAugmentationValue("UPG_OE_AUX_SHIELD_LINKER") > 0 then 
				local manning_level = shipManager:GetSystem(0).iActiveManned
				local linker_value = shipManager:GetAugmentationValue("UPG_OE_AUX_SHIELD_LINKER")
				charge_mult = charge_mult + manning_level * 0.1 * linker_value
			end
			charge_time = charge_time / charge_mult

			system.table.charge_time = (system.table.charge_time or 0) + time_increment(true)/charge_time
			if system.table.charge_time >= 1 then
				system.table.charge_time = 0
				shipManager.shieldSystem:AddSuperShield(shipManager.shieldSystem.superUpLoc)
				if manningCrew and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
					manningCrew:IncreaseSkill(2)
				end
			end
		elseif (system.table.charge_time or 0) > 0 then
			system.table.charge_time = math.max(0, (system.table.charge_time or 0) - time_increment(true)*2)
		end
	end
end)


script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
	local systemId = Hyperspace.ShipSystem.NameToSystemId(systemName)
	if shipManager and augName == "SHIELD_RECHARGE" and shipManager:HasSystem(systemId) and shipManager:GetSystem(systemId).bManned and shipManager:GetAugmentationValue("UPG_OE_AUX_SHIELD_LINKER") > 0 then
		local manning_level = shipManager:GetSystem(systemId).iActiveManned
		local linker_value = shipManager:GetAugmentationValue("UPG_OE_AUX_SHIELD_LINKER")
		augValue = augValue + manning_level * 0.1 * linker_value
	end
	return Defines.Chain.CONTINUE, augValue
end, -100)