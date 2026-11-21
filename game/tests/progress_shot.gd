extends SceneTree
## Screenshot of the pause menu Progress page in Chapter 3 (E-wallet Texts, at home on the phone; run without --headless).

func _initialize() -> void:
	var game: Node = root.get_node("Game")
	game.start_new_game()
	game.completed[0] = true
	game.completed[1] = true
	game.select_chapter(3, "")
	change_scene_to_file("res://scenes/office.tscn")
	var office: Node = null
	for i in 1500:
		await process_frame
		office = current_scene
		if office != null and office.has_method("debug_state"):
			if office.debug_state() == "ACTIVE":
				break
			if office.dialogue.is_open():
				office.debug_advance()
	await create_timer(0.5).timeout
	office.pause_menu.open()
	office.pause_menu._show_progress()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/pause_progress.png")
	print("PROGRESS SHOT OK")
	quit(0)
