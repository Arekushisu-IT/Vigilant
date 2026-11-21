extends SceneTree
## Game-feel screenshots (run WITHOUT --headless so the audio and rendering are real):
##   Godot --path <game> --script res://tests/capture_feel.gd
## Saves PNGs to res://tests/shots/feel/: the settings panel with the new sliders, the chapter title card, the
## interactable glow, the floating "+10" and the compromise flash. Prints "FEEL ..." lines for the audio state.

const OFFICE := "res://scenes/office.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const OUT := "res://tests/shots/feel/"

var game: Node
var audio: Node
var office: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	audio = root.get_node("/root/Audio")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _sec(0.5)

	# Main menu + Settings panel with the Music / Sound effects sliders.
	change_scene_to_file(MAIN_MENU)
	await _sec(1.2)
	current_scene.call("_on_settings")
	await _sec(0.6)
	await _shot("05_settings_sliders")
	print("FEEL menu music track=%s" % audio.current_track)

	# New game: intro, then the chapter 1 briefing with its title card.
	game.start_new_game()
	change_scene_to_file(OFFICE)
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("debug_state"))
	office = current_scene
	await _until(func() -> bool: return office.debug_state() == "INTRO")
	while office.debug_state() == "INTRO":
		office.debug_advance()
		await _sec(0.12)
	await _sec(0.9)
	await _shot("01_title_card")
	print("FEEL title card '%s' showing=%s state=%s" % [office.title_card.text(), office.title_card.is_showing(), office.debug_state()])
	while office.debug_state() != "ACTIVE":
		office.debug_advance()
		await _sec(0.12)
	await _sec(0.3)

	# Walk a little: head-bob and footsteps.
	var player: Node3D = office.player
	var cam: Camera3D = player.get_camera()
	Input.action_press("move_forward")
	var max_bob := 0.0
	for i: int in 50:
		await physics_frame
		max_bob = maxf(max_bob, cam.position.length())
	Input.action_release("move_forward")
	await _sec(0.6)
	print("FEEL head-bob max offset %.3f m, at rest %.3f m" % [max_bob, cam.position.length()])

	# Look at the workstation: soft glow.
	var b: Node = office.builder
	player.teleport(b.chapter_spawn)
	_look(player, b.monitor_point)
	await _sec(0.5)
	print("FEEL workstation highlighted=%s" % b.workstation.is_highlighted())
	await _shot("04_interactable_glow")

	# Score change: the floating "+10" and the pulse.
	game.apply_outcome("correct", 0, "capture")
	await _sec(0.32)
	await _shot("02_floating_score")
	await _sec(1.4)

	# Compromise: the red flash, shake and glitch bars at the start of the notice.
	office.compromise_notice.show_notice("Black Veil now has your account. (capture only)")
	await _sec(0.08)
	await _shot("03_compromise_flash")
	await office.compromise_notice.finished
	# Off the clock (home and cafe): the personal-loss notice, no Aegis header.
	office.compromise_notice.show_notice("Your KwartaPay balance was sent out within minutes. (capture only)", "home")
	await _sec(0.5)
	await _shot("03b_compromise_home")
	await office.compromise_notice.finished

	# Chapter 9 (QR Code Phishing, Fri 09:00 PM): the night track crossfades in.
	audio.set_music(audio.track_for_chapter(9))
	await _sec(3.0)
	var playing := 0
	for p: Node in audio.get_children():
		if p is AudioStreamPlayer and (p as AudioStreamPlayer).playing and (p as AudioStreamPlayer).bus == "Music":
			playing += 1
	print("FEEL music track=%s (expected night) music players playing=%d ambient wanted" % [audio.current_track, playing])
	if current_scene != null:
		current_scene.queue_free()
	await _sec(0.5)
	print("CAPTURE FEEL DONE")
	quit(0)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + shot_name + ".png")
	print("shot %s (%s) %s" % [shot_name, img.get_size(), "ok" if err == OK else "ERR %d" % err])


func _sec(t: float) -> void:
	await create_timer(t).timeout


func _until(cond: Callable, timeout: float = 15.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			print("TIMEOUT")
			return
		await process_frame


func _look(player: Node3D, target: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var to := target - head.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
