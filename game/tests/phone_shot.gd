extends SceneTree
## Screenshots of the desk phone keypad and the phone screen (run without --headless).

var game: Node

func _initialize() -> void:
	game = root.get_node("Game")
	# Placed call: Chapter 1, verify the benefits email by calling HR.
	game.start_new_game()
	game.select_chapter(1, "c1_benefits")
	change_scene_to_file("res://scenes/office.tscn")
	var office: Node = await _active()
	office.tutorial.finish()
	await office.debug_interact("workstation")
	await create_timer(0.6).timeout
	office.debug_select_item("c1_benefits")
	var st: Dictionary = office.session.step()
	var dir := -1
	for i in st.choices.size():
		if st.choices[i].has("opens"):
			dir = i
	office.debug_inspect("sender")
	office.debug_inspect("link:c1_portal")
	office.debug_choose(dir)
	office = await _active()
	if office.desktop.is_open():
		office.desktop.handle_back()
	await create_timer(0.8).timeout
	await office.debug_interact("telephone")
	await create_timer(0.6).timeout
	office.dial_pad.press("1")
	office.dial_pad.press("3")
	office.dial_pad.press("0")
	await create_timer(0.3).timeout
	await _shot("phone_dialing")
	# Incoming call: Chapter 4 (Vishing), the fake IT call shows its outside number on the phone screen.
	game.select_chapter(4, "c3_mark")
	change_scene_to_file("res://scenes/office.tscn")
	office = await _active()
	await create_timer(1.0).timeout
	await office.player.focus_camera_on(office.builder.phone_point, 0.4)
	await create_timer(0.6).timeout
	print("PHONE SCREEN: ", office.builder.phone_display())
	await _shot("phone_ringing")
	print("PHONE SHOT OK")
	quit(0)


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
