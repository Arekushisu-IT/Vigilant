extends SceneTree
## Screenshots of the tutorial steps, plus a real click on Skip and the Restart Chapter check (run without --headless).

var game: Node

func _initialize() -> void:
	game = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute("res://tests/shots/tutorial")
	game.start_new_game()
	change_scene_to_file("res://scenes/office.tscn")
	var office: Node = await _active()
	await _frames(20)
	await _shot("1_walk")
	office.player.global_position += Vector3(1, 0, 0)
	await _frames(10)
	await _shot("2_desk")
	office.debug_interact("workstation")
	await _frames(60)
	await _shot("3_sender")
	office.debug_inspect("sender")
	await _frames(20)
	await _shot("4_copy")
	office.session.clipboard = "https://intranet.aegis-solutions.example/hr/orientation"
	await _frames(20)
	await _shot("5_browser")
	office.desktop._select_app("browser")
	await _frames(20)
	await _shot("6_paste")
	office.desktop._paste()
	await _frames(20)
	await _shot("7_choose")

	# A real mouse click on Skip.
	var skip: Button = office.tutorial.find_child("TutorialSkip", true, false)
	var at: Vector2 = skip.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)
		await _frames(3)
	print("SKIP_CLICK active=", office.tutorial.is_active())

	# Restart Chapter must not bring it back.
	game.is_restart = true
	game.current_chapter = 1
	change_scene_to_file("res://scenes/office.tscn")
	await _frames(5)
	office = await _active()
	await _frames(10)
	print("AFTER_RESTART active=", office.tutorial.is_active())
	quit(0)


func _active() -> Node:
	for i in 1200:
		await process_frame
		var o: Node = current_scene
		if o != null and o.has_method("debug_state"):
			if o.debug_state() == "ACTIVE":
				return o
			if o.dialogue.is_open():
				o.debug_advance()
	push_error("never active")
	return current_scene


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/tutorial/%s.png" % name)
