extends SceneTree
## Visual capture of Chapters 7 (Social Media Impersonation, Chat app) and 9 (QR Code Phishing), the two office
## chapters that were Chapters 5 and 6 before the ten-chapter week. Run WITHOUT --headless:
##   Godot --path <game> --script res://tests/capture_ch56.gd
## Starts at Chapter 7 the way Restart Chapter loads a chapter (chapters 1-6 marked complete), presses the real
## profile / request / Preview QR link buttons for the key shots, plays the rest through the office test hooks,
## jumps over Chapter 8 (the cafe) the way Chapter Select does, and saves PNGs to res://tests/shots/ch79/.

const OFFICE := "res://scenes/office.tscn"
const ENDING := "res://scenes/ending.tscn"
const OUT := "res://tests/shots/ch79/"

var game: Node
var office: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("window ", root.get_visible_rect().size)

	game.start_new_game()
	for i: int in 6:
		game.completed[i] = true
	game.begin_chapter(7)
	game.is_restart = true
	change_scene_to_file(OFFICE)
	office = await _wait_office()
	await _drive("ACTIVE")
	await _sec(0.4)

	# ------------------------------------------------------------------ Chapter 7: Chat
	await office.debug_interact("workstation")
	await _sec(0.5)
	var otp := Campaign.item(7, "c5_otp")
	office.debug_select_item("c5_otp")
	await _sec(0.3)
	await _shot("c56_01_chat_locked")
	(_find_button_prefix(office.desktop, "Coworker - Sales  ") as Button).pressed.emit()
	await _frames(2)
	(_find_button_prefix(office.desktop, "Check the request") as Button).pressed.emit()
	await _sec(0.3)
	_scroll_reading_pane_bottom()
	await _sec(0.3)
	await _shot("c56_02_chat_profile_and_request_revealed")
	office.debug_select_item("c5_lunch")
	await _sec(0.3)
	(_find_button_prefix(office.desktop, "Coworker - Sales  ") as Button).pressed.emit()
	await _sec(0.3)
	await _shot("c56_03_chat_genuine_profile")
	await _play(Campaign.item(7, "c5_lunch"))
	# The main attack by the verify route; stop on its checklist for the shot.
	await _play(otp, true)
	await _sec(0.4)
	await _shot("c56_04_ch7_checklist")
	await _finish_checklist()
	await _play(Campaign.item(7, "c5_prize"))
	office.debug_select_item("c5_coworker")
	await _sec(0.3)
	(_find_button_prefix(office.desktop, "Coworker - Admin  ") as Button).pressed.emit()
	await _frames(2)
	(_find_button_prefix(office.desktop, "Show forwarded details") as Button).pressed.emit()
	await _sec(0.3)
	_scroll_reading_pane_bottom()
	await _sec(0.3)
	await _shot("c56_05_chat_coworker_quote")
	await _play(Campaign.item(7, "c5_coworker"))
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.5)
	await _shot("c56_06_ch7_feedback")
	# Chapter 8 is at the cafe: jump to Chapter 9 the way Chapter Select does (a new office scene at the office).
	game.select_chapter(9)
	change_scene_to_file(OFFICE)
	await _until(func() -> bool: return current_scene != office)
	office = await _wait_office()
	await _drive("ACTIVE")
	await _sec(0.5)

	# ------------------------------------------------------------------ Chapter 9: QR codes
	_look(office.player, office.builder.monitor_point)
	await _sec(0.4)
	await _shot("c56_07_ch9_hud")
	await office.debug_interact("workstation")
	await _sec(0.5)
	office.debug_select_item("c6_parking")
	await _sec(0.3)
	await _shot("c56_08_qr_email_locked")
	(_find_button_prefix(office.desktop, "Aegis Facilities  ") as Button).pressed.emit()
	await _frames(2)
	(_find_button_prefix(office.desktop, "Preview QR link") as Button).pressed.emit()
	await _sec(0.3)
	_scroll_reading_pane_bottom()
	await _sec(0.3)
	await _shot("c56_09_qr_preview_revealed")
	await _play(Campaign.item(9, "c6_parking"), true)
	await _sec(0.4)
	await _shot("c56_10_ch9_checklist")
	await _finish_checklist()
	await _play(Campaign.item(9, "c6_rice"))
	office.debug_select_item("c6_menu")
	await _sec(0.3)
	(_find_button_prefix(office.desktop, "Aegis Facilities  ") as Button).pressed.emit()
	await _frames(2)
	(_find_button_prefix(office.desktop, "Preview QR link") as Button).pressed.emit()
	await _sec(0.3)
	_scroll_reading_pane_bottom()
	await _sec(0.3)
	await _shot("c56_11_qr_genuine_menu_preview")
	await _play(Campaign.item(9, "c6_menu"))
	office.debug_select_item("c6_coworker")
	await _sec(0.3)
	(_find_button_prefix(office.desktop, "Coworker - Marketing  ") as Button).pressed.emit()
	await _frames(2)
	(_find_button_prefix(office.desktop, "Show forwarded details") as Button).pressed.emit()
	await _frames(2)
	(_find_button_prefix(office.desktop, "Preview QR link") as Button).pressed.emit()
	await _sec(0.3)
	_scroll_reading_pane_bottom()
	await _sec(0.3)
	await _shot("c56_12_qr_coworker_quote")
	(office.desktop._app_buttons["browser"] as Button).pressed.emit()
	office.desktop.show_page("facilities")
	await _sec(0.3)
	await _shot("c56_13_browser_facilities_page")
	(office.desktop._app_buttons["mail"] as Button).pressed.emit()
	# The cafe chapters were skipped: count them complete so finishing Chapter 9 ends the week (ending shot).
	game.completed[7] = true
	game.completed[9] = true
	await _play(Campaign.item(9, "c6_coworker"))
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.5)
	await _shot("c56_14_ch9_feedback")
	office.debug_advance()
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == ENDING)
	await _sec(1.2)
	office = null
	await _shot("c56_15_ending")
	print("capture done")
	quit(0)


## Plays an item through the hooks: select, every inspection, first correct choice / exact checklist. With
## `stop_at_checklist`, returns when the item reaches its checklist step (for a screenshot).
func _play(it: Dictionary, stop_at_checklist: bool = false) -> void:
	var id: String = it.id
	if not office.desktop.is_open():
		await office.debug_interact("workstation")
		await _sec(0.4)
	office.debug_select_item(id)
	await _frames(2)
	for k: Variant in it.required_inspections:
		office.debug_inspect(str(k))
	await _frames(2)
	var guard := 0
	while not office.session.is_done(id) and guard < 10:
		guard += 1
		var st: Dictionary = office.session.step()
		if office.session.waits_for_telephone():
			# Place the call: the desk phone's keypad, the extension from the call header.
			await office.debug_interact("telephone")
			await _sec(0.4)
			await office.debug_dial(office.session.expected_number())
			await _sec(0.6)
			office.debug_advance()
			await _sec(0.3)
		if office.session.is_checklist():
			if stop_at_checklist:
				return
			await _finish_checklist()
			continue
		var pick := -1
		var choices: Array = st.get("choices", [])
		for i: int in choices.size():
			if str(choices[i].outcome) == "correct":
				pick = i
				break
		office.debug_choose(pick)
		await _frames(2)
		office.debug_advance()
		await _until(func() -> bool: return office.debug_state() in ["ACTIVE", "FEEDBACK"])
		await _sec(0.5)
		await _until(func() -> bool: return office.debug_state() != "ACTIVE" or office.desktop.is_open() or office.call_ui.is_open() or office.session.is_done(id) or office.session.waits_for_telephone())


func _finish_checklist() -> void:
	var st: Dictionary = office.session.step()
	var real: Array[int] = []
	for i: int in st.options.size():
		if bool(st.options[i].real):
			real.append(i)
	office.debug_check(real)
	await _frames(2)
	office.debug_advance()
	await _until(func() -> bool: return office.debug_state() in ["ACTIVE", "FEEDBACK"])
	await _sec(0.3)


func _scroll_reading_pane_bottom() -> void:
	for sc: Node in office.desktop.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		if s.is_visible_in_tree():
			s.scroll_vertical = 100000


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	print("shot %s (%s) %s  state=%s score=%d" % [name, img.get_size(), "ok" if err == OK else "ERR %d" % err,
		office.debug_state() if office != null and is_instance_valid(office) else "-", game.score])


func _sec(t: float) -> void:
	await create_timer(t).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _until(cond: Callable, timeout: float = 15.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			print("TIMEOUT waiting")
			return
		await process_frame


func _drive(target: String) -> void:
	var t0 := Time.get_ticks_msec()
	var frame := 0
	while is_instance_valid(office) and office.debug_state() != target:
		if (Time.get_ticks_msec() - t0) / 1000.0 > 30.0:
			print("TIMEOUT driving to ", target, " state ", office.debug_state())
			return
		frame += 1
		if ["INTRO", "BRIEFING", "OUTCOME", "FEEDBACK"].has(office.debug_state()) and frame % 4 == 0:
			office.debug_advance()
		await process_frame


func _wait_office() -> Node:
	await _until(func() -> bool:
		var cs := current_scene
		return cs != null and is_instance_valid(cs) and cs.scene_file_path == OFFICE and cs.has_method("debug_state"))
	await process_frame
	return current_scene


func _look(player: Node3D, target: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var to := target - head.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _find_button_prefix(node: Node, prefix: String) -> Button:
	for bn: Node in node.find_children("*", "Button", true, false):
		var btn := bn as Button
		if btn.text.begins_with(prefix) and btn.is_visible_in_tree() and not btn.is_queued_for_deletion():
			return btn
	return null
