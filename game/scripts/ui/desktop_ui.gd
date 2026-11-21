class_name DesktopUI
extends Overlay
## Simulated office desktop (Objective 3) and the inspection mechanic (Objective 5).
## Four apps only: Mail, Messages, Chat (Kumusta Chat, Ch5) and Browser. Mail, Messages and Chat list every
## available item of the chapter (TASKS-SPEC.md C.7); the player selects one, reveals the real sender (a chat
## account's profile, a coworker's forwarded details, a chat request), copies a link with "Copy link address" and
## pastes it in the Browser to read the full address, or previews a QR code's link (Ch6). Pasting or previewing
## never opens a website. The DecisionBar at the bottom follows the ChapterSession gate of the selected item exactly,
## and shows a tick-box report (ChecklistView) on checklist steps.
## Device seams (_apps, _message_apps, _app_name/_glyph/_color, _thread_title/_subtitle, _bookmarks, _default_clock,
## _ui_text, _checklist_columns/_scroll, _mail_pane, _thread_pane, _rebuild_hosts, _bookmark_pressed, _sender_name)
## return the office values here; PhoneUI (the player's phone off the clock) overrides them.

signal inspected(key: String)
signal choice_selected(index: int)
signal close_requested
signal item_selected(item_id: String)
signal checklist_submitted(ticked: Array[int])

const ChecklistView := preload("res://scripts/ui/checklist_view.gd")
const QRCode := preload("res://scripts/ui/qr_code.gd")

const APPS: Array[String] = ["mail", "messages", "chat", "browser"]
const MESSAGE_APPS: Array[String] = ["mail", "messages", "chat"]
const APP_NAMES := {"mail": "Mail", "messages": "Messages", "chat": "Chat", "browser": "Browser"}
const APP_GLYPHS := {"mail": "@", "messages": "SMS", "chat": "KC", "browser": "WWW"}
const APP_COLORS := {"mail": Color("2f7fb5"), "messages": Color("3d9a5f"), "chat": Color("c06a32"), "browser": Color("7a5cc2")}
const CHAT_APP_NAME := "Kumusta Chat"
const USER_ADDR := "you@aegis-solutions.example"
const DEFAULT_CLOCK := "08:00"
const LINK_COLOR := Color("7cc8ee")
const COPY_LINK_ID := 0
const PASTED_LINE := "This is the full link address. The website was not opened."
const EMPTY_CLIPBOARD := "Nothing to paste. Copy a link first."
const BOOKMARKS := [["courier", "SwiftParcel (official)"], ["directory", "Aegis Staff Directory"],
	["facilities", "Aegis Facilities (intranet)"]]
const QUOTE_BUTTON_TEXT := "Show forwarded details"
const PROFILE_BUTTON_TIP := "Open the account's profile"
const REQUEST_BUTTON_TEXT := "Check the request"
const QR_BUTTON_TEXT := "Preview QR link"
const QR_PREVIEW_LINE := "This is the QR code's link address. The website was not opened."
const QR_SIZE := 150.0
const CHECKLIST_DEFAULT_HINT := "Tick every warning sign you found, then submit."
const ROW_HEIGHT := 56
const TOAST_LEFT := 250.0
const LIST_WIDTH := 330
const CHECKLIST_SCROLL := 184.0      ## option area of the DecisionBar checklist (leaves room for the evidence)
## Every string the DecisionBar and the top bar show about the workstation and the desk phone (see _ui_text).
const UI_TEXT := {
	"select_none": "Select a message to work on.",
	"select_another": "Select another message.",
	"phone_ringing": "Your desk phone is ringing. Leave the desk (Esc).",
	"done_all": "All messages handled. Leave the desk (Esc).",
	"wait": "Leave the desk (Esc) to use your desk phone.",
	"phone": "Leave the desk (Esc) to use your desk phone.",
	"phone_use": "Leave the desk (Esc) to use your desk phone.",
	"user_addr": USER_ADDR,
}

var session: ChapterSession

var _app: String = "mail"
var _locked: bool = false            ## choices locked while an outcome is showing
var _pending_link: String = ""       ## link id waiting for "Copy link address"
var _hover_link: String = ""         ## link id under the mouse (for right-click)
var _browser_notice: String = ""     ## e.g. the empty-clipboard notice

# Render state of the message apps (only the selected item is rendered in a reading pane).
var _built_sig: String = ""          ## selection + available/status signature of the last rebuild
var _rebuild_queued: bool = false
var _rendered_item: String = ""
var _sender_open: bool = false       ## local reveal toggle of the rendered item's sender
var _sender_was_inspected: bool = false
var _quote_open: bool = false        ## local reveal toggle of the rendered item's forwarded details
var _quote_was_inspected: bool = false
var _request_open: bool = false      ## local reveal toggle of a chat item's request details
var _request_was_inspected: bool = false
var _qr_open: Dictionary = {}        ## qr id -> local reveal toggle of its link preview
var _qr_was_inspected: Dictionary = {}
var _known_ids: Dictionary = {}      ## item ids already announced (new-message toast)
var _decision_sig: String = ""       ## what the DecisionBar controls were last built for

var _bold_mono: SystemFont
var _link_re: RegEx
var _tag_re: RegEx

# Layout nodes
var _message_body: RichTextLabel     ## the rendered message's body (for the tutorial ring)
var _paste_button: Button
var _app_buttons: Dictionary = {}    ## app -> Button
var _badges: Dictionary = {}         ## app -> PanelContainer (its child 0 is the count Label)
var _views: Dictionary = {}          ## app -> Control
var _mail_host: MarginContainer
var _messages_host: MarginContainer
var _chat_host: MarginContainer
var _sender_buttons: Array[Button] = []
var _sender_details: Array[Control] = []
var _quote_buttons: Array[Button] = []
var _quote_details: Array[Control] = []
var _request_buttons: Array[Button] = []
var _request_details: Array[Control] = []
var _qr_buttons: Dictionary = {}     ## qr id -> Button
var _qr_details: Dictionary = {}     ## qr id -> Control
var _tasks_label: Label
var _clock_label: Label

# Browser nodes
var _address: RichTextLabel
var _browser_info: Label
var _page_box: VBoxContainer

# DecisionBar nodes
var _question: Label
var _choice_flow: HFlowContainer
var _checklist_host: VBoxContainer
var _checklist: ChecklistView
var _hint: Label
var _choice_buttons: Array[Button] = []

# Feedback nodes
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _link_menu: PopupMenu


func _ready() -> void:
	_setup_text_tools()

	var bg := ColorRect.new()
	bg.color = Color("05070a")
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.full_rect(bg)
	add_child(bg)

	# The monitor screen: a rounded panel inside a thin dark bezel.
	var bezel := MarginContainer.new()
	UIStyle.full_rect(bezel)
	for side: String in ["left", "right", "top", "bottom"]:
		bezel.add_theme_constant_override("margin_" + side, 12)
	add_child(bezel)
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, 10, 0, UIStyle.PANEL_LIGHTER))
	bezel.add_child(screen)

	var column := UIStyle.vbox(0)
	screen.add_child(column)
	column.add_child(_build_top_bar())
	var body := UIStyle.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_rail())

	var app_area := MarginContainer.new()
	app_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		app_area.add_theme_constant_override("margin_" + side, 14)
	body.add_child(app_area)
	_mail_host = MarginContainer.new()
	_messages_host = MarginContainer.new()
	_chat_host = MarginContainer.new()
	_views = {"mail": _mail_host, "messages": _messages_host, "chat": _chat_host, "browser": _build_browser()}
	for app: String in _apps():
		app_area.add_child(_views[app])

	column.add_child(_build_decision_bar())
	_build_toast()
	_build_link_menu()


## The bold monospace font and the BBCode regexes used by the renderers (subclasses call this in their _ready).
func _setup_text_tools() -> void:
	_bold_mono = SystemFont.new()
	_bold_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	_bold_mono.font_weight = 700
	_link_re = RegEx.create_from_string("\\[url=([^\\]]+)\\](.*?)\\[/url\\]")
	_tag_re = RegEx.create_from_string("\\[/?[a-z]+[^\\]]*\\]")


# --- Device seams (the office values; PhoneUI overrides them) ---

## The apps of the device, in rail order.
func _apps() -> Array[String]:
	return APPS


## The apps that list items (Mail, Messages, Chat).
func _message_apps() -> Array[String]:
	return MESSAGE_APPS


func _app_name(app: String) -> String:
	return str(APP_NAMES.get(app, app.capitalize()))


func _app_glyph(app: String) -> String:
	return str(APP_GLYPHS.get(app, app.substr(0, 1).to_upper()))


func _app_color(app: String) -> Color:
	return APP_COLORS.get(app, UIStyle.ACCENT)


## The title of a thread app's list and empty view.
func _thread_title(app: String) -> String:
	return CHAT_APP_NAME if app == "chat" else "Messages"


func _thread_subtitle(app: String) -> String:
	return "synced to your workstation" if app == "chat" else "synced from your phone"


## Browser bookmarks: [[PAGES id, label], ...].
func _bookmarks() -> Array:
	return BOOKMARKS


## The clock shown before any item has a time.
func _default_clock() -> String:
	return DEFAULT_CLOCK


## A device string by key (UI_TEXT: the DecisionBar hints and the user's address).
func _ui_text(key: String) -> String:
	return str(UI_TEXT.get(key, ""))


func _checklist_columns() -> int:
	return 2


func _checklist_scroll() -> float:
	return CHECKLIST_SCROLL


## The name a new item is announced with: the sender (Mail, Messages, Chat) or the app (bank app screens).
func _sender_name(it: Dictionary) -> String:
	var msg: Dictionary = it.get("message", {})
	return str(msg.get("from_name", msg.get("sender_label", msg.get("app_name", ""))))


# --- Public API (CONTRACT.md Module B, TASKS-SPEC.md C.7) ---

## Stores the session, selects the app of the selected item (Mail, Messages or Chat), renders and shows.
## It never selects the Browser by itself: the Browser keeps session.page / session.pasted_url for later.
func open_session(s: ChapterSession) -> void:
	if s != session:
		session = s
		_locked = false
		_pending_link = ""
		_browser_notice = ""
		_built_sig = ""
		_decision_sig = ""
		_rendered_item = ""
		_known_ids.clear()
		# A new session: everything available now is already "known" (no toast).
		for it: Dictionary in session.available_items():
			_known_ids[str(it.get("id", ""))] = true
	_link_menu.hide()
	_rebuild_now()
	_select_app(_item_app())
	refresh()
	show_overlay()


## Re-renders from the session. Lists and reading panes are rebuilt (deferred) only when the selection or the
## set of available / done items changed; everything else is updated in place.
func refresh() -> void:
	if session == null:
		return
	_note_new_items()
	if _signature() != _built_sig:
		_queue_rebuild()
	else:
		_sync_reveals()
	_update_rail()
	_update_top_bar()
	_render_decision()


## Disables every choice button (and the checklist) while an outcome is showing; unlocking restores the gate rules.
func set_choices_locked(locked: bool) -> void:
	_locked = locked
	_update_choice_states()


## Sets session.page and switches to the Browser showing that bookmark page.
func show_page(page_id: String) -> void:
	if session == null or not Campaign.PAGES.has(page_id):
		return
	session.page = page_id
	_browser_notice = ""
	_select_app("browser")


## A Browser bookmark was pressed: show its page. The office desktop records no inspection for it (PhoneUI does).
func _bookmark_pressed(page_id: String) -> void:
	show_page(page_id)


## Shows a short notice in the top bar (e.g. "Your desk phone is ringing").
func notify(text: String) -> void:
	_show_toast(text)


func hide_overlay() -> void:
	if _link_menu != null:
		_link_menu.hide()
	super.hide_overlay()


## ESC stands the player up; the office closes the desktop.
func handle_back() -> void:
	_link_menu.hide()
	close_requested.emit()


## Ctrl+V pastes the in-game clipboard into the Browser while the desktop is open.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_open() or session == null or _locked:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if event.is_action_pressed("ui_paste") or (key.keycode == KEY_V and key.ctrl_pressed):
		get_viewport().set_input_as_handled()
		_paste()


# --- Top bar and app rail ---

func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := UIStyle.box(UIStyle.PANEL, 0, 0)
	sb.corner_radius_top_left = 9
	sb.corner_radius_top_right = 9
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", sb)
	var row := UIStyle.hbox(12)
	bar.add_child(row)
	row.add_child(_tile("A", UIStyle.ACCENT, 28, 16, 6))
	row.add_child(_line("Aegis Workstation", 17, UIStyle.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_tasks_label = _line("", 15, UIStyle.ACCENT)
	row.add_child(_tasks_label)
	row.add_child(_line(_ui_text("user_addr"), 15, UIStyle.MUTED, true))
	_clock_label = _line(_default_clock(), 16, UIStyle.TEXT, true)
	row.add_child(_clock_label)
	var leave := UIStyle.button("Leave desk (Esc)", 14, UIStyle.PANEL_LIGHT)
	leave.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL_LIGHT, 6, 6))
	leave.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHTER, 6, 6, UIStyle.ACCENT))
	leave.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL, 6, 6, UIStyle.ACCENT))
	leave.pressed.connect(handle_back)
	row.add_child(leave)
	return bar


## Task counter and clock (the latest time among the available mail/messages items).
func _update_top_bar() -> void:
	if session == null:
		return
	_tasks_label.text = "Tasks %d/%d" % [session.tasks_done(), session.task_count()]
	var latest := ""
	for it: Dictionary in session.available_items():
		if not _message_apps().has(str(it.get("app", ""))):
			continue
		var t := str((it.get("message", {}) as Dictionary).get("time", ""))
		if t > latest:
			latest = t
	_clock_label.text = latest if latest != "" else _default_clock()


func _build_rail() -> Control:
	var rail := PanelContainer.new()
	var sb := UIStyle.box(Color("141a22"), 0, 10)
	sb.corner_radius_bottom_left = 9
	rail.add_theme_stylebox_override("panel", sb)
	rail.custom_minimum_size.x = 104
	var list := UIStyle.vbox(6)
	rail.add_child(list)
	for app: String in _apps():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		# Four apps: 66 px each keeps the rail shorter than the checklist's room at 1280x720.
		b.custom_minimum_size = Vector2(84, 66)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "Open " + _app_name(app)
		b.pressed.connect(_select_app.bind(app))
		b.pressed.connect(Audio.play_sfx.bind("app_switch", -6.0, 1.0))
		var content := UIStyle.vbox(4)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIStyle.full_rect(content)
		b.add_child(content)
		var icon := _tile(_app_glyph(app), _app_color(app), 34, 13 if _app_glyph(app).length() > 1 else 18, 9)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		var name_label := _line(_app_name(app), 14, UIStyle.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_label)
		var badge := _tile("1", UIStyle.ACCENT, 20, 12, 10)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -26
		badge.offset_right = -6
		badge.offset_top = 4
		badge.offset_bottom = 24
		badge.visible = false
		b.add_child(badge)
		_app_buttons[app] = b
		_badges[app] = badge
		list.add_child(b)
	return rail


## The app on screen ("mail", "messages", "chat" or "browser").
func current_app() -> String:
	return _app


## The control the tutorial points at: "sender", "body", "paste", "decision" or an app name; null if not on screen.
func tutorial_target(kind: String) -> Control:
	match kind:
		"sender":
			return _sender_buttons[0] if not _sender_buttons.is_empty() and is_instance_valid(_sender_buttons[0]) else null
		"body":
			return _message_body if is_instance_valid(_message_body) else null
		"paste":
			return _paste_button if is_instance_valid(_paste_button) else null
		"decision":
			return find_child("DecisionBar", true, false) as Control
	return _app_buttons.get(kind) as Control


func _select_app(app: String) -> void:
	_app = app
	for a: String in _apps():
		(_views[a] as Control).visible = a == app
	_link_menu.hide()
	_update_rail()
	if app == "browser":
		_render_browser()


## Selected-app highlight and, per app, a badge with the number of available, unfinished items.
func _update_rail() -> void:
	for app: String in _apps():
		var b: Button = _app_buttons[app]
		var selected := app == _app
		var normal := UIStyle.box(UIStyle.PANEL_LIGHT, 8, 4, UIStyle.ACCENT) if selected else UIStyle.box(Color(0, 0, 0, 0), 8, 4)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHTER if not selected else UIStyle.PANEL_LIGHT, 8, 4, UIStyle.ACCENT))
		b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL_LIGHT, 8, 4, UIStyle.ACCENT))
		var count := _open_count(app)
		var badge: PanelContainer = _badges[app]
		badge.visible = count > 0
		(badge.get_child(0) as Label).text = str(count)


func _open_count(app: String) -> int:
	if session == null or not _message_apps().has(app):
		return 0
	var n := 0
	for it: Dictionary in session.available_items(app):
		if not session.is_done(str(it.get("id", ""))):
			n += 1
	return n


# --- Items: selection, signature, rebuild ---

func _message() -> Dictionary:
	if session == null:
		return {}
	return session.item().get("message", {})


## The app of the selected item (mail / messages / chat); falls back to the first available desktop item, then Mail.
func _item_app() -> String:
	if session == null:
		return "mail"
	var app := str(session.item().get("app", ""))
	if _message_apps().has(app):
		return app
	for it: Dictionary in session.available_items():
		var a := str(it.get("app", ""))
		if _message_apps().has(a):
			return a
	var chapter_app := str(session.chapter.get("app", "mail"))
	return chapter_app if _message_apps().has(chapter_app) else "mail"


## The inspection key of the sender reveal: the number (Messages), the profile (Chat), else the address (Mail).
func _sender_key_for(it: Dictionary) -> String:
	match str(it.get("app", "")):
		"messages":
			return "sender_number"
		"chat":
			return "profile"
		"bank":
			return "app_info"
	return "sender"


func _sender_key() -> String:
	return _sender_key_for(session.item()) if session != null else "sender"


## Selection + every available item with its status; a change means the lists and panes must be rebuilt.
func _signature() -> String:
	var parts := PackedStringArray([str(session.get_instance_id()), session.item_id])
	for it: Dictionary in session.available_items():
		var id := str(it.get("id", ""))
		parts.append(id + ":" + session.status(id))
	return "|".join(parts)


## Toast for mail/messages items that became available after the session was first opened.
func _note_new_items() -> void:
	var names := PackedStringArray()
	for it: Dictionary in session.available_items():
		if not _message_apps().has(str(it.get("app", ""))):
			continue
		var id := str(it.get("id", ""))
		if _known_ids.has(id):
			continue
		_known_ids[id] = true
		names.append(_sender_name(it))
	if not names.is_empty():
		_show_toast("New message: " + ", ".join(names))
		Audio.play_sfx("notify_ping", -4.0)


## Deferred so a row button's own pressed callback never frees the node that emitted it.
func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_deferred_rebuild")


func _deferred_rebuild() -> void:
	if not _rebuild_queued:
		return
	_rebuild_now()


## Rebuilds both message apps: the item lists and the reading pane of the selected item.
func _rebuild_now() -> void:
	_rebuild_queued = false
	if session == null:
		return
	_built_sig = _signature()
	_rendered_item = session.item_id
	var it := session.item()
	_sender_was_inspected = session.inspected.has(_sender_key_for(it))
	_sender_open = _sender_was_inspected and not _collapse_sender_for_checklist()
	_quote_was_inspected = session.inspected.has("quote")
	_quote_open = _quote_was_inspected
	_request_was_inspected = session.inspected.has("request")
	_request_open = _request_was_inspected
	_qr_open.clear()
	_qr_was_inspected.clear()
	for qr_id: String in (it.get("message", {}) as Dictionary).get("qrs", {}):
		_qr_was_inspected[qr_id] = session.inspected.has("qr:" + qr_id)
		_qr_open[qr_id] = _qr_was_inspected[qr_id]
	_sender_buttons.clear()
	_sender_details.clear()
	_quote_buttons.clear()
	_quote_details.clear()
	_request_buttons.clear()
	_request_details.clear()
	_qr_buttons.clear()
	_qr_details.clear()
	_hover_link = ""
	_rebuild_hosts()
	_update_rail()
	_update_top_bar()


## Empties and refills every item host (the office: Mail, Messages and Chat). PhoneUI adds its own hosts.
func _rebuild_hosts() -> void:
	for host: MarginContainer in [_mail_host, _messages_host, _chat_host]:
		_clear_host(host)
	_mail_host.add_child(_build_mail())
	_messages_host.add_child(_build_thread("messages"))
	_chat_host.add_child(_build_thread("chat"))


func _clear_host(host: Control) -> void:
	for child: Node in host.get_children():
		host.remove_child(child)
		child.queue_free()


## A Messages / Chat item on its checklist step keeps its sender details folded (more room for the thread).
func _collapse_sender_for_checklist() -> bool:
	return session != null and str(session.item().get("app", "")) in ["messages", "chat"] and session.is_checklist()


## In-place update of the reveal toggles: an inspection credited elsewhere (e.g. a test hook) opens it once.
func _sync_reveals() -> void:
	if session == null or _rendered_item != session.item_id or _rendered_item == "":
		return
	var has_sender := session.inspected.has(_sender_key())
	if has_sender and not _sender_was_inspected:
		_set_sender_open(true)
	_sender_was_inspected = has_sender
	var has_quote := session.inspected.has("quote")
	if has_quote and not _quote_was_inspected:
		_set_quote_open(true)
	_quote_was_inspected = has_quote
	var has_request := session.inspected.has("request")
	if has_request and not _request_was_inspected:
		_set_request_open(true)
	_request_was_inspected = has_request
	for qr_id: String in _qr_buttons:
		var has_qr := session.inspected.has("qr:" + qr_id)
		if has_qr and not bool(_qr_was_inspected.get(qr_id, false)):
			_set_qr_open(qr_id, true)
		_qr_was_inspected[qr_id] = has_qr


func _on_item_pressed(id: String) -> void:
	if session == null:
		return
	_link_menu.hide()
	item_selected.emit(id)


# --- Mail and Messages ---

func _build_mail() -> Control:
	var items := session.available_items("mail")
	if items.is_empty():
		return _empty_view("Inbox", "No messages")
	var split := UIStyle.hbox(12)
	split.add_child(_item_list("Inbox", "", items, "mail"))
	var it := session.item()
	if str(it.get("app", "")) != "mail":
		split.add_child(_placeholder_pane())
		return split
	split.add_child(_mail_pane(it))
	return split


## The reading pane of a Mail item: subject, the From name button (reveals the address), To, body, QR / quote.
func _mail_pane(it: Dictionary) -> Control:
	var msg: Dictionary = it.get("message", {})
	var pane := UIStyle.panel(UIStyle.PANEL, 18)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := _scroll_column(pane, 8)
	content.add_child(UIStyle.label(str(msg.get("subject", "")), 22, UIStyle.TEXT))

	var from_row := UIStyle.hbox(8)
	from_row.add_child(_field_name("From:"))
	from_row.add_child(_sender_button(str(msg.get("from_name", "")), "sender", "Show the full sender address"))
	content.add_child(from_row)

	var details := UIStyle.panel(UIStyle.PANEL_LIGHT, 8)
	var rows := UIStyle.vbox(4)
	details.add_child(rows)
	rows.add_child(_detail_row("From:", str(msg.get("from_addr", ""))))
	var reply_to := str(msg.get("reply_to", ""))
	if reply_to != "":
		rows.add_child(_detail_row("Reply-To:", reply_to))
	_register_details(details)
	content.add_child(details)

	var to_row := UIStyle.hbox(8)
	to_row.add_child(_field_name("To:"))
	to_row.add_child(_line(str(msg.get("to", _ui_text("user_addr"))), 16, UIStyle.TEXT, true))
	content.add_child(to_row)
	content.add_child(HSeparator.new())
	content.add_child(_body(str(msg.get("body", "")), 17))
	if str(it.get("kind", "")) == "coworker":
		content.add_child(_quote_block(msg))   # a forwarded email's QR codes sit inside the quote
	else:
		for qr: Control in _qr_blocks(msg):
			content.add_child(qr)
	return pane


## Messages (texts synced from your phone) and Chat (Kumusta Chat, synced to the workstation) share one
## phone-style layout: a thread list, a header whose name button reveals the number (Messages) or the account's
## profile (Chat), and the bubble.
func _build_thread(app: String) -> Control:
	var app_title: String = _thread_title(app)
	var items := session.available_items(app)
	if items.is_empty():
		return _empty_view(app_title, "No messages")
	var split := UIStyle.hbox(12)
	split.add_child(_item_list(app_title, _thread_subtitle(app), items, app))
	var it := session.item()
	if str(it.get("app", "")) != app:
		split.add_child(_placeholder_pane())
		return split
	split.add_child(_thread_pane(app, it))
	return split


## The conversation pane of a Messages / Chat item: header (name button, revealed number or profile), bubble,
## request and forwarded message.
func _thread_pane(app: String, it: Dictionary) -> Control:
	var chat := app == "chat"
	var msg: Dictionary = it.get("message", {})
	var sender := str(msg.get("sender_label", ""))

	# Conversation pane, phone style.
	var pane := UIStyle.panel(UIStyle.PANEL, 0)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIStyle.vbox(0)
	pane.add_child(column)
	var header := PanelContainer.new()
	var hsb := UIStyle.box(UIStyle.PANEL_LIGHT, 0, 14)
	hsb.corner_radius_top_left = 8
	hsb.corner_radius_top_right = 8
	header.add_theme_stylebox_override("panel", hsb)
	var head_col := UIStyle.vbox(8)
	header.add_child(head_col)
	var head_row := UIStyle.hbox(10)
	head_row.add_child(_tile(sender.substr(0, 1).to_upper(), _app_color(app), 36, 17, 18))
	if chat:
		head_row.add_child(_sender_button(sender, "profile", PROFILE_BUTTON_TIP))
		head_row.add_child(_line("View profile", 13, UIStyle.MUTED))
	else:
		head_row.add_child(_sender_button(sender, "sender_number", "Show the sender's number"))
	head_col.add_child(head_row)
	var details := UIStyle.panel(UIStyle.PANEL, 12)
	var rows := UIStyle.vbox(6)
	details.add_child(rows)
	if chat:
		# Two columns keep the header short, so the thread (request, forwarded message) stays in view.
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 28)
		grid.add_theme_constant_override("v_separation", 4)
		rows.add_child(grid)
		for line: Variant in msg.get("profile", []):
			grid.add_child(_line(str(line), 15, UIStyle.TEXT, true))   # no autowrap: a grid cell would shrink to 0
	else:
		rows.add_child(_detail_row("Number:", str(msg.get("sender_number", ""))))
		rows.add_child(UIStyle.mono_label(str(msg.get("sender_info", "")), 15, UIStyle.MUTED))
	_register_details(details)
	head_col.add_child(details)
	column.add_child(header)

	var thread_area := MarginContainer.new()
	thread_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		thread_area.add_theme_constant_override("margin_" + side, 16)
	column.add_child(thread_area)
	var thread := _scroll_column(thread_area, 10)
	var day := _line("Today " + str(msg.get("time", _default_clock())), 13, UIStyle.MUTED)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thread.add_child(day)
	var bubble := PanelContainer.new()
	var bsb := UIStyle.box(UIStyle.PANEL_LIGHTER, 16, 14)
	bsb.corner_radius_bottom_left = 4
	bubble.add_theme_stylebox_override("panel", bsb)
	bubble.add_child(_body(str(msg.get("body", "")), 18))
	thread.add_child(_left_row(bubble))
	if msg.has("request"):
		thread.add_child(_request_block(msg))
	if str(it.get("kind", "")) == "coworker":
		thread.add_child(_quote_block(msg))   # full width: its details button stays in view at 1280x720
	return pane


## A row that keeps its content on the left (phone-style bubbles), leaving a gap on the right.
func _left_row(content: Control) -> Control:
	var row := UIStyle.hbox(0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_stretch_ratio = 4.0   # bubbles take 80 % of the thread width (shorter, so more fits)
	row.add_child(content)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 1.0
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	return row


## The item list of an app: a header and one 56 px row button per available item, in data order, scrollable.
func _item_list(title_text: String, subtitle: String, items: Array, app: String) -> Control:
	var panel := UIStyle.panel(UIStyle.PANEL, 12)
	panel.custom_minimum_size.x = LIST_WIDTH
	var v := UIStyle.vbox(8)
	panel.add_child(v)
	var new_count := 0
	for it: Dictionary in items:
		if session.status(str(it.get("id", ""))) == "new":
			new_count += 1
	var head := UIStyle.hbox(8)
	head.add_child(_line(title_text, 18, UIStyle.TEXT))
	head.add_child(_line("%d new" % new_count, 14, UIStyle.ACCENT if new_count > 0 else UIStyle.MUTED))
	v.add_child(head)
	if subtitle != "":
		v.add_child(_line(subtitle, 13, UIStyle.MUTED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 0
	v.add_child(scroll)
	var rows := UIStyle.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for it: Dictionary in items:
		rows.add_child(_item_row(it, app))
	return panel


## One compact row: status glyph, avatar, sender, trimmed subject/preview, time. Empty button text; the labels
## ignore the mouse, so the whole row is one click target.
func _item_row(it: Dictionary, app: String) -> Button:
	var id := str(it.get("id", ""))
	var msg: Dictionary = it.get("message", {})
	var status := session.status(id)
	var selected := id == session.item_id
	var title_text := _row_title(it, app)
	var preview := _row_preview(it, app)

	var b := Button.new()
	b.name = "Item_" + id
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = title_text
	var border := UIStyle.ACCENT if selected else Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL_LIGHT if selected else UIStyle.PANEL, 8, 6, border))
	b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHTER, 8, 6, border))
	b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL_LIGHT, 8, 6, UIStyle.ACCENT))
	if status == "done":
		b.modulate.a = 0.7
	b.pressed.connect(_on_item_pressed.bind(id))

	var row := UIStyle.hbox(8)
	UIStyle.full_rect(row)
	row.offset_left = 6
	row.offset_right = -8
	b.add_child(row)
	var glyph_text := ""
	var glyph_color := UIStyle.TEXT
	if status == "new":
		glyph_text = "•"
		glyph_color = UIStyle.ACCENT
	elif status == "done":
		glyph_text = "✓"
		glyph_color = UIStyle.GOOD
	var glyph := _line(glyph_text, 16, glyph_color)
	glyph.custom_minimum_size.x = 12
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(glyph)
	row.add_child(_tile(title_text.substr(0, 1).to_upper(), _app_color(app), 28, 14, 14))
	# Two lines: the full display name (what players compare first) over the trimmed subject / preview.
	var text_col := UIStyle.vbox(0)
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.custom_minimum_size.x = 1
	row.add_child(text_col)
	var head := _line(title_text, 15, UIStyle.TEXT if status != "new" else Color.WHITE)
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.custom_minimum_size.x = 1
	text_col.add_child(head)
	var sub := _line(preview, 13, UIStyle.MUTED)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size.x = 1
	text_col.add_child(sub)
	row.add_child(_line(str(msg.get("time", "")), 13, UIStyle.MUTED, true))
	_ignore_mouse(row)
	return b


## A list row's name: the sender (Mail: from_name; Messages / Chat: sender_label), or the app of a bank app screen.
func _row_title(it: Dictionary, app: String) -> String:
	var msg: Dictionary = it.get("message", {})
	match app:
		"mail":
			return str(msg.get("from_name", ""))
		"bank":
			return str(msg.get("app_name", ""))
	return str(msg.get("sender_label", ""))


## A list row's preview: the subject (Mail), the screen title (bank app) or the body as plain text.
func _row_preview(it: Dictionary, app: String) -> String:
	var msg: Dictionary = it.get("message", {})
	match app:
		"mail":
			return str(msg.get("subject", ""))
		"bank":
			return str(msg.get("title", ""))
	return _plain(str(msg.get("body", "")))


func _placeholder_pane() -> Control:
	var p := _empty_view("", "Select a message")
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


## A coworker's forwarded message: label, a reveal button for its details (monospace) and its body with links.
func _quote_block(msg: Dictionary) -> Control:
	var q: Dictionary = msg.get("quote", {})
	var p := PanelContainer.new()
	var sb := UIStyle.box(UIStyle.PANEL_LIGHT, 6, 12)
	sb.border_color = UIStyle.ACCENT
	sb.border_width_left = 3
	p.add_theme_stylebox_override("panel", sb)
	var v := UIStyle.vbox(6)
	p.add_child(v)
	v.add_child(_line(str(q.get("label", "Forwarded message")), 14, UIStyle.MUTED))
	var b := _link_button(QUOTE_BUTTON_TEXT, 16, "Show the forwarded message's details")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(_on_quote_pressed)
	_quote_buttons.append(b)
	_update_toggle_button(b, _quote_open)
	v.add_child(b)
	var details := UIStyle.panel(UIStyle.PANEL, 10)
	var rows := UIStyle.vbox(4)
	details.add_child(rows)
	for line: Variant in q.get("details", []):
		rows.add_child(UIStyle.mono_label(str(line), 15, UIStyle.TEXT))
	details.visible = _quote_open
	_quote_details.append(details)
	v.add_child(details)
	v.add_child(_body(str(q.get("body", "")), 16))
	for qr: Control in _qr_blocks(msg):
		v.add_child(qr)
	return p


## A chat message's request: what it asks for, revealed by "Check the request" (inspection key "request").
func _request_block(msg: Dictionary) -> Control:
	var q: Dictionary = msg.get("request", {})
	var p := PanelContainer.new()
	var sb := UIStyle.box(UIStyle.PANEL_LIGHT, 6, 12)
	sb.border_color = UIStyle.ACCENT
	sb.border_width_left = 3
	p.add_theme_stylebox_override("panel", sb)
	var v := UIStyle.vbox(6)
	p.add_child(v)
	v.add_child(_line(str(q.get("label", "Request")), 14, UIStyle.MUTED))
	var b := _link_button(REQUEST_BUTTON_TEXT, 16, "Show exactly what the message asks for")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(_on_request_pressed)
	_request_buttons.append(b)
	_update_toggle_button(b, _request_open)
	v.add_child(b)
	var details := UIStyle.panel(UIStyle.PANEL, 10)
	var rows := UIStyle.vbox(4)
	details.add_child(rows)
	for line: Variant in q.get("details", []):
		var l := UIStyle.mono_label(str(line), 15, UIStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(l)
	details.visible = _request_open
	_request_details.append(details)
	v.add_child(details)
	return p


## One drawn QR code per entry of message.qrs, each with "Preview QR link": like a phone camera preview, it shows
## the code's real link address (host highlighted, facts only) and never opens it (inspection key "qr:<id>").
func _qr_blocks(msg: Dictionary) -> Array[Control]:
	var out: Array[Control] = []
	var qrs: Dictionary = msg.get("qrs", {})
	for qr_id: String in qrs:
		out.append(_qr_block(qr_id, str(qrs[qr_id])))
	return out


func _qr_block(qr_id: String, url: String) -> Control:
	var open := bool(_qr_open.get(qr_id, false))
	var p := PanelContainer.new()
	p.name = "QR_" + qr_id
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHT, 8, 12))
	var row := UIStyle.hbox(16)
	p.add_child(row)
	var code := TextureRect.new()
	code.name = "QRImage"
	code.texture = QRCode.texture(url, 5)
	code.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	code.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	code.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	code.custom_minimum_size = Vector2(QR_SIZE, QR_SIZE)
	code.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	code.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(code)
	var v := UIStyle.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(_line("QR code", 15, UIStyle.TEXT))
	v.add_child(UIStyle.label("A phone camera can show where a code leads before anything opens.", 14, UIStyle.MUTED))
	var b := _link_button(QR_BUTTON_TEXT, 16, "Show the code's link address without opening it")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(_on_qr_pressed.bind(qr_id))
	_qr_buttons[qr_id] = b
	_update_toggle_button(b, open)
	v.add_child(b)
	var details := UIStyle.panel(UIStyle.PANEL, 10)
	var rows := UIStyle.vbox(6)
	details.add_child(rows)
	rows.add_child(_line("Camera preview: link address", 13, UIStyle.MUTED))
	var addr := _rich(16, true)
	addr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	addr.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	addr.text = _url_bbcode(url, true)
	rows.add_child(addr)
	rows.add_child(UIStyle.label(QR_PREVIEW_LINE, 14, UIStyle.TEXT))
	details.visible = open
	_qr_details[qr_id] = details
	v.add_child(details)
	return p


## A link-style button (display name of a sender, forwarded-details toggle).
func _link_button(text: String, size: int, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", LINK_COLOR)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", UIStyle.box(Color(0, 0, 0, 0), 4, 6))
	b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHTER, 4, 6))
	b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL_LIGHTER, 4, 6))
	b.set_meta("display", text)
	return b


## The display name as a link-style button; clicking it reveals the real address/number.
func _sender_button(text: String, key: String, tip: String) -> Button:
	var b := _link_button(text, 18, tip)
	b.pressed.connect(_on_sender_pressed.bind(key))
	_sender_buttons.append(b)
	_update_toggle_button(b, _sender_open)
	return b


func _register_details(details: Control) -> void:
	details.visible = _sender_open
	_sender_details.append(details)


func _update_toggle_button(b: Button, open: bool) -> void:
	b.text = str(b.get_meta("display")) + ("  ▴" if open else "  ▾")


func _set_sender_open(open: bool) -> void:
	_sender_open = open
	for b: Button in _sender_buttons:
		_update_toggle_button(b, open)
	for d: Control in _sender_details:
		d.visible = open


func _set_quote_open(open: bool) -> void:
	_quote_open = open
	for b: Button in _quote_buttons:
		_update_toggle_button(b, open)
	for d: Control in _quote_details:
		d.visible = open


func _on_sender_pressed(key: String) -> void:
	if session == null:
		return
	_set_sender_open(not _sender_open)
	if _sender_open:
		inspected.emit(key)


func _set_request_open(open: bool) -> void:
	_request_open = open
	for b: Button in _request_buttons:
		_update_toggle_button(b, open)
	for d: Control in _request_details:
		d.visible = open


func _set_qr_open(qr_id: String, open: bool) -> void:
	_qr_open[qr_id] = open
	if _qr_buttons.has(qr_id):
		_update_toggle_button(_qr_buttons[qr_id] as Button, open)
	if _qr_details.has(qr_id):
		(_qr_details[qr_id] as Control).visible = open


func _on_request_pressed() -> void:
	if session == null:
		return
	_set_request_open(not _request_open)
	if _request_open:
		inspected.emit("request")


func _on_qr_pressed(qr_id: String) -> void:
	if session == null:
		return
	var open := not bool(_qr_open.get(qr_id, false))
	_set_qr_open(qr_id, open)
	if open:
		inspected.emit("qr:" + qr_id)


func _on_quote_pressed() -> void:
	if session == null:
		return
	_set_quote_open(not _quote_open)
	if _quote_open:
		inspected.emit("quote")


## Message body: BBCode with [url=<link id>] links. Never selectable, no context menu, never opens anything.
func _body(bbcode: String, size: int) -> RichTextLabel:
	var r := _rich(size)
	r.meta_underlined = true
	r.text = _link_re.sub(bbcode, "[color=#%s][url=$1]$2[/url][/color]" % LINK_COLOR.to_html(false), true)
	r.meta_clicked.connect(_on_meta_clicked)
	r.meta_hover_started.connect(_on_meta_hover_started)
	r.meta_hover_ended.connect(_on_meta_hover_ended)
	r.gui_input.connect(_on_body_gui_input.bind(r))
	_message_body = r
	return r


func _on_meta_clicked(meta: Variant) -> void:
	_open_link_menu(str(meta))


func _on_meta_hover_started(meta: Variant) -> void:
	_hover_link = str(meta)


func _on_meta_hover_ended(_meta: Variant) -> void:
	_hover_link = ""


## Right-clicking a link opens the same menu as a left click.
func _on_body_gui_input(event: InputEvent, body: RichTextLabel) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and _hover_link != "":
		body.accept_event()
		_open_link_menu(_hover_link)


# --- Link menu and clipboard ---

func _build_link_menu() -> void:
	_link_menu = PopupMenu.new()
	# No typing anywhere (paper Limitation 9): no type-to-search, and the engine's search bar stays off.
	_link_menu.allow_search = false
	_link_menu.search_bar_enabled = false
	_link_menu.add_item("Copy link address", COPY_LINK_ID)
	_link_menu.add_theme_font_size_override("font_size", 17)
	_link_menu.add_theme_color_override("font_color", UIStyle.TEXT)
	_link_menu.add_theme_color_override("font_hover_color", Color.WHITE)
	_link_menu.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_LIGHT, 6, 6, UIStyle.PANEL_LIGHTER))
	_link_menu.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.ACCENT.darkened(0.25), 4, 6))
	_link_menu.add_theme_constant_override("item_start_padding", 12)
	_link_menu.add_theme_constant_override("item_end_padding", 16)
	_link_menu.add_theme_constant_override("v_separation", 10)
	_link_menu.id_pressed.connect(_on_link_menu_id)
	add_child(_link_menu)


## Opens "Copy link address" at the mouse for a link of the selected item. A link click never opens a page.
func _open_link_menu(link_id: String) -> void:
	var links: Dictionary = _message().get("links", {})
	if not links.has(link_id):
		return
	_pending_link = link_id
	_link_menu.reset_size()
	var menu_size := _link_menu.size
	var at := get_screen_position() + get_local_mouse_position()
	var limit := get_viewport_rect().size
	at.x = minf(at.x, limit.x - menu_size.x - 4.0)
	at.y = minf(at.y, limit.y - menu_size.y - 4.0)
	_link_menu.popup(Rect2i(Vector2i(at), menu_size))


func _on_link_menu_id(id: int) -> void:
	if id != COPY_LINK_ID or _pending_link == "" or session == null:
		return
	var links: Dictionary = _message().get("links", {})
	if not links.has(_pending_link):
		links = session.all_links()
	session.clipboard = str(links.get(_pending_link, ""))
	_pending_link = ""
	_show_toast("Link address copied")
	Audio.play_sfx("copy")


## Copies the in-game clipboard into the address bar. Emits inspected("link:<id>") for a matching link of any
## available item (the session credits it to the item that owns the link).
func _paste() -> void:
	if session == null:
		return
	if session.clipboard == "":
		_browser_notice = EMPTY_CLIPBOARD
		_show_toast(EMPTY_CLIPBOARD)
		_select_app("browser")
		return
	_browser_notice = ""
	Audio.play_sfx("paste")
	session.pasted_url = session.clipboard
	session.page = ""
	_select_app("browser")
	var links: Dictionary = session.all_links()
	for link_id: String in links:
		if str(links[link_id]) == session.pasted_url:
			inspected.emit("link:" + link_id)


# --- Browser ---

func _build_browser() -> Control:
	var v := UIStyle.vbox(10)
	var toolbar := UIStyle.panel(UIStyle.PANEL, 10)
	var row := UIStyle.hbox(10)
	toolbar.add_child(row)
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", UIStyle.box(Color("0b0f14"), 6, 10, UIStyle.PANEL_LIGHTER))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_address = _rich(18, true)
	_address.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_address.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	field.add_child(_address)
	row.add_child(field)
	var paste := UIStyle.button("Paste", 17, UIStyle.ACCENT.darkened(0.35))
	paste.tooltip_text = "Paste the copied link address (Ctrl+V)"
	paste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	paste.custom_minimum_size.x = 96
	paste.pressed.connect(_paste)
	row.add_child(paste)
	_paste_button = paste
	v.add_child(toolbar)

	var marks := UIStyle.hbox(8)
	marks.add_child(_line("Bookmarks", 14, UIStyle.MUTED))
	for mark: Array in _bookmarks():
		var b := UIStyle.button(str(mark[1]), 15, UIStyle.PANEL)
		b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL, 6, 8))
		b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHT, 6, 8, UIStyle.ACCENT))
		b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL_LIGHT, 6, 8, UIStyle.ACCENT))
		b.pressed.connect(_bookmark_pressed.bind(str(mark[0])))
		marks.add_child(b)
	v.add_child(marks)

	_browser_info = UIStyle.label("", 16, UIStyle.WARN)
	_browser_info.visible = false
	v.add_child(_browser_info)

	var page := UIStyle.panel(UIStyle.PANEL, 24)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box = _scroll_column(page, 14)
	v.add_child(page)
	return v


## Renders the address bar and the page area: a bookmark page, the pasted-link view, or a new tab.
func _render_browser() -> void:
	if session == null:
		return
	for child: Node in _page_box.get_children():
		_page_box.remove_child(child)
		child.queue_free()
	_browser_info.text = _browser_notice
	_browser_info.visible = _browser_notice != ""
	if session.page != "" and Campaign.PAGES.has(session.page):
		var page: Dictionary = Campaign.PAGES[session.page]
		_address.text = _url_bbcode(str(page.get("url", "")), false)
		_render_page(session.page, page)
	elif session.pasted_url != "":
		_address.text = _url_bbcode(session.pasted_url, true)
		_page_box.add_child(_line("Pasted link address", 15, UIStyle.MUTED))
		var big := _rich(22, true)
		big.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		big.text = _url_bbcode(session.pasted_url, true)
		_page_box.add_child(big)
		_page_box.add_child(UIStyle.label(PASTED_LINE, 17, UIStyle.TEXT))
	else:
		_address.text = "[color=#%s]Paste a link address to read it[/color]" % UIStyle.MUTED.to_html(false)
		var head := UIStyle.hbox(12)
		head.add_child(_tile("WWW", _app_color("browser"), 44, 13, 10))
		head.add_child(_line("New tab", 22, UIStyle.TEXT))
		_page_box.add_child(head)
		_page_box.add_child(UIStyle.label("Paste a link address you copied to read it in full, or open a bookmark.", 17, UIStyle.MUTED))


## Static bookmark page from Campaign.PAGES: a table (directory) or lines (courier). No inputs.
func _render_page(page_id: String, page: Dictionary) -> void:
	var title := str(page.get("title", ""))
	var parts := title.split(": ", true, 1)
	var band := PanelContainer.new()
	var brand_color := Color("b8692a") if page_id == "courier" else UIStyle.ACCENT.darkened(0.35)
	band.add_theme_stylebox_override("panel", UIStyle.box(brand_color, 6, 16))
	var band_col := UIStyle.vbox(2)
	band.add_child(band_col)
	band_col.add_child(_line(parts[0], 22, Color.WHITE))
	if parts.size() > 1:
		band_col.add_child(_line(parts[1], 16, Color(1, 1, 1, 0.85)))
	_page_box.add_child(band)
	if page.has("columns"):
		_page_box.add_child(_table(page.get("columns", []), page.get("rows", [])))
	for text: String in page.get("lines", []):
		_page_box.add_child(UIStyle.label(text, 18, UIStyle.TEXT))


func _table(columns: Array, rows: Array) -> Control:
	var widths: Array[int] = [170, 220, 380, 110]
	var mono_cols: Array[int] = []
	for i: int in columns.size():
		if str(columns[i]) in ["Email", "Extension"]:
			mono_cols.append(i)
	var v := UIStyle.vbox(0)
	v.add_child(_table_row(columns, widths, mono_cols, true, UIStyle.PANEL_LIGHTER))
	for r: int in rows.size():
		v.add_child(_table_row(rows[r], widths, mono_cols, false, UIStyle.PANEL_LIGHT if r % 2 == 0 else UIStyle.PANEL))
	return v


func _table_row(cells: Array, widths: Array[int], mono_cols: Array[int], header: bool, color: Color) -> Control:
	var row := PanelContainer.new()
	var sb := UIStyle.box(color, 0, 10)
	sb.content_margin_left = 14
	row.add_theme_stylebox_override("panel", sb)
	var h := UIStyle.hbox(16)
	row.add_child(h)
	for i: int in cells.size():
		var mono := not header and mono_cols.has(i)
		var cell := _line(str(cells[i]), 15 if header else 16, UIStyle.MUTED if header else UIStyle.TEXT, mono)
		cell.custom_minimum_size.x = widths[i] if i < widths.size() else 120
		h.add_child(cell)
	return row


## Full URL in monospace with the host emphasised (bold, highlighted). Facts only: never red, never "fake".
func _url_bbcode(url: String, highlight: bool) -> String:
	var start := url.find("://")
	start = 0 if start < 0 else start + 3
	var stop := url.length()
	for c: String in ["/", "?", "#"]:
		var j := url.find(c, start)
		if j >= 0 and j < stop:
			stop = j
	var muted := UIStyle.MUTED.to_html(false)
	var host := "[b][color=#ffffff]%s[/color][/b]" % _esc(url.substr(start, stop - start))
	if highlight:
		host = "[bgcolor=#%s]%s[/bgcolor]" % [UIStyle.PANEL_LIGHTER.to_html(false), host]
	return "[color=#%s]%s[/color]%s[color=#%s]%s[/color]" % [muted, _esc(url.substr(0, start)), host, muted, _esc(url.substr(stop))]


# --- DecisionBar ---

func _build_decision_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "DecisionBar"
	var sb := UIStyle.box(UIStyle.PANEL, 0, 10)
	sb.corner_radius_bottom_left = 9
	sb.corner_radius_bottom_right = 9
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.border_color = UIStyle.ACCENT
	sb.border_width_top = 2
	bar.add_theme_stylebox_override("panel", sb)
	var v := UIStyle.vbox(8)
	bar.add_child(v)
	var head := UIStyle.hbox(12)
	var tag := _tile("DECISION", UIStyle.ACCENT.darkened(0.3), 0, 12, 4)
	tag.custom_minimum_size = Vector2(0, 0)
	(tag.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
	(tag.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8
	head.add_child(tag)
	_question = UIStyle.label("", 19, UIStyle.TEXT)
	_question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_question)
	v.add_child(head)
	_choice_flow = HFlowContainer.new()
	_choice_flow.add_theme_constant_override("h_separation", 10)
	_choice_flow.add_theme_constant_override("v_separation", 8)
	v.add_child(_choice_flow)
	_checklist_host = UIStyle.vbox(0)
	_checklist_host.visible = false
	v.add_child(_checklist_host)
	_hint = UIStyle.label("", 15, UIStyle.MUTED)
	v.add_child(_hint)
	return bar


## What the DecisionBar shows for the selected item: none, done, wait (telephone), phone, checklist or choices.
func _decision_mode() -> String:
	var it := session.item()
	if it.is_empty():
		return "none"
	if session.is_done(session.item_id):
		return "done"
	if session.waits_for_telephone():
		return "wait"
	if session.item_surface() != "desktop":
		return "phone"
	if session.is_checklist():
		return "checklist"
	return "choices"


## Question + choice buttons or the checklist, following gate_open / gate_hint / is_disabled / waits_for_telephone.
## The controls are rebuilt only when the item, its step or (for a checklist) its tried reports change.
func _render_decision() -> void:
	if session == null:
		return
	var mode := _decision_mode()
	var tried_count := session.tried().size() if mode == "checklist" else 0
	var sig := "%d|%s|%s|%d|%d" % [session.get_instance_id(), session.item_id, mode, session.step_index, tried_count]
	if sig != _decision_sig:
		_decision_sig = sig
		_clear_decision_controls()
		if mode == "choices":
			_build_choice_buttons()
		elif mode == "checklist":
			_build_checklist()
			# The checklist makes the DecisionBar taller: fold the revealed number in Messages so the text the
			# player reports on stays in view (the header button opens it again).
			if _collapse_sender_for_checklist():
				_set_sender_open(false)
	_choice_flow.visible = mode == "choices"
	_checklist_host.visible = mode == "checklist"
	var step := session.step()
	match mode:
		"none":
			_question.text = _ui_text("select_none")
			_set_hint("", UIStyle.MUTED)
		"done":
			_question.text = "Done: " + str(session.item().get("task", ""))
			if session.desktop_pending():
				_set_hint(_ui_text("select_another"), UIStyle.MUTED)
			elif session.phone_incoming():
				_set_hint(_ui_text("phone_ringing"), UIStyle.ACCENT)
			else:
				_set_hint(_ui_text("done_all"), UIStyle.GOOD)
		"wait":
			_question.text = str(step.get("wait_objective", ""))
			_set_hint(_ui_text("wait"), UIStyle.ACCENT)
		"phone":
			_question.text = session.objective()
			_set_hint(_ui_text("phone"), UIStyle.ACCENT)
		"checklist":
			_question.text = str(step.get("question", ""))
			_update_checklist_hint(session.ticks())
		_:
			_question.text = str(step.get("question", ""))
			_set_hint(session.gate_hint(), UIStyle.MUTED if session.gate_open() else UIStyle.WARN)
	_update_choice_states()


func _clear_decision_controls() -> void:
	for b: Button in _choice_buttons:
		_choice_flow.remove_child(b)
		b.queue_free()
	_choice_buttons.clear()
	if _checklist != null:
		_checklist_host.remove_child(_checklist)
		_checklist.queue_free()
		_checklist = null


## One button per choice in an HFlowContainer; long texts wrap so four choices take at most two rows.
func _build_choice_buttons() -> void:
	var choices: Array = session.step().get("choices", [])
	for i: int in choices.size():
		var b := UIStyle.button(str((choices[i] as Dictionary).get("text", "")), 16, UIStyle.PANEL_LIGHT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 360
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_choice_pressed.bind(i))
		_choice_flow.add_child(b)
		_choice_buttons.append(b)


## The tick-box report of warning signs (no typing), two columns, scrolling, Submit always visible.
func _build_checklist() -> void:
	_checklist = ChecklistView.new()
	_checklist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checklist_host.add_child(_checklist)
	_checklist.setup(session.step(), session.ticks(), session.tried(), _checklist_columns(), _checklist_scroll())
	_checklist.ticks_changed.connect(_on_checklist_ticks_changed)
	_checklist.submitted.connect(_on_checklist_view_submitted)


func _set_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.visible = text != ""
	_hint.add_theme_color_override("font_color", color)


func _update_checklist_hint(t: Array[int]) -> void:
	if not session.gate_open():
		_set_hint(session.gate_hint(), UIStyle.WARN)
		return
	var text := session.checklist_hint(t)
	_set_hint(text, UIStyle.MUTED if text == CHECKLIST_DEFAULT_HINT else UIStyle.WARN)


func _update_choice_states() -> void:
	if session == null:
		return
	var gate := session.gate_open()
	for i: int in _choice_buttons.size():
		_choice_buttons[i].disabled = _locked or not gate or session.is_disabled(i)
		UIStyle.mark_tried(_choice_buttons[i], session.is_disabled(i))
	if _checklist != null:
		_checklist.set_locked(_locked or not gate)


func _on_choice_pressed(index: int) -> void:
	if session == null or _locked or not session.gate_open() or session.is_disabled(index):
		return
	if session.item_surface() != "desktop" or session.is_checklist():
		return
	choice_selected.emit(index)


func _on_checklist_ticks_changed(t: Array[int]) -> void:
	if session == null:
		return
	session.set_ticks(t)
	_update_checklist_hint(t)


func _on_checklist_view_submitted(t: Array[int]) -> void:
	if session == null or _locked or not session.gate_open() or not session.is_checklist():
		return
	checklist_submitted.emit(t)


# --- Toast ---

func _build_toast() -> void:
	_toast = PanelContainer.new()
	var tsb := UIStyle.box(UIStyle.PANEL_LIGHTER, 8, 12, UIStyle.ACCENT)
	tsb.content_margin_top = 8
	tsb.content_margin_bottom = 8
	_toast.add_theme_stylebox_override("panel", tsb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# In the empty left part of the top bar (y 12..60), just after "Aegis Workstation" and growing to the right,
	# so it never hides the "Tasks D/T" counter, the Browser address bar or app content.
	_toast.anchor_left = 0.0
	_toast.anchor_right = 0.0
	_toast.offset_left = TOAST_LEFT
	_toast.offset_right = TOAST_LEFT
	_toast.offset_top = 14
	_toast.offset_bottom = 14
	_toast.grow_horizontal = Control.GROW_DIRECTION_END
	_toast_label = _line("", 17, UIStyle.TEXT)
	_toast.add_child(_toast_label)
	_toast.visible = false
	add_child(_toast)


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast_label.text = text
	_toast.reset_size()   # grows to the right (GROW_DIRECTION_END) to fit the text
	_toast.modulate.a = 1.0
	_toast.visible = true
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


# --- Small builders ---

## Single-line label (no autowrap, so it keeps its width inside an HBox).
func _line(text: String, size: int, color: Color, mono: bool = false) -> Label:
	var l := UIStyle.mono_label(text, size, color) if mono else UIStyle.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _field_name(text: String) -> Label:
	var l := _line(text, 16, UIStyle.MUTED)
	l.custom_minimum_size.x = 50
	return l


func _detail_row(name_text: String, value: String) -> Control:
	var row := UIStyle.hbox(10)
	var n := _line(name_text, 15, UIStyle.MUTED)
	n.custom_minimum_size.x = 84
	row.add_child(n)
	row.add_child(_line(value, 17, UIStyle.TEXT, true))
	return row


## Coloured square/rounded tile with centred text (app icons, avatars, badges).
func _tile(text: String, color: Color, side: int, font_size: int, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(color, radius, 2))
	p.custom_minimum_size = Vector2(side, side)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _line(text, font_size, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## Makes a control and all its descendants ignore the mouse (row contents inside a row button).
func _ignore_mouse(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in c.get_children():
		if child is Control:
			_ignore_mouse(child as Control)


func _empty_view(title_text: String, text: String) -> Control:
	var p := UIStyle.panel(UIStyle.PANEL, 24)
	var c := CenterContainer.new()
	p.add_child(c)
	var v := UIStyle.vbox(6)
	c.add_child(v)
	if title_text != "":
		var t := _line(title_text, 20, UIStyle.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	var m := _line(text, 16, UIStyle.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	return p


## A vertical scroll area inside parent; returns the column to fill.
func _scroll_column(parent: Control, sep: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var v := UIStyle.vbox(sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	return v


## Read-only RichTextLabel: no selection, no context menu, no focus (nothing reaches the OS clipboard).
func _rich(size: int, mono: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = false
	r.context_menu_enabled = false
	r.shortcut_keys_enabled = false
	r.focus_mode = Control.FOCUS_NONE
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_color_override("default_color", UIStyle.TEXT)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	if mono:
		r.add_theme_font_override("normal_font", UIStyle.mono_font())
		r.add_theme_font_override("bold_font", _bold_mono)
	return r


func _plain(bbcode: String) -> String:
	return _tag_re.sub(bbcode, "", true).replace("\n", " ")


func _esc(text: String) -> String:
	return text.replace("[", "[lb]")
