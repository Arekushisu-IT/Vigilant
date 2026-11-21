class_name Pantry
extends Node3D
## The pantry corner's usable things (E): the coffee maker and the water dispenser. Art and feel only: they never
## score, never touch the chapter and work in every chapter. The notice board next to them opens NoticeBoard.
## Coffee: "Brew coffee" (the pot fills with a drip, steam and a brewing gurgle; the light glows red then green),
## then "Pour a cup of coffee" (the level drops), and round again. Water: a paper cup drops onto the tray, fills
## under the cold tap, and is taken away. A short floating line ("Fresh coffee is ready.") says what happened.
## The effects are built in code on top of the Blender models, in each model's own space.

const BREW_TIME := 4.5
const POUR_TIME := 1.2
const WATER_TIME := 2.2
const LEVEL_LOW := 0.06           ## coffee height in the pot (m): what the model shows
const LEVEL_FULL := 0.115
const POT_BOTTOM := 0.957         ## counter space
const POT_XZ := Vector2(-0.42, 0.03)
const BREW_HEAD_Y := 1.205        ## bottom of the coffee maker's head
const TAP := Vector3(-0.05, 0.725, 0.172)    ## the cold tap's nozzle (dispenser space)
const CUP_BOTTOM := 0.593

enum { EMPTY, BREWING, FULL, POURING }

var coffee_machine: Interactable
var water_cooler: Interactable

var _counter: Node3D
var _dispenser: Node3D
var _coffee := EMPTY
var _water_busy := false
var _level := LEVEL_LOW
var _fill: MeshInstance3D
var _drip: MeshInstance3D
var _steam: CPUParticles3D
var _led: MeshInstance3D
var _led_mat: StandardMaterial3D
var _cup: MeshInstance3D
var _cup_water: MeshInstance3D
var _stream: MeshInstance3D
var _brews := 0
var _cups := 0


## Builds the effects on the counter and dispenser models and the two interactables (added to `collision`).
func setup(counter: Node3D, dispenser: Node3D, collision: Node3D, counter_space: Transform3D, dispenser_space: Transform3D) -> void:
	_counter = counter
	_dispenser = dispenser
	var coffee_col := _mat(Color("4a2c1a"), 0.2)
	_fill = _cyl(counter, 0.052, 0.05, coffee_col, "CoffeeFill")
	_clearer_glass(counter)
	_drip = _cyl(counter, 0.0035, 0.0035, coffee_col, "CoffeeDrip")
	_drip.visible = false
	_set_level(LEVEL_LOW)
	_led_mat = _mat(Color("1a1a1a"), 0.4)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color.BLACK
	_led = MeshInstance3D.new()
	_led.name = "BrewLight"
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.008
	led_mesh.height = 0.016
	_led.mesh = led_mesh
	_led.material_override = _led_mat
	_led.position = Vector3(POT_XZ.x + 0.07, 0.937, 0.124)
	counter.add_child(_led)
	_steam = _make_steam()
	_steam.position = Vector3(POT_XZ.x, 1.28, 0.0)      # rises from the top of the machine
	counter.add_child(_steam)

	_cup = _cyl(dispenser, 0.03, 0.022, _mat(Color("f2efe6"), 0.8), "PaperCup")
	_cup.scale = Vector3(1.0, 0.07, 1.0)
	_cup.position = Vector3(TAP.x, CUP_BOTTOM + 0.035, TAP.z)
	_cup.visible = false
	var water_mat := _mat(Color("6fb8ee"), 0.1)
	_cup_water = _cyl(dispenser, 0.027, 0.027, water_mat, "CupWater")
	_cup_water.scale = Vector3(1.0, 0.004, 1.0)
	_cup_water.visible = false
	_stream = _cyl(dispenser, 0.0035, 0.0035, water_mat, "WaterStream")
	_stream.scale = Vector3(1.0, 0.065, 1.0)
	_stream.position = Vector3(TAP.x, TAP.y - 0.0325, TAP.z)
	_stream.visible = false

	coffee_machine = Interactable.new()
	coffee_machine.name = "CoffeeMaker"
	coffee_machine.device_id = "coffee"
	coffee_machine.set_box(Vector3(0.3, 0.42, 0.3))
	# No rim glow here: on the whole counter it would wash out the glass pot and hide the coffee level.
	coffee_machine.transform = counter_space * Transform3D(Basis(), Vector3(POT_XZ.x, 1.1, POT_XZ.y))
	collision.add_child(coffee_machine)
	water_cooler = Interactable.new()
	water_cooler.name = "WaterDispenser"
	water_cooler.device_id = "water"
	water_cooler.set_box(Vector3(0.36, 0.5, 0.36))
	water_cooler.highlight_nodes = [dispenser]
	water_cooler.transform = dispenser_space * Transform3D(Basis(), Vector3(0.0, 0.72, 0.05))
	collision.add_child(water_cooler)
	_refresh()


## What E on the coffee maker or the water dispenser does. Returns false when it is busy.
func use(device_id: String) -> bool:
	match device_id:
		"coffee":
			if _coffee == EMPTY:
				_brew()
				return true
			if _coffee == FULL:
				_pour()
				return true
		"water":
			if not _water_busy:
				_pour_water()
				return true
	return false


func coffee_state() -> int:
	return _coffee


func coffee_level() -> float:
	return _level


func is_water_busy() -> bool:
	return _water_busy


func brews() -> int:
	return _brews


func cups() -> int:
	return _cups


func _brew() -> void:
	_coffee = BREWING
	_refresh()
	Audio.play_3d("coffee_brew", _counter.global_transform * Vector3(POT_XZ.x, 1.1, POT_XZ.y), -4.0)
	_set_led(Color("ff5a3a"))
	_drip.visible = true
	_steam.emitting = true
	var tw := create_tween()
	tw.tween_method(_set_level, _level, LEVEL_FULL, BREW_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_drip.visible = false
		_coffee = FULL
		_brews += 1
		_set_led(Color("5ee08a"))
		_refresh()
		_float("Fresh coffee is ready.", _counter, Vector3(POT_XZ.x, 1.42, POT_XZ.y)))
	tw.tween_interval(6.0)
	tw.tween_callback(func() -> void: _steam.emitting = false)


func _pour() -> void:
	_coffee = POURING
	_refresh()
	Audio.play_3d("coffee_pour", _counter.global_transform * Vector3(POT_XZ.x, 1.1, POT_XZ.y), -4.0)
	var tw := create_tween()
	tw.tween_method(_set_level, _level, LEVEL_LOW, POUR_TIME)
	tw.tween_callback(func() -> void:
		_coffee = EMPTY
		_cups += 1
		_set_led(Color.BLACK)
		_refresh()
		_float("Ahh, a good cup of coffee.", _counter, Vector3(POT_XZ.x, 1.42, POT_XZ.y)))


func _pour_water() -> void:
	_water_busy = true
	_refresh()
	Audio.play_3d("water_pour", _dispenser.global_transform * TAP, -4.0)
	_cup.visible = true
	_cup_water.visible = true
	_set_cup_water(0.0)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void: _stream.visible = true)
	tw.tween_method(_set_cup_water, 0.0, 1.0, WATER_TIME - 0.5)
	tw.tween_callback(func() -> void:
		_stream.visible = false
		_float("Nice and cold.", _dispenser, Vector3(0.0, 1.0, 0.25)))
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:
		_cup.visible = false
		_cup_water.visible = false
		_water_busy = false
		_refresh())


## Sets the coffee height in the pot and keeps the drip running from the brew head down to it.
func _set_level(h: float) -> void:
	_level = h
	_fill.scale = Vector3(1.0, h, 1.0)
	_fill.position = Vector3(POT_XZ.x, POT_BOTTOM + h * 0.5, POT_XZ.y)
	var top := POT_BOTTOM + h
	var len := BREW_HEAD_Y - top
	_drip.scale = Vector3(1.0, len, 1.0)
	_drip.position = Vector3(POT_XZ.x, top + len * 0.5, POT_XZ.y)


func _set_cup_water(u: float) -> void:
	_cup_water.position = Vector3(TAP.x, CUP_BOTTOM + 0.006 + 0.055 * u, TAP.z)
	var r := lerpf(0.82, 1.0, u)                     # the cup widens toward the rim
	_cup_water.scale = Vector3(r, 0.004, r)


func _set_led(c: Color) -> void:
	_led_mat.emission = c
	_led_mat.emission_energy_multiplier = 0.0 if c == Color.BLACK else 3.0


func _refresh() -> void:
	if coffee_machine != null:
		coffee_machine.enabled = _coffee == EMPTY or _coffee == FULL
		coffee_machine.prompt = "Brew coffee" if _coffee == EMPTY else "Pour a cup of coffee"
		coffee_machine.disabled_prompt = "Brewing..." if _coffee == BREWING else "Pouring..."
	if water_cooler != null:
		water_cooler.enabled = not _water_busy
		water_cooler.prompt = "Get a cup of water"
		water_cooler.disabled_prompt = "Filling the cup..."


## Makes the pot's glass (and the jars) see-through enough to show the coffee level.
func _clearer_glass(model: Node3D) -> void:
	for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i: int in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as StandardMaterial3D
			if src != null and src.resource_name == "Glass":
				var g := src.duplicate() as StandardMaterial3D
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.albedo_color.a = 0.18
				g.cull_mode = BaseMaterial3D.CULL_BACK
				m.set_surface_override_material(i, g)


## A short line that floats up from the thing and fades out.
func _float(text: String, parent: Node3D, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 30
	l.pixel_size = 0.0018
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 0.25, 2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(1.4)
	tw.chain().tween_callback(l.queue_free)


func _make_steam() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Steam"
	p.amount = 16
	p.lifetime = 1.8
	p.emitting = false
	p.local_coords = false
	var m := SphereMesh.new()
	m.radius = 0.014
	m.height = 0.028
	m.radial_segments = 6
	m.rings = 3
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(1, 1, 1, 0.45)
	m.material = sm
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.02
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.12
	p.gravity = Vector3(0.0, 0.06, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.25, Color(1, 1, 1, 0.55))
	p.color_ramp = g
	return p


## A unit-height cylinder (scaled on y to its height) in `parent`'s space.
func _cyl(parent: Node3D, top: float, bottom: float, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = 1.0
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
