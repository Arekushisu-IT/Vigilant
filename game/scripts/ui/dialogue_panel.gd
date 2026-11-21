class_name DialoguePanel
extends Overlay
## Ms. Dela Vega's intro and chapter briefings (paper UI item 6): a bottom panel with a portrait,
## the speaker's name and the line, typed out quickly. E, ESC or a click advances one line
## (the first press finishes the typing). Use: `panel.play(lines)` then `await panel.finished`.
## Also holds small shared helpers (portrait, fonts, lists) used by the other Module C screens.

signal finished

const CHARS_PER_SECOND := 60.0
const PANEL_WIDTH := 1120

var _lines: Array = []
var _index: int = -1
var _portrait: PanelContainer
var _portrait_label: Label
var _speaker: Label
var _text: Label
var _counter: Label
var _tween: Tween

static var _bold: FontVariation
static var _italic: FontVariation


func _ready() -> void:
	# Soft dark gradient at the bottom so the text reads over any part of the office.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_top = 0.5
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	# Transparent full-screen click catcher: any click advances one line.
	var catcher := UIStyle.backdrop(0.0)
	catcher.gui_input.connect(_on_catcher_input)
	add_child(catcher)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.PANEL, 0.96), 12, 22, UIStyle.PANEL_LIGHTER))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH / 2.0
	panel.offset_right = PANEL_WIDTH / 2.0
	panel.offset_top = -200
	panel.offset_bottom = -32
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var row := UIStyle.hbox(22)
	panel.add_child(row)

	_portrait = portrait("DV", 104)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_label = _portrait.get_child(0) as Label
	row.add_child(_portrait)

	var col := UIStyle.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	_speaker = UIStyle.label("", 20, UIStyle.ACCENT)
	_speaker.add_theme_font_override("font", bold_font())
	col.add_child(_speaker)

	_text = UIStyle.label("", 21, UIStyle.TEXT)
	_text.custom_minimum_size = Vector2(0, 64)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)

	var footer := UIStyle.hbox(12)
	col.add_child(footer)
	_counter = UIStyle.label("", 14, UIStyle.MUTED)
	_counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_counter)
	var hint := UIStyle.label("E / click to continue  ▸", 14, UIStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(hint)

	# Clicks on the panel fall through to the catcher behind it.
	ignore_mouse(panel)


## Plays the lines ({speaker, text} dictionaries) one at a time, then hides and emits `finished`.
func play(lines: Array) -> void:
	_lines = lines.duplicate()
	_index = -1
	if _lines.is_empty():
		hide_overlay()
		finished.emit.call_deferred()
		return
	show_overlay()
	_next_line()


func handle_advance() -> void:
	_advance()


func handle_back() -> void:
	_advance()


func _on_catcher_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


## First press finishes the typing; the next one moves on.
func _advance() -> void:
	if not is_open():
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
		_text.visible_ratio = 1.0
		return
	_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	if _index > 0:
		Audio.play_sfx("page_turn", -4.0, randf_range(0.94, 1.06))
	var line: Dictionary = _lines[_index]
	var who := str(line.get("speaker", ""))
	_speaker.text = who
	_speaker.visible = who != ""
	_portrait.visible = who != ""
	_portrait_label.text = initials_of(who)
	_text.text = str(line.get("text", ""))
	_counter.text = "%d / %d" % [_index + 1, _lines.size()]
	_text.visible_ratio = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(0.15, _text.text.length() / CHARS_PER_SECOND))


func _finish() -> void:
	if _tween != null:
		_tween.kill()
	_lines.clear()
	_index = -1
	hide_overlay()
	finished.emit()


# ---------------------------------------------------------------------------
# Shared helpers for the Module C screens (outcome, feedback, game over, call).
# ---------------------------------------------------------------------------

## Bold version of the default font (same embolden trick as Godot's default theme).
static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
	return _bold


## Italic (slanted) version of the default font, as Godot's default theme builds its italics.
static func italic_font() -> Font:
	if _italic == null:
		_italic = FontVariation.new()
		_italic.base_font = ThemeDB.fallback_font
		_italic.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
	return _italic


## "Ms. Dela Vega" -> "DV", "R. Ramos" -> "RR". Honorifics are skipped.
static func initials_of(person: String) -> String:
	var out := ""
	for word: String in person.split(" ", false):
		if word in ["Ms.", "Mr.", "Mrs.", "Dr."]:
			continue
		out += word.substr(0, 1).to_upper()
		if out.length() >= 2:
			break
	return out


## A coloured square with initials, used as a speaker portrait.
static func portrait(initials: String, side: int = 88) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.ACCENT.darkened(0.45), 10, 0, UIStyle.ACCENT))
	p.custom_minimum_size = Vector2(side, side)
	var l := UIStyle.label(initials, int(side * 0.36), Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", bold_font())
	p.add_child(l)
	return p


## Small bold upper-case caption, e.g. "WARNING SIGNS".
static func section(text: String, color: Color = UIStyle.MUTED, size: int = 13) -> Label:
	var l := UIStyle.label(text.to_upper(), size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", bold_font())
	return l


## A bulleted list of strings.
static func bullet_list(items: Array, size: int = 17, bullet_color: Color = UIStyle.WARN) -> VBoxContainer:
	var v := UIStyle.vbox(6)
	for item: Variant in items:
		var row := UIStyle.hbox(10)
		var dot := UIStyle.label("•", size, bullet_color)
		dot.autowrap_mode = TextServer.AUTOWRAP_OFF
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
		var text := UIStyle.label(str(item), size, UIStyle.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		v.add_child(row)
	return v


## A thin horizontal divider line.
static func rule(color: Color = UIStyle.PANEL_LIGHTER) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Sets the four button styles to a tint of `color` (keeps UIStyle's shape and padding).
static func tint_button(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", UIStyle.box(color, 6, 12))
	b.add_theme_stylebox_override("hover", UIStyle.box(color.lightened(0.15), 6, 12, color.lightened(0.45)))
	b.add_theme_stylebox_override("pressed", UIStyle.box(color.darkened(0.15), 6, 12, color.lightened(0.45)))
	b.add_theme_stylebox_override("disabled", UIStyle.box(Color(color, 0.4), 6, 12))


## Makes a control and all its descendants ignore the mouse.
static func ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		ignore_mouse(child)
