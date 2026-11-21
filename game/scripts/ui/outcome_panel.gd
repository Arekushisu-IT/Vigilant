class_name OutcomePanel
extends Overlay
## Outcome notification after every choice (Objective 6): "Correct" / "Wrong action" / "Unsafe choice"
## in green / orange / red, the score change, the other side's reply (if any) and the feedback.
## Continue, ESC or E hides it and emits `continued`.

signal continued

const CARD_WIDTH := 640

var _card: PanelContainer
var _badge: PanelContainer
var _badge_label: Label
var _title: Label
var _delta: Label
var _response: Label
var _feedback: Label
var _continue: Button
var _fade: Tween


func _ready() -> void:
	add_child(UIStyle.backdrop(0.6))
	var center := UIStyle.center()
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_card)

	var v := UIStyle.vbox(16)
	_card.add_child(v)

	var head := UIStyle.hbox(16)
	v.add_child(head)
	_badge = PanelContainer.new()
	_badge.custom_minimum_size = Vector2(48, 48)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_badge)
	_badge_label = UIStyle.label("", 26, Color.WHITE)
	_badge_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_override("font", DialoguePanel.bold_font())
	_badge.add_child(_badge_label)

	_title = UIStyle.label("", 30)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", DialoguePanel.bold_font())
	head.add_child(_title)

	_delta = UIStyle.label("", 34)
	_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	_delta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_delta.add_theme_font_override("font", DialoguePanel.bold_font())
	head.add_child(_delta)

	v.add_child(DialoguePanel.rule())

	_response = UIStyle.label("", 19, Color("c9d3dd"))
	_response.add_theme_font_override("font", DialoguePanel.italic_font())
	v.add_child(_response)

	_feedback = UIStyle.label("", 19, UIStyle.TEXT)
	v.add_child(_feedback)

	var footer := UIStyle.hbox(12)
	v.add_child(footer)
	var keys := UIStyle.label("E / ESC", 14, UIStyle.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_OFF
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(keys)
	_continue = UIStyle.button("Continue", 18)
	_continue.custom_minimum_size = Vector2(180, 46)
	_continue.pressed.connect(_on_continue)
	footer.add_child(_continue)


## Shows the result of a choice. `outcome` is "correct", "wrong" or "unsafe"; `delta` the points applied.
func show_outcome(outcome: String, delta: int, feedback: String, response_line: String = "") -> void:
	var color := UIStyle.outcome_color(outcome)
	match outcome:
		"correct":
			_title.text = "Correct"
			_badge_label.text = "✓"
		"wrong":
			_title.text = "Wrong action"
			_badge_label.text = "!"
		"unsafe":
			_title.text = "Unsafe choice"
			_badge_label.text = "✕"
		"complete":
			_title.text = "Chapter complete"
			_badge_label.text = "✓"
		_:
			_title.text = outcome.capitalize()
			_badge_label.text = "•"
	_title.add_theme_color_override("font_color", color)
	_delta.text = ("+%d" % delta) if delta > 0 else str(delta)
	_delta.add_theme_color_override("font_color", color)

	var sb := UIStyle.box(UIStyle.PANEL, 14, 28, color)
	sb.border_width_top = 6
	_card.add_theme_stylebox_override("panel", sb)
	_badge.add_theme_stylebox_override("panel", UIStyle.box(color.darkened(0.2), 24, 0))
	DialoguePanel.tint_button(_continue, color.darkened(0.45))

	_response.text = "“%s”" % response_line
	_response.visible = response_line != ""
	_feedback.text = feedback

	match outcome:
		"correct", "complete":
			Audio.play_correct()
		_:
			Audio.play_wrong()                # for an unsafe choice, the breach hit follows on the compromise notice
	modulate.a = 0.0
	show_overlay()
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.15)


func handle_back() -> void:
	_on_continue()


func handle_advance() -> void:
	_on_continue()


func _on_continue() -> void:
	if not is_open():
		return
	if _fade != null:
		_fade.kill()
	modulate.a = 1.0
	hide_overlay()
	continued.emit()
