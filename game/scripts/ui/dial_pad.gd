class_name DialPad
extends Overlay
## The desk phone's keypad for calls the player places (verify through a known channel, Objective 5).
## The player clicks the number keys; the digits show here and on the phone's own little screen in the office.
## Call checks the number: the right extension connects, any other number does not answer (no points lost).
## Mouse only (the paper's controls stay WASD / mouse / E / ESC); ESC hangs up without calling.
## configure_device() turns it into the player's phone keypad (home and cafe chapters: the hotlines card).

signal dialed(number: String)
signal cancelled
signal digits_changed(number: String)

const MAX_DIGITS := 8
const KEYS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
const LETTERS: Array[String] = ["", "ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ", "", "+", ""]

var number: String = ""
var _display: Label
# The device (configure_device): the desk phone in the office, the player's phone at home and in the cafe.
var _title: String = "DESK PHONE"
var _card_title: String = "PHONE CARD"
var _card_lines: Array[String] = Campaign.PHONE_CARD.duplicate()
var _title_label: Label
var _card_title_label: Label
var _card_box: VBoxContainer
var _who: Label
var _status: Label
var _call: Button


func _ready() -> void:
	add_child(UIStyle.backdrop(0.25))
	var right := Control.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -470.0
	right.offset_right = -40.0
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	var center := UIStyle.center()
	right.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.08, 0.12, 0.96), 16, 22, Color(UIStyle.ACCENT, 0.55)))
	card.custom_minimum_size = Vector2(400, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var v := UIStyle.vbox(10)
	card.add_child(v)

	_title_label = DialoguePanel.section(_title, UIStyle.ACCENT, 14)
	v.add_child(_title_label)
	_who = UIStyle.label("", 16, Color(UIStyle.TEXT, 0.9))
	_who.custom_minimum_size.x = 356.0
	v.add_child(_who)

	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", UIStyle.box(Color("0f2a1c"), 8, 12, Color("2f6b4a")))
	v.add_child(screen)
	_display = UIStyle.mono_label("", 34, Color("8ff0b0"))
	_display.autowrap_mode = TextServer.AUTOWRAP_OFF
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.name = "Display"
	screen.add_child(_display)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for k: int in KEYS.size():
		grid.add_child(_key(KEYS[k], LETTERS[k]))

	var row := UIStyle.hbox(10)
	v.add_child(row)
	var clear := UIStyle.button("⌫", 22)
	clear.name = "Backspace"
	clear.tooltip_text = "Delete the last digit"
	clear.custom_minimum_size = Vector2(70, 50)
	clear.pressed.connect(_backspace)
	row.add_child(clear)
	_call = UIStyle.button("Call", 19, UIStyle.GOOD.darkened(0.35))
	_call.name = "CallButton"
	_call.custom_minimum_size = Vector2(140, 50)
	_call.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_call.pressed.connect(_place_call)
	row.add_child(_call)
	var hang := UIStyle.button("Hang up", 17, UIStyle.DANGER.darkened(0.35))
	hang.name = "HangUp"
	hang.custom_minimum_size = Vector2(110, 50)
	hang.pressed.connect(handle_back)
	row.add_child(hang)

	_status = UIStyle.label("", 15, UIStyle.WARN)
	_status.custom_minimum_size.x = 356.0
	v.add_child(_status)

	v.add_child(DialoguePanel.rule(Color(1, 1, 1, 0.08)))
	_card_title_label = DialoguePanel.section(_card_title, UIStyle.MUTED, 12)
	v.add_child(_card_title_label)
	_card_box = UIStyle.vbox(10)
	v.add_child(_card_box)
	_fill_card()


## Sets the keypad's title and its card of known numbers (office default: "DESK PHONE", "PHONE CARD",
## Campaign.PHONE_CARD; the player's phone: "YOUR PHONE", "HOTLINES", Campaign.PHONE_CARD_MOBILE).
## Works before or after _ready.
func configure_device(title: String, card_title: String, card_lines: Array[String]) -> void:
	_title = title
	_card_title = card_title
	_card_lines = card_lines.duplicate()
	if _title_label != null:
		_title_label.text = title.to_upper()
		_card_title_label.text = card_title.to_upper()
		_fill_card()


func _fill_card() -> void:
	for child: Node in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()
	for line: String in _card_lines:
		_card_box.add_child(UIStyle.mono_label(line, 14, Color(UIStyle.TEXT, 0.75)))


## Opens the keypad empty. `who` says who the player is about to call (the objective line).
func open_pad(who: String) -> void:
	_who.text = who
	_status.text = ""
	_set_number("")
	show_overlay()


## Shows that a number did not answer, clears the digits and stays open.
func no_answer(dialed_number: String) -> void:
	_status.text = "%s is not answering. Check the number and dial again." % dialed_number
	_set_number("")


## ESC and Hang up both close the keypad without calling.
func handle_back() -> void:
	if not is_open():
		return
	Audio.play_sfx("phone_hangup", -4.0)
	hide_overlay()
	cancelled.emit()


## Presses a key as if clicked (also used by the office's test hook).
func press(key: String) -> void:
	if number.length() >= MAX_DIGITS:
		return
	Audio.play_sfx(_tone_of(key), -6.0)
	_status.text = ""
	_set_number(number + key)


func _key(digit: String, letters: String) -> Button:
	var b := Button.new()
	b.name = "Key_" + ("star" if digit == "*" else ("hash" if digit == "#" else digit))
	b.text = digit if letters == "" else "%s\n%s" % [digit, letters]
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(100, 52)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", UIStyle.TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_constant_override("line_spacing", -6)
	b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL_LIGHT, 10, 4))
	b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHTER, 10, 4, UIStyle.ACCENT))
	b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.ACCENT.darkened(0.3), 10, 4, UIStyle.ACCENT))
	b.pressed.connect(press.bind(digit))
	return b


func _backspace() -> void:
	if number != "":
		_set_number(number.substr(0, number.length() - 1))


func _place_call() -> void:
	if number == "":
		_status.text = "Dial a number first."
		return
	dialed.emit(number)


func _set_number(n: String) -> void:
	number = n
	_display.text = n if n != "" else "_ _ _ _"
	_call.disabled = n == ""
	digits_changed.emit(n)


## The keypad tone (DTMF) synthesized for a key.
static func _tone_of(key: String) -> String:
	match key:
		"*":
			return "dtmf_star"
		"#":
			return "dtmf_hash"
	return "dtmf_" + key
