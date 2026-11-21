class_name PersonWalker
extends Node
## Makes a decorative coworker walk the office on a fixed loop of stops (art only: never interacts, never
## scores). Each stop is a place to stand and do something for a while (make coffee, read the whiteboard,
## drop papers); between stops the person walks a fixed path that never crosses furniture.
## The people are rigid low-poly parts parented at their joints (no skeleton), so the walk is procedural: the
## thighs swing, the knees bend during each swing, the arms swing opposite the legs and the body dips so the
## feet stay on the floor. PersonIdle (breathing, head turns) keeps running on the other parts.
## The person stops and waits when the player (or another walker) is right in front of them, and says
## "Excuse me" if the player keeps blocking the way. A moving collider stops the player walking through them.
## Add it as a child of the person's model root; the route is in the space of the model's parent.

signal arrived(stop_index: int)

const SPEED := 1.0               ## m/s
const STEP_LEN := 0.52           ## m per step (two steps per walk cycle)
const TURN_SPEED := 3.0          ## rad/s
const LEG_SWING := 0.34          ## rad at full stride
const KNEE_BEND := 0.55          ## rad at mid-swing
const ARM_SWING := 0.2           ## rad
const BLOCK_DIST := 1.05         ## m: someone this close in front makes the walker wait
const EXCUSE_AFTER := 1.4        ## s blocked by the player before saying "Excuse me"

enum { WALK, WAIT }

## Stops: {"at": Vector3, "face": float (yaw, radians; the model faces +Z), "wait": float (s),
## "via": Array[Vector3] (waypoints before reaching "at")}.
var route: Array[Dictionary] = []
## Nodes to give way to (the player; other walkers are found through `others`).
var obstacles: Array[Node3D] = []
var others: Array[PersonWalker] = []

var _body: Node3D
var _parts: Dictionary = {}       ## part name -> Node3D
var _rest: Dictionary = {}        ## part name -> Transform3D
var _axis: Dictionary = {}        ## part name -> the model's X axis in the part's parent space
var _state := WAIT
var _stop := 0
var _path: Array[Vector3] = []
var _wait_left := 0.0
var _phase := 0.0
var _amp := 0.0
var _ground := 0.0
var _leg_len := 0.85
var _blocked := false
var _blocked_time := 0.0
var _said := false
var _bubble: Label3D
var _bubble_left := 0.0
var _last_step := 0
var _distance := 0.0              ## total metres walked (tests)
var _walker_wait := 0.0           ## s spent waiting for another walker
var _ghost := 0.0                 ## s left during which other walkers are ignored (breaks a rare standoff)


func _init(stops: Array[Dictionary] = [], start_wait: float = 2.0) -> void:
	route = stops
	_wait_left = start_wait


func _ready() -> void:
	_body = get_parent() as Node3D
	_ground = _body.position.y
	for n: String in ["Hips", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "UpperArm_L", "UpperArm_R"]:
		var part := _body.find_child(n, true, false) as Node3D
		if part == null:
			continue
		_parts[n] = part
		_rest[n] = part.transform
		_axis[n] = (_model_basis(part.get_parent()).inverse() * Vector3.RIGHT).normalized()
	if _parts.has("Hips"):
		_leg_len = clampf(_model_origin(_parts["Hips"]).y * 0.98, 0.5, 1.1)
	if not route.is_empty():
		var first: Dictionary = route[0]
		_body.position = Vector3(first.at.x, _ground, first.at.z)
		_body.rotation.y = float(first.face)
	_bubble = Label3D.new()
	_bubble.name = "ExcuseMe"
	_bubble.text = "Excuse me!"
	_bubble.font_size = 40
	_bubble.pixel_size = 0.0026
	_bubble.outline_size = 10
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0.0, 2.02, 0.0)
	_bubble.visible = false
	_body.add_child.call_deferred(_bubble)
	set_process(not route.is_empty())


func is_walking() -> bool:
	return _state == WALK and not _blocked


func is_blocked() -> bool:
	return _blocked


func current_stop() -> int:
	return _stop


func distance_walked() -> float:
	return _distance


## Skips the current wait (tests and captures).
func hurry() -> void:
	_wait_left = 0.0


func _process(delta: float) -> void:
	var moving := false
	_blocked = false
	if _state == WAIT:
		var stop: Dictionary = route[_stop]
		_turn_toward(float(stop.face), delta)
		_wait_left -= delta
		if _wait_left <= 0.0:
			_stop = (_stop + 1) % route.size()
			var next: Dictionary = route[_stop]
			_path.clear()
			for p: Vector3 in next.get("via", []):
				_path.append(p)
			_path.append(next.at)
			_state = WALK
	else:
		var target := _path[0]
		var to := Vector3(target.x - _body.position.x, 0.0, target.z - _body.position.z)
		var dist := to.length()
		if dist < 0.04:
			_path.pop_front()
			if _path.is_empty():
				_state = WAIT
				_wait_left = float(route[_stop].get("wait", 5.0))
				arrived.emit(_stop)
		else:
			var diff := _turn_toward(atan2(to.x, to.z), delta)
			_blocked = _someone_ahead()
			if not _blocked:
				var spd := SPEED * clampf(1.0 - absf(diff) / 1.1, 0.0, 1.0)
				var step := minf(spd * delta, dist)
				if step > 0.0:
					_body.position += to / dist * step
					_phase += step / STEP_LEN * PI
					_distance += step
					moving = true
				elif absf(diff) > 0.05:
					_phase += delta * 4.0          # small steps while turning on the spot
					moving = true
	_update_bubble(delta)
	_amp = move_toward(_amp, 1.0 if moving else 0.0, delta * 4.0)
	_pose()


## Turns the body toward `yaw` at TURN_SPEED. Returns the angle still left to turn.
func _turn_toward(yaw: float, delta: float) -> float:
	var diff := wrapf(yaw - _body.rotation.y, -PI, PI)
	_body.rotation.y += clampf(diff, -TURN_SPEED * delta, TURN_SPEED * delta)
	return wrapf(yaw - _body.rotation.y, -PI, PI)


## True when the player or another walker stands just ahead. Two walkers facing each other do not both wait:
## the one created first goes on.
func _someone_ahead() -> bool:
	var fwd := Vector3(sin(_body.rotation.y), 0.0, cos(_body.rotation.y))
	var by_player := false
	for o: Node3D in obstacles:
		if is_instance_valid(o) and o.is_inside_tree() and _ahead(o.global_position, fwd):
			by_player = true
	if by_player:
		_blocked_time += get_process_delta_time()
		if _blocked_time > EXCUSE_AFTER and not _said:
			_said = true
			_bubble_left = 2.2
		return true
	_blocked_time = 0.0
	_said = false
	if _ghost > 0.0:
		_ghost -= get_process_delta_time()
		return false
	for w: PersonWalker in others:
		if w == self or not is_instance_valid(w) or w._body == null:
			continue
		if _ahead(w._body.global_position, fwd):
			if w.is_blocked() and get_instance_id() < w.get_instance_id():
				continue
			_walker_wait += get_process_delta_time()
			if _walker_wait > 3.0:
				_walker_wait = 0.0
				_ghost = 1.5
			return true
	_walker_wait = 0.0
	return false


func _ahead(world_pos: Vector3, fwd: Vector3) -> bool:
	var rel := world_pos - _body.global_position
	rel.y = 0.0
	var d := rel.length()
	return d < BLOCK_DIST and d > 0.01 and rel.dot(fwd) / d > 0.45


func _update_bubble(delta: float) -> void:
	if _bubble == null:
		return
	_bubble_left = maxf(0.0, _bubble_left - delta)
	_bubble.visible = _bubble_left > 0.0


## The walk cycle on top of each part's rest transform.
func _pose() -> void:
	var a := _amp
	var s := sin(_phase)
	var c := cos(_phase)
	var thigh := LEG_SWING * s * a
	_swing("Thigh_L", -thigh)                         # left leg forward while s > 0
	_swing("Thigh_R", thigh)
	_swing("Shin_L", KNEE_BEND * maxf(0.0, c) * a)    # the knee bends while that leg swings forward
	_swing("Shin_R", KNEE_BEND * maxf(0.0, -c) * a)
	_swing("UpperArm_L", ARM_SWING * s * a)           # arms swing opposite the legs
	_swing("UpperArm_R", -ARM_SWING * s * a)
	# Dip so the planted foot stays on the floor while the legs are spread.
	_body.position.y = _ground - _leg_len * (1.0 - cos(thigh))
	# A footstep sound each time a foot lands.
	var step_i := int(floor(_phase / PI))
	if step_i != _last_step:
		_last_step = step_i
		if a > 0.5:
			Audio.play_3d("footstep", _body.global_position, -20.0, randf_range(0.9, 1.1))


## Rotates a part about the model's left-right axis through its joint (positive = its far end goes back).
func _swing(part: String, angle: float) -> void:
	var node := _parts.get(part) as Node3D
	if node == null:
		return
	var rest: Transform3D = _rest[part]
	node.transform = Transform3D(Basis(_axis[part], angle) * rest.basis, rest.origin)


## Position of `node` relative to the model root.
func _model_origin(node: Node3D) -> Vector3:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != _body:
		var n3 := n as Node3D
		if n3 != null:
			t = n3.transform * t
		n = n.get_parent()
	return t.origin


## Basis of `node` relative to the model root.
func _model_basis(node: Node) -> Basis:
	var b := Basis()
	var n := node
	while n != null and n != _body:
		var n3 := n as Node3D
		if n3 != null:
			b = n3.transform.basis * b
		n = n.get_parent()
	return b.orthonormalized()
