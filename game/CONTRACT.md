# Vigilant prototype: build contract

This is a rushed prototype (deadline Saturday 2026-11-07) of the design in `../docs/2026-11-01-vigilant-godot-prototype-design.md`.
**The paper's Objectives 1-7 are the most important rule.** Every feature below traces to one. Build nothing that is not listed.
Where this contract and the design doc differ, follow this contract (it is the lean prototype version).

## Task model (merged 2026-11-03; `TASKS-SPEC.md` wins wherever it differs from Modules B-E below)

Still exactly four chapters in the paper's order (email phishing, smishing, vishing, BEC). Each chapter is a workday
of **4 items** of its own attack type (16 in all), played in Mail, Messages or on the desk phone:
- **genuine** item (handle it normally = +10; reporting/deleting/blocking it = -5, the evidence showed it was real),
- **fake** item of the same type, the **main attack** (the paper's GDD 8 scenario, unchanged classes), and a
  **coworker** item ("Coworker - Sales" etc. forwards a Black Veil message; advising them to go ahead = unsafe).
- The main attack ends with a **warning-sign checklist** (CheckBoxes, real signs + decoys; exact set = +10, else -5
  and retry; no typing). Every chapter uses a **known channel**: Staff Directory + HR ext. 1300 (Ch1, one of two
  equal routes per GDD 8), the official SwiftParcel site (Ch2, required), IT ext. 1100 / Security ext. 1200 (Ch3),
  Mr. Ramos ext. 2045 (Ch4, required).
- Choices stay locked until the item's `required_inspections` are done. Hint ramp: Ch1 names what is missing,
  Ch2-3 "Inspect before you decide.", Ch4 "Responses locked.". Revealed facts are neutral; pages carry the evidence.
- Tracking (Objective 7): HUD "Tasks D/T" list (+ "N more later"), desktop counter, per-task feedback screen, ending
  with per-item lines and "Tasks completed: 23 of 23". HUD tasks per chapter 5/6/6/6.
- Scores: +10 / -5 / +20 per chapter (once). Max computed from data: `Game.max_score()` = **320** (80 per chapter;
  every flawless route scores the same). Every-wrong-first run = **105** (30 / 20 / 30 / 25). `Campaign.MAX_SCORE`
  no longer exists. Unsafe = compromise notice + bad ending with the item's own `bad_ending`/`warning_signs`/`tip`.

**Addendum 2026-11-03 (user request): six chapters.** Ch5 Social Media Impersonation (new desktop app Chat, "Kumusta Chat") and Ch6 QR Code Phishing (drawn QR codes in Mail with Preview QR link) follow Ch4; this overrides "four chapters" and the "QR" item of the never-add list below. Max 500, wrong-first 135, tasks 36; details in `TASKS-SPEC.md` addendum (b).

Tests: `tests/smoke_test.gd` (headless) is the acceptance test. `tests/compile_check.gd` loads every script.
Maintained screenshot helpers (run windowed): `tests/capture.gd` (all 16 items through the real buttons, PNGs in
`tests/shots/tasks/`), `tests/capture_menu_tasks.gd` (instructions panel, coworker game over),
`tests/capture_runtime.gd` and `tests/probe_input.gd` (real E/ESC input). `tests/capture_play.gd` is **obsolete**
(old one-message keys) and must not be run.

- Godot **4.7.2**, statically typed **GDScript 2.0** (Godot 4 syntax only: `@export`, `@onready`, `signal x(a: int)`, `x.connect(f)`, `await sig`, `CharacterBody3D`, `velocity` + `move_and_slide()`, typed arrays).
- Editor binary for checks: `C:/Users/ADMIN/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- Project root: `C:/Users/ADMIN/Desktop/Dev Apps/Vigilant/game` (`res://`).
- **All nodes are built in code** in `_ready()` (or `_init()`); `.tscn` files are only one-node stubs. Do not write `.tscn` files with child nodes.
- Indent with **tabs**. Use `UIStyle` helpers for every UI element so the game looks consistent.
- Greybox only: `MeshInstance3D` with `BoxMesh` / `CylinderMesh` / `CapsuleMesh` / `PlaneMesh` and `StandardMaterial3D` flat colours. Keep all meshes under a node named `Visual` and collision under `Collision`, so low-poly art can replace `Visual` later without code changes.
- Never use: `get_tree().paused`, `OS.shell_open`, `OS.execute`, `HTTPRequest`, `DisplayServer.clipboard_set/get`, `LineEdit`, `TextEdit`, `CodeEdit`, `SpinBox`, `FileDialog`, selectable text (`RichTextLabel.selection_enabled` stays false). No free-text input anywhere.
- Never add: extra chapters, NPC attackers, walking NPCs, USB/ID-card/sticky-note/QR/package items, fake login pages, ads, downloads, attachments, neutral/perfect endings, accounts, saves of progress, online anything.

## Already written (do not change; read them first)

| File | What it gives you |
|---|---|
| `project.godot` | Main scene `res://scenes/main_menu.tscn`; autoloads `Settings`, `Game`, `Router` |
| `autoload/settings.gd` | Input actions `move_forward/back/left/right` (WASD only), `interact` (E), `back` (ESC), `advance` (E only: the paper lists only WASD, mouse, E, ESC). `Settings.mouse_radians_per_pixel()`, `sensitivity` 1-10, `master_volume`, `fullscreen`, setters, `reset_to_defaults()`, signal `changed` |
| `autoload/game.gd` | Score + progress. `start_new_game()`, `begin_chapter(n)`, `apply_outcome(outcome, step, text) -> int`, `complete_chapter()`, `next_chapter() -> bool`, `restart_chapter()`, `all_complete()`, `chapter_total(n)`, `chapter_log(n)`, `score`, `current_chapter`, `is_restart`, constants `CORRECT/WRONG/UNSAFE/COMPLETE`, signal `score_changed(score, delta, reason)` |
| `autoload/router.gd` | `Router.go_to(path)` with fade; `Router.MAIN_MENU`, `OFFICE`, `ENDING`; `Router.quit()` |
| `data/campaign.gd` | `Campaign.INTRO`, `CHAPTERS`, `chapter(n)`, `PAGES` (`courier`, `directory`), `PHONE_CARD`, `GOOD_ENDING`, `item(n, id)`. Key reference at the top of the file |
| `scripts/core/chapter_session.gd` | `ChapterSession`: `chapter`, `step_index`, `step()`, `required()`, `missing()`, `gate_open()`, `mark(key)`, `is_disabled(i)`, `disable_choice(i)`, `advance_to(n)`, `waits_for_telephone()`, `gate_hint()`, `clipboard`, `pasted_url`, `page` |
| `scripts/ui/ui_style.gd` | `UIStyle`: colours, `mono_font()`, `box()`, `panel()`, `label()`, `mono_label()`, `title()`, `button()` (FOCUS_NONE), `backdrop()`, `center()`, `vbox()`, `hbox()`, `outcome_color()` |
| `scripts/ui/overlay.gd` | `Overlay extends Control`: hidden by default, full rect. `show_overlay()`, `hide_overlay()`, `is_open()`, signals `opened(o)` / `closed(o)`, virtual `handle_back()` (ESC) and `handle_advance()` (E) |
| `scenes/office.tscn`, `main_menu.tscn`, `ending.tscn` | One-node stubs pointing at `scripts/office/office.gd`, `scripts/menus/main_menu.gd`, `scripts/menus/ending.gd` |

## Input and mouse rules (owned by `office.gd`)
- Overlays never read `back`/`advance` themselves. `office.gd` handles `_unhandled_input`: `back` → top overlay's `handle_back()`, or opens the pause menu if no overlay is open; `advance` → top overlay's `handle_advance()`; `interact` (no overlay open) → player's focused interactable.
- Overlay buttons are clicked with the mouse. While any overlay is open: `Input.mouse_mode = MOUSE_MODE_VISIBLE`, `player.controls_enabled = false`. When none are open: `MOUSE_MODE_CAPTURED`, controls on.
- Ctrl+V in the Browser is the one exception: `DesktopUI._unhandled_key_input` may handle Ctrl+V itself while it is open.

## Module A: World (Objective 1) — files `scripts/office/office_builder.gd`, `scripts/office/interactable.gd`, `scripts/player/player.gd`

`class_name Interactable extends StaticBody3D` (`interactable.gd`)
- `@export var device_id: String` (`"workstation"` or `"telephone"`), `var prompt: String` (e.g. `"Use workstation"`), `var disabled_prompt: String` (shown without `[E]` when disabled; may be empty), `var enabled: bool = false`.
- Collision layer 3 only (`collision_layer = 4`), mask 0. Has a `CollisionShape3D` child sized to the object.
- `func prompt_text() -> String`: `"[E] " + prompt` if enabled, else `disabled_prompt`.
- signal `interacted(device_id: String)`; `func interact() -> void` emits it only if enabled.

`class_name Player extends CharacterBody3D` (`player.gd`)
- Capsule collision (radius 0.35, height 1.75), camera at eye height 1.6 inside a `Head` Node3D (yaw on body, pitch on head, pitch clamped ±85°), `RayCast3D` from the camera, length 2.2 m, `collision_mask = 4`.
- Walk speed 3.5 m/s, gravity, no jump, no sprint, no crouch. WASD via `Input.get_vector("move_left","move_right","move_forward","move_back")`. Mouse look with `InputEventMouseMotion.screen_relative * Settings.mouse_radians_per_pixel()` only when `controls_enabled` and the mouse is captured.
- `var controls_enabled: bool = true`. When false: no movement input (still applies gravity, velocity x/z → 0), no look, no ray prompt (emit empty prompt once).
- signal `focus_changed(target: Interactable)` and `prompt_changed(text: String)`; recompute each physics frame, emit only when the target or its `prompt_text()` changes.
- `func get_focus() -> Interactable` (null if none). `func teleport(xform: Transform3D) -> void` (sets position and yaw, resets pitch). `func get_camera() -> Camera3D`.
- `func focus_camera_on(target: Vector3, duration: float) -> void` and `func release_camera(duration: float) -> void`: tween the head pitch / body yaw to look at a point (used when sitting at the monitor or answering the phone). Both awaitable (return when the tween ends; use `await tween.finished`).

`class_name OfficeBuilder extends Node3D` (`office_builder.gd`) — builds the greybox office in `_ready()`:
- About 14 m × 10 m × 3 m room: floor, ceiling, 4 walls (StaticBody3D collisions, `collision_layer = 1`), an entrance area, a reception desk with **Ms. Dela Vega** as a static figure (capsule body + sphere head + a simple name label `Label3D` "Ms. Dela Vega — Security"), 4-6 other office desks with chairs and plain monitors as decoration (not interactable), a plant or two, a whiteboard with "Aegis Solutions — Vigilant Protocol" `Label3D`, and **the player's desk** 8-10 m from the entrance with:
  - **workstation**: a monitor + keyboard + PC tower; an `Interactable` (`device_id = "workstation"`, `prompt = "Use workstation"`) covering it. The monitor screen is a dark-blue emissive quad. 
  - **telephone**: a desk phone on the same desk; an `Interactable` (`device_id = "telephone"`, `prompt = "Answer the telephone"`) with a small `OmniLight3D` + emissive bulb mesh as the ring light, and an `AudioStreamPlayer3D` ring made from an `AudioStreamGenerator` **or** omit audio and rely on the blinking light plus a `Label3D` "RING!" that bobs. (A procedural ring tone via `AudioStreamGenerator` is a bonus, not required.)
- Lighting: `WorldEnvironment` (ambient light, soft sky colour background, tonemap filmic), one `DirectionalLight3D` with shadows off or soft, 2-4 `OmniLight3D` ceiling lights. Warm, readable, low-poly-friendly colours.
- Public API: `var workstation: Interactable`, `var telephone: Interactable`, `var intro_spawn: Transform3D` (just inside the entrance, facing reception), `var chapter_spawn: Transform3D` (standing beside the player's desk, facing the monitor), `var monitor_point: Vector3` (centre of the monitor screen), `var phone_point: Vector3`, `func set_phone_ringing(on: bool) -> void` (blinks the light, shows/hides the RING label, plays/stops the ring sound if any), `func set_monitor_alert(on: bool)` (brightens the screen / shows a small "1 new" Label3D above the monitor).
- Every mesh goes under a child `Visual`; every collision body under `Collision` (Interactables may sit under the desk group but their meshes go under `Visual`).

## Module B: Desktop UI (Objectives 3 and 5) — file `scripts/ui/desktop_ui.gd`

`class_name DesktopUI extends Overlay`
- Full-screen simulated desktop (not a real OS): a top bar ("Aegis Workstation", the clock text "09:00" static, the user `you@aegis-solutions.example`), a left app rail with exactly three apps: **Mail**, **Messages**, **Browser** (badge dot on the app that holds the chapter's new message), and the app area. At the bottom, the **DecisionBar**: the step `question`, the choice buttons (one per choice, in order), and a hint line.
- `func open_session(session: ChapterSession) -> void`: stores the session, selects the chapter's app (`mail` or `messages`; if `session.page != ""` select Browser), renders, then `show_overlay()`.
- `func refresh() -> void`: re-renders the DecisionBar from the session: if `session.waits_for_telephone()` show `step.wait_objective` and no choices; else show the question and buttons; buttons for `session.is_disabled(i)` are disabled; if `not session.gate_open()` all buttons disabled and the hint shows `session.gate_hint()`, else the hint reads "Choose a response."
- `func set_choices_locked(locked: bool) -> void`: disables all choice buttons while an outcome is showing.
- `func show_page(page_id: String) -> void`: sets `session.page` and switches to the Browser showing that bookmark page.
- signals: `inspected(key: String)`, `choice_selected(index: int)`, `close_requested`.
- `handle_back()` emits `close_requested` (the office closes the desktop and stands the player up).
- **Mail app** (used by Ch1 and Ch4): an inbox list with exactly one message (the chapter's `message`), opened by default. The reading pane shows From as the display name only, as a clickable link-style button "Aegis HR Benefits ▾". Clicking it reveals the full `from_addr` and (if non-empty) `Reply-To:` in monospace, and emits `inspected("sender")`. Subject, To, then the body in a `RichTextLabel` with `bbcode_enabled = true`, `meta_underlined = true`. Links are `[url=<link id>]text[/url]` in the body; the real URL is in `message.links`.
- **Messages app** (Ch2): a phone-style conversation list with one thread (`sender_label`), the bubble with the body (same link handling). Clicking the sender header reveals `sender_number` + `sender_info` in monospace and emits `inspected("sender_number")`.
- **Link click** (`meta_clicked`): open a small `PopupMenu` at the mouse with one item **"Copy link address"**. Choosing it sets `session.clipboard` to the real URL and shows a toast "Link address copied". A link click never opens a page and never ends the game.
- **Browser app**: an address bar that is a read-only `Label` styled like a field (monospace), a **Paste** button, and bookmark buttons **"SwiftParcel (official)"** and **"Aegis Staff Directory"**. Paste (button or Ctrl+V while the desktop is open) copies `session.clipboard` into `session.pasted_url` and shows it in the address bar with the host part highlighted (bold or coloured) — do **not** colour it red or call it fake; show the facts only — and below it a plain line "This is the full link address. The website was not opened." If the pasted URL equals one of the message links, emit `inspected("link:<link id>")`. If the clipboard is empty, show "Nothing to paste. Copy a link first." Bookmark pages render from `Campaign.PAGES` (directory as a simple table; courier as lines) with their `url` in the address bar. A malicious link's page is never rendered.
- No windows to drag, no start menu, no other apps.

## Module C: Office overlays (Objectives 5, 6, 7) — files in `scripts/ui/`

All extend `Overlay` unless noted. Each builds its nodes in `_ready()`.

- `hud.gd` — `class_name HUD extends Control` (always visible, `mouse_filter = IGNORE`, not an Overlay): top-left **Score: N** (pulses green/orange/red on change, listening to `Game.score_changed`) and **Chapter N of 4 — Title**; top-right chapter progress pips (4 circles: done/current/upcoming from `Game.completed` and `Game.current_chapter`); top-centre objective line; centre crosshair dot; below centre the interaction prompt. API: `set_objective(text)`, `set_prompt(text)`, `refresh()` (chapter + pips + score), `set_crosshair_visible(bool)`.
- `dialogue_panel.gd` — `class_name DialoguePanel`: bottom panel with speaker name, text, portrait square (coloured box with initials "DV"), and "E / click to continue". `func play(lines: Array) -> void` (each line `{speaker, text}`), shows overlay, shows lines one at a time; `handle_advance()`, `handle_back()` and a click advance one line; after the last line hides and emits `finished`. Awaitable via `await panel.finished`. Optional typewriter effect that completes instantly on first advance.
- `call_ui.gd` — `class_name CallUI` (Objectives 3/5 for the telephone): a phone-call panel over a dimmed 3D view: header (`call.caller_id` for Ch3 step 0 as a clickable button "Caller ID: OUTSIDE LINE 09XX-XXX-0381 ⓘ" → reveals `caller_id_info` and emits `inspected("caller_id")`; or `step.call_header` text for other steps), caller name, a transcript of lines, the **phone card** (`Campaign.PHONE_CARD`), and a decision area (question, choice buttons, hint) using the same gate/disabled rules as the DecisionBar. API: `func open_session(session: ChapterSession) -> void` (show overlay, play the step's lines — `chapter.call.lines` for Ch3 step 0, `step.call_lines` otherwise — appended to the transcript with a short delay each, then reveal the decision area), `refresh()`, `set_choices_locked(locked)`, `add_line(speaker: String, text: String)`, `close()` (= hide_overlay). signals `inspected(key)`, `choice_selected(index)`. `handle_back()` shows the hint "Choose a response." and does nothing else (ESC never counts as hanging up).
- `outcome_panel.gd` — `class_name OutcomePanel`: centred card. `func show_outcome(outcome: String, delta: int, feedback: String, response_line: String = "") -> void`: title "Correct" / "Wrong action" / "Unsafe choice" in `UIStyle.outcome_color`, the delta "+10" / "-5", the response line in italics if any, the feedback, a **Continue** button. Continue, `handle_back()` or `handle_advance()` hide it and emit `continued`.
- `compromise_notice.gd` — `class_name CompromiseNotice`: full-screen red security alert (a large warning icon, title "SECURITY ALERT — ACCOUNT COMPROMISED") with the chapter's compromise text; `func show_notice(text: String) -> void` shows it, waits 2.5 s, hides, emits `finished`. `handle_back()` does nothing.
- `game_over_screen.gd` — `class_name GameOverScreen` (the bad ending): title "GAME OVER: Aegis Solutions has been breached", a "BLACK VEIL" mark, the chapter's `bad_ending` text, "Warning signs you missed" list, the tip, "Score: N". Buttons **Restart Chapter** and **Main Menu**, each disables both after the first press. `func show_game_over(chapter: Dictionary, score: int) -> void`. signals `restart_pressed`, `menu_pressed`. `handle_back()` does nothing.
- `feedback_screen.gd` — `class_name FeedbackScreen`: after a completed chapter: "Chapter N complete: Title", Dela Vega's `debrief`, "Warning signs" list, "Tip", and this chapter's score breakdown from `Game.chapter_log(n)` (each line "choice text  +10/-5", plus "Chapter complete +20") and "Chapter score: X". Continue button. `func show_feedback(chapter: Dictionary) -> void`; signal `continued`; Continue, `handle_back()`, `handle_advance()` continue.
- `pause_menu.gd` — `class_name PauseMenu`: Resume, Instructions, Settings, Main Menu (with a confirm "Leave the training? Your progress will be lost." Yes/No). Uses `InstructionsPanel` and `SettingsPanel` from Module D as sub-panels inside it. `handle_back()`: if a sub-panel or the confirm is open, go back to the menu; otherwise resume. signals `resume_pressed`, `menu_pressed`. `func open() -> void` (= show_overlay with the main page).

## Module D: Menus (Objective 2, plus the endings for Objective 7) — files `scripts/menus/main_menu.gd`, `scripts/menus/ending.gd`, `scripts/ui/settings_panel.gd`, `scripts/ui/instructions_panel.gd`

- `instructions_panel.gd` — `class_name InstructionsPanel extends PanelContainer`: controls (WASD move, Mouse look, E interact, ESC exit screens / pause) and how to play: walk to your workstation or phone, inspect who sent it and where links really go (click the sender; click a link → Copy link address → Browser → Paste), choose a response; scoring +10 correct, −5 wrong, +20 chapter complete; an unsafe choice is a breach and game over, and you can restart the chapter; finish all four chapters safely to pass. A **Back** button emits `back_pressed`.
- `settings_panel.gd` — `class_name SettingsPanel extends PanelContainer`: Mouse sensitivity (`HSlider` 1-10, step 1, shows value), Master volume (`HSlider` 0-100 %), Fullscreen (`CheckButton`), **Reset to defaults**, **Back** (emits `back_pressed`). Writes through `Settings` setters immediately. Sliders/check buttons `focus_mode = FOCUS_NONE`.
- `main_menu.gd` (`extends Control`, root of `main_menu.tscn`): background (dark gradient or a slow-rotating greybox office desk in a `SubViewportContainer` — the flat background is fine), title **"VIGILANT"**, subtitle "A 3D Desktop Simulation Game for Raising Awareness of Social Engineering Attacks in Cybersecurity", buttons **Start**, **Instructions**, **Settings**, **Exit**. Start: `Game.start_new_game()` then `Router.go_to(Router.OFFICE)`. Instructions/Settings: show the panel in place of the buttons; Back or ESC returns. Exit: `Router.quit()`. Mouse visible. Small footer "STI College – General Santos · BSIT Capstone".
- `ending.gd` (`extends Control`, root of `ending.tscn`, the good ending): "You passed the Vigilant Protocol", `Campaign.GOOD_ENDING` lines (Dela Vega), final score "N / Game.max_score()", "Chapters completed: 4 of 4", per-chapter breakdown table (`Game.chapter_total(n)` for n = 1..4 with titles), buttons **Main Menu** and **Exit**. Mouse visible. If reached without `Game.all_complete()` (e.g. run directly), show it anyway with the current data.

## Module E: Office director (Objectives 4, 6, 7 glue) — file `scripts/office/office.gd`

`extends Node3D` (root of `office.tscn`). In `_ready()`: add `OfficeBuilder`, `Player`, a `CanvasLayer` (layer 10) holding `HUD` then the overlays (`DialoguePanel`, `DesktopUI`, `CallUI`, `OutcomePanel`, `CompromiseNotice`, `GameOverScreen`, `FeedbackScreen`, `PauseMenu`). Connect every overlay's `opened`/`closed` to maintain `_stack: Array[Overlay]` and apply the mouse/controls rule. Connect the player's `prompt_changed` → `hud.set_prompt`.

Flow (design doc sections 5 and 7):
1. Spawn: if `Game.is_restart` → `chapter_spawn`, skip the intro, set `Game.is_restart = false`; else `intro_spawn` and play `Campaign.INTRO`.
2. `_start_chapter(n)`: `Game.begin_chapter(n)`, new `ChapterSession`, HUD refresh, play the briefing, set the HUD objective, enable only the chapter's device (`device`), set the other device's `disabled_prompt` to the objective. Ch3: `set_phone_ringing(true)`. Workstation chapters: `set_monitor_alert(true)`.
3. Interact workstation → camera focuses the monitor (`player.focus_camera_on(monitor_point, 0.4)`) → `desktop.open_session(session)`. Desktop `close_requested` → hide desktop, `player.release_camera(0.3)`. Re-opening keeps the session (inspections, disabled options, page).
4. Interact telephone → Ch3: stop ringing, focus the phone, `call_ui.open_session(session)`. Ch4 step 1 (`waits_for_telephone()`): close the desktop first if open, then open the Call UI.
5. On `inspected(key)` from desktop or call: `session.mark(key)` then refresh that UI.
6. On `choice_selected(i)`: lock choices; `delta = Game.apply_outcome(outcome, session.step_index, text)`; show the outcome panel; await `continued`; then:
   - **correct** with `next_step` → `session.advance_to(next)`; if the choice has `opens` → `desktop.show_page(opens)`; if the new step waits for the telephone → refresh the desktop (it shows the wait objective), HUD objective = `wait_objective`, workstation disabled with `disabled_prompt = wait_objective`, telephone enabled with `prompt = trigger_prompt`; else refresh the active UI (for a call step, `call_ui.open_session(session)` again plays the next step's lines).
   - **correct** without `next_step` → `Game.complete_chapter()`, close desktop/call, release camera, disable both devices, show `FeedbackScreen`; await `continued`; if `Game.next_chapter()` → `_start_chapter(Game.current_chapter)`; else `Router.go_to(Router.ENDING)`.
   - **wrong** → `session.disable_choice(i)`; if the choice has `response_line` and the call UI is open, `call_ui.add_line(...)`; unlock and refresh.
   - **unsafe** → close desktop/call, `compromise.show_notice(choice.compromise)`; await; `game_over.show_game_over(chapter, Game.score)`. Restart → `Game.restart_chapter()`; `Router.go_to(Router.OFFICE)`. Main Menu → `Router.go_to(Router.MAIN_MENU)`.
7. ESC with no overlay open → `pause.open()`; Resume → hide; Main Menu → `Router.go_to(Router.MAIN_MENU)`.
8. **Test hooks** (used by the headless smoke test; keep them public): `var session: ChapterSession`, `func debug_state() -> String` (e.g. `"BRIEFING"`, `"ACTIVE"`, `"OUTCOME"`, `"FEEDBACK"`, `"GAME_OVER"`), `func debug_interact(device_id: String)`, `func debug_inspect(key: String)`, `func debug_choose(index: int)`, `func debug_advance()` (advances the top overlay like `advance`). Keep a `var state: String` updated at every transition.

## Objective checklist (the final review uses this; every item must be true)
1. 3D office, first-person WASD + mouse look, interact with the workstation and the telephone with E.
2. Main menu with Start, Instructions, Settings, Exit; Instructions and Settings also reachable from the pause menu.
3. Simulated desktop with Mail, Messages and Browser (web pages: pasted-link view, SwiftParcel official, Staff Directory).
4. Four scripted chapters in order: email phishing, smishing, vishing (telephone), BEC.
5. Inspect before deciding: sender reveal, copy link + paste in Browser to read the real address, caller ID; choices locked until the required inspections are done.
6. Programmed rules: +10 / −5 / +20, outcome notification after every choice, compromise notice + game over (bad ending) after an unsafe choice, restart chapter.
7. Score and chapter completion tracked and shown (HUD score, chapter N of 4, pips, feedback breakdown, ending summary).

## Game feel (added 2026-11-04; presentation only: no gameplay, scoring, content or input changes)
- **No audio files.** `autoload/audio.gd` (autoload `Audio`, registered after `Settings`) plays sounds that
  `scripts/core/audio_synth.gd` (`AudioSynth`) synthesizes as 16-bit PCM `AudioStreamWAV`s, rendered once per run
  on the WorkerThreadPool and cached. Headless (smoke test) = silent no-op: nothing is rendered or played.
- Buses created in code: Master → **Music**, **SFX**. API: `play_sfx(name, volume_db, pitch)`, `play_3d(...)`,
  `get_stream(name)`, `set_music("day"|"night")` (2.5 s crossfade), `stop_music()`, `start_ambient()` /
  `stop_ambient()`, `track_for_chapter(n)` ("day" Ch1-4, menus, ending; "night" Ch5-6), `synth(name)`.
- Sounds: footstep, ui_click (every BaseButton via `node_added`), notify_ping, phone_ring (3D, same cadence as the
  ring light), phone_pickup, phone_hangup, evidence_found (only when `ChapterSession.mark()` records a new key),
  copy, paste, correct, wrong, unsafe_alarm, chapter_complete, badge, typing (3D loop at the typing coworker),
  page_turn (dialogue advance), ambient (room tone + aircon hum). Previews: `tests/render_audio_preview.gd` →
  `tests/audio_preview/*.wav` (a `.gdignore` keeps Godot from importing them).
- Settings: `music_volume` (default 0.5) and `sfx_volume` (default 0.8) next to `master_volume`, saved in
  `user://settings.cfg`, covered by `reset_to_defaults()`; sliders `MusicSlider` / `SfxSlider` in `SettingsPanel`.
- Visuals: HUD floating "+10 / -5 / +20" (layer above the overlays) and score pulse; compromise notice = one red
  flash + 0.45 s shake + glitch bars (nothing flashes faster than 3 Hz); `TitleCard` ("Chapter N · Title · time",
  2.5 s, non-blocking over the briefing; `office.title_card`); soft rim glow (`Interactable.set_highlight`,
  `highlight_nodes`) on the enabled device under the crosshair; head-bob + footsteps every 0.7 m (camera local
  position only, so the focus / release tweens are untouched).
- Screenshots: `tests/capture_feel.gd` (windowed) → `tests/shots/feel/`.

## Tutorial
`scripts/ui/tutorial_hint.gd` (`TutorialHint`, not an Overlay) guides a new game's first task in Chapter 1. `office.gd` starts it after the first briefing, and never after Restart Chapter. It only watches state (session, desktop, player), never changes the flow or the score, and only its Skip button takes the mouse. Check with `tests/capture_tutorial.gd` (not headless).

## Sound juice
`Audio.play_correct()` / `play_wrong()` track a sound-only streak (never read by scoring). `play_evidence(index)` rises per inspection, and `gate_unlock` plays when the choices unlock. `cut_music()` is used on a breach; `duck_music()` is used under big moments. Tracks: day (Ch1-2), drive (Ch3-4), night (Ch5-6). **Rule: no sound may hint at an answer before the player chooses.** `tests/audio_levels.gd` measures every sound. Headless runs skip audio, so run the smoke test once without --headless after changing audio code.


## Windows build
`export_presets.cfg` builds `../build/Vigilant.exe` (one file, game data embedded, tests excluded): `<godot console> --headless --path game --export-release "Windows Desktop" ../build/Vigilant.exe`. To test the exported data: `<godot console> --headless --main-pack build/Vigilant.exe --script <absolute copy of smoke_test.gd>`. The release exe itself ignores --script. Re-export after any game change.

## Chapter Select and Progress
`scripts/menus/chapter_select.gd` (`ChapterSelect`, in the main menu): carousel of chapter cards; `chapter_chosen(n, item_id)` → `Game.select_chapter(n, item_id)` → office. `Game.jump_item` makes `office._start_chapter()` call `ChapterSession.skip_to(id)` (earlier items resolved as skipped, no points). Feedback screen `chose_select` and pause `select_pressed` go to `office._to_chapter_select()` (`Game.open_select`). The pause menu's Progress page reads the live session. Run progress is memory-only.

## Desk phone dialing
`scripts/ui/dial_pad.gd` (`DialPad`, overlay) opens when the phone is used for a placed call (`session.waits_for_telephone()`). The expected extension is parsed from the step's `call_header` ("EXT 2045: ..."); a wrong number does not answer and costs nothing. `OfficeBuilder.set_phone_display()` drives the phone LCD and the caller tag under "RING!". Test hook: `office.debug_dial(number)`. DTMF tones, `ringback` and `no_answer` are synthesized in `AudioSynth`.

## Office life
`PersonWalker` (`scripts/office/person_walker.gd`, child of a person model) walks the printer and mug coworkers on fixed routes (`OfficeBuilder._build_walkers`; stops with `at` / `face` / `wait` / `via`). Procedural walk on the rigid parts (thighs, shins, upper arms, body dip), 3D footsteps, an `AnimatableBody3D` capsule on layer 1, waits for the player (`set_walker_obstacles`) and says "Excuse me"; walkers yield to each other. `PersonIdle` adds the typist's stretch break and the phone coworker's chair swivel (`swivel`). `Pantry` (`scripts/office/pantry.gd`) adds the coffee maker (`coffee`: brew, then pour) and water dispenser (`water`) interactables; `builder.notice_board` (`board`) opens `NoticeBoard`. All feel only: no score, no session change. Test hook: `office.debug_pantry(id)`. Screenshots: `tests/life_shot.gd` (not headless).

## Ten chapters, places and the phone (2026-11-21)
- **Order (`data/campaign.gd`, positional):** 1 Email Phishing, 2 Smishing, 3 E-wallet Texts (home), 4 Vishing, 5 The Bank Agent (home), 6 BEC, 7 Social Media, 8 The Easy Sideline (cafe), 9 QR Phishing, 10 Who Are You? (cafe). Item ids are kept (c1_..c6_ office, c7_..c10_ new), so ids no longer match chapter numbers: always pair them with the chapter via `Campaign.item(n, id)`. Each chapter carries `place`, `music`, `hint_level` and its own per-chapter display keys. Items follow genuine → main → fake → help (+ an optional genuine cool-down).
- **Places:** `scripts/world/location_builder.gd` (`LocationBuilder.create(place)`) with `office_builder.gd`, `home_builder.gd` and `cafe_builder.gd`. `office.gd` swaps the builder in-scene when the next chapter's place differs. Moods are keyed per place.
- **Phone:** `scripts/ui/phone_ui.gd` (`PhoneUI` extends `DesktopUI` through behaviour-neutral seams; `office.screen()` returns the active one). It has KwartaPay (balance = base + unlocked transactions, History, Inbox, Report a scam) and hotline dialing via a step's `dial` key (8700 card hotline, 1326 anti-scam hotline).
- **Achievements:** `Game` keeps a session events log (`secret_shared`, `misdial`, `trap_failed`) for OTP Bantay, Hotline Hero and Not Your Mule.
- **Fun Facts:** `data/fun_facts.gd` (short source names only; the URLs are in `docs/PH-CHAPTERS-SCRIPT.md`), shown on the title card, the feedback screen and the main menu's Fun Facts page.
- **Previews for the editor:** `tests/make_previews.gd` writes `tests/previews/{office,home,cafe}_preview.scn` (static, no scripts) so the places can be seen in the 3D view. Re-run after art changes.
- **Art:** `tests/capture_art.gd` (all 10 moods and close-ups); `tests/capture_play.gd` (real input, phone included).
