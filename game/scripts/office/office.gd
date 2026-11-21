extends Node3D
## Office director (root of office.tscn). Builds the chapter's place, the player and every overlay, then runs the
## chapter flow of contract "Module E": intro, briefing, inspect, decide, outcome, feedback, game over.
## Objectives 4 (ten chapters in order), 6 (scoring, outcome, compromise, game over, restart) and 7 (progress shown).
## Each chapter is a workday of several items (TASKS-SPEC.md C.4): the chapter is complete once every item is
## resolved; an unsafe choice in any item ends it. _update_world() re-arms the devices after every transition.
##
## One scene serves the whole week. The place ("office", "home" or "cafe", from the chapter data) is a
## LocationBuilder; when the next chapter is somewhere else, _start_chapter swaps the builder in this same node
## (_switch_place). At the office the workstation (DesktopUI) and the desk phone are used; at home and at the cafe
## the player's smartphone opens PhoneUI, and its calls use the same CallUI and DialPad (reconfigured per place).
##
## It is the only place that reads the "back", "advance" and "interact" actions, and the only place that sets
## the mouse mode and the player's controls: while any overlay is open the mouse is free and the player cannot move.

## Flow states reported by debug_state() (kept in `state`).
const S_LOADING := "LOADING"
const S_INTRO := "INTRO"
const S_BRIEFING := "BRIEFING"
const S_ACTIVE := "ACTIVE"            ## the chapter is playable (walk, inspect, decide, or wait for the telephone)
const S_OUTCOME := "OUTCOME"          ## the Outcome panel is showing after a choice
const S_COMPROMISED := "COMPROMISED"  ## the red compromise notice is showing
const S_GAME_OVER := "GAME_OVER"      ## the bad ending screen (Restart Chapter / Main Menu)
const S_FEEDBACK := "FEEDBACK"        ## chapter complete, debrief on screen
const S_LEAVING := "LEAVING"          ## a scene change has been requested
## Transition states: the cursor stays free and the player stays frozen even in the gap between two overlays.
## BRIEFING is not here: the briefing dialogue closes while the state is still BRIEFING, and that is where
## the mouse must be captured for play.
const HOLD_UI_STATES: Array[String] = [S_LOADING, S_INTRO, S_OUTCOME, S_COMPROMISED, S_GAME_OVER, S_FEEDBACK, S_LEAVING]

const FOCUS_TIME := 0.4
const RELEASE_TIME := 0.3
const DIAL_CONNECT_TIME := 0.9     ## one ring of ringback before a placed call connects
const WORKSTATION_PROMPT := "Use workstation"
const TELEPHONE_PROMPT := "Answer the telephone"
## The smartphone off the clock (home and cafe).
const PHONE_PROMPT := "Check your phone"
const PHONE_ANSWER_PROMPT := "Answer your phone"
const BUILDER_NAME := "Builder"

# --- Public test hooks (contract Module E step 8) ---
var state: String = S_LOADING
var session: ChapterSession

# --- Scene parts (public so the integration test can reach them) ---
var builder: LocationBuilder      ## the current place (OfficeBuilder, HomeBuilder or CafeBuilder), node "Builder"
var player: Player
var ui_layer: CanvasLayer
var hud: HUD
var dialogue: DialoguePanel
var desktop: DesktopUI             ## the office workstation
var phone_ui: PhoneUI              ## the player's smartphone (home and cafe); see screen()
var call_ui: CallUI
var dial_pad: DialPad
var board_view: NoticeBoard         ## the pantry notice board up close (feel only)
var outcome_panel: OutcomePanel
var compromise_notice: CompromiseNotice
var game_over: GameOverScreen
var feedback_screen: FeedbackScreen
var pause_menu: PauseMenu
var tutorial: TutorialHint          ## guided first task of a new game (never takes input except Skip)
var _tutorial_pending: bool = false
var title_card: TitleCard          ## "Chapter N · Title · time" at each chapter start (never takes input)

## Open overlays, oldest first; the last one is on top and receives back/advance.
var _stack: Array[Overlay] = []
## True while an outcome, transition or camera move is running: blocks new choices, interactions and pause.
var _busy: bool = false
## True while the camera is gliding to or from a device: keeps the player still even with no overlay open.
var _cinematic: bool = false
## Whether the phone was ringing at the last _update_world() (to toast "ringing" only when it starts).
var _was_ringing: bool = false
## New desktop items waiting at the last _update_world() (a soft ping when more arrive).
var _new_count: int = 0
## True while the keypad was opened from the phone's Calls app: hanging up returns to the phone.
var _pad_from_phone: bool = false


func _ready() -> void:
	_build()
	_apply_input_mode()
	Audio.start_ambient()
	_begin.call_deferred()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.stop_ambient()


## Frees the mouse when the window loses focus and restores the rule when it comes back.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree():
		_apply_input_mode()


# =====================================================================================================
# Building
# =====================================================================================================

func _build() -> void:
	# The place of the chapter about to load (Restart Chapter / Chapter Select); a new game starts at the office.
	var n := Game.current_chapter if Game.is_restart else 1
	builder = LocationBuilder.create(_place_of(n))
	builder.name = BUILDER_NAME
	add_child(builder)
	# Light the place for that chapter before the first frame.
	builder.apply_chapter_mood(n)

	player = Player.new()
	player.name = "Player"
	add_child(player)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 10
	add_child(ui_layer)

	# Child order is draw order: later overlays draw on top of earlier ones.
	hud = HUD.new()
	hud.name = "HUD"
	ui_layer.add_child(hud)

	dialogue = DialoguePanel.new()
	desktop = DesktopUI.new()
	phone_ui = PhoneUI.new()
	call_ui = CallUI.new()
	dial_pad = DialPad.new()
	board_view = NoticeBoard.new()
	outcome_panel = OutcomePanel.new()
	compromise_notice = CompromiseNotice.new()
	game_over = GameOverScreen.new()
	feedback_screen = FeedbackScreen.new()
	pause_menu = PauseMenu.new()
	var overlays: Array[Overlay] = [dialogue, desktop, phone_ui, call_ui, dial_pad, board_view, outcome_panel,
		compromise_notice, game_over, feedback_screen, pause_menu]
	var names: Array[String] = ["DialoguePanel", "DesktopUI", "PhoneUI", "CallUI", "DialPad", "NoticeBoardView",
		"OutcomePanel", "CompromiseNotice", "GameOverScreen", "FeedbackScreen", "PauseMenu"]
	for i: int in overlays.size():
		var o: Overlay = overlays[i]
		o.name = names[i]
		ui_layer.add_child(o)
		o.opened.connect(_on_overlay_opened)
		o.closed.connect(_on_overlay_closed)
	# Drawn above every overlay; it ignores the mouse and is not part of the overlay stack.
	title_card = TitleCard.new()
	title_card.name = "TitleCard"
	ui_layer.add_child(title_card)
	tutorial = TutorialHint.new()
	tutorial.name = "Tutorial"
	ui_layer.add_child(tutorial)

	player.prompt_changed.connect(hud.set_prompt)
	_connect_builder()

	dial_pad.dialed.connect(_on_dialed)
	dial_pad.cancelled.connect(_on_dial_cancelled)
	dial_pad.digits_changed.connect(_on_dial_digits)
	# The workstation and the smartphone are the same kind of screen: the same handlers serve both.
	for s: DesktopUI in [desktop, phone_ui]:
		s.inspected.connect(_on_inspected)
		s.choice_selected.connect(_on_choice_selected)
		s.close_requested.connect(_on_desktop_close_requested)
		s.item_selected.connect(_on_item_selected)
		s.checklist_submitted.connect(_on_checklist_submitted)
	phone_ui.answer_requested.connect(_on_phone_answer)
	phone_ui.dial_requested.connect(_on_phone_dial)
	call_ui.inspected.connect(_on_inspected)
	call_ui.choice_selected.connect(_on_choice_selected)
	call_ui.checklist_submitted.connect(_on_checklist_submitted)
	pause_menu.resume_pressed.connect(_on_pause_resume)
	pause_menu.menu_pressed.connect(_go_to_menu)
	pause_menu.select_pressed.connect(_to_chapter_select)
	game_over.restart_pressed.connect(_on_restart_pressed)
	game_over.menu_pressed.connect(_go_to_menu)

	_configure_devices()
	_disable_devices()


## Hooks up the current builder's devices (null-safe: home and cafe have only the smartphone; the office has the
## workstation, the desk phone, the pantry and the notice board). Called after every build or place switch.
func _connect_builder() -> void:
	var devices: Array[Interactable] = [builder.workstation, builder.telephone, builder.phone, builder.notice_board]
	# The pantry (coffee, water, notice board) works in every office chapter and never touches the score.
	if builder.pantry != null:
		devices.append(builder.pantry.coffee_machine)
		devices.append(builder.pantry.water_cooler)
	for d: Interactable in devices:
		if d != null and not d.interacted.is_connected(_on_device_interacted):
			d.interacted.connect(_on_device_interacted)
	var avoid: Array[Node3D] = [player]
	builder.set_walker_obstacles(avoid)


## The call screen, the keypad and the room tone follow the place: the desk phone and its phone card at the
## office; the player's phone and the hotlines card (bank, e-wallet, 1326) at home and at the cafe.
func _configure_devices() -> void:
	if builder.location == "office":
		call_ui.configure_device("Phone card", Campaign.PHONE_CARD)
		dial_pad.configure_device("DESK PHONE", "PHONE CARD", Campaign.PHONE_CARD)
	else:
		call_ui.configure_device("Hotlines", Campaign.PHONE_CARD_MOBILE)
		dial_pad.configure_device("YOUR PHONE", "HOTLINES", Campaign.PHONE_CARD_MOBILE)
	Audio.set_place_ambient(builder.location)


## The place of chapter n ("office", "home" or "cafe").
func _place_of(n: int) -> String:
	if n < 1 or n > Campaign.CHAPTERS.size():
		return "office"
	return str(Campaign.chapter(n).get("place", "office"))


## Moves the scene to another place in this same node: the old builder is removed (its ringtone stops) and the
## new one takes its place in the tree, before the Player. False when already there (nothing changes).
func _switch_place(place: String) -> bool:
	if builder != null and builder.location == place:
		return false
	_disable_devices()
	var index := get_child_count()
	if builder != null:
		index = builder.get_index()
		remove_child(builder)
		builder.queue_free()
	builder = LocationBuilder.create(place)
	builder.name = BUILDER_NAME
	add_child(builder)
	move_child(builder, mini(index, get_child_count() - 1))
	_connect_builder()
	_configure_devices()
	_disable_devices()
	return true


## Stands the player at the chapter spawn looking at the chapter's device, so its [E] prompt shows at once (a level
## gaze passes over the desk): the desk phone for a telephone chapter, the monitor otherwise, and the smartphone
## at home and at the cafe.
func _spawn_at_device(n: int) -> void:
	var device: String = Campaign.chapter(n).get("device", "workstation")
	var aim := builder.phone_point if (device == "telephone" or builder.location != "office") else builder.monitor_point
	var eye := builder.chapter_spawn.origin + Vector3.UP * Player.EYE_HEIGHT
	var to := aim - eye
	var spawn := builder.chapter_spawn
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > 0.01:
		spawn = Transform3D(Basis.looking_at(flat, Vector3.UP), spawn.origin)
	player.teleport(spawn, atan2(to.y, flat.length()))


## The screen the session is played on: the workstation at the office, the smartphone elsewhere.
func screen() -> DesktopUI:
	return desktop if _at_office() else phone_ui


func _at_office() -> bool:
	return builder == null or builder.location == "office"


# =====================================================================================================
# Overlay stack and the mouse / controls rule
# =====================================================================================================

func _on_overlay_opened(o: Overlay) -> void:
	_stack.erase(o)
	_stack.append(o)
	_apply_input_mode()


func _on_overlay_closed(o: Overlay) -> void:
	_stack.erase(o)
	_apply_input_mode()


## The overlay on top of the stack (null when the player is walking).
func top_overlay() -> Overlay:
	return _top()


func _top() -> Overlay:
	return null if _stack.is_empty() else _stack.back()


## Any overlay open (or a transition state): mouse visible, player frozen. Otherwise: mouse captured,
## controls on (unless the camera is moving).
func _apply_input_mode() -> void:
	var ui_open := not _stack.is_empty() or state in HOLD_UI_STATES
	var mode := Input.MOUSE_MODE_VISIBLE if ui_open else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
	if player != null:
		player.controls_enabled = not ui_open and not _cinematic
	if hud != null:
		hud.set_crosshair_visible(not ui_open)


## Every flow transition goes through here so a state change always re-applies the mouse / controls rule.
func _set_state(s: String) -> void:
	state = s
	_apply_input_mode()


func _set_cinematic(on: bool) -> void:
	_cinematic = on
	_apply_input_mode()


# =====================================================================================================
# Input routing
# =====================================================================================================

func _unhandled_input(event: InputEvent) -> void:
	if Router.is_busy() or state == S_LEAVING:
		return
	var top := _top()
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		if top != null:
			top.handle_back()
		elif not _busy and state == S_ACTIVE:
			pause_menu.open()
		return
	if top != null:
		# E is both "advance" and "interact": with an overlay open it only ever advances.
		if event.is_action_pressed("advance"):
			get_viewport().set_input_as_handled()
			top.handle_advance()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if not _busy and state == S_ACTIVE:
			var target := player.get_focus()
			if target != null:
				target.interact()
		return
	# A click in the 3D view recaptures the mouse if the window gave it back (e.g. after alt-tab).
	if event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_apply_input_mode()


# =====================================================================================================
# Chapter flow
# =====================================================================================================

## Entry point: Restart Chapter skips the intro and spawns at the chapter's device (the scene was already built at
## the chapter's place); a new game plays the intro first, at the office.
func _begin() -> void:
	if Game.is_restart:
		Game.is_restart = false
		_spawn_at_device(Game.current_chapter)
		await _start_chapter(Game.current_chapter)
	else:
		builder.apply_chapter_mood(1)
		Audio.reset_streak()
		Audio.set_music("day")
		player.teleport(builder.intro_spawn)
		_busy = true
		_set_state(S_INTRO)
		hud.refresh()
		hud.set_objective("")
		dialogue.play(Campaign.INTRO)
		await dialogue.finished
		_tutorial_pending = true     # a new game only: Restart Chapter skips this branch
		await _start_chapter(1)


## Briefing, then arms the devices for the chapter's first items. Ends in ACTIVE.
## When the chapter is somewhere else (office -> home -> office ...), the place is swapped first, in this same node,
## behind a short fade to black, and the player stands at the new place's device.
func _start_chapter(n: int) -> void:
	_busy = true
	# Plain assignment: re-applying the mouse rule here would capture the mouse for one frame between the
	# previous screen (intro / feedback) and the briefing dialogue, which opens just below.
	state = S_BRIEFING
	var place := _place_of(n)
	if builder.location != place:
		# Nothing of the previous chapter stays on the HUD while the screen fades out.
		_disable_devices()
		hud.set_tasks([], 0)
		hud.set_objective("")
		await Router.fade_out()
		if not is_inside_tree():
			return
		_switch_place(place)
		_spawn_at_device(n)
		Router.fade_in()          # not awaited: the briefing opens while the new place fades in
	Game.begin_chapter(n)
	builder.apply_chapter_mood(n)     # time of day for this chapter (also after Restart Chapter)
	session = ChapterSession.new(Campaign.chapter(n))
	_was_ringing = false
	_new_count = 0
	_pad_from_phone = false
	_disable_devices()
	builder.set_phone_ringing(false)
	builder.set_monitor_alert(false)
	Audio.set_music(Audio.track_for_chapter(n))   # crossfades to the chapter's own track (chapter data "music")
	# The HUD must not show the previous chapter's tasks during the briefing.
	hud.set_tasks([], 0)
	hud.refresh()
	hud.set_objective("")
	if Game.jump_item != "":
		# Chapter Select jumped to one subquest: the items before it are skipped (resolved, no points).
		session.skip_to(Game.jump_item)
		session.select_item(Game.jump_item)
		Game.jump_item = ""
	dialogue.play(session.chapter.briefing)
	title_card.show_card(n, str(session.chapter.get("title", "")))    # plays over the briefing, non-blocking
	await dialogue.finished
	title_card.dismiss()
	hud.set_tasks(session.task_list(), session.task_count())
	_update_world()
	_set_state(S_ACTIVE)
	_busy = false
	if _tutorial_pending:
		_tutorial_pending = false
		tutorial.begin(self)


## Re-arms the world from the session after every transition: which device is usable and its prompt, the
## ringing phone, the "N new" monitor label, the HUD objective and the task list (Objective 7).
func _update_world() -> void:
	if session == null:
		return
	if not _at_office():
		_update_phone_world()
		return
	var objective := session.objective()
	var call_open := call_ui.is_open()
	var phone_id := session.phone_item()
	var incoming := session.phone_incoming()
	var phone_prompt := TELEPHONE_PROMPT
	if not incoming and phone_id != "":
		phone_prompt = session.item_step(phone_id).get("trigger_prompt", TELEPHONE_PROMPT)
	_set_device(builder.telephone, phone_id != "" and not call_open, phone_prompt, objective)
	_set_device(builder.workstation, session.desktop_pending(), WORKSTATION_PROMPT, objective)
	var ringing := incoming and not call_open
	builder.set_phone_ringing(ringing)
	if ringing:
		builder.set_phone_display(_caller_display(session.item(phone_id)))
	elif not call_open and not dial_pad.is_open():
		builder.set_phone_display("READY")
	if ringing and not _was_ringing and desktop.is_open():
		desktop.notify("Your desk phone is ringing")
	_was_ringing = ringing
	var n := session.new_desktop_count()
	builder.set_monitor_alert(n > 0 and not desktop.is_open(), n)
	if n > _new_count and not desktop.is_open():
		Audio.play_sfx("notify_ping", -4.0)        # new mail / messages waiting on the monitor
	_new_count = n
	hud.set_objective(objective)
	hud.set_tasks(session.task_list(), session.task_count())
	hud.refresh()


## _update_world() at home and at the cafe: one device, the smartphone. It is usable while anything waits on it
## (a message, a ringing call, a call to place) and the phone is not already in the player's hands. It rings with
## the one ringtone for every call; the "N new" label and the soft ping follow the same rule as the office monitor
## (the same sound for every item). The PhoneUI's own banner announces a call that rings while the phone is open.
func _update_phone_world() -> void:
	var objective := session.objective()
	var call_open := call_ui.is_open()
	var phone_id := session.phone_item()
	var incoming := session.phone_incoming()
	var in_hand := phone_ui.is_open() or call_open or dial_pad.is_open()
	var on := (session.desktop_pending() or phone_id != "") and not in_hand
	var prompt := PHONE_PROMPT
	if incoming:
		prompt = PHONE_ANSWER_PROMPT
	elif _phone_call_waits():
		prompt = str(session.item_step(phone_id).get("trigger_prompt", PHONE_PROMPT))
	_set_device(builder.phone, on, prompt, objective)
	var ringing := incoming and not call_open
	builder.set_phone_ringing(ringing)
	if ringing:
		builder.set_phone_display(_caller_display(session.item(phone_id)))
	elif not call_open and not dial_pad.is_open():
		builder.set_phone_display("READY")
	_was_ringing = ringing
	var n := session.new_desktop_count()
	builder.set_monitor_alert(n > 0 and not phone_ui.is_open(), n)
	if n > _new_count and not phone_ui.is_open():
		Audio.play_sfx("notify_ping", -4.0)        # new messages waiting on the phone
	_new_count = n
	hud.set_objective(objective)
	hud.set_tasks(session.task_list(), session.task_count())
	hud.refresh()


## A call the player places (a wait_for "telephone" step) is what the phone is for right now: no message waits.
## When both wait, E on the phone opens the phone itself; its Calls keypad leads to the call.
func _phone_call_waits() -> bool:
	var id := session.phone_item()
	if id == "" or session.desktop_pending():
		return false
	return str(session.item_step(id).get("wait_for", "")) == "telephone"


func _on_device_interacted(device_id: String) -> void:
	_use_device(device_id)


## What E on a device does. Awaitable: returns once the desktop or call is open (or nothing happened).
func _use_device(device_id: String) -> void:
	if _busy or state != S_ACTIVE or session == null:
		return
	match device_id:
		"workstation":
			if builder.workstation != null and builder.workstation.enabled and not desktop.is_open() \
					and not call_ui.is_open():
				await _open_workstation()
		"telephone":
			if builder.telephone != null and builder.telephone.enabled and not call_ui.is_open():
				await _open_telephone()
		"phone":
			# The smartphone: a ringing call or a call to place opens the call side; anything else opens the phone.
			if builder.phone == null or not builder.phone.enabled or phone_ui.is_open() or call_ui.is_open() \
					or dial_pad.is_open():
				return
			if session.phone_incoming() or _phone_call_waits():
				await _open_telephone()
			else:
				await _open_workstation()
		"coffee", "water":
			if builder.pantry != null:
				builder.pantry.use(device_id)
		"board":
			if builder.notice_board != null:
				board_view.open_board()


## Sit at the monitor and open the desktop (at home or at the cafe: pick up the phone and open it). Re-opening
## keeps the session (inspections, disabled options, page). If no usable desktop item is selected, the first
## pending one is selected.
func _open_workstation() -> void:
	_busy = true
	if _at_office():
		Audio.play_sfx("desk_open", -3.0)
	else:
		Audio.play_sfx("app_switch", -6.0)      # the phone wakes up (the same sound for every item)
	_set_cinematic(true)
	var cur := session.item_id
	if cur == "" or session.is_done(cur) or session.item_surface(cur) != "desktop":
		session.select_item(session.next_desktop_item())
	builder.set_monitor_alert(false)
	await player.focus_camera_on(builder.monitor_point, FOCUS_TIME)
	screen().open_session(session)
	# A call that was already ringing before the player sat down is announced too (the phone shows its banner).
	if session.phone_incoming() and _at_office():
		desktop.notify("Your desk phone is ringing")
	_set_cinematic(false)
	_busy = false
	_update_world()


## Answer the ringing phone or place a call to a known number (a wait_for step). Closes the desktop (or the
## phone's apps) first.
func _open_telephone() -> void:
	_busy = true
	_set_cinematic(true)
	_pad_from_phone = false
	session.select_item(session.phone_item())
	builder.set_phone_ringing(false)
	_was_ringing = false
	if screen().is_open():
		screen().hide_overlay()
	if _at_office():
		_set_device(builder.telephone, false, TELEPHONE_PROMPT, "")
	else:
		_set_device(builder.phone, false, PHONE_PROMPT, "")
	Audio.play_sfx("phone_pickup")
	await player.focus_camera_on(builder.phone_point, FOCUS_TIME)
	if session.waits_for_telephone():
		# A call the player places: dial the extension (or the hotline) on the keypad first.
		builder.set_phone_display("DIAL")
		dial_pad.open_pad(str(session.step().get("wait_objective", "")))
		_set_cinematic(false)
		_busy = false
		if not _at_office():
			_update_world()      # the phone's prompt and "N new" label follow (the office keeps its old timing)
		return
	builder.set_phone_display(_caller_display(session.item()))
	call_ui.open_session(session)
	_set_cinematic(false)
	_busy = false
	_update_world()


## The Answer button of the phone's incoming-call banner (PhoneUI): the same as picking up the ringing phone.
func _on_phone_answer() -> void:
	if _busy or state != S_ACTIVE or session == null:
		return
	if session.phone_incoming():
		await _open_telephone()


## The Calls app's Keypad button (PhoneUI): a call waits to be placed, so the keypad opens over the phone (the
## camera is already on it). Hanging up the keypad returns to the phone.
func _on_phone_dial() -> void:
	if _busy or state != S_ACTIVE or session == null:
		return
	var id := session.phone_item()
	if id == "" or str(session.item_step(id).get("wait_for", "")) != "telephone":
		return
	if not phone_ui.is_open():
		await _open_telephone()
		return
	session.select_item(id)
	builder.set_phone_ringing(false)
	builder.set_phone_display("DIAL")
	# Open the keypad before closing the phone so the cursor never flips to captured in between.
	dial_pad.open_pad(str(session.step().get("wait_objective", "")))
	phone_ui.hide_overlay()
	_pad_from_phone = true
	_update_world()


## The number the current outgoing call needs: its "dial" key (a hotline such as 8700 or 1326), else the
## extension in its call header ("EXT 2045: R. RAMOS" -> "2045"). See ChapterSession.expected_number().
func _expected_extension() -> String:
	return session.expected_number()


func _on_dial_digits(number: String) -> void:
	builder.set_phone_display(number if number != "" else "DIAL")


## Call pressed on the keypad: the right number rings and connects; any other number does not answer. A wrong
## number never changes the score; it is only logged (Hotline Hero counts misdialed hotlines).
func _on_dialed(number: String) -> void:
	if _busy or session == null or not session.waits_for_telephone():
		return
	if number != _expected_extension():
		Game.record_event("misdial", {"item": session.item_id, "step": session.step_index, "number": number,
			"hotline": session.step().has("dial")})
		Audio.play_sfx("no_answer", -4.0)
		dial_pad.no_answer(("Ext. " + number) if _at_office() else number)     # clears the digits first...
		builder.set_phone_display("NO ANSWER")    # ...so the phone screen keeps this until the next key
		return
	_busy = true
	builder.set_phone_display("CALLING " + number)
	Audio.play_sfx("ringback", -4.0)
	await get_tree().create_timer(DIAL_CONNECT_TIME).timeout
	if not is_inside_tree() or state != S_ACTIVE:
		return
	dial_pad.hide_overlay()
	_pad_from_phone = false
	builder.set_phone_display(("EXT " if _at_office() else "HOTLINE ") + number)
	call_ui.open_session(session)
	_busy = false
	_update_world()


## Hang up on the keypad (or ESC) before calling: stand back up; the call can be placed later. If the keypad was
## opened from the phone's Calls app, the phone stays in hand and shows Calls again.
func _on_dial_cancelled() -> void:
	if session == null:
		return
	builder.set_phone_display("READY")
	if _pad_from_phone and not _at_office() and state == S_ACTIVE:
		_pad_from_phone = false
		phone_ui.open_session(session)
		phone_ui.show_app("calls")
		_update_world()
		return
	_pad_from_phone = false
	_busy = true
	await player.release_camera(RELEASE_TIME)
	_busy = false
	_update_world()


## What the phone's screen shows for a ringing call: the caller ID text from the call data.
func _caller_display(it: Dictionary) -> String:
	var caller := str(it.get("call", {}).get("caller_id", ""))
	if caller == "":
		return "INCOMING"
	# The screen is small: show the number itself ("EXT 1100", or the last part of an outside line).
	if caller.begins_with("EXT"):
		return caller
	return caller.get_slice(" ", caller.get_slice_count(" ") - 1)


## ESC on the desktop (or Put phone away): stand up. The session is kept, so the player can come back.
func _on_desktop_close_requested() -> void:
	if _busy or not screen().is_open():
		return
	_busy = true
	if _at_office():
		Audio.play_sfx("desk_close", -4.0)
	_set_cinematic(true)
	screen().hide_overlay()
	await player.release_camera(RELEASE_TIME)
	_set_cinematic(false)
	_busy = false
	_update_world()


## An inbox / thread row was pressed: select that Mail, Messages, Chat or bank-app item.
func _on_item_selected(id: String) -> void:
	_select_desktop_item(id)


func _select_desktop_item(id: String) -> bool:
	if session == null or state != S_ACTIVE or _busy or not screen().is_open():
		return false
	var it := session.item(id)
	if it.is_empty():
		return false
	if not ChapterSession.DESKTOP_APPS.has(String(it.get("app", ""))):
		return false
	if not session.select_item(id):
		return false
	screen().refresh()
	_update_world()
	return true


## Objective 5: an inspection is recorded (links go to the item that owns them) and the open surface
## re-renders (the gate may unlock).
func _on_inspected(key: String) -> void:
	if session == null or state != S_ACTIVE:
		return
	var was_locked := not session.gate_open()
	if session.mark(key):
		Audio.play_evidence(session.inspected.size() - 1)     # each new piece of evidence rings higher
		if was_locked and session.gate_open():
			Audio.play_sfx("gate_unlock", -2.0)               # the choices just unlocked
	_refresh_surfaces()
	_update_world()


func _on_choice_selected(index: int) -> void:
	_resolve_choice(index)


## Objective 6: score the choice, show the outcome, then advance, stay, resolve the item or game over.
func _resolve_choice(index: int) -> void:
	if not _can_choose(index):
		return
	var choice: Dictionary = session.step().choices[index]
	var outcome: String = choice.outcome
	_busy = true
	_set_state(S_OUTCOME)
	_lock_choices(true)
	var delta := Game.apply_outcome(outcome, session.step_index, choice.text, session.item_id)
	_record_choice_events(choice, outcome)
	outcome_panel.show_outcome(outcome, delta, choice.feedback, choice.get("response_line", ""))
	await outcome_panel.continued
	match outcome:
		"correct":
			if choice.has("next_step"):
				await _advance_step(choice)
			else:
				_open_page(choice.get("opens", ""))
				_open_app(choice.get("opens_app", ""))
				await _resolve_item()
				return
		"wrong":
			_stay_on_step(index, choice)
		"unsafe":
			await _compromise(choice)


## The session-only events log behind the achievements (it never scores): giving away an OTP or MPIN
## (OTP Bantay) and any wrong or unsafe pick in a money-mule item (Not Your Mule). Kept across Restart Chapter.
func _record_choice_events(choice: Dictionary, outcome: String) -> void:
	if bool(choice.get("shares_secret", false)):
		Game.record_event("secret_shared", {"item": session.item_id, "step": session.step_index})
	if str(session.item().get("trap", "")) == "mule" and (outcome == "wrong" or outcome == "unsafe"):
		Game.record_event("trap_failed", {"item": session.item_id, "step": session.step_index, "outcome": outcome})


## Same rules as the choice buttons: an existing, enabled choice, gate open, its surface open, not a checklist.
func _can_choose(index: int) -> bool:
	if _busy or state != S_ACTIVE or session == null:
		return false
	var st := session.step()
	if st.is_empty() or session.is_checklist():
		return false
	var choices: Array = st.get("choices", [])
	if index < 0 or index >= choices.size():
		return false
	if session.is_disabled(index) or not session.gate_open():
		return false
	return _step_surface_open(st)


## The surface the step is played on is the one on screen (a wait_for step's choices appear only on the call).
func _step_surface_open(st: Dictionary) -> bool:
	match String(st.get("surface", "desktop")):
		"desktop":
			return screen().is_open()
		"call":
			return call_ui.is_open()
	return false


func _on_checklist_submitted(ticked: Array[int]) -> void:
	_resolve_checklist(ticked)


## Same rules as the Submit button: a checklist step, gate open, its surface open, an allowed tick set.
func _can_submit(ticked: Array[int]) -> bool:
	if _busy or state != S_ACTIVE or session == null:
		return false
	if not session.is_checklist() or not session.gate_open():
		return false
	if not _step_surface_open(session.step()):
		return false
	return session.can_submit(ticked)


## Report the warning signs: exact set = correct (+10), anything else = wrong (-5) and try again.
func _resolve_checklist(ticked: Array[int]) -> void:
	if not _can_submit(ticked):
		return
	Audio.play_sfx("stamp", -2.0)
	var st := session.step()
	_busy = true
	_set_state(S_OUTCOME)
	_lock_choices(true)
	session.set_ticks(ticked)
	var result := session.check(ticked)
	var correct := bool(result.correct)
	var outcome := "correct" if correct else "wrong"
	var delta := Game.apply_outcome(outcome, session.step_index, session.checklist_log_text(result), session.item_id)
	var feedback: String = st.get("feedback", "") if correct else session.checklist_feedback(result)
	outcome_panel.show_outcome(outcome, delta, feedback)
	await outcome_panel.continued
	if correct:
		if st.has("next_step"):
			await _advance_step(st)
		else:
			await _resolve_item()
		return
	session.record_try(ticked)
	_unlock_and_refresh()
	_update_world()
	_set_state(S_ACTIVE)
	_busy = false


## Correct with next_step (`src` is the choice, or the checklist step): move the item on; open a Browser page if
## it says so; then wait for the telephone, play the next call lines, or go from the call back to the desk.
func _advance_step(src: Dictionary) -> void:
	session.advance_to(int(src.next_step))
	_open_page(src.get("opens", ""))
	_open_app(src.get("opens_app", ""))
	var st := session.step()
	var surface: String = st.get("surface", "desktop")
	if session.waits_for_telephone() and call_ui.is_open():
		# The call ended and the next step is a call the player places (hang up, then call the number on your
		# card): the keypad opens at once. The camera is already on the phone. Office data never gets here.
		call_ui.close()
		builder.set_phone_display("DIAL")
		_pad_from_phone = false
		dial_pad.open_pad(str(st.get("wait_objective", "")))
	elif session.waits_for_telephone():
		_unlock_and_refresh()   # the desktop shows the wait objective; the telephone is armed below
	elif surface == "call" and call_ui.is_open():
		_lock_choices(false)
		# A call to a known extension (e.g. IT on ext. 1100) answers in the transcript before the next part.
		var reply: String = src.get("response_line", "")
		if reply != "":
			call_ui.add_reply(reply)
		call_ui.open_session(session)   # plays the next step's lines (e.g. "CALL ENDED", Security Office)
	elif surface == "desktop" and call_ui.is_open():
		# The call is over and the item continues at the desk: turn back to the monitor.
		_set_cinematic(true)
		call_ui.close()
		await player.focus_camera_on(builder.monitor_point, FOCUS_TIME)
		screen().open_session(session)
		_set_cinematic(false)
	else:
		_unlock_and_refresh()
	_update_world()
	_set_state(S_ACTIVE)
	_busy = false


## A correct choice's `opens` ("courier" / "directory"): the Browser shows that bookmark page (chapter-wide).
func _open_page(page: String) -> void:
	if page == "":
		return
	session.page = page
	if screen().is_open():
		screen().show_page(page)


## A correct choice's `opens_app` ("wallet", "wallet_inbox", "telco", "bank"): the phone switches to that app view
## now if it is open, else the next time it opens (PhoneUI consumes session.phone_app).
func _open_app(target: String) -> void:
	if target == "" or session == null:
		return
	session.phone_app = target
	if phone_ui.is_open():
		phone_ui.show_app(target)


## Wrong: -5 already applied; the option is disabled and the player stays on the same decision.
func _stay_on_step(index: int, choice: Dictionary) -> void:
	session.disable_choice(index)
	var line: String = choice.get("response_line", "")
	if line != "" and call_ui.is_open():
		call_ui.add_line(_caller_name(), line)
	_unlock_and_refresh()
	_update_world()
	_set_state(S_ACTIVE)
	_busy = false


## Correct without next_step: the item is resolved. The last one completes the chapter; otherwise the call
## (if any) hangs up and the next items become available.
func _resolve_item() -> void:
	session.resolve_current()
	if session.all_done():
		# Nothing may touch the state, the mouse or _busy after this: the next chapter (or a scene change) follows.
		await _complete_chapter()
		return
	if call_ui.is_open():
		_set_cinematic(true)
		call_ui.close()
		await player.release_camera(RELEASE_TIME)
		_set_cinematic(false)
	else:
		_unlock_and_refresh()
	_update_world()
	_set_state(S_ACTIVE)
	_busy = false


## Every item resolved: +20 (once), stand up, feedback screen, then the next chapter or the good ending.
func _complete_chapter() -> void:
	Game.complete_chapter()
	var earned := Achievements.unlock_new()
	_set_cinematic(true)
	_disable_devices()
	builder.set_phone_ringing(false)
	builder.set_monitor_alert(false)
	_was_ringing = false
	desktop.hide_overlay()
	phone_ui.hide_overlay()
	call_ui.close()
	hud.set_tasks(session.task_list(), session.task_count())
	hud.refresh()
	hud.set_objective("")
	await player.release_camera(RELEASE_TIME)
	_set_state(S_FEEDBACK)
	feedback_screen.show_feedback(session.chapter, earned)
	_set_cinematic(false)
	await feedback_screen.continued
	if feedback_screen.chose_select:
		_to_chapter_select()
	elif Game.all_complete():
		_set_state(S_LEAVING)
		Router.go_to(Router.ENDING)
	elif Game.next_chapter():
		await _start_chapter(Game.current_chapter)   # same scene; _start_chapter swaps the place if it changes
	else:
		_to_chapter_select()      # the last chapter is done but an earlier one is not: pick it from the cards


## Back to the chapter cards (the main menu opens straight on them). This run's results stay in memory.
func _to_chapter_select() -> void:
	if state == S_LEAVING:
		return
	_set_state(S_LEAVING)
	Game.open_select = true
	Router.go_to(Router.MAIN_MENU)


## Unsafe: compromise notice (2.5 s), then the bad ending with Restart Chapter / Main Menu. The game-over text
## comes from the item where the unsafe choice happened (its overrides), else the chapter.
func _compromise(choice: Dictionary) -> void:
	_set_state(S_COMPROMISED)
	_disable_devices()
	builder.set_phone_ringing(false)
	builder.set_monitor_alert(false)
	_was_ringing = false
	# Show the notice before closing the surfaces so the mouse never flips to captured in between. Off the clock
	# the notice shows a personal loss, never the Aegis header.
	compromise_notice.show_notice(choice.get("compromise", ""), builder.location)
	desktop.hide_overlay()
	phone_ui.hide_overlay()
	call_ui.close()
	await compromise_notice.finished
	_set_state(S_GAME_OVER)
	game_over.show_game_over(session.failure_context(), Game.score)


func _on_restart_pressed() -> void:
	if state == S_LEAVING:
		return
	_set_state(S_LEAVING)
	Audio.play_sfx("restart", -3.0)
	Game.restart_chapter()
	Router.go_to(Router.OFFICE)


func _on_pause_resume() -> void:
	pause_menu.hide_overlay()


func _go_to_menu() -> void:
	if state == S_LEAVING:
		return
	_set_state(S_LEAVING)
	Router.go_to(Router.MAIN_MENU)


# =====================================================================================================
# Helpers
# =====================================================================================================

## Null-safe: a place without that device (the office has no smartphone; home and cafe have only it) is skipped.
func _set_device(d: Interactable, on: bool, prompt: String, disabled_prompt: String) -> void:
	if d == null:
		return
	d.enabled = on
	d.prompt = prompt
	d.disabled_prompt = disabled_prompt


func _disable_devices() -> void:
	if builder == null:
		return
	_set_device(builder.workstation, false, WORKSTATION_PROMPT, "")
	_set_device(builder.telephone, false, TELEPHONE_PROMPT, "")
	_set_device(builder.phone, false, PHONE_PROMPT, "")


func _device(device_id: String) -> Interactable:
	match device_id:
		"workstation":
			return builder.workstation
		"telephone":
			return builder.telephone
		"phone":
			return builder.phone
	return null


func _lock_choices(locked: bool) -> void:
	if screen().is_open():
		screen().set_choices_locked(locked)
	if call_ui.is_open():
		call_ui.set_choices_locked(locked)


func _refresh_surfaces() -> void:
	if screen().is_open():
		screen().refresh()
	if call_ui.is_open():
		call_ui.refresh()


func _unlock_and_refresh() -> void:
	_lock_choices(false)
	_refresh_surfaces()


## Who speaks a response line on the call: the step's call_name (e.g. "HR"), else the item's caller, else the
## sender of the item's message.
func _caller_name() -> String:
	var st := session.step()
	var name_on_step: String = st.get("call_name", "")
	if name_on_step != "":
		return name_on_step
	var it := session.item()
	var c: Dictionary = it.get("call", {})
	var caller: String = c.get("caller_name", "")
	if caller != "":
		return caller
	var m: Dictionary = it.get("message", {})
	var sender: String = m.get("from_name", m.get("sender_label", ""))
	return sender if sender != "" else "Caller"


# =====================================================================================================
# Public test hooks (headless smoke test)
# =====================================================================================================

## "INTRO", "BRIEFING", "ACTIVE", "OUTCOME", "COMPROMISED", "GAME_OVER", "FEEDBACK", "LEAVING" (or "LOADING").
func debug_state() -> String:
	return state


## Same as looking at the device and pressing E (respects `enabled`). Coroutine: await it; it returns once the
## desktop or the call is open. Allowed while the desktop is open (the telephone closes it first).
## Devices: "workstation" and "telephone" at the office, "phone" (the smartphone) at home and at the cafe.
func debug_interact(device_id: String) -> void:
	var d := _device(device_id)
	if d == null or not d.enabled:
		print("debug_interact: %s is not enabled (ignored, like pressing E on a disabled device)" % device_id)
		return
	await _use_device(device_id)


## Dials a number on the open keypad and presses Call (awaitable: returns once the call is open or refused).
## Uses a pantry thing as if E was pressed on it ("coffee", "water" or "board"). Tests and captures only.
func debug_pantry(device_id: String) -> void:
	await _use_device(device_id)


func debug_dial(number: String) -> void:
	if not dial_pad.is_open():
		print("debug_dial: the keypad is not open")
		return
	for ch: String in number:
		dial_pad.press(ch)
	await _on_dialed(dial_pad.number)


## Same as the open surface emitting inspected(key).
func debug_inspect(key: String) -> void:
	_on_inspected(key)


## Same as clicking choice button `index`. Ignored (with a warning) when that button would be disabled.
func debug_choose(index: int) -> void:
	if not _can_choose(index):
		# Expected in tests (locked gate, disabled option, waiting for the phone): not an error.
		print("debug_choose(%d) ignored in state %s (choice locked or disabled)" % [index, state])
		return
	_resolve_choice(index)


## Same as pressing E: advances the top overlay (dialogue line, Continue, ...).
func debug_advance() -> void:
	var top := _top()
	if top != null:
		top.handle_advance()


## Same as pressing the inbox / thread row of `id`: only while ACTIVE, not busy, the screen (desktop or phone) open
## and `id` an available Mail / Messages / Chat / bank-app item. Returns true on success.
func debug_select_item(id: String) -> bool:
	var ok := _select_desktop_item(id)
	if not ok:
		print("debug_select_item(%s) ignored in state %s" % [id, state])
	return ok


## Same as ticking exactly `indices` and pressing Submit. Ignored (ticks untouched) when Submit would be disabled.
func debug_check(indices: Array[int]) -> void:
	if not _can_submit(indices):
		print("debug_check(%s) ignored in state %s (not a checklist, locked, or not allowed)" % [str(indices), state])
		return
	_resolve_checklist(indices)


## The selected item's id ("" = none).
func debug_item() -> String:
	return session.item_id if session != null else ""


## "done/total" of the chapter's task list (Objective 7).
func debug_tasks() -> String:
	if session == null:
		return "0/0"
	return "%d/%d" % [session.tasks_done(), session.task_count()]


## The current place: "office", "home" or "cafe".
func debug_place() -> String:
	return builder.location if builder != null else ""


## Same as pressing Answer on the phone's incoming-call banner (awaitable: returns once the call is open).
func debug_answer() -> void:
	await _on_phone_answer()


## Same as pressing Keypad in the phone's Calls app (awaitable: returns once the keypad is open, or nothing
## happened because no call waits to be placed).
func debug_open_keypad() -> void:
	await _on_phone_dial()
