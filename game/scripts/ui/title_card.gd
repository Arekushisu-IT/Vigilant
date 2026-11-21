class_name TitleCard
extends Control
## Chapter title card shown at each chapter start: "CHAPTER N · OFFICE / HOME / CAFE", the title and the day and
## time (chapter "when"), fading in and out over about 2.5 s, with a Fun Fact (FunFacts.pick(n, "start")) under it.
## It is not an Overlay: it never takes input, never joins the office's overlay stack and never changes the flow
## state; it simply plays over the briefing dialogue (upper part of the screen, between the HUD top bar and the
## dialogue panel). The title band fades out by itself; the Fun Fact stays until dismiss(), which the office calls
## when the briefing ends, and which hides both.
## No autoload names here (Audio is looked up at runtime), so tests can call TitleCard.time_of() from --script.

## Fallback times (the old six office chapters) for chapter data without a "when" key.
const TIMES: Array[String] = ["08:30 AM", "12:00 PM", "03:30 PM", "05:00 PM", "06:30 PM", "09:00 PM"]
const PLACES := {"office": "OFFICE", "home": "HOME", "cafe": "CAFE"}
const FADE_IN := 0.45
const HOLD := 1.6
const FADE_OUT := 0.45
const FACT_WIDTH := 640.0

var _band: PanelContainer
var _eyebrow: Label
var _title: Label
var _time: Label
var _fact: FunFactCard
var _tween: Tween
var _text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# Band and fact stacked in the upper part of the screen: from 22% down they end well above the dialogue panel
	# (bottom 200 px) and start below the HUD top bar.
	var stack := UIStyle.vbox(14)
	stack.anchor_left = 0.0
	stack.anchor_right = 1.0
	stack.anchor_top = 0.22
	stack.anchor_bottom = 0.22
	stack.offset_top = -10
	stack.offset_bottom = 300
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(stack)

	_band = PanelContainer.new()
	_band.name = "Band"
	_band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := UIStyle.box(Color(UIStyle.BG, 0.82), 12, 0, Color(UIStyle.ACCENT, 0.55))
	sb.content_margin_left = 56
	sb.content_margin_right = 56
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	sb.border_width_left = 0
	sb.border_width_right = 0
	_band.add_theme_stylebox_override("panel", sb)
	stack.add_child(_band)

	var v := UIStyle.vbox(4)
	_band.add_child(v)
	_eyebrow = UIStyle.title("", 15)
	_eyebrow.add_theme_color_override("font_color", UIStyle.ACCENT)
	_eyebrow.add_theme_font_override("font", DialoguePanel.bold_font())
	v.add_child(_eyebrow)
	_title = UIStyle.title("", 40)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.add_theme_font_override("font", DialoguePanel.bold_font())
	v.add_child(_title)
	_time = UIStyle.title("", 18)
	_time.add_theme_color_override("font_color", UIStyle.MUTED)
	_time.add_theme_font_override("font", UIStyle.mono_font())
	v.add_child(_time)

	_fact = FunFactCard.new(FACT_WIDTH, 16)
	_fact.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(_fact)
	DialoguePanel.ignore_mouse(self)


## Plays the card for chapter `n`: the band fades in, holds and fades out; the chapter's start Fun Fact fades in
## with it and stays until dismiss(). Calling it again restarts it.
func show_card(n: int, chapter_title: String) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.call("play_sfx", "title_hit", -4.0)
		audio.call("duck_music", -6.0, 1.2)
	var time := time_of(n)
	_text = "Chapter %d · %s · %s" % [n, chapter_title, time]
	_eyebrow.text = "CHAPTER %d  ·  %s" % [n, place_label(n)]
	_title.text = chapter_title
	_time.text = time
	_fact.set_fact(FunFacts.pick(n, "start"))
	if _tween != null:
		_tween.kill()
	visible = true
	modulate.a = 1.0
	_band.visible = true
	_band.modulate.a = 0.0
	_fact.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_band, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_fact, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_delay(0.25)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_band, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE)


## Fades the card (band and Fun Fact) out now: the briefing it plays over has ended, and it must not sit over
## the game.
func dismiss() -> void:
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(_hide_all)


## "Chapter N · Title · Mon 08:30 AM" of the card shown last.
func text() -> String:
	return _text


## True from show_card() until dismiss() has finished (the Fun Fact stays after the band has faded).
func is_showing() -> bool:
	return visible


## True while the Fun Fact is on screen.
func fact_showing() -> bool:
	return visible and _fact.visible


## The Fun Fact card (node "FunFact").
func fact_card() -> FunFactCard:
	return _fact


func _hide_all() -> void:
	hide()
	modulate.a = 1.0
	_fact.set_fact({})


## Chapter n's day and time ("Mon 08:30 AM"), from the chapter data's "when".
static func time_of(n: int) -> String:
	var fallback := TIMES[clampi(n, 1, TIMES.size()) - 1]
	if n < 1 or n > Campaign.CHAPTERS.size():
		return fallback
	return str(Campaign.chapter(n).get("when", fallback))


## "OFFICE", "HOME" or "CAFE" for chapter n.
static func place_label(n: int) -> String:
	var place := "office"
	if n >= 1 and n <= Campaign.CHAPTERS.size():
		place = str(Campaign.chapter(n).get("place", "office"))
	return str(PLACES.get(place, place.to_upper()))
