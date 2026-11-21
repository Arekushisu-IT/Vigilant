class_name ChapterSelect
extends Control
## Chapter Select, opened by Play on the main menu: one big chapter card at a time in the middle, with ‹ › arrows
## (and dots) to move between the ten chapters. The card lists the chapter's subquests (its items): click the card's
## Play to start the chapter, or a subquest to start the chapter at that message (the ones before it are skipped).
## Chapters unlock in order (finish one to open the next); Review mode in Settings opens them all and makes the
## subquests clickable, so a panel can review any scenario directly.
## The cards show this run's progress (done, badge, score), which lives in memory only: nothing is saved.
## Subquest labels are the neutral task names, so a card never reveals which messages are fake.
## The tag line ("Text message · Home · Mon 07:30 PM") comes from the chapter data (attack, place, when).

signal back_pressed
signal chapter_chosen(n: int, item_id: String)

const CARD_SIZE := Vector2(660, 450)
const SLIDE := 70.0
const PLACES := {"office": "Office", "home": "Home", "cafe": "Cafe"}

var _stack: Control
var _cards: Array[Control] = []
var _dots: HBoxContainer
var _prev: Button
var _next: Button
var _summary: Label
var _index: int = 0
var _tween: Tween


func _ready() -> void:
	UIStyle.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	UIStyle.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := UIStyle.vbox(10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)

	var head := UIStyle.hbox(14)
	root.add_child(head)
	var titles := UIStyle.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var title := UIStyle.label("Select a chapter", 30)
	title.add_theme_font_override("font", DialoguePanel.bold_font())
	titles.add_child(title)
	_summary = UIStyle.label("", 15, UIStyle.MUTED)
	titles.add_child(_summary)
	var reset := UIStyle.button("Reset progress", 15)
	reset.tooltip_text = "Clear this run's results and badges"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_on_reset)
	head.add_child(reset)
	var back := UIStyle.button("Back", 16, UIStyle.ACCENT.darkened(0.45))
	back.custom_minimum_size = Vector2(120, 0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(back)

	# ‹ [ card ] ›
	var row := UIStyle.hbox(26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	_prev = _arrow("‹", -1)
	row.add_child(_prev)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	_stack = Control.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_stack)
	_next = _arrow("›", 1)
	row.add_child(_next)

	var dots_row := CenterContainer.new()
	dots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dots_row)
	_dots = UIStyle.hbox(12)
	dots_row.add_child(_dots)
	refresh()


## Rebuilds the cards from this run's progress and opens on the first chapter not done yet.
func refresh() -> void:
	for c: Control in _cards:
		_stack.remove_child(c)
		c.queue_free()
	_cards.clear()
	for child: Node in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	for n: int in range(1, Game.CHAPTER_COUNT + 1):
		var card := _card(n)
		_stack.add_child(card)
		_cards.append(card)
		var dot := Button.new()
		dot.name = "Dot%d" % n
		dot.focus_mode = Control.FOCUS_NONE
		dot.custom_minimum_size = Vector2(16, 16)
		dot.tooltip_text = "Chapter %d" % n
		dot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dot.pressed.connect(show_chapter.bind(n))
		_dots.add_child(dot)
	# Every card has the same fixed size, so the arrows and dots never jump around.
	_stack.custom_minimum_size = CARD_SIZE
	for card: Control in _cards:
		card.size = CARD_SIZE
	var done := Game.completed.count(true)
	var how := "REVIEW MODE: all chapters open, click a task to start right there." if Settings.review_mode else "Finish a chapter to unlock the next."
	_summary.text = "Chapters completed: %d of %d   ·   Score: %d   ·   %s" % [done, Game.CHAPTER_COUNT, Game.score, how]
	_summary.add_theme_color_override("font_color", UIStyle.WARN if Settings.review_mode else UIStyle.MUTED)
	var first := Game.completed.find(false)
	_index = first if first >= 0 else 0
	_show(_index, 0)


## Shows chapter n's card (1-based).
func show_chapter(n: int) -> void:
	var to := clampi(n - 1, 0, _cards.size() - 1)
	if to != _index:
		_show(to, signi(to - _index))


func current_chapter() -> int:
	return _index + 1


func _step(dir: int) -> void:
	var to := _index + dir
	if to >= 0 and to < _cards.size():
		_show(to, dir)


## Slides the new card in from the side it comes from.
func _show(i: int, dir: int) -> void:
	_index = i
	if _tween != null:
		_tween.kill()
	for k: int in _cards.size():
		_cards[k].visible = k == i
		_cards[k].position = Vector2.ZERO
		_cards[k].modulate.a = 1.0
	if dir != 0:
		var card := _cards[i]
		card.position.x = SLIDE * dir
		card.modulate.a = 0.0
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(card, "position:x", 0.0, 0.25)
		_tween.tween_property(card, "modulate:a", 1.0, 0.2)
	_prev.disabled = i == 0
	_next.disabled = i == _cards.size() - 1
	for k: int in _dots.get_child_count():
		var dot := _dots.get_child(k) as Button
		var color := UIStyle.ACCENT if k == i else (UIStyle.GOOD if Game.completed[k] else Color(1, 1, 1, 0.25 if _open(k + 1) else 0.1))
		var sb := UIStyle.box(color, 8, 0)
		for state: String in ["normal", "hover", "pressed"]:
			dot.add_theme_stylebox_override(state, sb)


## A round ‹ or › button beside the card.
func _arrow(glyph: String, dir: int) -> Button:
	var b := Button.new()
	b.name = "Prev" if dir < 0 else "Next"
	b.text = glyph
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Previous chapter" if dir < 0 else "Next chapter"
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", UIStyle.TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(UIStyle.MUTED, 0.3))
	b.add_theme_stylebox_override("normal", UIStyle.box(Color(0.05, 0.07, 0.11, 0.7), 32, 0, Color(UIStyle.ACCENT, 0.6)))
	b.add_theme_stylebox_override("hover", UIStyle.box(Color(UIStyle.ACCENT, 0.45), 32, 0, UIStyle.ACCENT))
	b.add_theme_stylebox_override("pressed", UIStyle.box(Color(UIStyle.ACCENT, 0.7), 32, 0, Color.WHITE))
	b.add_theme_stylebox_override("disabled", UIStyle.box(Color(0.05, 0.07, 0.11, 0.35), 32, 0))
	b.pressed.connect(_step.bind(dir))
	return b


func _card(n: int) -> Control:
	var ch := Campaign.chapter(n)
	var done: bool = Game.completed[n - 1]
	var open := _open(n)
	var flawless := done and Achievements.chapter_flawless(n)
	var edge := UIStyle.WARN if flawless else (UIStyle.GOOD if done else (UIStyle.ACCENT if open else UIStyle.MUTED))

	var card := PanelContainer.new()
	card.name = "Chapter%d" % n
	var sb := UIStyle.box(Color(0.06, 0.08, 0.12, 0.93), 14, 24, Color(edge, 0.55))
	sb.border_width_top = 6
	sb.border_color = edge
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var v := UIStyle.vbox(8)
	# Fixed inner width: cards start hidden, and hidden wrapping labels would otherwise collapse to one letter wide.
	v.custom_minimum_size.x = CARD_SIZE.x - 48.0
	card.add_child(v)
	var top := UIStyle.hbox(8)
	v.add_child(top)
	var eyebrow := _tag("CHAPTER %d OF %d" % [n, Game.CHAPTER_COUNT], edge, 14)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(eyebrow)
	top.add_child(_chip(n, done, flawless) if open else _tag("LOCKED", UIStyle.MUTED, 14))

	var name_l := UIStyle.label(str(ch.get("title", "")), 32)
	name_l.add_theme_font_override("font", DialoguePanel.bold_font())
	name_l.custom_minimum_size.x = CARD_SIZE.x - 48.0
	v.add_child(name_l)
	v.add_child(_tag(tag_line(n), UIStyle.MUTED, 15))
	var premise := UIStyle.label(_premise(ch), 16, Color(UIStyle.TEXT, 0.85))
	premise.custom_minimum_size.x = CARD_SIZE.x - 48.0
	v.add_child(premise)
	v.add_child(DialoguePanel.rule(Color(1, 1, 1, 0.1)))
	v.add_child(_tag("TASKS  ·  click one to start there" if Settings.review_mode else "TASKS", UIStyle.WARN if Settings.review_mode else UIStyle.MUTED, 13))

	var list := UIStyle.vbox(2)
	v.add_child(list)
	for it: Dictionary in ch.get("items", []):
		list.add_child(_subquest(n, it))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)          # keeps Play at the bottom of every card
	v.add_child(DialoguePanel.rule(Color(1, 1, 1, 0.1)))
	var foot := UIStyle.hbox(8)
	v.add_child(foot)
	var score_text := ("Score: %d / %d" % [Game.chapter_total(n), Game.chapter_max(n)]) if done else ("Best possible: %d points" % Game.chapter_max(n))
	if not open:
		score_text = "Finish Chapter %d to unlock" % (n - 1)
	var score := _tag(score_text, UIStyle.GOOD if done else UIStyle.MUTED, 15)
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(score)
	var play := UIStyle.button("Replay chapter" if done else ("Play chapter  ▶" if open else "Locked"), 18, edge.darkened(0.45))
	play.name = "Play"
	play.disabled = not open
	play.custom_minimum_size = Vector2(200, 46)
	play.pressed.connect(func() -> void: chapter_chosen.emit(n, ""))
	foot.add_child(play)
	return card


## "Text message  ·  Home  ·  Mon 07:30 PM": the attack, the place and the day and time of chapter n.
static func tag_line(n: int) -> String:
	var ch := Campaign.chapter(n)
	var parts: Array[String] = []
	var attack := str(ch.get("attack", ""))
	if attack != "":
		parts.append(attack)
	var place := str(ch.get("place", "office"))
	parts.append(str(PLACES.get(place, place.capitalize())))
	parts.append(TitleCard.time_of(n))
	return "  ·  ".join(parts)


## The chapter's opening line from Ms. Dela Vega, without the "Chapter N." prefix.
func _premise(ch: Dictionary) -> String:
	var lines: Array = ch.get("briefing", [])
	if lines.is_empty():
		return ""
	var text := str(lines[0].get("text", ""))
	var dot := text.find(". ")
	if text.begins_with("Chapter") and dot >= 0:
		text = text.substr(dot + 2)
	return text


## Done (with the badge initials, gold when flawless) or "Not played".
func _chip(n: int, done: bool, flawless: bool) -> Control:
	if done:
		var row := UIStyle.hbox(6)
		row.add_child(_tag("Done ✓", UIStyle.GOOD, 14))
		row.add_child(Achievements.badge_icon(n, true, flawless, 28))
		return row
	return _tag("Not played", UIStyle.MUTED, 14)


func _tag(text: String, color: Color, size: int) -> Label:
	var l := UIStyle.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## One subquest row: a flat button that starts the chapter at this message.
func _subquest(n: int, it: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Task_" + str(it.get("id", ""))
	b.text = "▸   " + str(it.get("task", ""))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Start Chapter %d at this task" % n
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(UIStyle.TEXT, 0.9))
	b.add_theme_color_override("font_hover_color", UIStyle.ACCENT)
	var hover := UIStyle.box(Color(UIStyle.ACCENT, 0.14), 6, 8)
	hover.content_margin_top = 2
	hover.content_margin_bottom = 2
	b.add_theme_stylebox_override("hover", hover)
	b.pressed.connect(func() -> void: chapter_chosen.emit(n, str(it.get("id", ""))))
	# Starting at a task is for review: in normal play the tasks are only listed.
	if not Settings.review_mode:
		b.disabled = true
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW
		b.tooltip_text = ""
		b.add_theme_color_override("font_disabled_color", Color(UIStyle.TEXT, 0.75 if _open(n) else 0.4))
	return b


func _open(n: int) -> bool:
	return Settings.chapter_unlocked(n, Game.completed)


func _on_reset() -> void:
	Game.start_new_game()
	refresh()
