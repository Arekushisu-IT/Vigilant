class_name InstructionsPanel
extends PanelContainer
## How to play (Objective 2): the paper's controls, the inspect-first loop at the office (workstation, desk phone)
## and off the clock (your phone at home and in the cafe), the trusted channels, the scoring rules and how to pass
## (wording from TASKS-SPEC C.13). Used by the main menu and the pause menu.
## Back emits back_pressed; ESC is handled by the owner.

signal back_pressed

const WIDTH := 1120


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 12, 20, UIStyle.PANEL_LIGHTER))
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root := UIStyle.vbox(10)
	add_child(root)

	var heading := UIStyle.label("Instructions", 28)
	root.add_child(heading)
	root.add_child(_rule())

	var columns := UIStyle.hbox(36)
	root.add_child(columns)

	var left := UIStyle.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	columns.add_child(left)
	_build_controls(left)
	_build_scoring(left)

	var right := UIStyle.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	columns.add_child(right)
	_build_how_to_play(right)
	_build_passing(left, right)

	root.add_child(_rule())

	var footer := UIStyle.hbox(12)
	root.add_child(footer)
	var note := UIStyle.label("This is an awareness game, not professional training.", 14, UIStyle.MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(note)
	var back := UIStyle.button("Back", 18)
	back.custom_minimum_size = Vector2(150, 46)
	back.pressed.connect(func() -> void: back_pressed.emit())
	footer.add_child(back)


## Controls from the paper: WASD move, mouse look, E interact, ESC exit screens / pause.
func _build_controls(parent: VBoxContainer) -> void:
	parent.add_child(_section("CONTROLS"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	_control_row(grid, "W A S D", "Move")
	_control_row(grid, "Mouse", "Look around; click buttons and responses")
	_control_row(grid, "E", "Use the workstation, the desk phone or your phone")
	_control_row(grid, "ESC", "Close the current screen / pause")


## The scoring rules come from the Game constants so the text can never disagree with the rules.
func _build_scoring(parent: VBoxContainer) -> void:
	parent.add_child(_section("SCORING"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	_score_row(grid, Game.CORRECT, "Correct response", UIStyle.outcome_color("correct"))
	_score_row(grid, Game.WRONG, "Wrong action", UIStyle.outcome_color("wrong"))
	_score_row(grid, Game.COMPLETE, "Chapter (scenario) complete", UIStyle.outcome_color("complete"))


func _build_how_to_play(parent: VBoxContainer) -> void:
	parent.add_child(_section("HOW TO PLAY"))
	_step(parent, 1, "At the office, walk to your workstation or desk phone and press E. At home and in the cafe, use your phone.")
	_step(parent, 2, "Each chapter has several tasks. Some messages and calls are real and some are attacks. The task list at the top right shows your progress.")
	_step(parent, 3, "Inspect before you decide. Click the sender to see the full address. Copy a link and Paste it in the Browser to read where it really goes. On a call, check the caller ID. In a chat, open the profile. Preview a QR code's link. In KwartaPay, check History and the Inbox.")
	_step(parent, 4, "The responses unlock once you have checked everything. Handle real messages normally: reporting or deleting a real one is a wrong action.")
	_step(parent, 5, "Verify through a channel you already trust. At work: the Staff Directory, the official SwiftParcel site, the intranet or a known desk-phone extension. Off the clock: the hotline on the back of your card (8700), KwartaPay's hotline 2299 or its Report a scam button, and the anti-scam hotline 1326.")
	_step(parent, 6, "When you report an attack, tick exactly the warning signs you found. Coworkers, family and friends may ask for your advice too. Later chapters give fewer hints.")


## The breach warning under the scoring rules, the pass goal under the steps.
func _build_passing(alert_parent: VBoxContainer, goal_parent: VBoxContainer) -> void:
	var alert := PanelContainer.new()
	alert.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.DANGER, 0.12), 8, 14, Color(UIStyle.DANGER, 0.55)))
	var alert_text := UIStyle.label("An unsafe choice is a breach: game over. You can then restart the chapter.", 15, UIStyle.TEXT)
	alert.add_child(alert_text)
	alert_parent.add_child(alert)

	var goal := PanelContainer.new()
	goal.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.GOOD, 0.12), 8, 14, Color(UIStyle.GOOD, 0.55)))
	var goal_text := UIStyle.label("Finish every task in all %d chapters safely to pass the Vigilant Protocol." % Game.CHAPTER_COUNT, 15, UIStyle.TEXT)
	goal.add_child(goal_text)
	goal_parent.add_child(goal)


func _section(text: String) -> Label:
	var l := UIStyle.label(text, 14, UIStyle.ACCENT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = UIStyle.PANEL_LIGHTER
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A key "chip" (monospace on a lighter box) followed by what the key does.
func _control_row(grid: GridContainer, key: String, action: String) -> void:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHTER, 5, 6))
	chip.custom_minimum_size = Vector2(96, 0)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key_label := UIStyle.mono_label(key, 15)
	key_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(key_label)
	grid.add_child(chip)

	var text := UIStyle.label(action, 16)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(text)


func _score_row(grid: GridContainer, points: int, text: String, color: Color) -> void:
	var value := UIStyle.mono_label("%+d" % points, 18, color)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.custom_minimum_size = Vector2(96, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(value)
	var label := UIStyle.label(text, 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)


## A numbered step: an accent number badge and wrapped text.
func _step(parent: VBoxContainer, n: int, text: String) -> void:
	var row := UIStyle.hbox(12)
	parent.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.ACCENT, 0.2), 14, 0, Color(UIStyle.ACCENT, 0.7)))
	badge.custom_minimum_size = Vector2(28, 28)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var num := UIStyle.label(str(n), 14, UIStyle.ACCENT)
	num.autowrap_mode = TextServer.AUTOWRAP_OFF
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)
	row.add_child(badge)
	var body := UIStyle.label(text, 15)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
