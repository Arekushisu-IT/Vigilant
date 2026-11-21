class_name HUD
extends Control
## Always-visible heads-up display (Objective 7): "Score: N" that pulses green / orange / red on every change,
## "Chapter N of 10 — Title", one pip per chapter (done / current / upcoming), the chapter's task list
## ("Tasks D/T" with ticks, TASKS-SPEC A.7 / C.10), the objective line, the crosshair dot and the
## interaction prompt. It never takes mouse input.

const PIP_SIZE := 16
const PIP_RADIUS := 8
const MARGIN := 20
const FLOAT_RISE := 46.0      ## px the floating "+10" rises
const FLOAT_TIME := 1.3       ## s until it has faded out

var _score: Label
var _delta: Label
var _chapter: Label
var _pips: Array[Panel] = []
var _objective_box: PanelContainer
var _objective: Label
var _prompt_box: PanelContainer
var _prompt: Label
var _crosshair: Panel
var _pulse: Tween
var _tasks_box: PanelContainer
var _tasks_header: Label
var _task_lines: VBoxContainer
## Floating score labels draw on their own layer above the overlays (the Outcome card's dimmed backdrop).
var _fx_layer: CanvasLayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer = CanvasLayer.new()
	_fx_layer.name = "ScoreFx"
	_fx_layer.layer = 12
	add_child(_fx_layer)
	_build_top_bar()
	_build_objective()
	_build_crosshair()
	_build_prompt()
	DialoguePanel.ignore_mouse(self)
	Game.score_changed.connect(_on_score_changed)
	refresh()


func set_objective(text: String) -> void:
	_objective.text = text
	_objective_box.visible = text != ""


## Shows the player's interaction prompt; "[E] ..." is bright, a disabled device's hint is muted.
func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.add_theme_color_override("font_color", UIStyle.TEXT if text.begins_with("[E]") else UIStyle.MUTED)
	_prompt_box.visible = text != ""


## The chapter's task list under the pips: "Tasks D/T" and one line per listed task ("✓" done, "•" open).
## Hidden when `tasks` is empty (set_tasks([], 0) during briefings). `tasks` are ChapterSession.task_list() rows.
func set_tasks(tasks: Array[Dictionary], total: int) -> void:
	for child: Node in _task_lines.get_children():
		_task_lines.remove_child(child)
		child.queue_free()
	_tasks_box.visible = not tasks.is_empty()
	if tasks.is_empty():
		_tasks_header.text = ""
		return
	var done := 0
	for t: Dictionary in tasks:
		var is_done := bool(t.get("done", false))
		if is_done:
			done += 1
		var line := _line(("✓ " if is_done else "• ") + str(t.get("text", "")), 14,
				UIStyle.GOOD if is_done else UIStyle.TEXT)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_task_lines.add_child(line)
	# The header counts every task of the chapter; the ones not unlocked yet are summed up in one muted line.
	var later := total - tasks.size()
	if later > 0:
		var more := _line("+ %d more later" % later, 13, UIStyle.MUTED)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_task_lines.add_child(more)
	_tasks_header.text = "Tasks %d/%d" % [done, total]


func set_crosshair_visible(on: bool) -> void:
	_crosshair.visible = on


## Re-reads score, chapter and progress from Game.
func refresh() -> void:
	_score.text = "Score: %d" % Game.score
	var n: int = clampi(Game.current_chapter, 1, Game.CHAPTER_COUNT)
	_chapter.text = "Chapter %d of %d — %s" % [n, Game.CHAPTER_COUNT, str(Campaign.chapter(n).title)]
	for i: int in _pips.size():
		var done: bool = Game.completed[i]
		var current := (i + 1) == n and not done
		var sb: StyleBoxFlat
		if done:
			sb = UIStyle.box(UIStyle.GOOD, PIP_RADIUS, 0)
		elif current:
			sb = UIStyle.box(UIStyle.ACCENT, PIP_RADIUS, 0, Color.WHITE)
		else:
			sb = UIStyle.box(Color(UIStyle.PANEL_LIGHTER, 0.9), PIP_RADIUS, 0)
		_pips[i].add_theme_stylebox_override("panel", sb)


func _on_score_changed(_score_value: int, delta: int, reason: String) -> void:
	refresh()
	if delta == 0:
		return
	if delta < 0:
		Audio.play_sfx("score_down", -5.0)
	elif reason != "complete":      # the chapter fanfare covers the +20
		get_tree().create_timer(0.3).timeout.connect(Audio.play_sfx.bind("score_up", -5.0, 1.0))
	var color := UIStyle.outcome_color(reason)
	_delta.text = ("+%d" % delta) if delta > 0 else str(delta)
	_delta.add_theme_color_override("font_color", color)
	_score.add_theme_color_override("font_color", color)
	# Quick pulse: the score grows a little from its left edge and settles back.
	_score.pivot_offset = Vector2(0.0, _score.size.y * 0.5)
	if _pulse != null:
		_pulse.kill()
	_score.scale = Vector2.ONE
	_pulse = create_tween().set_parallel(true)
	_pulse.tween_property(_score, "scale", Vector2.ONE * 1.16, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(_score, "scale", Vector2.ONE, 0.32).set_delay(0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(_score, "theme_override_colors/font_color", UIStyle.TEXT, 0.9).set_delay(0.25)
	_float_delta(_delta.text, color)


## "+10" / "-5" / "+20" that rises from beside the score and fades (green / orange / red by outcome).
func _float_delta(text: String, color: Color) -> void:
	var f := _line(text, 24, color)
	f.name = "FloatingDelta"
	f.add_theme_font_override("font", DialoguePanel.bold_font())
	f.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	f.add_theme_constant_override("outline_size", 6)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(f)
	var from := _delta.global_position + Vector2(4.0, -2.0)
	f.position = from
	f.pivot_offset = Vector2(0.0, 14.0)
	f.scale = Vector2.ONE * 0.7
	var t := f.create_tween().set_parallel(true)
	t.tween_property(f, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(f, "position:y", from.y - FLOAT_RISE, FLOAT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(f, "modulate:a", 0.0, 0.45).set_delay(FLOAT_TIME - 0.45)
	t.chain().tween_callback(f.queue_free)


func _build_top_bar() -> void:
	var bar := UIStyle.hbox(12)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = MARGIN
	add_child(bar)

	# Top-left: score and chapter.
	var left := _hud_panel()
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_child(left)
	var lv := UIStyle.vbox(2)
	left.add_child(lv)
	var score_row := UIStyle.hbox(10)
	lv.add_child(score_row)
	_score = _line("Score: 0", 26, UIStyle.TEXT)
	_score.add_theme_font_override("font", DialoguePanel.bold_font())
	score_row.add_child(_score)
	_delta = _line("", 20, UIStyle.GOOD)
	_delta.add_theme_font_override("font", DialoguePanel.bold_font())
	_delta.custom_minimum_size = Vector2(46, 0)
	_delta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_delta.modulate.a = 0.0
	score_row.add_child(_delta)
	_chapter = _line("", 15, UIStyle.MUTED)
	lv.add_child(_chapter)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	# Top-right: chapter progress pips, and the task list under them.
	var right_column := UIStyle.vbox(8)
	right_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_child(right_column)
	var right := _hud_panel()
	right_column.add_child(right)
	var rv := UIStyle.vbox(8)
	right.add_child(rv)
	var caption := DialoguePanel.section("Chapters", UIStyle.MUTED, 12)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(caption)
	var pips := UIStyle.hbox(10)
	pips.alignment = BoxContainer.ALIGNMENT_END
	rv.add_child(pips)
	for i: int in Game.CHAPTER_COUNT:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
		pips.add_child(pip)
		_pips.append(pip)

	_tasks_box = _hud_panel()
	_tasks_box.name = "TaskPanel"
	right_column.add_child(_tasks_box)
	var tv := UIStyle.vbox(4)
	_tasks_box.add_child(tv)
	_tasks_header = _line("", 15, UIStyle.ACCENT)
	_tasks_header.add_theme_font_override("font", DialoguePanel.bold_font())
	tv.add_child(_tasks_header)
	_task_lines = UIStyle.vbox(3)
	tv.add_child(_task_lines)
	_tasks_box.visible = false


func _build_objective() -> void:
	var band := CenterContainer.new()
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_top = MARGIN
	band.offset_bottom = MARGIN + 48
	add_child(band)
	_objective_box = _hud_panel()
	band.add_child(_objective_box)
	var row := UIStyle.hbox(12)
	_objective_box.add_child(row)
	var tag := DialoguePanel.section("Objective", UIStyle.ACCENT, 12)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	_objective = _line("", 17, UIStyle.TEXT)
	row.add_child(_objective)
	_objective_box.visible = false


func _build_crosshair() -> void:
	_crosshair = Panel.new()
	_crosshair.add_theme_stylebox_override("panel", UIStyle.box(Color(1, 1, 1, 0.9), 4, 0, Color(0, 0, 0, 0.55)))
	_crosshair.anchor_left = 0.5
	_crosshair.anchor_right = 0.5
	_crosshair.anchor_top = 0.5
	_crosshair.anchor_bottom = 0.5
	_crosshair.offset_left = -4
	_crosshair.offset_right = 4
	_crosshair.offset_top = -4
	_crosshair.offset_bottom = 4
	add_child(_crosshair)


func _build_prompt() -> void:
	var band := CenterContainer.new()
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_top = 30
	band.offset_bottom = 80
	add_child(band)
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UIStyle.box(Color(0, 0, 0, 0.6), 6, 10))
	band.add_child(_prompt_box)
	_prompt = _line("", 17, UIStyle.TEXT)
	_prompt_box.add_child(_prompt)
	_prompt_box.visible = false


func _hud_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.PANEL, 0.78), 10, 12))
	return p


## Single-line label (no wrapping) so HUD panels size to their text.
func _line(text: String, size: int, color: Color) -> Label:
	var l := UIStyle.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l
