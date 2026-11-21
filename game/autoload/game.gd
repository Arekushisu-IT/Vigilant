extends Node
## Session state: score, chapter progress and the score log.
## Lives only in memory. Nothing here is written to disk (paper Limitation 6).

signal score_changed(score: int, delta: int, reason: String)

## Scoring rules from the paper (FR7, GDD 9). Choices declare an outcome, never points.
const CORRECT := 10
const WRONG := -5
const UNSAFE := -5
const COMPLETE := 20
## One per chapter in Campaign.CHAPTERS (ten: six at the office, four off the clock). GDScript constants cannot
## call size(), so _ready() and the smoke test check that it matches the data.
const CHAPTER_COUNT := 10

var score: int = 0
var current_chapter: int = 1
var completed: Array[bool] = _fresh_completed()
var score_at_chapter_start: int = 0
var score_log: Array[Dictionary] = []
## True when the office is loaded from Restart Chapter, so the long intro is skipped.
var is_restart: bool = false
## Chapters restarted after a breach this session, and the achievement ids earned (scripts/core/achievements.gd).
var restarted: Array[int] = []
var achievements: Array[String] = []
## Chapter Select: the item a chapter should start at ("" = from the beginning), and whether the main menu should
## open straight on the chapter cards. Kept in memory only, like everything else here.
var jump_item: String = ""
var open_select: bool = false
## Session-only events log for the achievements (OTP Bantay, Hotline Hero, Not Your Mule): each entry is
## {"kind", "chapter", ...data}. Kinds: "misdial" {item, step, number, hotline}, "secret_shared" {item, step},
## "trap_failed" {item, step}. It never scores, is never saved, survives Restart Chapter (a game over still
## counts), is dropped per chapter on Chapter Select replay and is cleared on a new game.
var events: Array[Dictionary] = []


func _ready() -> void:
	if CHAPTER_COUNT != Campaign.CHAPTERS.size():
		push_error("Game.CHAPTER_COUNT (%d) != Campaign.CHAPTERS.size() (%d)" % [CHAPTER_COUNT, Campaign.CHAPTERS.size()])


func start_new_game() -> void:
	score = 0
	current_chapter = 1
	completed = _fresh_completed()
	score_log.clear()
	is_restart = false
	score_at_chapter_start = 0
	restarted.clear()
	achievements.clear()
	jump_item = ""
	events.clear()


## Adds one entry to the events log, tagged with its kind and the current chapter. Never changes the score.
func record_event(kind: String, data: Dictionary = {}) -> void:
	var e: Dictionary = data.duplicate()
	e["kind"] = kind
	e["chapter"] = current_chapter
	events.append(e)


## The logged events of one kind, in order.
func events_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## Call when a chapter's briefing starts. Snapshots the score for Restart Chapter.
func begin_chapter(n: int) -> void:
	current_chapter = n
	score_at_chapter_start = score


## Applies a choice outcome ("correct", "wrong" or "unsafe") and returns the delta.
## `item_id` names the chapter item the decision belongs to (TASKS-SPEC C.3); it is stored in the log entry.
func apply_outcome(outcome: String, step: int, choice_text: String, item_id: String = "") -> int:
	var delta := 0
	match outcome:
		"correct":
			delta = CORRECT
		"wrong":
			delta = WRONG
		"unsafe":
			delta = UNSAFE
		_:
			push_error("Unknown outcome: %s" % outcome)
			return 0
	_add(delta, step, choice_text, outcome, item_id)
	return delta


## Awards the +20 completion bonus once and marks the current chapter complete.
func complete_chapter() -> void:
	var i := current_chapter - 1
	if completed[i]:
		return
	completed[i] = true
	_add(COMPLETE, -1, "Chapter complete", "complete")


## True if there is another chapter after the current one; moves to it.
func next_chapter() -> bool:
	if current_chapter >= CHAPTER_COUNT:
		return false
	begin_chapter(current_chapter + 1)
	return true


## Chapter Select: (re)plays chapter n, optionally starting at one item. That chapter's earlier result is dropped
## (like Restart Chapter); other chapters' results stay, so the cards keep this run's progress. The long intro
## plays only for a first, plain Chapter 1.
func select_chapter(n: int, item_id: String = "") -> void:
	var first_run := score_log.is_empty() and not completed.has(true)
	score_log = score_log.filter(func(e: Dictionary) -> bool: return e.chapter != n)
	events = events.filter(func(e: Dictionary) -> bool: return int(e.get("chapter", 0)) != n)
	completed[n - 1] = false
	score = 0
	for e: Dictionary in score_log:
		score += int(e.delta)
	current_chapter = n
	score_at_chapter_start = score
	jump_item = item_id
	is_restart = not (n == 1 and item_id == "" and first_run)


## Rolls the score back to the chapter start and drops this chapter's log entries. The events log is kept.
func restart_chapter() -> void:
	score = score_at_chapter_start
	score_log = score_log.filter(func(e: Dictionary) -> bool: return e.chapter != current_chapter)
	completed[current_chapter - 1] = false
	is_restart = true
	if not restarted.has(current_chapter):
		restarted.append(current_chapter)
	score_changed.emit(score, 0, "restart")


## One false per chapter, sized from the data.
static func _fresh_completed() -> Array[bool]:
	var out: Array[bool] = []
	for i: int in CHAPTER_COUNT:
		out.append(false)
	return out


func all_complete() -> bool:
	return not completed.has(false)


func chapter_total(n: int) -> int:
	var total := 0
	for e: Dictionary in score_log:
		if e.chapter == n:
			total += int(e.delta)
	return total


func chapter_log(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in score_log:
		if e.chapter == n:
			out.append(e)
	return out


## Log entries of one item of chapter n, in order.
func item_log(n: int, item_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in score_log:
		if e.chapter == n and e.get("item", "") == item_id:
			out.append(e)
	return out


func item_total(n: int, item_id: String) -> int:
	var total := 0
	for e: Dictionary in item_log(n, item_id):
		total += int(e.delta)
	return total


## Best possible points of an item: CORRECT x the longest chain of correct decisions from step 0.
## Terminates because every next_step is greater than its own step index (TASKS-SPEC A.4 invariant 8).
func item_max(item: Dictionary) -> int:
	var steps: Array = item.get("steps", [])
	if steps.is_empty():
		return 0
	return _step_best(steps, 0)


## Sum of item_max over the chapter's items plus the completion bonus.
func chapter_max(n: int) -> int:
	var total := COMPLETE
	for it: Dictionary in Campaign.chapter(n).get("items", []):
		total += item_max(it)
	return total


## The best score of the whole game, computed from the data (never hard-coded).
func max_score() -> int:
	var total := 0
	for n: int in range(1, CHAPTER_COUNT + 1):
		total += chapter_max(n)
	return total


func _step_best(steps: Array, i: int) -> int:
	if i < 0 or i >= steps.size():
		return 0
	var st: Dictionary = steps[i]
	if st.get("kind", "choices") == "checklist":
		var after := 0
		if st.has("next_step") and int(st.next_step) > i:
			after = _step_best(steps, int(st.next_step))
		return CORRECT + after
	var best_next := 0
	var any_correct := false
	for c: Dictionary in st.get("choices", []):
		if c.get("outcome", "") != "correct":
			continue
		any_correct = true
		if c.has("next_step") and int(c.next_step) > i:
			best_next = maxi(best_next, _step_best(steps, int(c.next_step)))
	return CORRECT + best_next if any_correct else 0


func _add(delta: int, step: int, text: String, reason: String, item_id: String = "") -> void:
	score += delta
	score_log.append({"chapter": current_chapter, "item": item_id, "step": step, "choice": text, "delta": delta,
		"reason": reason})
	score_changed.emit(score, delta, reason)
