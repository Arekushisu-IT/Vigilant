extends Control
## Good ending (Objective 7): Dela Vega's closing lines, the final score out of Game.max_score() (computed
## from the data, TASKS-SPEC C.12), chapters and tasks completed, and the per-chapter breakdown with one line
## per task item. Main Menu and Exit.
## Shown with whatever Game data exists, even if reached without finishing (e.g. run directly).

const BREAKDOWN_HEIGHT := 92
const BADGE_COLUMNS := 5
const BADGE_SIZE := 38

var _buttons: Array[Button] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UIStyle.full_rect(self)
	Achievements.unlock_new()   # judges the end-of-game achievements
	Audio.set_music("day")
	Audio.play_sfx("victory", -1.0)
	Audio.duck_music(-12.0, 3.5)
	_build_background()

	var center := UIStyle.center()
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 14, 16, Color(UIStyle.GOOD, 0.45)))
	card.custom_minimum_size = Vector2(1100, 0)
	center.add_child(card)

	var root := UIStyle.vbox(8)
	card.add_child(root)

	var eyebrow := UIStyle.title("AEGIS SOLUTIONS · VIGILANT PROTOCOL", 14)
	eyebrow.add_theme_color_override("font_color", UIStyle.GOOD)
	root.add_child(eyebrow)
	root.add_child(UIStyle.title("You passed the Vigilant Protocol", 30))

	root.add_child(_build_closing_lines())
	root.add_child(_build_stats())
	root.add_child(_build_rewards())
	root.add_child(_build_breakdown())

	var buttons := UIStyle.hbox(14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(buttons)
	_add_button(buttons, "Main Menu", UIStyle.ACCENT.darkened(0.4), _on_main_menu)
	_add_button(buttons, "Exit", UIStyle.PANEL_LIGHT, _on_exit)

	card.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.6).set_delay(0.15)
	t.tween_callback(Audio.play_sfx.bind("gold_badge", -4.0, 1.0)).set_delay(1.6)


## Ms. Dela Vega's portrait (initials) beside Campaign.GOOD_ENDING.
func _build_closing_lines() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHT, 10, 12))
	var row := UIStyle.hbox(18)
	box.add_child(row)

	var portrait := PanelContainer.new()
	portrait.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.ACCENT.darkened(0.35), 10, 0))
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var initials := UIStyle.label("DV", 26)
	initials.autowrap_mode = TextServer.AUTOWRAP_OFF
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(initials)
	row.add_child(portrait)

	var text := UIStyle.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UIStyle.label("%s — Security" % Campaign.SECURITY, 15, UIStyle.ACCENT))
	for line: String in Campaign.GOOD_ENDING:
		text.add_child(UIStyle.label(line, 15))
	return box


## Two tiles: the final score out of Game.max_score(), and progress (chapters and tasks completed).
func _build_stats() -> Control:
	var row := UIStyle.hbox(14)
	row.add_child(_stat_tile("Final score", "%d / %d" % [Game.score, Game.max_score()]))

	var chapters_done := 0
	var tasks_total := 0
	var tasks_done := 0
	for n: int in range(1, Game.CHAPTER_COUNT + 1):
		# The task rule lives only in ChapterSession; a chapter is complete only when all its tasks are done.
		var count := ChapterSession.new(Campaign.chapter(n)).task_count()
		tasks_total += count
		if Game.completed[n - 1]:
			chapters_done += 1
			tasks_done += count

	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, 10, 12, UIStyle.PANEL_LIGHTER))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIStyle.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(v)
	v.add_child(_progress_line("Chapters completed: %d of %d" % [chapters_done, Game.CHAPTER_COUNT]))
	v.add_child(_progress_line("Tasks completed: %d of %d" % [tasks_done, tasks_total]))
	row.add_child(tile)
	return row


## The chapter badges (gold when flawless) in a grid of BADGE_COLUMNS, so ten badges keep the card compact, and
## every achievement, earned or still locked.
func _build_rewards() -> Control:
	var box := UIStyle.vbox(6)
	box.name = "Rewards"
	var header := UIStyle.label("BADGES AND ACHIEVEMENTS  ·  %d of %d achievements" % [Game.achievements.size(), Achievements.LIST.size()], 14, UIStyle.MUTED)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(header)
	var row := UIStyle.hbox(14)
	box.add_child(row)
	var badges := GridContainer.new()
	badges.name = "Badges"
	badges.columns = BADGE_COLUMNS
	badges.add_theme_constant_override("h_separation", 6)
	badges.add_theme_constant_override("v_separation", 6)
	badges.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badges)
	for n: int in range(1, Game.CHAPTER_COUNT + 1):
		badges.add_child(Achievements.badge_icon(n, Game.completed[n - 1], Achievements.chapter_flawless(n), BADGE_SIZE))
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	row.add_child(flow)
	for a: Dictionary in Achievements.LIST:
		var got := Game.achievements.has(a.id)
		var pill := PanelContainer.new()
		var c := UIStyle.GOOD if got else UIStyle.PANEL_LIGHTER
		pill.add_theme_stylebox_override("panel", UIStyle.box(Color(c, 0.18 if got else 0.35), 14, 8, c))
		var l := UIStyle.label(("✓ " if got else "") + str(a.title), 13, UIStyle.TEXT if got else UIStyle.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill.tooltip_text = str(a.desc)
		pill.add_child(l)
		flow.add_child(pill)
	return box


func _progress_line(text: String) -> Label:
	var l := UIStyle.mono_label(text, 19, UIStyle.GOOD)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## One block per chapter (title, completion, total / max) with one compact line per task item,
## inside a fixed-height scroll (an expand flag inside a CenterContainer would give it no height).
func _build_breakdown() -> Control:
	var table := UIStyle.vbox(4)
	var header := UIStyle.label("SCORE BY CHAPTER", 14, UIStyle.MUTED)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	table.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.name = "Breakdown"
	scroll.custom_minimum_size = Vector2(0, BREAKDOWN_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table.add_child(scroll)
	var rows := UIStyle.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for n: int in range(1, Game.CHAPTER_COUNT + 1):
		rows.add_child(_chapter_row(n))
	return table


func _chapter_row(n: int) -> Control:
	var tint := UIStyle.PANEL_LIGHT if n % 2 == 1 else UIStyle.PANEL_LIGHT.darkened(0.12)
	var row_box := PanelContainer.new()
	row_box.add_theme_stylebox_override("panel", UIStyle.box(tint, 6, 8))
	var block := UIStyle.vbox(4)
	row_box.add_child(block)
	var row := UIStyle.hbox(16)
	block.add_child(row)

	var number := UIStyle.mono_label("Chapter %d" % n, 16, UIStyle.MUTED)
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.custom_minimum_size = Vector2(110, 0)
	row.add_child(number)

	var title := UIStyle.label(String(Campaign.chapter(n).get("title", "")), 18)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var is_done: bool = Game.completed[n - 1]
	var status := UIStyle.label("Complete" if is_done else "Not completed", 15,
			UIStyle.GOOD if is_done else UIStyle.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.custom_minimum_size = Vector2(130, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status)

	var total := Game.chapter_total(n)
	var points := UIStyle.mono_label("%d / %d" % [total, Game.chapter_max(n)], 18,
			UIStyle.WARN if total < 0 else UIStyle.TEXT)
	points.autowrap_mode = TextServer.AUTOWRAP_OFF
	points.custom_minimum_size = Vector2(110, 0)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(points)

	# One compact line per item: "<mark> <task> (<N> tasks)  <signed item total>" (a tick once the chapter is
	# complete). The sub-task count makes the "Tasks completed" tile traceable: the lines add up to it.
	for item: Dictionary in Campaign.chapter(n).get("items", []):
		var line := UIStyle.hbox(12)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(110, 0)
		line.add_child(pad)
		var mark := "✓ " if is_done else "• "
		var sub_tasks := _sub_task_count(item)
		var label := mark + str(item.get("task", ""))
		if sub_tasks > 1:
			label += "  (%d tasks)" % sub_tasks
		var task := UIStyle.label(label, 14, UIStyle.GOOD if is_done else UIStyle.MUTED)
		task.autowrap_mode = TextServer.AUTOWRAP_OFF
		task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(task)
		var item_total := Game.item_total(n, str(item.get("id", "")))
		var value := UIStyle.mono_label(_signed(item_total), 14, UIStyle.WARN if item_total < 0 else UIStyle.MUTED)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.custom_minimum_size = Vector2(110, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		block.add_child(line)
	return row_box


## HUD tasks of one item: its steps that carry a "task" label, at least 1 (the same rule as ChapterSession).
func _sub_task_count(item: Dictionary) -> int:
	var n := 0
	for st: Dictionary in item.get("steps", []):
		if st.has("task"):
			n += 1
	return maxi(1, n)


func _signed(value: int) -> String:
	return ("+%d" % value) if value > 0 else str(value)


func _stat_tile(caption: String, value: String) -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, 10, 12, UIStyle.PANEL_LIGHTER))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIStyle.vbox(2)
	tile.add_child(v)
	var caption_label := UIStyle.title(caption.to_upper(), 13)
	caption_label.add_theme_color_override("font_color", UIStyle.MUTED)
	v.add_child(caption_label)
	var value_label := UIStyle.mono_label(value, 28, UIStyle.GOOD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(value_label)
	return tile


func _add_button(parent: HBoxContainer, text: String, color: Color, handler: Callable) -> void:
	var b := UIStyle.button(text, 20, color)
	b.custom_minimum_size = Vector2(220, 52)
	b.pressed.connect(handler)
	parent.add_child(b)
	_buttons.append(b)


## Same dark office background as the main menu, with a green glow for the pass.
func _build_background() -> void:
	var base := ColorRect.new()
	base.color = UIStyle.BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(base)
	add_child(base)

	var g := Gradient.new()
	g.set_color(0, Color(UIStyle.GOOD, 0.16))
	g.set_color(1, Color(UIStyle.GOOD, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.3)
	tex.fill_to = Vector2(1.05, 0.3)
	tex.width = 256
	tex.height = 256
	var glow := TextureRect.new()
	glow.texture = tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(glow)
	add_child(glow)


func _set_buttons_enabled(on: bool) -> void:
	for b: Button in _buttons:
		b.disabled = not on


func _on_main_menu() -> void:
	_set_buttons_enabled(false)
	Router.go_to(Router.MAIN_MENU)


func _on_exit() -> void:
	_set_buttons_enabled(false)
	Router.quit()
