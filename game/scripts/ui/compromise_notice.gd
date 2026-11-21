class_name CompromiseNotice
extends Overlay
## The compromise notification after an unsafe choice (Objective 6): a full-screen red security alert
## with the chapter's compromise text. It stays for 2.5 s (ESC and the advance keys cannot skip it),
## then hides and emits `finished`. Followed by the Game Over screen.
## Place-aware: at the office it is Aegis's security alert; off the clock (home, cafe) it is a personal-loss
## alert with no Aegis or Black Veil wording (the office passes builder.location to show_notice()).
## Game feel: the alarm sound, ONE red flash, a short decaying screen shake and a few glitch bars at the start.
## Accessibility: nothing flashes faster than 3 Hz (one flash; the background pulse is 1.25 Hz).

signal finished

const DURATION := 2.5
const RED_DARK := Color("1c0405")
const RED_MID := Color("3d0a0c")
const OFFICE_HEADING := "SECURITY ALERT — ACCOUNT COMPROMISED"
const OFFICE_SOURCE := "Aegis Solutions Security Office · Incident detected"
const PHONE_HEADING := "YOUR ACCOUNT WAS COMPROMISED"
const PHONE_SOURCE := "Your phone · Off the clock"

var _bg: ColorRect
var _heading: Label
var _source: Label
var _text: Label
var _bar: ProgressBar
var _pulse: Tween
var _timer: Tween
var _content: Control
var _flash: ColorRect
var _glitch: Array[ColorRect] = []
var _fx: Tween


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = RED_DARK
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.full_rect(_bg)
	add_child(_bg)

	# Red hazard bars at the top and bottom edges.
	for top: bool in [true, false]:
		var edge := ColorRect.new()
		edge.color = UIStyle.DANGER
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			edge.offset_bottom = 10
		else:
			edge.offset_top = -10
		add_child(edge)

	var center := UIStyle.center()
	_content = center
	add_child(center)
	var v := UIStyle.vbox(22)
	v.custom_minimum_size = Vector2(900, 0)
	center.add_child(v)

	var icon := UIStyle.title("⚠", 88)
	icon.add_theme_color_override("font_color", UIStyle.DANGER)
	v.add_child(icon)

	_heading = UIStyle.title(OFFICE_HEADING, 40)
	_heading.name = "Heading"
	_heading.add_theme_color_override("font_color", Color.WHITE)
	_heading.add_theme_font_override("font", DialoguePanel.bold_font())
	v.add_child(_heading)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.box(Color(0, 0, 0, 0.45), 10, 24, UIStyle.DANGER))
	v.add_child(box)
	_text = UIStyle.label("", 26, Color("ffe1e1"))
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)

	_source = UIStyle.title(OFFICE_SOURCE, 16)
	_source.name = "Source"
	_source.add_theme_color_override("font_color", Color("e89a9a"))
	v.add_child(_source)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.add_theme_stylebox_override("background", UIStyle.box(Color(1, 1, 1, 0.08), 3, 0))
	_bar.add_theme_stylebox_override("fill", UIStyle.box(UIStyle.DANGER, 3, 0))
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bar)

	# Glitch bars (thin offset strips) and the single red flash, both over everything.
	for i: int in 4:
		var g := ColorRect.new()
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.color = Color(1.0, 0.25, 0.3, 0.22) if i % 2 == 0 else Color(0.4, 0.9, 1.0, 0.12)
		g.visible = false
		add_child(g)
		_glitch.append(g)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.16, 0.12, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(_flash)
	add_child(_flash)


## Shows the alert with `text`, waits 2.5 s, hides and emits `finished`. `place` is the chapter's place
## ("office", "home" or "cafe"): only the office alert names Aegis.
func show_notice(text: String, place: String = "office") -> void:
	var office := place == "office"
	_heading.text = OFFICE_HEADING if office else PHONE_HEADING
	_source.text = OFFICE_SOURCE if office else PHONE_SOURCE
	_text.text = text
	_bar.value = 100.0
	show_overlay()
	Audio.cut_music()
	Audio.play_sfx("breach_hit", -1.0)
	Audio.play_sfx("unsafe_alarm", -8.0)
	_play_impact()

	if _pulse != null:
		_pulse.kill()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_bg, "color", RED_MID, 0.4)
	_pulse.tween_property(_bg, "color", RED_DARK, 0.4)

	if _timer != null:
		_timer.kill()
	_timer = create_tween()
	_timer.tween_property(_bar, "value", 0.0, DURATION)
	_timer.tween_callback(_done)


## ESC is blocked on this screen.
func handle_back() -> void:
	pass


## One red flash (0.5 s fade), a 0.45 s decaying shake of the alert and glitch bars that fade with it.
func _play_impact() -> void:
	if _fx != null:
		_fx.kill()
	var view := get_viewport_rect().size
	for g: ColorRect in _glitch:
		var h := randf_range(6.0, 22.0)
		g.position = Vector2(randf_range(-40.0, 40.0), randf_range(0.15, 0.85) * view.y)
		g.size = Vector2(view.x + 80.0, h)
		g.modulate.a = 1.0
		g.visible = true
	_flash.color.a = 0.55
	_fx = create_tween().set_parallel(true)
	_fx.tween_property(_flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fx.tween_method(_shake, 1.0, 0.0, 0.45)
	for g: ColorRect in _glitch:
		_fx.tween_property(g, "modulate:a", 0.0, 0.35).set_delay(0.1)
	_fx.chain().tween_callback(_end_impact)


## Offsets the alert content by a random amount scaled by `strength` (1 -> 0).
func _shake(strength: float) -> void:
	var a := 9.0 * strength * strength
	_offset_content(Vector2(randf_range(-a, a), randf_range(-a, a) * 0.6))


## Moves the full-rect alert content without resizing it (all four offsets move together).
func _offset_content(d: Vector2) -> void:
	_content.offset_left = d.x
	_content.offset_right = d.x
	_content.offset_top = d.y
	_content.offset_bottom = d.y


func _end_impact() -> void:
	_offset_content(Vector2.ZERO)
	_flash.color.a = 0.0
	for g: ColorRect in _glitch:
		g.visible = false


func _done() -> void:
	if _fx != null:
		_fx.kill()
	_end_impact()
	if _pulse != null:
		_pulse.kill()
	_bg.color = RED_DARK
	hide_overlay()
	finished.emit()
