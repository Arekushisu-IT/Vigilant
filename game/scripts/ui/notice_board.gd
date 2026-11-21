class_name NoticeBoard
extends Overlay
## The pantry notice board seen up close (E on the cork board). Art and feel only: nothing here scores.
## The Security Office's reminders restate the habits the chapters teach (supports the awareness aim of the
## study), next to an everyday office note. ESC, E or Close puts it back.

const NOTES: Array[Dictionary] = [
	{"title": "IT SECURITY", "text": "IT will never ask for your password by email, text or phone.", "color": "f4efe3"},
	{"title": "VERIFY FIRST", "text": "Odd request? Call back on the extension printed on your phone card, not the number in the message.", "color": "f7e27c"},
	{"title": "BEFORE YOU CLICK", "text": "Check the sender's address and hover over links to see where they really go.", "color": "a8d3f0"},
	{"title": "MONEY REQUESTS", "text": "Urgent transfer or new bank details? Confirm with the person by phone before anything is paid.", "color": "f5b3c4"},
	{"title": "QR CODES", "text": "Don't scan QR codes on flyers or stickers you don't know. Type the address yourself.", "color": "b6e3a8"},
	{"title": "SEE SOMETHING?", "text": "Report anything suspicious to the Security Office: Ms. Dela Vega, ext. 1200.", "color": "cfe0f5"},
]
const FOOTER := "Pantry: please wash your own mug.   ·   Friday merienda is on the Sales team!"
const NOTE_SIZE := Vector2(250, 170)
const INK := Color("2b2622")


func _ready() -> void:
	add_child(UIStyle.backdrop(0.6))
	var center := UIStyle.center()
	add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIStyle.box(Color("5a3e2b"), 14, 16))
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(frame)
	var cork := PanelContainer.new()
	cork.add_theme_stylebox_override("panel", UIStyle.box(Color("c49a62"), 6, 22))
	frame.add_child(cork)
	var v := UIStyle.vbox(16)
	cork.add_child(v)

	var head := UIStyle.label("PANTRY NOTICE BOARD", 22, INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(head)
	var sub := UIStyle.label("Reminders from the Security Office", 15, Color(INK, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(sub)

	var grid := GridContainer.new()
	grid.name = "Notes"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)
	for n: Dictionary in NOTES:
		grid.add_child(_note(n))

	var foot := UIStyle.label(FOOTER, 14, Color(INK, 0.8))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(foot)
	var close := UIStyle.button("Close", 17)
	close.name = "CloseButton"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(140, 44)
	close.pressed.connect(handle_back)
	v.add_child(close)


func open_board() -> void:
	Audio.play_sfx("page_turn", -4.0)
	show_overlay()


func handle_back() -> void:
	if is_open():
		Audio.play_sfx("page_turn", -6.0, 0.9)
		hide_overlay()


func handle_advance() -> void:
	handle_back()


## One pinned sticky note: a red pin, a bold heading and the reminder.
func _note(n: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = NOTE_SIZE
	var sb := UIStyle.box(Color(str(n.color)), 3, 14)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(2, 3)
	p.add_theme_stylebox_override("panel", sb)
	var v := UIStyle.vbox(6)
	p.add_child(v)
	var pin := ColorRect.new()
	pin.color = Color("d64541")
	pin.custom_minimum_size = Vector2(12, 12)
	pin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pin)
	var t := UIStyle.label(str(n.title), 16, INK)
	t.add_theme_font_override("font", DialoguePanel.bold_font())
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var body := UIStyle.label(str(n.text), 15, INK)
	body.custom_minimum_size.x = NOTE_SIZE.x - 28.0
	v.add_child(body)
	return p
