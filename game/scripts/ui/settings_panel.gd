class_name SettingsPanel
extends PanelContainer
## Settings (Objective 2): mouse sensitivity, master / music / sound-effects volume and fullscreen.
## Every change is written through the Settings setters immediately (they apply and save).
## Used by the main menu and the pause menu. Back emits back_pressed; ESC is handled by the owner.

signal back_pressed

const WIDTH := 640

var _sensitivity: HSlider
var _sensitivity_value: Label
var _volume: HSlider
var _volume_value: Label
var _music: HSlider
var _music_value: Label
var _sfx: HSlider
var _sfx_value: Label
var _fullscreen: CheckButton
var _review: CheckButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 12, 28, UIStyle.PANEL_LIGHTER))
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root := UIStyle.vbox(18)
	add_child(root)
	root.add_child(UIStyle.label("Settings", 30))
	root.add_child(_rule())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 22)
	root.add_child(grid)

	_sensitivity = _slider(Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX)
	_sensitivity_value = _value_label()
	_row(grid, "Mouse sensitivity", _sensitivity, _sensitivity_value)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)

	_volume = _slider(0, 100)
	_volume.name = "MasterSlider"
	_volume_value = _value_label()
	_row(grid, "Master volume", _volume, _volume_value)
	_volume.value_changed.connect(_on_volume_changed)

	_music = _slider(0, 100)
	_music.name = "MusicSlider"
	_music_value = _value_label()
	_row(grid, "Music volume", _music, _music_value)
	_music.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v / 100.0))

	_sfx = _slider(0, 100)
	_sfx.name = "SfxSlider"
	_sfx_value = _value_label()
	_row(grid, "Sound effects", _sfx, _sfx_value)
	_sfx.value_changed.connect(func(v: float) -> void: Settings.set_sfx_volume(v / 100.0))
	# A short sample at the new level when the handle is let go.
	_sfx.drag_ended.connect(func(_changed: bool) -> void: Audio.play_sfx("notify_ping"))

	_fullscreen = CheckButton.new()
	_fullscreen.focus_mode = Control.FOCUS_NONE
	_fullscreen.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fullscreen.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fullscreen.add_theme_font_size_override("font_size", 16)
	_fullscreen.add_theme_color_override("font_color", UIStyle.MUTED)
	_fullscreen.add_theme_color_override("font_pressed_color", UIStyle.TEXT)
	_fullscreen.add_theme_color_override("font_hover_color", UIStyle.TEXT)
	_fullscreen.add_theme_color_override("font_hover_pressed_color", UIStyle.TEXT)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_row(grid, "Fullscreen", _fullscreen, Control.new())

	_review = CheckButton.new()
	_review.name = "ReviewMode"
	_review.focus_mode = Control.FOCUS_NONE
	_review.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_review.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_review.tooltip_text = "Unlock every chapter and let Chapter Select start at any task (for evaluators). Off each time the game starts."
	_review.add_theme_font_size_override("font_size", 16)
	_review.add_theme_color_override("font_color", UIStyle.MUTED)
	_review.add_theme_color_override("font_pressed_color", UIStyle.WARN)
	_review.add_theme_color_override("font_hover_color", UIStyle.TEXT)
	_review.add_theme_color_override("font_hover_pressed_color", UIStyle.WARN)
	_review.toggled.connect(func(on: bool) -> void:
		Settings.set_review_mode(on)
		_review.text = "On: all chapters unlocked" if on else "Off")
	_row(grid, "Review mode", _review, Control.new())

	root.add_child(_rule())

	var buttons := UIStyle.hbox(12)
	root.add_child(buttons)
	var reset := UIStyle.button("Reset to defaults", 18)
	reset.custom_minimum_size = Vector2(200, 46)
	reset.pressed.connect(func() -> void: Settings.reset_to_defaults())
	buttons.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var back := UIStyle.button("Back", 18)
	back.custom_minimum_size = Vector2(150, 46)
	back.pressed.connect(func() -> void: back_pressed.emit())
	buttons.add_child(back)

	# Stay in sync when another panel (or Reset) changes the settings.
	Settings.changed.connect(refresh)
	refresh()


## Shows the current Settings values without writing them back.
func refresh() -> void:
	_sensitivity.set_value_no_signal(Settings.sensitivity)
	_sensitivity_value.text = str(Settings.sensitivity)
	var percent := roundi(Settings.master_volume * 100.0)
	_volume.set_value_no_signal(percent)
	_volume_value.text = "%d %%" % percent
	_set_percent(_music, _music_value, Settings.music_volume)
	_set_percent(_sfx, _sfx_value, Settings.sfx_volume)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_fullscreen.text = "On" if Settings.fullscreen else "Off"
	_review.set_pressed_no_signal(Settings.review_mode)
	_review.text = "On: all chapters unlocked" if Settings.review_mode else "Off"


func _set_percent(slider: HSlider, value_label: Label, linear: float) -> void:
	var percent := roundi(linear * 100.0)
	slider.set_value_no_signal(percent)
	value_label.text = "%d %%" % percent


func _on_sensitivity_changed(value: float) -> void:
	Settings.set_sensitivity(roundi(value))


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)


func _on_fullscreen_toggled(on: bool) -> void:
	Settings.set_fullscreen(on)


func _row(grid: GridContainer, name_text: String, control: Control, value: Control) -> void:
	var l := UIStyle.label(name_text, 18)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(190, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(l)
	grid.add_child(control)
	grid.add_child(value)


## A mouse-only slider with whole-number steps and the accent fill.
func _slider(min_value: int, max_value: int) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = 1
	s.rounded = true
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(300, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	s.add_theme_stylebox_override("slider", UIStyle.box(UIStyle.PANEL_LIGHTER, 3, 3))
	s.add_theme_stylebox_override("grabber_area", UIStyle.box(UIStyle.ACCENT, 3, 3))
	s.add_theme_stylebox_override("grabber_area_highlight", UIStyle.box(UIStyle.ACCENT.lightened(0.15), 3, 3))
	return s


func _value_label() -> Label:
	var l := UIStyle.mono_label("", 18, UIStyle.ACCENT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(70, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = UIStyle.PANEL_LIGHTER
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
