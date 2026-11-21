class_name TutorialHint
extends Control
## Guided first task of a new game (Objective 2): one short prompt at a time during Chapter 1, each cleared by
## doing the action, with a pulsing ring on the control to use. It is not an Overlay: it never joins the office's
## overlay stack, never changes the flow state or the score, and only its Skip button takes the mouse.
## It watches the office each frame, so doing steps out of order simply moves it on.

const STEPS: Array[Dictionary] = [
	{"id": "move", "text": "Use W, A, S, D to walk and the mouse to look around."},
	{"id": "desk", "text": "Walk to YOUR DESK, look at the computer and press E."},
	{"id": "sender", "text": "Click the sender's name to see the full address."},
	{"id": "copy", "text": "Scroll down to the blue link in the email and click it, then choose Copy link address. The website will not open."},
	{"id": "paste", "text": "Open the Browser, then press Paste to read the link's real address."},
	{"id": "choose", "text": "You checked the evidence. Now choose a response below."},
]
const MOVE_DISTANCE := 0.75
const CARD_WIDTH := 320.0
const LIST_LEFT := 118.0       ## card's x offset from the DecisionBar: over the empty lower part of the item list

var _office: Node
var _step: int = 0
var _active: bool = false
var _start_pos: Vector3
var _time: float = 0.0

var _card: PanelContainer
var _count: Label
var _text: Label
var _skip: Button
var _ring: Panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_ring = Panel.new()
	var rs := UIStyle.box(Color(0, 0, 0, 0), 8, 0, UIStyle.WARN)
	rs.set_border_width_all(3)
	_ring.add_theme_stylebox_override("panel", rs)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	add_child(_ring)

	_card = PanelContainer.new()
	_card.name = "TutorialCard"
	_card.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.BG, 0.96), 10, 14, UIStyle.WARN))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size.x = CARD_WIDTH
	add_child(_card)

	var v := UIStyle.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	var head := UIStyle.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_count = UIStyle.label("", 13, UIStyle.WARN)
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_count)
	_skip = UIStyle.button("Skip tutorial", 13)
	_skip.name = "TutorialSkip"
	_skip.pressed.connect(finish)
	head.add_child(_skip)
	_text = UIStyle.label("", 16, UIStyle.TEXT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	set_process(false)


## Starts the guide. `office` is the office root (session, player, desktop, state, top_overlay()).
func begin(office: Node) -> void:
	_office = office
	_step = 0
	_active = true
	_start_pos = office.player.global_position
	set_process(true)


func is_active() -> bool:
	return _active


## The id of the current step ("" when the guide is not running).
func step_id() -> String:
	return str(STEPS[_step].id) if _active else ""


func finish() -> void:
	_active = false
	visible = false
	_ring.visible = false
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_office) or _office.session == null or int(_office.session.chapter.get("id", 0)) != 1:
		finish()
		return
	while _active and _step_done(str(STEPS[_step].id)):
		_step += 1
		if _step >= STEPS.size():
			finish()
	if not _active:
		return
	_show_current()


func _step_done(id: String) -> bool:
	var s: ChapterSession = _office.session
	match id:
		"move":
			var moved: Vector3 = _office.player.global_position - _start_pos
			return Vector2(moved.x, moved.z).length() >= MOVE_DISTANCE or _office.desktop.is_open()
		"desk":
			return _office.desktop.is_open()
		"sender":
			return s.inspected.has("sender")
		"copy":
			return s.clipboard != ""
		"paste":
			return s.pasted_url != ""
		"choose":
			return not Game.chapter_log(1).is_empty()
	return true


## Shows the card and ring only while the player can act on them: walking steps with no screen open, desktop
## steps with the desktop on top. Anything else on screen (result card, pause, dialogue) hides them.
func _show_current() -> void:
	var id := str(STEPS[_step].id)
	var top: Overlay = _office.top_overlay()
	var desktop: DesktopUI = _office.desktop
	var walking_step := id == "move" or id == "desk"
	var at_desktop: bool = top == desktop and top != null
	var walking: bool = top == null
	if _office.state != "ACTIVE" or not (at_desktop or walking):
		visible = false
		return
	visible = true
	_count.text = "TUTORIAL  ·  %d of %d" % [_step + 1, STEPS.size()]
	_skip.visible = at_desktop    # the mouse is captured while walking
	var target: Control = null
	if walking and not walking_step:
		_text.text = "Go back to your computer and press E."
	else:
		_text.text = str(STEPS[_step].text)
		if at_desktop:
			target = _target(id, desktop)
	_place_card(at_desktop, desktop)
	_place_ring(target)


func _target(id: String, desktop: DesktopUI) -> Control:
	match id:
		"sender", "copy":
			# The email is in Mail: bring the player back to it if they wandered off.
			if desktop.current_app() != "mail":
				_text.text = "Click Mail on the left to go back to the email."
				return desktop.tutorial_target("mail")
			return desktop.tutorial_target("sender" if id == "sender" else "body")
		"paste":
			return desktop.tutorial_target("paste" if desktop.current_app() == "browser" else "browser")
		"choose":
			return desktop.tutorial_target("decision")
	return null


func _place_card(at_desktop: bool, desktop: DesktopUI) -> void:
	_card.reset_size()
	if at_desktop:
		var bar := desktop.tutorial_target("decision")
		if bar != null:
			var r := bar.get_global_rect()
			_card.global_position = Vector2(r.position.x + LIST_LEFT, r.position.y - _card.size.y - 10.0)
			return
	# Walking: under the objective line, centered.
	_card.global_position = Vector2((size.x - _card.size.x) * 0.5, 84.0)


func _place_ring(target: Control) -> void:
	if target == null or not target.is_visible_in_tree():
		_ring.visible = false
		return
	var r := target.get_global_rect()
	# A control inside a scroll area is only outlined where it can be seen.
	var parent := target.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			r = r.intersection((parent as ScrollContainer).get_global_rect())
			break
		parent = parent.get_parent()
	r = r.grow(4.0)
	_ring.global_position = r.position
	_ring.size = r.size
	_ring.visible = true
	_ring.modulate.a = 0.7 + 0.3 * sin(_time * 4.0)
