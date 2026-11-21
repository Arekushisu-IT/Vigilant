class_name ChapterSession
extends RefCounted
## Mutable state of the chapter being played (TASKS-SPEC.md C.2). A chapter holds several items (inbox entries,
## text threads, phone calls); each item keeps its own current step, inspections (Objective 5), disabled choices
## and checklist ticks. One item is "selected" at a time: the compatibility properties step_index / inspected /
## disabled and the step helpers read that item.
## Content dictionaries from Campaign are read-only; all changes live here.
## The clipboard is the in-game one, never the OS clipboard.

## The apps that hold listed items on the workstation or the phone (the rest are calls). "bank" is the phone's
## BancoNation app.
const DESKTOP_APPS: Array[String] = ["mail", "messages", "chat", "bank"]

var chapter: Dictionary
var item_id: String = ""             ## the selected item ("" = none)
var clipboard: String = ""           ## text copied with "Copy link address"
var pasted_url: String = ""          ## what the Browser address field shows after Paste
var page: String = ""                ## "" or a Campaign.PAGES id: the Browser page (chapter-wide)
## The phone app view a choice opened (chapter-wide, like `page`): "", "wallet", "wallet_inbox", "telco" or
## "bank" (Campaign.PHONE_APP_TARGETS). Set by the office on a choice's opens_app; read by PhoneUI.
var phone_app: String = ""

## Current step of the selected item (0 with none selected).
var step_index: int:
	get:
		var s := _state()
		return int(s.step) if not s.is_empty() else 0
	set(value):
		var s := _state()
		if not s.is_empty():
			s.step = value

## Inspection key -> true, for the selected item (a reference, so .has() works; a fresh {} with none selected).
var inspected: Dictionary:
	get:
		var s := _state()
		if s.is_empty():
			return {}
		return s.inspected

## Disabled choice indices of the selected item's current step (a reference; a fresh empty array with none).
var disabled: Array[int]:
	get:
		var s := _state()
		if s.is_empty():
			var none: Array[int] = []
			return none
		return s.disabled

## item id -> {"step", "inspected", "disabled", "ticks", "tried", "seen", "done"}
var _states: Dictionary = {}
## item id -> the item dictionary (read-only content)
var _items: Dictionary = {}


func _init(ch: Dictionary) -> void:
	chapter = ch
	for it: Dictionary in items():
		var id: String = it.get("id", "")
		var d: Array[int] = []
		var t: Array[int] = []
		_items[id] = it
		# An app the player opens from the home screen (kind "app") is never announced as new.
		var seen: bool = str(it.get("kind", "")) == "app"
		_states[id] = {"step": 0, "inspected": {}, "disabled": d, "ticks": t, "tried": [], "seen": seen, "done": false}


# =====================================================================================================
# Items
# =====================================================================================================

func items() -> Array:
	return chapter.get("items", [])


## Where the chapter is played: "office", "home" or "cafe".
func place() -> String:
	return str(chapter.get("place", "office"))


## True off the clock (home and cafe): the chapter is played on the smartphone.
func is_phone() -> bool:
	return place() != "office"


## "" = the selected item. {} if unknown or none selected.
func item(id: String = "") -> Dictionary:
	var key := item_id if id == "" else id
	if not _items.has(key):
		return {}
	return _items[key]


## That item's current step ({} if done or unknown).
func item_step(id: String) -> Dictionary:
	if not _items.has(id) or is_done(id):
		return {}
	var steps: Array = _items[id].get("steps", [])
	var i := item_step_index(id)
	if i < 0 or i >= steps.size():
		return {}
	return steps[i]


func item_step_index(id: String) -> int:
	if not _states.has(id):
		return 0
	return int(_states[id].step)


## True when every unlock_after id is resolved.
func is_unlocked(id: String) -> bool:
	if not _items.has(id):
		return false
	for dep: String in _items[id].get("unlock_after", []):
		if not is_done(dep):
			return false
	return true


func is_done(id: String) -> bool:
	return _states.has(id) and bool(_states[id].done)


## "locked" | "new" (unseen) | "open" | "done"
func status(id: String) -> String:
	if is_done(id):
		return "done"
	if not is_unlocked(id):
		return "locked"
	if not bool(_states[id].seen):
		return "new"
	return "open"


## Unlocked items (resolved ones included), in data order; only those of `app` when it is not "".
func available_items(app: String = "") -> Array:
	var out: Array = []
	for it: Dictionary in items():
		var id: String = it.get("id", "")
		if not is_unlocked(id):
			continue
		if app != "" and it.get("app", "") != app:
			continue
		out.append(it)
	return out


## Selects an item. False (and no change) if it is unknown or still locked.
func select_item(id: String) -> bool:
	if not _items.has(id) or not is_unlocked(id):
		return false
	item_id = id
	_states[id].seen = true
	return true


## The current step's surface ("desktop" or "call"); "" if the item is done or unknown.
func item_surface(id: String = "") -> String:
	var key := item_id if id == "" else id
	var st := item_step(key)
	if st.is_empty():
		return ""
	return st.get("surface", "desktop")


## First unlocked, unresolved item whose current step is on the desktop; "" if none.
func next_desktop_item() -> String:
	for it: Dictionary in items():
		var id: String = it.get("id", "")
		if is_unlocked(id) and not is_done(id) and item_surface(id) == "desktop":
			return id
	return ""


func desktop_pending() -> bool:
	return next_desktop_item() != ""


## Unlocked, unseen, unresolved Mail / Messages / Chat / bank-app items (the "N new" monitor label).
func new_desktop_count() -> int:
	var n := 0
	for it: Dictionary in items():
		var id: String = it.get("id", "")
		var app: String = it.get("app", "")
		if DESKTOP_APPS.has(app) and is_unlocked(id) and not is_done(id) and not bool(_states[id].seen):
			n += 1
	return n


## First unlocked, unresolved item whose current step is on the telephone; "" if none.
func phone_item() -> String:
	for it: Dictionary in items():
		var id: String = it.get("id", "")
		if is_unlocked(id) and not is_done(id) and item_surface(id) == "call":
			return id
	return ""


## The phone rings: a call item waits at step 0 (an incoming call, not a call the player places).
func phone_incoming() -> bool:
	var id := phone_item()
	if id == "":
		return false
	return item_step_index(id) == 0 and item_step(id).get("wait_for", "") == ""


## Link id -> real URL over every unlocked item.
func all_links() -> Dictionary:
	var out: Dictionary = {}
	for it: Dictionary in items():
		if not is_unlocked(it.get("id", "")):
			continue
		var links: Dictionary = it.get("message", {}).get("links", {})
		for k: String in links:
			out[k] = links[k]
	return out


## The item that owns a QR code id ("" if none). QR codes live in message.qrs {<qr id>: url}.
func qr_owner(qr_id: String) -> String:
	for it: Dictionary in items():
		var qrs: Dictionary = it.get("message", {}).get("qrs", {})
		if qrs.has(qr_id):
			return it.get("id", "")
	return ""


## The item that owns a link id ("" if none).
func link_owner(link_id: String) -> String:
	for it: Dictionary in items():
		var links: Dictionary = it.get("message", {}).get("links", {})
		if links.has(link_id):
			return it.get("id", "")
	return ""


## Every KwartaPay history entry of the unlocked items (resolved ones included), in data order. Each is a copy of
## message.wallet_tx[<tx id>] plus "id" (the tx id) and "item" (the owning item id).
func all_wallet_tx() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in items():
		var id: String = it.get("id", "")
		if not is_unlocked(id):
			continue
		var txs: Dictionary = it.get("message", {}).get("wallet_tx", {})
		for tx_id: String in txs:
			var e: Dictionary = (txs[tx_id] as Dictionary).duplicate()
			e["id"] = tx_id
			e["item"] = id
			out.append(e)
	return out


## The item that owns a KwartaPay history entry ("" if none).
func tx_owner(tx_id: String) -> String:
	for it: Dictionary in items():
		var txs: Dictionary = it.get("message", {}).get("wallet_tx", {})
		if txs.has(tx_id):
			return it.get("id", "")
	return ""


# =====================================================================================================
# The selected item's current step
# =====================================================================================================

## {} if none is selected or it is resolved.
func step() -> Dictionary:
	if item_id == "":
		return {}
	return item_step(item_id)


## The inspections that must be done before choices unlock. Only step 0 of an item is gated.
func required() -> Array:
	var it := item()
	if it.is_empty() or is_done(item_id) or step_index != 0:
		return []
	return it.get("required_inspections", [])


## required() minus what was inspected, in required_inspections order.
func missing() -> Array:
	var done := inspected
	return required().filter(func(k: String) -> bool: return not done.has(k))


func gate_open() -> bool:
	return missing().is_empty()


## The step-0 gate of any item, like required() for the selected one: [] once it is past step 0, resolved,
## locked or unknown.
func item_required(id: String) -> Array:
	if not _items.has(id) or is_done(id) or not is_unlocked(id) or item_step_index(id) != 0:
		return []
	return _items[id].get("required_inspections", [])


## Records an inspection. "link:<id>" / "qr:<id>" / "tx:<id>" are credited to the item that owns that link, QR
## code or KwartaPay history entry. "wallet_inbox" and "page:<id>" (shared phone views) are credited to every
## unlocked, unresolved item whose step-0 gate needs that key, plus the selected item. Any other key goes to the
## selected item. Returns true if anything was credited for the first time.
func mark(key: String) -> bool:
	var targets: Array[String] = []
	if key == "wallet_inbox" or key.begins_with("page:"):
		for it: Dictionary in items():
			var id: String = it.get("id", "")
			if item_required(id).has(key):
				targets.append(id)
		if item_id != "" and not targets.has(item_id):
			targets.append(item_id)
	else:
		var owner := ""
		if key.begins_with("link:"):
			owner = link_owner(key.substr(5))
		elif key.begins_with("qr:"):
			owner = qr_owner(key.substr(3))
		elif key.begins_with("tx:"):
			owner = tx_owner(key.substr(3))
		targets.append(owner if owner != "" else item_id)
	var fresh := false
	for target: String in targets:
		if not _states.has(target):
			continue
		var ins: Dictionary = _states[target].inspected
		if ins.has(key):
			continue
		ins[key] = true
		fresh = true
	return fresh


func is_disabled(index: int) -> bool:
	return disabled.has(index)


func disable_choice(index: int) -> void:
	var d := disabled
	if not d.has(index):
		d.append(index)


## Moves the selected item to step `next` and clears its disabled choices, ticks and tried reports.
func advance_to(next: int) -> void:
	var s := _state()
	if s.is_empty():
		return
	s.step = next
	(s.disabled as Array[int]).clear()
	(s.ticks as Array[int]).clear()
	(s.tried as Array).clear()


## True when the current step waits for the telephone before its choices appear.
func waits_for_telephone() -> bool:
	return step().get("wait_for", "") == "telephone"


## The number the keypad must dial for the current step: its "dial" key (a hotline such as "8700" or "1326"),
## else the extension in its call header ("EXT 2045: R. RAMOS" -> "2045"), else "".
func expected_number() -> String:
	var st := step()
	if st.has("dial"):
		return str(st.dial)
	var re := RegEx.create_from_string("EXT\\s*(\\d+)")
	var m := re.search(str(st.get("call_header", "")))
	return m.get_string(1) if m != null else ""


## Hint for the decision area (A.5): "Choose a response." when open; otherwise per the chapter's hint_level.
func gate_hint() -> String:
	if gate_open():
		return "Choose a response."
	match String(chapter.get("hint_level", "full")):
		"generic":
			return "Inspect before you decide."
		"none":
			return "Responses locked."
	var names: Array[String] = []
	for k: String in missing():
		names.append(_inspection_name(k))
	return "Inspect first: " + ", ".join(names)


## Marks the selected item resolved.
func resolve_current() -> void:
	var s := _state()
	if not s.is_empty():
		s.done = true


## Chapter Select: marks every item before `id` (in data order) and everything it waits on as skipped, so `id`
## is open at once. Skipped items count as resolved and score nothing. Returns the ids skipped.
func skip_to(id: String) -> Array[String]:
	var skipped: Array[String] = []
	if not _items.has(id):
		return skipped
	var wanted: Array[String] = [id]
	var i := 0
	while i < wanted.size():
		for dep: String in _items[wanted[i]].get("unlock_after", []):
			if not wanted.has(dep):
				wanted.append(dep)
		i += 1
	for it: Dictionary in items():
		var other: String = it.get("id", "")
		if other == id:
			break
		if not wanted.has(other):
			wanted.append(other)
	for other: String in wanted:
		if other != id and not bool(_states[other].done):
			_states[other].done = true
			_states[other].skipped = true
			skipped.append(other)
	return skipped


func is_skipped(id: String) -> bool:
	return _states.has(id) and bool(_states[id].get("skipped", false))


## Every item resolved = chapter complete.
func all_done() -> bool:
	for id: String in _states:
		if not bool(_states[id].done):
			return false
	return not _states.is_empty()


# =====================================================================================================
# Checklist (the selected item's current step)
# =====================================================================================================

func is_checklist() -> bool:
	return step().get("kind", "choices") == "checklist"


func ticks() -> Array[int]:
	var s := _state()
	if s.is_empty():
		var none: Array[int] = []
		return none
	return s.ticks


## Stores the ticks sorted (a typed copy; the stored array keeps its identity).
func set_ticks(t: Array[int]) -> void:
	var s := _state()
	if s.is_empty():
		return
	var stored: Array[int] = s.ticks
	var sorted := _sorted(t)
	stored.clear()
	stored.append_array(sorted)


## Ticked sets already submitted wrong (each a sorted Array[int]).
func tried() -> Array:
	var s := _state()
	if s.is_empty():
		return []
	return s.tried


## Not empty, not every box, valid indices, and not a set already submitted wrong.
func can_submit(t: Array[int]) -> bool:
	var n := _options().size()
	var sorted := _sorted(t)
	if sorted.is_empty() or sorted.size() >= n:
		return false
	for i: int in sorted:
		if i < 0 or i >= n:
			return false
	return not _was_tried(sorted)


## The one checklist hint string, used by both UIs.
func checklist_hint(t: Array[int] = []) -> String:
	var sorted := _sorted(t)
	var n := _options().size()
	if n > 0 and sorted.size() >= n:
		return "Tick only the real warning signs."
	if _was_tried(sorted):
		return "You already sent that report. Change your ticks."
	return "Tick every warning sign you found, then submit."


## {"correct": bool, "missed": Array[int], "decoys": Array[int]} (option indices).
func check(t: Array[int]) -> Dictionary:
	var sorted := _sorted(t)
	var opts := _options()
	var missed: Array[int] = []
	var decoys: Array[int] = []
	for i: int in opts.size():
		var real := bool(opts[i].get("real", false))
		if real and not sorted.has(i):
			missed.append(i)
		elif not real and sorted.has(i):
			decoys.append(i)
	return {"correct": missed.is_empty() and decoys.is_empty(), "missed": missed, "decoys": decoys}


func record_try(t: Array[int]) -> void:
	var s := _state()
	if s.is_empty():
		return
	var sorted := _sorted(t)
	if not _was_tried(sorted):
		(s.tried as Array).append(sorted)


## Feedback for a wrong report: explains each ticked decoy, gives only the NUMBER of missed signs.
func checklist_feedback(result: Dictionary) -> String:
	var opts := _options()
	var lines: Array[String] = ["Not quite: your report does not match the evidence."]
	for i: int in result.get("decoys", []):
		if i >= 0 and i < opts.size():
			var o: Dictionary = opts[i]
			lines.append("Not a warning sign: %s. %s" % [o.get("text", ""), o.get("why", "")])
	var missed: int = (result.get("missed", []) as Array).size()
	if missed > 0:
		lines.append("You missed %d warning sign(s). Look again at what you inspected and at the wording." % missed)
	lines.append("Change your ticks and submit again.")
	return "\n".join(lines)


## Score-log text of a report.
func checklist_log_text(result: Dictionary) -> String:
	if bool(result.get("correct", false)):
		return "Warning-sign report: correct"
	return "Warning-sign report: %d missed, %d wrongly ticked" % [
		(result.get("missed", []) as Array).size(), (result.get("decoys", []) as Array).size()]


# =====================================================================================================
# Tracking (Objective 7)
# =====================================================================================================

## Listed tasks in data order (A.7): [{"text", "done", "item"}].
func task_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in items():
		var id: String = it.get("id", "")
		if not is_unlocked(id):
			continue
		var done_item := is_done(id)
		var task_steps := _task_steps(it)
		if task_steps.is_empty():
			out.append({"text": String(it.get("task", "")), "done": done_item, "item": id})
			continue
		var cur := item_step_index(id)
		var steps: Array = it.get("steps", [])
		for k: int in task_steps.size():
			var s: int = task_steps[k]
			if not done_item and cur < s:
				continue
			var next_task: int = task_steps[k + 1] if k + 1 < task_steps.size() else -1
			var done := done_item or (next_task >= 0 and cur >= next_task)
			out.append({"text": String(steps[s].get("task", "")), "done": done, "item": id})
	return out


## Every task of every item, locked or not. Pure: the same on a fresh session.
func task_count() -> int:
	var n := 0
	for it: Dictionary in items():
		n += maxi(1, _task_steps(it).size())
	return n


func tasks_done() -> int:
	var n := 0
	for t: Dictionary in task_list():
		if bool(t.done):
			n += 1
	return n


## The task of the nearest step at or before `step` that has one, else item.task.
func task_label_for_step(id: String, step_i: int) -> String:
	var it := item(id) if id != "" else {}
	if it.is_empty():
		return ""
	var steps: Array = it.get("steps", [])
	var i := mini(step_i, steps.size() - 1)
	while i >= 0:
		var st: Dictionary = steps[i]
		if st.has("task"):
			return st.task
		i -= 1
	return it.get("task", "")


## HUD objective for the current situation. Off the clock it speaks of the smartphone; at the office it is
## unchanged.
func objective() -> String:
	if is_phone():
		return _phone_objective()
	if phone_incoming():
		return "Answer the ringing telephone"
	var ph := phone_item()
	if ph != "":
		return item_step(ph).get("wait_objective", "")
	var desk := next_desktop_item()
	if desk != "":
		match String(item(desk).get("app", "")):
			"messages":
				return "Check your messages at your workstation"
			"chat":
				return "Check your chat messages at your workstation"
		return "Check your email at your workstation"
	return ""


## objective() at home or at the cafe: the ringing phone, a call to place, or the chapter's own objective while
## a listed item is pending ("Check your chats").
func _phone_objective() -> String:
	if phone_incoming():
		return "Answer your ringing phone"
	var ph := phone_item()
	if ph != "":
		return item_step(ph).get("wait_objective", "")
	if next_desktop_item() != "":
		var text := str(chapter.get("objective", ""))
		return text if text != "" else "Check your phone"
	return ""


## What the game-over screen shows: the chapter, with the selected item's overrides.
func failure_context() -> Dictionary:
	var ctx := chapter.duplicate()
	var it := item()
	for k: String in ["bad_ending", "warning_signs", "tip"]:
		if it.has(k):
			ctx[k] = it[k]
	return ctx


# =====================================================================================================
# Internals
# =====================================================================================================

func _state() -> Dictionary:
	if item_id == "" or not _states.has(item_id):
		return {}
	return _states[item_id]


func _options() -> Array:
	return step().get("options", [])


func _task_steps(it: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var steps: Array = it.get("steps", [])
	for i: int in steps.size():
		if (steps[i] as Dictionary).has("task"):
			out.append(i)
	return out


func _sorted(t: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in t:
		var i := int(v)
		if not out.has(i):
			out.append(i)
	out.sort()
	return out


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


func _was_tried(sorted: Array[int]) -> bool:
	for prev: Variant in tried():
		if _same(prev as Array, sorted):
			return true
	return false


func _inspection_name(k: String) -> String:
	if k.begins_with("link:"):
		return "link (copy it and paste it in the Browser)"
	if k.begins_with("qr:"):
		return "QR code link (preview it)"
	if k.begins_with("tx:"):
		return "the KwartaPay history entry"
	if k.begins_with("page:"):
		var pages: Dictionary = Campaign.PAGES
		var page_id := k.substr(5)
		if pages.has(page_id) and str(pages[page_id].get("title", "")) != "":
			return "the " + str(pages[page_id].title) + " page"
		return "the page"
	match k:
		"wallet_inbox":
			return "the KwartaPay inbox"
		"app_info":
			return "the app details"
		"profile":
			return "profile"
		"request":
			return "request"
		"sender_number":
			return "sender number"
		"caller_id":
			return "caller ID"
		"quote":
			return "forwarded message details"
	return k
