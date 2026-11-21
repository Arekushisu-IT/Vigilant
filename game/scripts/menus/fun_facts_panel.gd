class_name FunFactsPanel
extends PanelContainer
## The Fun Facts page of the main menu: every FunFacts entry with its source, grouped under "General" and then
## the chapter titles in chapter order (a fact is listed under its first tag). The list scrolls inside a fixed
## height, so the Back button always stays inside the window. Pure reading: nothing here scores or plays a sound
## (apart from the shared button click). Back emits back_pressed; ESC is handled by the owner.

signal back_pressed

const WIDTH := 940
const LIST_HEIGHT := 470

var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 12, 20, UIStyle.PANEL_LIGHTER))
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root := UIStyle.vbox(10)
	add_child(root)
	var heading := UIStyle.label("Fun Facts", 28)
	heading.add_theme_font_override("font", DialoguePanel.bold_font())
	root.add_child(heading)
	root.add_child(UIStyle.label("Real facts about scams in the Philippines. Each one names its source.", 15, UIStyle.MUTED))
	root.add_child(DialoguePanel.rule())

	_scroll = ScrollContainer.new()
	_scroll.name = "FactList"
	_scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_list = UIStyle.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_fill()

	root.add_child(DialoguePanel.rule())
	var footer := UIStyle.hbox(12)
	root.add_child(footer)
	var note := UIStyle.label("Facts marked (reported) come from a secondary report.", 14, UIStyle.MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(note)
	var back := UIStyle.button("Back", 18)
	back.name = "Back"
	back.custom_minimum_size = Vector2(150, 46)
	back.pressed.connect(func() -> void: back_pressed.emit())
	footer.add_child(back)


## Scrolls back to the top (called when the page opens).
func refresh() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = 0


## The groups in order ("General", then each chapter title) with their facts.
func _fill() -> void:
	var groups: Array[String] = ["general"]
	var titles := {"general": "General"}
	for ch: Dictionary in Campaign.CHAPTERS:
		var key := str(ch.get("key", ""))
		if key != "" and not titles.has(key):
			groups.append(key)
			titles[key] = "Chapter %d · %s" % [int(ch.get("id", 0)), str(ch.get("title", ""))]
	var by_group: Dictionary = {}
	for f: Dictionary in FunFacts.all():
		var tags: Array = f.get("chapters", [])
		var group := str(tags[0]) if not tags.is_empty() else "general"
		if not titles.has(group):
			group = "general"
		if not by_group.has(group):
			by_group[group] = []
		(by_group[group] as Array).append(f)
	for g: String in groups:
		if not by_group.has(g):
			continue
		var head := DialoguePanel.section(str(titles[g]), UIStyle.ACCENT, 13)
		head.name = "Group_" + g
		_list.add_child(head)
		for f: Dictionary in by_group[g]:
			_list.add_child(_row(f))


## One fact: its text, then the source in small muted text.
func _row(f: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Fact_" + str(f.get("id", ""))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := UIStyle.box(UIStyle.PANEL_LIGHT, 8, 12)
	sb.border_width_left = 4
	sb.border_color = Color(UIStyle.WARN, 0.7)
	row.add_theme_stylebox_override("panel", sb)
	var v := UIStyle.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(v)
	v.add_child(UIStyle.label(FunFacts.display_text(f), 16, UIStyle.TEXT))
	v.add_child(UIStyle.label(FunFacts.source_line(f), 12, UIStyle.MUTED))
	return row
