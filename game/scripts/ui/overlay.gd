class_name Overlay
extends Control
## Base class for every interface screen shown over the office (desktop, call, dialogue, notices, pause...).
## The office keeps a stack of open overlays: while any is open the mouse is free and the player cannot move.
## ESC (the "back" action) is sent only to the top overlay, through handle_back().

signal opened(overlay: Overlay)
signal closed(overlay: Overlay)


func _init() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return visible


func show_overlay() -> void:
	if visible:
		return
	visible = true
	opened.emit(self)


func hide_overlay() -> void:
	if not visible:
		return
	visible = false
	closed.emit(self)


## Called by the office when ESC is pressed and this overlay is on top. Override per screen.
func handle_back() -> void:
	pass


## Called by the office when "advance" (E) is pressed and this overlay is on top. Override if needed.
func handle_advance() -> void:
	pass
