class_name OfficeBuilder
extends LocationBuilder
## Builds the Aegis Solutions office (Objective 1): room, entrance, reception with Ms. Dela Vega, coworkers'
## desks, a whiteboard, pantry and printer corners, lighting, and the player's desk with the two interactable
## devices (workstation and telephone).
## Every mesh sits under `Visual` and every world collider under `Collision`. The room shell (floor, walls,
## ceiling) is built in code; furniture, props and people are low-poly models made by script in Blender
## (art/blender/build_assets.py, exported to res://assets/models/*.glb). The colliders are the same boxes the
## greybox used, plus a few for the new wall furniture. Room: x -7..7, z -5..5, floor at y 0, ceiling at y 3.
## The moods (MOODS, keyed by id: office_morning ... office_noir) set the time of day; apply_chapter_mood() picks the
## chapter's mood from its Campaign data. The shared helpers and the public contract live in LocationBuilder.

const ROOM_W := 14.0
const ROOM_D := 10.0
const ROOM_H := 3.0
const WALL_T := 0.2
const DOOR_X := 4.5                              ## entrance in the south wall (z = +5)
const DOOR_W := 1.6
const DOOR_H := 2.2
const PLAYER_DESK := Vector3(-2.5, 0.0, -1.5)    ## about 9.5 m from the entrance
const RECEPTION := Vector3(1.9, 0.0, 3.0)
const DESK_TOP_Y := 0.75
const MONITOR_X := -0.05                         ## monitor and keyboard offset on a desk (local x)
const SCREEN_LOCAL := Vector3(-0.05, 1.085, -0.1815)
const PHONE_LOCAL := Vector3(0.55, 0.81, 0.0)
const WAINSCOT_H := 1.0
const SEAT_LOCAL := Vector3(-0.05, 0.0, 0.74)    ## where a seated coworker (and their chair) sits at a desk

## Ceiling light positions (x, z).
const CEILING_LIGHTS: Array[Vector2] = [Vector2(-4.0, -2.6), Vector2(1.0, -2.6), Vector2(-2.6, 2.2), Vector2(3.8, 2.2)]
## Only these ceiling lights cast shadows (one over the desks, one over reception), to keep it cheap.
const SHADOW_LIGHTS: Array[int] = [0, 3]

# Warm "GenSan office" palette for the parts built in code.
const C_FLOOR := Color("c9a27a")
const C_FLOOR_ALT := Color("c49c73")
const C_FLOOR_GROUT := Color("b08b66")
const C_WALL := Color("efe6d6")
const C_WAINSCOT := Color("8b5a3c")
const C_CAP_RAIL := Color("6f4a32")
const C_SKIRTING := Color("5a3e2b")
const C_CEILING := Color("f4f1ea")
const C_CEILING_GRID := Color("dcd7cc")
const C_SCREEN_OFF := Color("101419")
const C_RUG := Color("2f6f74")
const C_RUG_BORDER := Color("d8b066")
const C_SCREEN := Color("0d1d36")
const C_SCREEN_GLOW := Color("1f4f92")
const C_SCREEN_ALERT := Color("3478d0")

## Office times of day, by mood id: the attacks get harder as the day gets darker (morning ... noir night).
## Keys: environment (bg, ambient, ambient_e, exposure, glow), sun (sun, sun_e, sun_rot in degrees), ceiling
## lights (lamp, lamp_e), glowing props (panel_e, bulb_e, screen_e), window view ("day" with sky_top / sky_hor
## and a tint for the landscape, or "night" with its own palette and city lights), the neon strips (noir only)
## and the wall-clock time in hours (clock).
const MOODS: Dictionary = {
	"office_morning": {   # morning, warm low sun raking in from the east, peach fill, pink-to-gold sky
		"bg": Color("f2dccb"), "ambient": Color("ffd4ad"), "ambient_e": 0.46, "exposure": 1.0, "glow": 0.15,
		"sun": Color("ffa866"), "sun_e": 0.62, "sun_rot": Vector3(-9.0, 72.0, 0.0),
		"lamp": Color("ffdfbd"), "lamp_e": 1.06, "panel": Color("fff0d8"), "panel_e": 1.25, "bulb_e": 1.2, "screen_e": 0.45,
		"player_screen_e": 0.7,
		"view": "day", "sky_top": Color("efc3cb"), "sky_hor": Color("ffd08f"), "tint": Color(1.0, 0.88, 0.78),
		"neon": false, "clock": 8.5,
	},
	"office_noon": {   # noon, bright white light from above (the brightest chapter)
		"bg": Color("e2eef6"), "ambient": Color("f3f5fb"), "ambient_e": 0.42, "exposure": 1.0, "glow": 0.1,
		"sun": Color("ffffff"), "sun_e": 0.5, "sun_rot": Vector3(-78.0, 20.0, 0.0),
		"lamp": Color("fff8ee"), "lamp_e": 1.12, "panel": Color("fffaf2"), "panel_e": 1.35, "bulb_e": 1.0, "screen_e": 0.5,
		"player_screen_e": 0.7,
		"view": "day", "sky_top": Color("6fb6ec"), "sky_hor": Color("d4eefa"), "tint": Color(1.0, 1.0, 1.0),
		"neon": false, "clock": 12.08,
	},
	"office_afternoon": {   # afternoon, high sun from the west, neutral-cool fill and a deep blue sky
		"bg": Color("d3e2ee"), "ambient": Color("e9eef5"), "ambient_e": 0.34, "exposure": 1.0, "glow": 0.12,
		"sun": Color("f4f1ea"), "sun_e": 0.42, "sun_rot": Vector3(-58.0, -55.0, 0.0),
		"lamp": Color("fff3e4"), "lamp_e": 0.97, "panel": Color("f6f8ff"), "panel_e": 1.3, "bulb_e": 1.2, "screen_e": 0.5,
		"player_screen_e": 0.7,
		"view": "day", "sky_top": Color("3f8fd6"), "sky_hor": Color("b4daf3"), "tint": Color(0.93, 0.97, 1.0),
		"neon": false, "clock": 15.2,
	},
	"office_golden": {   # golden late afternoon
		"bg": Color("e8d6bd"), "ambient": Color("ffd9a6"), "ambient_e": 0.35, "exposure": 1.0, "glow": 0.25,
		"sun": Color("ffad5c"), "sun_e": 0.55, "sun_rot": Vector3(-14.0, -78.0, 0.0),
		"lamp": Color("ffe0b5"), "lamp_e": 1.0, "panel": Color("ffedd2"), "panel_e": 1.4, "bulb_e": 1.8, "screen_e": 0.55,
		"player_screen_e": 0.72,
		"view": "day", "sky_top": Color("8ea6d2"), "sky_hor": Color("ffb35e"), "tint": Color(1.0, 0.8, 0.6),
		"neon": false, "clock": 16.75,
	},
	"office_dusk": {   # dusk, purple and orange sky, the interior lights carry the room
		"bg": Color("4a3a5e"), "ambient": Color("b896be"), "ambient_e": 0.3, "exposure": 1.0, "glow": 0.45,
		"sun": Color("ff8a5c"), "sun_e": 0.22, "sun_rot": Vector3(-6.0, -84.0, 0.0),
		"lamp": Color("ffdcae"), "lamp_e": 1.15, "panel": Color("ffe7c4"), "panel_e": 1.75, "bulb_e": 3.0, "screen_e": 0.55,
		"player_screen_e": 0.8,
		"view": "night", "night_sky": Color("4f3d80"), "night_hor": Color("f08350"), "night_mtn": Color("3b2c58"),
		"night_sea": Color("44386a"), "city": Color("2f2848"), "ground": Color("2a2340"), "lights_e": 2.5,
		"neon": false, "clock": 18.3,
	},
	"office_noir": {   # noir night, dark blue room: monitors, desk lamps and the pink/cyan neon carry the light
		"bg": Color("0b1020"), "ambient": Color("2a3878"), "ambient_e": 0.4, "exposure": 1.0, "glow": 0.7,
		"sun": Color("6a82d4"), "sun_e": 0.16, "sun_rot": Vector3(-50.0, 30.0, 0.0),
		"lamp": Color("7286d6"), "lamp_e": 0.26, "panel": Color("8a9ad6"), "panel_e": 0.45, "bulb_e": 4.0, "screen_e": 0.3,
		"player_screen_e": 1.3,
		"view": "night", "night_sky": Color("0b1530"), "night_hor": Color("2a2f5e"), "night_mtn": Color("151b33"),
		"night_sea": Color("0e1c33"), "city": Color("1a2036"), "ground": Color("121729"), "lights_e": 4.0,
		"neon": true, "clock": 21.7,
	},
}

# Contract (LocationBuilder): workstation and telephone are the player's devices; intro_spawn is just inside the
# entrance facing reception; chapter_spawn is beside the player's desk facing the monitor; monitor_point is the
# centre of the monitor screen and phone_point the centre of the desk phone (world); pantry (coffee maker and water
# dispenser, E) and notice_board (E opens NoticeBoard) are feel only; walkers are the coworkers on their rounds.
# _phone_screen is the desk phone's small LCD and _caller_tag the caller's number under "RING!".

var _dela_vega_head := Vector3.ZERO
var _bulb_mat: StandardMaterial3D
var _ring_light: OmniLight3D

# Art and mood state.
var _ceiling_lights: Array[OmniLight3D] = []
var _neon_lights: Array[OmniLight3D] = []
var _desk_screen_mat: StandardMaterial3D        ## coworkers' and reception monitors (UI texture)
var _panel_mat: StandardMaterial3D              ## ceiling light panel diffusers
var _neon_mats: Array[StandardMaterial3D] = []
var _neon_strips: Array[Node3D] = []           ## whole strip models, shown in the noir mood only
var _fan_blades: Node3D
var _mug_mats: Dictionary = {}


func _init() -> void:
	location = "office"


func _ready() -> void:
	_build_roots()
	_build_environment()
	_build_lights()
	_build_room()
	_build_entrance()
	_build_reception()
	_build_office_desks()
	_build_player_desk()
	_build_decor()
	intro_spawn = global_transform * _facing(Vector3(DOOR_X, 0.0, 3.9), _dela_vega_head)
	apply_mood("office_morning")


func _process(delta: float) -> void:
	_time += delta
	if _ringing:
		_ring_time += delta
		var on := _ring_on_at(fmod(_ring_time, RING_PERIOD)) > 0.5
		_ring_light.visible = on
		_bulb_mat.emission_energy_multiplier = 6.0 if on else 0.4
		_ring_label.position.y = _ring_label_y + sin(_ring_time * 7.0) * 0.035
		_ring_label.scale = Vector3.ONE * (1.12 if on else 1.0)
	if _alert:
		var pulse := 0.5 + 0.5 * sin(_time * 3.2)
		_screen_mat.emission_energy_multiplier = lerpf(_screen_base_e + 0.1, _screen_base_e + 0.7, pulse)
		_alert_label.position.y = _alert_label_y + sin(_time * 2.4) * 0.02
	_update_clock()
	if _fan_blades != null:
		_fan_blades.rotation.z = fmod(_fan_blades.rotation.z + delta * 14.0, TAU)


## Stops the ring tone when the office is unloaded (scene change, quit or a place switch).
func _exit_tree() -> void:
	_stop_ring()


# ---------------------------------------------------------------- public API
# set_phone_display / phone_display (the desk phone's LCD and the caller tag) come from LocationBuilder.

## Starts or stops the ring: blinking light, bobbing "RING!" label and a procedural ring tone.
## Calling it again with the current state does nothing, so the ring never restarts mid-ring.
func set_phone_ringing(on: bool) -> void:
	if _ring_light == null or on == _ringing:
		return
	_ringing = on
	_ring_time = 0.0
	_ring_label.visible = on
	_caller_tag.visible = on
	_ring_label.position.y = _ring_label_y
	_ring_label.scale = Vector3.ONE
	_ring_light.visible = false
	_bulb_mat.emission_energy_multiplier = 0.4 if on else 0.0
	# The synthesized ring loop (Audio "phone_ring") has the same 3 s ring-ring-pause as the light.
	if on and _ring_player.stream != null:
		_ring_player.play()
	elif not on:
		_ring_player.stop()


## Shows new messages waiting on the workstation: a brighter, pulsing screen and a "N new" label.
func set_monitor_alert(on: bool, count: int = 1) -> void:
	if _screen_mat == null:
		return
	_alert_label.text = "%d new" % count
	if on == _alert:
		return
	_alert = on
	_alert_label.visible = on
	_alert_label.position.y = _alert_label_y
	_screen_mat.emission = C_SCREEN_ALERT if on else C_SCREEN_GLOW
	_screen_mat.emission_energy_multiplier = _screen_base_e + (0.1 if on else 0.0)


func moods() -> Dictionary:
	return MOODS


func default_mood() -> String:
	return "office_morning"


## Sets the office's time of day (apply_mood / apply_chapter_mood): sky, ambient light, tone mapping and glow,
## the sun's direction and colour, the ceiling lights, glowing props (light panels, lamps, monitors), the
## window view (day or night palette), the wall clock and, in the noir mood only, the neon strips. Purely visual;
## safe to call any time (chapter start, Restart Chapter, the intro).
func _apply_mood(m: Dictionary) -> void:
	_apply_env_mood(m)
	for l: OmniLight3D in _ceiling_lights:
		l.light_color = m.lamp
		l.light_energy = m.lamp_e
	_panel_mat.emission = m.panel
	_panel_mat.emission_energy_multiplier = m.panel_e
	_lamp_bulb_mat.emission_energy_multiplier = m.bulb_e
	_desk_screen_mat.emission_energy_multiplier = m.screen_e
	_screen_base_e = m.get("player_screen_e", 0.7)
	if _screen_mat != null and not _alert:
		_screen_mat.emission_energy_multiplier = _screen_base_e
	var neon: bool = m.neon
	for l: OmniLight3D in _neon_lights:
		l.visible = neon
	for strip: Node3D in _neon_strips:
		strip.visible = neon                       # by day the strips (and their rails) are not there at all
	for mat: StandardMaterial3D in _neon_mats:
		mat.emission_enabled = neon
		mat.albedo_color = mat.get_meta("glow") if neon else Color(0.86, 0.86, 0.88)    # unlit tube
	_apply_view(m)
	_clock_base = m.clock
	_update_clock()


# ---------------------------------------------------------------- environment and lights

func _build_lights() -> void:
	var lights := _node(self, "Lights")
	_build_sun(lights)
	var i := 0
	for p: Vector2 in CEILING_LIGHTS:
		var omni := OmniLight3D.new()
		omni.name = "CeilingLight%d" % (i + 1)
		omni.position = Vector3(p.x, 2.7, p.y)
		omni.light_color = Color("ffe9cc")
		omni.light_energy = 1.3
		omni.omni_range = 8.0
		omni.omni_attenuation = 0.6
		omni.shadow_enabled = SHADOW_LIGHTS.has(i)
		omni.shadow_blur = 1.5
		lights.add_child(omni)
		_ceiling_lights.append(omni)
		i += 1
	# Noir neon glow (no shadows), toggled by the mood.
	# [position, colour, energy, range]. The pink one sits at the west end of its strip so it rims the wall
	# without washing over the player's desk.
	var neon: Array = [[Vector3(-5.6, 2.45, -4.45), Color("ff3ea5"), 0.55, 3.4],
		[Vector3(3.9, 2.45, -4.4), Color("36e4ff"), 0.45, 3.6],
		[Vector3(-6.3, 2.45, 2.6), Color("ff3ea5"), 0.6, 3.8]]
	for k: int in neon.size():
		var nl := OmniLight3D.new()
		nl.name = "NeonLight%d" % (k + 1)
		nl.position = neon[k][0]
		nl.light_color = neon[k][1]
		nl.light_energy = neon[k][2]
		nl.omni_range = neon[k][3]
		nl.omni_attenuation = 1.4
		nl.shadow_enabled = false
		nl.visible = false
		lights.add_child(nl)
		_neon_lights.append(nl)


# ---------------------------------------------------------------- room shell

func _build_room() -> void:
	var g := _node(_visual, "Room")
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	# Floor (0.6 m vinyl tiles) and ceiling (0.6 m acoustic grid), from a tiny generated texture.
	var floor_mi := _box(g, Vector3(ROOM_W, 0.1, ROOM_D), Vector3(0.0, -0.05, 0.0), C_FLOOR, 0.9)
	floor_mi.material_override = _tile_material(C_FLOOR, C_FLOOR_ALT, C_FLOOR_GROUT, 0.6, 0.8)
	var ceil_mi := _box(g, Vector3(ROOM_W, 0.1, ROOM_D), Vector3(0.0, ROOM_H + 0.05, 0.0), C_CEILING)
	ceil_mi.material_override = _tile_material(C_CEILING, C_CEILING, C_CEILING_GRID, 0.6, 0.95)
	_solid(_room_body, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0.0, -0.1, 0.0))
	_solid(_room_body, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0.0, ROOM_H + 0.1, 0.0))
	# North, west and east walls.
	_wall(g, Vector3(ROOM_W + 2.0 * WALL_T, ROOM_H, WALL_T), Vector3(0.0, ROOM_H * 0.5, -hd - WALL_T * 0.5), C_WALL)
	_wall(g, Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(-hw - WALL_T * 0.5, ROOM_H * 0.5, 0.0), C_WALL)
	_wall(g, Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(hw + WALL_T * 0.5, ROOM_H * 0.5, 0.0), C_WALL)
	# South wall, split around the entrance.
	var door_l := DOOR_X - DOOR_W * 0.5
	var door_r := DOOR_X + DOOR_W * 0.5
	var sz := hd + WALL_T * 0.5
	var left_w := door_l + hw + WALL_T
	var right_w := hw + WALL_T - door_r
	_wall(g, Vector3(left_w, ROOM_H, WALL_T), Vector3(door_l - left_w * 0.5, ROOM_H * 0.5, sz), C_WALL)
	_wall(g, Vector3(right_w, ROOM_H, WALL_T), Vector3(door_r + right_w * 0.5, ROOM_H * 0.5, sz), C_WALL)
	_wall(g, Vector3(DOOR_W, ROOM_H - DOOR_H, WALL_T), Vector3(DOOR_X, (ROOM_H + DOOR_H) * 0.5, sz), C_WALL)
	# Wooden wainscot with a cap rail and skirting, all around (visual only: thinner than the colliders).
	_wainscot(g, Vector3(-hw, 0.0, -hd), Vector3(hw, 0.0, -hd), Vector3.BACK)
	_wainscot(g, Vector3(-hw, 0.0, -hd), Vector3(-hw, 0.0, hd), Vector3.RIGHT)
	_wainscot(g, Vector3(hw, 0.0, -hd), Vector3(hw, 0.0, hd), Vector3.LEFT)
	_wainscot(g, Vector3(-hw, 0.0, hd), Vector3(door_l, 0.0, hd), Vector3.FORWARD)
	_wainscot(g, Vector3(door_r, 0.0, hd), Vector3(hw, 0.0, hd), Vector3.FORWARD)
	# Ceiling light panels (the visible part of the ceiling lights).
	for p: Vector2 in CEILING_LIGHTS:
		var panel := _model(g, "light_panel", Vector3(p.x, ROOM_H, p.y))
		var diffuser := panel.find_child("Diffuser", true, false) as MeshInstance3D
		if _panel_mat == null:
			_panel_mat = (diffuser.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		diffuser.material_override = _panel_mat
		_no_shadow(panel)


func _wall(parent: Node3D, size: Vector3, center: Vector3, color: Color) -> void:
	_box(parent, size, center, color)
	_solid(_room_body, size, center)


## A wainscot run on the wall face from `a` to `b` (floor level); `inward` points into the room.
func _wainscot(parent: Node3D, a: Vector3, b: Vector3, inward: Vector3) -> void:
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var parts: Array = [
		[WAINSCOT_H, 0.02, WAINSCOT_H * 0.5, C_WAINSCOT, 0.7],           # panel
		[0.045, 0.04, WAINSCOT_H, C_CAP_RAIL, 0.6],                      # cap rail
		[0.1, 0.035, 0.05, C_SKIRTING, 0.7],                             # skirting
	]
	for p: Array in parts:
		var h: float = p[0]
		var t: float = p[1]
		var size := Vector3(length, h, t) if along_x else Vector3(t, h, length)
		var mi := _box(parent, size, mid + inward * (t * 0.5) + Vector3(0.0, p[2], 0.0), p[3], p[4])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- entrance

func _build_entrance() -> void:
	var g := _node(_visual, "Entrance")
	var z := ROOM_D * 0.5
	# Glass double door with frame, handles and a lit corridor behind it (the room side is -z).
	_model(g, "glass_door", Vector3(DOOR_X, 0.0, z))
	_solid(_room_body, Vector3(DOOR_W, DOOR_H, WALL_T), Vector3(DOOR_X, DOOR_H * 0.5, z + WALL_T * 0.5))
	_model(g, "doormat", Vector3(DOOR_X, 0.0, z - 0.55))
	_model(g, "light_switch", Vector3(DOOR_X - DOOR_W * 0.5 - 0.3, 1.25, z), 180.0)


# ---------------------------------------------------------------- reception and Ms. Dela Vega

func _build_reception() -> void:
	# Local +z is the counter's front; the group is turned so the front faces the entrance side (+x).
	var g := _group(_visual, "Reception", RECEPTION, 90.0)
	_model(g, "reception_counter", Vector3.ZERO)
	_label3d(g, "RECEPTION", Vector3(0.0, 0.58, 0.285), 40, 0.004, Color("f3ead9"), false, 0)
	_solid(_furniture_body, Vector3(2.1, 1.1, 0.7), Vector3(0.0, 0.55, 0.03), g)
	# Reception monitor: small, at the counter end and angled toward Ms. Dela Vega, so its back never shows
	# as a big black slab to the entrance. A small plant sits on the other end of the counter.
	var mon := _model(g, "monitor", Vector3(0.85, 1.09, -0.12), 215.0)
	mon.scale = Vector3.ONE * 0.75
	_set_desk_screen(mon)
	_model(g, "plant_desk", Vector3(-0.9, 1.09, -0.22))

	# Ms. Dela Vega: a static figure behind the counter (not interactable), with subtle idle motion.
	var dv := _group(g, "DelaVega", Vector3(0.0, 0.0, -0.62))
	_person(dv, "person_dela_vega", Vector3.ZERO, 0.0, PersonIdle.Pose.STANDING, 11)
	_label3d(dv, "Ms. Dela Vega — Security", Vector3(0.0, 1.98, 0.0), 40, 0.0028, UIStyle.TEXT, true)
	_solid(_furniture_body, Vector3(0.6, 1.8, 0.45), Vector3(0.0, 0.9, 0.0), dv)
	_dela_vega_head = _space_of(dv) * Vector3(0.0, 1.57, 0.0)


# ---------------------------------------------------------------- desks

func _build_office_desks() -> void:
	var g := _node(_visual, "OfficeDesks")
	var spots: Array[Vector3] = [
		Vector3(-5.0, 0.0, -1.5), Vector3(0.0, 0.0, -1.5), Vector3(2.6, 0.0, -1.5),
		Vector3(-5.0, 0.0, -3.9), Vector3(-2.5, 0.0, -3.9), Vector3(0.0, 0.0, -3.9),
	]
	var chair_yaw: Array[float] = [8.0, -12.0, 4.0, -6.0, 15.0, -3.0]
	var mug_colors: Array[Color] = [Color("c0392b"), Color("f0e6d2"), Color("2e86ab"), Color("e3b04b")]
	# Which coworker sits at which desk: Desk1 is on a call, Desk2 types (both next to the player's desk).
	var seated: Dictionary = {0: "person_coworker_phone", 1: "person_coworker_typing"}
	for i in spots.size():
		var d := _desk(g, "Desk%d" % (i + 1), spots[i], chair_yaw[i], not seated.has(i))
		_set_desk_screen(d.get_node("Monitor") as Node3D)
		if seated.has(i):
			var seat := _model(d, "office_chair", SEAT_LOCAL, 0.0, "SeatChair")
			var pose: PersonIdle.Pose = PersonIdle.Pose.PHONE if i == 0 else PersonIdle.Pose.TYPING
			var turn_with: Array[Node3D] = []
			if pose == PersonIdle.Pose.PHONE:
				turn_with.append(seat)
			_person(d, seated[i], SEAT_LOCAL, 0.0, pose, 20 + i, turn_with)
			if pose == PersonIdle.Pose.TYPING:
				_typing_sound(d)
		_desk_props(d, i, mug_colors[i % mug_colors.size()])


## Props on coworker desk `i` (slots chosen so nothing overlaps the monitor, keyboard or tower).
func _desk_props(d: Node3D, i: int, mug_color: Color) -> void:
	var y := DESK_TOP_Y
	if i % 2 == 0:
		_model(d, "pc_tower", Vector3(-0.6, y, -0.12))
	else:
		_lamp(d, Vector3(-0.62, y, -0.16), 15.0)
	match i:
		0:
			var phone := _model(d, "desk_phone", Vector3(0.55, y, 0.0))
			(phone.find_child("Handset", true, false) as Node3D).visible = false    # she is holding it
			_model(d, "pen_cup", Vector3(0.66, y, -0.28))
			_model(d, "photo_frame", Vector3(0.38, y, -0.27), -12.0)
			_mug(d, Vector3(-0.42, y, 0.2), mug_color)
		1:
			_model(d, "paper_stack", Vector3(0.56, y, -0.05), -8.0)
			_mug(d, Vector3(0.62, y, 0.22), mug_color)
			_model(d, "plant_desk", Vector3(0.42, y, -0.29))
		2:
			_lamp(d, Vector3(0.62, y, -0.18), -20.0)
			_model(d, "pen_cup", Vector3(0.4, y, -0.28))
			_mug(d, Vector3(0.55, y, 0.12), mug_color)
		3:
			_model(d, "paper_stack", Vector3(0.55, y, 0.0), 6.0)
			_model(d, "plant_desk", Vector3(0.64, y, -0.28))
			_mug(d, Vector3(-0.42, y, 0.2), mug_color)
		4:
			_model(d, "desk_phone", Vector3(0.55, y, 0.0))
			_model(d, "pen_cup", Vector3(0.38, y, -0.28))
			_model(d, "photo_frame", Vector3(0.66, y, -0.27), -18.0)
		_:
			_model(d, "desk_phone", Vector3(0.55, y, 0.0))
			_model(d, "paper_stack", Vector3(-0.45, y, 0.1), 10.0)
			_model(d, "photo_frame", Vector3(0.4, y, -0.27), -10.0)
	if i != 2:
		_model(d, "trash_bin", Vector3(0.52, 0.0, -0.12))


## A desk with a monitor, keyboard, mouse, cubicle panels and chair. Local +z is where the person sits.
## The chair collider always sits at the greybox spot; `chair_visual` false leaves the chair model to the
## caller (a seated coworker's chair is pulled in to the keyboard).
func _desk(parent: Node3D, n: String, pos: Vector3, chair_yaw: float, chair_visual: bool = true) -> Node3D:
	var g := _group(parent, n, pos)
	_model(g, "desk", Vector3.ZERO)
	_solid(_furniture_body, Vector3(1.6, DESK_TOP_Y, 0.75), Vector3(0.0, DESK_TOP_Y * 0.5, 0.0), g)
	_model(g, "monitor", Vector3(MONITOR_X, DESK_TOP_Y, -0.2), 0.0, "Monitor")
	_model(g, "keyboard", Vector3(MONITOR_X, DESK_TOP_Y, 0.12))
	_model(g, "mouse", Vector3(0.27, DESK_TOP_Y, 0.12))
	_model(g, "cubicle_divider", Vector3(0.0, DESK_TOP_Y, -0.355))
	_model(g, "cubicle_divider_side", Vector3(-0.78, DESK_TOP_Y, 0.02))
	_chair(g, Vector3(0.0, 0.0, 0.78), chair_yaw, chair_visual)
	return g


func _chair(parent: Node3D, pos: Vector3, yaw_deg: float, visual: bool = true) -> void:
	var g := _group(parent, "Chair", pos, yaw_deg)
	if visual:
		_model(g, "office_chair", Vector3.ZERO)
	_solid(_furniture_body, Vector3(0.55, 1.1, 0.55), Vector3(0.0, 0.55, 0.0), g)


# ---------------------------------------------------------------- the player's desk and devices

func _build_player_desk() -> void:
	_screen_mat = _emissive(C_SCREEN, C_SCREEN_GLOW, 0.7)
	_screen_mat.roughness = 0.3
	var g := _desk(_visual, "PlayerDesk", PLAYER_DESK, 0.0)
	var screen := g.get_node("Monitor").find_child("Screen", true, false) as MeshInstance3D
	screen.material_override = _screen_mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tower := _model(g, "pc_tower", Vector3(-0.6, DESK_TOP_Y, -0.12))
	_mug(g, Vector3(-0.42, DESK_TOP_Y, 0.21), Color("e3b04b"))
	_model(g, "photo_frame", Vector3(0.36, DESK_TOP_Y, -0.28), -14.0)
	_model(g, "pen_cup", Vector3(0.72, DESK_TOP_Y, -0.27))
	_model(g, "trash_bin", Vector3(0.52, 0.0, -0.12))
	var sp := _space_of(g)

	# Rug and sign so the player's desk is easy to find.
	_box(g, Vector3(2.5, 0.01, 2.1), Vector3(0.0, 0.005, 0.35), C_RUG_BORDER, 1.0)
	_box(g, Vector3(2.3, 0.016, 1.9), Vector3(0.0, 0.008, 0.35), C_RUG, 1.0)
	# Wayfinding marker seen from across the room; hidden up close so it never fills the view at the desk.
	var desk_label := _label3d(g, "YOUR DESK", Vector3(0.0, 2.15, -0.2), 64, 0.0045, UIStyle.ACCENT, true, 14)
	desk_label.visibility_range_begin = 3.0
	_label3d(g, "Aegis Workstation", SCREEN_LOCAL + Vector3(0.0, 0.0, 0.003), 24, 0.0013, Color("cfe3ff"), false, 0)
	_alert_label_y = 1.42
	_alert_label = _label3d(g, "1 new", Vector3(MONITOR_X, _alert_label_y, -0.2), 44, 0.0028, UIStyle.WARN, true, 12)
	_alert_label.visible = false

	# Desk phone: the model's RingBulb sits exactly where the greybox bulb was.
	var base := PHONE_LOCAL - Vector3(0.0, PHONE_LOCAL.y - DESK_TOP_Y, 0.0)
	var phone := _model(g, "desk_phone", base, 0.0, "DeskPhone")
	_bulb_mat = _emissive(Color("5a1010"), Color("ff3b2f"), 0.0)
	var bulb := phone.find_child("RingBulb", true, false) as MeshInstance3D
	bulb.material_override = _bulb_mat
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_label_y = 1.22
	_ring_label = _label3d(g, "RING!", Vector3(PHONE_LOCAL.x + 0.1, _ring_label_y, 0.05), 48, 0.003, UIStyle.DANGER, true, 14)
	_ring_label.visible = false
	_caller_tag = _label3d(g, "", Vector3(PHONE_LOCAL.x + 0.1, _ring_label_y - 0.13, 0.05), 34, 0.0024, Color("8ff0b0"), true, 12)
	_caller_tag.font = UIStyle.mono_font()
	_caller_tag.visible = false
	# Text on the phone's LCD (the model's LCD box sits at Blender (0.035, 0.06, 0.066), flat on top).
	_phone_screen = Label3D.new()
	_phone_screen.name = "PhoneScreen"
	_phone_screen.text = "READY"
	_phone_screen.font_size = 24
	_phone_screen.pixel_size = 0.0004
	_phone_screen.width = 190.0
	_phone_screen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phone_screen.modulate = Color("103a22")
	_phone_screen.outline_size = 0
	_phone_screen.font = UIStyle.mono_font()
	_phone_screen.position = Vector3(0.035, 0.0705, -0.06)
	_phone_screen.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_phone_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_phone_screen.no_depth_test = false
	phone.add_child(_phone_screen)

	# Ring light and the synthesized ring tone (no audio files; null when headless).
	var fx := _node(self, "PhoneFx")
	fx.transform = sp
	_ring_light = OmniLight3D.new()
	_ring_light.name = "RingLight"
	_ring_light.position = PHONE_LOCAL + Vector3(0.05, 0.15, -0.05)
	_ring_light.light_color = Color("ff4a3a")
	_ring_light.light_energy = 1.6
	_ring_light.omni_range = 1.6
	_ring_light.visible = false
	fx.add_child(_ring_light)
	_ring_player = AudioStreamPlayer3D.new()
	_ring_player.name = "RingSound"
	_ring_player.stream = Audio.get_stream("phone_ring")
	_ring_player.bus = "SFX"
	_ring_player.position = PHONE_LOCAL
	_ring_player.unit_size = 4.0
	_ring_player.volume_db = -5.0
	fx.add_child(_ring_player)

	# Interactables: collision boxes on layer 3 that stand proud of the desk.
	workstation = Interactable.new()
	workstation.name = "Workstation"
	workstation.device_id = "workstation"
	workstation.prompt = "Use workstation"
	workstation.set_box(Vector3(1.05, 0.6, 0.6))
	workstation.highlight_nodes = [g.get_node("Monitor") as Node3D, tower, _child_from(g, "keyboard")]
	workstation.transform = sp * Transform3D(Basis(), Vector3(-0.225, DESK_TOP_Y + 0.285, -0.055))
	_collision.add_child(workstation)

	telephone = Interactable.new()
	telephone.name = "Telephone"
	telephone.device_id = "telephone"
	telephone.prompt = "Answer the telephone"
	telephone.set_box(Vector3(0.34, 0.26, 0.34))
	telephone.highlight_nodes = [phone]
	telephone.transform = sp * Transform3D(Basis(), Vector3(PHONE_LOCAL.x, DESK_TOP_Y + 0.13, 0.0))
	_collision.add_child(telephone)

	monitor_point = global_transform * (sp * SCREEN_LOCAL)
	phone_point = global_transform * (sp * PHONE_LOCAL)
	chapter_spawn = global_transform * _facing(sp * Vector3(0.9, 0.0, 0.95), sp * SCREEN_LOCAL)


# ---------------------------------------------------------------- decor

func _build_decor() -> void:
	var g := _node(_visual, "Decor")
	var hw := ROOM_W * 0.5
	var wz := -ROOM_D * 0.5
	# North wall: whiteboard (with its own "AEGIS SOLUTIONS / Vigilant Protocol" lettering), two windows
	# looking out on the sea and Mt. Matutum, the security poster and the clock.
	_model(g, "whiteboard", Vector3(4.6, 1.7, wz))
	for x: float in [-4.4, -1.2]:
		_window(g, Vector3(x, 1.8, wz))
	_model(g, "poster_security", Vector3(1.8, 1.6, wz))
	_wall_clock(g, Vector3(1.8, 2.5, wz))
	# Neon strips (lit in the noir mood only).
	_neon(g, "neon_strip_pink", Vector3(-4.4, 2.78, wz), 0.0)
	_neon(g, "neon_strip_cyan", Vector3(-1.2, 2.78, wz), 0.0)
	_neon(g, "neon_strip_cyan", Vector3(4.6, 2.72, wz), 0.0)
	_neon(g, "neon_strip_pink", Vector3(-hw, 2.72, 2.6), 90.0)      # clear of the aircon (z 0.55..1.45)
	# Power outlets on the wainscot.
	for p: Vector3 in [Vector3(-3.3, 0.32, wz + 0.02), Vector3(-0.2, 0.32, wz + 0.02), Vector3(2.0, 0.32, wz + 0.02)]:
		_model(g, "wall_outlet", p)
	_model(g, "wall_outlet", Vector3(-hw + 0.02, 0.32, -1.2), 90.0)
	_model(g, "wall_outlet", Vector3(hw - 0.02, 0.32, -0.35), -90.0)

	# West wall: aircon, filing cabinets and a bookshelf.
	_model(g, "aircon", Vector3(-hw, 2.55, 1.0), 90.0)
	_model(g, "filing_cabinet", Vector3(-hw + 0.32, 0.0, 0.45), 90.0)
	_model(g, "filing_cabinet", Vector3(-hw + 0.32, 0.0, 0.95), 90.0)
	_solid(_furniture_body, Vector3(0.66, 1.03, 0.96), Vector3(-hw + 0.33, 0.515, 0.7))
	_model(g, "bookshelf", Vector3(-hw + 0.17, 0.0, 2.3), 90.0)
	_solid(_furniture_body, Vector3(0.34, 1.9, 0.92), Vector3(-hw + 0.17, 0.95, 2.3))
	_model(g, "light_switch", Vector3(-hw, 1.25, 3.2), 90.0)

	# East wall: printer station, pantry counter (coffee maker, E) and water dispenser (E), a stand fan and a
	# snake plant. Two coworkers walk their rounds from here (see _build_walkers).
	_model(g, "printer_station", Vector3(hw - 0.27, 0.0, -1.2), -90.0)
	_solid(_furniture_body, Vector3(0.55, 1.02, 0.74), Vector3(hw - 0.28, 0.51, -1.2))
	var counter := _model(g, "pantry_counter", Vector3(hw - 0.32, 0.0, 0.6), -90.0)
	_solid(_furniture_body, Vector3(0.64, 1.0, 1.46), Vector3(hw - 0.32, 0.5, 0.6))
	var dispenser := _model(g, "water_dispenser", Vector3(hw - 0.2, 0.0, 1.75), -90.0)
	_solid(_furniture_body, Vector3(0.42, 1.37, 0.42), Vector3(hw - 0.2, 0.685, 1.75))
	pantry = Pantry.new()
	pantry.name = "Pantry"
	g.add_child(pantry)
	pantry.setup(counter, dispenser, _collision, _space_of(counter), _space_of(dispenser))
	var fan := _model(g, "stand_fan", Vector3(6.35, 0.0, -3.7), -55.0)
	_fan_blades = fan.find_child("FanBlades", true, false) as Node3D
	_solid(_furniture_body, Vector3(0.45, 1.4, 0.45), Vector3(6.35, 0.7, -3.7))
	_model(g, "plant_snake", Vector3(6.0, 0.0, -4.65))          # along the north wall, apart from the fan
	_solid(_furniture_body, Vector3(0.34, 1.2, 0.34), Vector3(6.0, 0.6, -4.65))
	var board := _model(g, "cork_board", Vector3(hw, 1.68, 0.75), -90.0)     # pantry notices above the counter
	notice_board = Interactable.new()
	notice_board.name = "NoticeBoard"
	notice_board.device_id = "board"
	notice_board.prompt = "Read the notice board"
	notice_board.enabled = true
	notice_board.set_box(Vector3(0.84, 0.6, 0.08))
	notice_board.highlight_nodes = [board]
	notice_board.transform = _space_of(board) * Transform3D(Basis(), Vector3(0.0, 0.0, 0.04))
	_collision.add_child(notice_board)
	_build_walkers(g)
	_model(g, "trash_bin", Vector3(6.75, 0.0, 2.25))

	# Plants by the entrance and in the far corner of the open area, plus a snake plant behind reception.
	_plant(g, Vector3(6.45, 0.0, 4.4))
	_plant(g, Vector3(-6.45, 0.0, 4.4))
	_model(g, "plant_snake", Vector3(0.75, 0.0, 4.6))
	_solid(_furniture_body, Vector3(0.34, 1.2, 0.34), Vector3(0.75, 0.6, 4.6))


func _plant(parent: Node3D, pos: Vector3) -> void:
	var g := _group(parent, "Plant", pos)
	_model(g, "plant_floor", Vector3.ZERO)
	_solid(_furniture_body, Vector3(0.5, 1.3, 0.5), Vector3(0.0, 0.65, 0.0), g)


func _neon(parent: Node3D, file: String, pos: Vector3, yaw: float) -> void:
	var strip := _model(parent, file, pos, yaw)
	var tube := strip.find_child("Tube", true, false) as MeshInstance3D
	var m := (tube.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.set_meta("glow", m.albedo_color)
	tube.material_override = m
	_neon_mats.append(m)
	_neon_strips.append(strip)
	_no_shadow(strip)


# ---------------------------------------------------------------- models

## Soft keyboard typing at the typing coworker's desk (a quiet looping 3D sound; nothing when headless).
func _typing_sound(desk: Node3D) -> void:
	var stream := Audio.get_stream("typing")
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.name = "TypingSound"
	p.stream = stream
	p.bus = "SFX"
	p.position = Vector3(MONITOR_X, DESK_TOP_Y + 0.05, 0.12)
	p.unit_size = 1.2
	p.max_distance = 9.0
	p.volume_db = -9.0
	p.autoplay = true
	desk.add_child(p)


## Two coworkers who walk their rounds on fixed paths clear of the furniture (art only, never interact):
## the printer coworker takes printouts to reception and to Desk 3, then goes back to the printer; the coworker
## with the mug goes from the coffee maker to the whiteboard and the water dispenser. Each has a moving
## collider, so the player cannot walk through them; they wait when someone is in their way.
func _build_walkers(g: Node3D) -> void:
	var east := PI * 0.5
	var printer_route: Array[Dictionary] = [
		{"at": Vector3(6.05, 0.0, -1.2), "face": east, "wait": 7.0},
		{"at": Vector3(2.75, 0.0, 2.25), "face": -east, "wait": 6.0,
			"via": [Vector3(4.9, 0.0, -0.1), Vector3(3.6, 0.0, 1.0)]},
		{"at": Vector3(3.75, 0.0, -1.3), "face": -east, "wait": 5.0, "via": [Vector3(3.6, 0.0, 1.0)]},
	]
	var mug_route: Array[Dictionary] = [
		{"at": Vector3(5.95, 0.0, 0.2), "face": east, "wait": 8.0},
		{"at": Vector3(4.45, 0.0, -4.05), "face": PI, "wait": 7.0,
			"via": [Vector3(5.45, 0.0, -0.7), Vector3(4.9, 0.0, -2.5)]},
		{"at": Vector3(6.15, 0.0, 1.6), "face": east, "wait": 5.0,
			"via": [Vector3(4.9, 0.0, -2.5), Vector3(5.45, 0.0, -0.7)]},
		{"at": Vector3(5.95, 0.0, 0.2), "face": east, "wait": 0.0, "via": [Vector3(5.8, 0.0, 1.35)]},
	]
	var specs: Array = [["person_coworker_printer", 31, printer_route, 1.0], ["person_coworker_mug", 42, mug_route, 4.0]]
	for spec: Array in specs:
		var p := _person(g, spec[0], Vector3.ZERO, 0.0, PersonIdle.Pose.STANDING, spec[1])
		var w := PersonWalker.new(spec[2] as Array[Dictionary], spec[3])
		w.name = "Walker"
		p.add_child(w)
		var body := AnimatableBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.24
		cap.height = 1.7
		cs.shape = cap
		cs.position = Vector3(0.0, 0.85, 0.0)
		body.add_child(cs)
		p.add_child(body)
		walkers.append(w)
	for w: PersonWalker in walkers:
		w.others = walkers


## Puts the shared "monitor on" material (a small UI picture) on a monitor model's Screen. The glb screen is
## swapped for a QuadMesh of the same size and place so the picture has UVs.
func _set_desk_screen(monitor: Node3D) -> void:
	if _desk_screen_mat == null:
		_desk_screen_mat = StandardMaterial3D.new()
		var tex := _screen_ui_texture()
		_desk_screen_mat.albedo_texture = tex
		_desk_screen_mat.albedo_color = Color(0.3, 0.32, 0.36)
		_desk_screen_mat.emission_enabled = true
		_desk_screen_mat.emission_texture = tex
		_desk_screen_mat.emission = Color.WHITE
		_desk_screen_mat.emission_energy_multiplier = 0.5
		_desk_screen_mat.roughness = 0.3
	var screen := monitor.find_child("Screen", true, false) as MeshInstance3D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.58, 0.335)
	screen.mesh = quad
	screen.position = Vector3(0.0, 0.335, 0.0185)
	screen.material_override = _desk_screen_mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _mug(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mug := _model(parent, "mug", pos, fmod(absf(pos.x * 97.0 + pos.z * 53.0), 80.0) - 40.0)
	var mi := mug.find_child("CoffeeMug", true, false) as MeshInstance3D
	var key := color.to_html()
	for s: int in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(s)
		if src != null and src.resource_name == "MugBody":
			if not _mug_mats.has(key):
				var m := src.duplicate() as StandardMaterial3D
				m.albedo_color = color
				_mug_mats[key] = m
			mi.set_surface_override_material(s, _mug_mats[key])


## A generic office app picture for coworkers' monitors: title bar, sidebar and text lines.
func _screen_ui_texture() -> ImageTexture:
	var w := 96
	var h := 56
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color("e6edf6"))
	img.fill_rect(Rect2i(0, 0, w, 7), Color("2b4c7e"))
	img.fill_rect(Rect2i(0, 7, 22, h - 7), Color("c9d6e6"))
	for i: int in 6:
		img.fill_rect(Rect2i(3, 11 + i * 7, 16, 3), Color("8fa3bd"))
	img.fill_rect(Rect2i(27, 11, 44, 4), Color("3478d0"))
	for i: int in 7:
		img.fill_rect(Rect2i(27, 19 + i * 5, 30 + (i * 17) % 36, 2), Color("9aa4b0"))
	img.fill_rect(Rect2i(76, 11, 16, 14), Color("e3b04b"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
