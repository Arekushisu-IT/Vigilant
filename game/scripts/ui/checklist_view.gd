extends VBoxContainer
## Tick-box report of warning signs (Objectives 5, 6 and 7; no typing, predefined options only).
## Used inside the desktop DecisionBar and the Call UI. It never shows which options are real: the host
## sends the ticked set to the office, which scores it with ChapterSession.check().
## Hosts: const ChecklistView := preload("res://scripts/ui/checklist_view.gd")

signal ticks_changed(ticked: Array[int])
signal submitted(ticked: Array[int])

const FONT_SIZE := 14

var _boxes: Array[CheckBox] = []
var _submit: Button
var _tried: Array = []
var _locked := false

static var _unchecked_icon: ImageTexture
static var _unchecked_disabled_icon: ImageTexture


## Builds the boxes and the Submit button now (does not rely on _ready), pre-ticking `ticked`.
## `tried` holds the sorted tick sets already submitted wrong; Submit stays disabled for them.
func setup(step: Dictionary, ticked: Array[int], tried: Array, columns: int = 2, scroll_height: float = 200.0) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_boxes.clear()
	_tried = tried.duplicate(true)
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.name = "Options"
	scroll.custom_minimum_size = Vector2(0, scroll_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = maxi(1, columns)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var options: Array = step.get("options", [])
	for i: int in options.size():
		var option: Dictionary = options[i]
		var box := _make_box(str(option.get("text", "")))
		box.name = "Check_%d" % i
		box.set_pressed_no_signal(ticked.has(i))
		box.toggled.connect(_on_toggled.unbind(1))
		grid.add_child(box)
		_boxes.append(box)

	_submit = UIStyle.button(str(step.get("submit_text", "Submit report")), 16)
	_submit.name = "Submit"
	DialoguePanel.tint_button(_submit, UIStyle.ACCENT.darkened(0.45))
	_submit.size_flags_horizontal = Control.SIZE_SHRINK_END
	_submit.custom_minimum_size = Vector2(200, 40)
	_submit.pressed.connect(_on_submit)
	add_child(_submit)
	_update_submit()


## Disables every box and the Submit button (while an outcome shows, lines play or the gate is closed).
func set_locked(locked: bool) -> void:
	_locked = locked
	for box: CheckBox in _boxes:
		box.disabled = locked
	_update_submit()


## The ticked option indices, sorted.
func get_ticked() -> Array[int]:
	var out: Array[int] = []
	for i: int in _boxes.size():
		if _boxes[i].button_pressed:
			out.append(i)
	return out


## The Submit button (layout checks in the smoke test).
func submit_button() -> Button:
	return _submit


func _make_box(text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.focus_mode = Control.FOCUS_NONE
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(1, 0)
	box.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.add_theme_font_size_override("font_size", FONT_SIZE)
	box.add_theme_color_override("font_color", UIStyle.TEXT)
	box.add_theme_color_override("font_hover_color", Color.WHITE)
	box.add_theme_color_override("font_pressed_color", Color.WHITE)
	box.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	box.add_theme_color_override("font_disabled_color", Color(UIStyle.MUTED, 0.75))
	var ticked_color := Color(UIStyle.ACCENT, 0.16)
	box.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL_LIGHT, 6, 8))
	box.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHT.lightened(0.08), 6, 8, Color(UIStyle.ACCENT, 0.6)))
	box.add_theme_stylebox_override("pressed", UIStyle.box(ticked_color, 6, 8, UIStyle.ACCENT))
	box.add_theme_stylebox_override("hover_pressed", UIStyle.box(ticked_color.lightened(0.05), 6, 8, UIStyle.ACCENT.lightened(0.2)))
	box.add_theme_stylebox_override("disabled", UIStyle.box(Color(UIStyle.PANEL_LIGHT, 0.5), 6, 8))
	# An empty box with a light outline: the engine's default unchecked icon is a dark square on a dark panel.
	box.add_theme_icon_override("unchecked", _outline_icon(false))
	box.add_theme_icon_override("unchecked_disabled", _outline_icon(true))
	return box


## A 16 px square outline (built once, shared by every box).
static func _outline_icon(disabled: bool) -> ImageTexture:
	if disabled and _unchecked_disabled_icon != null:
		return _unchecked_disabled_icon
	if not disabled and _unchecked_icon != null:
		return _unchecked_icon
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := Color(UIStyle.MUTED, 0.45 if disabled else 1.0)
	var fill := Color(UIStyle.BG, 0.6)
	for y: int in range(1, size - 1):
		for x: int in range(1, size - 1):
			var border := x <= 2 or y <= 2 or x >= size - 3 or y >= size - 3
			img.set_pixel(x, y, edge if border else fill)
	var tex := ImageTexture.create_from_image(img)
	if disabled:
		_unchecked_disabled_icon = tex
	else:
		_unchecked_icon = tex
	return tex


func _on_toggled() -> void:
	Audio.play_sfx("tick", -4.0, randf_range(0.96, 1.05))
	_update_submit()
	ticks_changed.emit(get_ticked())


func _on_submit() -> void:
	if not _can_submit():
		return
	submitted.emit(get_ticked())


## Enabled iff not locked, at least one box ticked, not every box ticked, and not a set already tried.
func _can_submit() -> bool:
	if _locked or _boxes.is_empty():
		return false
	var t := get_ticked()
	if t.is_empty() or t.size() >= _boxes.size():
		return false
	for prev: Variant in _tried:
		if prev is Array and _same(prev as Array, t):
			return false
	return true


func _update_submit() -> void:
	if _submit != null:
		_submit.disabled = not _can_submit()


## Element-wise comparison of two index lists (typed and untyped arrays compare alike).
func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var sa := a.duplicate()
	sa.sort()
	var sb := b.duplicate()
	sb.sort()
	for i: int in sa.size():
		if int(sa[i]) != int(sb[i]):
			return false
	return true
