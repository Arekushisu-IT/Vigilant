extends SceneTree
## Visual capture for the objective audit of the "more tasks per chapter" build (TASKS-SPEC.md). Run WITHOUT
## --headless:
##   Godot --path <game> --script res://tests/capture.gd
## Plays the four original office chapters of the ten-chapter week (Chapter 1 Email Phishing, 2 Smishing, 4 Vishing,
## 6 Business Email Compromise; the home chapters 3 and 5 are jumped over the way Chapter Select does) through the
## office test hooks and the real buttons (row buttons, sender and forwarded-details buttons, CheckBoxes + Submit)
## and saves PNGs to res://tests/shots/tasks/.

const OFFICE := "res://scenes/office.tscn"
const ENDING := "res://scenes/ending.tscn"
const OUT := "res://tests/shots/tasks/"

var game: Node
var router: Node
var office: Node
var _shots := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	router = root.get_node("/root/Router")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("window ", root.get_visible_rect().size)

	game.start_new_game()
	change_scene_to_file(OFFICE)
	office = await _wait_office()
	await _drive("ACTIVE")
	await _sec(0.3)

	# ------------------------------------------------------------------ Chapter 1 (hint level full)
	await _hud_view("t01_ch1_hud_tasks_start", office.builder.monitor_point)
	await office.debug_interact("workstation")
	await _sec(0.5)
	await _shot("t02_ch1_inbox_locked_full_hint")
	var c1o := Campaign.item(1, "c1_orientation")
	await _press_sender(c1o)
	await _shot("t03_ch1_genuine_sender_revealed_hint_shrinks")
	await _paste_link(c1o, "c1_agenda")
	await _shot("t04_ch1_genuine_link_pasted_browser")
	await _open_app("mail")
	await _shot("t05_ch1_genuine_unlocked_choices")
	await _choose_text(c1o.steps[0], "Report it to Security as phishing", "t06_ch1_genuine_reported_wrong")
	await _choose_outcome(c1o.steps[0], "correct", "")
	var c1b := Campaign.item(1, "c1_benefits")
	await _select(c1b)
	await _press_sender(c1b)
	await _shot("t07_ch1_main_sender_revealed")
	office.debug_inspect("link:c1_portal")
	await _frames(3)
	await _choose_index(1, "")   # Directory + call HR (verify route)
	await _sec(0.4)
	await _shot("t08_ch1_directory_wait_for_phone")
	await _open_app("mail")
	await _shot("t09_ch1_mail_wait_objective_decisionbar")
	await _phone()
	await _sec(4.0)
	await _shot("t10_ch1_call_hr_verification")
	await _choose_index(0, "t11_ch1_hr_call_outcome")
	await _until(func() -> bool: return office.desktop.is_open() and office.debug_state() == "ACTIVE")
	await _sec(0.4)
	await _shot("t12_ch1_checklist_red_flags")
	var cl := _real(c1b.steps[3])
	var wrong: Array[int] = [0, 1, 2, 3]
	await _submit_ui(wrong, "t13_ch1_checklist_wrong_feedback")
	await _shot("t14_ch1_checklist_after_wrong")
	await _submit_ui(cl, "t15_ch1_checklist_correct_outcome")
	var c1v := Campaign.item(1, "c1_voucher")
	await _select(c1v)
	await _press_sender(c1v)
	await _shot("t16_ch1_fake_voucher_sender_revealed")
	office.debug_inspect("link:c1_claim")
	await _frames(3)
	await _choose_outcome(c1v.steps[0], "correct", "")
	var c1c := Campaign.item(1, "c1_coworker")
	await _select(c1c)
	await _shot("t17_ch1_coworker_new_locked")
	await _press_sender(c1c)
	await _press_quote()
	await _shot("t18_ch1_coworker_quote_revealed")
	office.debug_inspect("link:c1_cw_pay")
	await _frames(3)
	await _scroll_reading_pane_bottom()
	await _shot("t19_ch1_coworker_unlocked")
	await _close_desk()
	await _hud_view("t20_ch1_hud_tasks_4of5", office.builder.monitor_point)
	await office.debug_interact("workstation")
	await _sec(0.4)
	await _select(c1c)
	await _choose_outcome(c1c.steps[0], "correct", "t21_ch1_coworker_outcome")
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.8)
	await _shot("t22_ch1_feedback_per_task")
	await _scroll_feedback_bottom()
	await _shot("t23_ch1_feedback_per_task_scrolled")
	office.debug_advance()
	await _sec(0.3)
	await _until(func() -> bool: return office.debug_state() == "BRIEFING")
	await _sec(0.5)
	await _shot("t24_ch2_briefing_hud_tasks_hidden")
	await _drive("ACTIVE")

	# ------------------------------------------------------------------ Chapter 2 (generic)
	await office.debug_interact("workstation")
	await _sec(0.5)
	await _shot("t25_ch2_messages_list_generic_hint")
	var c2r := Campaign.item(2, "c2_redeliver")
	await _select(c2r)
	await _press_sender(c2r)
	office.debug_inspect("link:c2_pay")
	await _frames(3)
	await _shot("t26_ch2_main_fake_sender_revealed")
	await _choose_index(0, "")
	await _sec(0.4)
	await _shot("t27_ch2_official_courier_site")
	await _open_app("messages")
	await _choose_outcome(c2r.steps[1], "correct", "")
	await _sec(0.3)
	await _shot("t28_ch2_checklist")
	await _submit_ui(_real(c2r.steps[2]), "")
	var c2d := Campaign.item(2, "c2_delivery")
	await _select(c2d)
	await _press_sender(c2d)
	office.debug_inspect("link:c2_track")
	await _frames(3)
	await _shot("t29_ch2_genuine_delivery_revealed")
	await _choose_outcome(c2d.steps[0], "correct", "")
	var c2a := Campaign.item(2, "c2_access")
	await _select(c2a)
	await _press_sender(c2a)
	office.debug_inspect("link:c2_keep")
	await _frames(3)
	await _shot("t30_ch2_fake_access_revealed")
	await _choose_outcome(c2a.steps[0], "correct", "")
	var c2c := Campaign.item(2, "c2_coworker")
	await _select(c2c)
	await _press_sender(c2c)
	await _press_quote()
	office.debug_inspect("link:c2_cw_pay")
	await _frames(3)
	await _shot("t31_ch2_coworker_revealed")
	await _choose_outcome(c2c.steps[0], "correct", "")
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.8)
	await _shot("t32_ch2_feedback")
	await _jump(4)

	# ------------------------------------------------------------------ Chapter 4: Vishing (generic, calls)
	await _sec(0.5)
	await _hud_view("t33_ch4_phone_ringing_hud", office.builder.phone_point)
	await office.debug_interact("telephone")
	await _sec(4.0)
	await _shot("t34_ch4_call_genuine_locked_generic")
	await _press_caller_id()
	await _shot("t35_ch4_genuine_caller_id_revealed")
	var c3f := Campaign.item(4, "c3_facilities")
	await _choose_outcome(c3f.steps[0], "correct", "t36_ch4_genuine_outcome")
	await _until(func() -> bool: return office.session.phone_incoming() and office.builder.telephone.enabled and office.debug_state() == "ACTIVE")
	await office.debug_interact("telephone")
	await _sec(6.0)
	await _press_caller_id()
	await _shot("t37_ch4_main_call_caller_id")
	var c3m := Campaign.item(4, "c3_mark")
	await _choose_outcome(c3m.steps[0], "correct", "")
	await _sec(0.6)
	await _shot("t38_ch4_call_ended_follow_up")
	await _choose_index(0, "t39_ch4_call_it_1100_verification")
	await _sec(4.0)
	await _shot("t40_ch4_call_checklist_security")
	await _submit_ui(_real(c3m.steps[2]), "")
	await _until(func() -> bool: return office.debug_state() == "ACTIVE" and not office.call_ui.is_open())
	await _sec(0.6)
	await _hud_view("t41_ch4_after_main_phone_and_desk", office.builder.phone_point)
	await office.debug_interact("telephone")
	await _sec(5.0)
	await _press_caller_id()
	await _shot("t42_ch4_fake_security_caller_id")
	var c3s := Campaign.item(4, "c3_security")
	await _choose_outcome(c3s.steps[0], "correct", "")
	await _until(func() -> bool: return office.debug_state() == "ACTIVE" and not office.call_ui.is_open())
	await office.debug_interact("workstation")
	await _sec(0.5)
	var c3c := Campaign.item(4, "c3_coworker")
	await _select(c3c)
	await _press_sender(c3c)
	await _press_quote()
	await _shot("t43_ch4_coworker_revealed")
	await _choose_outcome(c3c.steps[0], "correct", "")
	await _finish_rest()
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.8)
	await _shot("t44_ch4_feedback")
	await _jump(6)

	# ------------------------------------------------------------------ Chapter 6: BEC (generic hint)
	await office.debug_interact("workstation")
	await _sec(0.5)
	await _shot("t45_ch6_inbox_responses_locked")
	var c4s := Campaign.item(6, "c4_supplier")
	await _select(c4s)
	await _press_sender(c4s)
	await _shot("t46_ch6_main_sender_reply_to_revealed")
	await _choose_index(0, "")
	await _sec(0.4)
	await _shot("t47_ch6_directory")
	await _phone()
	await _sec(3.0)
	await _shot("t48_ch6_call_ramos_verification")
	await _choose_index(0, "")
	await _until(func() -> bool: return office.desktop.is_open() and office.debug_state() == "ACTIVE")
	await _sec(0.4)
	await _shot("t49_ch6_checklist")
	var decoys := _decoys(c4s.steps[2])
	await _submit_ui(decoys, "t50_ch6_worst_wrong_report_outcome")
	await _submit_ui(_real(c4s.steps[2]), "")
	var c4g := Campaign.item(6, "c4_giftcards")
	await _select(c4g)
	await _press_sender(c4g)
	await _shot("t51_ch6_fake_giftcards_revealed")
	await _choose_outcome(c4g.steps[0], "correct", "")
	var c4p := Campaign.item(6, "c4_policy")
	await _select(c4p)
	await _press_sender(c4p)
	office.debug_inspect("link:c4_expense")
	await _frames(3)
	await _shot("t52_ch6_genuine_policy_revealed")
	await _choose_outcome(c4p.steps[0], "correct", "")
	var c4c := Campaign.item(6, "c4_coworker")
	await _select(c4c)
	await _press_sender(c4c)
	await _press_quote()
	await _shot("t53_ch6_coworker_revealed")
	await _choose_outcome(c4c.steps[0], "correct", "")
	# The chapters this capture jumped over count as complete, so finishing Chapter 6 ends the week.
	for i: int in game.completed.size():
		if i != 5:
			game.completed[i] = true
	await _finish_rest()
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.8)
	await _shot("t54_ch6_feedback")
	print("score before ending ", game.score, " max ", game.max_score())
	office.debug_advance()
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == ENDING and not router.is_busy(), 20.0)
	await _sec(1.5)
	await _shot("t55_ending")
	var scrolls: Array[Node] = current_scene.find_children("*", "ScrollContainer", true, false)
	for s: Node in scrolls:
		(s as ScrollContainer).scroll_vertical = 100000
	await _sec(0.3)
	await _shot("t56_ending_scrolled")

	print("CAPTURE DONE (%d shots) score %d" % [_shots, game.score])
	quit(0)


# ---------------------------------------------------------------------------------------------- actions

func _open_app(app: String) -> void:
	(office.desktop._app_buttons[app] as Button).pressed.emit()
	await _frames(3)


func _select(it: Dictionary) -> void:
	await _open_app(str(it.app))
	var row := office.desktop.find_child("Item_" + str(it.id), true, false) as Button
	if row == null:
		print("ROW MISSING ", it.id)
		return
	row.pressed.emit()
	await _frames(4)
	if office.debug_item() != str(it.id):
		print("SELECT FAILED ", it.id)


func _press_sender(it: Dictionary) -> void:
	var msg: Dictionary = it.message
	var name_text: String = msg.get("from_name", msg.get("sender_label", ""))
	var b := _find_button_prefix(office.desktop, name_text + "  ")
	if b == null:
		print("SENDER BUTTON MISSING ", it.id)
		return
	b.pressed.emit()
	await _frames(3)


func _press_quote() -> void:
	var b := _find_button_prefix(office.desktop, "Show forwarded details")
	if b == null:
		print("QUOTE BUTTON MISSING")
		return
	b.pressed.emit()
	await _frames(3)


func _press_caller_id() -> void:
	var b := _find_button_prefix(office.call_ui, "Caller ID:")
	if b == null:
		print("CALLER ID BUTTON MISSING")
		return
	b.pressed.emit()
	await _frames(3)


func _paste_link(it: Dictionary, link_id: String) -> void:
	await _open_app(str(it.app))
	var body := _find_rich_with(office.desktop, "[url=%s]" % link_id)
	if body == null:
		print("LINK BODY MISSING ", link_id)
		return
	body.meta_clicked.emit(link_id)
	await _frames(2)
	var menus: Array[Node] = office.desktop.find_children("*", "PopupMenu", true, false)
	if not menus.is_empty():
		var menu := menus[0] as PopupMenu
		menu.id_pressed.emit(menu.get_item_id(0))
		menu.hide()
	await _open_app("browser")
	var paste := _find_button(office.desktop, "Paste")
	if paste != null:
		paste.pressed.emit()
	await _frames(3)


func _choose_text(step: Dictionary, text: String, shot: String) -> void:
	var choices: Array = step.choices
	for i: int in choices.size():
		if str(choices[i].text) == text:
			await _choose_index(i, shot)
			return
	print("NO CHOICE ", text)


func _choose_outcome(step: Dictionary, outcome: String, shot: String) -> void:
	var choices: Array = step.choices
	for i: int in choices.size():
		if str(choices[i].outcome) == outcome:
			await _choose_index(i, shot)
			return


## Presses choice `i` through its real button (desktop or call), shows the outcome, continues.
func _choose_index(i: int, shot: String) -> void:
	var st: Dictionary = office.session.step()
	var text := str(st.choices[i].text)
	var surface: Node = office.call_ui if office.call_ui.is_open() else office.desktop
	var btn := _find_button(surface, text)
	if btn != null and not btn.disabled:
		btn.pressed.emit()
	else:
		print("BUTTON MISSING/DISABLED, using hook: ", text)
		office.debug_choose(i)
	await _until(func() -> bool: return office.debug_state() == "OUTCOME")
	await _sec(0.4)
	if shot != "":
		await _shot(shot)
	office.debug_advance()
	await _frames(2)
	# The office stays busy while the feedback screen waits for Continue, so only ACTIVE needs not-busy.
	await _until(func() -> bool: return office.debug_state() in ["FEEDBACK", "GAME_OVER"] or (office.debug_state() == "ACTIVE" and not office._busy))
	await _frames(3)


## Ticks exactly `t` on the real ChecklistView and presses its real Submit button.
func _submit_ui(t: Array[int], shot: String) -> void:
	var cv: Node = office.call_ui._checklist if office.call_ui.is_open() else office.desktop._checklist
	if cv == null:
		print("NO CHECKLIST VIEW")
		return
	var i := 0
	while true:
		var box := cv.find_child("Check_%d" % i, true, false) as CheckBox
		if box == null:
			break
		box.button_pressed = t.has(i)
		i += 1
	await _frames(2)
	var sub := cv.submit_button() as Button
	if sub == null or sub.disabled:
		print("SUBMIT DISABLED, using hook ", t)
		office.debug_check(t)
	else:
		sub.pressed.emit()
	await _until(func() -> bool: return office.debug_state() == "OUTCOME")
	await _sec(0.4)
	if shot != "":
		await _shot(shot)
	office.debug_advance()
	await _frames(2)
	await _until(func() -> bool: return office.debug_state() in ["ACTIVE", "FEEDBACK"] and not office._busy)
	await _frames(3)


## Chapter Select jump to chapter n (a new office scene; the jumped-over chapters stay as they are).
func _jump(n: int) -> void:
	game.select_chapter(n)
	change_scene_to_file(OFFICE)
	await _until(func() -> bool: return current_scene != office)
	office = await _wait_office()
	await _drive("ACTIVE")
	await _sec(0.5)


## E on the desk phone: answers a ringing call, or opens the keypad and dials the number the step asks for.
func _phone() -> void:
	await office.debug_interact("telephone")
	await _sec(0.3)
	if office.dial_pad.is_open():
		await office.debug_dial(office.session.expected_number())


## Plays every item still open through the hooks (the ones this capture does not show: c3_printer, c4_delivery).
func _finish_rest() -> void:
	var guard := 0
	while office.debug_state() == "ACTIVE" and not office.session.all_done() and guard < 30:
		guard += 1
		var s: ChapterSession = office.session
		var id := ""
		for it: Dictionary in s.items():
			if s.is_unlocked(str(it.id)) and not s.is_done(str(it.id)):
				id = str(it.id)
				break
		if id == "":
			return
		if s.item_surface(id) == "call" and not office.call_ui.is_open():
			if office.desktop.is_open():
				await _close_desk()
			await _phone()
			await _sec(0.6)
			office.debug_advance()
			await _sec(0.3)
		elif s.item_surface(id) == "desktop":
			if not office.desktop.is_open():
				await office.debug_interact("workstation")
				await _sec(0.4)
			office.debug_select_item(id)
			await _frames(3)
		for k: Variant in s.item(id).required_inspections:
			office.debug_inspect(str(k))
		await _frames(3)
		if s.is_checklist():
			await _submit_ui(_real(s.step()), "")
		else:
			await _choose_outcome(s.step(), "correct", "")


func _close_desk() -> void:
	office.desktop.handle_back()
	await _until(func() -> bool: return not office.desktop.is_open() and not office._busy)
	await _sec(0.4)


## The 3D view at the desk looking at `target` (HUD with the task list visible).
func _hud_view(shot: String, target: Vector3) -> void:
	var player: Node3D = office.player
	player.teleport(office.builder.chapter_spawn)
	_look(player, target)
	await _sec(0.6)
	await _shot(shot)


func _scroll_reading_pane_bottom() -> void:
	for s: Node in office.desktop.find_children("*", "ScrollContainer", true, false):
		if (s as Control).is_visible_in_tree():
			(s as ScrollContainer).scroll_vertical = 100000
	await _frames(3)


func _scroll_feedback_bottom() -> void:
	for s: Node in office.feedback_screen.find_children("*", "ScrollContainer", true, false):
		(s as ScrollContainer).scroll_vertical = 100000
	await _frames(3)


# ---------------------------------------------------------------------------------------------- helpers

func _real(st: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var opts: Array = st.options
	for i: int in opts.size():
		if bool(opts[i].real):
			out.append(i)
	return out


func _decoys(st: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var opts: Array = st.options
	for i: int in opts.size():
		if not bool(opts[i].real):
			out.append(i)
	return out


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	_shots += 1
	print("shot %s (%s) %s  state=%s item=%s tasks=%s score=%d" % [name, img.get_size(), "ok" if err == OK else "ERR %d" % err,
		office.debug_state() if is_instance_valid(office) else "-", office.debug_item() if is_instance_valid(office) else "-",
		office.debug_tasks() if is_instance_valid(office) else "-", game.score])


func _sec(t: float) -> void:
	await create_timer(t).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _until(cond: Callable, timeout: float = 15.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			print("TIMEOUT waiting (state %s)" % (office.debug_state() if is_instance_valid(office) else "-"))
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
