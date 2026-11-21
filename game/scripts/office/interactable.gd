class_name Interactable
extends StaticBody3D
## A device the player can use with E (Objective 1): the workstation or the telephone in the office, or the
## player's smartphone at home and in the cafe (device_id "phone"); also the pantry and notice board (feel only).
## It is only a collision box on layer 3 (bit value 4) that the player's ray hits; its meshes live under the place's Visual node.
## The office director decides when it is enabled and which prompts it shows.

signal interacted(device_id: String)

@export var device_id: String = ""      ## "workstation", "telephone" or "phone" (plus "coffee", "water", "board")
var prompt: String = ""                 ## e.g. "Use workstation"; shown as "[E] <prompt>" when enabled
var disabled_prompt: String = ""        ## shown without "[E]" when disabled (usually the current objective); may be empty
var enabled: bool = false
## The device's meshes (under the office's Visual node) that glow softly while the player looks at it enabled.
var highlight_nodes: Array[Node3D] = []

var _shape: CollisionShape3D
var _highlighted := false

static var _glow: ShaderMaterial


func _init() -> void:
	collision_layer = 4
	collision_mask = 0
	_shape = CollisionShape3D.new()
	_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	_shape.shape = box
	add_child(_shape)


## Sizes the collision box to the object. `offset` is the box centre relative to this body.
func set_box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	(_shape.shape as BoxShape3D).size = size
	_shape.position = offset


## The interaction prompt the HUD shows while the player looks at this device.
func prompt_text() -> String:
	if enabled:
		return "[E] " + prompt
	return disabled_prompt


## Called by the office when E is pressed while the player looks at this device.
func interact() -> void:
	if enabled:
		interacted.emit(device_id)


func is_highlighted() -> bool:
	return _highlighted


## Soft rim glow on the device's meshes (a material_overlay, so the meshes' own materials are untouched).
func set_highlight(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	var mat: Material = glow_material() if on else null
	for n: Node3D in highlight_nodes:
		if not is_instance_valid(n):
			continue
		var meshes: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
		if n is MeshInstance3D:
			meshes.append(n)
		for m: Node in meshes:
			(m as MeshInstance3D).material_overlay = mat


## Shared glow: an additive, unshaded fresnel rim with a slow breathing pulse (about 0.5 Hz).
static func glow_material() -> ShaderMaterial:
	if _glow == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec3 glow_color : source_color = vec3(0.45, 0.82, 1.0);
uniform float strength = 0.45;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float pulse = 0.82 + 0.18 * sin(TIME * 3.0);
	ALBEDO = glow_color * (0.07 + rim * 0.95) * strength * pulse;
}
"""
		_glow = ShaderMaterial.new()
		_glow.shader = sh
	return _glow
