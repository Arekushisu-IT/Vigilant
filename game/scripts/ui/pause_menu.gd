class_name PauseMenu
extends Overlay
## Pause menu opened with ESC while walking (Objective 2: Instructions and Settings are also reachable
## here). Resume, Progress (where you are: chapters, this chapter's tasks, score), Instructions, Settings, Chapter
## Select and Main Menu; the last two ask to confirm because the current chapter's progress is lost.
## ESC in a sub-panel or the confirm returns to the menu; ESC on the menu resumes.

signal resume_pressed
signal menu_pressed
signal select_pressed

const MENU_WIDTH := 420
const PROGRESS_HEIGHT := 430

var _page := "main"
var _main: PanelContainer
var _confirm: PanelContainer
var _instructions: InstructionsPanel
var _settings: SettingsPanel
var _yes: Button
var _no: Button
var _warn: Label
var _confirm_target := "menu"     ## "menu" or "select": where Yes leads
var _progress: PanelContainer
var _progress_body: VBoxContainer
var _progress_scroll: ScrollContainer


func _ready() -> void:
	add_child(UIStyle.backdrop(0.65))
	var center := UIStyle.center()
	add_child(center)

	_main = _card(MENU_WIDTH)
	center.add_child(_main)
	var v := UIStyle.vbox(12)
	_main.add_child(v)
	var heading := UIStyle.title("Paused", 32)
	heading.add_theme_font_override("font", DialoguePanel.bold_font())
	v.add_child(heading)
	var sub := UIStyle.title("Vigilant Protocol training", 15)
	sub.add_theme_color_override("font_color", UIStyle.MUTED)
	v.add_child(sub)
	v.add_child(DialoguePanel.rule())
	v.add_child(_menu_button("Resume", _resume, UIStyle.ACCENT.darkened(0.45)))
	v.add_child(_menu_button("Progress", _show_progress))
	v.add_child(_menu_button("Instructions", _show_page.bind("instructions")))
	v.add_child(_menu_button("Settings", _show_page.bind("settings")))
	v.add_child(_menu_button("Chapter Select", _ask.bind("select")))
	v.add_child(_menu_button("Main Menu", _ask.bind("menu")))

	_progress = _card(640)
	center.add_child(_progress)
	var pv := UIStyle.vbox(10)
	_progress.add_child(pv)
	var ph := UIStyle.title("Your progress", 28)
	ph.add_theme_font_override("font", DialoguePanel.bold_font())
	pv.add_child(ph)
	pv.add_child(DialoguePanel.rule())
	# Ten chapters plus this chapter's tasks: a fixed-height scroll keeps Back inside a 720p window.
	_progress_scroll = ScrollContainer.new()
	_progress_scroll.name = "ProgressScroll"
	_progress_scroll.custom_minimum_size = Vector2(0, PROGRESS_HEIGHT)
	_progress_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(_progress_scroll)
	_progress_body = UIStyle.vbox(8)
	_progress_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_scroll.add_child(_progress_body)
	pv.add_child(DialoguePanel.rule())
	pv.add_child(_menu_button("Back", _show_page.bind("main")))

	_instructions = InstructionsPanel.new()
	_instructions.back_pressed.connect(_show_page.bind("main"))
	center.add_child(_instructions)

	_settings = SettingsPanel.new()
	_settings.back_pressed.connect(_show_page.bind("main"))
	center.add_child(_settings)

	_confirm = _card(540)
	center.add_child(_confirm)
	var cv := UIStyle.vbox(14)
	_confirm.add_child(cv)
	var ask := UIStyle.title("Leave the training?", 28)
	ask.add_theme_font_override("font", DialoguePanel.bold_font())
	cv.add_child(ask)
	_warn = UIStyle.title("Your progress will be lost.", 18)
	_warn.add_theme_color_override("font_color", UIStyle.WARN)
	cv.add_child(_warn)
	var row := UIStyle.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(row)
	_yes = UIStyle.button("Yes, leave", 18)
	DialoguePanel.tint_button(_yes, UIStyle.DANGER.darkened(0.35))
	_yes.custom_minimum_size = Vector2(180, 48)
	_yes.pressed.connect(_on_yes)
	row.add_child(_yes)
	_no = UIStyle.button("No, stay", 18)
	_no.custom_minimum_size = Vector2(180, 48)
	_no.pressed.connect(_show_page.bind("main"))
	row.add_child(_no)

	_show_page("main")


## Shows the pause menu on its main page.
func open() -> void:
	_yes.disabled = false
	_no.disabled = false
	_show_page("main")
	show_overlay()


func handle_back() -> void:
	if _page != "main":
		_show_page("main")
	else:
		_resume()


func _show_page(page: String) -> void:
	_page = page
	_main.visible = page == "main"
	_instructions.visible = page == "instructions"
	_settings.visible = page == "settings"
	_confirm.visible = page == "confirm"
	_progress.visible = page == "progress"


func _resume() -> void:
	if not is_open():
		return
	hide_overlay()
	resume_pressed.emit()


func _on_yes() -> void:
	if _yes.disabled:
		return
	_yes.disabled = true
	_no.disabled = true
	if _confirm_target == "select":
		select_pressed.emit()
	else:
		menu_pressed.emit()


func _ask(target: String) -> void:
	_confirm_target = target
	_warn.text = "Progress in this chapter will be lost." if target == "select" else "Your progress will be lost."
	_show_page("confirm")


## Where the player is: every chapter (done / now / to do) with its score, then this chapter's tasks with the
## next one marked, the total score and the achievements so far. Read from the office's live session.
func _show_progress() -> void:
	for child: Node in _progress_body.get_children():
		_progress_body.remove_child(child)
		child.queue_free()
	var office := get_tree().current_scene
	var session: ChapterSession = office.get("session") if office != null else null
	for n: int in range(1, Game.CHAPTER_COUNT + 1):
		var ch := Campaign.chapter(n)
		var mark := "✓" if Game.completed[n - 1] else ("▶" if n == Game.current_chapter else "·")
		var color := UIStyle.GOOD if Game.completed[n - 1] else (UIStyle.ACCENT if n == Game.current_chapter else UIStyle.MUTED)
		var row := UIStyle.hbox(10)
		var name_l := UIStyle.label("%s  Chapter %d · %s" % [mark, n, str(ch.get("title", ""))], 16, color)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		if Game.completed[n - 1]:
			var pts := UIStyle.mono_label("%d / %d" % [Game.chapter_total(n), Game.chapter_max(n)], 14, UIStyle.GOOD)
			pts.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(pts)
		_progress_body.add_child(row)
	if session != null:
		var tasks := session.task_list()
		var done := tasks.filter(func(t: Dictionary) -> bool: return t.done).size()
		_progress_body.add_child(DialoguePanel.section("This chapter: tasks %d of %d" % [done, session.task_count()], UIStyle.ACCENT))
		var next_marked := false
		for t: Dictionary in tasks:
			var is_next: bool = not t.done and not next_marked
			next_marked = next_marked or is_next
			var line := ("✓  " if t.done else ("▶  " if is_next else "·  ")) + str(t.text) + ("   (next)" if is_next else "")
			_progress_body.add_child(UIStyle.label(line, 15, UIStyle.GOOD if t.done else (UIStyle.TEXT if is_next else UIStyle.MUTED)))
		var hidden := session.task_count() - tasks.size()
		if hidden > 0:
			_progress_body.add_child(UIStyle.label("+ %d more later in this chapter" % hidden, 14, UIStyle.MUTED))
	_progress_body.add_child(UIStyle.label("Score: %d   ·   Achievements: %d of %d" % [Game.score, Game.achievements.size(), Achievements.LIST.size()], 15, UIStyle.TEXT))
	_progress_scroll.scroll_vertical = 0
	_show_page("progress")


func _card(width: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 12, 28, UIStyle.PANEL_LIGHTER))
	p.custom_minimum_size = Vector2(width, 0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _menu_button(text: String, action: Callable, color: Color = UIStyle.PANEL_LIGHT) -> Button:
	var b := UIStyle.button(text, 19, color)
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(action)
	return b
