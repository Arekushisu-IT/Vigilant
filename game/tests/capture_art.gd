extends SceneTree
## Art capture of the three low-poly places (office, home, cafe) for every chapter mood. Run WITHOUT --headless:
##   Godot --path <game> --script res://tests/capture_art.gd
## For chapters 1..10 builds the chapter's place on its own (LocationBuilder.create(chapter.place), no office
## director and no UI), applies the chapter's mood, waits for the lighting to settle and saves:
##   chN_desk.png  from chapter_spawn toward the chapter's device (the office monitor or the smartphone)
##   chN_room.png  a wide view of the place (office: from the entrance; home: from the door; cafe: from a corner)
## plus close-ups (detail_*.png): the office people and corners in Chapter 1, the condo's balcony door and the
## smartphone with new messages and ringing in Chapter 3, the cafe's counter, customers and street in Chapter 8.
## Sound is muted while capturing. Output: res://tests/shots/art/.

const OUT := "res://tests/shots/art/"
const EYE_HEIGHT := 1.6                  ## Player.EYE_HEIGHT (the player script uses autoloads, so it is not loaded here)

## Wide views per place: [camera position, look-at point, fov].
const ROOM_VIEWS: Dictionary = {
	"office": [Vector3(4.6, 1.7, 4.45), Vector3(-0.8, 0.35, -2.2), 72.0],
	"home": [Vector3(1.9, 1.7, 2.2), Vector3(-0.7, 0.55, -1.5), 78.0],
	"cafe": [Vector3(-4.1, 1.85, 2.6), Vector3(1.4, 0.8, -1.6), 76.0],
}

var location_builder: Variant            ## LocationBuilder (loaded at run time: it uses the Audio autoload)
var campaign: Variant
var builder: Node3D
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	location_builder = load("res://scripts/world/location_builder.gd")
	campaign = load("res://data/campaign.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0, true)
	print("window ", root.get_visible_rect().size)

	var count: int = campaign.CHAPTERS.size()
	for n: int in range(1, 11):
		if n > count:
			print("ch%d: no chapter data (only %d chapters)" % [n, count])
			continue
		var place := str(campaign.chapter(n).get("place", "office"))
		await _build(place)
		builder.apply_chapter_mood(n)
		await _sec(1.0)
		print("ch%d %s mood %s (chapter_mood %d)" % [n, place, builder.mood_id, builder.chapter_mood])
		var eye: Vector3 = builder.chapter_spawn.origin + Vector3.UP * EYE_HEIGHT
		var target: Vector3 = builder.monitor_point
		if place == "office":
			target += Vector3(0.0, -0.05, 0.0)
		_aim(eye, target, 75.0)
		await _shot("ch%d_desk" % n)
		var v: Array = ROOM_VIEWS.get(place, ROOM_VIEWS["office"])
		_aim(v[0], v[1], v[2])
		await _shot("ch%d_room" % n)
		match n:
			1: await _office_details()
			3: await _home_details()
			8: await _cafe_details()
	AudioServer.set_bus_mute(0, false)
	quit()


## Replaces the current place with a fresh builder for `place`.
func _build(place: String) -> void:
	if builder != null and is_instance_valid(builder):
		builder.queue_free()
		await process_frame
	cam = null
	builder = location_builder.create(place)
	builder.name = "Builder"
	root.add_child(builder)
	await process_frame


## Close-ups of the office people and corners (Chapter 1 lighting).
func _office_details() -> void:
	_aim(Vector3(3.2, 1.55, 3.0), Vector3(1.28, 1.25, 3.0), 60.0)
	await _shot("detail_dela_vega")
	_aim(Vector3(1.3, 1.45, 0.4), Vector3(-0.1, 0.95, -0.9), 60.0)
	await _shot("detail_typist")
	_aim(Vector3(-3.6, 1.45, 0.4), Vector3(-5.0, 0.95, -0.9), 60.0)
	await _shot("detail_phone")
	_aim(Vector3(4.2, 1.6, 0.6), Vector3(6.3, 1.1, -1.0), 70.0)
	await _shot("detail_printer_pantry")
	_aim(Vector3(-2.0, 1.6, 2.5), Vector3(-6.0, 1.3, 0.8), 70.0)
	await _shot("detail_west_wall")
	_aim(Vector3(2.0, 1.6, -1.0), Vector3(5.5, 1.0, 3.5), 70.0)
	await _shot("detail_pantry_door")
	_aim(Vector3(-3.3, 1.0, -0.6), Vector3(-5.05, 0.7, -0.75), 60.0)
	await _shot("detail_phone_side")


## The condo: the balcony door, the living corner and the smartphone's feedback (Chapter 3 lighting).
func _home_details() -> void:
	_aim(Vector3(-0.2, 1.55, 1.2), Vector3(1.2, 1.25, -2.5), 70.0)
	await _shot("detail_home_balcony")
	_aim(Vector3(0.6, 1.5, -0.4), Vector3(-2.0, 0.6, 1.4), 72.0)
	await _shot("detail_home_living")
	_aim(Vector3(-0.2, 1.6, 0.2), Vector3(2.6, 0.9, 0.6), 70.0)
	await _shot("detail_home_kitchen")
	await _phone_feedback("home")


## The cafe: the counter with the barista, the customers and the street (Chapter 8 lighting).
func _cafe_details() -> void:
	_aim(Vector3(0.6, 1.6, 0.9), Vector3(1.0, 1.3, -2.6), 68.0)
	await _shot("detail_cafe_counter")
	_aim(Vector3(0.4, 1.55, 2.2), Vector3(3.0, 0.9, 0.4), 66.0)
	await _shot("detail_cafe_customers")
	_aim(Vector3(-2.2, 1.5, -0.3), Vector3(-3.4, 0.95, -0.6), 62.0)
	await _shot("detail_cafe_laptop")
	_aim(Vector3(0.6, 1.6, -0.2), Vector3(-1.4, 1.3, 3.0), 72.0)
	await _shot("detail_cafe_street")
	await _phone_feedback("cafe")


## The smartphone up close: idle, with new messages ("N new" and the brighter screen), and ringing.
func _phone_feedback(place: String) -> void:
	var p: Vector3 = builder.phone_point
	var eye: Vector3 = builder.chapter_spawn.origin + Vector3.UP * EYE_HEIGHT
	var from := p + (eye - p).normalized() * 0.75
	_aim(from, p + Vector3(0.0, 0.08, 0.0), 60.0)
	await _shot("detail_%s_phone" % place)
	builder.set_monitor_alert(true, 2)
	await _sec(0.3)
	await _shot("detail_%s_phone_alert" % place)
	builder.set_monitor_alert(false)
	builder.set_phone_display("MOBILE\n09XX-XXX-7781")
	builder.set_phone_ringing(true)
	await _sec(0.2)
	await _shot("detail_%s_phone_ring" % place)
	builder.set_phone_ringing(false)
	builder.set_phone_display("")


## Puts a free camera at `from` looking at `to`.
func _aim(from: Vector3, to: Vector3, fov: float) -> void:
	if cam == null or not is_instance_valid(cam):
		cam = Camera3D.new()
		cam.name = "ArtCaptureCamera"
		cam.near = 0.05
		builder.add_child(cam)
	cam.fov = fov
	cam.global_transform = Transform3D(Basis(), from).looking_at(to, Vector3.UP)
	cam.make_current()


func _shot(shot_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + shot_name + ".png")
	print("shot %s (%s) %s" % [shot_name, img.get_size(), "ok" if err == OK else "ERR %d" % err])


func _sec(t: float) -> void:
	await create_timer(t).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
