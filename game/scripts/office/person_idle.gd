class_name PersonIdle
extends Node
## Subtle idle motion for a decorative office worker (art only: never walks, never interacts). The people are
## rigid low-poly parts parented at their joints (no skeleton), so the motion is a small offset applied on top
## of each part's stored rest transform: breathing (chest scale), slow head turns, a slight weight shift and,
## per pose, typing hands, phone-call gestures or a glance at what the person holds. Each person gets its own
## phase and rates, so nobody moves in sync. Add it as a child of the person's model root.
## Seated workers also take short breaks: the typist leans back and stretches with hands behind the head now
## and then, and the worker on the phone swivels their chair (`swivel` holds the chair, turned with them).

enum Pose { STANDING, SEATED, TYPING, PHONE }

var pose: Pose = Pose.STANDING

var _t := 0.0
var _phase := 0.0
var _breath_rate := 1.5
var _turn_rate := 0.3
var _parts: Dictionary = {}          ## part name -> Node3D
var _rest: Dictionary = {}           ## part name -> Transform3D at rest
var _axis: Dictionary = {}           ## part name -> the model's X axis in the part's parent space
## Nodes turned together with the person when they swivel (their chair).
var swivel: Array[Node3D] = []
## When true, the PHONE pose never turns the person (or their chair): for someone seated at a fixed table.
var fixed_seat := false
var _swivel_base: Array[float] = []
var _body_yaw := 0.0


func _init(p: Pose = Pose.STANDING, seed_value: int = 0) -> void:
	pose = p
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_phase = rng.randf() * TAU
	_breath_rate = TAU / rng.randf_range(3.6, 4.8)
	_turn_rate = rng.randf_range(0.22, 0.38)
	_t = rng.randf() * 20.0


func _ready() -> void:
	var body := get_parent()
	for n: String in ["Torso", "Chest", "Head", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R"]:
		var part := body.find_child(n, true, false) as Node3D
		if part != null:
			_parts[n] = part
			_rest[n] = part.transform
			_axis[n] = (_model_basis(body, part.get_parent()).inverse() * Vector3.RIGHT).normalized()
	_body_yaw = (body as Node3D).rotation.y
	for n3: Node3D in swivel:
		_swivel_base.append(n3.rotation.y)
	set_process(_parts.has("Chest") and _parts.has("Head"))


## How far into a stretch break the typist is (0 = typing, 1 = fully stretched): 5 s every 26 s.
func stretch_weight() -> float:
	if pose != Pose.TYPING:
		return 0.0
	var c := fmod(_t + _phase * 4.0, 26.0)
	return smoothstep(0.0, 1.0, c) * (1.0 - smoothstep(4.0, 5.2, c))


func _process(delta: float) -> void:
	_t += delta
	var t := _t
	# Breathing: the chest swells slightly (arms and neck hang off Torso, so they stay attached).
	var b := sin(t * _breath_rate + _phase)
	var chest := _parts["Chest"] as Node3D
	chest.scale = (_rest["Chest"] as Transform3D).basis.get_scale() * Vector3(1.0 + 0.008 * b, 1.0 + 0.012 * b, 1.0 + 0.022 * b)
	# Head: slow look-around made of two sines, plus a small nod.
	var yaw := 0.07 * sin(t * _turn_rate + _phase * 1.7) + 0.03 * sin(t * _turn_rate * 2.9 + _phase)
	var pitch := 0.025 * sin(t * _turn_rate * 1.6 + _phase * 0.5)
	if pose == Pose.TYPING:
		yaw *= 0.45                                   # eyes stay on the screen
	elif pose == Pose.PHONE:
		pitch += 0.03 * sin(t * 1.9 + _phase)         # nodding along to the caller
	_offset("Head", Vector3(pitch, yaw, 0.0))
	# Torso: a slow weight shift when standing, a slight lean when seated.
	var sway := sin(t * 0.42 + _phase * 0.3)
	if pose == Pose.STANDING:
		_offset("Torso", Vector3(0.006 * b, 0.0, 0.012 * sway))
	else:
		_offset("Torso", Vector3(0.008 * b + 0.01 * sway, 0.0, 0.0))
	var w := stretch_weight()
	match pose:
		Pose.TYPING:
			# Typing in bursts: alternating wrist taps, quiet pauses in between (none during a stretch).
			var burst := smoothstep(-0.2, 0.3, sin(t * 0.55 + _phase)) * (1.0 - w)
			for i: int in 2:
				var side := "L" if i == 0 else "R"
				var tap := maxf(0.0, sin(t * 13.0 + float(i) * 2.1 + _phase)) * burst
				_offset("Hand_" + side, Vector3(0.16 * tap, 0.0, 0.0))
				_offset("Forearm_" + side, Vector3(0.035 * tap, 0.0, 0.0))
		Pose.PHONE:
			# The free (left) hand gestures now and then while talking.
			var talk := smoothstep(0.1, 0.6, sin(t * 0.35 + _phase))
			_offset("Forearm_L", Vector3(0.12 * talk * sin(t * 2.3), 0.0, 0.05 * talk))
			# Slowly swivels the chair while talking (not when seated at a fixed table).
			if not fixed_seat:
				var yaw_sw := 0.2 * sin(t * 0.23 + _phase) + 0.06 * sin(t * 0.61)
				(get_parent() as Node3D).rotation.y = _body_yaw + yaw_sw
				for i: int in swivel.size():
					swivel[i].rotation.y = _swivel_base[i] + yaw_sw
		_:
			# Slight forearm drift so held props (clipboard, papers, mug) are not frozen.
			var drift := 0.03 * sin(t * 0.7 + _phase * 1.3)
			_offset("Forearm_L", Vector3(drift, 0.0, 0.0))
			_offset("Forearm_R", Vector3(-drift * 0.8, 0.0, 0.0))
	if pose == Pose.TYPING:
		for side: String in ["UpperArm_L", "UpperArm_R"]:
			if _parts.has(side):
				(_parts[side] as Node3D).transform = _rest[side]
	if w > 0.0:
		# Stretch break (seated, facing -Z): lean back, chin up, arms raised so the hands go behind the head.
		_turn("Torso", 0.2 * w)
		_turn("Head", 0.18 * w)
		_turn("UpperArm_L", 2.3 * w)
		_turn("UpperArm_R", 2.3 * w)


## Turns a part (after its offset) about the model's left-right axis through its joint.
func _turn(part: String, angle: float) -> void:
	var node := _parts.get(part) as Node3D
	if node == null:
		return
	node.transform = Transform3D(Basis(_axis[part], angle) * node.transform.basis, node.transform.origin)


## Basis of `node` relative to the model root `body`.
static func _model_basis(body: Node, node: Node) -> Basis:
	var b := Basis()
	var n := node
	while n != null and n != body:
		var n3 := n as Node3D
		if n3 != null:
			b = n3.transform.basis * b
		n = n.get_parent()
	return b.orthonormalized()


## Rotates a part by a small local Euler offset (radians) on top of its rest transform.
func _offset(part: String, euler: Vector3) -> void:
	var node := _parts.get(part) as Node3D
	if node == null:
		return
	var rest: Transform3D = _rest[part]
	node.transform = Transform3D(rest.basis * Basis.from_euler(euler), rest.origin)
