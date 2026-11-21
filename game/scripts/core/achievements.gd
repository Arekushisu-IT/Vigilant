class_name Achievements
extends RefCounted
## Badges and achievements (reward system, extends Objective 7's performance tracking).
## A chapter badge is earned when the chapter is completed; it gets a "flawless" star when the chapter's
## log has no wrong or unsafe choice. Achievements are judged from Game's score log, except OTP Bantay, Hotline
## Hero and Not Your Mule, which read Game's session events log (it survives Restart Chapter).
## Everything lives in Game for the current session only: nothing is saved (paper Limitation 6).

## One badge per chapter, in chapter order: {title, short (icon initials)}. badge(n) adds the desc from the
## chapter data, so a reorder can never make the numbers drift.
const BADGES: Array[Dictionary] = [
	{"title": "Phish Spotter", "short": "PS"},
	{"title": "Text Guard", "short": "TG"},
	{"title": "Wallet Watcher", "short": "WW"},
	{"title": "Call Screener", "short": "CS"},
	{"title": "Hang-Up Hero", "short": "HU"},
	{"title": "Payment Protector", "short": "PP"},
	{"title": "Profile Checker", "short": "PC"},
	{"title": "Sideline Skeptic", "short": "SS"},
	{"title": "QR Inspector", "short": "QR"},
	{"title": "Identity Keeper", "short": "IK"},
]

## Achievements in display order. "final" ones are only judged once every chapter is complete.
const LIST: Array[Dictionary] = [
	{"id": "first_day", "title": "First Day Survivor", "desc": "Complete Chapter 1.", "final": false},
	{"id": "clean_sweep", "title": "Clean Sweep", "desc": "Complete a chapter without a single wrong choice.", "final": false},
	{"id": "comeback", "title": "Comeback", "desc": "Complete a chapter after restarting it from a breach.", "final": false},
	{"id": "eagle_eye", "title": "Eagle Eye", "desc": "Get every red-flag checklist right on the first try.", "final": true},
	{"id": "no_false_alarms", "title": "No False Alarms", "desc": "Handle every genuine message correctly the first time.", "final": true},
	{"id": "good_colleague", "title": "Good Colleague", "desc": "Give every coworker, friend and family member the right advice on the first try.", "final": true},
	{"id": "fully_vigilant", "title": "Fully Vigilant", "desc": "Finish all chapters with the maximum score and no restarts.", "final": true},
	{"id": "otp_bantay", "title": "OTP Bantay", "desc": "Never share an OTP or MPIN.", "final": true},
	{"id": "hotline_hero", "title": "Hotline Hero", "desc": "Dial every official hotline right on the first try.", "final": true},
	{"id": "not_your_mule", "title": "Not Your Mule", "desc": "Turn down the wrong-send and rent-your-account traps on the first try.", "final": true},
]


## The Game autoload, looked up at run time (scripts compiled before autoloads exist, like the smoke test,
## cannot name it directly).
static func _g() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Game")


## Badge n (1-based) as {title, short, desc}; desc is "Completed Chapter n: <chapter title>".
static func badge(n: int) -> Dictionary:
	if n > BADGES.size():
		push_error("Achievements.badge(%d): only %d badges" % [n, BADGES.size()])
	var i := clampi(n, 1, BADGES.size())
	var b: Dictionary = BADGES[i - 1].duplicate()
	var title := ""
	if i <= Campaign.CHAPTERS.size():
		title = str(Campaign.chapter(i).get("title", ""))
	b["desc"] = "Completed Chapter %d: %s" % [i, title]
	return b


static func info(id: String) -> Dictionary:
	for a: Dictionary in LIST:
		if a.id == id:
			return a
	return {}


## True when chapter n is complete and its log has no wrong or unsafe choice.
static func chapter_flawless(n: int) -> bool:
	if not _g().completed[n - 1]:
		return false
	for e: Dictionary in _g().chapter_log(n):
		if e.reason == "wrong" or e.reason == "unsafe":
			return false
	return true


## Judges every achievement against the current Game state, adds the newly earned ones to
## _g().achievements and returns their ids (in LIST order).
static func unlock_new() -> Array[String]:
	var fresh: Array[String] = []
	for a: Dictionary in LIST:
		if _g().achievements.has(a.id):
			continue
		if bool(a.final) and not _g().all_complete():
			continue
		if _earned(a.id):
			_g().achievements.append(a.id)
			fresh.append(a.id)
	return fresh


static func _earned(id: String) -> bool:
	match id:
		"first_day":
			return _g().completed[0]
		"clean_sweep":
			for n: int in range(1, _g().CHAPTER_COUNT + 1):
				if chapter_flawless(n):
					return true
			return false
		"comeback":
			for n: int in _g().restarted:
				if _g().completed[n - 1]:
					return true
			return false
		"eagle_eye":
			return _all_first_try(func(it: Dictionary, st: Dictionary) -> bool: return st.get("kind", "") == "checklist")
		"no_false_alarms":
			for n: int in range(1, _g().CHAPTER_COUNT + 1):
				for it: Dictionary in Campaign.chapter(n).get("items", []):
					if it.get("role", "") == "genuine" and _has_mistake(n, str(it.id)):
						return false
			return true
		"good_colleague":
			return _all_first_try(func(it: Dictionary, _st: Dictionary) -> bool: return it.get("role", "") == "coworker")
		"fully_vigilant":
			return _g().restarted.is_empty() and _g().score == _g().max_score()
		"otp_bantay":
			return _g().events_of("secret_shared").is_empty()
		"hotline_hero":
			for e: Dictionary in _g().events_of("misdial"):
				if bool(e.get("hotline", false)):
					return false
			return true
		"not_your_mule":
			return _g().events_of("trap_failed").is_empty()
	return false


## True when, for every step the filter selects, the first logged answer to that step was correct.
static func _all_first_try(select: Callable) -> bool:
	for n: int in range(1, _g().CHAPTER_COUNT + 1):
		for it: Dictionary in Campaign.chapter(n).get("items", []):
			var steps: Array = it.get("steps", [])
			for i: int in steps.size():
				if not select.call(it, steps[i]):
					continue
				for e: Dictionary in _g().item_log(n, str(it.id)):
					if int(e.step) == i:
						if e.reason != "correct":
							return false
						break
	return true


static func _has_mistake(n: int, item_id: String) -> bool:
	for e: Dictionary in _g().item_log(n, item_id):
		if e.reason == "wrong" or e.reason == "unsafe":
			return true
	return false


## A round badge icon: the badge initials in a circle, gold when flawless, accent when earned, dim when not.
static func badge_icon(n: int, earned: bool, flawless: bool, size: int = 56) -> Control:
	var color := UIStyle.WARN if flawless else (UIStyle.ACCENT if earned else UIStyle.PANEL_LIGHTER)
	var circle := PanelContainer.new()
	var sb := UIStyle.box(Color(color, 0.25 if earned else 0.4), size / 2, 0, color if earned else Color(UIStyle.MUTED, 0.4))
	circle.add_theme_stylebox_override("panel", sb)
	circle.custom_minimum_size = Vector2(size, size)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := UIStyle.label(str(badge(n).short) if earned else "?", int(size * 0.36), Color.WHITE if earned else UIStyle.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(text)
	circle.tooltip_text = "%s%s" % [badge(n).title, " (flawless)" if flawless else ""]
	return circle
