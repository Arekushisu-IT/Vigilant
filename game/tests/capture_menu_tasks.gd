extends SceneTree
## Captures the main-menu HOW TO PLAY panel and an unsafe coworker game over for the audit (run without --headless).
const OUT := "res://tests/shots/tasks/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(1.2).timeout
	current_scene.call("_on_instructions")
	await create_timer(0.5).timeout
	await _shot("t00_menu_instructions")
	for s: Node in current_scene.find_children("*", "ScrollContainer", true, false):
		(s as ScrollContainer).scroll_vertical = 100000
	await create_timer(0.3).timeout
	await _shot("t00b_menu_instructions_scrolled")
	# Game over from the Ch1 coworker's unsafe advice (item override text).
	var game := root.get_node("/root/Game")
	game.start_new_game()
	change_scene_to_file("res://scenes/office.tscn")
	await create_timer(1.0).timeout
	var office := current_scene
	var t0 := Time.get_ticks_msec()
	while office.debug_state() != "ACTIVE" and Time.get_ticks_msec() - t0 < 30000:
		if office.debug_state() in ["INTRO", "BRIEFING"]:
			office.debug_advance()
		await process_frame
	await office.debug_interact("workstation")
	await create_timer(0.4).timeout
	for id: String in ["c1_orientation", "c1_benefits", "c1_voucher"]:
		office.debug_select_item(id)
		await process_frame
		var it: Dictionary = Campaign.item(1, id)
		for k: String in it.required_inspections:
			office.debug_inspect(k)
		await process_frame
		var path: Array = [2, 1] if id == "c1_benefits" else [-1]
		var si := 0
		while not office.session.is_done(id):
			var st: Dictionary = office.session.step()
			if st.get("kind", "") == "checklist":
				var r: Array[int] = []
				for i: int in st.options.size():
					if st.options[i].real:
						r.append(i)
				office.debug_check(r)
			else:
				var idx := 0
				for i: int in st.choices.size():
					if st.choices[i].outcome == "correct":
						idx = i
						break
				if id == "c1_benefits" and office.session.step_index == 0:
					idx = 2
				office.debug_choose(idx)
			await create_timer(0.3).timeout
			office.debug_advance()
			await create_timer(0.3).timeout
			si += 1
			if si > 6:
				break
	office.debug_select_item("c1_coworker")
	for k: String in Campaign.item(1, "c1_coworker").required_inspections:
		office.debug_inspect(k)
	await process_frame
	office.debug_choose(1)
	await create_timer(0.4).timeout
	office.debug_advance()
	await create_timer(1.0).timeout
	await _shot("t57_compromise_notice")
	t0 = Time.get_ticks_msec()
	while office.debug_state() != "GAME_OVER" and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
	await create_timer(0.6).timeout
	await _shot("t58_game_over_coworker_override")
	print("score at game over ", game.score)
	quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)
