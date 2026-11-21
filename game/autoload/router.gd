extends CanvasLayer
## Scene changes with a short fade to black.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const OFFICE := "res://scenes/office.tscn"
const ENDING := "res://scenes/ending.tscn"
const FADE_TIME := 0.35

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func is_busy() -> bool:
	return _busy


func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await out.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Scene change failed (%s): %s" % [err, path])
		get_tree().change_scene_to_file(MAIN_MENU)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Fades to black without changing the scene (awaitable), e.g. while the office scene moves to another place
## between two chapters. Input stays blocked (is_busy()) until fade_in().
func fade_out(time: float = FADE_TIME) -> void:
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_fade, "modulate:a", 1.0, time)
	await out.finished


## Fades back in after fade_out() (awaitable) and releases the input.
func fade_in(time: float = FADE_TIME) -> void:
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "modulate:a", 0.0, time)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func quit() -> void:
	get_tree().quit()
