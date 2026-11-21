class_name UIStyle
extends RefCounted
## Shared look for every screen: colours, fonts, panels and buttons. All UI is built in code with these helpers.

const BG := Color("10141a")
const PANEL := Color("1a212b")
const PANEL_LIGHT := Color("252e3b")
const PANEL_LIGHTER := Color("323d4d")
const ACCENT := Color("3fa7d6")
const TEXT := Color("e8edf2")
const MUTED := Color("97a3b0")
const GOOD := Color("4caf6a")
const WARN := Color("e8a33a")
const DANGER := Color("e04848")

static var _mono: SystemFont


## Monospace font for addresses, URLs and numbers so l, 1, rn and m can be told apart.
static func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	return _mono


static func box(color: Color = PANEL, radius: int = 8, pad: int = 16, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	return sb


static func panel(color: Color = PANEL, pad: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, 8, pad))
	return p


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func mono_label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", mono_font())
	return l


static func title(text: String, size: int = 30) -> Label:
	var l := label(text, size, TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Mouse-only button (focus none) so keyboard keys never trigger a choice by accident.
static func button(text: String, size: int = 18, color: Color = PANEL_LIGHT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))
	b.add_theme_stylebox_override("normal", box(color, 6, 12))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), 6, 12, ACCENT))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 6, 12, ACCENT))
	b.add_theme_stylebox_override("disabled", box(Color(color, 0.45), 6, 12))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## Marks a choice the player already tried (wrong, -5): a red-bordered disabled look and a tooltip, so it reads
## differently from a choice that is only locked until the inspections are done. The text is unchanged.
static func mark_tried(b: Button, tried: bool) -> void:
	if tried:
		var sb := box(Color(DANGER, 0.12), 6, 12, Color(DANGER, 0.85))
		b.add_theme_stylebox_override("disabled", sb)
		b.add_theme_color_override("font_disabled_color", Color(DANGER.lightened(0.35), 0.8))
		b.tooltip_text = "Already tried (%d)" % Game.WRONG
	elif b.tooltip_text.begins_with("Already tried"):
		b.remove_theme_stylebox_override("disabled")
		b.add_theme_stylebox_override("disabled", box(Color(PANEL_LIGHT, 0.45), 6, 12))
		b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))
		b.tooltip_text = ""


## A full-screen translucent backdrop that blocks clicks to whatever is behind it.
static func backdrop(alpha: float = 0.65) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A CenterContainer filling the parent, for centring a panel on screen.
static func center() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func outcome_color(outcome: String) -> Color:
	match outcome:
		"correct", "complete":
			return GOOD
		"wrong":
			return WARN
		"unsafe":
			return DANGER
	return TEXT
