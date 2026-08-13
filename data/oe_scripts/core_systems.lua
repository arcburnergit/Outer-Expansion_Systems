local mod_name = "Outer Expansion: Acidic Growth"
if not mods.oe then
	error("Outer Expansion: Core not detected, please ensure it is present in the mod list and patched before "..mod_name.."!")
else
	mods.oe.acid = {}
end

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

local usedFTLman = false
for _, file in ipairs(mods.multiverse.blueprintFiles) do
	local doc = RapidXML.xml_document(file)
	for node in node_child_iter(doc:first_node("FTL") or doc) do
		if node:name() == "usedFTLman" then
			usedFTLman = true
		end
	end
	doc:clear()
end
script.on_render_event(Defines.RenderEvents.MAIN_MENU, function() end, function()
    local menu = Hyperspace.Global.GetInstance():GetCApp().menu
    if menu.shipBuilder.bOpen or usedFTLman then
        return
    end
    Graphics.CSurface.GL_DrawRect(15, 540, 340, 165, Graphics.GL_Color(0, 0, 0, 0.8))
    Graphics.freetype.easy_print(10, 20, 545, "WARNING: It is recommended you use FTLman \ninstead of slipstream to patch your addons.")
    Graphics.freetype.easy_print(10, 20, 590, "This will enable The Outer Expansion to \ngive it's custom systems to ships.")
    Graphics.freetype.easy_print(10, 20, 635, "FTLman can be found here: \nhttps://github.com/afishhh/ftlman/releases/latest\nThis is completely optional, if you're not \ncomfortable switching, ignore this message.")
end)