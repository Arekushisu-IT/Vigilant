extends SceneTree
## Playability capture (run WITHOUT --headless). Drives the game mostly with REAL input events
## (Viewport.push_input mouse clicks at the controls' centres, key presses) so blocked buttons,
## ESC routing and mouse-mode bugs show up. Saves PNGs to res://tests/shots/play_<res>/.
## Covers the menu, the intro, walking, pause, Chapter 1 at the workstation, the smartphone at home (Chapter 3:
## KwartaPay History and Inbox; Chapter 5: the bank agent's call coming in while the phone is in hand, Answer, the
## keypad), the desk phone in Chapter 4 (wrong, ESC, unsafe, game over, Restart Chapter) and the ending.
##   Godot --path <game> --script res://tests/capture_play.gd            (1280x720)
##   Godot --path <game> --script res://tests/capture_play.gd -- 1080    (1920x1080 window)

const OFFICE := "res://scenes/office.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const ENDING := "res://scenes/ending.tscn"

var out_dir := "res://tests/shots/play_720/"
var game: Node
var router: Node
var problems: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	router = root.get_node("/root/Router")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var want := Vector2i(1280, 720)
	if OS.get_cmdline_user_args().has("1080"):
		want = Vector2i(1920, 1080)
		out_dir = "res://tests/shots/play_1080/"
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(want)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	await _sec(0.5)
	print("screen ", DisplayServer.screen_get_size(), " window ", DisplayServer.window_get_size(), " root ", root.size, " visible ", root.get_visible_rect().size)

	# ---------------- main menu (real clicks)
	change_scene_to_file(MAIN_MENU)
	await _sec(1.2)
	await _shot("01_main_menu")
	await _click_button(current_scene, "Settings")
	await _sec(0.3)
	_expect(_visible_class(current_scene, "SettingsPanel"), "main menu: Settings button opens the panel (real click)")
	await _shot("02_main_settings")
	await _key(KEY_ESCAPE)
	_expect(not _visible_class(current_scene, "SettingsPanel"), "main menu: ESC closes Settings")
	await _click_button(current_scene, "Instructions")
	await _sec(0.3)
	await _shot("03_main_instructions")
	await _click_button(current_scene, "Back")
	await _sec(0.2)
	await _click_button(current_scene, "Fun Facts")
	await _sec(0.3)
	_expect(_visible_class(current_scene, "FunFactsPanel"), "main menu: Fun Facts button opens the page (real click)")
	await _shot("03b_main_fun_facts")
	await _key(KEY_ESCAPE)
	await _sec(0.2)
	# Play opens Chapter Select; Chapter 1 is open on a new game.
	await _click_button(current_scene, "Play")
	await _sec(0.5)
	await _shot("03c_chapter_select")
	await _click_button(current_scene, "Play chapter  ▶")
	var office: Node = await _wait_office(null)
	print("mouse mode at office load: ", Input.mouse_mode)

	# ---------------- intro
	await _until(func() -> bool: return office.debug_state() == "INTRO")
	await _sec(1.4)
	await _shot("04_intro_dialogue")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "intro: mouse visible while dialogue open")
	# advance with real keys and a real click
	var guard := 0
	while office.debug_state() in ["INTRO", "BRIEFING"] and guard < 60:
		guard += 1
		if guard % 3 == 0:
			await _click_at(Vector2(640, 200))
		else:
			await _key(KEY_E)
		await _sec(0.05)
	_expect(office.debug_state() == "ACTIVE", "intro+briefing advanced with real E/click (state %s)" % office.debug_state())
	await _sec(0.3)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "ACTIVE: mouse captured (mode %d)" % Input.mouse_mode)
	await _shot("05_active_intro_spawn")

	var player: Node3D = office.player
	var b: Node = office.builder
	var spawn: Transform3D = b.chapter_spawn
	var mp: Vector3 = b.monitor_point

	# ---------------- walking: forward from the intro spawn toward the desk, wall test
	player.teleport(_facing(b.intro_spawn.origin, mp))
	await _sec(0.3)
	await _shot("06_walk_view_toward_desk")
	var p0: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _sec(1.5)
	Input.action_release("move_forward")
	await _sec(0.2)
	var p1: Vector3 = player.global_position
	print("walked from ", p0, " to ", p1, " dist ", p0.distance_to(p1))
	_expect(p0.distance_to(p1) > 2.0, "walking: W moves the player (%.2f m in 1.5 s)" % p0.distance_to(p1))
	_expect(absf(p1.y) < 0.05, "walking: stays on the floor (y %.3f)" % p1.y)
	await _shot("07_after_walking")
	# west wall
	player.teleport(Transform3D(Basis(), Vector3(-5.8, 0, 2.5)).looking_at(Vector3(-10, 0, 2.5), Vector3.UP))
	Input.action_press("move_forward")
	await _sec(1.5)
	Input.action_release("move_forward")
	_expect(player.global_position.x > -7.0 + 0.3, "walls: west wall stops the player (x %.2f)" % player.global_position.x)
	# out the door
	player.teleport(Transform3D(Basis(), Vector3(4.5, 0, 3.9)).looking_at(Vector3(4.5, 0, 9), Vector3.UP))
	Input.action_press("move_forward")
	await _sec(1.5)
	Input.action_release("move_forward")
	_expect(player.global_position.z < 5.0, "walls: closed door stops the player (z %.2f)" % player.global_position.z)

	# ---------------- prompt at the desk
	player.teleport(spawn)
	await _sec(0.3)
	var prompt_flat := _hud_prompt(office)
	print("prompt at chapter_spawn (yaw only, pitch 0): '%s'" % prompt_flat)
	await _shot("08_chapter_spawn_no_pitch")
	_look(player, mp)
	await _sec(0.3)
	var prompt := _hud_prompt(office)
	_expect(prompt == "[E] Use workstation", "prompt looking at monitor: '%s'" % prompt)
	await _shot("09_desk_prompt")
	_look(player, b.phone_point)
	await _sec(0.3)
	print("prompt looking at phone in ch1: '%s'" % _hud_prompt(office))

	# ---------------- pause menu with real ESC and clicks
	_look(player, mp)
	await _sec(0.1)
	await _key(KEY_ESCAPE)
	await _sec(0.2)
	_expect(office.pause_menu.is_open(), "ESC while walking opens pause")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause: mouse visible")
	await _shot("10_pause")
	await _click_button(office.pause_menu, "Instructions")
	await _sec(0.2)
	await _shot("11_pause_instructions")
	await _key(KEY_ESCAPE)
	_expect(office.pause_menu.is_open(), "ESC in pause sub-panel goes back to the pause page (still open)")
	await _click_button(office.pause_menu, "Settings")
	await _sec(0.2)
	await _shot("12_pause_settings")
	await _click_button(office.pause_menu, "Back")
	await _click_button(office.pause_menu, "Main Menu")
	await _sec(0.2)
	await _shot("13_pause_confirm")
	await _click_button(office.pause_menu, "No, stay")
	await _click_button(office.pause_menu, "Resume")
	await _sec(0.2)
	_expect(not office.pause_menu.is_open(), "Resume closes pause")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "after resume: mouse captured (%d)" % Input.mouse_mode)

	# ---------------- chapter 1 desktop with real E (the genuine orientation email)
	await _key(KEY_E)
	await _sec(0.7)
	_expect(office.desktop.is_open(), "real E on the workstation opens the desktop")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "desktop: mouse visible")
	await _shot("14_mail_locked")
	var c1o: Dictionary = Campaign.item(1, "c1_orientation")
	await _click_button_prefix(office.desktop, str(c1o.message.from_name) + "  ")
	await _sec(0.2)
	_expect(office.session.inspected.has("sender"), "real click on sender reveals it")
	await _shot("15_mail_sender_revealed")
	# link popup at the mouse
	var body := _find_rich_with(office.desktop, "[url=c1_agenda]")
	var at := body.get_global_rect().position + Vector2(120, body.get_global_rect().size.y - 40)
	root.warp_mouse(at)
	await _sec(0.15)
	body.meta_clicked.emit("c1_agenda")
	await _sec(0.2)
	var menu: PopupMenu = office.desktop.find_children("*", "PopupMenu", true, false)[0]
	print("popup visible ", menu.visible, " at ", menu.position, " size ", menu.size, " mouse wanted ", at, " root mouse ", root.get_mouse_position())
	_expect(menu.visible and Vector2(menu.position).distance_to(at) < 12.0, "link popup opens at the mouse (%s vs %s)" % [menu.position, at])
	await _shot("16_link_popup")
	# click the item for real
	await _click_at(Vector2(menu.position) + Vector2(menu.size) * 0.5)
	await _sec(0.2)
	_expect(office.session.clipboard != "", "real click on 'Copy link address' copies (clipboard '%s')" % office.session.clipboard)
	_expect(not menu.visible, "popup closes after choosing")
	await _shot("17_toast_copied")
	# popup near the bottom-right corner clamps on screen
	var vp := root.get_visible_rect().size
	root.warp_mouse(vp - Vector2(5, 5))
	await _sec(0.15)
	office.desktop.call("_open_link_menu", "c1_agenda")
	await _sec(0.2)
	_expect(Rect2(Vector2.ZERO, vp).encloses(Rect2(Vector2(menu.position), Vector2(menu.size))), "popup near corner stays on screen (%s %s)" % [menu.position, menu.size])
	await _key(KEY_ESCAPE)
	await _sec(0.1)
	print("after ESC with popup: popup visible ", menu.visible, " desktop open ", office.desktop.is_open())
	if not office.desktop.is_open():
		problems.append("ESC while the link popup is open also closed the desktop")
		await _key(KEY_E)
		await _sec(0.7)
	# Ctrl+V real key
	await _key(KEY_V, true)
	await _sec(0.3)
	_expect(office.session.pasted_url != "", "Ctrl+V pastes (pasted '%s')" % office.session.pasted_url)
	await _shot("18_browser_pasted")
	_expect(office.session.gate_open(), "gate open after real inspections")
	# real click on the correct choice (handle the genuine email normally)
	await _click_button(office.desktop, "Open the agenda link and keep the email for Thursday")
	await _sec(0.4)
	_expect(office.outcome_panel.is_open(), "real click on a choice shows the outcome")
	await _shot("19_outcome_correct")
	await _click_button(office.outcome_panel, "Continue")
	var saw_capture := false
	for i in 40:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			saw_capture = true
		if office.debug_state() == "ACTIVE" and not office._busy:
			break
		await process_frame
	if saw_capture and office.desktop.is_open():
		problems.append("mouse flips to CAPTURED between the outcome Continue and the desktop (cursor recentred)")
	await _sec(0.4)
	await _shot("20_ch1_next_item")
	await _key(KEY_ESCAPE)
	await _sec(0.5)
	_expect(not office.desktop.is_open(), "ESC closes the desktop")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "after leaving the desk: mouse captured")

	# ---------------- chapter 3 at home: the smartphone and KwartaPay (Chapter Select jump)
	game.select_chapter(3)
	change_scene_to_file(OFFICE)
	office = await _wait_office(office)
	await _advance_dialogue(office)
	await _sec(0.5)
	player = office.player
	b = office.builder
	_expect(office.debug_place() == "home", "chapter 3 is at home (%s)" % office.debug_place())
	print("ch3 prompt at the phone: '%s'" % _hud_prompt(office))
	_expect(_hud_prompt(office) == "[E] Check your phone", "home spawn looks at the phone: '%s'" % _hud_prompt(office))
	await _shot("21_home_spawn_phone")
	await _key(KEY_E)
	await _sec(0.8)
	_expect(office.phone_ui.is_open(), "real E on the phone opens it")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "phone: mouse visible")
	await _shot("22_phone_messages_item")
	await _click_button(office.phone_ui, "‹ Back")
	await _sec(0.3)
	await _shot("23_phone_messages_list")
	await _click_button(office.phone_ui, "Home")
	await _sec(0.3)
	await _shot("24_phone_home_screen")
	await _click_control(office.phone_ui.find_child("App_wallet", true, false) as Button, "App_wallet")
	await _sec(0.3)
	await _click_control(office.phone_ui.find_child("Tx_c8_tx_mama", true, false) as Button, "Tx_c8_tx_mama")
	await _sec(0.3)
	_expect(office.session.inspected.has("tx:c8_tx_mama"), "real click on the KwartaPay history entry checks it")
	await _shot("25_kwartapay_history")
	await _click_control(office.phone_ui.find_child("WalletTab_inbox", true, false) as Button, "WalletTab_inbox")
	await _sec(0.3)
	await _shot("26_kwartapay_inbox")
	await _key(KEY_ESCAPE)
	await _sec(0.5)
	_expect(not office.phone_ui.is_open(), "ESC puts the phone away")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "after putting the phone away: mouse captured")

	# ---------------- chapter 5 at home: the bank agent calls while the phone is in hand
	game.select_chapter(5)
	change_scene_to_file(OFFICE)
	office = await _wait_office(office)
	await _advance_dialogue(office)
	await _sec(0.5)
	await _key(KEY_E)
	await _sec(0.8)
	var c7o: Dictionary = Campaign.item(5, "c7_otp")
	for k: Variant in c7o.required_inspections:
		office.debug_inspect(str(k))
	await _sec(0.2)
	await _click_button(office.phone_ui, "Type the code into the ShopKo checkout you opened yourself")
	await _sec(0.4)
	await _key(KEY_E)
	await _until(func() -> bool: return office.session.phone_incoming() and office.debug_state() == "ACTIVE")
	await _sec(0.6)
	_expect(office.phone_ui.find_child("IncomingCall", true, false).is_visible_in_tree(), "the incoming call banner shows on the open phone")
	await _shot("27_phone_incoming_call")
	await _click_button(office.phone_ui, "Answer")
	await _sec(1.0)
	_expect(office.call_ui.is_open(), "real click on Answer opens the call")
	await _shot("28_phone_call_hotlines_card")
	await _key(KEY_E)   # skip playback
	await _sec(0.3)
	await _click_button_prefix(office.call_ui, "Caller ID:")
	await _click_button(office.call_ui, "Hang up")
	await _sec(0.3)
	await _key(KEY_E)
	await _sec(0.5)
	await _click_button(office.call_ui, "Call the hotline on the back of your BancoNation card (8700)")
	await _sec(0.3)
	await _key(KEY_E)
	await _sec(0.6)
	_expect(office.dial_pad.is_open(), "hanging up to call the card hotline opens the keypad at once")
	for d: String in "8700":
		await _click_control(office.dial_pad.find_child("Key_" + d, true, false) as Button, "Key_" + d)
	await _sec(0.2)
	await _shot("29_phone_keypad_8700")

	# ---------------- chapter 4 at the office: the desk phone (Chapter Select jump to the fake IT call)
	game.select_chapter(4, "c3_mark")
	change_scene_to_file(OFFICE)
	office = await _wait_office(office)
	await _advance_dialogue(office)
	player = office.player
	b = office.builder
	spawn = b.chapter_spawn
	mp = b.monitor_point
	player.teleport(spawn)
	_look(player, b.phone_point)
	await _sec(0.5)
	print("ch4 prompt at phone: '%s'" % _hud_prompt(office))
	await _shot("30_desk_phone_ringing")
	await _key(KEY_E)
	await _sec(0.8)
	_expect(office.call_ui.is_open(), "real E on the phone answers")
	await _sec(1.0)
	await _shot("31_call_playing")
	await _sec(5.5)
	await _shot("32_call_locked")
	await _click_button_prefix(office.call_ui, "Caller ID:")
	await _sec(0.2)
	await _shot("33_call_caller_id")
	var c3m: Dictionary = Campaign.item(4, "c3_mark")
	await _click_button(office.call_ui, _choice_text(c3m.steps[0], "wrong"))
	await _sec(0.4)
	await _shot("34_outcome_wrong_call")
	await _key(KEY_ESCAPE)
	await _sec(1.2)
	await _key(KEY_ESCAPE)   # must not hang up
	await _sec(0.2)
	_expect(office.call_ui.is_open(), "ESC does not hang up")
	await _click_button(office.call_ui, _choice_text(c3m.steps[0], "unsafe"))
	await _sec(0.4)
	await _shot("35_outcome_unsafe")
	await _click_button(office.outcome_panel, "Continue")
	await _sec(0.6)
	await _shot("36_compromise")
	await _key(KEY_ESCAPE)
	await _key(KEY_E)
	_expect(office.compromise_notice.is_open(), "compromise cannot be skipped")
	await _until(func() -> bool: return office.debug_state() == "GAME_OVER")
	await _sec(0.4)
	await _shot("37_game_over")
	await _key(KEY_ESCAPE)
	_expect(office.game_over.is_open(), "ESC blocked on game over")
	await _click_button(office.game_over, "Restart Chapter")
	office = await _wait_office(office)
	await _until(func() -> bool: return office.debug_state() in ["BRIEFING", "ACTIVE"])
	await _sec(0.5)
	await _shot("38_restart_briefing")
	await _advance_dialogue(office)
	await _sec(0.3)
	print("after restart prompt (spawn facing): '%s' state %s" % [_hud_prompt(office), office.debug_state()])
	await _shot("39_restart_spawn_view")

	# ---------------- ending (every chapter counted complete)
	for i: int in game.completed.size():
		game.completed[i] = true
	change_scene_to_file(ENDING)
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == ENDING and not router.is_busy())
	await _sec(1.0)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "ending: mouse visible")
	_expect(_visible_text_contains(current_scene, "Chapters completed: 10 of 10"), "ending counts all ten chapters")
	await _shot("49_ending")
	await _click_button(current_scene, "Main Menu")
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == MAIN_MENU and not router.is_busy())
	await _sec(0.5)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "back at menu: mouse visible")
	await _shot("50_back_to_menu")

	print("")
	for p: String in problems:
		print("PROBLEM ", p)
	print("CAPTURE_PLAY DONE, problems: %d" % problems.size())
	if current_scene != null:
		current_scene.queue_free()
	await _sec(0.3)
	quit(0)


# ------------------------------------------------------------------ input helpers

func _click_at(pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	root.push_input(mm, true)
	await process_frame
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)
	await process_frame
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = pos
	r.global_position = pos
	root.push_input(r, true)
	await process_frame
	await process_frame


## Clicks a visible button by its centre and reports if its pressed signal did not fire (something covers it).
func _click_button(node: Node, text: String) -> void:
	var btn := _find_button(node, text)
	if btn == null:
		problems.append("button not found / not visible: '%s'" % text)
		return
	await _click_control(btn, text)


func _click_button_prefix(node: Node, prefix: String) -> void:
	var btn := _find_button_prefix(node, prefix)
	if btn == null:
		problems.append("button not found (prefix): '%s'" % prefix)
		return
	await _click_control(btn, prefix)


func _click_control(btn: Button, what: String) -> void:
	var fired := [false]
	var cb := func() -> void: fired[0] = true
	btn.pressed.connect(cb)
	var pos := btn.get_global_rect().get_center()
	var vp := root.get_visible_rect().size
	if not Rect2(Vector2.ZERO, vp).has_point(pos):
		problems.append("button '%s' centre %s is off screen (%s)" % [what, pos, vp])
	if btn.disabled:
		problems.append("button '%s' disabled when clicked" % what)
	await _click_at(pos)
	if is_instance_valid(btn) and btn.pressed.is_connected(cb):
		btn.pressed.disconnect(cb)
	if not fired[0]:
		var hovered := root.gui_get_hovered_control()
		problems.append("real click did not press '%s' at %s (hovered: %s)" % [what, pos, hovered.get_path() if hovered != null else "none"])


func _key(code: Key, ctrl: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.ctrl_pressed = ctrl
	e.pressed = true
	root.push_input(e)
	await process_frame
	var r := InputEventKey.new()
	r.keycode = code
	r.physical_keycode = code
	r.ctrl_pressed = ctrl
	r.pressed = false
	root.push_input(r)
	await process_frame
	await process_frame


func _advance_dialogue(office: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(office) and office.debug_state() != "ACTIVE":
		if (Time.get_ticks_msec() - t0) > 15000:
			print("TIMEOUT advancing, state ", office.debug_state())
			return
		if office.debug_state() in ["INTRO", "BRIEFING", "FEEDBACK"]:
			await _key(KEY_E)
		await _sec(0.05)



func _choice_text(step: Dictionary, outcome: String) -> String:
	for c: Dictionary in step.get("choices", []):
		if str(c.outcome) == outcome:
			return str(c.text)
	return ""


func _visible_text_contains(node: Node, needle: String) -> bool:
	for c: Node in node.find_children("*", "Label", true, false):
		if (c as Label).is_visible_in_tree() and (c as Label).text.contains(needle):
			return true
	return false


# ------------------------------------------------------------------ misc helpers

func _expect(ok: bool, what: String) -> void:
	print(("OK   " if ok else "BAD  ") + what)
	if not ok:
		problems.append(what)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir + name + ".png")
	print("shot ", name, " ", img.get_size())


func _sec(t: float) -> void:
	await create_timer(t).timeout


func _until(cond: Callable, timeout: float = 15.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			print("TIMEOUT waiting")
			return
		await process_frame


func _wait_office(old: Node) -> Node:
	var old_id: int = old.get_instance_id() if old != null and is_instance_valid(old) else 0
	await _until(func() -> bool:
		var cs := current_scene
		return cs != null and is_instance_valid(cs) and cs.get_instance_id() != old_id and cs.scene_file_path == OFFICE and cs.has_method("debug_state"))
	await process_frame
	return current_scene


func _facing(pos: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis(), pos).looking_at(Vector3(target.x, pos.y, target.z), Vector3.UP)


func _look(player: Node3D, target: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var to := target - head.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _hud_prompt(office: Node) -> String:
	var hud: Node = office.hud
	var lbl: Label = hud.get("_prompt")
	var box: Control = hud.get("_prompt_box")
	return lbl.text if box.visible else ""


func _visible_class(node: Node, cls: String) -> bool:
	for c: Node in node.find_children("*", "", true, false):
		var s: Script = c.get_script()
		if s != null and s.get_global_name() == cls and (c as CanvasItem).is_visible_in_tree():
			return true
	return false


func _find_button_prefix(node: Node, prefix: String) -> Button:
	for bn: Node in node.find_children("*", "Button", true, false):
		var btn := bn as Button
		if btn.text.begins_with(prefix) and btn.is_visible_in_tree():
			return btn
	return null


func _find_button(node: Node, text: String) -> Button:
	for bn: Node in node.find_children("*", "Button", true, false):
		if (bn as Button).text == text and (bn as Button).is_visible_in_tree():
			return bn as Button
	return null


func _find_rich_with(node: Node, needle: String) -> RichTextLabel:
	for r: Node in node.find_children("*", "RichTextLabel", true, false):
		if (r as RichTextLabel).text.contains(needle) and (r as RichTextLabel).is_visible_in_tree():
			return r as RichTextLabel
	return null
