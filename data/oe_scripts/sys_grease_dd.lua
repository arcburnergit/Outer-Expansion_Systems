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

local get_adjacent_rooms = mods.multiverse.get_adjacent_rooms


local soulplagueName = "OE_GREASE_EFFECT_BOMB_DD_SOULPLAGUE"
local soulplagueBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(soulplagueName)

function mods.oe.spawn_soulplague(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_soulplague")
	local spaceManager = Hyperspace.App.world.space
	spaceManager:CreateLaserBlast(
		soulplagueBlueprint,
		location,
		projectile.currentSpace,
		projectile.ownerId,
		location,
		projectile.destinationSpace,
		projectile.heading)
end
local spawn_soulplague = mods.oe.spawn_soulplague

local randomDarknessCrew = {}
for crew in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_DDDARK_OBELISK_ENTITIES")) do
    table.insert(randomDarknessCrew, crew)
end

function mods.oe.spawn_darkness(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_darkness")
	local random = math.random(6)
	if random <= 1 then
		mods.oe.spawn_fire(shipManager, projectile, location, damage, shipFriendlyFire)
	elseif random <= 2 then
		mods.oe.spawn_breach(shipManager, projectile, location, damage, shipFriendlyFire)
	else
		local crewId = randomDarknessCrew[math.random(#randomDarknessCrew)]
		local intruder = not (shipManager.iShipId == projectile.ownerId)
		local room = get_room_at_location(shipManager, location, true)
		local crew = shipManager:AddCrewMemberFromString("Voidborn", crewId, intruder, room, true, true)
		crew.extend.deathTimer = Hyperspace.TimerHelper(false)
    	crew.extend.deathTimer:Start(30)
	end
end
local spawn_darkness = mods.oe.spawn_darkness

local shadowName = "OE_GREASE_EFFECT_BOMB_DD_SHADOW"
local shadowBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(shadowName)

function mods.oe.spawn_shadow(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_shadow")
	local spaceManager = Hyperspace.App.world.space
	spaceManager:CreateLaserBlast(
		shadowBlueprint,
		location,
		projectile.currentSpace,
		projectile.ownerId,
		location,
		projectile.destinationSpace,
		projectile.heading)
end
local spawn_shadow = mods.oe.spawn_shadow

local radiantName = "OE_GREASE_EFFECT_BOMB_DD_RADIANT"
local radiantBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(radiantName)

function mods.oe.spawn_radiant(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_radiant")
	local spaceManager = Hyperspace.App.world.space
	spaceManager:CreateLaserBlast(
		radiantBlueprint,
		location,
		projectile.currentSpace,
		projectile.ownerId,
		location,
		projectile.destinationSpace,
		projectile.heading)
end
local spawn_radiant = mods.oe.spawn_radiant