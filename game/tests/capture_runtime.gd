extends SceneTree
## Playability / runtime capture of the task model (TASKS-SPEC.md). Run WITHOUT --headless:
##   Godot --path <game> --script res://tests/capture_runtime.gd
## Plays the four original office chapters of the ten-chapter week (Chapter 1 Email Phishing, 2 Smishing, 4 Vishing
## and 6 Business Email Compromise; Chapters 3 and 5 at home are jumped over the way Chapter Select does) through
## the office's public test hooks AND the real buttons (row buttons, sender reveal, forwarded details, Copy link
## address + Paste, choice buttons, tick boxes, Submit, Restart Chapter, the desk phone keypad), sends real ESC key
## events, and saves PNGs to res://tests/shots/tasks/runtime/. Prints "CHECK ..." lines for the playability checks
## and "LAYOUT ..." lines for controls that leave the viewport.

const OFFICE := "res://scenes/office.tscn"
const ENDING := "res://scenes/ending.tscn"
const OUT := "res://tests/shots/tasks/runtime/"

var game: Node
var router: Node
var office: Node
var problems: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	router = root.get_node("/root/Router")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("screen size ", DisplayServer.screen_get_size(), " window ", DisplayServer.window_get_size())
	await _window(Vector2i(1280, 720))

	game.start_new_game()
	change_scene_to_file(OFFICE)
	office = await _wait_office(null)
	await _until(func() -> bool: return office.debug_state() == "INTRO")
	await _drive("ACTIVE")
	await _chapter1()
	await _drive("ACTIVE")
	await _chapter2()
	await _jump(4)
	await _chapter3()
	await _jump(6)
	await _chapter4()

	print("")
	print("PROBLEMS (%d):" % problems.size())
	for p: String in problems:
		print("  - ", p)
	if current_scene != null:
		current_scene.queue_free()
	await _sec(0.3)
	print("CAPTURE DONE")
	quit(0)


# ============================================================================================ chapters

func _chapter1() -> void:
	var player: Node3D = office.player
	var b: Node = office.builder
	player.teleport(b.chapter_spawn)
	_look(player, b.monitor_point)
	await _sec(0.6)
	_check("ch1 start: mouse captured", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, str(Input.mouse_mode))
	_check("ch1 start: tasks 0/5", office.debug_tasks() == "0/5", office.debug_tasks())
	await _shot("01_ch1_hud_tasks_3d")

	await office.debug_interact("workstation")
	await _sec(0.5)
	_check("ch1: desktop open, mouse visible", office.desktop.is_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "")
	_check("ch1: first item selected", office.debug_item() == "c1_orientation", office.debug_item())
	await _shot("02_ch1_inbox_multi_1280_locked")
	await _layout("ch1 inbox", office.desktop)

	# Genuine orientation email: sender + link through the real UI.
	_press(_btn_prefix(office.desktop, "Aegis HR  "), "orientation sender")
	await _copy_paste_link("c1_agenda")
	_rail("Mail")
	await _sec(0.3)
	await _shot("03_ch1_genuine_inspected")
	_check("ch1 orientation gate open", office.session.gate_open(), str(office.session.missing()))
	_choose(office.desktop, "Open the agenda link and keep the email for Thursday")
	await _sec(0.4)
	await _shot("04_outcome_genuine_correct")
	await _continue()
	await _sec(0.3)
	await _shot("05_ch1_done_item_view")

	# Main attack: benefits email.
	_press(_row("c1_benefits"), "row c1_benefits")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "Aegis HR Benefits"), "benefits sender")
	await _sec(0.3)
	await _shot("06_ch1_fake_sender_revealed_hint")
	await _copy_paste_link("c1_portal")
	_rail("Mail")
	await _sec(0.2)

	# ESC through the real input path, then reopen: the item, inspections and gate must be kept.
	await _key(KEY_ESCAPE)
	await _until(func() -> bool: return not office.desktop.is_open() and not office.get("_busy"))
	await _sec(0.2)
	_check("ESC closes the desktop", not office.desktop.is_open(), "")
	_check("after ESC: mouse captured", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, str(Input.mouse_mode))
	_check("after ESC: state ACTIVE", office.debug_state() == "ACTIVE", office.debug_state())
	await office.debug_interact("workstation")
	await _sec(0.4)
	_check("reopen keeps the selected item", office.debug_item() == "c1_benefits", office.debug_item())
	_check("reopen keeps inspections (gate open)", office.session.gate_open(), str(office.session.missing()))
	await _shot("07_ch1_reopen_keeps_state")

	_choose(office.desktop, "Look up HR in the Staff Directory and call their extension")
	await _continue()
	await _sec(0.4)
	await _shot("08_ch1_directory_wait_phone")
	_check("ch1 telephone enabled for the HR call", b.telephone.enabled, b.telephone.prompt)
	_check("ch1 workstation still enabled (other mail pending)", b.workstation.enabled, "")
	_check("ch1 phone not ringing for an outgoing call", not b.get("_ringing"), "")

	await _phone()
	await _wait_playback()
	await _sec(0.3)
	await _shot("09_ch1_verify_call_hr_1300")
	await _layout("ch1 HR call", office.call_ui)
	_choose(office.call_ui, "Report it to Security as phishing")
	await _continue()
	await _until(func() -> bool: return office.desktop.is_open() and office.debug_state() == "ACTIVE")
	await _sec(0.4)
	await _shot("10_ch1_checklist_desktop_1280")
	await _layout("ch1 checklist", office.desktop)
	await _scroll_report("ch1 checklist", office.desktop)

	# Wrong report: one real sign missing + one decoy. Ticks must survive ESC + reopen.
	var real := _real_options(1, "c1_benefits", 3)
	var wrong: Array[int] = real.slice(1)
	wrong.append(1)
	_tick(office.desktop, wrong)
	await _sec(0.2)
	await _key(KEY_ESCAPE)
	await _until(func() -> bool: return not office.desktop.is_open() and not office.get("_busy"))
	await office.debug_interact("workstation")
	await _sec(0.4)
	_check("reopen keeps checklist ticks", _ticked(office.desktop) == _sorted(wrong), "%s vs %s" % [_ticked(office.desktop), _sorted(wrong)])
	_submit(office.desktop)
	await _sec(0.4)
	await _shot("11_ch1_checklist_wrong_feedback")
	await _layout("checklist wrong outcome", office.outcome_panel)
	await _continue()
	await _sec(0.3)
	await _shot("12_ch1_checklist_retry_same_set_blocked")
	_check("same wrong set cannot be resubmitted", _submit_button(office.desktop) != null and _submit_button(office.desktop).disabled, "")
	_tick(office.desktop, real)
	await _sec(0.1)
	_submit(office.desktop)
	await _continue()
	await _sec(0.3)

	# Fake voucher email.
	_press(_row("c1_voucher"), "row c1_voucher")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "Aegis Welcome Rewards"), "voucher sender")
	await _copy_paste_link("c1_claim")
	_rail("Mail")
	await _sec(0.2)
	_choose(office.desktop, "Report it to Security as phishing")
	await _continue()
	await _sec(0.3)

	# Coworker.
	_press(_row("c1_coworker"), "row c1_coworker")
	await _sec(0.4)
	await _shot("13_ch1_coworker_locked")
	_press(_btn_prefix(office.desktop, "Coworker - Sales"), "coworker sender")
	_press(_btn_prefix(office.desktop, "Show forwarded details"), "quote")
	await _copy_paste_link("c1_cw_pay")
	_rail("Mail")
	await _sec(0.3)
	await _shot("14_ch1_coworker_quote_revealed")
	await _layout("ch1 coworker", office.desktop)
	_choose(office.desktop, "Tell them not to click it and to report it to Security (ext. 1200)")
	await _sec(0.4)
	await _shot("15_outcome_coworker_correct")
	await _continue()
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.7)
	await _shot("16_ch1_feedback_per_task")
	await _layout("ch1 feedback", office.feedback_screen)
	_check("ch1 score 75 (one wrong report)", game.score == 75, str(game.score))
	office.debug_advance()


func _chapter2() -> void:
	await _sec(0.3)
	_check("ch2 start: tasks 0/6", office.debug_tasks() == "0/6", office.debug_tasks())
	await office.debug_interact("workstation")
	await _sec(0.5)
	await _shot("17_ch2_messages_inbox_1280")
	await _layout("ch2 inbox", office.desktop)
	# The genuine delivery text is first in the list now; the main fake (redelivery) is the second row.
	_press(_row("c2_redeliver"), "row c2_redeliver")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "SwftParcel"), "c2 sender")
	await _copy_paste_link("c2_pay")
	_rail("Messages")
	await _sec(0.2)
	await _shot("18_ch2_fake_sender_revealed")
	_choose(office.desktop, "Reply \"Who is this?\"")
	await _sec(0.4)
	await _shot("19_outcome_wrong")
	await _continue()
	await _sec(0.2)
	await _shot("20_ch2_wrong_choice_disabled")
	_choose(office.desktop, "Check the parcel on SwiftParcel's official website")
	await _continue()
	await _sec(0.4)
	await _shot("21_ch2_courier_official")
	_choose(office.desktop, "Report the text to Security and delete it")
	await _continue()
	await _sec(0.3)
	# The checklist at 1920x1080.
	_rail("Messages")
	await _window(Vector2i(1920, 1080))
	await _shot("22_ch2_checklist_1920")
	await _layout("ch2 checklist 1920", office.desktop)
	await _scroll_report("ch2 checklist 1920", office.desktop)
	await _window(Vector2i(1280, 720))
	await _shot("23_ch2_checklist_1280")
	await _scroll_report("ch2 checklist 1280", office.desktop)
	_tick(office.desktop, _real_options(2, "c2_redeliver", 2))
	_submit(office.desktop)
	await _continue()
	await _sec(0.3)

	# Genuine delivery text.
	_press(_row("c2_delivery"), "row c2_delivery")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "SwiftParcel  "), "c2_delivery sender")
	await _copy_paste_link("c2_track")
	_rail("Messages")
	await _sec(0.3)
	await _shot("24_ch2_genuine_sender_revealed")
	_choose(office.desktop, "Keep the text and check SP-4417 on the official SwiftParcel site")
	await _continue()
	# That choice opens the official courier page in the Browser; go back to Messages.
	await _sec(0.3)
	_rail("Messages")
	await _sec(0.3)

	# Fake access text through hooks.
	_press(_row("c2_access"), "row c2_access")
	await _sec(0.3)
	office.debug_inspect("sender_number")
	office.debug_inspect("link:c2_keep")
	await _sec(0.2)
	_choose(office.desktop, "Report the text to Security and delete it")
	await _continue()

	# Coworker.
	_press(_row("c2_coworker"), "row c2_coworker")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "Coworker - Admin"), "c2 coworker sender")
	_press(_btn_prefix(office.desktop, "Show forwarded details"), "c2 quote")
	await _copy_paste_link("c2_cw_pay")
	_rail("Messages")
	await _sec(0.3)
	await _shot("25_ch2_coworker_quote_1280")
	await _layout("ch2 coworker", office.desktop)
	_choose(office.desktop, "Tell them not to tap it, to check the official site and report it")
	await _continue()
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.6)
	await _shot("26_ch2_feedback")
	# No Continue here: the next chapter is at home, and _jump() leaves from the feedback screen (a scene change in the
	# middle of the home switch's fade would leave the Router busy).


## Chapter 4 (Vishing): the calls on the desk phone.
func _chapter3() -> void:
	var player: Node3D = office.player
	var b: Node = office.builder
	var start_score: int = game.score
	player.teleport(b.chapter_spawn)
	_look(player, b.phone_point)
	await _sec(0.7)
	_check("ch4 start: phone rings", b.get("_ringing"), "")
	_check("ch4 start: workstation disabled", not b.workstation.enabled, "")
	await _shot("27_ch3_phone_ringing_hud")

	# Call 1 (genuine Facilities).
	await office.debug_interact("telephone")
	await _wait_playback()
	_press(_btn_prefix(office.call_ui, "Caller ID:"), "c3 facilities caller id")
	await _sec(0.3)
	await _shot("28_ch3_genuine_call_caller_id")
	await _layout("ch3 facilities call", office.call_ui)
	_choose(office.call_ui, "Answer their question: tell them the line is clear")
	await _continue()
	await _sec(0.5)
	_check("ch3: phone rings again for the 2nd call", b.get("_ringing") and b.telephone.enabled, "")
	_check("ch3: call closed, mouse captured", not office.call_ui.is_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, str(Input.mouse_mode))
	_check("ch3: phone prompt", b.telephone.prompt_text(), b.telephone.prompt_text())
	await _shot("29_ch3_second_ring")

	# Call 2 (main attack).
	await office.debug_interact("telephone")
	await _wait_playback()
	await _shot("30_ch3_mark_call_locked_generic_hint")
	_press(_btn_prefix(office.call_ui, "Caller ID:"), "c3 mark caller id")
	await _sec(0.2)
	_choose(office.call_ui, "Ask him to prove he is from IT")
	await _continue()
	await _sec(0.3)
	_choose(office.call_ui, "Refuse and hang up")
	await _continue()
	await _wait_playback()
	await _sec(0.3)
	await _shot("31_ch3_call_ended_followup")
	_choose(office.call_ui, "Call the IT Helpdesk on the known ext. 1100")
	await _sec(0.4)
	await _shot("32_outcome_it_callback")
	await _continue()
	await _wait_playback()
	await _sec(0.3)
	await _shot("33_ch3_security_call_checklist")
	await _layout("ch3 call checklist", office.call_ui)
	await _scroll_report("ch3 call checklist", office.call_ui)
	_tick(office.call_ui, _real_options(4, "c3_mark", 2))
	_submit(office.call_ui)
	await _continue()
	await _sec(0.6)
	_check("ch3: 3rd call rings after the main call", b.get("_ringing"), "")
	_check("ch3: workstation enabled for the coworker text", b.workstation.enabled, "")
	_check("ch4 tasks 4/7", office.debug_tasks() == "4/7", office.debug_tasks())
	_look(player, b.phone_point)
	await _sec(0.3)
	await _shot("34_ch3_third_ring_and_new_message")

	# Call 3: unsafe -> compromise -> game over -> Restart Chapter.
	await office.debug_interact("telephone")
	await _wait_playback()
	_press(_btn_prefix(office.call_ui, "Caller ID:"), "c3 security caller id")
	await _sec(0.2)
	await _shot("35_ch3_fake_security_caller_id")
	_choose(office.call_ui, "Read out the code")
	await _continue()
	await _until(func() -> bool: return office.debug_state() == "COMPROMISED")
	await _sec(0.5)
	await _shot("36_compromise_notice")
	await _until(func() -> bool: return office.debug_state() == "GAME_OVER")
	await _sec(0.5)
	await _shot("37_game_over_item_text")
	await _layout("game over", office.game_over)
	_press(_btn(office.game_over, "Restart Chapter"), "Restart Chapter")
	office = await _wait_office(office)
	await _drive("ACTIVE")
	await _sec(0.5)
	b = office.builder
	player = office.player
	_check("restart: score rolled back to chapter start", game.score == start_score, "%d vs %d" % [game.score, start_score])
	_check("restart: tasks 0/7", office.debug_tasks() == "0/7", office.debug_tasks())
	_check("restart: phone rings again", b.get("_ringing"), "")
	_check("restart: mouse captured", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, str(Input.mouse_mode))
	await _shot("38_ch3_after_restart")

	# Replay Chapter 3 the best way.
	await office.debug_interact("telephone")
	await _wait_playback()
	office.debug_inspect("caller_id")
	_choose(office.call_ui, "Answer their question: tell them the line is clear")
	await _continue()
	await _sec(0.4)
	await office.debug_interact("telephone")
	await _wait_playback()
	office.debug_inspect("caller_id")
	_choose(office.call_ui, "Refuse and hang up")
	await _continue()
	await _wait_playback()
	_choose(office.call_ui, "Report the call to Security (ext. 1200)")
	await _continue()
	await _wait_playback()
	_tick(office.call_ui, _real_options(4, "c3_mark", 2))
	_submit(office.call_ui)
	await _continue()
	await _sec(0.4)
	# Coworker first (while the phone rings), then the 3rd call.
	await office.debug_interact("workstation")
	await _sec(0.5)
	await _shot("39_ch3_coworker_messages_phone_ringing")
	_press(_btn_prefix(office.desktop, "Coworker - Marketing"), "c3 coworker sender")
	_press(_btn_prefix(office.desktop, "Show forwarded details"), "c3 quote")
	await _sec(0.3)
	await _shot("40_ch3_coworker_quote")
	_choose(office.desktop, "Tell them not to share it, to call IT on ext. 1100 and report it")
	await _continue()
	await _sec(0.3)
	await _shot("41_ch3_desktop_after_last_message")
	await office.debug_interact("telephone")
	await _wait_playback()
	office.debug_inspect("caller_id")
	_choose(office.call_ui, "Refuse, hang up and report it to Security on ext. 1200")
	await _continue()
	await _finish_rest()
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.6)
	await _shot("42_ch4_feedback")
	_check("ch4 replay best = chapter max", game.chapter_total(4) == game.chapter_max(4), "%d of %d" % [game.chapter_total(4), game.chapter_max(4)])
	# No Continue: Chapter 5 is at home; _jump(6) leaves from the feedback screen.


## Chapter 6 (Business Email Compromise) at the workstation.
func _chapter4() -> void:
	await office.debug_interact("workstation")
	await _sec(0.5)
	await _shot("43_ch6_inbox_generic_hint")
	_check("ch6 hint level generic", office.session.gate_hint() == "Inspect before you decide.", office.session.gate_hint())
	# The main BEC email is the second row now (the genuine policy email comes first).
	_press(_row("c4_supplier"), "row c4_supplier")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "R. Ramos"), "ch4 sender")
	await _sec(0.3)
	await _shot("44_ch4_bec_sender_revealed")
	_choose(office.desktop, "Look up Mr. Ramos in the Staff Directory and call his extension")
	await _continue()
	await _sec(0.4)
	await _shot("45_ch6_directory_wait_phone")
	await _phone()
	await _wait_playback()
	await _sec(0.2)
	await _shot("46_ch4_call_ramos")
	_choose(office.call_ui, "Report the email to Security (Ms. Dela Vega)")
	await _continue()
	await _until(func() -> bool: return office.desktop.is_open() and office.debug_state() == "ACTIVE")
	await _sec(0.4)
	await _shot("47_ch4_checklist_8_options")
	await _scroll_report("ch4 checklist", office.desktop)
	_tick(office.desktop, _real_options(6, "c4_supplier", 2))
	_submit(office.desktop)
	await _continue()
	await _sec(0.3)
	_press(_row("c4_giftcards"), "row giftcards")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "Office of the CEO"), "ceo sender")
	_choose(office.desktop, "Report it to Security as business email compromise")
	await _continue()
	_press(_row("c4_policy"), "row policy")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "R. Ramos"), "policy sender")
	await _copy_paste_link("c4_expense")
	_rail("Mail")
	await _sec(0.3)
	await _shot("48_ch4_genuine_policy")
	_choose(office.desktop, "Open the policy link, read it, and reply \"Noted\"")
	await _continue()
	_press(_row("c4_coworker"), "row c4 coworker")
	await _sec(0.3)
	_press(_btn_prefix(office.desktop, "Coworker - Finance"), "c4 coworker sender")
	_press(_btn_prefix(office.desktop, "Show forwarded details"), "c4 quote")
	await _sec(0.3)
	await _shot("49_ch4_coworker")
	_choose(office.desktop, "Tell them to call Kestrel on the number on file and report it")
	await _continue()
	# The chapters this capture jumped over count as complete, so finishing Chapter 6 ends the week.
	for i: int in game.completed.size():
		if i != 5:
			game.completed[i] = true
	await _finish_rest()
	await _until(func() -> bool: return office.debug_state() == "FEEDBACK")
	await _sec(0.6)
	await _shot("50_ch6_feedback")
	office.debug_advance()
	await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == ENDING and not router.is_busy(), 20.0)
	await _sec(1.2)
	await _shot("51_ending_1280")
	await _layout("ending", current_scene)
	await _window(Vector2i(1920, 1080))
	await _shot("52_ending_1920")
	print("final score %d / %d" % [game.score, game.max_score()])


# ============================================================================================ helpers

func _check(label: String, ok: Variant, detail: String) -> void:
	var good: bool = ok if ok is bool else str(ok) != ""
	print("CHECK %s %s %s" % ["ok  " if good else "FAIL", label, detail])
	if not good:
		problems.append(label + " " + detail)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	print("shot %s (%s) %s" % [name, img.get_size(), "ok" if err == OK else "ERR %d" % err])


func _window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	await _sec(0.6)
	print("window now ", DisplayServer.window_get_size(), " visible rect ", root.get_visible_rect())


func _sec(t: float) -> void:
	await create_timer(t).timeout


func _until(cond: Callable, timeout: float = 15.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			print("TIMEOUT waiting (state %s)" % (office.debug_state() if is_instance_valid(office) else "?"))
			problems.append("timeout")
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


## Chapter Select jump to chapter n (a new office scene; the jumped-over chapters stay as they are).
func _jump(n: int) -> void:
	game.select_chapter(n)
	change_scene_to_file(OFFICE)
	office = await _wait_office(office)
	await _drive("ACTIVE")
	await _sec(0.4)


## E on the desk phone: answers a ringing call, or opens the keypad and dials the number the step asks for.
func _phone() -> void:
	await office.debug_interact("telephone")
	await _sec(0.3)
	if office.dial_pad.is_open():
		await office.debug_dial(office.session.expected_number())


## Plays every item still open through the hooks (inspections, first correct choice, exact checklists) until the
## chapter's feedback: the items this capture does not show one by one (c3_printer, c4_delivery).
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
				office.desktop.handle_back()
				await _until(func() -> bool: return not office.desktop.is_open() and not office.get("_busy"))
			await _phone()
			await _wait_playback()
		elif s.item_surface(id) == "desktop":
			if not office.desktop.is_open():
				await office.debug_interact("workstation")
				await _sec(0.4)
			office.debug_select_item(id)
			await _sec(0.2)
		for k: Variant in s.item(id).required_inspections:
			office.debug_inspect(str(k))
		await _sec(0.1)
		var st: Dictionary = s.step()
		if s.is_checklist():
			var real: Array[int] = []
			for i: int in st.options.size():
				if bool(st.options[i].real):
					real.append(i)
			office.debug_check(real)
		else:
			for i: int in st.choices.size():
				if str(st.choices[i].outcome) == "correct":
					office.debug_choose(i)
					break
		await _continue()
		await _sec(0.3)


func _continue() -> void:
	await _until(func() -> bool: return office.outcome_panel.is_open())
	await _sec(0.2)
	office.debug_advance()
	await _until(func() -> bool:
		var st: String = office.debug_state()
		return (st != "OUTCOME" and not office.get("_busy")) or st in ["FEEDBACK", "COMPROMISED", "GAME_OVER"])
	await _sec(0.1)


func _wait_playback() -> void:
	await _until(func() -> bool: return office.call_ui.is_open() and not bool(office.call_ui.get("_playing")) and not office.get("_busy"))
	await _sec(0.2)


func _wait_office(old: Node) -> Node:
	var old_id: int = old.get_instance_id() if old != null and is_instance_valid(old) else 0
	await _until(func() -> bool:
		var cs := current_scene
		return cs != null and is_instance_valid(cs) and cs.get_instance_id() != old_id and cs.scene_file_path == OFFICE and cs.has_method("debug_state"))
	await process_frame
	return current_scene


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


func _look(player: Node3D, target: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var to := target - head.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _press(btn: Button, what: String) -> void:
	if btn == null:
		print("MISSING button: ", what)
		problems.append("missing button " + what)
		return
	if btn.disabled:
		print("DISABLED button: ", what)
		problems.append("disabled button " + what)
		return
	btn.pressed.emit()


func _choose(surface: Node, text: String) -> void:
	_press(_btn(surface, text), "choice '" + text + "'")


func _row(id: String) -> Button:
	return office.desktop.find_child("Item_" + id, true, false) as Button


func _rail(app: String) -> void:
	for rb: Node in office.desktop.find_children("*", "Button", true, false):
		if (rb as Button).tooltip_text == "Open " + app:
			(rb as Button).pressed.emit()
			return


func _copy_paste_link(link_id: String) -> void:
	var body := _find_rich_with(office.desktop, "[url=" + link_id + "]")
	if body == null:
		print("MISSING link ", link_id)
		problems.append("missing link " + link_id)
		return
	body.meta_clicked.emit(link_id)
	await _sec(0.15)
	var menus: Array[Node] = office.desktop.find_children("*", "PopupMenu", true, false)
	if not menus.is_empty():
		var menu := menus[0] as PopupMenu
		menu.id_pressed.emit(menu.get_item_id(0))
		menu.hide()
	await _sec(0.1)
	_rail("Browser")
	await _sec(0.1)
	_press(_btn(office.desktop, "Paste"), "Paste")
	await _sec(0.2)


func _real_options(n: int, id: String, step: int) -> Array[int]:
	var out: Array[int] = []
	var opts: Array = Campaign.item(n, id).steps[step].options
	for i: int in opts.size():
		if bool(opts[i].real):
			out.append(i)
	return out


func _boxes(surface: Node) -> Array[CheckBox]:
	var out: Array[CheckBox] = []
	for n: Node in surface.find_children("Check_*", "CheckBox", true, false):
		if (n as CheckBox).is_visible_in_tree() and not n.is_queued_for_deletion():
			out.append(n as CheckBox)
	return out


func _tick(surface: Node, indices: Array[int]) -> void:
	var boxes := _boxes(surface)
	if boxes.is_empty():
		problems.append("no checklist boxes")
		print("MISSING checklist boxes")
	for box: CheckBox in boxes:
		var i := int(str(box.name).trim_prefix("Check_"))
		box.button_pressed = indices.has(i)


func _ticked(surface: Node) -> Array[int]:
	var out: Array[int] = []
	for box: CheckBox in _boxes(surface):
		if box.button_pressed:
			out.append(int(str(box.name).trim_prefix("Check_")))
	out.sort()
	return out


func _sorted(a: Array[int]) -> Array[int]:
	var c: Array[int] = a.duplicate()
	c.sort()
	return c


func _submit_button(surface: Node) -> Button:
	for n: Node in surface.find_children("Submit", "Button", true, false):
		if (n as Button).is_visible_in_tree() and not n.is_queued_for_deletion():
			return n as Button
	return null


func _submit(surface: Node) -> void:
	_press(_submit_button(surface), "Submit")


func _btn_prefix(node: Node, prefix: String) -> Button:
	for bn: Node in node.find_children("*", "Button", true, false):
		var btn := bn as Button
		if btn.text.begins_with(prefix) and btn.is_visible_in_tree() and not btn.is_queued_for_deletion():
			return btn
	return null


func _btn(node: Node, text: String) -> Button:
	for bn: Node in node.find_children("*", "Button", true, false):
		var btn := bn as Button
		if btn.text == text and btn.is_visible_in_tree() and not btn.is_queued_for_deletion():
			return btn
	return null


func _find_rich_with(node: Node, needle: String) -> RichTextLabel:
	for r: Node in node.find_children("*", "RichTextLabel", true, false):
		if (r as RichTextLabel).text.contains(needle) and (r as RichTextLabel).is_visible_in_tree():
			return r as RichTextLabel
	return null


## Visible buttons, check boxes, labels and panels (outside scroll areas) that leave the viewport.
func _layout(tag: String, node: Node) -> void:
	await process_frame
	var vp := root.get_visible_rect()
	var bad: Array[String] = []
	for c: Node in node.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or _in_scroll(ctl):
			continue
		if not (ctl is Button or ctl is Label or ctl is PanelContainer or ctl is ScrollContainer):
			continue
		var r := ctl.get_global_rect()
		if r.size.x < 1 or r.size.y < 1:
			continue
		if r.position.x < vp.position.x - 1 or r.position.y < vp.position.y - 1 or r.end.x > vp.end.x + 1 or r.end.y > vp.end.y + 1:
			var txt := ""
			if ctl is Button:
				txt = (ctl as Button).text
			elif ctl is Label:
				txt = (ctl as Label).text
			bad.append("%s '%s' %s" % [ctl.get_class(), txt.left(40), r])
	print("LAYOUT %s: %d outside %s" % [tag, bad.size(), vp])
	for s: String in bad.slice(0, 8):
		print("    ", s)
	if not bad.is_empty():
		problems.append("layout " + tag + ": " + str(bad.size()) + " controls outside the viewport")


## Which visible scroll areas actually scroll (content hidden until the player scrolls).
func _scroll_report(tag: String, node: Node) -> void:
	await process_frame
	for c: Node in node.find_children("*", "ScrollContainer", true, false):
		var s := c as ScrollContainer
		if not s.is_visible_in_tree():
			continue
		var v := s.get_v_scroll_bar()
		var h := s.get_h_scroll_bar()
		if v.visible or h.visible:
			print("SCROLL %s: %s size %s v=%s (max %d page %d) h=%s" % [tag, s.name, s.size, v.visible, int(v.max_value), int(v.page), h.visible])


func _in_scroll(ctl: Control) -> bool:
	var p := ctl.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false
