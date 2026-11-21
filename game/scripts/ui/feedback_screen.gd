class_name FeedbackScreen
extends Overlay
## Chapter debrief after a completed chapter (Objectives 6 and 7): "Chapter N complete: Title",
## Ms. Dela Vega's debrief (names Black Veil), the warning signs (FR9: the full list), the tip, and the
## per-task results matching the HUD task list (TASKS-SPEC C.11): one block per item with its role and
## Game.item_total, its log entries grouped by task label, the +20, and "Chapter score: X / max".
## Off the clock the debrief comes "by text" and the helper item is labelled with its helper_label (Family,
## Friend). A Fun Fact for the chapter (FunFacts.pick(n, "results")) sits under the Tip; it never scores.
## Continue, ESC or E continues.

signal continued

const CARD_WIDTH := 1160
const SCROLL_HEIGHT := 190
## Role names in the results. A "coworker" item off the clock names its helper_label ("Family", "Friend") instead.
const ROLE_LABELS := {"genuine": "Genuine", "fake": "Fake", "main": "Main attack", "coworker": "Coworker"}

var _title: Label
var _debrief: Label
var _signs_holder: VBoxContainer
var _tip: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _chapter_score: Label
var _totals: Label
var _continue: Button
var _select: Button
## True when the player pressed "Chapter Select" instead of Continue (read by the office after `continued`).
var chose_select: bool = false
var _rewards: VBoxContainer
var _who: Label
var _fact: FunFactCard


func _ready() -> void:
	add_child(UIStyle.backdrop(0.75))
	var center := UIStyle.center()
	add_child(center)

	var card := PanelContainer.new()
	var sb := UIStyle.box(UIStyle.PANEL, 14, 20, UIStyle.PANEL_LIGHTER)
	sb.border_color = UIStyle.GOOD
	sb.border_width_top = 6
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var root := UIStyle.vbox(10)
	card.add_child(root)
	root.add_child(DialoguePanel.section("Chapter complete", UIStyle.GOOD, 14))
	_title = UIStyle.label("", 30)
	_title.add_theme_font_override("font", DialoguePanel.bold_font())
	root.add_child(_title)
	root.add_child(DialoguePanel.rule())

	var body := UIStyle.hbox(28)
	root.add_child(body)

	# Left: debrief, warning signs, tip.
	var left := UIStyle.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	body.add_child(left)

	var speaker := UIStyle.hbox(16)
	left.add_child(speaker)
	var face := DialoguePanel.portrait("DV", 64)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	speaker.add_child(face)
	var said := UIStyle.vbox(4)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker.add_child(said)
	_who = UIStyle.label(Campaign.SECURITY + " · Security Office", 16, UIStyle.ACCENT)
	_who.add_theme_font_override("font", DialoguePanel.bold_font())
	said.add_child(_who)
	_debrief = UIStyle.label("", 16, UIStyle.TEXT)
	said.add_child(_debrief)

	left.add_child(DialoguePanel.section("Warning signs", UIStyle.WARN))
	_signs_holder = UIStyle.vbox(0)
	left.add_child(_signs_holder)
	left.add_child(DialoguePanel.section("Tip", UIStyle.ACCENT))
	var tip_box := PanelContainer.new()
	tip_box.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHT, 8, 14, Color(UIStyle.ACCENT, 0.6)))
	left.add_child(tip_box)
	_tip = UIStyle.label("", 15, UIStyle.TEXT)
	tip_box.add_child(_tip)
	# A Fun Fact for the chapter just finished (display only: no input, no sound, no score).
	_fact = FunFactCard.new(0.0, 14)
	left.add_child(_fact)

	# Right: this chapter's results per task.
	var right := UIStyle.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.9
	body.add_child(right)
	_rewards = UIStyle.vbox(6)
	_rewards.name = "Rewards"
	right.add_child(_rewards)
	right.add_child(DialoguePanel.section("Results per task"))
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHT, 8, 14))
	right.add_child(table)
	var tv := UIStyle.vbox(8)
	table.add_child(tv)
	# A fixed-height scroll: inside a CenterContainer an expand flag would give it no height.
	_scroll = ScrollContainer.new()
	_scroll.name = "Breakdown"
	_scroll.custom_minimum_size = Vector2(0, SCROLL_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tv.add_child(_scroll)
	_rows = UIStyle.vbox(6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	tv.add_child(DialoguePanel.rule(UIStyle.PANEL_LIGHTER))
	_chapter_score = UIStyle.label("", 20, UIStyle.TEXT)
	_chapter_score.add_theme_font_override("font", DialoguePanel.bold_font())
	tv.add_child(_chapter_score)
	_totals = UIStyle.label("", 15, UIStyle.MUTED)
	right.add_child(_totals)

	root.add_child(DialoguePanel.rule())
	var footer := UIStyle.hbox(12)
	root.add_child(footer)
	var keys := UIStyle.label("E / ESC", 14, UIStyle.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_OFF
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(keys)
	_continue = UIStyle.button("Continue", 18)
	DialoguePanel.tint_button(_continue, UIStyle.GOOD.darkened(0.45))
	_continue.custom_minimum_size = Vector2(180, 46)
	_continue.pressed.connect(_on_continue)
	_select = UIStyle.button("Chapter Select", 18)
	_select.custom_minimum_size = Vector2(190, 46)
	_select.pressed.connect(_on_select)
	footer.add_child(_select)
	footer.add_child(_continue)


## Fills the debrief from the chapter dictionary and this chapter's per-item score log, then shows it.
## `earned` lists the achievement ids unlocked by this chapter (Achievements.unlock_new()).
func show_feedback(chapter: Dictionary, earned: Array[String] = []) -> void:
	chose_select = false
	var n := int(chapter.get("id", Game.current_chapter))
	_title.text = "Chapter %d complete: %s" % [n, str(chapter.get("title", ""))]
	_fill_rewards(n, earned)
	_debrief.text = str(chapter.get("debrief", ""))
	for child: Node in _signs_holder.get_children():
		_signs_holder.remove_child(child)
		child.queue_free()
	_signs_holder.add_child(DialoguePanel.bullet_list(chapter.get("warning_signs", []), 15, UIStyle.WARN))
	_tip.text = str(chapter.get("tip", ""))
	var office := str(chapter.get("place", "office")) == "office"
	_who.text = Campaign.SECURITY + (" · Security Office" if office else " · by text")
	_fact.set_fact(FunFacts.pick(n, "results"))

	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	# Task labels come from ChapterSession only (the rule lives there); a fresh session needs no state.
	var labels := ChapterSession.new(chapter)
	for item: Dictionary in chapter.get("items", []):
		_add_item_block(n, item, labels)
	if Game.completed[clampi(n, 1, Game.CHAPTER_COUNT) - 1]:
		_rows.add_child(_score_row("Chapter (scenario) complete", Game.COMPLETE, "complete", true))
	_scroll.scroll_vertical = 0
	_chapter_score.text = "Chapter score: %s / %d" % [_signed(Game.chapter_total(n)), Game.chapter_max(n)]
	var done := Game.completed.count(true)
	_totals.text = "Total score: %d   ·   Chapters completed: %d of %d" % [Game.score, done, Game.CHAPTER_COUNT]
	show_overlay()
	Audio.play_sfx("chapter_complete", -1.0)
	Audio.duck_music(-9.0, 2.0)
	# The rewards land one after another, after the fanfare has hit.
	var badge_sound := "gold_badge" if Achievements.chapter_flawless(n) else "badge"
	get_tree().create_timer(0.95).timeout.connect(Audio.play_sfx.bind(badge_sound, -3.0, 1.0))
	for i: int in earned.size():
		get_tree().create_timer(1.6 + i * 0.4).timeout.connect(Audio.play_sfx.bind("achievement", -4.0, 1.0))


## The chapter badge (gold star when flawless) and any achievements this chapter unlocked.
func _fill_rewards(n: int, earned: Array[String]) -> void:
	for child: Node in _rewards.get_children():
		_rewards.remove_child(child)
		child.queue_free()
	var done: bool = Game.completed[clampi(n, 1, Game.CHAPTER_COUNT) - 1]
	var flawless := Achievements.chapter_flawless(n)
	var top := UIStyle.hbox(12)
	_rewards.add_child(top)
	top.add_child(Achievements.badge_icon(n, done, flawless, 48))
	var text := UIStyle.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text)
	var badge := Achievements.badge(n)
	var head := UIStyle.label("Badge: %s%s" % [badge.title, "  ★ Flawless" if flawless else ""], 17,
			UIStyle.WARN if flawless else UIStyle.ACCENT)
	head.add_theme_font_override("font", DialoguePanel.bold_font())
	text.add_child(head)
	text.add_child(UIStyle.label("Gold star: no wrong choices." if flawless else "No wrong choices earns the gold star.", 13, UIStyle.MUTED))
	if earned.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_rewards.add_child(flow)
	# Many at once (the last chapter can unlock seven): shorter, smaller pills so Continue stays on screen.
	var compact := earned.size() > 4
	for id: String in earned:
		var a := Achievements.info(id)
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.GOOD, 0.18), 16, 7 if compact else 10, UIStyle.GOOD))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var l := UIStyle.label(("★ " if compact else "Achievement: ") + str(a.get("title", id)), 13 if compact else 14, UIStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.tooltip_text = str(a.get("desc", ""))
		pill.add_child(l)
		flow.add_child(pill)


func _on_select() -> void:
	if not is_open():
		return
	chose_select = true
	hide_overlay()
	continued.emit()


func handle_back() -> void:
	_on_continue()


func handle_advance() -> void:
	_on_continue()


func _on_continue() -> void:
	if not is_open():
		return
	hide_overlay()
	continued.emit()


## One item: a header "task  ·  role" with its total, then its log entries grouped by task label
## ("✓ <task label>" sub-headers, the choices indented under them with their signed delta).
func _add_item_block(n: int, item: Dictionary, labels: ChapterSession) -> void:
	var id := str(item.get("id", ""))
	var role_key := str(item.get("role", ""))
	var role := str(ROLE_LABELS.get(role_key, ""))
	if role_key == "coworker":
		role = str(item.get("helper_label", "Coworker"))
	var title := str(item.get("task", id))
	if role != "":
		title += "  ·  " + role
	var total := Game.item_total(n, id)
	_rows.add_child(_score_row(title, total, "correct" if total >= 0 else "wrong", true))

	var groups: Array[String] = []
	var entries: Dictionary = {}           # task label -> Array of log entries, in log order
	for entry: Dictionary in Game.item_log(n, id):
		var task := labels.task_label_for_step(id, int(entry.get("step", 0)))
		if not entries.has(task):
			groups.append(task)
			entries[task] = []
		(entries[task] as Array).append(entry)

	var block := MarginContainer.new()
	block.add_theme_constant_override("margin_left", 12)
	_rows.add_child(block)
	var bv := UIStyle.vbox(3)
	block.add_child(bv)
	for task: String in groups:
		var sub := UIStyle.label("✓ " + task, 14, UIStyle.GOOD)
		bv.add_child(sub)
		for entry: Dictionary in entries[task]:
			var line := MarginContainer.new()
			line.add_theme_constant_override("margin_left", 18)
			line.add_child(_score_row(str(entry.get("choice", "")), int(entry.get("delta", 0)),
					str(entry.get("reason", "")), false))
			bv.add_child(line)
	_rows.add_child(DialoguePanel.rule(Color(UIStyle.PANEL_LIGHTER, 0.6)))


## One breakdown line: "text      +10" (bold for item headers and the completion bonus).
func _score_row(text: String, delta: int, reason: String, strong: bool = false) -> HBoxContainer:
	var row := UIStyle.hbox(12)
	var l := UIStyle.label(text, 16 if strong else 14, UIStyle.TEXT if strong else UIStyle.MUTED.lightened(0.25))
	if strong:
		l.add_theme_font_override("font", DialoguePanel.bold_font())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var d := UIStyle.mono_label(_signed(delta), 16 if strong else 14, UIStyle.outcome_color(reason))
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.custom_minimum_size = Vector2(48, 0)
	d.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(d)
	return row


func _signed(value: int) -> String:
	return ("+%d" % value) if value > 0 else str(value)
