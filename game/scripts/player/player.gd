class_name Player
extends CharacterBody3D
## First-person player (Objective 1, FR1): WASD walking, mouse look and an interaction ray.
## Yaw turns the body, pitch turns the Head. The ray only sees Interactables (layer 3, bit value 4).
## The office owns the mouse mode and the E key; the player only reports what it is looking at.

signal focus_changed(target: Interactable)
signal prompt_changed(text: String)

const WALK_SPEED := 3.5
const EYE_HEIGHT := 1.6
const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.75
const REACH := 2.2
const PITCH_LIMIT := 1.4835298641951802   ## 85 degrees in radians
const FOV := 75.0
const FOCUS_FOV := 62.0                     ## slight zoom while looking at the monitor or phone
## Game feel: a footstep sound every STRIDE metres walked and a gentle head-bob in step with it.
const STRIDE := 0.7
const BOB_DOWN := 0.022                     ## m the eye dips at each footfall
const BOB_SWAY := 0.012                     ## m of side sway per stride pair
const BOB_BLEND := 5.0                      ## how fast the bob fades in / out (per second)

## When false (an overlay is open): no movement input, no look and no prompt. Gravity still applies.
var controls_enabled: bool = true:
	set(value):
		controls_enabled = value
		if not value:
			velocity.x = 0.0
			velocity.z = 0.0
			_update_focus()

var _head: Node3D
var _camera: Camera3D
var _ray: RayCast3D
var _focused: Interactable = null
var _shown_prompt: String = "\u0001"        ## sentinel so the first prompt is always emitted
var _cam_tween: Tween
var _has_rest := false                      ## true while the camera is focused on a point
var _rest_yaw := 0.0
var _rest_pitch := 0.0
var _glowing: Interactable = null            ## the enabled device under the crosshair (soft highlight)
var _stride_dist := STRIDE * 0.5            ## metres since the last footstep (first step comes sooner)
var _bob_phase := 0.0
var _bob_amount := 0.0


func _init() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	col.shape = capsule
	col.position.y = CAPSULE_HEIGHT * 0.5
	add_child(col)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = EYE_HEIGHT
	add_child(_head)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = FOV
	_camera.near = 0.05
	_head.add_child(_camera)

	_ray = RayCast3D.new()
	_ray.name = "InteractRay"
	_ray.target_position = Vector3(0.0, 0.0, -REACH)
	_ray.collision_mask = 4
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	_camera.add_child(_ray)


func _ready() -> void:
	_camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	# screen_relative is not scaled by the canvas_items stretch, so the feel is the same at any window size.
	var turn := motion.screen_relative * Settings.mouse_radians_per_pixel()
	rotation.y -= turn.x
	_head.rotation.x = clampf(_head.rotation.x - turn.y, -PITCH_LIMIT, PITCH_LIMIT)
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var dir := Vector3.ZERO
	if controls_enabled:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = global_transform.basis * Vector3(input.x, 0.0, input.y)
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED
	move_and_slide()
	_update_steps(delta)
	_update_focus()


## Footsteps and head-bob from the distance actually walked (sliding along a wall still counts, pushing
## into one does not). The bob only moves the camera's local position, never the yaw / pitch the
## focus and release tweens drive.
func _update_steps(delta: float) -> void:
	var real := get_real_velocity()
	var speed := Vector2(real.x, real.z).length()
	var walking := controls_enabled and is_on_floor() and speed > 0.5
	_bob_amount = move_toward(_bob_amount, 1.0 if walking else 0.0, delta * BOB_BLEND)
	if walking:
		var step := speed * delta
		_stride_dist += step
		_bob_phase += step / STRIDE * PI
		if _stride_dist >= STRIDE:
			_stride_dist -= STRIDE
			Audio.play_sfx("footstep", randf_range(-15.0, -12.5), randf_range(0.88, 1.12))
	else:
		_stride_dist = minf(_stride_dist, STRIDE * 0.5)
	if _bob_amount <= 0.0:
		_camera.position = Vector3.ZERO
		return
	# Lowest at each footfall (phase = k * PI); one side-to-side sway every two steps.
	var dip := -BOB_DOWN * (cos(2.0 * _bob_phase) + 1.0) * 0.5
	_camera.position = Vector3(sin(_bob_phase) * BOB_SWAY, dip, 0.0) * _bob_amount


## The Interactable under the crosshair, or null.
func get_focus() -> Interactable:
	if _focused != null and not is_instance_valid(_focused):
		_focused = null
	return _focused


func get_camera() -> Camera3D:
	return _camera


## Places the player at xform's origin, facing along its -Z (yaw only). Pitch is set to `pitch` (radians,
## default level) and the zoom is reset.
func teleport(xform: Transform3D, pitch: float = 0.0) -> void:
	_finish_camera_tween()
	_has_rest = false
	var fwd := -xform.basis.z
	var yaw := atan2(-fwd.x, -fwd.z)
	if is_inside_tree():
		global_position = xform.origin
	else:
		position = xform.origin
	rotation = Vector3(0.0, yaw, 0.0)
	_head.rotation = Vector3(clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT), 0.0, 0.0)
	_camera.fov = FOV
	_camera.position = Vector3.ZERO
	_bob_amount = 0.0
	velocity = Vector3.ZERO
	_update_focus()


## Turns the body (yaw) and head (pitch) to look at a world point, e.g. when sitting at the monitor.
## Awaitable: returns when the tween ends.
func focus_camera_on(target: Vector3, duration: float) -> void:
	if not _has_rest:
		_rest_yaw = rotation.y
		_rest_pitch = _head.rotation.x
		_has_rest = true
	var to := target - _head.global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -PITCH_LIMIT, PITCH_LIMIT)
	await _tween_view(rotation.y + wrapf(yaw - rotation.y, -PI, PI), pitch, FOCUS_FOV, duration)


## Turns the view back to where the player was looking before focus_camera_on. Awaitable.
func release_camera(duration: float) -> void:
	if not _has_rest:
		return
	_has_rest = false
	var yaw := rotation.y + wrapf(_rest_yaw - rotation.y, -PI, PI)
	await _tween_view(yaw, _rest_pitch, FOV, duration)


func _tween_view(yaw: float, pitch: float, fov: float, duration: float) -> void:
	_finish_camera_tween()
	if duration <= 0.0:
		rotation.y = yaw
		_head.rotation.x = pitch
		_camera.fov = fov
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", yaw, duration)
	tween.tween_property(_head, "rotation:x", pitch, duration)
	tween.tween_property(_camera, "fov", fov, duration)
	_cam_tween = tween
	await tween.finished


## Jumps a running camera tween to its end so its awaiting caller resumes (never left hanging).
func _finish_camera_tween() -> void:
	if _cam_tween != null and _cam_tween.is_valid() and _cam_tween.is_running():
		_cam_tween.custom_step(1000.0)
	_cam_tween = null


## Re-evaluated every physics frame: catches a new target and a change of the target's prompt.
func _update_focus() -> void:
	if _ray == null:
		return
	var target: Interactable = null
	if controls_enabled and is_inside_tree():
		_ray.force_raycast_update()
		if _ray.is_colliding():
			target = _ray.get_collider() as Interactable
	if _focused != null and not is_instance_valid(_focused):
		_focused = null
	if target != _focused:
		_focused = target
		focus_changed.emit(target)
	# The soft glow follows the crosshair, only on a device that can be used now.
	var glow: Interactable = target if target != null and target.enabled else null
	if glow != _glowing:
		if _glowing != null and is_instance_valid(_glowing):
			_glowing.set_highlight(false)
		_glowing = glow
		if glow != null:
			glow.set_highlight(true)
	var text: String = target.prompt_text() if target != null else ""
	if text != _shown_prompt:
		_shown_prompt = text
		prompt_changed.emit(text)
