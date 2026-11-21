extends Node
## Player preferences (mouse sensitivity, master / music / sound-effects volume, display mode) and the input map.
## Preferences are saved to user://settings.cfg. Game progress is never saved (paper Limitation 6).

signal changed

const PATH := "user://settings.cfg"
const SENSITIVITY_MIN := 1
const SENSITIVITY_MAX := 10
const DEFAULT_MASTER := 0.8
const DEFAULT_MUSIC := 0.5
const DEFAULT_SFX := 0.8

var sensitivity: int = 5          ## 1..10, the player turns it into radians per pixel
var master_volume: float = DEFAULT_MASTER    ## 0..1 linear
var music_volume: float = DEFAULT_MUSIC    ## 0..1 linear, Music bus (the music is mixed low on top of this)
var sfx_volume: float = DEFAULT_SFX      ## 0..1 linear, SFX bus (effects and office ambience)
var fullscreen: bool = false
## Review mode: every chapter is open and Chapter Select can start at any task (for evaluators and the panel).
## Never saved: it is off each time the game starts, so respondents always get the chapters in order.
var review_mode: bool = false


func _enter_tree() -> void:
	_register_inputs()
	load_settings()
	apply()


## Radians of camera turn per pixel of mouse motion.
func mouse_radians_per_pixel() -> float:
	return 0.0005 * float(sensitivity)


func set_sensitivity(value: int) -> void:
	sensitivity = clampi(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	_commit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_commit()


func set_review_mode(on: bool) -> void:
	review_mode = on
	changed.emit()       # not saved on purpose (see review_mode)


## Chapter n can be played: Chapter 1 always, the next one after the one before it is finished this run, any of
## them in Review mode.
func chapter_unlocked(n: int, completed: Array[bool]) -> bool:
	return review_mode or n <= 1 or completed[n - 2]


func reset_to_defaults() -> void:
	sensitivity = 5
	master_volume = DEFAULT_MASTER
	music_volume = DEFAULT_MUSIC
	sfx_volume = DEFAULT_SFX
	fullscreen = false
	review_mode = false
	_commit()


func apply() -> void:
	apply_audio()
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


## Master, Music and SFX bus volumes. The Music and SFX buses are created by the Audio autoload, which calls this
## again once they exist.
func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sensitivity = clampi(int(cfg.get_value("controls", "sensitivity", sensitivity)), SENSITIVITY_MIN, SENSITIVITY_MAX)
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "sensitivity", sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)


func _commit() -> void:
	apply()
	save_settings()
	changed.emit()


## Controls from the paper: WASD move, mouse look, E interact, ESC exit interface screens.
## "advance" (E) moves dialogue and notices forward. No other keys: the paper lists only these.
func _register_inputs() -> void:
	_add_keys("move_forward", [KEY_W])
	_add_keys("move_back", [KEY_S])
	_add_keys("move_left", [KEY_A])
	_add_keys("move_right", [KEY_D])
	_add_keys("interact", [KEY_E])
	_add_keys("back", [KEY_ESCAPE])
	_add_keys("advance", [KEY_E])


func _add_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key as Key
		InputMap.action_add_event(action, ev)
