extends SceneTree
## Screenshots of the walking coworkers, the typist's stretch and the pantry (run without --headless).

var game: Node

func _initialize() -> void:
	game = root.get_node("Game")
	game.start_new_game()
	game.select_chapter(1, "")
	change_scene_to_file("res://scenes/office.tscn")
	var office: Node = await _active()
	office.tutorial.finish()
	var b: Variant = office.builder
	# Walkers: watch the printer coworker set off toward reception.
	for w: Variant in b.walkers:
		w.hurry()
	await _look(office, Vector3(2.6, 0.0, 0.9), Vector3(5.3, 0.9, -0.6))
	await create_timer(1.3).timeout
	await _shot("walk_1")
	await create_timer(0.35).timeout
	await _shot("walk_2")
	await create_timer(1.6).timeout
	await _shot("walk_3")
	# Typist's stretch break.
	var typist: Node3D = b.get_node("Visual/OfficeDesks/Desk2").find_child("Idle", true, false).get_parent()
	var idle: Variant = typist.get_node("Idle")
	idle._t = fposmod(2.5 - idle._phase * 4.0, 26.0)
	await _look(office, Vector3(1.3, 0.0, 0.1), Vector3(-0.05, 1.0, -0.85))
	await create_timer(0.4).timeout
	await _shot("typist_stretch")
	# Pantry: brewing, then water.
	await _look(office, Vector3(5.45, 0.0, 0.85), Vector3(6.7, 1.05, 0.55))
	await create_timer(0.3).timeout
	await _shot("pantry_idle")
	await _look(office, Vector3(5.95, 0.0, 0.3), Vector3(6.65, 1.02, 0.18))
	await create_timer(0.2).timeout
	await _shot("pot_idle")
	await office.debug_pantry("coffee")
	await create_timer(2.2).timeout
	await _shot("pot_brewing")
	await create_timer(2.8).timeout
	await _shot("pot_ready")
	await _look(office, Vector3(5.45, 0.0, 0.85), Vector3(6.7, 1.05, 0.55))
	await create_timer(0.2).timeout
	await _shot("pantry_ready")
	await office.debug_pantry("water")
	await create_timer(1.2).timeout
	await _look(office, Vector3(5.75, 0.0, 1.75), Vector3(6.7, 0.65, 1.72))
	await create_timer(0.1).timeout
	await _shot("water_pour")
	await office.debug_pantry("board")
	await create_timer(0.4).timeout
	await _shot("notice_board")
	print("LIFE SHOT OK")
	quit(0)


func _look(office: Node, feet: Vector3, target: Vector3) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var eye := feet + Vector3.UP * 1.6
	var to := target - eye
	var flat := Vector3(to.x, 0.0, to.z)
	office.player.teleport(Transform3D(Basis.looking_at(flat, Vector3.UP), feet), atan2(to.y, flat.length()))
	await office.player.focus_camera_on(target, 0.01)


func _active() -> Node:
	for i in 2400:
		await process_frame
		var o: Node = current_scene
		if o != null and o.has_method("debug_state"):
			if o.debug_state() == "ACTIVE":
				return o
			if o.dialogue.is_open() or o.outcome_panel.is_open():
				o.debug_advance()
	return current_scene


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/%s.png" % name)
