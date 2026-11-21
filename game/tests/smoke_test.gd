extends SceneTree
## Headless smoke test for the whole prototype (Objectives 1-7 end to end), task model of TASKS-SPEC.md (D.2, D.3).
## Run: Godot --headless --path <game> --script res://tests/smoke_test.gd
## Everything is driven from the Campaign data: items are played in data order, choices are found by outcome,
## checklist ticks by the options' `real` flags. Scenario (h) presses the real on-screen controls.
## The ten-chapter week runs in one office scene: office chapters on the workstation and the desk phone, home and
## cafe chapters (3, 5, 8, 10) on the smartphone (PhoneUI: list -> detail apps, KwartaPay, bookmarks, Calls keypad).
## Autoloads are looked up at run time, and scripts that name an autoload (TitleCard, PhoneUI, LocationBuilder) are
## only loaded at run time, because this --script is compiled before the autoload names exist.

const OFFICE := "res://scenes/office.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const ENDING := "res://scenes/ending.tscn"
const TOTAL_TIMEOUT := 1500.0
const WAIT_TIMEOUT := 15.0

## States in which the driver presses "advance" to move dialogue, outcomes and feedback forward.
const ADVANCE_STATES: Array[String] = ["INTRO", "BRIEFING", "OUTCOME", "FEEDBACK"]
## One work week: office chapters 1, 2, 4, 6, 7, 9 and off-the-clock chapters 3, 5 (home) and 8, 10 (cafe).
const TITLES: Array[String] = ["Email Phishing", "Smishing", "E-wallet Texts", "Vishing", "The Bank Agent",
	"Business Email Compromise", "Social Media Impersonation", "The Easy Sideline", "QR Code Phishing", "Who Are You?"]
const CHAPTERS := 10
## TASKS-SPEC header table / B.4, the 2026-11-03 addenda and the PH chapters (docs/PH-CHAPTERS-SCRIPT.md). The old
## office chapters keep their values at their new positions (1, 2, 4, 6, 7, 9).
const SPEC_MAX := 800
const SPEC_CHAPTER_MAX: Array[int] = [80, 80, 80, 90, 80, 90, 80, 70, 80, 70]
const SPEC_TASKS: Array[int] = [5, 6, 6, 7, 6, 7, 6, 5, 5, 5]
const SPEC_TASKS_TOTAL := 58
const SPEC_WRONG_FIRST: Array[int] = [30, 20, 35, 25, 30, 20, 20, 35, 20, 35]
const SPEC_WRONG_FIRST_TOTAL := 270
const KEYS: Array[String] = ["email", "smishing", "ewallet", "vishing", "bank_agent", "bec", "social", "sideline", "qr",
	"identity"]
const PLACES: Array[String] = ["office", "office", "home", "office", "home", "office", "office", "cafe", "office", "cafe"]
const HINT_LEVELS: Array[String] = ["full", "full", "full", "generic", "generic", "generic", "generic", "none", "none",
	"none"]
## decisions.md item 12.
const MUSIC: Array[String] = ["day", "day", "day", "drive", "night", "drive", "night", "day", "night", "night"]
## Choices that give away an OTP or MPIN (OTP Bantay): the five agreed in the plan, plus the office c5_otp
## "Send them the code" (decisions.md item 6).
const SECRET_CHOICES := {
	"c8_ayuda": "Tap the link and log in with your MPIN to claim",
	"c8_migo": "Tell him to give it, since it's just to deposit the prize",
	"c7_otp": "Forward the code to a friend to check if it's real",
	"c7_agent": "Read him the code",
	"c7_tita": "Tell her to give it, since he knows her name",
	"c5_otp": "Send them the code so they can finish setting up",
}
const MULE_ITEMS: Array[String] = ["c8_wrongsend", "c9_mule"]
const FACT_COUNT := 15
const FORBIDDEN: Array[String] = ["login page", "log-in page", "sign-in page", "sign in page", "download", "attachment",
	"advertisement", "pop-up", "software update", "install", "usb", "malware", "virus"]
const BRITISH: Array[String] = ["enrolment", "favour", "misspelt", "colour", "behaviour", "cancelled"]

var _failures := 0
var _passes := 0
var _start_ms := 0
## Autoloads, looked up at run time (the main --script is compiled before autoload names exist).
var game: Node
var router: Node


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	game = root.get_node("/root/Game")
	router = root.get_node("/root/Router")
	# The headless window starts at 64x64 (visible rect 1280x1280 with the "expand" aspect); the game runs at
	# 1280x720 (project settings), so the layout checks (k) need the real window size.
	root.size = Vector2i(1280, 720)
	await process_frame
	_check(_view().size == Vector2(1280, 720), "viewport is 1280x720 (%s)" % _view().size)
	await _test_menus()
	await _test_fun_facts_menu()
	await _test_game_feel()
	_test_data()
	_test_fun_facts_data()
	await _test_best_run()
	await _test_wrong_first_run()
	await _test_unsafe_and_restart()
	await _test_home_restart()
	await _test_coworker_unsafe()
	await _test_chapter_select()
	await _test_tutorial()
	await _test_chapter1_rules()
	await _test_office_life()
	await _test_ui_run()
	await _test_ui_late_chapters()
	# Unload the office and give the audio thread time to drop the ring tone playback before quitting.
	if current_scene != null:
		current_scene.queue_free()
	await create_timer(0.3).timeout
	print("")
	print("SUMMARY: %d passed, %d failed (%.1f s)" % [_passes, _failures, _elapsed()])
	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED")
		quit(1)


# =====================================================================================================
# Scenarios
# =====================================================================================================

func _test_menus() -> void:
	print("--- menus: main_menu.tscn and ending.tscn instantiate")
	for path: String in [MAIN_MENU, ENDING]:
		var packed := load(path) as PackedScene
		_check(packed != null, "load %s" % path)
		if packed == null:
			continue
		var node := packed.instantiate()
		_check(node != null, "instantiate %s" % path)
		if node == null:
			continue
		root.add_child(node)
		await process_frame
		await process_frame
		_check(node.get_child_count() > 0, "%s built its UI in _ready()" % path)
		node.queue_free()
		await process_frame


## The main menu's Fun Facts page: every fact listed (reading only), Back inside the window, ESC returns.
func _test_fun_facts_menu() -> void:
	print("--- FUN FACTS MENU: the main menu's Fun Facts page")
	if not await _wait(func() -> bool: return not router.is_busy(), "Router idle"):
		return
	game.start_new_game()
	change_scene_to_file(MAIN_MENU)
	await _expect_scene(MAIN_MENU)
	var menu := current_scene
	if menu == null:
		return
	await _frames(2)
	var button := menu.find_child("FunFactsButton", true, false) as Button
	_check(button != null and button.text == "Fun Facts", "main menu has a Fun Facts button")
	var score0: int = game.score
	menu.call("_show_fun_facts")
	await _frames(3)
	var panel := menu.find_child("FunFacts", true, false) as Control
	_check(panel != null and panel.is_visible_in_tree(), "Fun Facts page shown")
	if panel == null:
		return
	var list := panel.find_child("FactList", true, false)
	var rows := list.find_children("Fact_*", "", true, false) if list != null else []
	_check(rows.size() == FACT_COUNT, "Fun Facts page lists %d facts (%d)" % [FACT_COUNT, rows.size()])
	var shown := _visible_text(panel)
	var f0: Dictionary = FunFacts.all()[0]
	_check(shown.contains(FunFacts.display_text(f0)) and shown.contains(FunFacts.source_line(f0)), "a fact row shows its text and source")
	_check(_in_view(_find_button(panel, "Back")), "k Fun Facts Back inside the viewport")
	_check(game.score == score0 and game.score_log.is_empty(), "reading Fun Facts never scores")
	var esc := InputEventAction.new()
	esc.action = "back"
	esc.pressed = true
	root.push_input(esc)
	await _frames(2)
	_check(not panel.visible, "ESC closes the Fun Facts page")


## Game feel: the Audio autoload and its buses, the Music / Sound effects sliders, and both volumes persisting.
func _test_game_feel() -> void:
	print("--- game feel: audio buses, volume sliders, settings persistence")
	var audio := root.get_node_or_null("/root/Audio")
	_check(audio != null and audio.has_method("play_sfx") and audio.has_method("set_music") and audio.has_method("stop_music"), "Audio autoload exists with play_sfx / set_music / stop_music")
	_check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0, "Music and SFX buses exist")
	if audio != null:
		audio.play_sfx("correct")          # headless: a safe no-op
		var tracks: Array[String] = []
		var data_music: Array[String] = []
		for n: int in range(1, CHAPTERS + 1):
			tracks.append(str(audio.track_for_chapter(n)))
			data_music.append(str(Campaign.chapter(n).get("music", "")))
		_check(tracks == MUSIC and data_music == MUSIC, "music per chapter %s (Audio %s, data %s)" % [MUSIC, tracks, data_music])
	var settings := root.get_node("/root/Settings")
	# Loaded at run time: the panel's script names the Settings autoload, which this script cannot see at compile time.
	var panel: Control = (load("res://scripts/ui/settings_panel.gd") as GDScript).new()
	root.add_child(panel)
	await process_frame
	var music := panel.find_child("MusicSlider", true, false) as HSlider
	var sfx := panel.find_child("SfxSlider", true, false) as HSlider
	_check(music != null and sfx != null and panel.find_child("MasterSlider", true, false) != null, "settings panel has Master, Music and Sound effects sliders")
	var keep: Array = [settings.music_volume, settings.sfx_volume, settings.master_volume, settings.sensitivity, settings.fullscreen]
	if music != null and sfx != null:
		music.value = 30
		sfx.value = 65
		_check(is_equal_approx(settings.music_volume, 0.3) and is_equal_approx(settings.sfx_volume, 0.65), "the sliders write Settings.music_volume / sfx_volume")
		var cfg := ConfigFile.new()
		var ok: bool = cfg.load(settings.PATH) == OK
		_check(ok and is_equal_approx(float(cfg.get_value("audio", "music_volume", -1.0)), 0.3) and is_equal_approx(float(cfg.get_value("audio", "sfx_volume", -1.0)), 0.65), "music and SFX volumes saved to settings.cfg")
		settings.music_volume = 0.0
		settings.sfx_volume = 0.0
		settings.load_settings()
		_check(is_equal_approx(settings.music_volume, 0.3) and is_equal_approx(settings.sfx_volume, 0.65), "music and SFX volumes load back from settings.cfg")
		settings.reset_to_defaults()
		_check(is_equal_approx(settings.music_volume, settings.DEFAULT_MUSIC) and is_equal_approx(settings.sfx_volume, settings.DEFAULT_SFX) and is_equal_approx(music.value, settings.DEFAULT_MUSIC * 100.0), "Reset to defaults covers music and SFX volumes")
	# Put the player's own preferences back.
	settings.music_volume = keep[0]
	settings.sfx_volume = keep[1]
	settings.master_volume = keep[2]
	settings.sensitivity = keep[3]
	settings.set_fullscreen(keep[4])
	panel.queue_free()
	await process_frame


## (i) Data validation: the 14 invariants of TASKS-SPEC A.4 plus the chapter facts.
func _test_data() -> void:
	print("--- (i) DATA: Campaign invariants")
	var chapters: Array = Campaign.CHAPTERS
	_check(chapters.size() == CHAPTERS, "exactly ten chapters (%d)" % chapters.size())
	_check(int(game.CHAPTER_COUNT) == chapters.size(), "Game.CHAPTER_COUNT == Campaign.CHAPTERS.size() (%d)" % game.CHAPTER_COUNT)
	var spec_sum := 0
	for v: int in SPEC_CHAPTER_MAX:
		spec_sum += v
	var task_sum := 0
	for v: int in SPEC_TASKS:
		task_sum += v
	var wrong_sum := 0
	for v: int in SPEC_WRONG_FIRST:
		wrong_sum += v
	_check(spec_sum == SPEC_MAX and task_sum == SPEC_TASKS_TOTAL and wrong_sum == SPEC_WRONG_FIRST_TOTAL,
		"spec sums: max %d == %d, tasks %d == %d, wrong-first %d == %d" % [spec_sum, SPEC_MAX, task_sum, SPEC_TASKS_TOTAL, wrong_sum, SPEC_WRONG_FIRST_TOTAL])
	var link_ids: Dictionary = {}
	var qr_ids: Dictionary = {}
	var tx_ids: Dictionary = {}
	var item_ids: Dictionary = {}
	var chapter_keys: Dictionary = {}
	var maxes: Array[int] = []
	var tasks: Array[int] = []
	var hints: Array[String] = []
	var places: Array[String] = []
	var secret_choices: Dictionary = {}
	var mule_items: Array[String] = []
	for n: int in range(1, CHAPTERS + 1):
		var ch := Campaign.chapter(n)
		var place := str(ch.get("place", ""))
		_check(str(ch.get("title", "")) == TITLES[n - 1], "chapter %d is %s (%s)" % [n, TITLES[n - 1], ch.get("title", "")])
		_check(int(ch.get("id", 0)) == n, "chapter %d id" % n)
		hints.append(str(ch.get("hint_level", "")))
		places.append(place)
		# Chapter keys that drive every per-chapter table (title card, Chapter Select, music, lighting).
		var missing_keys: Array[String] = []
		for k: String in ["key", "place", "when", "attack", "music", "mood", "device", "app", "hint_level", "objective"]:
			if str(ch.get(k, "")) == "":
				missing_keys.append(k)
		_check(missing_keys.is_empty(), "ch%d has key, place, when, attack, music, mood, device, app, hint_level, objective %s" % [n, missing_keys])
		_check(str(ch.get("key", "")) == KEYS[n - 1] and not chapter_keys.has(ch.get("key", "")), "ch%d key %s is unique (%s)" % [n, KEYS[n - 1], ch.get("key", "")])
		chapter_keys[ch.get("key", "")] = true
		var mood := str(ch.get("mood", ""))
		_check(mood.begins_with(place + "_"), "ch%d mood %s belongs to the %s" % [n, mood, place])
		if place == "office":
			_check(str(ch.device) in ["workstation", "telephone"] and not ch.has("wallet") and not ch.has("breach_title"),
				"ch%d (office) device %s, no wallet, no breach_title" % [n, ch.device])
		else:
			_check(str(ch.device) == "phone", "ch%d (%s) is played on the phone (%s)" % [n, place, ch.device])
			var wallet: Dictionary = ch.get("wallet", {})
			_check(not wallet.is_empty() and wallet.has("base_balance") and not (wallet.get("history", []) as Array).is_empty() \
					and not (wallet.get("inbox", []) as Array).is_empty() and str(ch.get("breach_title", "")).begins_with("GAME OVER"),
				"ch%d (%s) has a wallet (base_balance, history, inbox) and a breach_title" % [n, place])
			var off_text := " ".join([str(ch.get("bad_ending", "")), str(ch.get("breach_title", "")), str(ch.get("debrief", "")), str(ch.get("tip", ""))])
			_check(not off_text.contains("Black Veil") and not off_text.contains("Aegis"), "ch%d (%s): the endings never name Black Veil or Aegis" % [n, place])
		var mains := 0
		var items: Array = ch.get("items", [])
		var earlier: Array[String] = []
		for it: Dictionary in items:
			var id: String = it.get("id", "")
			if str(it.get("role", "")) == "main":
				mains += 1
			_check(not item_ids.has(id), "item id %s unique" % id)
			item_ids[id] = true
			_check_item(n, it, earlier)
			for lid: String in (it.get("message", {}) as Dictionary).get("links", {}):
				_check(not link_ids.has(lid), "link id %s unique" % lid)
				link_ids[lid] = true
			for qid: String in (it.get("message", {}) as Dictionary).get("qrs", {}):
				_check(not qr_ids.has(qid) and not link_ids.has(qid), "qr id %s unique" % qid)
				qr_ids[qid] = true
			for tid: String in (it.get("message", {}) as Dictionary).get("wallet_tx", {}):
				_check(not tx_ids.has(tid) and not link_ids.has(tid) and not qr_ids.has(tid), "tx id %s unique" % tid)
				tx_ids[tid] = true
			if str(it.get("trap", "")) == "mule":
				mule_items.append(id)
			for st: Dictionary in it.get("steps", []):
				for c: Dictionary in st.get("choices", []):
					if bool(c.get("shares_secret", false)):
						_check(not secret_choices.has(id), "one shares_secret choice in %s" % id)
						secret_choices[id] = str(c.text)
			earlier.append(id)
		_check(mains == 1, "chapter %d has exactly one main item (%d)" % [n, mains])
		# Role order (decisions.md item 14): genuine, main, a fake before the help item, only genuine after it.
		var roles: Array[String] = []
		for it: Dictionary in items:
			roles.append(str(it.get("role", "")))
		var cw := roles.find("coworker")
		var fake := roles.find("fake")
		var after_ok := true
		for i: int in range(cw + 1, roles.size()):
			after_ok = after_ok and roles[i] == "genuine"
		_check(roles.size() >= 4 and roles[0] == "genuine" and roles[1] == "main" and fake > 1 and cw > fake and after_ok,
			"ch%d role order genuine, main, fake, help(, genuine) %s" % [n, roles])
		# The new chapters are chain-locked: each item waits on an earlier one (the old office chapters keep theirs).
		if place != "office":
			var chained := true
			for i: int in range(1, items.size()):
				chained = chained and not (items[i].get("unlock_after", []) as Array).is_empty()
			_check(chained, "ch%d (%s): every item after the first is chain-locked" % [n, place])
		for it: Dictionary in items:
			if str(it.get("role", "")) == "coworker":
				var label := str(it.get("helper_label", ""))
				_check((place == "office" and label == "") or (place != "office" and label in ["Family", "Friend"]),
					"ch%d %s helper_label '%s'" % [n, it.id, label])
		# Invariant 4: call items form an unlock chain.
		var calls: Array[Dictionary] = []
		for it: Dictionary in items:
			for st: Dictionary in it.get("steps", []):
				if str(st.get("surface", "desktop")) == "call":
					calls.append(it)
					break
		for i: int in range(1, calls.size()):
			_check(_depends_on(items, str(calls[i].id), str(calls[i - 1].id)),
				"inv4: call item %s transitively unlocks after %s" % [calls[i].id, calls[i - 1].id])
		maxes.append(int(game.chapter_max(n)))
		tasks.append(ChapterSession.new(ch).task_count())
	for lid: String in link_ids:
		_check(not item_ids.has(lid), "inv5: link id %s differs from every item id" % lid)
	for qid: String in qr_ids:
		_check(not item_ids.has(qid) and not link_ids.has(qid), "inv5: qr id %s differs from every item and link id" % qid)
	_check(maxes == SPEC_CHAPTER_MAX, "Game.chapter_max = %s (%s)" % [SPEC_CHAPTER_MAX, maxes])
	_check(int(game.max_score()) == SPEC_MAX, "Game.max_score() == %d (%d)" % [SPEC_MAX, game.max_score()])
	_check(tasks == SPEC_TASKS, "task_count() = %s (%s)" % [SPEC_TASKS, tasks])
	_check(hints == HINT_LEVELS, "hint levels %s (%s)" % [HINT_LEVELS, hints])
	_check(places == PLACES, "places %s (%s)" % [PLACES, places])
	_check(Campaign.PHONE_CARD.size() == 4, "phone card lists four extensions")
	_check(Campaign.PHONE_CARD_MOBILE.size() == 3, "the phone's hotline card lists three numbers")
	_check(not (load("res://data/campaign.gd") as GDScript).get_script_constant_map().has("MAX_SCORE"),
		"Campaign.MAX_SCORE removed (max is computed)")
	_check(Campaign.chapter(7).app == "chat" and Campaign.chapter(7).hint_level == "generic" and Campaign.chapter(9).hint_level == "none",
		"Ch7 lives in Chat; Ch7 generic, Ch9 none")
	_check(Achievements.BADGES.size() == int(game.CHAPTER_COUNT), "one badge per chapter (%d)" % Achievements.BADGES.size())
	var badge_ok := true
	for n: int in range(1, CHAPTERS + 1):
		badge_ok = badge_ok and str(Achievements.badge(n).desc) == "Completed Chapter %d: %s" % [n, TITLES[n - 1]]
	_check(badge_ok, "badge descs follow the chapter data")
	for id: String in ["otp_bantay", "hotline_hero", "not_your_mule"]:
		_check(bool(Achievements.info(id).get("final", false)), "achievement %s exists and is final" % id)
	_check(Achievements.LIST.size() == 10, "ten achievements (%d)" % Achievements.LIST.size())
	# Title card times: TitleCard is loaded at run time (a compile-time name would pull its UI dependencies in).
	var title_card: GDScript = load("res://scripts/ui/title_card.gd")
	var times_ok := true
	for n: int in range(1, CHAPTERS + 1):
		times_ok = times_ok and str(title_card.call("time_of", n)) == str(Campaign.chapter(n).when)
	_check(times_ok, "TitleCard.time_of(n) == chapter n's when")
	var opens_ok := true
	var apps_ok := true
	var dial_ok := true
	var dial_steps := 0
	for ch: Dictionary in chapters:
		for it: Dictionary in ch.items:
			for st: Dictionary in it.steps:
				for c: Dictionary in st.get("choices", []):
					if c.has("opens") and not Campaign.PAGES.has(str(c.opens)):
						opens_ok = false
					if c.has("opens_app") and (not Campaign.PHONE_APP_TARGETS.has(str(c.opens_app)) or str(ch.place) == "office"):
						apps_ok = false
				if st.has("dial"):
					dial_steps += 1
					var number := str(st.dial)
					var on_card := false
					for line: String in Campaign.PHONE_CARD_MOBILE:
						on_card = on_card or line.ends_with(": " + number)
					if str(st.get("wait_for", "")) != "telephone" or number.length() != 4 or not number.is_valid_int() or not on_card \
							or not str(st.get("call_header", "")).begins_with("HOTLINE " + number + ": ") or str(ch.place) == "office" \
							or str(st.get("checklist_line", "")) == "":
						dial_ok = false
	_check(opens_ok, "every opens names a Browser page in Campaign.PAGES")
	_check(apps_ok, "every opens_app is in PHONE_APP_TARGETS (and only off the clock)")
	_check(dial_ok and dial_steps == 4, "every dial step waits for the telephone, dials a 4-digit number on the hotline card (%d steps)" % dial_steps)
	var marks_ok := true
	for m: Array in Campaign.PHONE_BOOKMARKS:
		marks_ok = marks_ok and Campaign.PAGES.has(str(m[0]))
	_check(marks_ok and Campaign.PHONE_BOOKMARKS.size() == 5, "every phone bookmark is a page in Campaign.PAGES")
	_check(Campaign.PHONE_APP_PAGES.has("telco") and Campaign.PHONE_APP_PAGES.has("bank") and Campaign.PHONE_APP_PAGES.has("wallet_report"),
		"phone app pages: telco, bank, wallet_report")
	_check(secret_choices == SECRET_CHOICES, "shares_secret on exactly the agreed choices %s" % [secret_choices])
	_check(mule_items == MULE_ITEMS, "trap mule on %s (%s)" % [MULE_ITEMS, mule_items])
	for n: int in [7, 9]:
		var bv := str(Campaign.chapter(n).briefing[0].text)
		_check(bv.contains("Black Veil") and bv.contains("escalat"), "ch%d briefing: Black Veil escalated" % n)
	var ending_text := " ".join(Campaign.GOOD_ENDING)
	_check(ending_text.contains("chat") and ending_text.contains("QR") and ending_text.contains("six coworkers")
			and ending_text.contains("family") and ending_text.contains("Black Veil"),
		"GOOD_ENDING covers all ten chapters (chat, QR, six coworkers, family, Black Veil)")
	# A QR inspection is credited to the item that owns the code, whichever item is selected.
	var s9 := ChapterSession.new(Campaign.chapter(9))
	s9.select_item("c6_rice")
	s9.mark("qr:c6_park_qr")
	var rice_has: bool = s9.inspected.has("qr:c6_park_qr")
	s9.select_item("c6_parking")
	_check(not rice_has and s9.inspected.has("qr:c6_park_qr") and s9.qr_owner("c6_park_qr") == "c6_parking",
		"qr:<id> is credited to the owning item")
	_test_phone_credit()

	# Invariants 6 and 7 and the spelling list over every string in the data, the phone's own text and the fun
	# facts (their real outlet names live only in "source", which is not scanned).
	var strings: Array[String] = []
	var consts: Dictionary = (load("res://data/campaign.gd") as GDScript).get_script_constant_map()
	for k: String in consts:
		_strings(consts[k], strings)
	var phone_consts: Dictionary = (load("res://scripts/ui/phone_ui.gd") as GDScript).get_script_constant_map()
	for k: String in ["PHONE_UI_TEXT", "PHONE_TEXT", "PHONE_APP_NAMES"]:
		_check(phone_consts.has(k), "PhoneUI.%s exists" % k)
		_strings(phone_consts.get(k, {}), strings)
	for f: Dictionary in FunFacts.all():
		strings.append(str(f.get("text", "")))
		strings.append(FunFacts.display_text(f))
	var domain_re := RegEx.create_from_string("(?i)\\b[a-z0-9-]+(\\.[a-z0-9-]+)*\\.[a-z]{2,}\\b(?!@)")
	var phone_re := RegEx.create_from_string("(\\+63|\\b0)9\\d")
	var digits_re := RegEx.create_from_string("\\d{7,}")
	var bad_domains: Array[String] = []
	var bad_phones: Array[String] = []
	var bad_words: Array[String] = []
	for s: String in strings:
		for m: RegExMatch in domain_re.search_all(s):
			if not m.get_string().to_lower().ends_with(".example"):
				bad_domains.append(m.get_string())
		if phone_re.search(s) != null or digits_re.search(s.replace(" ", "").replace("-", "")) != null:
			bad_phones.append(s.left(60))
		var low := s.to_lower()
		for w: String in FORBIDDEN + BRITISH:
			if low.contains(w):
				bad_words.append(w)
	_check(bad_domains.is_empty(), "inv6: every domain ends in .example %s" % [bad_domains])
	_check(bad_phones.is_empty(), "inv6: no real-format phone numbers or long digit runs %s" % [bad_phones])
	_check(bad_words.is_empty(), "inv7: no forbidden phrases or British spellings %s" % [bad_words])
	print("  data checked: %d strings (%.1f s)" % [strings.size(), _elapsed()])


## Phone inspection credit rules on fresh sessions (TASKS-SPEC A.5): tx:<id> goes to the owner; wallet_inbox and
## page:<id> go to every unlocked item that needs them; app items start seen; the number to dial.
func _test_phone_credit() -> void:
	var s3 := ChapterSession.new(Campaign.chapter(3))
	_check(s3.is_phone() and s3.place() == "home", "ch3 session is played on the phone at home")
	s3.select_item("c8_cashin")
	_check(s3.all_wallet_tx().size() == 1 and str(s3.all_wallet_tx()[0].id) == "c8_tx_mama" and str(s3.all_wallet_tx()[0].item) == "c8_cashin",
		"ch3: only unlocked items' transfers are in the KwartaPay history")
	_check(s3.tx_owner("c8_tx_jan") == "c8_wrongsend", "tx_owner finds the owning item")
	s3.mark("tx:c8_tx_mama")
	_check(s3.inspected.has("tx:c8_tx_mama") and s3.gate_open() == false, "tx:<id> credited to its owner (the selected c8_cashin)")
	s3.mark("sender_number")
	_check(s3.gate_open(), "c8_cashin gate open after its two checks")
	s3.resolve_current()
	_check(s3.is_unlocked("c8_ayuda") and s3.all_wallet_tx().size() == 1, "c8_ayuda unlocked; c8_wrongsend's transfer still hidden")
	# The Inbox is shared: opening it with c8_cashin still selected counts for c8_ayuda, which needs it.
	s3.mark("wallet_inbox")
	s3.select_item("c8_ayuda")
	_check(s3.inspected.has("wallet_inbox"), "wallet_inbox credited to every unlocked item that needs it")
	s3.mark("tx:c8_tx_jan")
	var ayuda_has: bool = s3.inspected.has("tx:c8_tx_jan")
	s3.resolve_current()
	s3.select_item("c8_wrongsend")
	_check(not ayuda_has and s3.inspected.has("tx:c8_tx_jan") and s3.all_wallet_tx().size() == 2,
		"tx:<id> credited to the owner c8_wrongsend, not the selected item")
	var s5 := ChapterSession.new(Campaign.chapter(5))
	s5.mark("page:shopko_checkout")
	s5.select_item("c7_otp")
	_check(s5.inspected.has("page:shopko_checkout"), "page:<id> credited to the unlocked item that needs it (nothing selected)")
	_check(s5.gate_hint() == "Inspect before you decide.", "ch5 generic hint")
	s5.resolve_current()
	s5.select_item("c7_agent")
	s5.advance_to(2)
	_check(s5.waits_for_telephone() and s5.expected_number() == "8700", "c7_agent step 2 dials 8700 (%s)" % s5.expected_number())
	var s1 := ChapterSession.new(Campaign.chapter(1))
	s1.select_item("c1_orientation")
	s1.resolve_current()
	s1.select_item("c1_benefits")
	s1.advance_to(1)
	_check(s1.expected_number() == "1300", "office steps still dial the EXT number (%s)" % s1.expected_number())
	var s10 := ChapterSession.new(Campaign.chapter(10))
	_check(s10.status("c10_kyc") == "open" and s10.new_desktop_count() == 0, "an app the player opens (c10_kyc) is never announced as new")
	s10.select_item("c10_kyc")
	s10.mark("page:sec_lenders")
	s10.resolve_current()
	s10.select_item("c10_loan")
	_check(not s10.inspected.has("page:sec_lenders"), "page:<id> never credited to a locked item")
	s10.mark("page:sec_lenders")
	_check(s10.inspected.has("page:sec_lenders"), "page:sec_lenders credited once c10_loan is open")


## Fun Facts (game/data/fun_facts.gd): 15 sourced facts, no URLs, tagged by chapter key, never spoiling a start.
func _test_fun_facts_data() -> void:
	print("--- FUN FACTS: data")
	var facts := FunFacts.all()
	_check(facts.size() == FACT_COUNT, "%d fun facts (%d)" % [FACT_COUNT, facts.size()])
	var ids: Dictionary = {}
	var bad: Array[String] = []
	for f: Dictionary in facts:
		var id := str(f.get("id", ""))
		if id == "" or ids.has(id):
			bad.append("id " + id)
		ids[id] = true
		if str(f.get("text", "")) == "" or str(f.get("source", "")) == "" or int(f.get("year", 0)) < 2000:
			bad.append(id + " text/source/year")
		if f.has("url") or str(f).contains("http"):
			bad.append(id + " has a URL")
		var status := str(f.get("status", ""))
		if not status in ["confirmed", "reported"]:
			bad.append(id + " status " + status)
		if FunFacts.display_text(f).contains("(reported)") != (status == "reported"):
			bad.append(id + " reported label")
		if FunFacts.source_line(f) != "Source: %s, %d" % [f.source, int(f.year)]:
			bad.append(id + " source line")
		for k: Variant in f.get("chapters", []):
			if not (KEYS.has(str(k)) or str(k) == "general"):
				bad.append(id + " tag " + str(k))
		for k: Variant in f.get("spoils", []):
			if not KEYS.has(str(k)):
				bad.append(id + " spoils " + str(k))
	_check(bad.is_empty(), "facts: unique ids, text, source, year, status, tags, no URLs %s" % [bad])
	for n: int in [3, 5, 8, 10]:
		_check(not FunFacts.for_chapter(n).is_empty(), "ch%d has its own fun facts" % n)
	var spoil: Array[int] = []
	for n: int in range(1, CHAPTERS + 1):
		var start := FunFacts.pick(n, "start")
		var again := FunFacts.pick(n, "start")
		var results := FunFacts.pick(n, "results")
		_check(not start.is_empty() and not results.is_empty() and str(start.id) == str(again.id),
			"ch%d: start and results facts picked, deterministic (%s / %s)" % [n, start.get("id", ""), results.get("id", "")])
		if (start.get("spoils", []) as Array).has(KEYS[n - 1]):
			spoil.append(n)
	_check(spoil.is_empty(), "no start fact gives away its chapter %s" % [spoil])


func _check_item(n: int, it: Dictionary, earlier: Array[String]) -> void:
	var id: String = it.get("id", "")
	var app: String = it.get("app", "")
	var steps: Array = it.get("steps", [])
	var msg: Dictionary = it.get("message", {})
	var links: Dictionary = msg.get("links", {})
	var office := str(Campaign.chapter(n).get("place", "office")) == "office"
	var ok := not steps.is_empty()
	var failures: Array[String] = []
	# Invariant 5: unlock_after names earlier items.
	for dep: String in it.get("unlock_after", []):
		if not earlier.has(dep):
			failures.append("inv5 unlock_after %s" % dep)
	# Invariant 14 (and 5: link keys exist).
	var expect: Array[String] = []
	match app:
		"mail":
			expect.append("sender")
		"messages":
			expect.append("sender_number")
		"call":
			expect.append("caller_id")
		"chat":
			expect.append("profile")
		"bank":
			expect.append("app_info")
	if str(it.get("kind", "")) == "coworker":
		expect.append("quote")
	if msg.has("request"):
		expect.append("request")
	for lid: String in links:
		expect.append("link:" + lid)
	var qrs: Dictionary = msg.get("qrs", {})
	for qid: String in qrs:
		expect.append("qr:" + qid)
	var txs: Dictionary = msg.get("wallet_tx", {})
	for tid: String in txs:
		expect.append("tx:" + tid)
		var tx: Dictionary = txs[tid]
		if not str(tx.get("dir", "")) in ["in", "out"] or float(tx.get("value", 0.0)) <= 0.0 or str(tx.get("ref", "")) == "":
			failures.append("wallet_tx %s shape" % tid)
	for k: Variant in it.get("extra_inspections", []):
		var key := str(k)
		expect.append(key)
		if key != "wallet_inbox" and not (key.begins_with("page:") and Campaign.PAGES.has(key.substr(5))):
			failures.append("extra_inspections %s" % key)
		if office:
			failures.append("extra_inspections %s at the office" % key)
	if app == "bank" and (msg.get("app_info", []) as Array).is_empty():
		failures.append("bank item without app_info")
	var req: Array[String] = []
	for k: Variant in it.get("required_inspections", []):
		req.append(str(k))
		if str(k).begins_with("link:") and not links.has(str(k).substr(5)):
			failures.append("inv5 link key %s" % k)
		if str(k).begins_with("qr:") and not qrs.has(str(k).substr(3)):
			failures.append("inv5 qr key %s" % k)
		if str(k).begins_with("tx:") and not txs.has(str(k).substr(3)):
			failures.append("inv5 tx key %s" % k)
	expect.sort()
	req.sort()
	if req != expect:
		failures.append("inv14 required %s != %s" % [req, expect])
	# Invariant 13.
	for t: String in [str(it.get("task", ""))] + _step_tasks(steps):
		if t.contains("'") or t.contains("\"") or t.contains("’"):
			failures.append("inv13 quote in task %s" % t)
	# Invariant 3 (item level), place-aware: Black Veil in the office; a personal loss (and never Black Veil or
	# Aegis) at home and in the cafe.
	if it.has("bad_ending") and not _inv3_text(str(it.bad_ending), office):
		failures.append("inv3 bad_ending")
	# Invariant 9.
	if steps.is_empty() or (app == "call") != (str((steps[0] as Dictionary).get("surface", "desktop")) == "call"):
		failures.append("inv9 step 0 surface vs app")
	for i: int in steps.size():
		var st: Dictionary = steps[i]
		var kind: String = st.get("kind", "choices")
		if kind == "checklist":
			var opts: Array = st.get("options", [])
			var real := 0
			for o: Dictionary in opts:
				if bool(o.get("real", false)):
					real += 1
			if opts.size() < 6 or opts.size() > 8 or real < 2 or opts.size() - real < 2:
				failures.append("inv12 step %d options %d real %d" % [i, opts.size(), real])
			if st.has("next_step"):
				_check_next(steps, i, int(st.next_step), failures)
			continue
		var choices: Array = st.get("choices", [])
		var corrects := 0
		var values: Array[int] = []
		for c: Dictionary in choices:
			var outcome: String = c.get("outcome", "")
			if outcome == "correct":
				corrects += 1
				var v := 10 + (_best(steps, int(c.next_step)) if c.has("next_step") else 0)
				values.append(v)
			if outcome == "unsafe":
				if str(it.get("role", "")) == "genuine":
					failures.append("inv2 genuine has an unsafe choice")
				if not _inv3_text(str(c.get("compromise", "")), office):
					failures.append("inv3 compromise of '%s'" % c.text)
			if c.has("next_step"):
				_check_next(steps, i, int(c.next_step), failures)
			if str(it.get("role", "")) == "genuine":
				var low := str(c.get("text", "")).to_lower()
				if (low.contains("report") or low.contains("delete") or low.contains("block")) and outcome != "wrong":
					failures.append("inv2 genuine '%s' must be wrong" % c.text)
		if corrects == 0:
			failures.append("inv1 step %d has no correct choice" % i)
		elif values[0] != _best(steps, i) or values.max() != values.min():
			failures.append("inv1 step %d correct values %s (best %d)" % [i, values, _best(steps, i)])
		if str(it.get("role", "")) == "genuine" and choices.size() != 4:
			failures.append("inv2 genuine has %d choices" % choices.size())
	# Invariant 10: a call step entered from a desktop step waits for the telephone.
	for i: int in steps.size():
		var st: Dictionary = steps[i]
		if str(st.get("surface", "desktop")) != "desktop":
			continue
		for j: int in _nexts(st):
			if j > 0 and j < steps.size() and str((steps[j] as Dictionary).get("surface", "desktop")) == "call" \
					and str((steps[j] as Dictionary).get("wait_for", "")) != "telephone":
				failures.append("inv10 step %d -> %d has no wait_for" % [i, j])
	# Invariant 11: every task step lies on every correct path.
	var paths: Array = []
	_paths(steps, 0, [], paths)
	for i: int in steps.size():
		if not (steps[i] as Dictionary).has("task"):
			continue
		for p: Array in paths:
			if not p.has(i):
				failures.append("inv11 task step %d not on path %s" % [i, p])
	_check(ok and failures.is_empty(), "ch%d %s: invariants 1-3, 5, 8-14 %s" % [n, id, failures])


## Invariant 3, place-aware (decisions.md item 17): an office compromise names Black Veil; off the clock it is a
## personal loss that names neither Black Veil nor Aegis.
func _inv3_text(text: String, office: bool) -> bool:
	if office:
		return text.contains("Black Veil")
	return text.strip_edges() != "" and not text.contains("Black Veil") and not text.contains("Aegis")


func _check_next(steps: Array, i: int, next: int, failures: Array[String]) -> void:
	if next <= i or next >= steps.size():
		failures.append("inv8 step %d next_step %d" % [i, next])


## Best points from step i along correct choices (same rule as Game.item_max).
func _best(steps: Array, i: int) -> int:
	if i < 0 or i >= steps.size():
		return 0
	var st: Dictionary = steps[i]
	if str(st.get("kind", "choices")) == "checklist":
		return 10 + (_best(steps, int(st.next_step)) if st.has("next_step") else 0)
	var best := -1
	for c: Dictionary in st.get("choices", []):
		if str(c.get("outcome", "")) != "correct":
			continue
		best = maxi(best, 10 + (_best(steps, int(c.next_step)) if c.has("next_step") and int(c.next_step) > i else 0))
	return maxi(best, 0)


## The next steps a correct decision of step `st` can lead to (-1 = resolves).
func _nexts(st: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if str(st.get("kind", "choices")) == "checklist":
		out.append(int(st.get("next_step", -1)))
		return out
	for c: Dictionary in st.get("choices", []):
		if str(c.get("outcome", "")) == "correct":
			out.append(int(c.get("next_step", -1)))
	return out


func _paths(steps: Array, i: int, so_far: Array, out: Array) -> void:
	var p := so_far.duplicate()
	p.append(i)
	for j: int in _nexts(steps[i]):
		if j < 0:
			out.append(p)
		elif j > i and j < steps.size():
			_paths(steps, j, p, out)


func _step_tasks(steps: Array) -> Array[String]:
	var out: Array[String] = []
	for st: Dictionary in steps:
		if st.has("task"):
			out.append(str(st.task))
	return out


func _depends_on(items: Array, id: String, dep: String) -> bool:
	for it: Dictionary in items:
		if str(it.get("id", "")) != id:
			continue
		for d: String in it.get("unlock_after", []):
			if d == dep or _depends_on(items, d, dep):
				return true
	return false


func _strings(v: Variant, out: Array[String]) -> void:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(str(v))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			for e: Variant in v:
				_strings(e, out)
		TYPE_DICTIONARY:
			for k: Variant in v:
				_strings(v[k], out)


## (a) Best run with (c) the gate in every chapter, (g) order checks, (j) scope guard and (k) layout.
func _test_best_run() -> void:
	print("--- (a) BEST RUN: every item, first correct choice, exact checklists")
	var office := await _new_game()
	if office == null:
		return
	_scope_guard(office, "start")
	var office_id := office.get_instance_id()
	var opts := {"gate_detail": true}
	for n: int in range(1, CHAPTERS + 1):
		var place_before: String = office.debug_place()
		office = await _play_chapter(office, n, opts)
		# After the last chapter the office is freed (the ending scene loads): only earlier chapters can stop here.
		if office == null and n < CHAPTERS:
			return
		_check(game.chapter_total(n) == game.chapter_max(n), "ch%d total %d == chapter_max %d" % [n, game.chapter_total(n), game.chapter_max(n)])
		if n < CHAPTERS:
			# The week runs in ONE scene: office -> home -> office ... swaps the place in this same node.
			_check(office.get_instance_id() == office_id and current_scene == office, "a ch%d: still the same office node" % (n + 1))
			_check_place(office, n + 1, place_before != str(Campaign.chapter(n + 1).place))
			_scope_guard(office, "chapter %d" % (n + 1))
		if n == 3:
			await _check_office_back(office)
	_check(game.score == SPEC_MAX and game.score == game.max_score(), "final score %d == Game.max_score() %d" % [game.score, game.max_score()])
	_check(game.all_complete(), "all ten chapters complete")
	_check(game.events_of("misdial").is_empty() and game.events_of("secret_shared").is_empty() and game.events_of("trap_failed").is_empty(),
		"best run logs no misdial, secret_shared or trap_failed events")
	await _check_ending("%d / %d" % [SPEC_MAX, SPEC_MAX])
	# Badges and achievements: a perfect run earns everything except Comeback, and ten gold badges.
	var best_expect: Array[String] = ["first_day", "clean_sweep", "eagle_eye", "no_false_alarms", "good_colleague",
		"fully_vigilant", "otp_bantay", "hotline_hero", "not_your_mule"]
	for id: String in best_expect:
		_check(game.achievements.has(id), "best run earns achievement %s (%s)" % [id, game.achievements])
	_check(not game.achievements.has("comeback"), "best run has no Comeback")
	for n: int in range(1, CHAPTERS + 1):
		_check(Achievements.chapter_flawless(n), "best run: chapter %d badge is flawless" % n)
	_check(_visible_text(current_scene).contains("9 of 10 achievements"), "ending shows '9 of 10 achievements'")
	var badges := current_scene.find_child("Badges", true, false)
	_check(badges != null and badges.get_child_count() == CHAPTERS, "ending shows ten badges (%d)" % (badges.get_child_count() if badges != null else -1))


## The office after a chapter at home (ch4 after ch3): the builder is the office again, with its pantry, notice
## board and walkers hooked up; the coffee maker still works and never scores.
func _check_office_back(office: Node) -> void:
	var b: Variant = office.builder
	_check(office.debug_place() == "office" and b.pantry != null and b.notice_board != null and b.walkers.size() == 2,
		"office again after home: pantry, notice board and two walkers")
	if b.pantry == null:
		return
	var score0: int = game.score
	var log0: int = game.score_log.size()
	await office.debug_pantry("coffee")
	_check(b.pantry.coffee_state() == 1, "office again after home: the coffee maker brews")
	_check(game.score == score0 and game.score_log.size() == log0 and office.debug_state() == "ACTIVE", "the coffee maker never scores")


## Chapter n has just started (ACTIVE): the scene stands at chapter n's place with one builder named "Builder"
## and that place's devices; after a place switch the player stands at the new chapter spawn.
func _check_place(office: Node, n: int, switched: bool) -> void:
	var place := str(Campaign.chapter(n).place)
	var b: Variant = office.builder
	var builders := 0
	for c: Node in office.get_children():
		# (LocationBuilder names the Audio autoload, so this --script cannot name the class at compile time.)
		if c.has_method("apply_chapter_mood") and not c.is_queued_for_deletion():
			builders += 1
	_check(office.debug_place() == place and str(b.location) == place and str(b.name) == "Builder" and builders == 1,
		"ch%d at the %s (%s), one builder named Builder (%d)" % [n, place, office.debug_place(), builders])
	if place == "office":
		_check(b.workstation != null and b.telephone != null and b.phone == null, "ch%d: workstation and desk phone, no smartphone" % n)
	else:
		_check(b.phone != null and b.workstation == null and b.telephone == null and b.walkers.is_empty(),
			"ch%d: only the smartphone at the %s" % [n, place])
		_check(office.screen() == office.phone_ui, "ch%d: the screen is the phone" % n)
	if switched:
		var spawn: Vector3 = b.chapter_spawn.origin
		var pos: Vector3 = office.player.global_position
		_check(Vector2(pos.x - spawn.x, pos.z - spawn.z).length() < 0.6, "ch%d: the player stands at the %s spawn (%s vs %s)" % [n, place, pos, spawn])


## (b) Wrong-first run: every wrong choice first (one wrong report per checklist), then the first correct one.
func _test_wrong_first_run() -> void:
	print("--- (b) WRONG-FIRST RUN: each wrong choice first, then correct")
	var office := await _new_game()
	if office == null:
		return
	var opts := {"wrong_first": true, "worst": ["c4_supplier"]}
	for n: int in range(1, CHAPTERS + 1):
		office = await _play_chapter(office, n, opts)
		# After the last chapter the office is freed (the ending scene loads): only earlier chapters can stop here.
		if office == null and n < CHAPTERS:
			return
		_check(game.chapter_total(n) == SPEC_WRONG_FIRST[n - 1], "ch%d total %d (got %d)" % [n, SPEC_WRONG_FIRST[n - 1], game.chapter_total(n)])
	_check(game.score == SPEC_WRONG_FIRST_TOTAL, "final score %d (got %d)" % [SPEC_WRONG_FIRST_TOTAL, game.score])
	_check(game.all_complete(), "all ten chapters complete")
	await _check_ending("%d / %d" % [SPEC_WRONG_FIRST_TOTAL, SPEC_MAX])
	_check(game.achievements.has("first_day"), "wrong-first run earns First Day Survivor")
	# The wrong choices include c7_otp's "Forward the code to a friend" (shares_secret, wrong): OTP Bantay is lost.
	# The wrong-send and rent-your-account items get a wrong pick first (trap_failed): Not Your Mule is lost.
	# Every hotline is dialed right the first time: Hotline Hero is earned.
	for id: String in ["clean_sweep", "eagle_eye", "no_false_alarms", "good_colleague", "fully_vigilant", "otp_bantay",
			"not_your_mule"]:
		_check(not game.achievements.has(id), "wrong-first run does not earn %s" % id)
	_check(game.achievements.has("hotline_hero"), "wrong-first run earns Hotline Hero (every hotline dialed right)")
	var secrets: Array[String] = []
	for e: Dictionary in game.events_of("secret_shared"):
		secrets.append(str(e.item))
	_check(secrets == ["c7_otp"], "wrong-first: the only secret shared is c7_otp's forwarded code (%s)" % [secrets])
	var traps: Array[String] = []
	for e: Dictionary in game.events_of("trap_failed"):
		traps.append(str(e.item))
	_check(traps == MULE_ITEMS, "wrong-first: trap_failed once per mule item (%s)" % [traps])
	_check(game.events_of("misdial").is_empty(), "wrong-first: no misdial")


## (d) Unsafe choice in Ch2's main item -> compromise -> game over; Restart Chapter reloads Ch2 without the intro.
func _test_unsafe_and_restart() -> void:
	print("--- (d) UNSAFE + RESTART: Chapter 2 unsafe choice, then Restart Chapter")
	var office := await _new_game()
	if office == null:
		return
	office = await _play_chapter(office, 1, {})
	if office == null:
		return
	var after_ch1 := int(game.chapter_max(1))
	_check(game.score == after_ch1, "after chapter 1 score %d (got %d)" % [after_ch1, game.score])
	if not await _drive(office, ["ACTIVE"]):
		return
	_check(game.current_chapter == 2, "now on chapter 2")
	var it := _main_item(2)
	if not await _open_item(office, it, false):
		return
	await _inspect(office, 2, it, {})
	var unsafe := _indices(it.steps[0], "unsafe")
	_check(not unsafe.is_empty(), "%s step 0 has an unsafe choice" % it.id)
	if unsafe.is_empty():
		return
	if not await _unsafe_to_game_over(office, unsafe[0]):
		return
	_check(game.score == after_ch1 + _const("UNSAFE"), "score after unsafe = %d (got %d)" % [after_ch1 + _const("UNSAFE"), game.score])
	var expect_end: String = it.get("bad_ending", Campaign.chapter(2).bad_ending)
	_check(_visible_text(office.game_over).contains(expect_end), "game-over text is Ch2's bad ending")
	var restart := _find_button(office.game_over, "Restart Chapter")
	_check(restart != null, "Restart Chapter button exists")
	if restart != null:
		restart.pressed.emit()
	else:
		office.game_over.restart_pressed.emit()
	var new_office := await _wait_office(office)
	if new_office == null:
		return
	_check(game.score == after_ch1, "after restart score back to %d (got %d)" % [after_ch1, game.score])
	_check(game.current_chapter == 2, "after restart current chapter 2 (got %d)" % game.current_chapter)
	_check(not game.is_restart, "is_restart consumed by the office")
	var first_state: String = new_office.debug_state()
	_check(first_state != "INTRO", "restart skipped the intro (state %s)" % first_state)
	_check(game.chapter_log(2).is_empty(), "chapter 2 log cleared on restart")
	_check(game.completed[0] and not game.completed[1], "chapter 1 still complete, chapter 2 not")
	var spawn: Vector3 = new_office.builder.chapter_spawn.origin
	var pos: Vector3 = new_office.player.global_position
	_check(Vector2(pos.x - spawn.x, pos.z - spawn.z).length() < 0.6, "restart spawns at the desk (%s vs %s)" % [pos, spawn])
	new_office = await _play_chapter(new_office, 2, {})
	if new_office == null:
		return
	_check(game.completed[1], "chapter 2 completed after restart")
	_check(game.restarted == [2] and game.achievements.has("comeback"), "restart then complete earns Comeback (%s)" % [game.achievements])
	var expect := after_ch1 + int(game.chapter_max(2))
	_check(game.score == expect, "score %d after Ch2 (got %d)" % [expect, game.score])
	_check(new_office.debug_state() == "ACTIVE" and game.current_chapter == 3, "chapter 3 starts next")
	# Chapter 3 is at home: the place switched in this same office node.
	_check(is_instance_valid(new_office) and current_scene == new_office and new_office.debug_place() == "home",
		"chapter 3 starts at home in the same office node (%s)" % new_office.debug_place())
	_check_place(new_office, 3, true)


## (d3) Off the clock: Chapter 5 at home. Reading the code to the fake bank agent is a personal loss (no Aegis, no
## Black Veil); Restart Chapter rebuilds the home, and OTP Bantay stays lost (the events log survives). The replay
## goes through the real phone controls (Answer, the keypad) and misdials the bank once: 0 points, logged, and
## Hotline Hero is lost. Then Chapter 6 brings the office back in the same node.
func _test_home_restart() -> void:
	print("--- (d3) HOME: Chapter 5 unsafe, Restart Chapter at home, misdial, phone controls")
	if not await _wait(func() -> bool: return not router.is_busy(), "Router idle"):
		return
	game.start_new_game()
	for i: int in 4:
		game.completed[i] = true
	game.select_chapter(5)
	_check(change_scene_to_file(OFFICE) == OK, "change scene to office at chapter 5")
	var office := await _wait_office(null)
	if office == null:
		return
	_check(office.debug_place() == "home" and office.debug_state() != "INTRO", "chapter 5 is built at home, no intro (%s)" % office.debug_place())
	if not await _drive(office, ["ACTIVE"]):
		return
	_check_place(office, 5, true)
	_check(office.builder.phone.enabled and office.builder.phone.prompt == "Check your phone", "the phone offers Check your phone (%s)" % office.builder.phone.prompt)
	_check(office.session.objective() == "Check your phone" and _find_label_prefix(office.hud, "Check your phone") != "",
		"HUD objective is the chapter's (Check your phone)")
	var otp := Campaign.item(5, "c7_otp")
	if not await _play_item(office, 5, otp, {}):
		return
	await _frames(2)
	var agent := Campaign.item(5, "c7_agent")
	_check(office.session.phone_incoming() and office.builder.is_ringing() and office.phone_ui.is_open(), "the bank agent calls while the phone is in hand")
	var banner := office.phone_ui.find_child("IncomingCall", true, false) as Control
	_check(banner != null and banner.is_visible_in_tree() and _visible_text(banner).contains(str(agent.call.caller_id)),
		"the phone shows the incoming call banner with the caller ID")
	_check(office.session.objective() == "Answer your ringing phone", "objective: Answer your ringing phone (%s)" % office.session.objective())
	if not await _open_item(office, agent, false):
		return
	await _inspect(office, 5, agent, {})
	var unsafe := _indices(agent.steps[0], "unsafe")
	if unsafe.is_empty():
		_check(false, "c7_agent step 0 has an unsafe choice")
		return
	var score_before: int = game.score
	if not await _unsafe_to_game_over(office, unsafe[0]):
		return
	_check(game.score == score_before + _const("UNSAFE"), "unsafe at home = -5 (score %d)" % game.score)
	_check(game.events_of("secret_shared").size() == 1, "reading the code logs secret_shared")
	var heading := office.game_over.find_child("Heading", true, false) as Label
	_check(heading != null and heading.text == str(Campaign.chapter(5).breach_title), "game-over heading is the chapter's breach_title (%s)" % (heading.text if heading != null else ""))
	var mark := office.game_over.find_child("BlackVeilMark", true, false) as Control
	_check(mark != null and not mark.is_visible_in_tree(), "no Black Veil mark off the clock")
	var shown := _visible_text(office.game_over)
	_check(shown.contains(str(Campaign.chapter(5).bad_ending)) and not shown.contains("Black Veil") and not shown.contains("Aegis"),
		"home game over: a personal loss, no Black Veil or Aegis")
	var restart := _find_button(office.game_over, "Restart Chapter")
	if restart == null:
		_check(false, "Restart Chapter button exists")
		return
	restart.pressed.emit()
	var home := await _wait_office(office)
	if home == null:
		return
	_check(home.debug_place() == "home" and game.current_chapter == 5 and home.debug_state() != "INTRO", "Restart Chapter rebuilds the home (%s)" % home.debug_place())
	if not await _drive(home, ["ACTIVE"]):
		return
	_check_place(home, 5, true)
	_check(game.score == 0 and game.chapter_log(5).is_empty(), "restart rolls chapter 5 back")
	_check(game.events_of("secret_shared").size() == 1 and not Achievements._earned("otp_bantay"),
		"the events log survives the restart: OTP Bantay stays lost")
	_check(Achievements._earned("hotline_hero"), "Hotline Hero still possible before the misdial")
	home = await _play_chapter(home, 5, {"ui": true, "misdial": {"c7_agent": "8701"}})
	if home == null:
		return
	_check(game.completed[4] and game.chapter_total(5) == game.chapter_max(5) - 0, "chapter 5 completed after the restart with full marks (%d)" % game.chapter_total(5))
	_check(not Achievements._earned("hotline_hero") and not Achievements._earned("otp_bantay") and Achievements._earned("not_your_mule"),
		"after the misdial: Hotline Hero and OTP Bantay lost, Not Your Mule kept")
	_check(home.debug_place() == "office" and current_scene == home and game.current_chapter == 6, "chapter 6 brings the office back in the same node")
	_check_place(home, 6, true)


## (d2) An unsafe choice in a coworker item shows that item's game-over override.
func _test_coworker_unsafe() -> void:
	print("--- (d2) COWORKER UNSAFE: the item's bad_ending override is shown")
	var office := await _new_game()
	if office == null:
		return
	if not await _drive(office, ["ACTIVE"]):
		return
	var cw := {}
	for it: Dictionary in Campaign.chapter(1).items:
		if str(it.role) == "coworker":
			cw = it
			break
		if not await _play_item(office, 1, it, {}):
			return
		await _drive(office, ["ACTIVE"])
	_check(not cw.is_empty() and cw.has("bad_ending"), "Ch1 coworker item has a bad_ending override")
	if cw.is_empty():
		return
	if not await _open_item(office, cw, false):
		return
	await _inspect(office, 1, cw, {})
	var unsafe := _indices(cw.steps[0], "unsafe")
	if unsafe.is_empty():
		_check(false, "coworker item has an unsafe choice")
		return
	if not await _unsafe_to_game_over(office, unsafe[0]):
		return
	var shown := _visible_text(office.game_over)
	_check(shown.contains(str(cw.bad_ending)), "game-over text equals %s.bad_ending" % cw.id)
	_check(not shown.contains(str(Campaign.chapter(1).bad_ending)), "chapter-level bad ending not shown")


## (e) checklist rules, (f) genuine item reported, (g) Chapter 1 order rules and the verify route.
## Chapter Select: ten cards listing every subquest, a jump straight to one subquest (earlier items skipped, no
## points), and the feedback screen's Chapter Select button returning to the cards.
func _test_chapter_select() -> void:
	print("--- CHAPTER SELECT: cards, subquest jump, back to the cards")
	if not await _wait(func() -> bool: return not router.is_busy(), "Router idle"):
		return
	game.start_new_game()
	change_scene_to_file(MAIN_MENU)
	await _expect_scene(MAIN_MENU)
	var menu := current_scene
	menu.call("_show_select")
	await process_frame
	var cards: Node = menu.find_child("ChapterSelect", true, false)
	_check(cards != null and cards.visible, "Play opens Chapter Select")
	var tasks := 0
	for n: int in range(1, CHAPTERS + 1):
		var card: Node = cards.find_child("Chapter%d" % n, true, false)
		_check(card != null, "card for chapter %d" % n)
		if card != null:
			for it: Dictionary in Campaign.chapter(n).items:
				if card.find_child("Task_" + str(it.id), true, false) != null:
					tasks += 1
	var total := 0
	for n: int in range(1, CHAPTERS + 1):
		total += Campaign.chapter(n).items.size()
	_check(tasks == total, "every subquest listed on its card (%d of %d)" % [tasks, total])
	# Locked in order by default: Chapter 1 open, Chapter 2 locked, tasks only listed.
	var settings := root.get_node("/root/Settings")
	settings.set("review_mode", false)
	cards.call("refresh")
	await process_frame
	var c1: Node = cards.find_child("Chapter1", true, false)
	var c2: Node = cards.find_child("Chapter2", true, false)
	_check(not (c1.find_child("Play", true, false) as Button).disabled, "Chapter 1 is open")
	_check((c2.find_child("Play", true, false) as Button).disabled, "Chapter 2 is locked until Chapter 1 is done")
	_check((c1.find_child("Task_c1_benefits", true, false) as Button).disabled, "tasks are not clickable outside Review mode")
	game.completed[0] = true
	cards.call("refresh")
	await process_frame
	_check(not (cards.find_child("Chapter2", true, false).find_child("Play", true, false) as Button).disabled, "finishing Chapter 1 unlocks Chapter 2")
	game.start_new_game()
	# Review mode opens everything.
	settings.call("set_review_mode", true)
	cards.call("refresh")
	await process_frame
	var all_open := true
	for n: int in range(1, CHAPTERS + 1):
		var card: Node = cards.find_child("Chapter%d" % n, true, false)
		all_open = all_open and not (card.find_child("Play", true, false) as Button).disabled
	_check(all_open, "Review mode unlocks every chapter")
	var c6_task := cards.find_child("Chapter6", true, false).find_child("Task_c4_delivery", true, false) as Button
	_check(c6_task != null and not c6_task.disabled, "Review mode makes tasks clickable (Task_c4_delivery on the Chapter 6 card)")
	var c3_card: Node = cards.find_child("Chapter3", true, false)
	_check(c3_card != null and c3_card.find_child("Task_c8_ayuda", true, false) != null, "the Chapter 3 card lists the home chapter's subquests")
	# One card at a time: each one, shown with the arrows' show_chapter(), fits on screen with its Play button.
	for n: int in range(1, CHAPTERS + 1):
		cards.call("show_chapter", n)
		await process_frame
		var card: Control = cards.find_child("Chapter%d" % n, true, false)
		_check(card != null and card.visible and _in_view(card) and _in_view(_find_button(card, "Play chapter  ▶")), "card %d shown and inside the viewport" % n)
	cards.call("show_chapter", 1)
	await process_frame
	_check((cards.find_child("Prev", true, false) as Button).disabled, "the previous arrow is off on Chapter 1")

	# Jump to Chapter 6's genuine Finance email: everything before it is skipped and scores nothing.
	menu.call("_on_chapter_chosen", 6, "c4_delivery")
	var office := await _wait_office(null)
	if office == null:
		return
	if not await _drive(office, ["ACTIVE"]):
		return
	var s: ChapterSession = office.session
	_check(game.current_chapter == 6 and office.debug_state() == "ACTIVE" and office.debug_place() == "office", "jump starts Chapter 6 at the office")
	var before_ok := true
	for it: Dictionary in Campaign.chapter(6).items:
		if str(it.id) == "c4_delivery":
			break
		before_ok = before_ok and s.is_done(str(it.id)) and s.is_skipped(str(it.id))
	_check(before_ok, "items before the chosen subquest are skipped")
	_check(not s.is_done("c4_delivery") and s.item_id == "c4_delivery", "the chosen subquest is open and selected")
	_check(game.score == 0 and game.chapter_log(6).is_empty(), "skipped items score nothing")

	# The feedback screen's Chapter Select button leads back to the cards.
	office.feedback_screen.show_feedback(Campaign.chapter(6), [] as Array[String])
	await process_frame
	var sel := _find_button(office.feedback_screen, "Chapter Select")
	_check(sel != null, "feedback screen has a Chapter Select button")
	office.call("_to_chapter_select")
	await _expect_scene(MAIN_MENU)
	await process_frame
	await process_frame
	var cards2: Node = current_scene.find_child("ChapterSelect", true, false)
	_check(cards2 != null and cards2.visible, "back on the chapter cards")
	settings.call("set_review_mode", false)
	game.start_new_game()


## The guided first task: follows the real actions, changes no score, skippable, and not shown after a restart.
func _test_tutorial() -> void:
	print("--- TUTORIAL: guided first task of a new game")
	var office := await _new_game()
	if office == null:
		return
	if not await _drive(office, ["ACTIVE"]):
		return
	await process_frame
	var t: Variant = office.tutorial
	_check(t.is_active() and t.step_id() == "move", "tutorial starts at 'move' (%s)" % t.step_id())
	_check(t.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tutorial root never takes the mouse")
	office.player.global_position += Vector3(1.0, 0.0, 0.0)
	await process_frame
	await process_frame
	_check(t.step_id() == "desk", "walking moves on to 'desk' (%s)" % t.step_id())
	var genuine: Dictionary = Campaign.chapter(1).items[0]
	if not await _open_item(office, genuine, false):
		return
	await process_frame
	_check(t.step_id() == "sender" and t.visible, "desktop open: 'sender' shown (%s)" % t.step_id())
	var ring: Control = t.get_node("TutorialCard") as Control
	_check(ring.get_global_rect().intersection(office.desktop.tutorial_target("decision").get_global_rect()).get_area() == 0.0, "card does not cover the choices")
	office.debug_inspect("sender")
	await process_frame
	await process_frame
	_check(t.step_id() == "copy", "sender checked: 'copy' (%s)" % t.step_id())
	office.session.clipboard = str(genuine.message.links.c1_agenda)
	await process_frame
	await process_frame
	_check(t.step_id() == "paste", "link copied: 'paste' (%s)" % t.step_id())
	office.session.pasted_url = office.session.clipboard
	office.debug_inspect("link:c1_agenda")
	await process_frame
	await process_frame
	_check(t.step_id() == "choose", "pasted: 'choose' (%s)" % t.step_id())
	_check(game.score == 0 and game.chapter_log(1).is_empty(), "tutorial changes no score")
	office.debug_choose(_choice_by_text(genuine.steps[0], "Open the agenda link and keep the email for Thursday"))
	await process_frame
	await process_frame
	_check(not t.is_active() and not t.visible, "first choice ends the tutorial")

	# Skip ends it at once.
	office = await _new_game()
	if office == null:
		return
	if not await _drive(office, ["ACTIVE"]):
		return
	await process_frame
	office.tutorial.finish()
	await process_frame
	_check(not office.tutorial.is_active() and not office.tutorial.visible, "Skip ends the tutorial")


func _test_office_life() -> void:
	print("--- (l) OFFICE LIFE: walking coworkers and the pantry (feel only, never scores)")
	var office := await _new_game()
	if office == null:
		return
	if not await _drive(office, ["ACTIVE"]):
		return
	var b: Variant = office.builder
	var score0: int = game.score
	var log0: int = game.score_log.size()
	var objective0: String = office.session.objective()
	_check(b.walkers.size() == 2, "l: two coworkers walk the office (%d)" % b.walkers.size())
	for w: Variant in b.walkers:
		_check(w.obstacles.has(office.player), "l: walker gives way to the player")
		var body := (w.get_parent() as Node).get_node_or_null("Body")
		_check(body is AnimatableBody3D and (body as AnimatableBody3D).collision_layer == 1, "l: walker has a moving collider on the world layer")
		w.hurry()
	await create_timer(2.5).timeout
	for w: Variant in b.walkers:
		# (One may stop to let the other cross first, so only a short walk is required of each.)
		_check(w.distance_walked() > 0.2, "l: %s walked %.2f m" % [w.get_parent().name, w.distance_walked()])
	# Blocking: stand right in front of a walking coworker; they wait and say "Excuse me".
	var w0: Variant = b.walkers[0]
	if await _wait(func() -> bool: return w0.is_walking(), "walker 0 walking"):
		var wb := w0.get_parent() as Node3D
		var fwd := Vector3(sin(wb.rotation.y), 0.0, cos(wb.rotation.y))
		office.player.teleport(Transform3D(Basis(), wb.global_position + fwd * 0.7))
		await create_timer(0.3).timeout
		var d0: float = w0.distance_walked()
		await create_timer(1.5).timeout
		_check(w0.is_blocked() and absf(w0.distance_walked() - d0) < 0.01, "l: the coworker waits while the player is in the way")
		_check(wb.get_node("ExcuseMe").visible, "l: the coworker says Excuse me")
		office.player.teleport(b.chapter_spawn)
		await create_timer(1.0).timeout
		_check(w0.distance_walked() > d0 + 0.2 or not w0.is_walking(), "l: the coworker walks on once the way is clear")
	# Coffee: brew, then pour.
	var pantry: Variant = b.pantry
	_check(pantry.coffee_machine.enabled and pantry.coffee_machine.prompt == "Brew coffee", "l: coffee maker offers Brew coffee")
	await office.debug_pantry("coffee")
	_check(pantry.coffee_state() == 1 and not pantry.coffee_machine.enabled, "l: brewing (coffee maker busy)")
	await _wait(func() -> bool: return pantry.coffee_state() == 2, "coffee brewed")
	_check(absf(pantry.coffee_level() - pantry.LEVEL_FULL) < 0.002 and pantry.coffee_machine.prompt == "Pour a cup of coffee",
		"l: the pot is full and offers Pour a cup (%.3f)" % pantry.coffee_level())
	await office.debug_pantry("coffee")
	await _wait(func() -> bool: return pantry.coffee_state() == 0, "coffee poured")
	_check(pantry.cups() == 1 and pantry.brews() == 1 and pantry.coffee_machine.prompt == "Brew coffee", "l: one cup poured, ready to brew again")
	# Water.
	await office.debug_pantry("water")
	_check(pantry.is_water_busy() and not pantry.water_cooler.enabled, "l: the water dispenser fills a cup")
	await _wait(func() -> bool: return not pantry.is_water_busy(), "water poured")
	_check(pantry.water_cooler.enabled, "l: the water dispenser is ready again")
	# Notice board.
	_check(b.notice_board.enabled and b.notice_board.prompt == "Read the notice board", "l: notice board readable")
	await office.debug_pantry("board")
	_check(office.board_view.is_open() and office.top_overlay() == office.board_view, "l: the notice board opens up close")
	_check(_visible_text(office.board_view).contains("ext. 1200"), "l: the board names the Security Office extension")
	office.board_view.handle_back()
	await _frames(2)
	_check(not office.board_view.is_open() and office.debug_state() == "ACTIVE", "l: ESC puts the notice board back")
	# Feel only: nothing scored, the chapter did not move.
	_check(game.score == score0 and game.score_log.size() == log0, "l: the pantry and coworkers never change the score")
	_check(office.session.objective() == objective0, "l: the chapter objective is unchanged")
	_scope_guard(office, "office life")


func _test_chapter1_rules() -> void:
	print("--- (e)(f)(g) CHAPTER 1 RULES: genuine item, verify route, checklist rules, order")
	var office := await _new_game()
	if office == null:
		return
	if not await _drive(office, ["ACTIVE"]):
		return
	var items: Array = Campaign.chapter(1).items
	var genuine: Dictionary = items[0]
	var main := _main_item(1)
	var cw := {}
	for it: Dictionary in items:
		if str(it.role) == "coworker":
			cw = it
	var s: ChapterSession = office.session
	_check(str(genuine.role) == "genuine" and str(genuine.id) == "c1_orientation", "Ch1 first item is the genuine c1_orientation")
	_check(not _ids(s.available_items()).has(cw.id), "g: %s not available at chapter start" % cw.id)
	_check(office.builder.workstation.enabled and not office.builder.telephone.enabled, "g: workstation on, telephone off at start")
	_check(office.builder._alert, "g: monitor shows the new-messages label")

	# (f) Genuine item reported = wrong (-5), then handled normally = +10.
	if not await _open_item(office, genuine, false):
		return
	_check(office.desktop.find_child("Item_" + str(cw.id), true, false) == null, "g: %s not on screen" % cw.id)
	await _inspect(office, 1, genuine, {})
	var report := _choice_by_text(genuine.steps[0], "Report it to Security as phishing")
	var handle := _choice_by_text(genuine.steps[0], "Open the agenda link and keep the email for Thursday")
	_check(report >= 0 and handle >= 0, "f: genuine choices found")
	if report < 0 or handle < 0:
		return
	var before: int = game.score
	office.debug_choose(report)
	await _frames(2)
	_check(office.debug_state() == "OUTCOME" and game.score == before - 5, "f: reporting a genuine email = -5 (score %d)" % game.score)
	await _advance_to_active(office)
	_check(office.session.is_disabled(report) and not office.session.is_done(genuine.id), "f: report option disabled, item still open")
	office.debug_choose(handle)
	await _frames(2)
	_check(game.score == before + 5, "f: handling it normally = +10 (score %d)" % game.score)
	await _advance_to_active(office)
	_check(office.session.is_done(genuine.id), "f: genuine item done")
	_check(office.debug_tasks() == "1/5", "f: debug_tasks() == 1/5 (%s)" % office.debug_tasks())
	await _frames(3)
	var row := office.desktop.find_child("Item_" + str(genuine.id), true, false) as Node
	_check(row != null and _visible_text(row).contains("✓"), "f: inbox row Item_%s shows ✓" % genuine.id)

	# (g) Verify route: Directory -> desk phone (HR) -> back at the desk on Mail with the checklist.
	if not await _open_item(office, main, false):
		return
	await _inspect(office, 1, main, {})
	var steps: Array = main.steps
	var dir := -1
	for i: int in steps[0].choices.size():
		if str(steps[0].choices[i].get("opens", "")) == "directory":
			dir = i
	_check(dir >= 0, "g: step 0 has the Directory choice")
	office.debug_choose(dir)
	await _frames(2)
	await _advance_to_active(office)
	var call_step: Dictionary = steps[int(steps[0].choices[dir].next_step)]
	_check(office.session.page == "directory", "g: Browser page is the Staff Directory")
	_check(office.session.waits_for_telephone(), "g: step waits for the telephone")
	_check(office.builder.telephone.enabled and office.builder.telephone.prompt == str(call_step.trigger_prompt),
		"g: telephone enabled with prompt '%s' (%s)" % [call_step.trigger_prompt, office.builder.telephone.prompt])
	_check(office.builder.telephone.prompt == "Call HR (ext. 1300)", "g: prompt is Call HR (ext. 1300)")
	await office.debug_interact("telephone")
	_check(office.dial_pad.is_open() and not office.call_ui.is_open(), "g: the phone opens the keypad, not the call")
	await office.debug_dial("1301")
	_check(office.dial_pad.is_open() and not office.call_ui.is_open() and office.builder.phone_display() == "NO ANSWER", "g: a wrong extension does not answer (%s)" % office.builder.phone_display())
	_check(game.chapter_log(1).filter(func(e: Dictionary) -> bool: return str(e.item) == "c1_benefits").size() == 1, "g: a wrong number costs nothing")
	await office.debug_dial("1300")
	_check(office.builder.phone_display() == "EXT 1300", "g: the phone screen shows EXT 1300 (%s)" % office.builder.phone_display())
	await _skip_call_lines(office)
	_check(office.call_ui.is_open() and not office.desktop.is_open(), "g: the HR call is open, desktop closed")
	var c := _indices(call_step, "correct")[0]
	office.debug_choose(c)
	await _frames(2)
	await _advance_to_active(office)
	if not await _wait(func() -> bool: return office.desktop.is_open() and office.debug_state() == "ACTIVE", "desktop after the HR call"):
		return
	await _frames(3)
	_check(office.desktop._app == "mail", "g: desktop reopens on Mail (%s), not the Browser" % office.desktop._app)
	_check(office.session.page == "directory", "g: Browser still keeps the Directory page")
	_check(office.debug_item() == main.id and office.session.is_checklist(), "g: %s selected, showing the checklist" % main.id)

	# (e) Checklist rules.
	var cl_step: Dictionary = office.session.step()
	var opts: Array = cl_step.options
	var all_idx: Array[int] = []
	for i: int in opts.size():
		all_idx.append(i)
	var boxes_ok := true
	for i: int in opts.size():
		boxes_ok = boxes_ok and office.desktop.find_child("Check_%d" % i, true, false) is CheckBox
	_check(boxes_ok, "e: CheckBoxes Check_0..Check_%d exist" % (opts.size() - 1))
	_check(_find_button(office.desktop, "Submit report") != null, "e: Submit report button exists")
	before = game.score
	office.debug_check(all_idx)
	await _frames(2)
	_check(game.score == before and office.debug_state() == "ACTIVE", "e: every box ticked -> ignored")
	_check(office.session.checklist_hint(all_idx) == "Tick only the real warning signs.", "e: hint for every box")
	var cv: Node = office.desktop._checklist
	_set_ticks_ui(cv, all_idx)
	await _frames(1)
	var all_pressed := true
	for i: int in opts.size():
		all_pressed = all_pressed and (cv.find_child("Check_%d" % i, true, false) as CheckBox).button_pressed
	_check(all_pressed and (cv.submit_button() as Button).disabled, "e: real Submit disabled with every CheckBox pressed")
	_check(_visible_text(office.desktop).contains("Tick only the real warning signs."), "e: the every-box hint is shown")
	var empty: Array[int] = []
	_set_ticks_ui(cv, empty)
	var real := _real(cl_step)
	var decoys := _decoys(cl_step)
	var w: Array[int] = real.duplicate()
	var missed: int = w.pop_back()
	w.append(decoys[0])
	w.sort()
	office.debug_check(w)
	await _frames(2)
	_check(office.debug_state() == "OUTCOME" and game.score == before - 5, "e: wrong report %s = -5" % [w])
	var fb := _visible_text(office.outcome_panel)
	_check(fb.contains("Not a warning sign: " + str(opts[decoys[0]].text)), "e: feedback names the ticked decoy")
	_check(fb.contains("You missed 1 warning sign(s)"), "e: feedback counts the missed sign")
	_check(not fb.contains(str(opts[missed].text)) and not fb.contains("aegis-benefits-verify"), "e: the missed sign is not named")
	_check(_in_view(_find_button(office.outcome_panel, "Continue")), "k: outcome Continue inside the viewport")
	await _advance_to_active(office)
	_check(office.session.step_index == steps.size() - 1 and office.session.is_checklist(), "e: still on the checklist step")
	before = game.score
	office.debug_check(w)
	await _frames(2)
	_check(game.score == before and office.debug_state() == "ACTIVE", "e: the same report again is ignored")
	office.debug_check(real)
	await _frames(2)
	_check(game.score == before + 10, "e: exact report %s = +10" % [real])
	await _advance_to_active(office)
	_check(office.session.is_done(main.id), "e: main item done")
	_check(_ids(office.session.available_items()).has(cw.id), "g: %s available after the main item" % cw.id)

	# Order: not complete with 3 of 4 items done.
	for it: Dictionary in items:
		if office.session.is_done(it.id) or it.id == cw.id:
			continue
		if not await _play_item(office, 1, it, {}):
			return
	await _frames(2)
	_check(office.debug_state() == "ACTIVE" and not game.completed[0], "g: chapter not complete with 3 of 4 items done")
	if not await _play_item(office, 1, cw, {}):
		return
	if not await _wait(func() -> bool: return office.debug_state() == "FEEDBACK", "FEEDBACK"):
		return
	_check(game.completed[0], "chapter 1 complete after the last item")
	_check(office.debug_tasks() == "5/5", "debug_tasks() == 5/5 (%s)" % office.debug_tasks())


## (h) Chapters 1-3 through the real controls (rows, sender / caller ID / forwarded-details buttons, Copy link
## address + Paste, choice buttons, CheckBoxes + Submit), and (e2) the equal-value alternative routes.
func _test_ui_run() -> void:
	print("--- (h)(e2) UI RUN: chapters 1-4 through the real controls (Ch3 on the phone), alternative correct routes")
	var office := await _new_game()
	if office == null:
		return
	var routes := {}
	var b := _main_item(1)
	routes[b.id] = {0: _choice_by_text(b.steps[0], "Report it to Security as phishing now")}
	var m := _main_item(4)
	routes[m.id] = {1: _choice_by_text(m.steps[1], "Report the call to Security (ext. 1200)")}
	_check(int(routes[b.id][0]) >= 0 and int(routes[m.id][1]) >= 0, "e2: alternative route choices found")
	var opts := {"ui": true, "routes": routes, "no_phone_chapter": 1, "wallet_report": 3}
	for n: int in [1, 2, 3, 4]:
		office = await _play_chapter(office, n, opts)
		# After the last chapter the office is freed (the ending scene loads): only earlier chapters can stop here.
		if office == null and n < CHAPTERS:
			return
	_check(game.item_total(1, b.id) == 30 and game.item_total(1, b.id) == game.item_max(b), "e2: %s by the report route = 30 = item_max (%d)" % [b.id, game.item_total(1, b.id)])
	var steps_taken: Array = game.item_log(1, b.id).map(func(e: Dictionary) -> int: return int(e.step))
	_check(steps_taken == [0, 2, 3], "e2: %s steps 0, 2, 3 (%s)" % [b.id, steps_taken])
	_check(game.item_total(4, m.id) == 30, "e2: %s by the Security route = 30 (%d)" % [m.id, game.item_total(4, m.id)])
	var expect := 0
	for n: int in [1, 2, 3, 4]:
		expect += int(game.chapter_max(n))
	_check(game.score == expect and expect == 330, "score after Ch1-4 best = 330 (got %d)" % game.score)
	_scope_guard(office, "after chapter 4")


## (h) Chapters 7-10 through the real controls (Chat rows, the profile and request buttons, Preview QR link,
## choice buttons, CheckBoxes + Submit; at the cafe the phone's Mail, ChatLink, BancoNation app, Browser bookmarks
## and keypad), and (e2) c6_parking by the intranet route. Starts at Chapter 7 the way Restart Chapter loads a
## chapter (chapters 1-6 marked complete, intro skipped).
func _test_ui_late_chapters() -> void:
	print("--- (h)(e2) UI RUN: chapters 7-10 through the real controls (Chat profile, QR preview, phone at the cafe)")
	if not await _wait(func() -> bool: return not router.is_busy(), "Router idle"):
		return
	game.start_new_game()
	for i: int in 6:
		game.completed[i] = true
	game.begin_chapter(7)
	game.is_restart = true
	_check(change_scene_to_file(OFFICE) == OK, "change scene to office at chapter 7")
	var office := await _wait_office(null)
	if office == null:
		return
	_check(office.debug_state() != "INTRO" and office.debug_place() == "office", "chapter 7 starts at the office without the intro")
	var p := _main_item(9)
	var route := _choice_by_text(p.steps[0], "Check the Facilities page on the intranet yourself")
	_check(route >= 0, "e2: c6_parking intranet route choice found")
	var opts := {"ui": true, "routes": {p.id: {0: route}}, "no_phone_chapter": 9}
	for n: int in [7, 8, 9, 10]:
		office = await _play_chapter(office, n, opts)
		# After the last chapter the office is freed (the ending scene loads): only earlier chapters can stop here.
		if office == null and n < CHAPTERS:
			return
	_check(game.item_total(9, p.id) == 30 and game.item_total(9, p.id) == game.item_max(p), "e2: %s by the intranet route = 30 = item_max (%d)" % [p.id, game.item_total(9, p.id)])
	var steps_taken: Array = game.item_log(9, p.id).map(func(e: Dictionary) -> int: return int(e.step))
	_check(steps_taken == [0, 2, 3], "e2: %s steps 0, 2, 3 (%s)" % [p.id, steps_taken])
	var expect := 0
	for n: int in [7, 8, 9, 10]:
		expect += int(game.chapter_max(n))
	_check(game.score == expect and expect == 300, "score after Ch7-10 best = 300 (got %d)" % game.score)
	_check(game.all_complete(), "all ten chapters complete after the late UI run")
	await _check_ending("%d / %d" % [expect, SPEC_MAX])


# =====================================================================================================
# Chapter and item driver (D.2)
# =====================================================================================================

## Plays chapter n from wherever the office is: repeatedly the first available, unresolved item in data order,
## until FEEDBACK; then continues to the next chapter (ACTIVE) or the ending (LEAVING). Office chapters use the
## workstation and the desk phone; home and cafe chapters use the smartphone (PhoneUI) and its calls.
func _play_chapter(office: Node, n: int, opts: Dictionary) -> Node:
	if not await _drive(office, ["ACTIVE"]):
		return null
	_check(game.current_chapter == n, "chapter %d active (current %d)" % [n, game.current_chapter])
	var ch := Campaign.chapter(n)
	var s: ChapterSession = office.session
	var phone := str(ch.place) != "office"
	_check(office.debug_place() == str(ch.place), "ch%d played at the %s (%s)" % [n, ch.place, office.debug_place()])
	_check(_hud_tasks(office) == "Tasks " + office.debug_tasks(), "ch%d: HUD shows %s" % [n, _hud_tasks(office)])
	var chapter_line := "Chapter %d of %d — %s" % [n, CHAPTERS, ch.title]
	_check(_find_label_prefix(office.hud, "Chapter ") == chapter_line, "ch%d: HUD shows '%s'" % [n, chapter_line])
	if str(ch.device) == "telephone":
		await _frames(2)
		_check(office.builder._ringing and s.phone_incoming(), "g ch%d: the phone rings at the start" % n)
		_check(not office.builder.workstation.enabled, "g ch%d: workstation disabled at the start" % n)
	elif phone:
		await _frames(2)
		_check(office.builder.phone.enabled and not office.builder.is_ringing() and office.builder.phone.prompt == "Check your phone",
			"g ch%d: the phone is usable at the start (Check your phone), not ringing" % n)
		_check(s.objective() == str(ch.objective), "ch%d: HUD objective is the chapter's own '%s' (%s)" % [n, ch.objective, s.objective()])
	var guard := 0
	var played := 0
	while office.debug_state() != "FEEDBACK":
		guard += 1
		var next := {}
		for it: Dictionary in ch.items:
			if s.is_unlocked(it.id) and not s.is_done(it.id):
				next = it
				break
		if next.is_empty() or guard > 12:
			_check(false, "ch%d: no playable item left but no FEEDBACK (state %s)" % [n, office.debug_state()])
			return null
		if not await _play_item(office, n, next, opts):
			return null
		played += 1
		if office.debug_state() == "FEEDBACK":
			break
		_check(office.debug_state() == "ACTIVE" and not s.all_done(), "ch%d: %s done, chapter continues (ACTIVE)" % [n, next.id])
		await _frames(2)
		_check(_hud_tasks(office) == "Tasks " + office.debug_tasks(), "ch%d: HUD task counter %s == %s" % [n, _hud_tasks(office), office.debug_tasks()])
		_check_devices(office, n)
		if played == 1 and int(opts.get("wallet_report", 0)) == n:
			await _check_wallet_report(office)
		if str(next.role) == "main":
			for it: Dictionary in ch.items:
				if (it.unlock_after as Array).has(next.id):
					if str(it.app) == "call":
						_check(s.phone_item() == it.id and s.phone_incoming(), "g ch%d: phone rings for %s after the main item" % [n, it.id])
					elif phone:
						_check(s.is_unlocked(it.id) and (office.builder.phone.enabled or office.phone_ui.is_open()),
							"g ch%d: the phone has %s" % [n, it.id])
					else:
						_check(office.builder.workstation.enabled and s.is_unlocked(it.id), "g ch%d: workstation enabled for %s" % [n, it.id])
	_check(office.feedback_screen.is_open(), "ch%d: feedback screen shown" % n)
	_check(game.completed[n - 1], "ch%d: marked complete" % n)
	_check(office.debug_tasks() == "%d/%d" % [s.task_count(), s.task_count()], "ch%d: tasks %s complete" % [n, office.debug_tasks()])
	_check(_hud_tasks(office) == "Tasks %d/%d" % [s.task_count(), s.task_count()], "ch%d: HUD reaches %s" % [n, _hud_tasks(office)])
	_check(_devices_off(office), "ch%d: devices disabled after completion" % n)
	_check(not office.screen().is_open() and not office.call_ui.is_open() and not office.dial_pad.is_open(), "ch%d: screens closed on completion" % n)
	await _frames(2)
	var bd := office.feedback_screen.find_child("Breakdown", true, false) as Control
	_check(bd != null and bd.get_global_rect().size.y > 0, "k ch%d: feedback breakdown has height" % n)
	_check(_in_view(_find_button(office.feedback_screen, "Continue")), "k ch%d: feedback Continue inside the viewport" % n)
	var fb_text := _visible_text(office.feedback_screen)
	_check(fb_text.contains("/ %d" % game.chapter_max(n)), "ch%d: feedback shows the chapter max %d" % [n, game.chapter_max(n)])
	# The results Fun Fact (never scores).
	var pr := FunFacts.pick(n, "results")
	var ff := office.feedback_screen.find_child("FunFact", true, false) as Control
	_check(ff != null and ff.is_visible_in_tree() and fb_text.contains(FunFacts.display_text(pr)) and fb_text.contains("Source: "),
		"ch%d: the results screen shows the fun fact %s with its source" % [n, pr.get("id", "")])
	if phone:
		for it: Dictionary in ch.items:
			if str(it.role) == "coworker":
				_check(fb_text.contains(str(it.helper_label)), "ch%d: results label the helper item %s" % [n, it.helper_label])
		_check(not fb_text.contains("Security Office") and fb_text.contains("by text"), "ch%d: the debrief comes by text off the clock" % n)
	var score_fb: int = game.score
	var log_fb: int = game.score_log.size()
	office.debug_advance()
	await process_frame
	if n < CHAPTERS:
		if not await _wait(func() -> bool: return office.debug_state() == "BRIEFING", "BRIEFING ch%d" % (n + 1)):
			return null
		var panel := office.hud.find_child("TaskPanel", true, false) as Control
		_check(panel != null and not panel.visible, "g ch%d: HUD task panel hidden during the briefing" % (n + 1))
		await _check_title_fact(office, n + 1, score_fb, log_fb)
		if not await _drive(office, ["ACTIVE"]):
			return null
	else:
		var ok := true
		var frames := 0
		while ok:
			var cs := current_scene
			if cs != null and cs.scene_file_path == ENDING:
				break
			if is_instance_valid(office) and office.is_inside_tree():
				ok = office.debug_state() == "LEAVING" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
			frames += 1
			if frames > 2000:
				ok = false
			await process_frame
		_check(ok, "a: LEAVING (mouse free) on every frame until the ending loads (%d frames)" % frames)
	if is_instance_valid(office) and office.is_inside_tree():
		var shown := _find_label_prefix(office.hud, "Score:")
		_check(shown == "Score: %d" % game.score, "ch%d: HUD shows '%s' (score %d)" % [n, shown, game.score])
	print("  chapter %d done, score %d (%.1f s)" % [n, game.score, _elapsed()])
	return office


## Device rules between items: at the office the workstation is on iff a desktop item is pending and the desk
## phone rings iff a call is incoming; at home and at the cafe the smartphone is usable iff anything waits on it
## and it is not already in hand, and it rings iff a call is incoming.
func _check_devices(office: Node, n: int) -> void:
	var s: ChapterSession = office.session
	var b: Variant = office.builder
	if office.debug_place() == "office":
		_check(b.workstation.enabled == s.desktop_pending(), "ch%d: workstation enabled iff a desktop item is pending" % n)
		_check(b._ringing == (s.phone_incoming() and not office.call_ui.is_open()), "ch%d: phone rings iff a call is incoming" % n)
		return
	var in_hand: bool = office.phone_ui.is_open() or office.call_ui.is_open() or office.dial_pad.is_open()
	_check(b.phone.enabled == ((s.desktop_pending() or s.phone_item() != "") and not in_hand),
		"ch%d: the phone is usable iff something waits on it and it is not in hand" % n)
	_check(b.is_ringing() == (s.phone_incoming() and not office.call_ui.is_open()) and b._ringing == b.is_ringing(),
		"ch%d: the phone rings iff a call is incoming" % n)


func _devices_off(office: Node) -> bool:
	var b: Variant = office.builder
	if office.debug_place() == "office":
		return not b.workstation.enabled and not b.telephone.enabled
	return not b.phone.enabled and not b.is_ringing()


## At a chapter's briefing: the title card shows the chapter's start Fun Fact between the HUD top bar and the
## dialogue panel; showing it changes no score.
func _check_title_fact(office: Node, n: int, score: int, log_size: int) -> void:
	var tc: Variant = office.title_card
	if not await _wait(func() -> bool: return tc.is_showing(), "title card ch%d" % n):
		return
	await _frames(3)
	var f := FunFacts.pick(n, "start")
	if f.is_empty():
		return
	var card: Control = tc.fact_card()
	_check(tc.fact_showing() and str(card.name) == "FunFact" and str(card.fact().get("id", "")) == str(f.id)
			and card.shown_text().begins_with(FunFacts.display_text(f)),
		"ch%d: the title card shows the start fun fact %s" % [n, f.id])
	var rect := card.get_global_rect()
	var dlg := _dialogue_rect(office)
	var top := _hud_top_rect(office)
	_check(rect.size.y > 0 and _view().grow(0.5).encloses(rect) and not rect.intersects(dlg) and not rect.intersects(top),
		"k ch%d: the fun fact sits between the HUD top bar and the dialogue (%s; dialogue %s; top bar %s)" % [n, rect, dlg, top])
	_check(game.score == score and game.score_log.size() == log_size, "ch%d: fun facts never score" % n)


func _dialogue_rect(office: Node) -> Rect2:
	for c: Node in office.dialogue.get_children():
		if c is PanelContainer and (c as Control).is_visible_in_tree():
			return (c as Control).get_global_rect()
	return Rect2()


func _hud_top_rect(office: Node) -> Rect2:
	for l: Node in office.hud.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Score:"):
			var p := l.get_parent()
			while p != null and not (p is PanelContainer):
				p = p.get_parent()
			if p != null:
				return (p as Control).get_global_rect()
	return Rect2()


## KwartaPay's Report a scam sheet is help text only: it never scores, never unlocks and never counts as a check.
func _check_wallet_report(office: Node) -> void:
	var scr: Node = office.screen()
	if not scr.is_open():
		await office.debug_interact("phone")
	var s: ChapterSession = office.session
	var score0: int = game.score
	var log0: int = game.score_log.size()
	var avail0 := _ids(s.available_items())
	var ins0 := s.inspected.duplicate()
	(scr._app_buttons["wallet"] as Button).pressed.emit()
	await _frames(1)
	var report := scr.find_child("WalletReport", true, false) as Button
	_check(report != null and report.is_visible_in_tree(), "h: KwartaPay has Report a scam")
	if report == null:
		return
	report.pressed.emit()
	await _frames(2)
	var sheet := scr.find_child("WalletReportSheet", true, false) as Control
	_check(sheet != null and sheet.is_visible_in_tree() and _visible_text(sheet).contains(str(Campaign.PHONE_APP_PAGES.wallet_report.lines[0])),
		"h: the Report a scam sheet opens")
	_check(game.score == score0 and game.score_log.size() == log0 and _ids(s.available_items()) == avail0 and s.inspected == ins0,
		"h: Report a scam never scores, unlocks or counts as a check")
	var close := scr.find_child("WalletReportClose", true, false) as Button
	if close != null:
		close.pressed.emit()
	await _frames(2)
	_check(scr.find_child("WalletReportSheet", true, false) == null, "h: Close puts the sheet away")


## Opens one item on its surface (D.2): a call on the desk phone (office) or the smartphone (home, cafe); anything
## else on the workstation or the phone, then its row is selected.
func _open_item(office: Node, it: Dictionary, ui: bool) -> bool:
	var id: String = it.id
	var phone: bool = office.debug_place() != "office"
	if str(it.app) == "call":
		if phone:
			if not await _wait(func() -> bool: return office.session.phone_item() == id and office.session.phone_incoming() \
					and (office.builder.phone.enabled or office.phone_ui.is_open()) and office.debug_state() == "ACTIVE", "phone rings for " + id):
				return false
			_check(office.builder.is_ringing(), "%s: the phone is ringing" % id)
			if office.phone_ui.is_open():
				# The call comes in while the phone is in hand: the banner shows the caller and Answer.
				var banner := office.phone_ui.find_child("IncomingCall", true, false) as Control
				_check(banner != null and banner.is_visible_in_tree() and _visible_text(banner).contains(str(it.call.caller_id)),
					"%s: the incoming call banner shows the caller ID" % id)
				if ui:
					var answer := office.phone_ui.find_child("AnswerCall", true, false) as Button
					_check(answer != null and answer.is_visible_in_tree() and not answer.disabled, "h %s: Answer button on the banner" % id)
					if answer != null:
						answer.pressed.emit()
					await _wait(func() -> bool: return office.call_ui.is_open(), "call open after Answer")
				else:
					await office.debug_answer()
			else:
				_check(office.builder.phone.prompt == "Answer your phone", "%s: the phone offers Answer your phone (%s)" % [id, office.builder.phone.prompt])
				await office.debug_interact("phone")
		else:
			if not await _wait(func() -> bool: return office.session.phone_item() == id and office.session.phone_incoming() \
					and office.builder.telephone.enabled and office.debug_state() == "ACTIVE", "phone rings for " + id):
				return false
			_check(office.builder._ringing, "%s: the phone is ringing" % id)
			await office.debug_interact("telephone")
		await _skip_call_lines(office)
		_check(office.call_ui.is_open() and not office.screen().is_open(), "%s: call open, screen closed" % id)
	else:
		var scr: Node = office.screen()
		_check(not office.call_ui.is_open(), "%s: no call open" % id)
		if not scr.is_open():
			await office.debug_interact("phone" if phone else "workstation")
		_check(scr.is_open(), "%s: %s open" % [id, "phone" if phone else "desktop"])
		await _frames(2)
		var app := str(it.app)
		if phone:
			# The phone's message apps are list -> detail: go back to the list to see the rows.
			scr.show_list(app)
			await _frames(2)
		# The list shows the app's available items in data order.
		var want := _ids(office.session.available_items(app))
		var host: Node = _host(scr, app)
		var rows: Array[String] = []
		if host != null:
			for r: Node in host.find_children("Item_*", "Button", true, false):
				rows.append(str(r.name).substr(5))
		_check(rows == want, "%s: %s list order %s" % [id, app, rows])
		if ui:
			# The player opens the item's app (rail or home screen), then presses its row.
			(scr._app_buttons[app] as Button).pressed.emit()
			await _frames(1)
			if phone:
				var back := scr.find_child("BackToList", true, false) as Button
				if back != null and back.is_visible_in_tree():
					back.pressed.emit()
					await _frames(2)
			var row := scr.find_child("Item_" + id, true, false) as Button
			_check(row != null and row.text == "" and row.is_visible_in_tree(), "%s: row button Item_%s with empty text on screen" % [id, id])
			if row != null:
				row.pressed.emit()
		else:
			_check(office.debug_select_item(id), "%s: debug_select_item" % id)
		await _frames(2)
		if phone and ui:
			var back2 := scr.find_child("BackToList", true, false) as Button
			_check(bool(scr._pane_shown(app)) and back2 != null and back2.is_visible_in_tree(), "h %s: the phone shows the item with a Back button" % id)
	_check(office.debug_item() == id, "%s: selected (%s)" % [id, office.debug_item()])
	return office.debug_item() == id


## The list host of a message app on the workstation or the phone ("bank" exists only on the phone).
func _host(scr: Node, app: String) -> Node:
	match app:
		"mail":
			return scr._mail_host
		"messages":
			return scr._messages_host
		"chat":
			return scr._chat_host
		"bank":
			return scr._bank_host
	return null


## Checks the gate (locked, hint per hint_level) and does every required inspection (hooks or real controls).
func _inspect(office: Node, n: int, it: Dictionary, opts: Dictionary) -> void:
	var id: String = it.id
	var req: Array = it.required_inspections
	var st0: Dictionary = it.steps[0]
	var surface: Node = office.call_ui if str(it.app) == "call" else office.screen()
	var level := str(Campaign.chapter(n).hint_level)
	if not req.is_empty():
		_check(not office.session.gate_open(), "c %s: gate closed before inspecting" % id)
		var before: int = game.score
		office.debug_choose(_indices(st0, "correct")[0])
		await _frames(2)
		_check(game.score == before and office.debug_state() == "ACTIVE", "c %s: choosing before inspecting is ignored" % id)
		await _frames(1)
		_check(_ui_states(surface, st0) == _all(st0.choices.size(), true), "c %s: buttons disabled while locked %s" % [id, _ui_states(surface, st0)])
		var hint: String = office.session.gate_hint()
		match level:
			"full":
				_check(hint == "Inspect first: " + ", ".join(_names(req)), "c %s: full hint '%s'" % [id, hint])
			"generic":
				_check(hint == "Inspect before you decide.", "c %s: generic hint '%s'" % [id, hint])
			"none":
				_check(hint == "Responses locked.", "c %s: no-hint level '%s'" % [id, hint])
		if level == "none":
			_check(not _visible_text(surface).contains("Inspect"), "c %s: no visible text says Inspect" % id)
		else:
			_check(_visible_text(surface).contains(hint), "c %s: hint visible" % id)
	if opts.get("ui", false):
		await _ui_inspect(office, it)
	else:
		for i: int in req.size():
			office.debug_inspect(req[i])
			if opts.get("gate_detail", false) and level == "full" and i == 0 and req.size() > 1:
				var rest := req.slice(1)
				var h: String = office.session.gate_hint()
				_check(h == "Inspect first: " + ", ".join(_names(rest)) and not office.session.gate_open(),
					"c %s: after the first inspection the hint shrinks to '%s' and stays locked" % [id, h])
				if id == "c1_orientation":
					_check(h == "Inspect first: link (copy it and paste it in the Browser)", "c: Ch1 exact shrunk hint")
	_check(office.session.gate_open(), "%s: gate open after the inspections (missing %s)" % [id, office.session.missing()])
	await _frames(2)
	if not req.is_empty():
		_check(_ui_states(surface, st0) == _all(st0.choices.size(), false), "c %s: buttons enabled after inspecting" % id)
		_check(office.session.gate_hint() == "Choose a response.", "c %s: hint is Choose a response." % id)
		if level == "none":
			_check(not _visible_text(surface).contains("Inspect"), "c %s: still no visible text says Inspect" % id)


## Inspections through the real controls: sender / caller ID / app name button, forwarded-details button, link
## menu + Paste; on the phone also KwartaPay History rows, the KwartaPay Inbox and Browser bookmarks.
func _ui_inspect(office: Node, it: Dictionary) -> void:
	var id: String = it.id
	if str(it.app) == "call":
		var caller := _find_button_prefix(office.call_ui, "Caller ID:")
		_check(caller != null, "h %s: caller ID button on screen" % id)
		if caller != null:
			caller.pressed.emit()
		await _frames(1)
		var info: String = str(it.call.get("caller_id_info", "")).split("\n")[0]
		_check(_visible_text(office.call_ui).contains(info), "h %s: caller ID info revealed" % id)
		return
	var desk: Node = office.screen()
	var phone: bool = office.debug_place() != "office"
	var msg: Dictionary = it.message
	var app: String = it.app
	var name_text: String = msg.get("from_name", msg.get("sender_label", msg.get("app_name", "")))
	var sender := _find_button_prefix(desk, name_text + "  ")
	_check(sender != null, "h %s: sender button '%s' on screen" % [id, name_text])
	if sender != null:
		sender.pressed.emit()
	await _frames(1)
	var detail: String = msg.get("from_addr", msg.get("sender_number", ""))
	if app == "chat":
		# Chat: the name button opens the account's profile (handle, age, mutual friends, contact).
		detail = str(msg.profile[0])
		_check(office.session.inspected.has("profile"), "h %s: opening the profile marks 'profile'" % id)
	elif app == "bank":
		# The BancoNation app: its name button reveals the app details (publisher, how you opened it).
		detail = str(msg.app_info[0])
		_check(office.session.inspected.has("app_info"), "h %s: opening the app details marks 'app_info'" % id)
	_check(detail != "" and _visible_text(desk).contains(detail), "h %s: sender details revealed (%s)" % [id, detail])
	if phone and app == "mail":
		_check(_visible_text(desk).contains("To: you@mymail.example"), "h %s: phone Mail is addressed to you@mymail.example" % id)
	if (it.required_inspections as Array).has("request"):
		var rb := _find_button_prefix(desk, "Check the request")
		_check(rb != null, "h %s: Check the request button" % id)
		if rb != null:
			rb.pressed.emit()
		await _frames(1)
		_check(_visible_text(desk).contains(str(msg.request.details[0])) and office.session.inspected.has("request"),
			"h %s: request details revealed" % id)
	if (it.required_inspections as Array).has("quote"):
		var qb := _find_button_prefix(desk, "Show forwarded details")
		_check(qb != null, "h %s: Show forwarded details button" % id)
		if qb != null:
			qb.pressed.emit()
		await _frames(1)
		var first: String = str(msg.quote.details[0])
		_check(_visible_text(desk).contains(first), "h %s: forwarded details revealed" % id)
	var qrs: Dictionary = msg.get("qrs", {})
	for qr_id: String in qrs:
		# QR code: drawn in the reading pane; "Preview QR link" shows its real address and never opens it.
		_check(not office.session.gate_open(), "h %s: still locked before QR %s is previewed" % [id, qr_id])
		var block := desk.find_child("QR_" + qr_id, true, false) as Control
		var img := block.find_child("QRImage", true, false) as TextureRect if block != null else null
		_check(block != null and block.is_visible_in_tree() and img != null and img.texture != null,
			"h %s: QR code %s drawn in the email" % [id, qr_id])
		var url := str(qrs[qr_id])
		_check(not _visible_text(desk).contains(url.substr(url.find("://") + 3)), "h %s: QR link hidden before the preview" % id)
		var pb := _find_button_prefix(block if block != null else desk, "Preview QR link")
		_check(pb != null, "h %s: Preview QR link button" % id)
		if pb != null:
			pb.pressed.emit()
		await _frames(2)
		var shown := _visible_text(desk)
		var host := url.substr(url.find("://") + 3)
		host = host.substr(0, host.find("/")) if host.find("/") >= 0 else host
		_check(shown.contains(host) and shown.contains("The website was not opened."), "h %s: QR preview shows %s" % [id, host])
		_check(office.session.inspected.has("qr:" + qr_id) and desk._app == app,
			"h %s: qr:%s inspected, nothing opened, still in %s" % [id, qr_id, app])
	for link_id: String in msg.get("links", {}):
		_check(not office.session.gate_open(), "h %s: still locked before link %s is pasted" % [id, link_id])
		(desk._app_buttons[app] as Button).pressed.emit()
		await _frames(1)
		var body := _find_rich_with(desk, "[url=%s]" % link_id)
		_check(body != null, "h %s: body shows link %s" % [id, link_id])
		if body == null:
			continue
		body.meta_clicked.emit(link_id)
		var menus: Array[Node] = desk.find_children("*", "PopupMenu", true, false)
		_check(menus.size() == 1 and (menus[0] as PopupMenu).get_item_text(0) == "Copy link address", "h %s: link click opens 'Copy link address'" % id)
		if menus.is_empty():
			continue
		var menu := menus[0] as PopupMenu
		menu.id_pressed.emit(menu.get_item_id(0))
		menu.hide()
		_check(office.session.clipboard == msg.links[link_id], "h %s: in-game clipboard holds the real URL" % id)
		(desk._app_buttons["browser"] as Button).pressed.emit()
		var paste := _find_button(desk, "Paste")
		_check(paste != null, "h %s: Browser Paste button" % id)
		if paste != null:
			paste.pressed.emit()
		await _frames(2)
		_check(office.session.pasted_url == msg.links[link_id], "h %s: pasted URL in the address bar" % id)
		_check(_visible_text(desk).contains("The website was not opened."), "h %s: 'not opened' note shown" % id)
	for k: Variant in it.required_inspections:
		var key := str(k)
		if key.begins_with("tx:"):
			await _ui_wallet_tx(office, id, key.substr(3))
		elif key == "wallet_inbox":
			await _ui_wallet_inbox(office, id)
		elif key.begins_with("page:"):
			await _ui_bookmark(office, id, key.substr(5))


## KwartaPay History: the item's transfer row (Tx_<id>) opens its details and counts as checking it; a baseline row
## (Hist_<i>) only shows its details. The balance is base_balance plus the unlocked items' transfers.
func _ui_wallet_tx(office: Node, id: String, tx_id: String) -> void:
	var scr: Node = office.screen()
	_check(not office.session.inspected.has("tx:" + tx_id), "h %s: tx:%s not checked yet" % [id, tx_id])
	(scr._app_buttons["wallet"] as Button).pressed.emit()
	await _frames(1)
	var tab := scr.find_child("WalletTab_history", true, false) as Button
	if tab != null:
		tab.pressed.emit()
	await _frames(2)
	var s: ChapterSession = office.session
	var wallet: Dictionary = s.chapter.wallet
	var total := float(wallet.base_balance)
	for t: Dictionary in s.all_wallet_tx():
		total += float(t.value) if str(t.dir) == "in" else -float(t.value)
	var bal := scr.find_child("BalanceAmount", true, false) as Label
	_check(bal != null and bal.is_visible_in_tree() and bal.text == _peso(total), "h %s: KwartaPay balance %s (%s)" % [id, _peso(total), bal.text if bal != null else ""])
	var base := scr.find_child("Hist_0", true, false) as Button
	if base != null:
		var count0 := s.inspected.size()
		base.pressed.emit()
		await _frames(1)
		_check(s.inspected.size() == count0, "h %s: a baseline History row is not a check" % id)
		base.pressed.emit()
	var row := scr.find_child("Tx_" + tx_id, true, false) as Button
	_check(row != null and row.text == "" and row.is_visible_in_tree(), "h %s: KwartaPay History row Tx_%s on screen" % [id, tx_id])
	if row == null:
		return
	row.pressed.emit()
	await _frames(1)
	var tx: Dictionary = (s.item(s.tx_owner(tx_id)).message.wallet_tx as Dictionary)[tx_id]
	var shown := _visible_text(scr)
	_check(shown.contains("Ref: " + str(tx.ref)) and shown.contains(str(tx.contact)), "h %s: the transfer details show (ref %s, %s)" % [id, tx.ref, tx.contact])
	_check(s.inspected.has("tx:" + tx_id), "h %s: tx:%s checked" % [id, tx_id])


## The KwartaPay Inbox tab (official notices) counts as checking it (wallet_inbox).
func _ui_wallet_inbox(office: Node, id: String) -> void:
	var scr: Node = office.screen()
	(scr._app_buttons["wallet"] as Button).pressed.emit()
	await _frames(1)
	var tab := scr.find_child("WalletTab_inbox", true, false) as Button
	_check(tab != null and tab.is_visible_in_tree(), "h %s: KwartaPay Inbox tab on screen" % id)
	if tab == null:
		return
	tab.pressed.emit()
	await _frames(2)
	var notes: Array = office.session.chapter.wallet.inbox
	_check(_visible_text(scr).contains(str(notes[0].title)), "h %s: the Inbox shows the official notices" % id)
	_check(office.session.inspected.has("wallet_inbox"), "h %s: wallet_inbox checked" % id)


## A phone Browser bookmark shows its page and counts as checking it (page:<id>).
func _ui_bookmark(office: Node, id: String, page_id: String) -> void:
	var scr: Node = office.screen()
	(scr._app_buttons["browser"] as Button).pressed.emit()
	await _frames(1)
	var b := scr.find_child("Bookmark_" + page_id, true, false) as Button
	_check(b != null and b.is_visible_in_tree() and _in_view(b), "h %s: bookmark %s on screen" % [id, page_id])
	if b == null:
		return
	b.pressed.emit()
	await _frames(2)
	var page: Dictionary = Campaign.PAGES[page_id]
	_check(_visible_text(scr).contains(str(page.lines[0])) and office.session.page == page_id, "h %s: the %s page is shown" % [id, page_id])
	_check(office.session.inspected.has("page:" + page_id), "h %s: page:%s checked" % [id, page_id])


## Plays one item from start to resolution (D.2). Returns false on a driver failure.
func _play_item(office: Node, n: int, it: Dictionary, opts: Dictionary) -> bool:
	var id: String = it.id
	var ui: bool = opts.get("ui", false)
	var wrong_first: bool = opts.get("wrong_first", false)
	var route: Dictionary = (opts.get("routes", {}) as Dictionary).get(id, {})
	var phone: bool = office.debug_place() != "office"
	if not await _open_item(office, it, ui):
		return false
	await _inspect(office, n, it, opts)
	var steps: Array = it.steps
	var si := 0
	var guard := 0
	while guard < 10:
		guard += 1
		var st: Dictionary = steps[si]
		_check(office.session.step_index == si and office.debug_item() == id, "%s: on step %d" % [id, si])
		if si > 0 and str(it.app) == "call":
			_check(not office.session.phone_incoming(), "g %s step %d: the phone does not ring mid-item" % [id, si])
		if int(opts.get("no_phone_chapter", 0)) == n:
			_check(not office.builder.telephone.enabled, "e2 %s step %d: the telephone is not needed" % [id, si])
		if str(st.get("wait_for", "")) == "telephone":
			if not await _place_call(office, it, si, st, opts):
				return false
		await _skip_call_lines(office)
		await _layout_check(office, id, si, st)
		var on_call := str(st.get("surface", "desktop")) == "call"
		var next := -1
		var opened := ""
		var opened_app := ""
		if str(st.get("kind", "choices")) == "checklist":
			var r := await _do_checklist(office, it, si, st, opts)
			if r == -2:
				return false
			next = r
		else:
			var picks: Array[int] = []
			if wrong_first:
				picks.append_array(_indices(st, "wrong"))
			picks.append(int(route[si]) if route.has(si) else _indices(st, "correct")[0])
			for i: int in picks:
				var choice: Dictionary = st.choices[i]
				var before: int = game.score
				var events_before: int = game.events.size()
				if ui:
					var surface: Node = office.call_ui if office.call_ui.is_open() else office.screen()
					var btn := _find_button(surface, str(choice.text))
					_check(btn != null and not btn.disabled, "h %s step %d: button '%s' enabled" % [id, si, choice.text])
					if btn == null:
						return false
					btn.pressed.emit()
				else:
					office.debug_choose(i)
				await _frames(2)
				_check(office.debug_state() == "OUTCOME", "%s step %d choice %d (%s): outcome shown" % [id, si, i, choice.outcome])
				var delta := _const("CORRECT") if choice.outcome == "correct" else _const("WRONG")
				_check(game.score == before + delta, "%s step %d choice %d: score %+d (now %d)" % [id, si, i, delta, game.score])
				# The session events behind OTP Bantay and Not Your Mule (never scored).
				var want_events := 0
				if bool(choice.get("shares_secret", false)):
					want_events += 1
				if str(it.get("trap", "")) == "mule" and choice.outcome != "correct":
					want_events += 1
				_check(game.events.size() == events_before + want_events, "%s step %d choice %d: %d event(s) logged" % [id, si, i, want_events])
				if choice.outcome == "wrong":
					await _advance_to_active(office)
					_check(office.session.is_disabled(i), "%s step %d: wrong choice %d disabled" % [id, si, i])
					await _skip_call_lines(office)
					var active_ui: Node = office.call_ui if office.call_ui.is_open() else office.screen()
					var states := _ui_states(active_ui, st)
					_check(states.size() == st.choices.size() and states[i], "%s step %d: wrong choice %d button disabled %s" % [id, si, i, states])
					var again: int = game.score
					office.debug_choose(i)
					await _frames(2)
					_check(game.score == again, "%s step %d: disabled choice cannot be picked again" % [id, si])
				else:
					office.debug_advance()
					await _frames(1)
					next = int(choice.get("next_step", -1))
					opened = str(choice.get("opens", ""))
					opened_app = str(choice.get("opens_app", ""))
		if next < 0:
			if not await _wait(func() -> bool: return office.debug_state() in ["ACTIVE", "FEEDBACK"], "%s resolved" % id):
				return false
			_check(office.session.is_done(id), "%s: resolved" % id)
			if opened != "":
				_check(office.session.page == opened, "%s: a resolving choice opens the %s page" % [id, opened])
			if opened_app != "" and office.debug_state() == "ACTIVE":
				_check_opened_app(office, id, opened_app)
			return true
		if not await _wait(func() -> bool: return office.debug_state() == "ACTIVE", "ACTIVE after %s step %d" % [id, si]):
			return false
		var nst: Dictionary = steps[next]
		# A correct call choice with a reply (IT on ext. 1100) answers in the transcript under its own divider.
		if on_call and office.call_ui.is_open() and str(nst.get("surface", "desktop")) == "call" and next != si:
			var picked: Dictionary = st.choices[int(route[si]) if route.has(si) else _indices(st, "correct")[0]] if st.has("choices") else {}
			var reply: String = str(picked.get("response_line", ""))
			if reply.contains(": "):
				var said := reply.substr(reply.find(": ") + 2)
				var tx := _visible_text(office.call_ui)
				_check(tx.contains(said) and tx.contains("EXT 1100: IT HELPDESK"), "%s step %d: the reply is in the call transcript" % [id, si])
		if str(nst.get("surface", "desktop")) == "desktop" and on_call:
			if not await _wait(func() -> bool: return office.screen().is_open() and office.debug_state() == "ACTIVE", "desktop after the call"):
				return false
			_check(office.debug_item() == id and office.screen()._app == str(it.app), "%s: back at the desk on %s with the item selected" % [id, it.app])
		if on_call and str(nst.get("wait_for", "")) == "telephone" and phone:
			# The call ended and the next step is a call the player places: the keypad opens at once (c7_agent).
			_check(office.dial_pad.is_open() and not office.call_ui.is_open(), "%s step %d: hanging up opens the keypad at once" % [id, si])
		if opened != "":
			_check(office.session.page == opened, "%s: Browser shows %s (page %s)" % [id, opened, office.session.page])
		if opened_app != "":
			_check_opened_app(office, id, opened_app)
		si = next
	_check(false, "%s: too many steps" % id)
	return false


## A correct choice's opens_app: the phone switched to that app view and consumed session.phone_app.
func _check_opened_app(office: Node, id: String, target: String) -> void:
	var scr: Node = office.phone_ui
	var app := "wallet" if target.begins_with("wallet") else target
	_check(office.session.phone_app == "" and scr.is_open() and str(scr._app) == app, "%s: opens_app %s shows the %s app (%s)" % [id, target, app, scr._app])
	if target == "wallet_inbox":
		_check(str(scr._wallet_tab) == "inbox", "%s: the KwartaPay Inbox tab is open" % id)


## A wait_for "telephone" step: the device prompt names the call, choices wait, then the keypad (the desk phone,
## the phone's Calls keypad, or opened at once after a call) dials the step's number (its "dial", else the EXT
## in its call header) and the call opens. opts.misdial {item id: number} dials a wrong number first.
func _place_call(office: Node, it: Dictionary, si: int, st: Dictionary, opts: Dictionary) -> bool:
	var id: String = it.id
	var ui: bool = opts.get("ui", false)
	var phone: bool = office.debug_place() != "office"
	var dev: Variant = office.builder.phone if phone else office.builder.telephone
	_check(not office.call_ui.is_open(), "%s step %d: waits for the telephone" % [id, si])
	_check(str(dev.prompt) == str(st.trigger_prompt) and (phone or dev.enabled),
		"%s step %d: %s prompt '%s' (%s)" % [id, si, "phone" if phone else "telephone", st.trigger_prompt, dev.prompt])
	if phone:
		_check(office.session.objective() == str(st.wait_objective), "%s step %d: objective '%s'" % [id, si, st.wait_objective])
	var score_wait: int = game.score
	if str(st.get("kind", "choices")) != "checklist":
		office.debug_choose(_indices(st, "correct")[0])
		await _frames(2)
	_check(game.score == score_wait, "%s step %d: choices ignored until the phone is used" % [id, si])
	if not office.dial_pad.is_open():
		if not phone:
			await office.debug_interact("telephone")
		elif office.phone_ui.is_open():
			if ui:
				# Calls app -> Keypad.
				var home := office.phone_ui.find_child("HomeButton", true, false) as Button
				if home != null:
					home.pressed.emit()
				await _frames(1)
				(office.phone_ui._app_buttons["calls"] as Button).pressed.emit()
				await _frames(2)
				var keypad := office.phone_ui.find_child("CallsKeypad", true, false) as Button
				_check(keypad != null and keypad.is_visible_in_tree() and not keypad.disabled
						and _visible_text(office.phone_ui).contains(str(st.wait_objective)),
					"h %s step %d: Calls shows the Keypad and what to dial" % [id, si])
				if keypad != null:
					keypad.pressed.emit()
				await _frames(2)
			else:
				await office.debug_open_keypad()
		else:
			_check(dev.enabled, "%s step %d: the phone is usable for the call" % [id, si])
			await office.debug_interact("phone")
			if not office.dial_pad.is_open() and office.phone_ui.is_open():
				await office.debug_open_keypad()
	_check(office.dial_pad.is_open() and not office.call_ui.is_open(), "%s step %d: the keypad is open" % [id, si])
	var number := str(st.dial) if st.has("dial") else str(RegEx.create_from_string("EXT\\s*(\\d+)").search(str(st.call_header)).get_string(1))
	_check(office.session.expected_number() == number, "%s step %d: the number to dial is %s (%s)" % [id, si, number, office.session.expected_number()])
	var wrong := str((opts.get("misdial", {}) as Dictionary).get(id, ""))
	if wrong != "":
		var score0: int = game.score
		var misdials: int = game.events_of("misdial").size()
		await office.debug_dial(wrong)
		await _frames(1)
		_check(game.score == score0, "%s step %d: a wrong number costs nothing" % [id, si])
		var mlog: Array[Dictionary] = game.events_of("misdial")
		_check(mlog.size() == misdials + 1 and str(mlog.back().number) == wrong and bool(mlog.back().hotline) == st.has("dial") and str(mlog.back().item) == id,
			"%s step %d: the misdial is logged (%s)" % [id, si, mlog.back() if not mlog.is_empty() else {}])
		_check(office.dial_pad.is_open() and not office.call_ui.is_open() and office.builder.phone_display() == "NO ANSWER"
				and _visible_text(office.dial_pad).contains(wrong + " is not answering"),
			"%s step %d: %s does not answer (%s)" % [id, si, wrong, office.builder.phone_display()])
		if st.has("dial"):
			_check(not Achievements._earned("hotline_hero"), "%s: a misdialed hotline loses Hotline Hero" % id)
	await office.debug_dial(number)
	_check(office.call_ui.is_open() and not office.screen().is_open(), "%s step %d: dialing %s opens the call" % [id, si, number])
	var display := ("HOTLINE " if phone else "EXT ") + number
	_check(office.builder.phone_display() == display, "%s step %d: the phone screen shows %s (%s)" % [id, si, display, office.builder.phone_display()])
	if phone:
		var card := _visible_text(office.call_ui)
		_check(card.contains(str(st.call_header)), "%s step %d: the call header %s" % [id, si, st.call_header])
	return true


## A checklist step: optionally one wrong report first, then the exact set. Returns the next step, -1 when the
## item resolves, -2 on failure.
func _do_checklist(office: Node, it: Dictionary, si: int, st: Dictionary, opts: Dictionary) -> int:
	var id: String = it.id
	var ui: bool = opts.get("ui", false)
	var real := _real(st)
	var decoys := _decoys(st)
	if opts.get("wrong_first", false):
		var worst: bool = (opts.get("worst", []) as Array).has(id)
		var w: Array[int] = []
		if worst:
			w = decoys.duplicate()
		else:
			w = real.duplicate()
			w.remove_at(0)
			w.append(decoys[0])
			w.sort()
		var before: int = game.score
		if not await _submit(office, w, ui, id):
			return -2
		_check(office.debug_state() == "OUTCOME" and game.score == before - 5, "%s: wrong report %s = -5 (score %d)" % [id, w, game.score])
		await _frames(2)
		var fb := _visible_text(office.outcome_panel)
		_check(fb.contains("Not a warning sign"), "%s: feedback explains the decoy" % id)
		if not worst:
			_check(fb.contains("You missed 1 warning sign(s)"), "%s: feedback counts 1 missed sign" % id)
		else:
			_check(_in_view(_find_button(office.outcome_panel, "Continue")), "k %s: Continue inside the viewport after the worst-case report" % id)
		await _advance_to_active(office)
		_check(office.session.step_index == si, "%s: still on the checklist" % id)
		var again: int = game.score
		office.debug_check(w)
		await _frames(2)
		_check(game.score == again and office.debug_state() == "ACTIVE", "%s: the same report again is ignored" % id)
	var before2: int = game.score
	if not await _submit(office, real, ui, id):
		return -2
	_check(office.debug_state() == "OUTCOME" and game.score == before2 + 10, "%s: exact report %s = +10" % [id, real])
	office.debug_advance()
	await _frames(1)
	return int(st.get("next_step", -1))


## Submits a tick set: the hook, or ticking the real CheckBoxes and pressing the real Submit button.
func _submit(office: Node, t: Array[int], ui: bool, id: String) -> bool:
	if not ui:
		office.debug_check(t)
		await _frames(2)
		return true
	var cv: Node = office.call_ui._checklist if office.call_ui.is_open() else office.screen()._checklist
	_check(cv != null, "h %s: checklist view on screen" % id)
	if cv == null:
		return false
	_set_ticks_ui(cv, t)
	await _frames(1)
	_check(office.session.ticks() == t, "h %s: ticking the boxes stores %s (%s)" % [id, t, office.session.ticks()])
	var sub := cv.submit_button() as Button
	_check(sub != null and not sub.disabled, "h %s: Submit enabled" % id)
	if sub == null or sub.disabled:
		return false
	sub.pressed.emit()
	await _frames(2)
	return true


func _set_ticks_ui(cv: Node, t: Array[int]) -> void:
	var i := 0
	while true:
		var box := cv.find_child("Check_%d" % i, true, false) as CheckBox
		if box == null:
			break
		box.button_pressed = t.has(i)
		i += 1


## (k) Layout at 1280x720: DecisionBar inside the viewport, Submit inside on checklists, phone card hidden on a
## call checklist.
func _layout_check(office: Node, id: String, si: int, st: Dictionary) -> void:
	await _frames(2)
	var checklist := str(st.get("kind", "choices")) == "checklist"
	var scr: Node = office.screen()
	if scr.is_open():
		var bar := scr.find_child("DecisionBar", true, false) as Control
		_check(bar != null and bar.get_global_rect().end.y <= _view().end.y + 0.5, "k %s step %d: DecisionBar inside the viewport (%s)" % [id, si, bar.get_global_rect() if bar != null else Rect2()])
		if office.debug_place() != "office":
			var frame := scr.find_child("Phone", true, false) as Control
			_check(frame != null and _view().grow(0.5).encloses(frame.get_global_rect()) and not frame.get_global_rect().intersects(bar.get_global_rect()),
				"k %s step %d: the phone and its DecisionBar fit side by side" % [id, si])
		if checklist:
			var cv: Node = scr._checklist
			_check(cv != null and _in_view(cv.submit_button()), "k %s step %d: Submit inside the viewport" % [id, si])
	elif office.call_ui.is_open() and checklist:
		var cv2: Node = office.call_ui._checklist
		_check(cv2 != null and _in_view(cv2.submit_button()), "k %s step %d: call Submit inside the viewport" % [id, si])
		var card := office.call_ui.find_child("PhoneCard", true, false) as Control
		_check(card != null and not card.is_visible_in_tree(), "k %s step %d: phone card hidden on the checklist" % [id, si])


## (a)/(b) The ending scene: final score tile, tasks tile, breakdown scroll and buttons inside the viewport.
func _check_ending(score_text: String) -> void:
	await _expect_scene(ENDING)
	var ending := current_scene
	if ending == null:
		return
	await create_timer(0.8).timeout
	var shown := _visible_text(ending)
	_check(shown.contains(score_text), "ending shows '%s'" % score_text)
	var total := 0
	for n: int in range(1, CHAPTERS + 1):
		total += ChapterSession.new(Campaign.chapter(n)).task_count()
	_check(shown.contains("Tasks completed: %d of %d" % [total, total]) and total == SPEC_TASKS_TOTAL, "ending shows 'Tasks completed: %d of %d'" % [SPEC_TASKS_TOTAL, SPEC_TASKS_TOTAL])
	var bd := ending.find_child("Breakdown", true, false) as Control
	_check(bd != null and bd.get_global_rect().size.y > 0, "k ending breakdown has height")
	var main_menu := _find_button(ending, "Main Menu")
	_check(_in_view(main_menu), "k ending Main Menu button inside the viewport")


## (j) Scope guard: no typing controls, no selectable text in the office tree.
func _scope_guard(office: Node, when: String) -> void:
	var bad: Array[String] = []
	for cls: String in ["LineEdit", "TextEdit", "CodeEdit", "SpinBox", "FileDialog"]:
		for node: Node in office.find_children("*", cls, true, false):
			# Godot's PopupMenu carries a hidden, engine-internal search field; it is allowed only while the
			# menu's search bar is disabled (the "Copy link address" menu takes no typing).
			var menu := _popup_ancestor(node)
			if node is LineEdit and menu != null and not menu.search_bar_enabled and not menu.allow_search 					and not (node as LineEdit).visible:
				continue
			bad.append("%s %s" % [cls, office.get_path_to(node)])
	for r: Node in office.find_children("*", "RichTextLabel", true, false):
		if (r as RichTextLabel).selection_enabled:
			bad.append("selectable " + str(r.name))
	_check(bad.is_empty(), "j (%s): no LineEdit/TextEdit/CodeEdit/SpinBox/FileDialog or selectable text %s" % [when, bad])
	_check(office.hud != null and office.hud.is_inside_tree(), "j (%s): HUD instantiated" % when)
	# The scan above covers the smartphone too: PhoneUI lives in the same office tree.
	_check(office.phone_ui != null and office.phone_ui.is_inside_tree() and office.is_ancestor_of(office.phone_ui),
		"j (%s): PhoneUI is part of the scanned office tree" % when)


func _popup_ancestor(node: Node) -> PopupMenu:
	var p := node.get_parent()
	while p != null:
		if p is PopupMenu:
			return p as PopupMenu
		p = p.get_parent()
	return null


func _unsafe_to_game_over(office: Node, index: int) -> bool:
	office.debug_choose(index)
	await _frames(2)
	_check(office.debug_state() == "OUTCOME" and office.outcome_panel.is_open(), "unsafe choice shows the outcome first (%s)" % office.debug_state())
	office.debug_advance()
	await _frames(2)
	_check(office.debug_state() == "COMPROMISED" and office.compromise_notice.is_open(), "compromise notice after the outcome (%s)" % office.debug_state())
	var notice := _visible_text(office.compromise_notice)
	if office.debug_place() == "office":
		_check(notice.contains("Black Veil"), "compromise notice names Black Veil")
	else:
		# Off the clock (decisions.md item 17): a personal loss, never Aegis or Black Veil.
		_check(not notice.contains("Black Veil") and not notice.contains("Aegis") and notice.contains("YOUR ACCOUNT WAS COMPROMISED"),
			"compromise notice at the %s: a personal loss, no Aegis or Black Veil" % office.debug_place())
	if not await _wait(func() -> bool: return office.debug_state() == "GAME_OVER", "GAME_OVER"):
		return false
	_check(office.game_over.is_open(), "game over screen open")
	_check(not office.screen().is_open() and not office.call_ui.is_open() and not office.dial_pad.is_open(), "screen and call closed")
	if office.debug_place() != "office":
		_check(not office.builder.phone.enabled and not office.builder.is_ringing(), "the phone is put away after the breach")
	return true


# =====================================================================================================
# Helpers
# =====================================================================================================

func _main_item(n: int) -> Dictionary:
	for it: Dictionary in Campaign.chapter(n).items:
		if str(it.role) == "main":
			return it
	return {}


func _ids(items: Array) -> Array[String]:
	var out: Array[String] = []
	for it: Dictionary in items:
		out.append(str(it.get("id", "")))
	return out


func _names(keys: Array) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in keys:
		var key := str(k)
		if key.begins_with("link:"):
			out.append("link (copy it and paste it in the Browser)")
		elif key.begins_with("tx:"):
			out.append("the KwartaPay history entry")
		elif key.begins_with("page:"):
			out.append("the %s page" % Campaign.PAGES[key.substr(5)].title)
		elif key == "wallet_inbox":
			out.append("the KwartaPay inbox")
		elif key == "app_info":
			out.append("the app details")
		else:
			out.append({"sender": "sender", "sender_number": "sender number", "caller_id": "caller ID",
				"quote": "forwarded message details", "profile": "profile", "request": "request"}.get(key, key) 				if not key.begins_with("qr:") else "QR code link (preview it)")
	return out


func _real(st: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i: int in st.options.size():
		if bool(st.options[i].get("real", false)):
			out.append(i)
	return out


func _decoys(st: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i: int in st.options.size():
		if not bool(st.options[i].get("real", false)):
			out.append(i)
	return out


func _choice_by_text(st: Dictionary, text: String) -> int:
	var choices: Array = st.get("choices", [])
	for i: int in choices.size():
		if str(choices[i].text) == text:
			return i
	return -1


## "₱1,740.50": the KwartaPay balance format.
func _peso(value: float) -> String:
	var cents := int(roundf(absf(value) * 100.0))
	var whole := str(int(cents / 100.0))
	var grouped := ""
	while whole.length() > 3:
		grouped = "," + whole.substr(whole.length() - 3) + grouped
		whole = whole.substr(0, whole.length() - 3)
	return "%s₱%s%s.%02d" % ["-" if value < 0.0 else "", whole, grouped, cents % 100]


func _hud_tasks(office: Node) -> String:
	return _find_label_prefix(office.hud, "Tasks ")


func _advance_to_active(office: Node) -> void:
	office.debug_advance()
	await _frames(1)
	await _wait(func() -> bool: return office.debug_state() == "ACTIVE", "ACTIVE")


func _view() -> Rect2:
	return root.get_visible_rect()


func _in_view(c: Control) -> bool:
	if c == null or not c.is_visible_in_tree():
		return false
	return _view().grow(0.5).encloses(c.get_global_rect())


## Starts a new game and loads the office as the current scene. Returns the office root.
func _new_game() -> Node:
	if not await _wait(func() -> bool: return not router.is_busy(), "Router idle"):
		return null
	game.start_new_game()
	var err := change_scene_to_file(OFFICE)
	_check(err == OK, "change scene to office")
	return await _wait_office(null)


## Waits for a (new) office scene that is not `old` and returns it.
func _wait_office(old: Node) -> Node:
	# Capture the id, not the node: the old office is freed by the scene change.
	var old_id: int = old.get_instance_id() if old != null else 0
	var ok := await _wait(func() -> bool:
		var cs := current_scene
		return cs != null and is_instance_valid(cs) and cs.get_instance_id() != old_id and cs.scene_file_path == OFFICE \
			and cs.has_method("debug_state") and not router.is_busy(), "office scene loaded")
	if not ok:
		return null
	await process_frame
	return current_scene


func _expect_scene(path: String) -> void:
	var ok := await _wait(func() -> bool:
		var cs := current_scene
		return cs != null and cs.scene_file_path == path and not router.is_busy(), "scene %s" % path)
	_check(ok, "current scene is %s" % path)


## Presses advance through dialogue / outcome / feedback until the office reaches one of `targets`.
func _drive(office: Node, targets: Array) -> bool:
	var t0 := Time.get_ticks_msec()
	var frame := 0
	while true:
		if not is_instance_valid(office):
			_check(false, "office freed while waiting for %s" % [targets])
			return false
		var st: String = office.debug_state()
		if targets.has(st):
			return true
		if (Time.get_ticks_msec() - t0) / 1000.0 > WAIT_TIMEOUT or _elapsed() > TOTAL_TIMEOUT:
			_check(false, "timeout waiting for %s (state %s)" % [targets, st])
			return false
		frame += 1
		if ADVANCE_STATES.has(st) and frame % 2 == 0:
			office.debug_advance()
		await process_frame
	return false


func _wait(cond: Callable, what: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > WAIT_TIMEOUT or _elapsed() > TOTAL_TIMEOUT:
			_check(false, "timeout waiting for " + what)
			return false
		await process_frame
	return true


## The call UI plays its lines before showing the decision area; "advance" skips the playback.
func _skip_call_lines(office: Node) -> void:
	await _frames(2)
	if office.call_ui.is_open() and office.debug_state() == "ACTIVE":
		office.debug_advance()
		await _frames(2)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


## Choice indices of a step with the given outcome, in order.
func _indices(step: Dictionary, outcome: String) -> Array[int]:
	var out: Array[int] = []
	var choices: Array = step.get("choices", [])
	for i: int in choices.size():
		if choices[i].outcome == outcome:
			out.append(i)
	return out


## Disabled flags of the visible choice buttons on a surface, in the step's choice order (matched by text).
func _ui_states(surface: Node, step: Dictionary) -> Array[bool]:
	var out: Array[bool] = []
	var buttons: Array[Node] = surface.find_children("*", "Button", true, false)
	for c: Dictionary in step.get("choices", []):
		for b: Node in buttons:
			var btn := b as Button
			if btn.text == c.text and btn.is_visible_in_tree() and not btn.is_queued_for_deletion():
				out.append(btn.disabled)
				break
	return out


func _all(count: int, value: bool) -> Array[bool]:
	var out: Array[bool] = []
	for i: int in count:
		out.append(value)
	return out


func _find_label_prefix(node: Node, prefix: String) -> String:
	for l: Node in node.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with(prefix) and not l.is_queued_for_deletion():
			return (l as Label).text
	return ""


func _find_button_prefix(node: Node, prefix: String) -> Button:
	for b: Node in node.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.text.begins_with(prefix) and btn.is_visible_in_tree() and not btn.is_queued_for_deletion():
			return btn
	return null


func _find_rich_with(node: Node, needle: String) -> RichTextLabel:
	for r: Node in node.find_children("*", "RichTextLabel", true, false):
		if (r as RichTextLabel).text.contains(needle) and (r as RichTextLabel).is_visible_in_tree():
			return r as RichTextLabel
	return null


## All visible Label / RichTextLabel / Button text under a node (parsed text for rich labels).
func _visible_text(node: Node) -> String:
	var parts: PackedStringArray = []
	var all: Array[Node] = [node]
	all.append_array(node.find_children("*", "", true, false))
	for c: Node in all:
		var ci := c as CanvasItem
		if ci == null or not ci.is_visible_in_tree() or c.is_queued_for_deletion():
			continue
		if c is Label:
			parts.append((c as Label).text)
		elif c is RichTextLabel:
			parts.append((c as RichTextLabel).get_parsed_text())
		elif c is Button:
			parts.append((c as Button).text)
	return "\n".join(parts)


func _find_button(node: Node, text: String) -> Button:
	for b: Node in node.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.text == text and btn.is_visible_in_tree() and not btn.is_queued_for_deletion():
			return btn
	return null


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
		print("PASS ", what)
	else:
		_failures += 1
		print("FAIL ", what)


func _const(name: String) -> int:
	return int(game.get_script().get_script_constant_map()[name])


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0
