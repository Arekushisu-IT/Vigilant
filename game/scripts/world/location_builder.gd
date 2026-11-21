class_name LocationBuilder
extends Node3D
## Base of the three places the week is played in (Objective 1): the Aegis office (OfficeBuilder), the player's
## condo (HomeBuilder) and a cafe (CafeBuilder). The office director (office.gd) builds one for the current chapter's
## place with create() and only talks to it through the public contract below, so every place looks the same to it.
## Every mesh sits under `Visual` and every world collider under `Collision`. Furniture, props and people are
## low-poly models made by script in Blender (art/blender/build_assets.py -> res://assets/models/*.glb).
## The shared building helpers live here. Home and cafe share the smartphone (the only device off the clock):
## _build_smartphone() makes it, and the phone feedback (ring, new-messages alert, screen text) is implemented here;
## the office overrides that feedback with its desk phone and monitor.

const MODELS := "res://assets/models/"
const RING_PERIOD := 3.0                         ## ring-ring ... pause (the same cadence for every phone)

## Smartphone screen colours (dark lock screen, glow, alert glow).
const C_PHONE_SCREEN := Color("0d1d36")
const C_PHONE_GLOW := Color("2a5aa0")
const C_PHONE_ALERT := Color("4a8ae0")

# ---------------------------------------------------------------- public contract
var location: String = ""             ## "office", "home" or "cafe"
var workstation: Interactable         ## office only (null elsewhere)
var telephone: Interactable           ## office only (null elsewhere)
var phone: Interactable               ## home and cafe only: the smartphone (device_id "phone"; null in the office)
var monitor_point: Vector3            ## where the camera looks to use the main device (home/cafe: the phone screen)
var phone_point: Vector3              ## where the camera looks to answer a call (home/cafe: the phone screen)
var chapter_spawn: Transform3D        ## where the player starts a chapter, facing the device
var intro_spawn: Transform3D          ## where the player starts the intro (home/cafe: the chapter spawn)
var chapter_mood := 0                 ## the chapter whose lighting was last applied (0 before the first call)
var mood_id := ""                     ## the mood (lighting) id currently applied
var pantry: Pantry                    ## office only (null elsewhere)
var notice_board: Interactable        ## office only (null elsewhere)
var walkers: Array[PersonWalker] = []   ## people who walk between stops (may be empty)

# ---------------------------------------------------------------- shared state
var _visual: Node3D
var _collision: Node3D
var _room_body: StaticBody3D
var _furniture_body: StaticBody3D
var _mats: Dictionary = {}
var _env: Environment
var _sun: DirectionalLight3D
var _lamp_bulb_mat: StandardMaterial3D          ## lamp bulbs (follow the mood)
var _view_mats: Dictionary = {}                 ## window view material name -> unshaded copy
var _view_base: Dictionary = {}                 ## window view material name -> imported colour
var _views_day: Array[Node3D] = []
var _views_night: Array[Node3D] = []
var _clock_hands: Array[Node3D] = []            ## hour, minute, second
var _clock_base := 8.5
var _time := 0.0

# Device feedback (the office's desk phone and monitor, or the smartphone).
var _screen_mat: StandardMaterial3D             ## the main device's screen (monitor, or the phone screen)
var _screen_base_e := 0.7                       ## its glow when idle (per mood)
var _alert_label: Label3D
var _alert_label_y := 0.0
var _ring_label: Label3D
var _ring_label_y := 0.0
var _caller_tag: Label3D                        ## the caller's number shown under "RING!" while the phone rings
var _phone_screen: Label3D                      ## text on the phone's screen: caller ID, dialed digits, status
var _ring_player: AudioStreamPlayer3D
var _ringing := false
var _alert := false
var _ring_time := 0.0

# Smartphone only.
var _phone_model: Node3D
var _phone_rest: Transform3D


## The builder for `place` ("office", "home" or "cafe"); unknown places fall back to the office.
static func create(place: String) -> LocationBuilder:
	match place:
		"home":
			return HomeBuilder.new()
		"cafe":
			return CafeBuilder.new()
		"office":
			return OfficeBuilder.new()
	push_error("LocationBuilder.create: unknown place '%s', using the office" % place)
	return OfficeBuilder.new()


# ---------------------------------------------------------------- moods

## This place's moods: id -> mood dictionary. Overridden by each place.
func moods() -> Dictionary:
	return {}


## The mood used when an id is unknown (the place's first mood).
func default_mood() -> String:
	var keys: Array = moods().keys()
	return str(keys[0]) if not keys.is_empty() else ""


## Sets the lighting for chapter `n`: the chapter's "mood" id (Campaign data), or this place's first mood (with a
## warning) when the id is not one of this place's moods. Purely visual; safe to call any time.
func apply_chapter_mood(n: int) -> void:
	var count := Campaign.CHAPTERS.size()
	var i := clampi(n, 1, maxi(count, 1))
	var id := ""
	if count > 0:
		id = str(Campaign.chapter(i).get("mood", ""))
	if not moods().has(id):
		push_warning("%s: chapter %d mood '%s' is not one of the %s moods, using '%s'" % [name, i, id, location, default_mood()])
		id = default_mood()
	apply_mood(id)
	chapter_mood = i


## Applies a mood by id (an unknown id falls back to default_mood() with a warning).
func apply_mood(id: String) -> void:
	var all := moods()
	if not all.has(id):
		push_warning("%s: unknown mood '%s', using '%s'" % [name, id, default_mood()])
		id = default_mood()
	if not all.has(id):
		return
	mood_id = id
	_apply_mood(all[id])


## Applies one mood dictionary (overridden by each place).
func _apply_mood(_m: Dictionary) -> void:
	pass


# ---------------------------------------------------------------- device feedback (smartphone; the office overrides)

func is_ringing() -> bool:
	return _ringing


## Starts or stops the ring: the phone buzzes on the table, its screen flashes, a "RING!" label bobs and the one
## ringtone (Audio "phone_ring", SFX bus) plays on the same 3 s cadence. Calling it again with the current state
## does nothing, so the ring never restarts mid-ring.
func set_phone_ringing(on: bool) -> void:
	if _phone_model == null or on == _ringing:
		return
	_ringing = on
	_ring_time = 0.0
	_ring_label.visible = on
	_caller_tag.visible = on
	_ring_label.position.y = _ring_label_y
	_ring_label.scale = Vector3.ONE
	_phone_model.transform = _phone_rest
	if not on:
		_screen_mat.emission = C_PHONE_ALERT if _alert else C_PHONE_GLOW
		_screen_mat.emission_energy_multiplier = _screen_base_e + (0.1 if _alert else 0.0)
	if on and _ring_player.stream != null:
		_ring_player.play()
	elif not on:
		_ring_player.stop()


## New messages waiting on the phone: a brighter, pulsing screen and a "N new" label above it.
func set_monitor_alert(on: bool, count: int = 1) -> void:
	if _phone_model == null:
		return
	_alert_label.text = "%d new" % count
	if on == _alert:
		return
	_alert = on
	_alert_label.visible = on
	_alert_label.position.y = _alert_label_y
	if not _ringing:
		_screen_mat.emission = C_PHONE_ALERT if on else C_PHONE_GLOW
		_screen_mat.emission_energy_multiplier = _screen_base_e + (0.1 if on else 0.0)


## Text on the phone's screen (and under "RING!" while it rings): a caller ID, the digits dialed, a status.
func set_phone_display(text: String) -> void:
	if _phone_screen != null:
		_phone_screen.text = text
	if _caller_tag != null:
		_caller_tag.text = text


func phone_display() -> String:
	return _phone_screen.text if _phone_screen != null else ""


## The nodes the walking people give way to (the player).
func set_walker_obstacles(nodes: Array[Node3D]) -> void:
	for w: PersonWalker in walkers:
		w.obstacles = nodes


# ---------------------------------------------------------------- smartphone

## The player's smartphone lying on a table at `pos` (table-top height) under `parent`, top of the screen turned
## `yaw_deg` from -Z. Makes the Interactable `phone` (device_id "phone"), the screen glow, its labels and the
## ringtone, and sets monitor_point and phone_point to the screen centre.
func _build_smartphone(parent: Node3D, pos: Vector3, yaw_deg: float) -> void:
	_phone_model = _model(parent, "smartphone", pos, yaw_deg, "Smartphone")
	_phone_rest = _phone_model.transform
	_screen_mat = StandardMaterial3D.new()
	var tex := _phone_screen_texture()
	_screen_mat.albedo_texture = tex
	_screen_mat.albedo_color = C_PHONE_SCREEN
	_screen_mat.emission_enabled = true
	_screen_mat.emission_texture = tex
	_screen_mat.emission = C_PHONE_GLOW
	_screen_mat.emission_energy_multiplier = _screen_base_e
	_screen_mat.roughness = 0.25
	var screen := _phone_model.find_child("Screen", true, false) as MeshInstance3D
	if screen != null:
		screen.material_override = _screen_mat
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Screen text, flat on the glass (readable from the player's side, +Z of the phone).
	_phone_screen = Label3D.new()
	_phone_screen.name = "PhoneScreen"
	_phone_screen.text = ""
	_phone_screen.font_size = 24
	_phone_screen.pixel_size = 0.00022
	_phone_screen.width = 260.0
	_phone_screen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phone_screen.modulate = Color("e8f1ff")
	_phone_screen.outline_size = 0
	_phone_screen.font = UIStyle.mono_font()
	_phone_screen.position = Vector3(0.0, 0.0124, 0.01)
	_phone_screen.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_phone_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_phone_screen.no_depth_test = false
	_phone_model.add_child(_phone_screen)
	# Labels above the phone (billboards, in the parent's space so they do not buzz with the phone).
	_alert_label_y = pos.y + 0.24
	_alert_label = _label3d(parent, "1 new", Vector3(pos.x, _alert_label_y, pos.z), 44, 0.0024, UIStyle.WARN, true, 12)
	_alert_label.visible = false
	_ring_label_y = pos.y + 0.34
	_ring_label = _label3d(parent, "RING!", Vector3(pos.x, _ring_label_y, pos.z), 48, 0.0026, UIStyle.DANGER, true, 14)
	_ring_label.visible = false
	_caller_tag = _label3d(parent, "", Vector3(pos.x, _ring_label_y - 0.11, pos.z), 34, 0.0021, Color("8ff0b0"), true, 12)
	_caller_tag.font = UIStyle.mono_font()
	_caller_tag.visible = false
	_ring_player = AudioStreamPlayer3D.new()
	_ring_player.name = "RingSound"
	_ring_player.stream = Audio.get_stream("phone_ring")
	_ring_player.bus = "SFX"
	_ring_player.position = pos
	_ring_player.unit_size = 4.0
	_ring_player.volume_db = -5.0
	parent.add_child(_ring_player)

	var sp := _space_of(_phone_model)
	phone = Interactable.new()
	phone.name = "Phone"
	phone.device_id = "phone"
	phone.prompt = "Use your phone"
	phone.set_box(Vector3(0.3, 0.12, 0.3))
	phone.highlight_nodes = [_phone_model]
	phone.transform = sp * Transform3D(Basis(), Vector3(0.0, 0.04, 0.0))
	_collision.add_child(phone)
	monitor_point = global_transform * (sp * Vector3(0.0, 0.012, -0.0025))
	phone_point = monitor_point


## Per-frame phone feedback (home and cafe call it from _process): the buzz and screen flash while ringing,
## the pulsing glow while messages wait, the bobbing labels.
func _phone_process(delta: float) -> void:
	if _phone_model == null:
		return
	if _ringing:
		_ring_time += delta
		var env := _ring_on_at(fmod(_ring_time, RING_PERIOD))
		var on := env > 0.5
		var buzz := Basis(Vector3.UP, sin(_ring_time * 71.0) * 0.07 * env)
		_phone_model.transform = Transform3D(_phone_rest.basis * buzz,
			_phone_rest.origin + Vector3(sin(_ring_time * 93.0) * 0.0018 * env, 0.0, cos(_ring_time * 83.0) * 0.0012 * env))
		_screen_mat.emission = C_PHONE_ALERT
		_screen_mat.emission_energy_multiplier = _screen_base_e + (1.6 if on else 0.2)
		_ring_label.position.y = _ring_label_y + sin(_ring_time * 7.0) * 0.03
		_ring_label.scale = Vector3.ONE * (1.12 if on else 1.0)
	elif _alert:
		var pulse := 0.5 + 0.5 * sin(_time * 3.2)
		_screen_mat.emission_energy_multiplier = lerpf(_screen_base_e + 0.1, _screen_base_e + 0.8, pulse)
		_alert_label.position.y = _alert_label_y + sin(_time * 2.4) * 0.015


## Stops the ringtone (scene change, quit, or the builder being swapped out).
func _stop_ring() -> void:
	_ringing = false
	if _ring_player != null:
		_ring_player.stop()


@warning_ignore("integer_division")
## A simple lock-screen picture for the smartphone: status bar, clock bar and app tiles.
func _phone_screen_texture() -> ImageTexture:
	var w := 36
	var h := 76
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y: int in h:
		img.fill_rect(Rect2i(0, y, w, 1), Color("1d3f78").lerp(Color("4a2f6e"), float(y) / float(h)))
	img.fill_rect(Rect2i(0, 0, w, 3), Color("0c1428"))
	img.fill_rect(Rect2i(8, 10, 20, 5), Color("dfe9ff"))
	var tiles: Array[Color] = [Color("3fa7d6"), Color("4caf6a"), Color("e3b04b"), Color("d64541"), Color("8a5cc2"), Color("f08a7e")]
	for i: int in 6:
		img.fill_rect(Rect2i(5 + (i % 3) * 10, 54 + (i / 3) * 10, 6, 6), tiles[i])
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- environment and lights

## The WorldEnvironment (flat background colour, colour ambient, filmic tone mapping, soft bloom on emissive parts).
func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("cfe0ee")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("fff1de")
	_env.ambient_light_energy = 0.45
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	# Soft bloom on emissive parts only (light panels, neon, city lights, monitors).
	_env.glow_enabled = true
	_env.glow_intensity = 0.2
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.1
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = _env
	add_child(we)


## A shadowless directional fill whose colour and angle carry the time of day (the rooms have no real openings,
## so a shadowed sun would only shade the whole interior).
func _build_sun(parent: Node3D) -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = Vector3(-62.0, -32.0, 0.0)
	_sun.light_color = Color("fff4e6")
	_sun.light_energy = 0.3
	_sun.shadow_enabled = false
	parent.add_child(_sun)


## The parts of a mood every place shares: background, ambient, glow and the sun.
func _apply_env_mood(m: Dictionary) -> void:
	_env.background_color = m.bg
	_env.ambient_light_color = m.ambient
	_env.ambient_light_energy = m.ambient_e
	_env.tonemap_exposure = m.get("exposure", 1.0)
	_env.glow_intensity = m.glow
	_sun.light_color = m.sun
	_sun.light_energy = m.sun_e
	_sun.rotation_degrees = m.sun_rot


## The Visual and Collision roots and the two static bodies (room shell, furniture).
func _build_roots() -> void:
	_visual = _node(self, "Visual")
	_collision = _node(self, "Collision")
	_room_body = _body("Room")
	_furniture_body = _body("Furniture")


## A simple box room centred on the origin (x -w/2..w/2, z -d/2..d/2, floor at 0, ceiling at h) with colliders:
## floor material `floor_mat`, `walls` = colours [north, south, west, east], a flat ceiling. `door` (x centre,
## width, height) cuts an opening in the south wall when its width is above zero. Returns the Room node.
func _build_shell(w: float, d: float, h: float, floor_mat: Material, walls: Array[Color], ceiling: Color,
		door: Vector3 = Vector3.ZERO) -> Node3D:
	var t := 0.2
	var g := _node(_visual, "Room")
	var hw := w * 0.5
	var hd := d * 0.5
	var floor_mi := _box(g, Vector3(w, 0.1, d), Vector3(0.0, -0.05, 0.0), Color.WHITE)
	floor_mi.material_override = floor_mat
	_box(g, Vector3(w, 0.1, d), Vector3(0.0, h + 0.05, 0.0), ceiling, 0.95)
	_solid(_room_body, Vector3(w + 0.4, 0.2, d + 0.4), Vector3(0.0, -0.1, 0.0))
	_solid(_room_body, Vector3(w + 0.4, 0.2, d + 0.4), Vector3(0.0, h + 0.1, 0.0))
	_shell_wall(g, Vector3(w + 2.0 * t, h, t), Vector3(0.0, h * 0.5, -hd - t * 0.5), walls[0])
	_shell_wall(g, Vector3(t, h, d), Vector3(-hw - t * 0.5, h * 0.5, 0.0), walls[2])
	_shell_wall(g, Vector3(t, h, d), Vector3(hw + t * 0.5, h * 0.5, 0.0), walls[3])
	var sz := hd + t * 0.5
	if door.y <= 0.0:
		_shell_wall(g, Vector3(w + 2.0 * t, h, t), Vector3(0.0, h * 0.5, sz), walls[1])
	else:
		var dl := door.x - door.y * 0.5
		var dr := door.x + door.y * 0.5
		var lw := dl + hw + t
		var rw := hw + t - dr
		_shell_wall(g, Vector3(lw, h, t), Vector3(dl - lw * 0.5, h * 0.5, sz), walls[1])
		_shell_wall(g, Vector3(rw, h, t), Vector3(dr + rw * 0.5, h * 0.5, sz), walls[1])
		_shell_wall(g, Vector3(door.y, h - door.z, t), Vector3(door.x, (h + door.z) * 0.5, sz), walls[1])
		_solid(_room_body, Vector3(door.y, door.z, t), Vector3(door.x, door.z * 0.5, sz))     # the closed door
	return g


func _shell_wall(parent: Node3D, size: Vector3, center: Vector3, color: Color) -> void:
	_box(parent, size, center, color, 0.9)
	_solid(_room_body, size, center)


## A skirting board (or any low strip) along a wall from `a` to `b` at floor level; `inward` points into the room.
func _strip(parent: Node3D, a: Vector3, b: Vector3, inward: Vector3, height: float, thick: float, color: Color,
		y0: float = 0.0) -> void:
	var length := a.distance_to(b)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var size := Vector3(length, height, thick) if along_x else Vector3(thick, height, length)
	var mi := _box(parent, size, (a + b) * 0.5 + inward * (thick * 0.5) + Vector3(0.0, y0 + height * 0.5, 0.0), color, 0.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## An omni light (no shadow unless asked) under `parent`.
func _omni(parent: Node3D, n: String, pos: Vector3, color: Color, energy: float, light_range: float,
		attenuation: float = 1.0, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = attenuation
	l.shadow_enabled = shadow
	l.shadow_blur = 1.5
	parent.add_child(l)
	return l


## The surface material named `mat_name` on any mesh under `root`, swapped for one shared duplicate per place
## (so a mood can recolour every copy at once). `shared` holds the duplicates by name.
func _shared_surface(root: Node, mat_name: String, shared: Dictionary) -> StandardMaterial3D:
	for c: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if src != null and src.resource_name == mat_name:
				if not shared.has(mat_name):
					shared[mat_name] = src.duplicate() as StandardMaterial3D
				mi.set_surface_override_material(s, shared[mat_name])
	return shared.get(mat_name) as StandardMaterial3D


## A small screen picture (UI-like blocks) for TVs and laptops, shown with an emissive material.
func _picture_material(top: Color, body: Color, accent: Color) -> StandardMaterial3D:
	var w := 64
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(body)
	img.fill_rect(Rect2i(0, 0, w, 6), top)
	for i: int in 5:
		img.fill_rect(Rect2i(4, 10 + i * 5, 22 + (i * 13) % 20, 2), body.darkened(0.35))
	img.fill_rect(Rect2i(40, 10, 20, 16), accent)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(0.3, 0.32, 0.36)
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.5
	m.roughness = 0.3
	return m


## Puts `mat` on the "Screen" child of a model (TV, laptop), without shadows.
func _set_screen(model: Node3D, mat: Material) -> void:
	var screen := model.find_child("Screen", true, false) as MeshInstance3D
	if screen != null:
		screen.material_override = mat
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Places a seated person on a chair facing `yaw_deg` (0 = facing -Z): the chair model and the person share the
## transform (the people are modelled to drop into a chair). Returns the person.
func _seated(parent: Node3D, chair_file: String, person_file: String, pos: Vector3, yaw_deg: float,
		pose: PersonIdle.Pose, seed_value: int) -> Node3D:
	_model(parent, chair_file, pos, yaw_deg)
	var p := _person(parent, person_file, pos, yaw_deg, pose, seed_value)
	var idle := p.get_node_or_null("Idle") as PersonIdle
	if idle != null:
		idle.fixed_seat = true
	_solid(_furniture_body, Vector3(0.5, 1.0, 0.5), Vector3(0.0, 0.5, 0.0), p)
	return p


# ---------------------------------------------------------------- windows and the clock

## A window unit: day and night views (one shown per mood) share unshaded copies of the view materials, so the
## mood can recolour the sky and landscape for the time of day. `file` is the window model.
func _window(parent: Node3D, pos: Vector3, file: String = "window", yaw_deg: float = 0.0) -> Node3D:
	var w := _model(parent, file, pos, yaw_deg)
	for view_name: String in ["ViewDay", "ViewNight"]:
		var view := w.find_child(view_name, true, false) as MeshInstance3D
		if view == null:
			continue
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s: int in view.mesh.get_surface_count():
			var src := view.mesh.surface_get_material(s) as StandardMaterial3D
			var key := src.resource_name
			if not _view_mats.has(key):
				var m := src.duplicate() as StandardMaterial3D
				_view_base[key] = src.albedo_color
				if key == "CityLights":
					m.emission_enabled = true          # stays shaded + emissive so the lights bloom
				else:
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					m.emission_enabled = false
				_view_mats[key] = m
			view.set_surface_override_material(s, _view_mats[key])
		if view_name == "ViewDay":
			_views_day.append(view)
		else:
			_views_night.append(view)
	return w


## Recolours the window views for the mood: a tinted day landscape, or the night (dusk) palette.
func _apply_view(m: Dictionary) -> void:
	var day: bool = m.view == "day"
	for v: Node3D in _views_day:
		v.visible = day
	for v: Node3D in _views_night:
		v.visible = not day
	for key: String in _view_mats:
		var mat := _view_mats[key] as StandardMaterial3D
		var base: Color = _view_base[key]
		var c := base
		if day:
			var tint: Color = m.tint
			c = Color(base.r * tint.r, base.g * tint.g, base.b * tint.b)
			if key == "SkyTop":
				c = m.sky_top
			elif key == "SkyHorizon":
				c = m.sky_hor
		else:
			match key:
				"NightSky": c = m.night_sky
				"NightHorizon": c = m.night_hor
				"NightMountain": c = m.night_mtn
				"NightSea": c = m.night_sea
				"CityNight": c = m.city
				"NightGround": c = m.get("ground", m.city)
		mat.albedo_color = c
		if key == "CityLights":
			mat.emission = base
			mat.emission_energy_multiplier = m.get("lights_e", 3.0)


## A wall clock whose hands show the mood's time (see _update_clock).
func _wall_clock(parent: Node3D, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var clock := _model(parent, "wall_clock", pos, yaw_deg)
	for hand: String in ["HourHand", "MinuteHand", "SecondHand"]:
		var h := clock.find_child(hand, true, false) as Node3D
		if h != null:
			_clock_hands.append(h)
	return clock


func _update_clock() -> void:
	if _clock_hands.size() < 3:
		return
	var hours := _clock_base + _time / 3600.0
	var minutes := fmod(hours, 1.0) * 60.0
	_clock_hands[0].rotation.z = -TAU * fmod(hours, 12.0) / 12.0
	_clock_hands[1].rotation.z = -TAU * minutes / 60.0
	_clock_hands[2].rotation.z = -TAU * floorf(fmod(_time + 17.0, 60.0)) / 60.0


# ---------------------------------------------------------------- models

## Instances res://assets/models/<file>.glb under `parent` at `pos`, turned `yaw_deg` about Y. A missing model is
## reported and replaced by an empty Node3D, so a place still builds.
func _model(parent: Node3D, file: String, pos: Vector3, yaw_deg: float = 0.0, n: String = "") -> Node3D:
	var scene := load(MODELS + file + ".glb") as PackedScene
	var inst: Node3D = null
	if scene != null:
		inst = scene.instantiate() as Node3D
	if inst == null:
		push_error("LocationBuilder: missing model %s%s.glb" % [MODELS, file])
		inst = Node3D.new()
		inst.name = file
	if n != "":
		inst.name = n
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	parent.add_child(inst)
	return inst


## The child of `parent` instanced from assets/models/<file>.glb (null if none).
func _child_from(parent: Node, file: String) -> Node3D:
	for c: Node in parent.get_children():
		if c.scene_file_path.ends_with("/" + file + ".glb"):
			return c as Node3D
	return null


## A decorative person (not interactive) with subtle idle motion. `swivel` turns with them (a seated
## worker's chair).
func _person(parent: Node3D, file: String, pos: Vector3, yaw_deg: float, pose: PersonIdle.Pose, seed_value: int,
		swivel: Array[Node3D] = []) -> Node3D:
	var p := _model(parent, file, pos, yaw_deg)
	var idle := PersonIdle.new(pose, seed_value)
	idle.name = "Idle"
	idle.swivel = swivel
	p.add_child(idle)
	return p


## A lamp model whose LampBulb glow follows the mood (one shared bulb material per place).
func _lamp(parent: Node3D, pos: Vector3, yaw_deg: float, file: String = "desk_lamp") -> Node3D:
	var lamp := _model(parent, file, pos, yaw_deg)
	var bulb := lamp.find_child("LampBulb", true, false) as MeshInstance3D
	if bulb == null:
		return lamp
	if _lamp_bulb_mat == null:
		_lamp_bulb_mat = (bulb.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	bulb.material_override = _lamp_bulb_mat
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lamp


func _no_shadow(root: Node) -> void:
	for c: Node in root.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


@warning_ignore("integer_division")
## A tiled material (world-space triplanar) from a generated 2 x 2 tile texture with grout lines.
func _tile_material(a: Color, b: Color, grout: Color, tile: float, roughness: float) -> StandardMaterial3D:
	var n := 32
	var img := Image.create(n * 2, n * 2, false, Image.FORMAT_RGB8)
	for y: int in n * 2:
		for x: int in n * 2:
			var c := a if ((x / n) + (y / n)) % 2 == 0 else b
			if x % n == 0 or y % n == 0:
				c = grout
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / (tile * 2.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = roughness
	return m


# ---------------------------------------------------------------- helpers

func _node(parent: Node, n: String) -> Node3D:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	return node


func _group(parent: Node3D, n: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var node := _node(parent, n)
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	return node


func _body(n: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = n
	body.collision_layer = 1
	body.collision_mask = 0
	_collision.add_child(body)
	return body


## Adds a box collider to `body`. `center` is in the space of `ref` (or the builder when null).
func _solid(body: StaticBody3D, size: Vector3, center: Vector3, ref: Node3D = null) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var t := Transform3D(Basis(), center)
	if ref != null:
		t = _space_of(ref) * t
	cs.transform = t
	body.add_child(cs)


## Transform of `node` relative to this builder.
func _space_of(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		var n3 := n as Node3D
		if n3 != null:
			t = n3.transform * t
		n = n.get_parent()
	return t


## A standing pose at `pos` (feet) looking toward `target` on the horizontal plane.
func _facing(pos: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis(), pos).looking_at(Vector3(target.x, pos.y, target.z), Vector3.UP)


func _mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), roughness]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_mats[key] = m
	return m


func _emissive(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = energy
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, roughness: float = 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, roughness)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness: float = 0.85) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, m, pos, color, roughness)


func _label3d(parent: Node3D, text: String, pos: Vector3, font_size: int, pixel: float, color: Color, billboard: bool, outline: int = 10) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0.04, 0.06, 0.09, 0.9)
	l.position = pos
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- ring tone

## Ring cadence envelope (0..1) at time `p` within the period: two short rings, then a pause.
func _ring_on_at(p: float) -> float:
	var fade := 0.015
	for seg: Vector2 in [Vector2(0.0, 0.4), Vector2(0.6, 1.0)]:
		if p >= seg.x and p < seg.y:
			return clampf(minf(p - seg.x, seg.y - p) / fade, 0.0, 1.0)
	return 0.0
