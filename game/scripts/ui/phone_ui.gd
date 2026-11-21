class_name PhoneUI
extends DesktopUI
## The player's own smartphone off the clock (home and cafe chapters; Objectives 3 and 5 on a phone).
## A portrait phone in the middle of the screen with the DecisionBar beside it. It reuses DesktopUI's renderers
## (item lists, sender reveals, link menu, Paste, QR previews, forwarded details, checklist) through the DesktopUI
## seams, and adds the phone-only views: a home screen of eight apps, KwartaPay (balance, History, Inbox, Report a
## scam), Calls (recents, keypad, hotlines), an incoming-call banner, Browser bookmarks that count as checks, the
## BancoNation app screen and the My Telco app. Buttons only: no typing anywhere, nothing scores here, no new sounds.
## Message apps are list -> detail: the list always has one Item_<id> row per available item; selecting a row shows
## its pane, and the header's Back button returns to the list.

signal answer_requested
signal dial_requested

const PHONE_APPS: Array[String] = ["messages", "calls", "chat", "wallet", "browser", "mail", "bank", "telco"]
const PHONE_MESSAGE_APPS: Array[String] = ["mail", "messages", "chat", "bank"]
const PHONE_APP_NAMES := {"messages": "Messages", "calls": "Calls", "chat": "ChatLink", "wallet": "KwartaPay",
	"browser": "Browser", "mail": "Mail", "bank": "BancoNation", "telco": "My Telco"}
const PHONE_APP_GLYPHS := {"messages": "SMS", "calls": "TEL", "chat": "CL", "wallet": "KP", "browser": "WWW",
	"mail": "@", "bank": "BN", "telco": "MT"}
const PHONE_APP_COLORS := {"messages": Color("3d9a5f"), "calls": Color("2e8b57"), "chat": Color("c06a32"),
	"wallet": Color("1d7f9e"), "browser": Color("7a5cc2"), "mail": Color("2f7fb5"), "bank": Color("1e4f8f"),
	"telco": Color("b8486b")}
## Every phone string of the DecisionBar and the top bar (DesktopUI._ui_text keys).
const PHONE_UI_TEXT := {
	"select_none": "Open an app and choose a message to work on.",
	"select_another": "Choose another message from the list.",
	"phone_ringing": "Answer the call on your phone.",
	"done_all": "All messages handled. Put the phone away (Esc).",
	"wait": "Open Calls and tap Keypad to dial.",
	"phone": "Answer the call on your phone.",
	"phone_use": "Open Calls and tap Keypad to dial.",
	"user_addr": "you@mymail.example",
}
## Other visible phone text (kept together so the smoke test can scan it).
const PHONE_TEXT := {
	"side_title": "Your phone",
	"put_away": "Put phone away (Esc)",
	"home": "Home",
	"back": "‹ Back",
	"home_hint": "Tap an app to open it.",
	"incoming": "Incoming call",
	"answer": "Answer",
	"balance": "Available balance",
	"history": "History",
	"inbox": "Inbox",
	"report": "Report a scam",
	"close": "Close",
	"details": "Details",
	"no_history": "No transactions yet.",
	"wallet_hotline": "KwartaPay hotline: 2299",
	"keypad": "Keypad",
	"keypad_idle": "The keypad is for calling a number you trust when a task asks you to.",
	"recents": "Recents",
	"no_recents": "No calls yet.",
	"hotlines": "Hotlines",
	"call_in": "Incoming call",
	"call_ringing": "Ringing now",
	"call_answered": "Answered",
	"call_out": "Outgoing call",
	"bookmarks": "Bookmarks",
	"account": "Your account",
	"at_home": "At home",
	"at_cafe": "At the cafe",
}
const PAGE_COLORS := {"shopko_checkout": Color("b8562a"), "banconation": Color("1e4f8f"), "kwartapay": Color("1d7f9e"),
	"sec_lenders": Color("3c4f6b"), "bpo_careers": Color("5a3f8a")}
const DAYS: Array[String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const PHONE_SIZE := Vector2(420, 700)
const SIDE_WIDTH := 560
const PHONE_CHECKLIST_SCROLL := 300.0
const TOAST_MAX_WIDTH := 330.0
const IN_COLOR := Color("5fd08a")

# Phone layout nodes
var _phone_root: Control
var _home: Control
var _home_clock: Label
var _home_place: Label
var _app_title: Label
var _back_button: Button
var _incoming: PanelContainer
var _incoming_caller: Label
var _bank_host: MarginContainer
var _wallet_host: MarginContainer
var _calls_host: MarginContainer
var _telco_host: MarginContainer

# KwartaPay
var _wallet_balance_label: Label
var _wallet_tabs: Dictionary = {}      ## "history" / "inbox" -> Button
var _wallet_content: VBoxContainer
var _wallet_tab: String = "history"
var _report_open: bool = false
var _tx_open: Dictionary = {}          ## row key ("tx:<id>" or "base_<i>") -> local reveal toggle
var _tx_details: Dictionary = {}       ## row key -> Control
var _tx_marks: Dictionary = {}         ## row key -> Label ("Details ▾")

# Calls
var _calls_keypad: Button
var _calls_hint: Label
var _calls_recents: VBoxContainer
var _recents_sig: String = ""

# List -> detail state of the message apps
var _show_list: Dictionary = {}        ## app -> true while the list is shown instead of the selected item's pane
var _last_item: String = ""
var _last_done: bool = false


func _ready() -> void:
	_setup_text_tools()

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.86)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.full_rect(bg)
	add_child(bg)

	var center := UIStyle.center()
	add_child(center)
	var row := UIStyle.hbox(28)
	center.add_child(row)
	row.add_child(_build_phone())
	row.add_child(_build_side())

	_build_toast()
	# The toast sits on the phone screen, under the status bar.
	remove_child(_toast)
	_phone_root.add_child(_toast)
	_toast.offset_left = 28
	_toast.offset_right = 28
	_toast.offset_top = 48
	_toast.offset_bottom = 48
	_toast_label.add_theme_font_size_override("font_size", 15)
	_build_link_menu()
	_select_app("home")


# --- Public API (on top of DesktopUI's) ---

## Stores the session and shows the selected item's app (its pane), or the home screen when no message item is
## selected. A pending session.phone_app (set by a correct choice's opens_app) is shown and cleared.
func open_session(s: ChapterSession) -> void:
	if s != session:
		_show_list.clear()
		_tx_open.clear()
		_wallet_tab = "history"
		_report_open = false
		_last_item = ""
		_last_done = false
		_recents_sig = ""
		if _toast_tween != null:
			_toast_tween.kill()
		_toast.hide()   # a notice from another chapter never carries over
	super.open_session(s)
	if session != null and session.phone_app != "":
		show_app(session.phone_app)


## Re-renders from the session, then the phone-only state (incoming call banner, Calls keypad and recents).
func refresh() -> void:
	super.refresh()
	if session == null:
		return
	_update_phone_state()


## Switches the phone to an app view: "wallet" (History), "wallet_inbox" (the Inbox tab: counts as opening it),
## "telco", "bank", or any phone app id. Clears session.phone_app when it names this target.
func show_app(target: String) -> void:
	if session == null:
		return
	if session.phone_app == target:
		session.phone_app = ""
	match target:
		"wallet":
			_wallet_tab = "history"
			_report_open = false
			_select_app("wallet")
		"wallet_inbox":
			_select_app("wallet")
			_on_wallet_tab("inbox")
		_:
			if PHONE_APPS.has(target):
				_select_app(target)


## Shows the list of a message app (the same as its Back button).
func show_list(app: String) -> void:
	_show_list[app] = true
	if session != null:
		_rebuild_now()
	_update_header()


# --- Seams ---

func _apps() -> Array[String]:
	return PHONE_APPS


func _message_apps() -> Array[String]:
	return PHONE_MESSAGE_APPS


func _app_name(app: String) -> String:
	return str(PHONE_APP_NAMES.get(app, app.capitalize()))


func _app_glyph(app: String) -> String:
	return str(PHONE_APP_GLYPHS.get(app, app.substr(0, 1).to_upper()))


func _app_color(app: String) -> Color:
	return PHONE_APP_COLORS.get(app, UIStyle.ACCENT)


func _thread_title(app: String) -> String:
	return "ChatLink" if app == "chat" else "Messages"


func _thread_subtitle(_app_id: String) -> String:
	return ""


func _bookmarks() -> Array:
	return Campaign.PHONE_BOOKMARKS


## The chapter's time on a 24-hour clock ("Mon 07:30 PM" -> "19:30").
func _default_clock() -> String:
	if session == null:
		return "12:00"
	return _clock_of(str(session.chapter.get("when", "")))


func _ui_text(key: String) -> String:
	return str(PHONE_UI_TEXT.get(key, super._ui_text(key)))


func _checklist_columns() -> int:
	return 1


func _checklist_scroll() -> float:
	return PHONE_CHECKLIST_SCROLL


## A bookmark shows its page and counts as checking it ("page:<id>", shared by every item that needs it).
func _bookmark_pressed(page_id: String) -> void:
	if session == null:
		return
	show_page(page_id)
	inspected.emit("page:" + page_id)


## The selected item's app when it is a message app, else the home screen.
func _item_app() -> String:
	if session == null:
		return "home"
	var app := str(session.item().get("app", ""))
	return app if _message_apps().has(app) else "home"


# --- Layout ---

func _build_phone() -> Control:
	_phone_root = Control.new()
	_phone_root.name = "Phone"
	_phone_root.custom_minimum_size = PHONE_SIZE
	_phone_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bezel := PanelContainer.new()
	bezel.add_theme_stylebox_override("panel", UIStyle.box(Color("0b0d11"), 36, 12, Color("2c3441")))
	UIStyle.full_rect(bezel)
	_phone_root.add_child(bezel)
	var screen := PanelContainer.new()
	screen.name = "Screen"
	screen.clip_contents = true
	screen.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, 26, 0))
	bezel.add_child(screen)
	var column := UIStyle.vbox(0)
	screen.add_child(column)
	column.add_child(_build_status_bar())
	column.add_child(_build_incoming_banner())
	column.add_child(_build_app_header())

	var area := MarginContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		area.add_theme_constant_override("margin_" + side, 8)
	column.add_child(area)
	_mail_host = MarginContainer.new()
	_messages_host = MarginContainer.new()
	_chat_host = MarginContainer.new()
	_bank_host = MarginContainer.new()
	_wallet_host = MarginContainer.new()
	_wallet_host.add_child(_build_wallet_view())
	_calls_host = MarginContainer.new()
	_calls_host.add_child(_build_calls_view())
	_telco_host = MarginContainer.new()
	_telco_host.add_child(_static_app_page("telco"))
	_views = {"messages": _messages_host, "calls": _calls_host, "chat": _chat_host, "wallet": _wallet_host,
		"browser": _build_browser(), "mail": _mail_host, "bank": _bank_host, "telco": _telco_host}
	_home = _build_home()
	area.add_child(_home)
	for app: String in _apps():
		area.add_child(_views[app])
	column.add_child(_build_nav_bar())
	return _phone_root


func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := UIStyle.box(Color("0d1117"), 0, 0)
	sb.corner_radius_top_left = 26
	sb.corner_radius_top_right = 26
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", sb)
	var row := UIStyle.hbox(10)
	bar.add_child(row)
	_clock_label = _line("12:00", 15, UIStyle.TEXT, true)
	_clock_label.name = "Clock"
	row.add_child(_clock_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_tasks_label = _line("", 14, UIStyle.ACCENT)
	_tasks_label.name = "Tasks"
	row.add_child(_tasks_label)
	row.add_child(_line("▮▮▮▯", 12, UIStyle.MUTED))
	return bar


func _build_incoming_banner() -> Control:
	_incoming = PanelContainer.new()
	_incoming.name = "IncomingCall"
	var sb := UIStyle.box(Color("1d5a3a"), 0, 10, Color("4caf6a"))
	sb.set_border_width_all(0)
	sb.border_width_bottom = 2
	_incoming.add_theme_stylebox_override("panel", sb)
	var row := UIStyle.hbox(10)
	_incoming.add_child(row)
	row.add_child(_tile("TEL", PHONE_APP_COLORS["calls"], 36, 11, 18))
	var v := UIStyle.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(_line(str(PHONE_TEXT.incoming), 13, Color(1, 1, 1, 0.8)))
	_incoming_caller = UIStyle.mono_label("", 15, Color.WHITE)
	_incoming_caller.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(_incoming_caller)
	var answer := UIStyle.button(str(PHONE_TEXT.answer), 15, UIStyle.GOOD.darkened(0.2))
	answer.name = "AnswerCall"
	answer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	answer.pressed.connect(_on_answer_pressed)
	row.add_child(answer)
	_incoming.visible = false
	return _incoming


func _build_app_header() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 0, 8))
	var row := UIStyle.hbox(8)
	bar.add_child(row)
	_back_button = _link_button(str(PHONE_TEXT.back), 15, "Back to the list")
	_back_button.name = "BackToList"
	_back_button.text = str(PHONE_TEXT.back)
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.visible = false
	row.add_child(_back_button)
	_app_title = _line("", 17, UIStyle.TEXT)
	_app_title.name = "AppTitle"
	_app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_app_title)
	return bar


func _build_nav_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := UIStyle.box(Color("0d1117"), 0, 6)
	sb.corner_radius_bottom_left = 26
	sb.corner_radius_bottom_right = 26
	bar.add_theme_stylebox_override("panel", sb)
	var c := CenterContainer.new()
	bar.add_child(c)
	var home := UIStyle.button(str(PHONE_TEXT.home), 15, UIStyle.PANEL_LIGHT)
	home.name = "HomeButton"
	home.custom_minimum_size = Vector2(150, 34)
	home.pressed.connect(_on_home_pressed)
	c.add_child(home)
	return bar


## The home screen: the time, where you are, and a 4 x 2 grid of app icons with badges.
func _build_home() -> Control:
	var v := UIStyle.vbox(14)
	v.name = "HomeScreen"
	var top := UIStyle.vbox(2)
	v.add_child(top)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	top.add_child(spacer)
	_home_clock = _line("12:00", 46, UIStyle.TEXT)
	_home_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_home_clock)
	_home_place = _line("", 15, UIStyle.MUTED)
	_home_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_home_place)
	var grid := GridContainer.new()
	grid.name = "AppGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for app: String in PHONE_APPS:
		grid.add_child(_app_icon(app))
	var hint := _line(str(PHONE_TEXT.home_hint), 14, UIStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	return v


func _app_icon(app: String) -> Button:
	var b := Button.new()
	b.name = "App_" + app
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 88)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Open " + _app_name(app)
	b.add_theme_stylebox_override("normal", UIStyle.box(Color(0, 0, 0, 0), 12, 4))
	b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHT, 12, 4, UIStyle.ACCENT))
	b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL_LIGHTER, 12, 4, UIStyle.ACCENT))
	b.pressed.connect(_on_app_icon.bind(app))
	var content := UIStyle.vbox(5)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.full_rect(content)
	b.add_child(content)
	var glyph := _app_glyph(app)
	var icon := _tile(glyph, _app_color(app), 50, 14 if glyph.length() > 1 else 22, 14)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	var name_label := _line(_app_name(app), 12, UIStyle.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	var badge := _tile("1", UIStyle.DANGER.darkened(0.1), 20, 12, 10)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -26
	badge.offset_right = -6
	badge.offset_top = 2
	badge.offset_bottom = 22
	badge.visible = false
	b.add_child(badge)
	_app_buttons[app] = b
	_badges[app] = badge
	return b


## Right of the phone: "Your phone", Put phone away (Esc), then the DecisionBar.
func _build_side() -> Control:
	var side := UIStyle.vbox(12)
	side.name = "Side"
	side.custom_minimum_size = Vector2(SIDE_WIDTH, PHONE_SIZE.y)
	var top := UIStyle.hbox(12)
	side.add_child(top)
	var title := DialoguePanel.section(str(PHONE_TEXT.side_title), UIStyle.ACCENT, 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	var away := UIStyle.button(str(PHONE_TEXT.put_away), 14, UIStyle.PANEL_LIGHT)
	away.name = "PutAway"
	away.pressed.connect(handle_back)
	top.add_child(away)
	var bar := _build_decision_bar()
	var sb := UIStyle.box(UIStyle.PANEL, 12, 18)
	sb.border_color = UIStyle.ACCENT
	sb.border_width_top = 2
	bar.add_theme_stylebox_override("panel", sb)
	side.add_child(bar)
	return side


# --- Apps, header and rail ---

func _select_app(app: String) -> void:
	if _home != null:
		_home.visible = app == "home"
	super._select_app(app)
	match app:
		"wallet":
			_render_wallet()
		"calls":
			_render_calls()
	_update_header()


## Badges on the home screen: open items per message app, and Calls while a call rings or waits to be placed.
func _update_rail() -> void:
	for app: String in _apps():
		var badge: PanelContainer = _badges.get(app)
		if badge == null:
			continue
		var count := _open_count(app)
		if app == "calls" and session != null and (session.phone_incoming() or _dial_ready()):
			count = 1
		badge.visible = count > 0
		(badge.get_child(0) as Label).text = str(count)


func _update_top_bar() -> void:
	if session == null:
		return
	_tasks_label.text = "Tasks %d/%d" % [session.tasks_done(), session.task_count()]
	var latest := _default_clock()
	for it: Dictionary in session.available_items():
		if not _message_apps().has(str(it.get("app", ""))):
			continue
		var t := str((it.get("message", {}) as Dictionary).get("time", ""))
		if t.length() == 5 and t > latest:
			latest = t
	_clock_label.text = latest
	_home_clock.text = latest
	var place := session.place()
	_home_place.text = str(session.chapter.get("when", "")).get_slice(" ", 0) + " · " + \
		str(PHONE_TEXT.at_cafe if place == "cafe" else PHONE_TEXT.at_home)


func _update_header() -> void:
	if _app_title == null:
		return
	_app_title.text = str(PHONE_TEXT.home) if _app == "home" else _app_name(_app)
	_back_button.visible = _message_apps().has(_app) and _pane_shown(_app)


func _update_phone_state() -> void:
	var ringing := session.phone_incoming()
	_incoming.visible = ringing
	if ringing:
		var call: Dictionary = session.item(session.phone_item()).get("call", {})
		_incoming_caller.text = str(call.get("caller_id", ""))
	_render_calls()
	_update_header()


func _on_app_icon(app: String) -> void:
	Audio.play_sfx("app_switch", -6.0, 1.0)
	_select_app(app)


func _on_home_pressed() -> void:
	Audio.play_sfx("app_switch", -6.0, 1.0)
	_select_app("home")


func _on_back_pressed() -> void:
	_link_menu.hide()
	show_list(_app)


func _on_answer_pressed() -> void:
	if session == null or not session.phone_incoming():
		return
	answer_requested.emit()


# --- Message apps: list -> detail ---

## True when the app shows the selected item's pane instead of its list.
func _pane_shown(app: String) -> bool:
	if session == null:
		return false
	return str(session.item().get("app", "")) == app and not bool(_show_list.get(app, false))


## A new selection opens its pane; an item that was just resolved returns its app to the list.
func _update_list_modes() -> void:
	var id := session.item_id
	var app := str(session.item().get("app", ""))
	var done := id != "" and session.is_done(id)
	if id != _last_item:
		if app != "":
			_show_list[app] = false
	elif done and not _last_done and app != "":
		_show_list[app] = true
	_last_item = id
	_last_done = done


func _on_item_pressed(id: String) -> void:
	if session == null:
		return
	super._on_item_pressed(id)
	if session != null and session.item_id == id:
		_show_list[str(session.item().get("app", ""))] = false
		_queue_rebuild()


func _rebuild_hosts() -> void:
	_update_list_modes()
	for host: MarginContainer in [_mail_host, _messages_host, _chat_host, _bank_host]:
		_clear_host(host)
	_mail_host.add_child(_build_mail())
	_messages_host.add_child(_build_thread("messages"))
	_chat_host.add_child(_build_thread("chat"))
	_bank_host.add_child(_build_bank())
	_render_wallet()
	_recents_sig = ""
	_render_calls()
	_update_header()


func _build_mail() -> Control:
	var items := session.available_items("mail")
	if items.is_empty():
		return _empty_view("Mail", "No messages")
	if _pane_shown("mail"):
		return _mail_pane(session.item())
	return _phone_list("Inbox", items, "mail")


func _build_thread(app: String) -> Control:
	var items := session.available_items(app)
	if items.is_empty():
		return _empty_view(_thread_title(app), "No messages")
	if _pane_shown(app):
		return _thread_pane(app, session.item())
	return _phone_list(_thread_title(app), items, app)


## BancoNation: the list of app screens (with the account card), or the selected screen; the static account page
## when the chapter has no BancoNation screen.
func _build_bank() -> Control:
	var items := session.available_items("bank")
	if items.is_empty():
		return _static_app_page("bank")
	if _pane_shown("bank"):
		return _bank_pane(session.item())
	var v := UIStyle.vbox(8)
	v.add_child(_phone_list("BancoNation", items, "bank"))
	var card := UIStyle.panel(UIStyle.PANEL_LIGHT, 12)
	var cv := UIStyle.vbox(4)
	card.add_child(cv)
	cv.add_child(_line(str(PHONE_TEXT.account), 13, UIStyle.MUTED))
	var page: Dictionary = Campaign.PHONE_APP_PAGES.get("bank", {})
	for line: Variant in page.get("lines", []):
		cv.add_child(UIStyle.label(str(line), 14, UIStyle.TEXT))
	v.add_child(card)
	return v


func _phone_list(title_text: String, items: Array, app: String) -> Control:
	var l := _item_list(title_text, "", items, app)
	l.custom_minimum_size.x = 0
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l


## A phone email: subject, From (name button reveals the address), To, body, and QR codes or the forwarded part.
func _mail_pane(it: Dictionary) -> Control:
	var msg: Dictionary = it.get("message", {})
	var pane := UIStyle.panel(UIStyle.PANEL, 14)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := _scroll_column(pane, 8)
	content.add_child(UIStyle.label(str(msg.get("subject", "")), 18, UIStyle.TEXT))
	var from_row := UIStyle.hbox(6)
	from_row.add_child(_field_name("From:"))
	from_row.add_child(_sender_button(str(msg.get("from_name", "")), "sender", "Show the full sender address"))
	content.add_child(from_row)
	var details := UIStyle.panel(UIStyle.PANEL_LIGHT, 8)
	var rows := UIStyle.vbox(4)
	details.add_child(rows)
	rows.add_child(_wrap_mono("From: " + str(msg.get("from_addr", "")), 14, UIStyle.TEXT))
	var reply_to := str(msg.get("reply_to", ""))
	if reply_to != "":
		rows.add_child(_wrap_mono("Reply-To: " + reply_to, 14, UIStyle.TEXT))
	_register_details(details)
	content.add_child(details)
	content.add_child(_wrap_mono("To: " + str(msg.get("to", _ui_text("user_addr"))), 13, UIStyle.MUTED))
	content.add_child(HSeparator.new())
	content.add_child(_body(str(msg.get("body", "")), 15))
	if str(it.get("kind", "")) == "coworker":
		content.add_child(_quote_block(msg))
	else:
		for qr: Control in _qr_blocks(msg):
			content.add_child(qr)
	return pane


## A phone conversation: header with the name button, then (scrolling) the revealed number or profile, earlier
## texts of the same thread (muted), the bubble, the request and the forwarded message.
func _thread_pane(app: String, it: Dictionary) -> Control:
	var chat := app == "chat"
	var msg: Dictionary = it.get("message", {})
	var sender := str(msg.get("sender_label", ""))
	var pane := UIStyle.panel(UIStyle.PANEL, 0)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIStyle.vbox(0)
	pane.add_child(column)
	var header := PanelContainer.new()
	var hsb := UIStyle.box(UIStyle.PANEL_LIGHT, 0, 10)
	hsb.corner_radius_top_left = 8
	hsb.corner_radius_top_right = 8
	header.add_theme_stylebox_override("panel", hsb)
	var head_row := UIStyle.hbox(8)
	header.add_child(head_row)
	head_row.add_child(_tile(sender.substr(0, 1).to_upper(), _app_color(app), 32, 15, 16))
	if chat:
		head_row.add_child(_sender_button(sender, "profile", PROFILE_BUTTON_TIP))
	else:
		head_row.add_child(_sender_button(sender, "sender_number", "Show the sender's number"))
	column.add_child(header)

	var thread_area := MarginContainer.new()
	thread_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		thread_area.add_theme_constant_override("margin_" + side, 10)
	column.add_child(thread_area)
	var thread := _scroll_column(thread_area, 10)
	var details := UIStyle.panel(UIStyle.PANEL_LIGHT, 10)
	var rows := UIStyle.vbox(4)
	details.add_child(rows)
	if chat:
		for line: Variant in msg.get("profile", []):
			rows.add_child(_wrap_mono(str(line), 14, UIStyle.TEXT))
	else:
		rows.add_child(_wrap_mono("Number: " + str(msg.get("sender_number", "")), 14, UIStyle.TEXT))
		rows.add_child(_wrap_mono(str(msg.get("sender_info", "")), 13, UIStyle.MUTED))
	_register_details(details)
	thread.add_child(details)
	var day := _line("Today " + str(msg.get("time", _default_clock())), 12, UIStyle.MUTED)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thread.add_child(day)
	for prev: Dictionary in _earlier_in_thread(it):
		thread.add_child(_left_row(_muted_bubble(prev)))
	var bubble := PanelContainer.new()
	var bsb := UIStyle.box(UIStyle.PANEL_LIGHTER, 14, 12)
	bsb.corner_radius_bottom_left = 4
	bubble.add_theme_stylebox_override("panel", bsb)
	bubble.add_child(_body(str(msg.get("body", "")), 15))
	thread.add_child(_left_row(bubble))
	if msg.has("request"):
		thread.add_child(_request_block(msg))
	if str(it.get("kind", "")) == "coworker":
		thread.add_child(_quote_block(msg))
	return pane


## Earlier available items of the same message.thread (data order), shown as muted bubbles above this one.
func _earlier_in_thread(it: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var thread_id := str((it.get("message", {}) as Dictionary).get("thread", ""))
	if thread_id == "" or session == null:
		return out
	for other: Dictionary in session.available_items(str(it.get("app", ""))):
		if str(other.get("id", "")) == str(it.get("id", "")):
			break
		if str((other.get("message", {}) as Dictionary).get("thread", "")) == thread_id:
			out.append(other)
	return out


func _muted_bubble(it: Dictionary) -> Control:
	var msg: Dictionary = it.get("message", {})
	var bubble := PanelContainer.new()
	var sb := UIStyle.box(UIStyle.PANEL_LIGHT, 14, 10)
	sb.corner_radius_bottom_left = 4
	bubble.add_theme_stylebox_override("panel", sb)
	var v := UIStyle.vbox(2)
	bubble.add_child(v)
	v.add_child(UIStyle.label(_plain(str(msg.get("body", ""))), 14, UIStyle.MUTED))
	v.add_child(_line(str(msg.get("time", "")), 11, Color(UIStyle.MUTED, 0.8)))
	bubble.modulate.a = 0.8
	return bubble


## A BancoNation app screen: the app name button reveals the app details (publisher, how you opened it).
func _bank_pane(it: Dictionary) -> Control:
	var msg: Dictionary = it.get("message", {})
	var pane := UIStyle.panel(UIStyle.PANEL, 14)
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := _scroll_column(pane, 10)
	var head := UIStyle.hbox(8)
	head.add_child(_tile(_app_glyph("bank"), _app_color("bank"), 34, 13, 9))
	head.add_child(_sender_button(str(msg.get("app_name", "")), "app_info", "Show the app details"))
	content.add_child(head)
	var details := UIStyle.panel(UIStyle.PANEL_LIGHT, 10)
	var rows := UIStyle.vbox(4)
	details.add_child(rows)
	for line: Variant in msg.get("app_info", []):
		rows.add_child(_wrap_mono(str(line), 14, UIStyle.TEXT))
	_register_details(details)
	content.add_child(details)
	content.add_child(HSeparator.new())
	content.add_child(UIStyle.label(str(msg.get("title", "")), 18, UIStyle.TEXT))
	content.add_child(_body(str(msg.get("body", "")), 15))
	for qr: Control in _qr_blocks(msg):
		content.add_child(qr)
	return pane


## A static app screen from Campaign.PHONE_APP_PAGES (My Telco, the BancoNation account, Report a scam).
func _static_app_page(key: String) -> Control:
	var page: Dictionary = Campaign.PHONE_APP_PAGES.get(key, {})
	var panel := UIStyle.panel(UIStyle.PANEL, 14)
	var content := _scroll_column(panel, 10)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UIStyle.box(_app_color(key).darkened(0.15), 8, 12))
	var bv := UIStyle.vbox(2)
	band.add_child(bv)
	bv.add_child(UIStyle.label(str(page.get("title", "")), 19, Color.WHITE))
	if page.has("publisher"):
		bv.add_child(UIStyle.label(str(page.get("publisher", "")), 13, Color(1, 1, 1, 0.85)))
	content.add_child(band)
	for line: Variant in page.get("lines", []):
		content.add_child(UIStyle.label(str(line), 15, UIStyle.TEXT))
	return panel


# --- KwartaPay ---

func _build_wallet_view() -> Control:
	var panel := UIStyle.panel(UIStyle.PANEL, 12)
	var col := _scroll_column(panel, 10)
	var head := UIStyle.hbox(8)
	head.add_child(_tile(_app_glyph("wallet"), _app_color("wallet"), 30, 12, 8))
	head.add_child(_line("KwartaPay", 18, UIStyle.TEXT))
	col.add_child(head)

	var card := PanelContainer.new()
	card.name = "WalletBalance"
	card.add_theme_stylebox_override("panel", UIStyle.box(Color("1d6f8a"), 12, 14))
	var cv := UIStyle.vbox(2)
	card.add_child(cv)
	cv.add_child(_line(str(PHONE_TEXT.balance), 13, Color(1, 1, 1, 0.8)))
	_wallet_balance_label = _line("", 28, Color.WHITE)
	_wallet_balance_label.name = "BalanceAmount"
	cv.add_child(_wallet_balance_label)
	col.add_child(card)

	var tabs := UIStyle.hbox(8)
	col.add_child(tabs)
	for tab: String in ["history", "inbox"]:
		var b := UIStyle.button(str(PHONE_TEXT[tab]), 15, UIStyle.PANEL_LIGHT)
		b.name = "WalletTab_" + tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_wallet_tab.bind(tab))
		tabs.add_child(b)
		_wallet_tabs[tab] = b

	_wallet_content = UIStyle.vbox(6)
	_wallet_content.name = "WalletContent"
	col.add_child(_wallet_content)

	var report := UIStyle.button(str(PHONE_TEXT.report), 15, UIStyle.PANEL_LIGHT)
	report.name = "WalletReport"
	report.pressed.connect(_on_wallet_report)
	col.add_child(report)
	col.add_child(_line(str(PHONE_TEXT.wallet_hotline), 14, UIStyle.MUTED, true))
	return panel


## Balance, tab highlight and the tab's content (History rows, Inbox notices or the Report a scam sheet).
func _render_wallet() -> void:
	if session == null or _wallet_content == null:
		return
	_wallet_balance_label.text = _wallet_balance()
	for tab: String in _wallet_tabs:
		var b: Button = _wallet_tabs[tab]
		var on := tab == _wallet_tab and not _report_open
		b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.ACCENT.darkened(0.35) if on else UIStyle.PANEL_LIGHT, 6, 10))
	_render_wallet_content()


func _render_wallet_content() -> void:
	for child: Node in _wallet_content.get_children():
		_wallet_content.remove_child(child)
		child.queue_free()
	_tx_details.clear()
	_tx_marks.clear()
	if _report_open:
		_wallet_content.add_child(_report_sheet())
	elif _wallet_tab == "inbox":
		var wallet: Dictionary = session.chapter.get("wallet", {})
		for note: Variant in wallet.get("inbox", []):
			_wallet_content.add_child(_inbox_notice(note as Dictionary))
	else:
		var rows := _wallet_rows()
		if rows.is_empty():
			_wallet_content.add_child(_line(str(PHONE_TEXT.no_history), 14, UIStyle.MUTED))
		for e: Dictionary in rows:
			_wallet_content.add_child(_tx_row(e))


## The chapter's baseline History plus the unlocked items' transfers, newest first.
func _wallet_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var wallet: Dictionary = session.chapter.get("wallet", {})
	var history: Array = wallet.get("history", [])
	for i: int in history.size():
		var e: Dictionary = (history[i] as Dictionary).duplicate()
		e["key"] = "base_%d" % i
		e["order"] = i
		rows.append(e)
	for t: Dictionary in session.all_wallet_tx():
		var e: Dictionary = t.duplicate()
		e["key"] = "tx:" + str(t.get("id", ""))
		e["order"] = -1
		rows.append(e)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := _time_key(str(a.get("time", "")))
		var kb := _time_key(str(b.get("time", "")))
		if ka != kb:
			return ka > kb
		return int(a.order) < int(b.order))
	return rows


func _tx_row(e: Dictionary) -> Control:
	var key := str(e.key)
	var is_item := key.begins_with("tx:")
	var open := bool(_tx_open.get(key, false))
	var incoming := str(e.get("dir", "in")) == "in"
	var box := UIStyle.vbox(0)
	var b := Button.new()
	b.name = ("Tx_" + key.substr(3)) if is_item else ("Hist_" + key.substr(5))
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL_LIGHT, 8, 6))
	b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHTER, 8, 6, UIStyle.ACCENT))
	b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL_LIGHTER, 8, 6, UIStyle.ACCENT))
	b.pressed.connect(_on_tx_pressed.bind(key))
	var row := UIStyle.hbox(8)
	UIStyle.full_rect(row)
	row.offset_left = 8
	row.offset_right = -8
	b.add_child(row)
	var arrow := _line("↓" if incoming else "↑", 18, IN_COLOR if incoming else UIStyle.MUTED)
	arrow.custom_minimum_size.x = 14
	row.add_child(arrow)
	var text_col := UIStyle.vbox(0)
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.custom_minimum_size.x = 1
	row.add_child(text_col)
	var name_label := _line(str(e.get("name", "")), 14, UIStyle.TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 1
	text_col.add_child(name_label)
	var mark := _line("%s · %s  %s" % [str(e.get("time", "")), str(PHONE_TEXT.details), "▴" if open else "▾"], 12, UIStyle.MUTED)
	mark.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mark.custom_minimum_size.x = 1
	text_col.add_child(mark)
	_tx_marks[key] = mark
	var amount := _line(("+" if incoming else "-") + str(e.get("amount", "")), 15, IN_COLOR if incoming else UIStyle.TEXT, true)
	row.add_child(amount)
	_ignore_mouse(row)
	box.add_child(b)

	var details := UIStyle.panel(UIStyle.PANEL, 10)
	var lines := UIStyle.vbox(3)
	details.add_child(lines)
	lines.add_child(_wrap_mono(("From: " if incoming else "To: ") + str(e.get("name", "")), 13, UIStyle.TEXT))
	if str(e.get("number", "")) != "":
		lines.add_child(_wrap_mono("Number: " + str(e.get("number", "")), 13, UIStyle.TEXT))
	lines.add_child(_wrap_mono("Contact: " + str(e.get("contact", "")), 13, UIStyle.TEXT))
	lines.add_child(_wrap_mono("Time: " + str(e.get("time", "")), 13, UIStyle.TEXT))
	lines.add_child(_wrap_mono("Ref: " + str(e.get("ref", "")), 13, UIStyle.TEXT))
	details.visible = open
	_tx_details[key] = details
	box.add_child(details)
	return box


## A History row toggles its details. An item's transfer counts as checking it ("tx:<id>") when opened.
func _on_tx_pressed(key: String) -> void:
	if session == null:
		return
	var open := not bool(_tx_open.get(key, false))
	_tx_open[key] = open
	if _tx_details.has(key):
		(_tx_details[key] as Control).visible = open
	if _tx_marks.has(key):
		var mark: Label = _tx_marks[key]
		mark.text = mark.text.substr(0, mark.text.length() - 1) + ("▴" if open else "▾")
	if open and key.begins_with("tx:"):
		inspected.emit(key)


func _inbox_notice(note: Dictionary) -> Control:
	var p := UIStyle.panel(UIStyle.PANEL_LIGHT, 10)
	var v := UIStyle.vbox(3)
	p.add_child(v)
	var title := UIStyle.label(str(note.get("title", "")), 15, UIStyle.TEXT)
	title.add_theme_font_override("font", DialoguePanel.bold_font())
	v.add_child(title)
	v.add_child(UIStyle.label(str(note.get("body", "")), 14, UIStyle.TEXT))
	v.add_child(_line(str(note.get("time", "")), 12, UIStyle.MUTED))
	return p


## The Report a scam sheet: static help text only. It never scores and never unlocks anything.
func _report_sheet() -> Control:
	var page: Dictionary = Campaign.PHONE_APP_PAGES.get("wallet_report", {})
	var p := UIStyle.panel(UIStyle.PANEL_LIGHT, 12)
	p.name = "WalletReportSheet"
	var v := UIStyle.vbox(6)
	p.add_child(v)
	var title := UIStyle.label(str(page.get("title", "")), 17, UIStyle.TEXT)
	title.add_theme_font_override("font", DialoguePanel.bold_font())
	v.add_child(title)
	for line: Variant in page.get("lines", []):
		v.add_child(UIStyle.label(str(line), 14, UIStyle.TEXT))
	var close := UIStyle.button(str(PHONE_TEXT.close), 14, UIStyle.PANEL)
	close.name = "WalletReportClose"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(_on_report_close)
	v.add_child(close)
	return p


func _on_wallet_tab(tab: String) -> void:
	if session == null:
		return
	_wallet_tab = tab
	_report_open = false
	_render_wallet()
	if tab == "inbox":
		inspected.emit("wallet_inbox")


func _on_wallet_report() -> void:
	if session == null:
		return
	_report_open = true
	_render_wallet()


func _on_report_close() -> void:
	_report_open = false
	call_deferred("_render_wallet")   # the Close button lives in the content being rebuilt


## base_balance plus every unlocked item's transfer (in adds, out subtracts); the text balance without a base.
func _wallet_balance() -> String:
	var wallet: Dictionary = session.chapter.get("wallet", {})
	if not wallet.has("base_balance"):
		return str(wallet.get("balance", ""))
	var total := float(wallet.get("base_balance", 0.0))
	for t: Dictionary in session.all_wallet_tx():
		var v := float(t.get("value", 0.0))
		total += v if str(t.get("dir", "in")) == "in" else -v
	return peso(total)


## "₱1,740.50" (two decimals, thousands commas).
static func peso(value: float) -> String:
	var cents := int(roundf(absf(value) * 100.0))
	var whole := str(int(cents / 100.0))
	var grouped := ""
	while whole.length() > 3:
		grouped = "," + whole.substr(whole.length() - 3) + grouped
		whole = whole.substr(0, whole.length() - 3)
	return "%s₱%s%s.%02d" % ["-" if value < 0.0 else "", whole, grouped, cents % 100]


## "Mon 07:30 PM" -> "19:30" ("" for anything else).
static func _clock_of(when: String) -> String:
	var m := _minutes_of(when)
	if m < 0:
		return ""
	return "%02d:%02d" % [int(m / 60.0), m % 60]


## Minutes after midnight of "07:30 PM" / "Mon 07:30 PM"; -1 if unreadable.
static func _minutes_of(when: String) -> int:
	var parts := when.strip_edges().split(" ", false)
	if parts.size() >= 3:
		parts = parts.slice(parts.size() - 2)
	if parts.size() != 2 or not parts[0].contains(":"):
		return -1
	var h := parts[0].get_slice(":", 0).to_int()
	var mi := parts[0].get_slice(":", 1).to_int()
	var pm := parts[1].to_upper() == "PM"
	if h == 12:
		h = 0
	if pm:
		h += 12
	return h * 60 + mi


## Sort key of a wallet time "Mon 07:28 PM" (Sunday first: the week of the story starts on Monday after it).
static func _time_key(when: String) -> int:
	var day := DAYS.find(when.get_slice(" ", 0))
	return maxi(day, 0) * 1440 + maxi(_minutes_of(when), 0)


# --- Calls ---

func _build_calls_view() -> Control:
	var panel := UIStyle.panel(UIStyle.PANEL, 12)
	var col := _scroll_column(panel, 10)
	var head := UIStyle.hbox(8)
	head.add_child(_tile(_app_glyph("calls"), _app_color("calls"), 30, 11, 8))
	head.add_child(_line("Calls", 18, UIStyle.TEXT))
	col.add_child(head)
	_calls_keypad = UIStyle.button(str(PHONE_TEXT.keypad), 17, UIStyle.GOOD.darkened(0.35))
	_calls_keypad.name = "CallsKeypad"
	_calls_keypad.custom_minimum_size.y = 46
	_calls_keypad.pressed.connect(_on_keypad_pressed)
	col.add_child(_calls_keypad)
	_calls_hint = UIStyle.label(str(PHONE_TEXT.keypad_idle), 14, UIStyle.MUTED)
	col.add_child(_calls_hint)
	col.add_child(DialoguePanel.section(str(PHONE_TEXT.recents), UIStyle.MUTED, 12))
	_calls_recents = UIStyle.vbox(6)
	col.add_child(_calls_recents)
	col.add_child(DialoguePanel.section(str(PHONE_TEXT.hotlines), UIStyle.MUTED, 12))
	for line: String in Campaign.PHONE_CARD_MOBILE:
		col.add_child(_wrap_mono(line, 14, UIStyle.TEXT))
	return panel


## A call waits to be placed: the selected item's step, or the first call item's step, waits for the telephone.
func _dial_ready() -> bool:
	if session == null:
		return false
	if session.waits_for_telephone():
		return true
	var id := session.phone_item()
	return id != "" and str(session.item_step(id).get("wait_for", "")) == "telephone"


func _render_calls() -> void:
	if session == null or _calls_keypad == null:
		return
	var can_dial := _dial_ready()
	_calls_keypad.disabled = not can_dial
	var waiting := ""
	if can_dial:
		var st := session.step() if session.waits_for_telephone() else session.item_step(session.phone_item())
		waiting = str(st.get("wait_objective", ""))
	_calls_hint.text = waiting if waiting != "" else str(PHONE_TEXT.keypad_idle)
	_calls_hint.add_theme_color_override("font_color", UIStyle.ACCENT if can_dial else UIStyle.MUTED)
	var recents := _recent_calls()
	var sig := str(recents)
	if sig == _recents_sig:
		return
	_recents_sig = sig
	for child: Node in _calls_recents.get_children():
		_calls_recents.remove_child(child)
		child.queue_free()
	if recents.is_empty():
		_calls_recents.add_child(_line(str(PHONE_TEXT.no_recents), 14, UIStyle.MUTED))
	for r: Array in recents:
		var p := UIStyle.panel(UIStyle.PANEL_LIGHT, 8)
		var v := UIStyle.vbox(1)
		p.add_child(v)
		v.add_child(_wrap_mono(str(r[0]), 14, UIStyle.TEXT))
		v.add_child(_line(str(r[1]), 12, UIStyle.MUTED))
		_calls_recents.add_child(p)


## Read-only rows [title, status], newest first: incoming call items so far and the hotline calls already placed.
func _recent_calls() -> Array:
	var out: Array = []
	for it: Dictionary in session.available_items():
		var id := str(it.get("id", ""))
		var call: Dictionary = it.get("call", {})
		if not call.is_empty():
			var status := str(PHONE_TEXT.call_answered)
			if session.phone_incoming() and session.phone_item() == id:
				status = str(PHONE_TEXT.call_ringing)
			out.push_front([str(call.get("caller_id", "")), str(PHONE_TEXT.call_in) + " · " + status])
		var steps: Array = it.get("steps", [])
		for si: int in steps.size():
			var st: Dictionary = steps[si]
			if not st.has("dial"):
				continue
			if session.is_done(id) or session.item_step_index(id) > si:
				out.push_front([str(st.get("call_header", st.get("dial", ""))), str(PHONE_TEXT.call_out)])
	return out


func _on_keypad_pressed() -> void:
	if session == null or not _dial_ready():
		return
	dial_requested.emit()


# --- Browser ---

## The phone Browser: address bar + Paste, bookmarks that wrap to the phone's width, and the page.
func _build_browser() -> Control:
	var panel := UIStyle.panel(UIStyle.PANEL, 10)
	var v := UIStyle.vbox(8)
	panel.add_child(v)
	var row := UIStyle.hbox(8)
	v.add_child(row)
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", UIStyle.box(Color("0b0f14"), 6, 8, UIStyle.PANEL_LIGHTER))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_address = _rich(14, true)
	_address.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_address.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	field.add_child(_address)
	row.add_child(field)
	var paste := UIStyle.button("Paste", 15, UIStyle.ACCENT.darkened(0.35))
	paste.tooltip_text = "Paste the copied link address (Ctrl+V)"
	paste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	paste.custom_minimum_size.x = 72
	paste.pressed.connect(_paste)
	row.add_child(paste)
	_paste_button = paste

	v.add_child(_line(str(PHONE_TEXT.bookmarks), 12, UIStyle.MUTED))
	var marks := HFlowContainer.new()
	marks.name = "Bookmarks"
	marks.add_theme_constant_override("h_separation", 6)
	marks.add_theme_constant_override("v_separation", 6)
	v.add_child(marks)
	for mark: Array in _bookmarks():
		var b := UIStyle.button(str(mark[1]), 13, UIStyle.PANEL_LIGHT)
		b.name = "Bookmark_" + str(mark[0])
		b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL_LIGHT, 6, 7))
		b.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.PANEL_LIGHTER, 6, 7, UIStyle.ACCENT))
		b.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL_LIGHTER, 6, 7, UIStyle.ACCENT))
		b.pressed.connect(_bookmark_pressed.bind(str(mark[0])))
		marks.add_child(b)

	_browser_info = UIStyle.label("", 14, UIStyle.WARN)
	_browser_info.visible = false
	v.add_child(_browser_info)

	var page := UIStyle.panel(UIStyle.BG, 12)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box = _scroll_column(page, 10)
	v.add_child(page)
	return panel


## A bookmark page on the phone: a brand band, table rows stacked as cards, then the lines. No inputs.
func _render_page(page_id: String, page: Dictionary) -> void:
	var title := str(page.get("title", ""))
	var parts := title.split(": ", true, 1)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UIStyle.box(PAGE_COLORS.get(page_id, UIStyle.ACCENT.darkened(0.35)), 6, 12))
	var band_col := UIStyle.vbox(2)
	band.add_child(band_col)
	band_col.add_child(UIStyle.label(parts[0], 18, Color.WHITE))
	if parts.size() > 1:
		band_col.add_child(UIStyle.label(parts[1], 14, Color(1, 1, 1, 0.85)))
	_page_box.add_child(band)
	if page.has("columns"):
		var columns: Array = page.get("columns", [])
		for r: Variant in page.get("rows", []):
			var cells: Array = r
			var card := UIStyle.panel(UIStyle.PANEL_LIGHT, 10)
			var cv := UIStyle.vbox(2)
			card.add_child(cv)
			for i: int in cells.size():
				if i == 0:
					var head := UIStyle.label(str(cells[i]), 15, UIStyle.TEXT)
					head.add_theme_font_override("font", DialoguePanel.bold_font())
					cv.add_child(head)
				else:
					var col_name := str(columns[i]) if i < columns.size() else ""
					cv.add_child(_wrap_mono("%s: %s" % [col_name, str(cells[i])], 13, UIStyle.MUTED))
			_page_box.add_child(card)
	for text: Variant in page.get("lines", []):
		_page_box.add_child(UIStyle.label(str(text), 15, UIStyle.TEXT))


# --- Toast ---

## Same toast as the desktop, kept inside the phone's width (long names wrap).
func _show_toast(text: String) -> void:
	if _toast == null:
		return
	var font := _toast_label.get_theme_font("font")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 4.0
	if width > TOAST_MAX_WIDTH:
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast_label.custom_minimum_size.x = TOAST_MAX_WIDTH
	else:
		_toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_toast_label.custom_minimum_size.x = 0
	super._show_toast(text)


# --- Small builders ---

## A monospace label that wraps anywhere (addresses, numbers), so it never widens the phone.
func _wrap_mono(text: String, size: int, color: Color) -> Label:
	var l := UIStyle.mono_label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 1
	return l
