class_name GameOverScreen
extends Overlay
## The bad ending (Objectives 6 and 7): the heading (the chapter's breach_title, else "GAME OVER: Aegis Solutions
## has been breached"), the Black Veil mark (office chapters only: off the clock the loss is personal), the
## chapter's breach narration, the warning signs the player missed, the tip and the current score.
## Restart Chapter or Main Menu; both buttons disable after the first press. ESC is blocked.

signal restart_pressed
signal menu_pressed

const CARD_WIDTH := 1060
const OFFICE_HEADING := "GAME OVER: Aegis Solutions has been breached"

var _heading: Label
var _mark: Control
var _chapter_line: Label
var _narration: Label
var _signs_holder: VBoxContainer
var _tip: Label
var _score: Label
var _restart: Button
var _menu: Button


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c0607")
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.full_rect(bg)
	add_child(bg)
	var edge := ColorRect.new()
	edge.color = UIStyle.DANGER
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	edge.offset_bottom = 8
	add_child(edge)

	var center := UIStyle.center()
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.box(Color("170b0d"), 14, 28, Color(UIStyle.DANGER, 0.7)))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var root := UIStyle.vbox(18)
	card.add_child(root)

	_heading = UIStyle.title(OFFICE_HEADING, 34)
	_heading.name = "Heading"
	_heading.add_theme_color_override("font_color", UIStyle.DANGER)
	_heading.add_theme_font_override("font", DialoguePanel.bold_font())
	root.add_child(_heading)
	_chapter_line = UIStyle.title("", 17)
	_chapter_line.add_theme_color_override("font_color", UIStyle.MUTED)
	root.add_child(_chapter_line)
	root.add_child(DialoguePanel.rule(Color(UIStyle.DANGER, 0.35)))

	var body := UIStyle.hbox(32)
	root.add_child(body)

	# Left: the Black Veil mark and the breach narration.
	var left := UIStyle.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	_mark = _black_veil_mark()
	_mark.name = "BlackVeilMark"
	left.add_child(_mark)
	var story := PanelContainer.new()
	story.add_theme_stylebox_override("panel", UIStyle.box(Color("2a0d10"), 8, 18))
	left.add_child(story)
	_narration = UIStyle.label("", 19, Color("f3dcdc"))
	story.add_child(_narration)

	# Right: warning signs missed and the tip.
	var right := UIStyle.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(DialoguePanel.section("Warning signs you missed", UIStyle.WARN, 14))
	_signs_holder = UIStyle.vbox(0)
	right.add_child(_signs_holder)
	right.add_child(DialoguePanel.section("Tip", UIStyle.ACCENT, 14))
	var tip_box := PanelContainer.new()
	tip_box.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 8, 14, Color(UIStyle.ACCENT, 0.6)))
	right.add_child(tip_box)
	_tip = UIStyle.label("", 17, UIStyle.TEXT)
	tip_box.add_child(_tip)

	root.add_child(DialoguePanel.rule(Color(UIStyle.DANGER, 0.35)))

	var footer := UIStyle.hbox(14)
	root.add_child(footer)
	_score = UIStyle.label("", 24, UIStyle.TEXT)
	_score.autowrap_mode = TextServer.AUTOWRAP_OFF
	_score.add_theme_font_override("font", DialoguePanel.bold_font())
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_score)
	_restart = UIStyle.button("Restart Chapter", 19)
	DialoguePanel.tint_button(_restart, UIStyle.DANGER.darkened(0.35))
	_restart.custom_minimum_size = Vector2(210, 50)
	_restart.pressed.connect(_on_restart)
	footer.add_child(_restart)
	_menu = UIStyle.button("Main Menu", 19)
	_menu.custom_minimum_size = Vector2(170, 50)
	_menu.pressed.connect(_on_menu)
	footer.add_child(_menu)


## Fills the screen from the chapter dictionary and shows it.
func show_game_over(chapter: Dictionary, score: int) -> void:
	Audio.play_sfx("game_over", -3.0)
	Audio.reset_streak()
	_heading.text = str(chapter.get("breach_title", OFFICE_HEADING))
	_mark.visible = str(chapter.get("place", "office")) == "office"
	_chapter_line.text = "Chapter %d: %s" % [int(chapter.get("id", 0)), str(chapter.get("title", ""))]
	_narration.text = str(chapter.get("bad_ending", ""))
	for child: Node in _signs_holder.get_children():
		_signs_holder.remove_child(child)
		child.queue_free()
	_signs_holder.add_child(DialoguePanel.bullet_list(chapter.get("warning_signs", []), 17, UIStyle.WARN))
	_tip.text = str(chapter.get("tip", ""))
	_score.text = "Score: %d" % score
	_restart.disabled = false
	_menu.disabled = false
	show_overlay()


## ESC is blocked: the player must choose Restart Chapter or Main Menu.
func handle_back() -> void:
	pass


func _on_restart() -> void:
	if _restart.disabled:
		return
	_lock_buttons()
	restart_pressed.emit()


func _on_menu() -> void:
	if _menu.disabled:
		return
	_lock_buttons()
	menu_pressed.emit()


func _lock_buttons() -> void:
	_restart.disabled = true
	_menu.disabled = true


## The attacker's mark: a red-ringed emblem with "BV" and the name BLACK VEIL (and its caption).
func _black_veil_mark() -> HBoxContainer:
	var row := UIStyle.hbox(18)
	var emblem := PanelContainer.new()
	emblem.custom_minimum_size = Vector2(96, 96)
	emblem.add_theme_stylebox_override("panel", UIStyle.box(Color("120607"), 48, 0, UIStyle.DANGER))
	row.add_child(emblem)
	var initials := UIStyle.label("BV", 38, UIStyle.DANGER)
	initials.autowrap_mode = TextServer.AUTOWRAP_OFF
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_override("font", DialoguePanel.bold_font())
	emblem.add_child(initials)

	var names := UIStyle.vbox(2)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(names)
	var spaced := FontVariation.new()
	spaced.base_font = DialoguePanel.bold_font()
	spaced.spacing_glyph = 6
	var veil := UIStyle.label("BLACK VEIL", 30, Color.WHITE)
	veil.autowrap_mode = TextServer.AUTOWRAP_OFF
	veil.add_theme_font_override("font", spaced)
	names.add_child(veil)
	var caption := UIStyle.label("The criminal group behind this attack", 15, UIStyle.MUTED)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	names.add_child(caption)
	return row
