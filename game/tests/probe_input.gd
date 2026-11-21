extends SceneTree
## Windowed probe of the real input path (E / ESC key events, raycast focus, mouse mode) in Chapter 1.
##   Godot --path <game> --script res://tests/probe_input.gd

const OFFICE := "res://scenes/office.tscn"
var office: Node
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var game := root.get_node("/root/Game")
	game.start_new_game()
	change_scene_to_file(OFFICE)
	await _until(func() -> bool: return current_scene != null and current_scene.has_method("debug_state"))
	office = current_scene
	# Intro and briefing with the real E key.
	var t0 := Time.get_ticks_msec()
	while office.debug_state() != "ACTIVE" and Time.get_ticks_msec() - t0 < 30000:
		await _key(KEY_E)
		await _sec(0.1)
	_check("reached ACTIVE with E", office.debug_state() == "ACTIVE")
	var b: Node = office.builder
	var player: Node3D = office.player
	player.teleport(b.chapter_spawn)
	_look(player, b.monitor_point)
	await _sec(0.4)
	_check("raycast focuses the workstation", player.get_focus() == b.workstation)
	_check("mouse captured in play", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	await _key(KEY_E)
	await _sec(0.8)
	_check("E opens the desktop", office.desktop.is_open())
	await _key(KEY_ESCAPE)
	await _sec(0.6)
	_check("ESC closes the desktop", not office.desktop.is_open())
	await _key(KEY_ESCAPE)
	await _sec(0.3)
	_check("ESC opens pause", office.pause_menu.is_open())
	_check("mouse visible in pause", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _key(KEY_ESCAPE)
	await _sec(0.3)
	_check("ESC resumes", not office.pause_menu.is_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	# Benefits email, verify route, real phone via E.
	_look(player, b.monitor_point)
	await _sec(0.3)
	await _key(KEY_E)
	await _sec(0.8)
	office.debug_select_item("c1_benefits")
	office.debug_inspect("sender")
	office.debug_inspect("link:c1_portal")
	office.debug_choose(1)
	await _sec(0.5)
	await _key(KEY_E)   # E continues the outcome panel
	await _sec(0.6)
	_check("E continued the outcome", not office.outcome_panel.is_open() and office.debug_state() == "ACTIVE")
	await _key(KEY_ESCAPE)
	await _sec(0.6)
	_look(player, b.phone_point)
	await _sec(0.4)
	_check("raycast focuses the telephone", player.get_focus() == b.telephone)
	print("phone prompt: ", b.telephone.prompt_text())
	await _key(KEY_E)
	await _sec(0.7)
	_check("E places the HR call", office.call_ui.is_open())
	await _key(KEY_E)   # skip playback
	await _sec(0.2)
	_check("E skips the call playback", not bool(office.call_ui.get("_playing")))
	await _key(KEY_ESCAPE)
	await _sec(0.3)
	_check("ESC does not hang up", office.call_ui.is_open())
	_check("ESC does not open pause during a call", not office.pause_menu.is_open())
	office.debug_choose(1)   # wrong: leave it in the inbox
	await _sec(0.4)
	await _key(KEY_ESCAPE)   # ESC continues the outcome panel
	await _sec(0.4)
	_check("ESC continued the wrong outcome; call still open", office.call_ui.is_open() and office.debug_state() == "ACTIVE")
	_check("mouse visible during the call", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	office.debug_choose(0)   # report
	await _sec(0.4)
	await _key(KEY_E)
	await _sec(1.0)
	_check("back at the desk on the checklist", office.desktop.is_open() and office.session.is_checklist())
	print("PROBE DONE, fails ", fails)
	quit(0)


func _check(label: String, ok: bool) -> void:
	print("CHECK %s %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		fails += 1


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up)
	await process_frame


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
