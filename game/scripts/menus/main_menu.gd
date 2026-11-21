extends Control
## Main menu (Objective 2): Play, Instructions, Fun Facts, Settings, Exit. The first screen the player sees.
## Behind it runs the real 3D office at noir night (Chapter 9's mood, office_noir) with a slowly drifting camera, so
## the first impression is the game itself. Play opens Chapter Select (big chapter cards with their subquests);
## Instructions, Fun Facts and Settings open in place of the menu. Back or ESC closes any of them.

const NIGHT_CHAPTER := 9
const CAM_POS := Vector3(5.6, 1.72, 4.1)
const CAM_LOOK := Vector3(-2.2, 1.05, -2.2)
const CAM_SWAY := Vector3(0.55, 0.06, 0.3)
const CAM_SWAY_SPEED := 0.13
const GLITCH_EVERY := Vector2(4.0, 8.0)
const GLITCH_TIME := 0.16
const TITLE_SPLIT := 3.0
const TICKER_SPEED := 42.0
const TICKER_TEXT := "MAIL GATEWAY: suspicious messages quarantined     ·     CALL LOG: unknown outside line flagged     ·     CHAT: copied account reported     ·     QR SCAN: lookalike domain blocked     ·     AEGIS SECURITY OFFICE: monitoring     ·     THREAT GROUP: BLACK VEIL active     ·     "

var _hero: VBoxContainer
var _buttons: Array[Button] = []
var _instructions: InstructionsPanel
var _fun_facts: FunFactsPanel
var _settings: SettingsPanel
var _select: ChapterSelect
var _camera: Camera3D
var _time: float = 0.0
var _title_cyan: Label
var _title_pink: Label
var _title_main: Label
var _next_glitch: float = 3.0
var _glitch_left: float = 0.0
var _ticker: Label
var _curtain: ColorRect


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UIStyle.full_rect(self)
	Audio.set_music("night")
	_build_background()
	_build_ticker()
	_build_hero()
	_build_panels()
	_animate_in()
	if Game.open_select:          # back from a chapter: straight to the cards
		Game.open_select = false
		_show_select()


func _process(delta: float) -> void:
	_time += delta
	_drift_camera()
	_update_title(delta)
	_ticker.position.x -= TICKER_SPEED * delta
	if _ticker.position.x < -_ticker.size.x * 0.5:
		_ticker.position.x += _ticker.size.x * 0.5


## ESC closes an open Instructions, Fun Facts, Settings or Chapter Select panel.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and _panel_open():
		_show_menu()
		get_viewport().set_input_as_handled()


# --- Building -----------------------------------------------------------------

## The live office in its own 3D world, then the shading that keeps the menu readable over it.
func _build_background() -> void:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(holder)
	add_child(holder)

	var view := SubViewport.new()
	view.own_world_3d = true
	view.handle_input_locally = false
	view.msaa_3d = Viewport.MSAA_2X
	holder.add_child(view)

	var office := OfficeBuilder.new()
	view.add_child(office)
	office.apply_chapter_mood(NIGHT_CHAPTER)
	_hide_world_labels(office)

	_camera = Camera3D.new()
	_camera.fov = 58.0
	view.add_child(_camera)
	_camera.current = true
	_drift_camera()

	# Dark on the left behind the menu, fading to the clear office on the right; a little darker top and bottom.
	add_child(_shade(GradientTexture2D.FILL_LINEAR, Vector2(0.0, 0.5), Vector2(0.72, 0.5), Color(0.02, 0.03, 0.06, 0.93), Color(0.02, 0.03, 0.06, 0.0)))
	add_child(_shade(GradientTexture2D.FILL_LINEAR, Vector2(0.5, 0.62), Vector2(0.5, 1.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.6)))
	add_child(_shade(GradientTexture2D.FILL_LINEAR, Vector2(0.5, 0.0), Vector2(0.5, 0.2), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.0)))


## "YOUR DESK" and the name tag are in-game guidance: they would only clutter the menu.
func _hide_world_labels(node: Node) -> void:
	for child: Node in node.get_children():
		var label := child as Label3D
		if label != null and not label.text.to_upper().contains("RECEPTION"):
			label.visible = false
		_hide_world_labels(child)


## A slow scrolling status line along the bottom. Pure atmosphere: it never takes input.
func _build_ticker() -> void:
	var band := Control.new()
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -38.0
	band.offset_bottom = -12.0
	add_child(band)
	_ticker = UIStyle.mono_label(TICKER_TEXT + TICKER_TEXT, 14, Color(UIStyle.ACCENT, 0.75))
	_ticker.autowrap_mode = TextServer.AUTOWRAP_OFF
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(_ticker)
	_ticker.reset_size()


## Left-aligned, like a game's title screen, leaving the office visible on the right.
func _build_hero() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(margin)
	margin.add_theme_constant_override("margin_left", 88)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	_hero = UIStyle.vbox(0)
	_hero.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(_hero)

	_hero.add_child(_build_title())
	var line := ColorRect.new()
	line.color = UIStyle.ACCENT
	line.custom_minimum_size = Vector2(120, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(line)
	_hero.add_child(_gap(14))
	var tag := UIStyle.label("Verify before you trust.", 20, Color(UIStyle.TEXT, 0.85))
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hero.add_child(tag)
	_hero.add_child(_gap(40))

	var column := UIStyle.vbox(10)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hero.add_child(column)
	_add_button(column, "Play", true, _show_select)
	_add_button(column, "Instructions", false, _on_instructions)
	_add_button(column, "Fun Facts", false, _show_fun_facts, "FunFactsButton")
	_add_button(column, "Settings", false, _on_settings)
	_add_button(column, "Exit", false, _on_exit)


## The title: three stacked copies whose cyan and pink edges split apart, with a brief glitch now and then.
func _build_title() -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_cyan = _title_layer(Color(0.2, 0.9, 1.0, 0.55))
	_title_pink = _title_layer(Color(1.0, 0.25, 0.65, 0.55))
	_title_main = _title_layer(UIStyle.TEXT)
	_title_main.add_theme_color_override("font_shadow_color", Color(UIStyle.ACCENT, 0.4))
	_title_main.add_theme_constant_override("shadow_offset_x", 0)
	_title_main.add_theme_constant_override("shadow_offset_y", 0)
	_title_main.add_theme_constant_override("shadow_outline_size", 22)
	for l: Label in [_title_cyan, _title_pink, _title_main]:
		box.add_child(l)
	# Fixed: a Label reports its real size only once it is in the tree, and the stack lays out before that.
	box.custom_minimum_size = Vector2(560.0, 132.0)
	return box


func _title_layer(color: Color) -> Label:
	var l := UIStyle.label("VIGILANT", 92, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", _title_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _add_button(parent: VBoxContainer, text: String, primary: bool, handler: Callable, node_name: String = "") -> void:
	var b := Button.new()
	if node_name != "":
		b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 52)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", UIStyle.TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(UIStyle.MUTED, 0.6))
	var base := Color(UIStyle.ACCENT, 0.32) if primary else Color(0.05, 0.07, 0.11, 0.62)
	var edge := UIStyle.ACCENT if primary else Color(1, 1, 1, 0.16)
	b.add_theme_stylebox_override("normal", _button_box(base, edge))
	b.add_theme_stylebox_override("hover", _button_box(Color(UIStyle.ACCENT, 0.5), Color(0.55, 0.95, 1.0)))
	b.add_theme_stylebox_override("pressed", _button_box(Color(UIStyle.ACCENT, 0.7), Color.WHITE))
	b.add_theme_stylebox_override("disabled", _button_box(Color(0.05, 0.07, 0.11, 0.4), Color(1, 1, 1, 0.08)))
	b.pressed.connect(handler)
	b.mouse_entered.connect(_nudge.bind(b, 12.0))
	b.mouse_exited.connect(_nudge.bind(b, 0.0))
	parent.add_child(b)
	_buttons.append(b)


func _button_box(color: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = edge
	sb.border_width_left = 4
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 22
	sb.content_margin_right = 14
	return sb


## Slides a hovered button to the right, and back.
func _nudge(b: Button, x: float) -> void:
	if b.disabled:
		return
	create_tween().tween_property(b, "position:x", x, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The panels share one centred slot and replace the whole menu while open.
func _build_panels() -> void:
	var center := UIStyle.center()
	add_child(center)

	_instructions = InstructionsPanel.new()
	_instructions.visible = false
	_instructions.back_pressed.connect(_show_menu)
	center.add_child(_instructions)

	_fun_facts = FunFactsPanel.new()
	_fun_facts.name = "FunFacts"
	_fun_facts.visible = false
	_fun_facts.back_pressed.connect(_show_menu)
	center.add_child(_fun_facts)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(_show_menu)
	center.add_child(_settings)

	_select = ChapterSelect.new()
	_select.name = "ChapterSelect"
	_select.visible = false
	_select.back_pressed.connect(_show_menu)
	_select.chapter_chosen.connect(_on_chapter_chosen)
	add_child(_select)


## Wide, bold letter-spaced version of the default font for the title.
func _title_font() -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.9
	fv.set_spacing(TextServer.SPACING_GLYPH, 14)
	return fv


func _shade(fill: GradientTexture2D.Fill, from: Vector2, to: Vector2, inner: Color, outer: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = fill
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(r)
	return r


func _gap(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# --- Motion -------------------------------------------------------------------

## A slow, gentle drift so the office feels alive.
func _drift_camera() -> void:
	var t := _time * CAM_SWAY_SPEED
	_camera.position = CAM_POS + Vector3(sin(t) * CAM_SWAY.x, sin(t * 1.7) * CAM_SWAY.y, cos(t * 0.8) * CAM_SWAY.z)
	_camera.look_at(CAM_LOOK + Vector3(sin(t * 0.6) * 0.5, 0.0, 0.0), Vector3.UP)


## The title's colored edges rest slightly apart; every few seconds they jump for a moment (one short glitch,
## never a repeating flash).
func _update_title(delta: float) -> void:
	var split := TITLE_SPLIT
	var y := 0.0
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_next_glitch = randf_range(GLITCH_EVERY.x, GLITCH_EVERY.y)
		_glitch_left = GLITCH_TIME
	if _glitch_left > 0.0:
		_glitch_left -= delta
		split = 11.0
		y = 2.0
	_title_cyan.position = Vector2(-split, -y)
	_title_pink.position = Vector2(split, y)


## Fades up from black, so the office appears only once it is ready.
func _animate_in() -> void:
	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(_curtain)
	add_child(_curtain)
	_hero.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_curtain, "modulate:a", 0.0, 1.2).set_delay(0.1)
	t.tween_property(_hero, "modulate:a", 1.0, 0.7).set_delay(0.7)
	t.chain().tween_callback(_curtain.hide)


# --- Navigation ---------------------------------------------------------------

func _panel_open() -> bool:
	return _instructions.visible or _fun_facts.visible or _settings.visible or _select.visible


func _show_menu() -> void:
	_instructions.visible = false
	_fun_facts.visible = false
	_settings.visible = false
	_select.visible = false
	_ticker.get_parent().visible = true
	_hero.visible = true


func _show_panel(panel: Control) -> void:
	_hero.visible = false
	_instructions.visible = panel == _instructions
	_fun_facts.visible = panel == _fun_facts
	_settings.visible = panel == _settings
	_select.visible = panel == _select
	_ticker.get_parent().visible = panel != _select      # the cards use the whole screen


func _set_buttons_enabled(on: bool) -> void:
	for b: Button in _buttons:
		b.disabled = not on


func _show_select() -> void:
	_select.refresh()
	_show_panel(_select)


## Starts a chapter (or one of its subquests) chosen on the cards.
func _on_chapter_chosen(n: int, item_id: String) -> void:
	if Router.is_busy():
		return
	_set_buttons_enabled(false)
	Game.select_chapter(n, item_id)
	Router.go_to(Router.OFFICE)


func _on_instructions() -> void:
	_show_panel(_instructions)


## The Fun Facts page (every fact with its source). Reading only: nothing scores.
func _show_fun_facts() -> void:
	_fun_facts.refresh()
	_show_panel(_fun_facts)


func _on_settings() -> void:
	_settings.refresh()
	_show_panel(_settings)


func _on_exit() -> void:
	_set_buttons_enabled(false)
	Router.quit()
