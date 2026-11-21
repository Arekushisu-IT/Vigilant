class_name HomeBuilder
extends LocationBuilder
## The player's condo in General Santos (Chapters 3 and 5, Objective 1): a 6 x 5 m studio with a 2.6 m ceiling.
## The entrance door is in the south wall and a sliding balcony door (GenSan skyline and Mt. Matutum outside) in the
## north wall. Sofa and TV, a bed in the corner, a kitchenette with the rice cooker, and the dining table by the
## window with the player's smartphone on it: the only device here (`phone`, device_id "phone"). No other people.
## Room: x -3..3, z -2.5..2.5, floor at y 0, ceiling at y 2.6. Low-poly models from build_assets.py.

const ROOM_W := 6.0
const ROOM_D := 5.0
const ROOM_H := 2.6
const TABLE := Vector3(1.2, 0.0, -1.45)          ## dining table centre (by the balcony door)
const TABLE_TOP_Y := 0.75
const PHONE_SPOT := Vector3(1.2, 0.75, -1.25)    ## the smartphone, on the player's side of the table
const SPAWN := Vector3(1.2, 0.0, -0.5)           ## where the player stands, facing the phone

const C_WALL := Color("ece4d6")
const C_WALL_ACCENT := Color("c8d6cf")
const C_SKIRTING := Color("8a6a4e")
const C_CEILING := Color("f6f3ec")
const C_FLOOR := Color("b98a5e")
const C_FLOOR_ALT := Color("b07f55")
const C_FLOOR_GROUT := Color("94683f")
const C_RUG := Color("8c4a3c")
const C_RUG_BORDER := Color("e0c48a")

## Home moods (Monday 7:30 PM and Tuesday 8:00 PM): night views through the balcony door, warm lamps inside.
## Keys: environment and sun (as in the office), ceiling lamp (ceiling, ceiling_e; 0 = off), floor lamp (lamp,
## lamp_e), kitchen light (kitchen_e), ceiling diffuser (panel, panel_e), lamp bulbs (bulb_e), TV (tv_e), the
## phone screen's idle glow (phone_e), the window view (night palette) and the wall clock (clock, hours).
const MOODS: Dictionary = {
	"home_evening": {   # Monday evening: purple-blue sky over the city, the ceiling lamp on
		"bg": Color("1c1b33"), "ambient": Color("a197c4"), "ambient_e": 0.34, "glow": 0.35,
		"sun": Color("9a86d8"), "sun_e": 0.14, "sun_rot": Vector3(-14.0, 160.0, 0.0),
		"ceiling": Color("ffe2bd"), "ceiling_e": 1.0, "panel": Color("fff0d6"), "panel_e": 1.4,
		"lamp": Color("ffc98a"), "lamp_e": 0.9, "kitchen_e": 0.5, "bulb_e": 3.0, "tv_e": 0.6, "phone_e": 0.7,
		"view": "night", "night_sky": Color("2a2d6a"), "night_hor": Color("9a5f9e"), "night_mtn": Color("2a2350"),
		"night_sea": Color("2c2a5a"), "city": Color("2b2a4c"), "ground": Color("201e3a"), "lights_e": 3.0,
		"clock": 19.5,
	},
	"home_night": {     # Tuesday night: darker, the ceiling lamp off, the floor lamp and the TV carry the room
		"bg": Color("0d1022"), "ambient": Color("4b538a"), "ambient_e": 0.3, "glow": 0.55,
		"sun": Color("5a6ab8"), "sun_e": 0.08, "sun_rot": Vector3(-30.0, 150.0, 0.0),
		"ceiling": Color("ffe2bd"), "ceiling_e": 0.0, "panel": Color("8a8a9a"), "panel_e": 0.12,
		"lamp": Color("ffbf78"), "lamp_e": 1.6, "kitchen_e": 0.35, "bulb_e": 4.0, "tv_e": 1.0, "phone_e": 0.9,
		"view": "night", "night_sky": Color("0b1230"), "night_hor": Color("262a5a"), "night_mtn": Color("141a33"),
		"night_sea": Color("0e1c33"), "city": Color("171c33"), "ground": Color("10142a"), "lights_e": 4.0,
		"clock": 20.0,
	},
}

var _ceiling_light: OmniLight3D
var _floor_light: OmniLight3D
var _kitchen_light: OmniLight3D
var _panel_mat: StandardMaterial3D
var _tv_mat: StandardMaterial3D


func _init() -> void:
	location = "home"


func _ready() -> void:
	_build_roots()
	_build_environment()
	_build_lights()
	_build_room()
	_build_dining()
	_build_living()
	_build_bed_corner()
	_build_kitchen()
	_build_entrance()
	chapter_spawn = global_transform * _facing(SPAWN, PHONE_SPOT)
	intro_spawn = chapter_spawn
	apply_mood("home_evening")


func _process(delta: float) -> void:
	_time += delta
	_phone_process(delta)
	_update_clock()


func _exit_tree() -> void:
	_stop_ring()


func moods() -> Dictionary:
	return MOODS


func default_mood() -> String:
	return "home_evening"


func _apply_mood(m: Dictionary) -> void:
	_apply_env_mood(m)
	_ceiling_light.light_color = m.ceiling
	_ceiling_light.light_energy = m.ceiling_e
	_ceiling_light.visible = m.ceiling_e > 0.0
	_floor_light.light_color = m.lamp
	_floor_light.light_energy = m.lamp_e
	_kitchen_light.light_energy = m.kitchen_e
	if _panel_mat != null:
		_panel_mat.emission = m.panel
		_panel_mat.emission_energy_multiplier = m.panel_e
	if _lamp_bulb_mat != null:
		_lamp_bulb_mat.emission_energy_multiplier = m.bulb_e
	_tv_mat.emission_energy_multiplier = m.tv_e
	_screen_base_e = m.phone_e
	if _screen_mat != null and not _alert and not _ringing:
		_screen_mat.emission_energy_multiplier = _screen_base_e
	_apply_view(m)
	_clock_base = m.clock
	_update_clock()


# ---------------------------------------------------------------- lights and room

func _build_lights() -> void:
	var lights := _node(self, "Lights")
	_build_sun(lights)
	# Three omnis, only the ceiling one shadowed.
	_ceiling_light = _omni(lights, "CeilingLight", Vector3(0.3, 2.35, -0.2), Color("ffe2bd"), 1.0, 6.5, 0.8, true)
	_floor_light = _omni(lights, "FloorLampLight", Vector3(-2.7, 1.42, 0.55), Color("ffc98a"), 0.9, 4.5, 1.0)
	_kitchen_light = _omni(lights, "KitchenLight", Vector3(2.5, 1.45, 0.55), Color("fff1d8"), 0.5, 2.6, 1.2)


func _build_room() -> void:
	var floor_mat := _tile_material(C_FLOOR, C_FLOOR_ALT, C_FLOOR_GROUT, 0.3, 0.75)
	var walls: Array[Color] = [C_WALL_ACCENT, C_WALL, C_WALL, C_WALL]
	var g := _build_shell(ROOM_W, ROOM_D, ROOM_H, floor_mat, walls, C_CEILING)
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	_strip(g, Vector3(-hw, 0.0, -hd), Vector3(hw, 0.0, -hd), Vector3.BACK, 0.08, 0.02, C_SKIRTING)
	_strip(g, Vector3(-hw, 0.0, hd), Vector3(hw, 0.0, hd), Vector3.FORWARD, 0.08, 0.02, C_SKIRTING)
	_strip(g, Vector3(-hw, 0.0, -hd), Vector3(-hw, 0.0, hd), Vector3.RIGHT, 0.08, 0.02, C_SKIRTING)
	_strip(g, Vector3(hw, 0.0, -hd), Vector3(hw, 0.0, hd), Vector3.LEFT, 0.08, 0.02, C_SKIRTING)
	var lamp := _model(g, "ceiling_lamp_round", Vector3(0.3, ROOM_H, -0.2))
	var diffuser := lamp.find_child("Diffuser", true, false) as MeshInstance3D
	if diffuser != null:
		_panel_mat = (diffuser.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		diffuser.material_override = _panel_mat
	_no_shadow(lamp)
	# Balcony door (the city at night), the aircon over the bed and the wall clock.
	_window(g, Vector3(TABLE.x, 1.07, -hd), "condo_window")
	_model(g, "aircon", Vector3(-2.0, 2.28, -hd))
	_wall_clock(g, Vector3(-0.35, 1.8, -hd))
	_model(g, "wall_outlet", Vector3(0.2, 0.32, -hd + 0.01))
	_model(g, "plant_snake", Vector3(2.62, 0.0, -2.15))
	_solid(_furniture_body, Vector3(0.34, 1.2, 0.34), Vector3(2.62, 0.6, -2.15))


# ---------------------------------------------------------------- the dining table and the phone

func _build_dining() -> void:
	var g := _node(_visual, "Dining")
	_model(g, "dining_table_small", TABLE)
	_solid(_furniture_body, Vector3(0.8, TABLE_TOP_Y, 0.8), TABLE + Vector3(0.0, TABLE_TOP_Y * 0.5, 0.0))
	for spec: Array in [[Vector3(TABLE.x, 0.0, TABLE.z - 0.55), 180.0], [Vector3(TABLE.x + 0.55, 0.0, TABLE.z), 90.0]]:
		_model(g, "dining_chair", spec[0], spec[1])
		_solid(_furniture_body, Vector3(0.44, 0.95, 0.44), (spec[0] as Vector3) + Vector3(0.0, 0.475, 0.0))
	_model(g, "mug", Vector3(TABLE.x + 0.24, TABLE_TOP_Y, TABLE.z - 0.12), 30.0)
	_build_smartphone(g, PHONE_SPOT, 0.0)


# ---------------------------------------------------------------- living corner: sofa, TV, floor lamp

func _build_living() -> void:
	var g := _node(_visual, "Living")
	_box(g, Vector3(2.0, 0.01, 1.5), Vector3(-1.6, 0.005, 1.1), C_RUG_BORDER, 1.0)
	_box(g, Vector3(1.84, 0.014, 1.34), Vector3(-1.6, 0.007, 1.1), C_RUG, 1.0)
	_model(g, "sofa", Vector3(-1.6, 0.0, 0.25))
	_solid(_furniture_body, Vector3(1.8, 0.85, 0.85), Vector3(-1.6, 0.425, 0.25))
	_model(g, "coffee_table", Vector3(-1.6, 0.0, 1.2))
	_solid(_furniture_body, Vector3(0.9, 0.45, 0.5), Vector3(-1.6, 0.225, 1.2))
	var tv := _model(g, "tv_console", Vector3(-1.6, 0.0, 2.28), 180.0)
	_tv_mat = _picture_material(Color("2b4c7e"), Color("5aa9e6"), Color("e3b04b"))
	_set_screen(tv, _tv_mat)
	_solid(_furniture_body, Vector3(1.4, 0.5, 0.43), Vector3(-1.6, 0.25, 2.28))
	_lamp(g, Vector3(-2.7, 0.0, 0.55), 0.0, "floor_lamp")
	_solid(_furniture_body, Vector3(0.32, 1.6, 0.32), Vector3(-2.7, 0.8, 0.55))
	_model(g, "wall_shelf", Vector3(-ROOM_W * 0.5, 1.45, 1.2), 90.0)


func _build_bed_corner() -> void:
	var g := _node(_visual, "Bed")
	_model(g, "bed_single", Vector3(-2.0, 0.0, -1.9), 90.0)
	_solid(_furniture_body, Vector3(2.04, 0.6, 1.04), Vector3(-2.0, 0.3, -1.9))
	_model(g, "wall_shelf", Vector3(-ROOM_W * 0.5, 1.4, -1.9), 90.0)


func _build_kitchen() -> void:
	var g := _group(_visual, "Kitchen", Vector3(2.69, 0.0, 0.55), -90.0)
	_model(g, "kitchenette", Vector3.ZERO)
	_model(g, "rice_cooker", Vector3(0.0, 0.935, 0.06), 10.0)
	_solid(_furniture_body, Vector3(1.84, 0.95, 0.62), Vector3(0.0, 0.475, 0.0), g)
	_model(_visual, "mini_fridge", Vector3(2.71, 0.0, 1.85), -90.0)
	_solid(_furniture_body, Vector3(0.58, 0.96, 0.5), Vector3(2.71, 0.48, 1.85))
	_model(_visual, "trash_bin", Vector3(2.75, 0.0, -0.62))


func _build_entrance() -> void:
	var g := _node(_visual, "Entrance")
	var hd := ROOM_D * 0.5
	_model(g, "condo_door", Vector3(0.7, 0.0, hd), 180.0)
	var mat := _model(g, "doormat", Vector3(0.7, 0.0, hd - 0.4))
	mat.scale = Vector3(0.6, 1.0, 0.6)
	_model(g, "light_switch", Vector3(1.4, 1.25, hd), 180.0)
	_model(g, "plant_floor", Vector3(-0.35, 0.0, 2.15))
	_solid(_furniture_body, Vector3(0.5, 1.3, 0.5), Vector3(-0.35, 0.65, 2.15))
