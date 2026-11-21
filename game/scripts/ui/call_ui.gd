class_name CallUI
extends Overlay
## The telephone call screen (Objectives 3 and 5 for the telephone): the selected item's incoming call
## (Chapter 3) or a call to a known extension (HR, IT, Security, Mr. Ramos). Shows the caller ID (clickable and
## inspectable on step 0 of a call item) or the step's call header, the caller, a transcript that fills line by
## line, the phone card, and the decision area: choice buttons, or a warning-sign checklist (TASKS-SPEC C.9).
## Choices follow the same inspection gate as the desktop: locked until session.gate_open().
## ESC never hangs up; it only flashes the hint.
## configure_device() swaps the desk phone card for the hotlines of the player's phone (home and cafe chapters).

signal inspected(key: String)
signal choice_selected(index: int)
signal checklist_submitted(ticked: Array[int])

const ChecklistView := preload("res://scripts/ui/checklist_view.gd")

const CARD_WIDTH := 1080
const FIRST_LINE_DELAY := 0.6
const LINE_PAUSE := 0.5
const CHARS_PER_SECOND := 50.0
const LCD_BG := Color("0d2419")
const LCD_BORDER := Color("2f6b4c")
const LCD_TEXT := Color("7ee2a8")
const YOU := "You"
const CHECKLIST_LINE := "(tells Security the warning signs)"
const DEFAULT_CARD_TITLE := "Phone card"

var session: ChapterSession

# The device's card of known numbers (configure_device): the desk phone card in the office, the hotlines on the
# player's phone at home and in the cafe.
var _card_title: String = DEFAULT_CARD_TITLE
var _card_lines: Array[String] = Campaign.PHONE_CARD.duplicate()
var _card_box: VBoxContainer

var _status: Label
var _status_box: PanelContainer
var _caller_id_button: Button
var _header_box: PanelContainer
var _header_label: Label
var _caller_info: PanelContainer
var _caller_info_label: Label
var _caller_name: Label
var _transcript_scroll: ScrollContainer
var _transcript: VBoxContainer
var _phone_card: PanelContainer
var _phone_rule: ColorRect
var _question: Label
var _listening: Label
var _choices: VBoxContainer
var _checklist: ChecklistView
var _hint: Label

var _locked := false
var _rendered_step := -1
var _rendered_item := ""
var _rendered_header := ""
var _playing := false
var _pending: Array[String] = []
var _playback: Tween
var _typing: Array[Tween] = []
var _typing_labels: Array[Label] = []
var _hint_flash: Tween


func _ready() -> void:
	add_child(UIStyle.backdrop(0.55))
	var center := UIStyle.center()
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 14, 24, UIStyle.PANEL_LIGHTER))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var cols := UIStyle.hbox(24)
	card.add_child(cols)
	cols.add_child(_build_call_column())
	cols.add_child(_build_decision_column())


## Sets the card of known numbers: its title and lines (the office default: "Phone card" + Campaign.PHONE_CARD;
## the player's phone: "Hotlines" + Campaign.PHONE_CARD_MOBILE). Works before or after _ready.
func configure_device(card_title: String, card_lines: Array[String]) -> void:
	_card_title = card_title
	_card_lines = card_lines.duplicate()
	if _card_box != null:
		_fill_card()


## Opens the call for the selected item's current step: shows the header, plays the step's lines
## into the transcript one by one, then reveals the decision area.
## Called again for the next call step of the same item while open: the transcript is kept, and a
## divider marks a new call header (e.g. "— EXT 1200: SECURITY OFFICE —").
func open_session(s: ChapterSession) -> void:
	var same_call := s == session and is_open() and s.item_id == _rendered_item
	session = s
	_locked = false
	_rendered_step = s.step_index
	_rendered_item = s.item_id
	var header := str(s.step().get("call_header", ""))
	if not same_call:
		_clear_transcript()
	elif header != "" and header != _rendered_header:
		_append_divider(header)
	_rendered_header = header
	refresh()
	show_overlay()
	_play(_step_lines())


## Re-renders the header and the decision area from the session (after an inspection or a wrong pick).
func refresh() -> void:
	if session == null:
		return
	if session.step_index != _rendered_step or session.item_id != _rendered_item:
		_rendered_step = session.step_index
		_rendered_item = session.item_id
		_locked = false
	_render_header()
	_render_choices()


## Locks the choice buttons and the checklist while an outcome is showing.
func set_choices_locked(locked: bool) -> void:
	_locked = locked
	_apply_choice_states()


## Appends one transcript line. An empty speaker means the current caller.
func add_line(speaker: String, text: String) -> void:
	_append_line(speaker if speaker != "" else _caller(), text, true)


## The answer heard on a call to a known extension (a correct choice's response_line, e.g.
## "IT Helpdesk: No, we haven't called you today..."): a divider naming that extension from the phone card
## ("— EXT 1100: IT HELPDESK —") and the line under that speaker.
func add_reply(line: String) -> void:
	var speaker := ""
	var text := line
	var cut := line.find(": ")
	if cut > 0:
		speaker = line.substr(0, cut)
		text = line.substr(cut + 2)
	if speaker != "":
		var header := speaker.to_upper()
		for card: String in _card_lines:
			if card.begins_with(speaker + ":") and card.contains("ext. "):
				header = "EXT %s: %s" % [card.get_slice("ext. ", 1).strip_edges(), speaker.to_upper()]
		_finish_typing()
		_append_divider(header)
	_append_line(speaker if speaker != "" else _caller(), text, false)


func close() -> void:
	if is_open():
		Audio.play_sfx("phone_hangup", -2.0)
	_stop_playback()
	hide_overlay()


## ESC never counts as hanging up.
func handle_back() -> void:
	_flash_hint()


## E skips the line-by-line playback.
func handle_advance() -> void:
	if _playing:
		_skip_playback()


# --- Layout ----------------------------------------------------------------

func _build_call_column() -> VBoxContainer:
	var left := UIStyle.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1

	var top := UIStyle.hbox(10)
	left.add_child(top)
	_status_box = PanelContainer.new()
	top.add_child(_status_box)
	_status = DialoguePanel.section("Incoming call", Color.WHITE, 13)
	_status_box.add_child(_status)

	# Inspectable caller ID (step 0 of a call item): an LCD-style button.
	_caller_id_button = UIStyle.button("", 19)
	_caller_id_button.add_theme_font_override("font", UIStyle.mono_font())
	_caller_id_button.add_theme_color_override("font_color", LCD_TEXT)
	_caller_id_button.add_theme_color_override("font_hover_color", LCD_TEXT.lightened(0.3))
	_caller_id_button.add_theme_color_override("font_pressed_color", LCD_TEXT)
	_caller_id_button.add_theme_stylebox_override("normal", UIStyle.box(LCD_BG, 6, 14, LCD_BORDER))
	_caller_id_button.add_theme_stylebox_override("hover", UIStyle.box(LCD_BG.lightened(0.08), 6, 14, LCD_TEXT))
	_caller_id_button.add_theme_stylebox_override("pressed", UIStyle.box(LCD_BG.darkened(0.2), 6, 14, LCD_TEXT))
	_caller_id_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caller_id_button.tooltip_text = "Check the caller ID"
	_caller_id_button.pressed.connect(_on_caller_id_pressed)
	left.add_child(_caller_id_button)

	# Plain call header for the other steps ("CALL ENDED", "EXT 2045: R. RAMOS").
	_header_box = PanelContainer.new()
	_header_box.add_theme_stylebox_override("panel", UIStyle.box(LCD_BG, 6, 14, LCD_BORDER))
	_header_label = UIStyle.mono_label("", 19, LCD_TEXT)
	_header_box.add_child(_header_label)
	left.add_child(_header_box)

	# Revealed caller ID facts.
	_caller_info = PanelContainer.new()
	_caller_info.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHT, 6, 12, UIStyle.ACCENT))
	_caller_info_label = UIStyle.mono_label("", 15, UIStyle.TEXT)
	_caller_info.add_child(_caller_info_label)
	_caller_info.visible = false
	left.add_child(_caller_info)

	var name_box := UIStyle.vbox(2)
	left.add_child(name_box)
	name_box.add_child(DialoguePanel.section("Caller"))
	_caller_name = UIStyle.label("", 22, UIStyle.TEXT)
	_caller_name.add_theme_font_override("font", DialoguePanel.bold_font())
	name_box.add_child(_caller_name)

	left.add_child(DialoguePanel.section("Transcript"))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, 8, 10))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(frame)
	_transcript_scroll = ScrollContainer.new()
	_transcript_scroll.custom_minimum_size = Vector2(0, 270)
	_transcript_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_transcript_scroll)
	_transcript = UIStyle.vbox(10)
	_transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcript_scroll.add_child(_transcript)
	# Keep the newest line in view.
	var bar := _transcript_scroll.get_v_scroll_bar()
	bar.changed.connect(func() -> void: _transcript_scroll.scroll_vertical = int(bar.max_value))
	return left


func _build_decision_column() -> VBoxContainer:
	var right := UIStyle.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.9

	# Phone card: the known internal numbers (hidden on a checklist step to make room for it).
	_phone_card = PanelContainer.new()
	_phone_card.name = "PhoneCard"
	_phone_card.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHT, 8, 14))
	right.add_child(_phone_card)
	_card_box = UIStyle.vbox(6)
	_phone_card.add_child(_card_box)
	_fill_card()

	_phone_rule = DialoguePanel.rule()
	right.add_child(_phone_rule)

	_question = UIStyle.label("", 20, UIStyle.TEXT)
	_question.add_theme_font_override("font", DialoguePanel.bold_font())
	right.add_child(_question)

	_listening = UIStyle.label("Listening to the call…", 16, UIStyle.MUTED)
	right.add_child(_listening)

	_choices = UIStyle.vbox(8)
	right.add_child(_choices)

	# Warning-sign report (checklist steps): one column, 14 px, Submit below the scroll.
	_checklist = ChecklistView.new()
	_checklist.name = "Checklist"
	_checklist.visible = false
	_checklist.ticks_changed.connect(_on_ticks_changed)
	_checklist.submitted.connect(_on_checklist_submit)
	right.add_child(_checklist)

	_hint = UIStyle.label("", 15, UIStyle.MUTED)
	right.add_child(_hint)
	return right


## (Re)builds the card: its title, then one monospace line per known number.
func _fill_card() -> void:
	for child: Node in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()
	_card_box.add_child(DialoguePanel.section(_card_title, UIStyle.ACCENT))
	for line: String in _card_lines:
		_card_box.add_child(UIStyle.mono_label(line, 16, UIStyle.TEXT))


# --- Rendering -------------------------------------------------------------

func _render_header() -> void:
	var step := session.step()
	var call := _call()
	var inspectable := session.step_index == 0 and not call.is_empty()
	_caller_id_button.visible = inspectable
	_header_box.visible = not inspectable
	if inspectable:
		_caller_id_button.text = "Caller ID: %s  ⓘ" % str(call.get("caller_id", ""))
		_caller_info_label.text = str(call.get("caller_id_info", ""))
		_caller_info.visible = session.inspected.has("caller_id")
	else:
		_header_label.text = str(step.get("call_header", ""))
		_caller_info.visible = false
	_caller_name.text = _caller()

	var status := "On call"
	var color := UIStyle.GOOD
	if inspectable:
		status = "Incoming call"
		color = UIStyle.ACCENT
	elif step.get("wait_for", "") == "telephone":
		status = "Outgoing call"
		color = UIStyle.GOOD
	elif (step.get("call_lines", []) as Array).is_empty() and not step.has("call_name"):
		status = "Call ended"
		color = UIStyle.PANEL_LIGHTER
	_status.text = status.to_upper()
	_status_box.add_theme_stylebox_override("panel", UIStyle.box(color.darkened(0.25), 5, 6))


func _render_choices() -> void:
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var step := session.step()
	_question.text = str(step.get("question", ""))
	var checklist := session.is_checklist()
	_phone_card.visible = not checklist
	_phone_rule.visible = not checklist
	if checklist:
		# The phone card is hidden on a checklist step, so all seven options fit without scrolling.
		_checklist.setup(step, session.ticks(), session.tried(), 1, 320.0)
	var choices: Array = [] if checklist else step.get("choices", [])
	for i: int in choices.size():
		var choice: Dictionary = choices[i]
		var b := UIStyle.button(str(choice.get("text", "")), 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_choice_pressed.bind(i))
		_choices.add_child(b)
	_set_decision_visible(not _playing)
	_apply_choice_states()
	_render_hint()


## Disabled when locked by an outcome, while the lines play, when the inspection gate is closed,
## or (choices) after a wrong pick.
func _apply_choice_states() -> void:
	if session == null:
		return
	var gate := session.gate_open()
	_checklist.set_locked(_locked or _playing or not gate)
	var i := 0
	for child: Node in _choices.get_children():
		var b := child as Button
		if b != null and not b.is_queued_for_deletion():
			b.disabled = _locked or not gate or session.is_disabled(i)
			UIStyle.mark_tried(b, session.is_disabled(i))
			i += 1


func _render_hint() -> void:
	if _hint_flash != null:
		_hint_flash.kill()
	if not session.gate_open():
		_hint.text = session.gate_hint()
		_hint.add_theme_color_override("font_color", UIStyle.WARN)
	elif session.is_checklist():
		_hint.text = session.checklist_hint(_checklist.get_ticked())
		_hint.add_theme_color_override("font_color", UIStyle.MUTED)
	else:
		_hint.text = "Choose a response."
		_hint.add_theme_color_override("font_color", UIStyle.MUTED)


func _flash_hint() -> void:
	if session == null:
		return
	if _hint_flash != null:
		_hint_flash.kill()
	if session.gate_open() and session.is_checklist():
		_hint.text = session.checklist_hint(_checklist.get_ticked())
	else:
		_hint.text = "Choose a response."
	_hint.add_theme_color_override("font_color", UIStyle.WARN)
	_hint_flash = create_tween()
	_hint_flash.tween_interval(1.5)
	_hint_flash.tween_callback(_render_hint)


func _set_decision_visible(on: bool) -> void:
	var checklist := session != null and session.is_checklist()
	_question.visible = on
	_choices.visible = on and not checklist
	_checklist.visible = on and checklist
	_listening.visible = not on


## The selected item's call script ({} for an item that is not a call, e.g. the HR call of Chapter 1).
func _call() -> Dictionary:
	if session == null:
		return {}
	return session.item().get("call", {})


## The person on the line: the step's call_name ("HR", "Security Office"), else the call script's caller,
## else the person in the call header ("EXT 2045: R. RAMOS" -> "R. Ramos").
func _caller() -> String:
	if session == null:
		return "Caller"
	var step := session.step()
	if step.has("call_name"):
		return str(step.get("call_name", "Caller"))
	var call := _call()
	if not call.is_empty():
		return str(call.get("caller_name", "Caller"))
	var header := str(step.get("call_header", ""))
	var parts := header.split(":", false)
	if parts.size() < 2:
		return "Caller"
	var words: Array[String] = []
	for w: String in parts[parts.size() - 1].strip_edges().split(" ", false):
		words.append(w.substr(0, 1).to_upper() + w.substr(1).to_lower())
	return " ".join(words)


## call.lines at step 0 of a call item, else the step's call_lines.
func _step_lines() -> Array[String]:
	var src: Array = []
	var call := _call()
	if session.step_index == 0 and not call.is_empty():
		src = call.get("lines", [])
	else:
		src = session.step().get("call_lines", [])
	var out: Array[String] = []
	for line: Variant in src:
		out.append(str(line))
	return out


# --- Transcript playback ---------------------------------------------------

func _play(lines: Array[String]) -> void:
	_stop_playback()
	_pending = lines.duplicate()
	if _pending.is_empty():
		_reveal()
		return
	_playing = true
	_set_decision_visible(false)
	_apply_choice_states()
	_playback = create_tween()
	_playback.tween_interval(FIRST_LINE_DELAY)
	for text: String in lines:
		_playback.tween_callback(_play_next_line)
		_playback.tween_interval(_type_time(text) + LINE_PAUSE)
	_playback.tween_callback(_reveal)


func _play_next_line() -> void:
	if _pending.is_empty():
		return
	_append_line(_caller(), _pending.pop_front(), true)


func _skip_playback() -> void:
	if _playback != null:
		_playback.kill()
	_finish_typing()
	while not _pending.is_empty():
		_append_line(_caller(), _pending.pop_front(), false)
	_reveal()


func _stop_playback() -> void:
	if _playback != null:
		_playback.kill()
	_finish_typing()
	_pending.clear()
	_playing = false


func _reveal() -> void:
	_playing = false
	_set_decision_visible(true)
	_apply_choice_states()


func _finish_typing() -> void:
	for t: Tween in _typing:
		if t != null:
			t.kill()
	for l: Label in _typing_labels:
		if is_instance_valid(l):
			l.visible_ratio = 1.0
	_typing.clear()
	_typing_labels.clear()


func _type_time(text: String) -> float:
	return maxf(0.2, text.length() / CHARS_PER_SECOND)


## Adds a speech bubble: the caller on the left, "You" on the right.
func _append_line(speaker: String, text: String, typed: bool) -> void:
	var is_you := speaker == YOU
	var row := MarginContainer.new()
	row.add_theme_constant_override("margin_left", 70 if is_you else 0)
	row.add_theme_constant_override("margin_right", 0 if is_you else 70)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UIStyle.box(Color("1f3a52") if is_you else UIStyle.PANEL_LIGHT, 10, 12))
	row.add_child(bubble)
	var v := UIStyle.vbox(4)
	bubble.add_child(v)
	v.add_child(DialoguePanel.section(speaker, UIStyle.ACCENT if is_you else UIStyle.WARN, 12))
	var body := UIStyle.label(text, 18, UIStyle.TEXT)
	v.add_child(body)
	_transcript.add_child(row)
	if typed:
		body.visible_ratio = 0.0
		var t := create_tween()
		t.tween_property(body, "visible_ratio", 1.0, _type_time(text))
		_typing.append(t)
		_typing_labels.append(body)


## A muted line between two parts of the same call, e.g. "— EXT 1200: SECURITY OFFICE —".
func _append_divider(header: String) -> void:
	var l := UIStyle.mono_label("— %s —" % header, 13, UIStyle.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transcript.add_child(l)


func _clear_transcript() -> void:
	_stop_playback()
	for child: Node in _transcript.get_children():
		_transcript.remove_child(child)
		child.queue_free()


# --- Input -----------------------------------------------------------------

func _on_caller_id_pressed() -> void:
	if session == null:
		return
	_caller_info.visible = true
	inspected.emit("caller_id")


func _on_choice_pressed(index: int) -> void:
	if session == null or _locked or _playing or not session.gate_open() or session.is_disabled(index):
		return
	var choices: Array = session.step().get("choices", [])
	_finish_typing()
	add_line(YOU, str((choices[index] as Dictionary).get("text", "")))
	choice_selected.emit(index)


## Ticking a box stores the ticks in the session (the only session write the Call UI makes) and updates the hint.
func _on_ticks_changed(ticked: Array[int]) -> void:
	if session == null:
		return
	session.set_ticks(ticked)
	_render_hint()


func _on_checklist_submit(ticked: Array[int]) -> void:
	if session == null or _locked or _playing or not session.gate_open() or not session.is_checklist():
		return
	_finish_typing()
	add_line(YOU, str(session.step().get("checklist_line", CHECKLIST_LINE)))
	checklist_submitted.emit(ticked)
