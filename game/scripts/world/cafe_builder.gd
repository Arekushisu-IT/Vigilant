class_name CafeBuilder
extends LocationBuilder
## Kape Kanto, a small cafe in General Santos (Chapters 8 and 10, Objective 1): 9 x 6 m with a 3.0 m ceiling.
## The storefront (a big window on the street and a glass door) is in the south wall and the counter in the north,
## with a barista behind it. A few customers sit at round tables (one on a laptop, one reading her phone, one
## having coffee). The player's table is by the window, with their smartphone on it: the only device here
## (`phone`, device_id "phone"). Nobody here ever talks to the player or takes part in a chapter.
## Room: x -4.5..4.5, z -3..3, floor at y 0, ceiling at y 3. Low-poly models from build_assets.py; the cafe's
## name and menu are part of the models (no QR codes anywhere in the cafe).

const ROOM_W := 9.0
const ROOM_D := 6.0
const ROOM_H := 3.0
const DOOR_X := 2.9                               ## glass door in the south wall
const DOOR_W := 1.6
const DOOR_H := 2.2
const COUNTER := Vector3(1.0, 0.0, -1.6)          ## counter centre (customers at +z, the barista at -z)
const TABLE_TOP_Y := 0.75
const PLAYER_TABLE := Vector3(-1.6, 0.0, 2.0)     ## the player's window table
const PHONE_SPOT := Vector3(-1.6, 0.75, 1.8)      ## the smartphone, on the player's side of the table
const SPAWN := Vector3(-1.6, 0.0, 1.05)           ## where the player stands, facing the phone (and the window)
const TABLE_A := Vector3(-3.4, 0.0, -0.9)         ## customer on a laptop
const TABLE_B := Vector3(-1.2, 0.0, -0.75)        ## empty table with cups
const TABLE_C := Vector3(3.0, 0.0, 0.6)           ## two customers: one on her phone, one having coffee

const C_WALL := Color("f0e4cf")
const C_WALL_ACCENT := Color("c98f6a")
const C_PANEL := Color("7a5236")
const C_PANEL_RAIL := Color("5a3e2b")
const C_CEILING := Color("e8dccb")
const C_FLOOR := Color("d8cbb4")
const C_FLOOR_ALT := Color("c9b89c")
const C_FLOOR_GROUT := Color("a8987e")
const C_BAR := Color("6e4a33")
const C_BAR_TOP := Color("e4dac9")

## Cafe moods (Friday lunch break and Saturday early evening). Keys: environment and sun (as in the office),
## pendant lights (pendant, pendant_e), lamp bulbs (bulb_e), string lights (string_e), laptop screens (screen_e),
## the phone screen's idle glow (phone_e), what shows behind the glass door (door_bg), the street view (day
## with sky_top / sky_hor / tint, or night with its palette) and the wall clock (clock, hours).
const MOODS: Dictionary = {
	"cafe_noon": {      # bright day on the street, the lamps barely needed
		"bg": Color("e2eef6"), "ambient": Color("fff2e2"), "ambient_e": 0.55, "glow": 0.12,
		"sun": Color("ffffff"), "sun_e": 0.55, "sun_rot": Vector3(-60.0, 170.0, 0.0),
		"pendant": Color("ffe6c4"), "pendant_e": 0.45, "bulb_e": 1.0, "string_e": 0.8, "screen_e": 0.5, "phone_e": 0.7,
		"door_bg": Color("dfe9ee"),
		"view": "day", "sky_top": Color("6fb6ec"), "sky_hor": Color("d4eefa"), "tint": Color(1.0, 1.0, 1.0),
		"clock": 12.5,
	},
	"cafe_evening": {   # dusk outside (orange horizon), warm pendants and string lights inside
		"bg": Color("4a3a5e"), "ambient": Color("c89a92"), "ambient_e": 0.34, "glow": 0.45,
		"sun": Color("ff8a5c"), "sun_e": 0.2, "sun_rot": Vector3(-8.0, 150.0, 0.0),
		"pendant": Color("ffcf8f"), "pendant_e": 1.15, "bulb_e": 3.0, "string_e": 5.0, "screen_e": 0.6, "phone_e": 0.8,
		"door_bg": Color("3a3050"),
		"view": "night", "night_sky": Color("4f3d80"), "night_hor": Color("f08350"), "night_mtn": Color("3b2c58"),
		"night_sea": Color("44386a"), "city": Color("2f2848"), "ground": Color("2a2340"), "lights_e": 2.5,
		"clock": 18.5,
	},
}

var _lights: Array[OmniLight3D] = []
var _string_mats: Dictionary = {}
var _string_mat: StandardMaterial3D
var _laptop_mat: StandardMaterial3D
var _door_mat: StandardMaterial3D


func _init() -> void:
	location = "cafe"


func _ready() -> void:
	_build_roots()
	_build_environment()
	_build_lights()
	_build_room()
	_build_storefront()
	_build_counter()
	_build_player_table()
	_build_customers()
	_build_decor()
	chapter_spawn = global_transform * _facing(SPAWN, PHONE_SPOT)
	intro_spawn = chapter_spawn
	apply_mood("cafe_noon")


func _process(delta: float) -> void:
	_time += delta
	_phone_process(delta)
	_update_clock()


func _exit_tree() -> void:
	_stop_ring()


func moods() -> Dictionary:
	return MOODS


func default_mood() -> String:
	return "cafe_noon"


func _apply_mood(m: Dictionary) -> void:
	_apply_env_mood(m)
	for l: OmniLight3D in _lights:
		l.light_color = m.pendant
		l.light_energy = m.pendant_e * float(l.get_meta("base", 1.0))
	if _lamp_bulb_mat != null:
		_lamp_bulb_mat.emission_energy_multiplier = m.bulb_e
	if _string_mat != null:
		_string_mat.emission_energy_multiplier = m.string_e
	_laptop_mat.emission_energy_multiplier = m.screen_e
	if _door_mat != null:
		_door_mat.albedo_color = m.door_bg
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
	# Three omnis under the pendants (the counter one shadowed); the other pendants and the string lights glow.
	var specs: Array = [
		[Vector3(PLAYER_TABLE.x, 2.0, PLAYER_TABLE.z), 1.0, 3.6, false],
		[Vector3(COUNTER.x, 2.35, COUNTER.z), 1.2, 5.5, true],
		[Vector3(TABLE_C.x, 2.0, TABLE_C.z), 0.9, 3.6, false],
	]
	for i: int in specs.size():
		var s: Array = specs[i]
		var l := _omni(lights, "PendantLight%d" % (i + 1), s[0], Color("ffe6c4"), s[1], s[2], 1.0, s[3])
		l.set_meta("base", s[1])
		_lights.append(l)


func _build_room() -> void:
	var floor_mat := _tile_material(C_FLOOR, C_FLOOR_ALT, C_FLOOR_GROUT, 0.4, 0.8)
	var walls: Array[Color] = [C_WALL_ACCENT, C_WALL, C_WALL, C_WALL]
	var g := _build_shell(ROOM_W, ROOM_D, ROOM_H, floor_mat, walls, C_CEILING, Vector3(DOOR_X, DOOR_W, DOOR_H))
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	# Wood panelling (1 m) with a rail on the north, west and east walls.
	for run: Array in [[Vector3(-hw, 0.0, -hd), Vector3(hw, 0.0, -hd), Vector3.BACK],
			[Vector3(-hw, 0.0, -hd), Vector3(-hw, 0.0, hd), Vector3.RIGHT],
			[Vector3(hw, 0.0, -hd), Vector3(hw, 0.0, hd), Vector3.LEFT]]:
		_strip(g, run[0], run[1], run[2], 1.0, 0.02, C_PANEL)
		_strip(g, run[0], run[1], run[2], 0.045, 0.04, C_PANEL_RAIL, 1.0)
	# Pendants over the tables and the counter.
	for p: Vector3 in [PLAYER_TABLE, TABLE_A, TABLE_B, TABLE_C, COUNTER + Vector3(-0.6, 0.0, 0.0), COUNTER + Vector3(0.6, 0.0, 0.0)]:
		var lamp := _lamp(g, Vector3(p.x, ROOM_H, p.z), 0.0, "pendant_lamp")
		if p == COUNTER + Vector3(-0.6, 0.0, 0.0) or p == COUNTER + Vector3(0.6, 0.0, 0.0):
			lamp.position.y = ROOM_H + 0.2       # a little higher over the counter (head room for the barista)
		_no_shadow(lamp)
	# Fairy lights along the side walls.
	for spec: Array in [[Vector3(-hw, 2.75, 0.0), 90.0], [Vector3(hw, 2.75, -0.3), -90.0]]:
		var lights := _model(g, "string_lights", spec[0], spec[1])
		_string_mat = _shared_surface(lights, "StringBulb", _string_mats)
		_no_shadow(lights)


# ---------------------------------------------------------------- storefront: window, door, sign

func _build_storefront() -> void:
	var g := _node(_visual, "Storefront")
	var hd := ROOM_D * 0.5
	_window(g, Vector3(-1.1, 1.25, hd), "storefront_window", 180.0)
	_solid(_furniture_body, Vector3(3.4, 0.3, 0.25), Vector3(-1.1, 0.15, hd - 0.12))      # the sill
	_model(g, "cafe_sign", Vector3(-1.1, 2.62, hd), 180.0)
	var door := _model(g, "glass_door", Vector3(DOOR_X, 0.0, hd))
	_door_mat = StandardMaterial3D.new()
	_door_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_door_mat.albedo_color = Color("dfe9ee")
	var backdrop := door.find_child("Backdrop", true, false) as MeshInstance3D
	if backdrop != null:
		backdrop.material_override = _door_mat
		backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model(g, "doormat", Vector3(DOOR_X, 0.0, hd - 0.55))
	_model(g, "light_switch", Vector3(DOOR_X - DOOR_W * 0.5 - 0.3, 1.25, hd), 180.0)


# ---------------------------------------------------------------- counter, back bar and the barista

func _build_counter() -> void:
	var g := _node(_visual, "Counter")
	_model(g, "cafe_counter", COUNTER)
	# Back bar along the north wall: cabinet, top, espresso machine, cups, a shelf and the menu board.
	var bz := -ROOM_D * 0.5 + 0.25
	_box(g, Vector3(2.6, 0.9, 0.5), Vector3(COUNTER.x, 0.45, bz), C_BAR, 0.7)
	_box(g, Vector3(2.7, 0.04, 0.55), Vector3(COUNTER.x, 0.92, bz + 0.01), C_BAR_TOP, 0.5)
	for i: int in 4:
		_box(g, Vector3(0.6, 0.78, 0.012), Vector3(COUNTER.x - 0.96 + i * 0.64, 0.46, bz + 0.256), C_BAR.lightened(0.12), 0.7)
	_model(g, "espresso_machine", Vector3(COUNTER.x - 0.55, 0.94, bz), 0.0)
	for i: int in 3:
		_model(g, "coffee_cup_saucer", Vector3(COUNTER.x + 0.25 + i * 0.18, 0.94, bz + 0.08), i * 25.0)
	_model(g, "iced_coffee", Vector3(COUNTER.x + 0.95, 0.94, bz + 0.05))
	_model(g, "menu_board", Vector3(COUNTER.x - 0.4, 2.1, -ROOM_D * 0.5))
	_model(g, "wall_shelf", Vector3(COUNTER.x + 0.95, 1.6, -ROOM_D * 0.5))
	# One collider for the counter, the barista's aisle and the back bar (staff only).
	var z0 := COUNTER.z + 0.36
	var z1 := -ROOM_D * 0.5
	_solid(_furniture_body, Vector3(2.7, 1.06, z0 - z1), Vector3(COUNTER.x, 0.53, (z0 + z1) * 0.5))
	_person(g, "person_barista", Vector3(COUNTER.x + 0.2, 0.0, COUNTER.z - 0.6), 0.0, PersonIdle.Pose.STANDING, 51)
	for x: float in [COUNTER.x - 0.6, COUNTER.x + 0.5]:
		_model(g, "bar_stool", Vector3(x, 0.0, COUNTER.z + 0.68))
		_solid(_furniture_body, Vector3(0.36, 0.75, 0.36), Vector3(x, 0.375, COUNTER.z + 0.68))


# ---------------------------------------------------------------- tables

func _table(parent: Node3D, pos: Vector3) -> void:
	_model(parent, "cafe_table_round", pos)
	_solid(_furniture_body, Vector3(0.7, TABLE_TOP_Y, 0.7), pos + Vector3(0.0, TABLE_TOP_Y * 0.5, 0.0))


## Where a chair goes: `dist` m from `table` on the side `yaw_deg` turns to (its sitter faces the table).
func _chair_at(table: Vector3, yaw_deg: float, dist: float = 0.55) -> Vector3:
	return table + Vector3(0.0, 0.0, dist).rotated(Vector3.UP, deg_to_rad(yaw_deg))


func _build_player_table() -> void:
	var g := _node(_visual, "PlayerTable")
	_table(g, PLAYER_TABLE)
	var cp := _chair_at(PLAYER_TABLE, -90.0)
	_model(g, "cafe_chair", cp, -90.0)
	_solid(_furniture_body, Vector3(0.44, 0.9, 0.44), cp + Vector3(0.0, 0.45, 0.0))
	_model(g, "iced_coffee", Vector3(PLAYER_TABLE.x + 0.18, TABLE_TOP_Y, PLAYER_TABLE.z - 0.02))
	_model(g, "pastry_plate", Vector3(PLAYER_TABLE.x - 0.12, TABLE_TOP_Y, PLAYER_TABLE.z + 0.15), 20.0)
	# The phone lies with the top of its screen toward the window (away from the player).
	_build_smartphone(g, PHONE_SPOT, 180.0)


func _build_customers() -> void:
	var g := _node(_visual, "Customers")
	_laptop_mat = _picture_material(Color("2b4c7e"), Color("e6edf6"), Color("3fa7d6"))
	# Table A: someone working on a laptop.
	_table(g, TABLE_A)
	_seated(g, "cafe_chair", "person_cafe_laptop", _chair_at(TABLE_A, 0.0), 0.0, PersonIdle.Pose.TYPING, 52)
	var laptop := _model(g, "laptop", TABLE_A + Vector3(0.0, TABLE_TOP_Y, 0.08))
	_set_screen(laptop, _laptop_mat)
	_model(g, "coffee_cup_saucer", TABLE_A + Vector3(0.22, TABLE_TOP_Y, -0.05), 40.0)
	var cp := _chair_at(TABLE_A, 180.0)
	_model(g, "cafe_chair", cp, 180.0)
	_solid(_furniture_body, Vector3(0.44, 0.9, 0.44), cp + Vector3(0.0, 0.45, 0.0))
	# Table B: empty, two cups left behind.
	_table(g, TABLE_B)
	for yaw: float in [0.0, 180.0]:
		var p := _chair_at(TABLE_B, yaw)
		_model(g, "cafe_chair", p, yaw)
		_solid(_furniture_body, Vector3(0.44, 0.9, 0.44), p + Vector3(0.0, 0.45, 0.0))
	_model(g, "coffee_cup_saucer", TABLE_B + Vector3(-0.12, TABLE_TOP_Y, 0.1), -20.0)
	_model(g, "coffee_cup_saucer", TABLE_B + Vector3(0.14, TABLE_TOP_Y, -0.08), 160.0)
	# Table C: one reading her phone, one having coffee.
	_table(g, TABLE_C)
	_seated(g, "cafe_chair", "person_cafe_phone", _chair_at(TABLE_C, -90.0), -90.0, PersonIdle.Pose.SEATED, 53)
	_seated(g, "cafe_chair", "person_cafe_sip", _chair_at(TABLE_C, 90.0), 90.0, PersonIdle.Pose.SEATED, 54)
	_model(g, "pastry_plate", TABLE_C + Vector3(-0.15, TABLE_TOP_Y, 0.08))
	_model(g, "iced_coffee", TABLE_C + Vector3(-0.1, TABLE_TOP_Y, -0.15))


func _build_decor() -> void:
	var g := _node(_visual, "Decor")
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	_plant_at(g, Vector3(-hw + 0.4, 0.0, hd - 0.45))
	_plant_at(g, Vector3(hw - 0.4, 0.0, hd - 0.45))
	_model(g, "plant_snake", Vector3(hw - 0.35, 0.0, -hd + 0.35))
	_solid(_furniture_body, Vector3(0.34, 1.2, 0.34), Vector3(hw - 0.35, 0.6, -hd + 0.35))
	_wall_clock(g, Vector3(hw, 2.2, 1.7), -90.0)
	_model(g, "trash_bin", Vector3(COUNTER.x + 1.55, 0.0, COUNTER.z + 0.45))
	_model(g, "wall_shelf", Vector3(-hw, 1.7, -1.9), 90.0)
	_model(g, "wall_outlet", Vector3(-hw + 0.01, 0.32, -0.4), 90.0)


func _plant_at(parent: Node3D, pos: Vector3) -> void:
	_model(parent, "plant_floor", pos)
	_solid(_furniture_body, Vector3(0.5, 1.3, 0.5), pos + Vector3(0.0, 0.65, 0.0))
