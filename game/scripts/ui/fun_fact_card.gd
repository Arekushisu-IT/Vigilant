class_name FunFactCard
extends PanelContainer
## One Fun Fact (FunFacts): a "DID YOU KNOW?" eyebrow, the fact text and its source in small muted text.
## Used by the title card (chapter start) and the feedback screen (chapter results). Pure display: it never
## takes input (MOUSE_FILTER_IGNORE on itself and every child), never scores and plays no sound.
## set_fact({}) hides it.

var _eyebrow: Label
var _text: Label
var _source: Label
var _fact: Dictionary = {}


## `width` is the fixed minimum width (0 = take the parent's width; wrapped labels need one or the other).
func _init(width: float = 0.0, text_size: int = 16) -> void:
	name = "FunFact"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, 0)
	var sb := UIStyle.box(Color(UIStyle.PANEL_LIGHT, 0.92), 8, 12, Color(UIStyle.WARN, 0.35))
	sb.border_width_left = 4
	sb.border_color = Color(UIStyle.WARN, 0.8)
	sb.content_margin_left = 16
	add_theme_stylebox_override("panel", sb)

	var v := UIStyle.vbox(3)
	add_child(v)
	_eyebrow = UIStyle.label("DID YOU KNOW?", 12, UIStyle.WARN)
	_eyebrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	_eyebrow.add_theme_font_override("font", DialoguePanel.bold_font())
	v.add_child(_eyebrow)
	_text = UIStyle.label("", text_size, UIStyle.TEXT)
	_text.name = "FactText"
	v.add_child(_text)
	_source = UIStyle.label("", 12, UIStyle.MUTED)
	_source.name = "FactSource"
	v.add_child(_source)
	DialoguePanel.ignore_mouse(self)
	visible = false


## Shows fact `f` (a FunFacts entry); an empty dictionary hides the card.
func set_fact(f: Dictionary) -> void:
	_fact = f.duplicate(true)
	if f.is_empty():
		_text.text = ""
		_source.text = ""
		visible = false
		return
	_text.text = FunFacts.display_text(f)
	_source.text = FunFacts.source_line(f)
	visible = true


## The fact shown now ({} when hidden).
func fact() -> Dictionary:
	return _fact


## The text shown now (fact text, then the source line), for tests and captures.
func shown_text() -> String:
	return "" if _fact.is_empty() else _text.text + "\n" + _source.text
