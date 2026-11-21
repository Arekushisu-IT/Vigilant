# Vigilant: Godot 4 Prototype Design Document (Final, rev. 2)

**Project:** Vigilant, a 3D desktop simulation game for social engineering awareness (BSIT capstone, STI College General Santos).
**Engine:** Godot 4, latest 4.x stable at kickoff (4.5 or newer). The exact patch version is pinned (see section 3).
**Target:** Windows desktop (the paper lists an AMD Ryzen 5 5600). Offline, single player.
**Art:** greybox primitives first, then low-poly 3D from Blender (glTF). Art is kept separate from logic.
**Basis:** the paper's Objectives, Scope, Limitations, Functional Requirements (FR1-10), UI list, GDD sections 1-14 and the Storyboard. The design starts from the Risk-First proposal (P3). It adds P2's vertical-slice milestones and roles, and P1's locked scoring, schema-level scope guard, outcome rule and safe link-click behaviour.

Items marked **PROPOSED — team to confirm** fill gaps the paper leaves open. Each one has a recommended answer, and the builder builds that answer until the team decides otherwise (section 16 says who decides and by when). Everything else follows the paper directly. This document does not plan edits to the paper. A colleague is revising the paper, and confirmed answers are passed to them so the paper and the build match.

---

## 1. Intent and why

**What we are building.** A short (20-30 minute), guided first-person game. The player is a new hire at the fictional company **Aegis Solutions** on their first day of the **Vigilant Protocol** training. **Ms. Dela Vega**, the security officer, introduces each situation and explains the warning signs. Four scripted attacks by the cybercriminal group **Black Veil** arrive in a fixed order:
1. a phishing email
2. a smishing text
3. a vishing phone call
4. a business email compromise (BEC) email impersonating the manager, **Mr. Ramos**

For each attack the player inspects the situation (checks the sender, copies a link and pastes it to read its real address, checks the caller ID), picks one of a fixed set of responses, sees the score change, and reads feedback on the warning signs. Ms. Dela Vega's debrief names Black Veil as the source of every attack, so a player who never fails still meets the antagonist. An unsafe choice ends in a breach and a game over, and the player can restart the chapter. Clearing all four chapters safely gives the good ending.

**Why it is shaped this way.**
- The panel will judge the build against Objectives 1-7 and the Scope modules. The hard rule is **nothing more, nothing less**. Every feature traces to an objective, scope module, FR or NFR (section 4), and every limitation has a design guarantee.
- The learning value comes from *inspect, then decide, then consequence, then feedback* (Kolb's experiential loop, cited in the paper). So inspection is mandatory and mechanical: the choice buttons stay locked until the player has inspected. Feedback follows every decision and every chapter.
- A team of three students must be able to build it. The architecture is small: six autoloads, one chapter director and typed data resources. Chapter 1 is playable end to end early, in greybox. Chapters 2-4 are mostly data plus one new UI surface each. Art goes into slots the logic never touches.

---

## 2. Goals, non-goals, anti-goals

### Goals
1. Satisfy Objectives 1-7 exactly, each with a test or QA check. Objective 8, the Google Forms evaluation, happens outside the game.
2. Use the paper's numbers literally: +10 correct, -5 wrong, +20 per completed chapter, and the score carries across chapters.
3. Make inspection real and required: a sender details reveal, Copy link address, a paste into the browser address field to read the full URL, and a caller-ID check.
4. Use exactly four fixed chapters in a fixed order, with two endings: good after all four are safe, bad on a breach.
5. Make the game deterministic and testable headless. Content lives in typed `.tres` files, and a validator plus a playthrough test enumerate every choice.
6. Make the swap from greybox to low-poly need zero script changes.
7. Run fully offline from an exported Windows `.exe` at 60 fps on the evaluation PC.

### Non-goals (not built, because of the paper's limitations)
- Multiplayer, networking, accounts, cloud storage, saved progress, a Continue button, chapter select.
- Real threat detection, real tools, real URLs, real brands, real phone numbers.
- Adaptive, random or AI-generated attacks. A fifth chapter or a different order.
- USB baiting, in-person impersonation, NPC attackers, walking NPCs.
- Network security, pentest, malware or exploitation topics.
- A real OS: no file explorer, start menu, terminal, window dragging, extra apps or free web browsing.
- Key rebinding, graphics presets, language options, voice acting, achievements, leaderboards.

### Anti-goals (these would fail the panel even if they work)
- **Anything from the GDD's "Suggested 3D Gameplay Additions":** ID cards and USBs, NPC attacker dialogue, sticky notes, QR codes, security check tasks, phone calls while walking, packages.
- **Neutral or Perfect endings**, a reputation system, or the old Game Lore's "repeated unsafe actions" loss rule.
- **Any attacker web page or old-lore lure.** That means no fake login pages, credential forms, malicious ads, software-update lures, downloads or attachments, whether rendered or described in choice or feedback text. A malicious link never opens a page.
- **Free-text input anywhere.** No typed URLs or replies, and no `LineEdit`, `TextEdit`, `CodeEdit`, `SpinBox` or `FileDialog` in any scene.
- **Interactions the paper does not designate.** Only the workstation and the telephone are interactable. Ms. Dela Vega is not.
- **Non-chapter content on the desktop.** The inbox and messages hold only the current chapter's attack message.
- **Making the decision for the player.** The game never colours a bad domain red or labels it "fake" before the choice. Inspection shows the facts in plain form, and the player judges them.
- **Anything that touches the real system or network.** No `OS.shell_open`, no `OS.execute`, no `HTTPRequest`, no writes to the OS clipboard (directly or through selectable text controls), no telemetry.
- **An in-game evaluation form, or a link or QR code to the Google Form.**
- **Binding F to interact.** The GDD's "F" is a typo. Interact is **E**.
- **Shipping debug helpers, tests or editor tools in the evaluation build.**
- **Any feature that cannot be traced to a row in section 4.**

---

## 3. Constraints

### 3.1 Paper constraints (binding)
- **Objectives 1-7** must be met by the build. **Objective 8** is a Google Forms survey after play, not an in-game feature.
- **Scope modules 1-8** (section 4.2) and **Limitations 1-10** (section 4.4).
- **Controls (FR1, FR2, Purpose):** WASD move, mouse look, **E** interact, **ESC** exit interface screens.
- **Scoring (FR7):** +10 correct action, -5 wrong action, +20 completed scenario. The score carries across chapters (GDD 9).
- **Endings (Scope 5, GDD 10):** good and bad only.
- **Story (GDD 5, 6, 8):** Aegis Solutions, the Vigilant Protocol, Ms. Dela Vega, Mr. Ramos, and Black Veil as the group behind all four attacks. Chapter content follows GDD 8.
- **NFRs:** user-friendly, runs on a Windows desktop, acceptable performance, offline, clear interface.

### 3.2 Engine and platform
- **Godot 4.x stable**, 4.5 or newer. Typed `Dictionary` needs 4.4+, while `screen_relative` mouse motion and the `--import` command-line flag need 4.3+. The exact version (for example `4.5.1-stable`) goes in a `GODOT_VERSION` file and the README. All three machines and the export templates use that version. Only patch upgrades are allowed, and only by team agreement.
- **Language: statically typed GDScript. PROPOSED — team to confirm before week 1** (the paper says C#; see section 16 #1 and the open questions).
  - Reasons: no .NET SDK or .NET editor build on lab PCs, the best editor integration for custom Resources, the fastest iteration, GUT tests that run headless, and most Godot 4 documentation is written in GDScript.
  - What the choice fixes: the editor build (standard or .NET), whether lab PCs need the .NET SDK, the test framework (GUT or gdUnit4Net), the export templates, and every code sample in section 8. If the team picks C#, use the Godot .NET build and gdUnit4Net throughout and never mix the two languages. Switching languages after M0 means rewriting everything.
  - Godot experience: before M0 each teammate states their Godot experience. Anyone new to Godot does the official "Your first 3D game" tutorial in week 1. This is one reason M0 is two weeks long.
- **Renderer:** Forward+ by default. In M0, run a Windows export on the evaluation reference PC (3.3). If Vulkan or D3D12 has trouble, or the frame rate is under 60 fps, switch to **Compatibility**. The Ryzen 5 5600 has no integrated GPU, so the GPU is unknown until it is tested. Low-poly art with simple lighting works in both renderers.
- **Window:** base resolution 1920x1080, with `display/window/stretch/mode = canvas_items` and `aspect = expand`. The UI uses containers and anchors so it reads on 1366x768 monitors.
- **Subwindows:** keep `display/window/subwindows/embed_subwindows = true` (the default), so `PopupMenu` stays inside the game window in fullscreen.
- **Offline:** the export embeds the PCK (`binary_format/embed_pck = true`). No networking class is used anywhere, and a scope test enforces this.
- **Persistence:** only `user://settings.cfg` (preferences). Progress lives in memory for one session.

### 3.3 Evaluation hardware. PROPOSED — team to confirm in week 1
- The team names the evaluation lab and one **reference PC** in it, and records its GPU, driver, monitor resolution and Windows build.
- In week 1 the team asks lab IT for permission to run a **portable, unsigned** Godot `.exe`: a folder copied from a USB drive, with no installer and no admin rights. Copying from USB normally avoids the SmartScreen "downloaded file" prompt. If antivirus or the locked Windows image still blocks it, IT whitelists the folder.
- If running an `.exe` is blocked and cannot be whitelisted, the evaluation runs on team laptops instead, and the team decides that in week 1, not at M7.
- Release packaging: a zip of one folder holding `Vigilant.exe` (PCK embedded) and a README. Nothing is installed.

### 3.4 Art
- Greybox (CSG and primitive meshes) until the content-complete alpha, then low-poly glTF from Blender.
- Logic scenes own collision, interaction bodies, markers, lights used by logic, and audio. Art lives only under a `Visual` child, and no script ever references a node inside `Visual`.

### 3.5 Existing pre-production material. PROPOSED — team to confirm by the end of M0
- **Chapter scripts, dialogue and decision map** (the paper says these were written in pre-production). Section 6 is **authoritative for structure**: steps, choices, outcome classes, required inspections and scoring. The existing scripts supply the **wording**. Where they conflict (a different choice set, a different correct answer, an extra step), the content writer raises it with the team before Ch1's `.tres` is written in M2. A structural change updates section 6 and the tests together. For example, a second Ch1 step would raise the maximum score from 150 to 160.
- **Art from the Unity phase** (office layout, Blender models, textures, UI mock-ups, portraits). The team lists what exists by the end of M0.
  - `.blend` sources are re-exported as `.glb` under the rules in 12.3. Unity scenes, prefabs and scripts are not ported.
  - If reusable models exist, the M1 dimension lock (12.2) is set to match them, not the other way round. Models that use a different scale, origins or many materials get conversion time in the art track.
  - If nothing exists, the art track starts from zero in M2 as planned.

### 3.6 Team
- Three students and about 15 production weeks (dates in 14.1). Suggested roles:
  - **Systems:** autoloads, director, rules, tests, flow.
  - **Interface:** menus, HUD, desktop apps, call UI, theme.
  - **Content & Art:** chapter `.tres` and dialogue, greybox level, Blender.
- One owner per `.tscn` per sprint.

---

## 4. Objective and scope traceability

### 4.1 Objectives 1-7

| Obj | Paper requirement | Feature | Scene / script | How to verify |
|---|---|---|---|---|
| 1 | 3D virtual office; first-person movement; interact with workstation and telephone | Greybox office (later low-poly); FP controller; interaction ray; two interactables with enabled/disabled prompts | `scenes/office/Office.tscn`, `scenes/player/player.gd`, `scenes/props/interactable.gd`, `props/workstation/Workstation.tscn`, `props/telephone/Telephone.tscn` + `telephone.gd` | QA: walk from the entrance to the desk; "[E] Use workstation" shows only when facing it within 2 m, never through walls; E on the ringing phone answers it. `test_interaction.gd`: E emits `Events.interacted(&"workstation")`; the prompt refreshes when `enabled` changes while the player looks at the object |
| 2 | Navigation interface: main menu with instructions and settings | Main Menu (Start / Instructions / Settings / Exit); Instructions panel; Settings panel; fade transitions | `scenes/main_menu/MainMenu.tscn`, `ui/common/InstructionsPanel.tscn`, `ui/common/SettingsPanel.tscn`, `autoload/scene_router.gd` | QA: every button reaches its screen; Back and ESC return one level. `test_settings.gd` (save/load round-trip) |
| 3 | Simulated desktop with email, messaging, web pages | Full-screen desktop with exactly 3 apps: Mail, Messages, Browser (paste-only address field + 2 static pages) | `ui/desktop/DesktopUI.tscn`, `apps/mail/MailApp.tscn`, `apps/messages/MessagesApp.tscn`, `apps/browser/BrowserApp.tscn` | Scope test: exactly these 3 apps; no text-input controls anywhere. QA: each app renders its chapter content |
| 4 | Four scripted chapters: phishing, smishing, vishing, BEC | `Campaign.chapters` = 4 `ChapterData` in fixed order | `data/campaign.tres`, `data/chapters/ch1..ch4.tres`, `scenes/office/chapter_director.gd` | `test_chapter_data.gd`: count == 4; attacks `[EMAIL_PHISHING, SMISHING, VISHING, BEC]`; triggers `[WS, WS, TEL, WS]` |
| 5 | Inspect (sender, real link address by copy/paste) before choosing predefined actions | Sender details reveal; link menu "Copy link address"; in-game clipboard; paste into the browser address field; caller-ID check; choices locked until the required inspections are done | `ui/desktop/link_body.gd`, `ui/desktop/desktop_ui.gd`, `ui/desktop/address_field.gd`, `autoload/game_clipboard.gd`, `core/chapter_session.gd` | `test_chapter_session.gd` (locked until every required inspection is recorded); `test_clipboard.gd` (copy then paste records `link_revealed:<id>`, including across chapters) |
| 6 | Programmed rules: score updates, outcome notifications, game over after unsafe choices | `ScoreRules` (locked constants); Outcome panel and HUD score pulse; Compromise notice, then Game Over / Bad Ending with Restart Chapter | `core/score_rules.gd`, `autoload/progress.gd`, `ui/common/OutcomePanel.tscn`, `ui/screens/CompromiseNotice.tscn`, `ui/screens/GameOverScreen.tscn` | `test_score_rules.gd` (pins 10 / -5 / -5 / 20); truth-table and playthrough tests (section 13) |
| 7 | Track performance through score and chapter completion | `Progress.score`, `Progress.completed[4]`, `Progress.score_log`; HUD "Score / Chapter n of 4" with 4 pips; per-chapter breakdown on Feedback and Ending screens | `autoload/progress.gd`, `ui/hud/HUD.tscn`, `ui/screens/FeedbackScreen.tscn`, `scenes/ending/Ending.tscn` | Golden-path test: final score 150, `completed == [true,true,true,true]`; QA: HUD updates after every delta |
| 8 | Google Forms evaluation | **Not in the game.** Facilitators run it after play | n/a | Scope test: no URL, form or QR code to it in the project |

### 4.2 Scope modules

| Scope module | Implementation | Verify |
|---|---|---|
| 1. 3D Virtual Environment (layout, FP movement and look, workstation and telephone interaction, on-screen dialogue and notifications, staging of scenario events) | `Office.tscn`, `Player.tscn`, `Interactable`, `DialoguePanel`, `OutcomePanel`, HUD objective line; `ChapterDirector` stages events (phone ring, new-mail badge, enabling the right device) | As Obj 1 |
| 2. System Navigation (main menu, scene transitions, access to instructions and settings) | `MainMenu`, `SceneRouter` (fade + threaded load), shared Instructions and Settings panels. The Pause menu (PROPOSED) also traces here: it gives in-game "access to instructions and settings" and, under NFR1, a way to quit mid-session | As Obj 2; QA for Pause |
| 3. Simulated Desktop Interface (only the screens needed; not a real OS) | Mail (Ch1, Ch4), Messages (Ch2), Browser (inspection view + courier page for Ch2 + staff directory for Ch4). One app visible at a time, maximised; no windows, files or start menu | Scope test; validator: every page is used by a chapter |
| 4. Interactive Scenario (4 fixed scripted chapters, triggered by story progression and interaction) | After each debrief, Ms. Dela Vega's briefing for the next chapter plays, the HUD objective changes, and only that chapter's device is enabled. The scenario content appears when the player presses E on it | Test: chapter n+1 cannot start before n is complete |
| 5. Decision-Based Gameplay (inspect, then predefined actions; good ending after 4 safe chapters; bad ending on breach) | Inspection gate + `ChoiceList`; `Ending.tscn` (good); `GameOverScreen` doubles as the bad ending (7.3) | Playthrough tests for both endings |
| 6. Consequence Simulation (safe allows progress; unsafe shows compromise notification, game over, restart chapter) | Director states `RESOLVING`, then `CHAPTER_COMPLETE` or `COMPROMISED`, then `GAME_OVER`; Restart Chapter reloads the office at that chapter with the score rolled back | `test_unsafe_restart.gd` |
| 7. Feedback and Tips (explain each decision's result; cybersecurity guidance) | Feedback after every decision (`OutcomePanel`); chapter debrief (`FeedbackScreen`: Dela Vega's Black Veil attribution, warning signs, tip); Game Over: warning signs + tip | Validator: every choice has feedback; every chapter has debrief lines, warning signs and a tip |
| 8. Progress Tracking (+ external evaluation) | `Progress` + HUD + debrief and ending summaries. Evaluation is external | As Obj 7 |

### 4.3 Functional and non-functional requirements

| Req | Implementation |
|---|---|
| FR1 WASD + mouse look | `move_*` actions; `InputEventMouseMotion.screen_relative` in `player.gd` (world context only) |
| FR2 E on workstation and telephone | `interact` action, `InteractRay`, `Interactable.interact()` |
| FR3 Desktop with email, messaging, web pages on workstation interaction | The sit-down sequence opens `DesktopUI` |
| FR4 Four scenarios | 4 `ChapterData` |
| FR5 Inspect: sender, copy/paste link | Section 8.6 |
| FR6 Predefined actions (open, ignore, report, hang up...) | `ChoiceData` labels per step (section 6) |
| FR7 +10 / -5 / +20 | `ScoreRules` constants, pinned by a test |
| FR8 Game-over screen after unsafe choice; restart the chapter | `GameOverScreen` → `Progress.restart_chapter()` → office reload |
| FR9 Feedback after each scenario | `FeedbackScreen` (plus per-choice feedback) |
| FR10 Track progress; good or bad ending | `Progress`, HUD, `Ending.tscn`, `GameOverScreen` |
| NFR1 user-friendly | Instructions screen; HUD objective line; disabled devices show the current objective; inspection hint on locked choices; Paste button for players who don't know shortcuts; Pause menu to reach help or quit (PROPOSED) |
| NFR2 Windows desktop | Windows export preset, tested on the reference PC from M0 |
| NFR3 performance | 60 fps target, office under 60k triangles, profiled on the reference PC |
| NFR4 offline | No networking code (scope test); launch test with the network unplugged |
| NFR5 clear interface | One shared theme, bundled sans and monospace fonts, 1366x768 check |

### 4.4 Limitations and how the design obeys them

| Limitation | Design guarantee |
|---|---|
| 1. No multiplayer | No networking, multiplayer or process-launching API anywhere (scope test list in 13.5) |
| 2. No real threat detection or tools | All URLs, numbers and addresses are static strings in `.tres`. Nothing resolves, connects, opens or launches |
| 3. Four fixed chapters, fixed order; no adaptive/AI attacks; no USB baiting or in-person impersonation | `AttackType` has exactly 4 values, and `Campaign.chapters` is validated for count and order. There is no randomisation code. The schema has no field for physical objects, NPC dialogue in 3D or attackers in person |
| 4. No network/pentest/malware topics | Content-review checklist plus the validator's forbidden-phrase scan (13.2); feedback text exists only inside the 4 chapter resources |
| 5. No real OS simulation | 3 single-purpose apps, no window manager, no file system; the browser has no navigation |
| 6. No accounts or cloud progress | Progress is in memory only. Only preferences are saved locally. No Continue |
| 7. Feedback limited to implemented scenarios | Feedback strings live only in chapter data |
| 8. Educational only | The Instructions screen says this is awareness training |
| 9. Guided, designated interactions, predefined choices | Only 2 interactables; choices come only from `ChoiceData`; no text input; the HUD objective always says what to do next, and a disabled device repeats it |
| 10. Evaluation via Google Forms only | Nothing is measured or collected in game |
| Excluded paper material | GDD "Suggested 3D Gameplay Additions", Neutral/Perfect endings, and the old Game Lore's fake login pages, malicious ads, software-update lures and downloads: **none built, and none described in content text** (validator scan) |

---

## 5. Player flow (step by step)

1. **Launch.** The exported `.exe` opens `MainMenu.tscn`, fullscreen or windowed per the saved settings. MainMenu pushes the `menu` input context.
2. **Main Menu:** Start, Instructions, Settings, Exit. Instructions and Settings open as panels (`panel` context) and close with Back or ESC.
3. **Start** calls `Progress.start_new_game()`: score 0, no chapter complete, `pending_chapter = 1`, not a restart. `SceneRouter` fades to `Office.tscn`. Office pushes `world`.
4. **Office intro (state `INTRO`).** The player spawns at `IntroSpawn` by the entrance. Ms. Dela Vega stands at reception as a static figure. The `DialoguePanel` plays the intro: input is locked, and the player advances with E, Space, Enter, a click or ESC. The intro covers:
   - welcome to Aegis Solutions, and why the Vigilant Protocol exists: "We've had incidents caused by social engineering. Security has linked them to a criminal group called Black Veil."
   - "Check things before you act: who sent it, where a link really goes, who is calling."
   - "IT will never ask for your password. The IT Helpdesk is ext. 1100, and Security is ext. 1200."
   - "Your desk is over there. Press E to use your workstation."
5. **Chapter 1 briefing (`BRIEFING(1)`).** A short Dela Vega line. The HUD objective appears ("Check your email at your workstation"). Only the workstation is enabled. Looking at the disabled telephone shows the current objective, without "[E]".
6. **Walk to the desk** (8-10 m) and press E. The camera glides to the monitor and the desktop fades in. Mail shows a new-mail badge.
7. **Inspect.** The choice bar at the bottom of the desktop lists the responses, greyed out, with the hint "Inspect first: sender, link". The player clicks the sender name to see the full address. They click the link, choose **Copy link address**, open the Browser, and paste (Ctrl+V or the Paste button) to read the full URL. The bar unlocks.
8. **Decide.** The player clicks a response. The Outcome panel shows the delta and the feedback, and closes with Continue, Enter or ESC:
   - **CORRECT:** +10. Continue to the next step, or the chapter completes.
   - **WRONG:** -5. That option is disabled and the player stays on the same decision.
   - **UNSAFE:** -5, then the red **Compromise notice**, then the **Game Over / Bad Ending** screen (step 12).
9. **Chapter complete.** +20 ("Chapter complete +20"). The desktop closes and the player stands up. The **Feedback screen** shows Ms. Dela Vega's debrief line naming Black Veil as the attacker, the chapter's warning signs, the tip, and this chapter's score breakdown. Continue (or ESC).
10. **Next chapter.** `BRIEFING(n+1)` plays as an intercom message with Dela Vega's portrait, and the HUD objective changes:
    - **Ch2:** back to the workstation (Messages app).
    - **Ch3:** the desk phone rings (3D ring sound + blinking light). The workstation is disabled and shows "Answer the ringing telephone". E on the phone answers it, and the Call UI opens. ESC during the call shows the hint "Choose a response".
    - **Ch4:** workstation (Mail). Verifying through the known channel sends the player to the desk telephone to call Mr. Ramos.
11. **After Chapter 4's Feedback screen,** `SceneRouter` goes to **Ending.tscn** (good ending). It shows Dela Vega's closing lines ("You stopped all four of Black Veil's attempts this week"), "You passed the Vigilant Protocol", the final score out of 150, 4 of 4 chapters, a per-chapter breakdown, and Main Menu and Exit.
12. **Unsafe path.** The compromise notice (about 2.5 s; ESC is blocked) is followed by the **Game Over / Bad Ending** screen (ESC is blocked). It shows:
    - the chapter's Black Veil breach narration
    - the warning signs and the tip
    - the current score

    It has two buttons, which disable themselves after the first press:
    - **Restart Chapter:** the score rolls back to its value at chapter start, and the office reloads at the desk-side `ChapterSpawn`. That chapter's briefing plays, and the long intro is skipped.
    - **Main Menu:** the session is discarded.
13. **ESC while walking** opens the Pause menu (PROPOSED): Resume, Instructions, Settings, and Main Menu with a confirm that progress will be lost. ESC in a Pause sub-panel returns to the Pause menu, and ESC in the Pause menu resumes.
14. **Exit** from the Main Menu or the Ending screen quits the application.

---

## 6. The four chapters in detail

**Content rules.**
- All names, domains and numbers are fictional placeholders. The paper gives only surnames for the staff ("Ms. Dela Vega", "Mr. Ramos"), and content does not invent first names.
- Domains use the reserved `.example` suffix. The legitimate company domain is `aegis-solutions.example`.
- Phone numbers are masked (`09XX-XXX-0381` style), so no real subscriber is shown.
- The content writer finalises the wording (3.5). Structure, classifications and inspections are the design.
- All addresses, URLs and numbers render in the **monospace** font, so `l`, `1`, `rn` and `m` can be told apart.
- **Black Veil attribution:** the intro, each chapter's `debrief_lines`, every `compromise_text` and the good-ending lines name Black Veil. The validator checks this.
- **Content-review checklist** (applied at M2 and M5, and partly enforced by the validator's forbidden-phrase scan): no choice, feedback, dialogue or body text mentions login pages or sign-in forms, downloads, attachments, ads or pop-ups, software updates or installs, USB devices, malware, or in-person visitors. Ch1's lure is a benefits form, as GDD 8 describes; it is not a login page.

**Outcome rule (applies to every choice; enforced in review, and by the validator where it can be checked):**
- **CORRECT:** the protocol response the GDD names: report, delete (Ch1), verify through an official or known channel, or hang up and then report or call back a known number.
- **WRONG:** the attacker's goal is **not** achieved, but the response is not the protocol. Examples: replying, forwarding, ignoring without verifying or reporting, using a contact the attacker supplied, deleting a BEC email without reporting it, keeping a scam caller talking.
- **UNSAFE:** the attacker's goal **is** achieved: opening the malicious link and handing over personal details or payment, giving a password, disclosing personal data, or changing bank details and paying.

**Shared assets used by several chapters:**
- **Aegis Intranet: Staff Directory page** (Browser bookmark). This is the game's real-domain reference. Columns: Name, Department, Email, Extension. Rows:
  - HR, `hr@aegis-solutions.example`, ext. 1300
  - IT Helpdesk, `it.helpdesk@aegis-solutions.example`, ext. 1100
  - Security Office (Ms. Dela Vega), `security@aegis-solutions.example`, ext. 1200
  - R. Ramos, Manager, `r.ramos@aegis-solutions.example`, ext. 2045
- **SwiftParcel official site: Track a parcel page** (Browser bookmark). Static text: "Parcel SP-4417: In transit, on schedule. No fees due." and "SwiftParcel never asks for payment by text message." It has no input fields.
- **Desk phone card** shown in the Call UI: IT Helpdesk 1100, Security 1200.
- There is **no welcome email**. The inbox holds only the current chapter's attack email (see section 16 #18).

### Chapter 1: Email Phishing

| Item | Design |
|---|---|
| Trigger | Story: after the intro and the Ch1 briefing ("HR sends benefits forms to new hires this week. Check your inbox."). Interaction: E on the workstation |
| Where | Desktop, Mail app (new-mail badge) |
| Artifact | From **"Aegis HR Benefits" `<hr-benefits@aegis-solutions-hr.example>`**. Subject "ACTION REQUIRED: Confirm your benefits within 24 hours". Body: "Dear Employee, ... confirm your benefits enrolment within 24 hours or your coverage will be cancelled." Link text **"Aegis Benefits Portal"**, real URL `http://aegis-benefits-verify.example/confirm?emp=2291` (hidden in the body) |
| Inspectables | **Sender** (click the name: the full address shows an outside domain that only looks like Aegis). **Link** (copy, then paste in the Browser: the host is `aegis-benefits-verify.example`, not `aegis-solutions.example`). Visible without clicks: the generic greeting and the 24-hour urgency. The Staff Directory lists the real HR address |
| Required inspections | `sender`, `link_revealed:c1_portal` |
| Steps | 1 |

**Step 1: "What will you do with this email?"**

| Choice | Class | Delta | Feedback gist |
|---|---|---|---|
| Report it to Security as phishing | CORRECT (completes) | +10 | Reporting lets Security warn everyone and block the sender |
| Delete the email | CORRECT (completes) | +10 | Safe: you did not engage. Reporting it as well helps protect coworkers |
| Reply to ask HR if it is real | WRONG | -5 | Replying goes to the sender, who will say yes. Check through a contact you already know |
| Forward it to a coworker to ask | WRONG | -5 | Forwarding spreads the link to someone who may click it |
| Open the link and confirm your benefits details | UNSAFE | -5 | Compromise: "Your employee details were sent to Black Veil." (No page is shown) |

- **Completion:** +20. Best chapter total: 30.
- **Debrief line (Dela Vega):** "That email came from Black Veil. They copied the look of our HR messages to collect your details."
- **Warning signs:** lookalike sender domain; generic "Dear Employee"; 24-hour pressure; a link whose real address is not Aegis.
- **Tip:** "Before you click, read the real address. Copy the link and look at the domain right before the first single slash."
- **Bad ending text:** "Black Veil used your employee details to pose as you and trick coworkers into trusting their messages. Aegis Solutions has been breached."

### Chapter 2: Smishing

| Item | Design |
|---|---|
| Trigger | Story: Ch2 briefing ("Your welcome kit ships by courier this week. Your phone's messages sync to the desktop."). Interaction: E on the workstation |
| Where | Desktop, Messages app (badge) |
| Artifact | SMS from sender label **"SwftParcel"**, number `+63 9XX XXX 4417`: "SwftParcel: Parcel SP-4417 is ON HOLD. Pay PHP 45 redelivery fee within 2 hrs: [link]". Link text "swftparcel-redeliver", real URL `http://swiftparcel-redeliver.example/pay?ref=4417` |
| Inspectables | **Sender** (click the label: an ordinary mobile number, not the courier; misspelt name). **Link** (copy, then paste: the host is not `swiftparcel.example`). Visible: the unexpected fee and the 2-hour pressure |
| Required inspections | `sender_number`, `link_revealed:c2_pay` |
| Steps | 2 |

**Step 1: "How will you handle this text?"**

| Choice | Class | Delta | Feedback gist |
|---|---|---|---|
| Check the parcel on SwiftParcel's official website | CORRECT → step 2, opens the courier page | +10 | Use the official site you find yourself, never the link in the text. It shows no fees due |
| Reply "Who is this?" | WRONG | -5 | Replying confirms your number is active and invites more scams |
| Ignore it and do nothing | WRONG (PROPOSED — team to confirm) | -5 | You avoided the trap, but the protocol is to verify through the official channel and report it |
| Open the link and pay the fee | UNSAFE | -5 | Compromise: "Your card details were sent to Black Veil." |

**Step 2 (the courier page shows "No fees due"): "What now?"**

| Choice | Class | Delta | Feedback gist |
|---|---|---|---|
| Report the text to Security and delete it | CORRECT (completes) | +10 | Reporting helps others who got the same text |
| Keep it in case it is needed later | WRONG | -5 | Keeping it leaves the link one tap away |
| Forward it to coworkers as a warning | WRONG | -5 | Forwarding spreads the live link. Report it so Security can warn people safely |

- **Completion:** +20. Best chapter total: 40.
- **Debrief line:** "Black Veil sent that text too. When email didn't work, they tried your phone."
- **Warning signs:** an unknown mobile number posing as a courier; a misspelt brand; an unexpected small fee; time pressure; a link to a non-official domain.
- **Tip:** "Couriers do not collect fees through text links. Check the tracking number on the courier's official website."
- **Bad ending text:** "Black Veil charged your card and used your details to target Aegis staff. Aegis Solutions has been breached."

### Chapter 3: Vishing

| Item | Design |
|---|---|
| Trigger | Story: Ch3 briefing ("Your desk phone is now connected. Answer calls as they come in."). The phone rings (looping 3D ring, blinking logic-owned light). The workstation is disabled and shows the objective "Answer the ringing telephone". Interaction: E on the telephone |
| Where | Call UI over the darkened 3D view (the camera tweens to the phone) |
| Artifact (`call_script`) | Caller-ID display `OUTSIDE LINE 09XX-XXX-0381`. Caller "Mark from IT Support": "We've detected suspicious logins on your account. It locks in 5 minutes unless I verify you. Tell me your password now." |
| Inspectables | **Caller ID** (click the display: "External number. Internal Aegis calls show a 4-digit extension. The IT Helpdesk is ext. 1100."). Visible: the unsolicited call, the pressure, the password request. The desk phone card lists 1100 and 1200 |
| Required inspections | `caller_id` |
| Steps | 2 |

**Step 1 (the caller's lines play first): "How do you respond?"**

| Choice | Class | Delta | Feedback gist |
|---|---|---|---|
| Refuse and hang up | CORRECT → step 2 | +10 | IT never asks for your password. Ending the call is the right move |
| Ask him to prove he is from IT | WRONG | -5 | Keeping a scam caller talking gives them more chances to pressure you (response line: "There's no time, your account locks in 3 minutes!") |
| Tell him your password | UNSAFE | -5 | Compromise: "Black Veil logged in to your account with your password." |

**Step 2 ("You hung up. What next?", shown on the Call UI):**

| Choice | Class | Delta | Feedback gist |
|---|---|---|---|
| Report the call to Security (ext. 1200) | CORRECT (completes) | +10 | Security can warn others about this caller |
| Call the IT Helpdesk on the known ext. 1100 | CORRECT (completes) | +10 | Calling back on a number you already trust confirms the truth (response line from IT: "We never called you. Thanks for checking.") |
| Call back the number that called you | WRONG | -5 | That number belongs to the attacker |
| Do nothing | WRONG | -5 | Unreported calls let the attacker try your coworkers next |

- **Completion:** +20. Best chapter total: 40.
- **Debrief line:** "That 'IT' caller works for Black Veil. Real IT never needs your password."
- **Warning signs:** an unexpected call from an outside line claiming to be internal IT; urgency and a lockout threat; a password request.
- **Tip:** "No real IT team asks for your password. Hang up and call back on a number you already know."
- **Bad ending text:** "Black Veil used your password to enter Aegis systems. Aegis Solutions has been breached."
- ESC is blocked for the whole call, so it can never count as hanging up. Pressing it shows the hint "Choose a response".

### Chapter 4: Business Email Compromise

| Item | Design |
|---|---|
| Trigger | Story: Ch4 briefing ("Managers may send you finance tasks this week. Check your inbox."). Interaction: E on the workstation |
| Where | Desktop, Mail app. Then the Browser Staff Directory page, then the desk telephone (outgoing call) |
| Artifact | From **"R. Ramos" `<r.ramos@aegis-so1utions.example>`** (the digit 1 in place of the letter l). **Reply-To:** `rramos.office@securemail-box.example`. Subject "Urgent and confidential: supplier payment". Body: "I'm in a board meeting and can't take calls. Kestrel Office Supplies changed their bank account. Update their details and pay PHP 248,000 today. Keep this between us until it's done. R. Ramos" |
| Inspectables | **Sender** (click the name: From shows the lookalike domain, and Reply-To shows an outside address). Visible: urgency, secrecy, "can't take calls", a bank-detail change. The Directory page shows the real address and ext. 2045 |
| Required inspections | `sender` |
| Steps | 2 (step 2 waits for a telephone interaction) |

**Step 1: "How will you handle this request?"**

| Choice | Class | Delta | Feedback gist |
|---|---|---|---|
| Verify with Mr. Ramos through a known channel: look up his extension and call him | CORRECT → step 2, opens the Staff Directory | +10 | Use contact details you already trust, not the ones in the email. His extension is in the Staff Directory |
| Reply to the email to confirm | WRONG | -5 | The reply goes to the attacker's Reply-To address (response line: "Yes, do it now. I'm counting on you.") |
| Update the supplier's bank details and process the payment | UNSAFE | -5 | Compromise: "PHP 248,000 was sent to an account controlled by Black Veil." |

**Step 2 (needs the telephone; `wait_for = TELEPHONE`).**
- The DecisionBar shows the step's `wait_objective`, "Call Mr. Ramos on ext. 2045 using your desk phone", with no choices. The HUD objective changes to the same text.
- The player leaves the desk with ESC. The workstation is now disabled and shows the same objective. The telephone is enabled with the prompt "[E] Call Mr. Ramos (ext. 2045)" (`trigger_prompt`).
- The Call UI opens with the header `EXT 2045: R. RAMOS` (`call_header`) and Mr. Ramos's line: "I never sent that email. Don't pay anything, and please report it."
- The question is "What do you do with the email?"

| Choice | Class | Delta | Feedback gist |
|---|---|---|---|
| Report the email to Security (Ms. Dela Vega) | CORRECT (completes) | +10 | Security can block the lookalike domain and alert Finance |
| Delete it and say nothing | WRONG | -5 | The attacker will try someone else in Finance next |

- **Completion:** +20. Best chapter total: 40.
- **Debrief line:** "Black Veil pretended to be Mr. Ramos to steal a payment. Calling him on a number you trusted stopped them."
- **Warning signs:** a lookalike domain; a Reply-To mismatch; urgency plus secrecy; "can't take calls"; a change of bank details together with a payment.
- **Tip:** "Verify any payment or bank-detail change through a known channel, such as a phone number you already have, before acting."
- **Bad ending text:** "Black Veil received the payment, and the real supplier was never paid. Aegis Solutions has suffered a costly breach."

**Good ending lines (Dela Vega):** "You stopped all four of Black Veil's attempts this week: the fake HR email, the courier text, the fake IT call and the fake payment request." / "You've passed the Vigilant Protocol. Welcome to Aegis Solutions."

**Totals:** best run = 30 + 40 + 40 + 40 = **150**. A successful run that picks every WRONG option first = 20 + 20 + 25 + 30 = **95**. Tests compute both from data (section 13).

---

## 7. Rules: scoring, consequences, game over, restart, endings

### 7.1 Scoring (FR7, GDD 9)

| Event | Delta | Notes |
|---|---|---|
| CORRECT choice | **+10** | |
| WRONG choice | **-5** | The option is then disabled, so there is no repeat penalty |
| UNSAFE choice | **-5** (PROPOSED — team to confirm) | Treated as a wrong action under FR7. Shown on the Game Over screen, then rolled back if the player restarts |
| Chapter completed | **+20** | Awarded once per chapter, with a guard against awarding it twice |

- The values live **only** in `core/score_rules.gd` as constants. Choices declare an *outcome*, never points. A unit test pins 10 / -5 / -5 / 20.
- The score carries across chapters and is never reset between them.
- **No score floor** (PROPOSED — team to confirm). The score can briefly go negative (for example, a WRONG choice first in Chapter 1). Clamping would invent a rule the paper does not state.
- Every change is appended to `Progress.score_log` as `{chapter, step, choice, delta, reason}`. This drives the debrief and ending breakdowns and the tests.
- **Outcome notifications:** the Outcome panel ("Correct +10", "Wrong action -5", "Chapter complete +20") with the feedback text and Continue, plus a HUD score pulse.

### 7.2 Gap (a): WRONG (-5) vs UNSAFE (game over). PROPOSED — team to confirm
- **The rule:** *was the attacker's goal achieved?*
  - **No**, but the response is not the protocol: **WRONG**. The player gets -5 and feedback explaining why, the option is disabled, and the player stays on the same step. Every step therefore ends in either a CORRECT or an UNSAFE resolution.
  - **Yes** (personal details, card, password or money handed over): **UNSAFE**. The player gets -5, then the Compromise notice, then Game Over.
- **Validator checks:**
  - every step has at least 1 CORRECT
  - every chapter has at least 1 UNSAFE
  - UNSAFE and WRONG choices have no `next_step`
  - every chapter has compromise text and bad-ending text

### 7.3 Gap (b): when the bad ending shows vs restart. PROPOSED — team to confirm
- **The Game Over screen is the bad ending.** Every UNSAFE choice runs the same sequence:
  1. **Compromise notice:** a red in-world security alert with chapter-specific text, about 2.5 s, ESC blocked.
  2. **Game Over / Bad Ending screen:** the title "GAME OVER: Aegis Solutions has been breached", the Black Veil logo, the chapter's breach narration, the warning signs and tip, the current score, and **[Restart Chapter]** and **[Main Menu]**. ESC is blocked, so the player makes an explicit choice.
- This single screen satisfies Scope 5 ("bad ending when an unsafe choice leads to a breach"), Scope 6 and FR8 ("compromise notification and game over, after which the player may restart the chapter"), UI item 9, and storyboard frames 14 and 16. There are only two endings.
- **Alternative for the team:** show the bad-ending narration only when the player picks Main Menu. Not recommended, because a player who restarts would never see the bad ending.

### 7.4 Gap (c): score on chapter restart. PROPOSED — team to confirm
- `Progress.begin_chapter(n)` stores `score_at_chapter_start`.
- **Restart Chapter** rolls the score back to that value. It also removes that chapter's entries from `score_log`, and clears clues, disabled options and the in-game clipboard (the scene reloads).
- Points and completion from earlier chapters are kept, so "the score carries across chapters" still holds.
- **Why:** it prevents farming points through retries, the final score reflects one successful run per chapter, and the tests stay deterministic.
- **Alternative:** keep the failed attempt's points. That is a one-line change in `restart_chapter()`.
- **Main Menu** from Game Over, the Pause menu or the Ending discards the session. **Start** always begins a new run at score 0.

### 7.5 Endings
- **Good ending:** only after `Progress.all_complete()` (all four chapters done, in order). `Ending.tscn` shows Dela Vega's closing lines (naming Black Veil), the final score out of 150, 4 of 4 chapters, a per-chapter breakdown, and Main Menu and Exit.
- **Bad ending:** the Game Over screen (7.3), reachable from any UNSAFE choice.
- There are no Neutral or Perfect endings.

### 7.6 Other rules
- **Inspection gate** (PROPOSED — team to confirm):
  - The choice list is visible but disabled until every `required_inspections` entry is recorded, with the hint "Inspect first: sender, link".
  - The gate applies to the chapter's first step. Later steps are already unlocked.
  - This enforces Objective 5's "inspect ... before selecting".
- **Link clicks** (PROPOSED — team to confirm):
  - Left- or right-clicking a link in a message only opens a menu with one item, **Copy link address**.
  - Opening the link is possible **only** through the predefined UNSAFE choice button, so exploratory clicks during inspection can never end the game.
  - *Alternative:* a left-click counts as the UNSAFE "open link" choice, which is closer to the GDD's "clicking malicious content". It risks accidental game overs for testers aged 13 and up.
- **Leaving mid-chapter:** ESC at the desktop stands the player up. The chapter session (clues, disabled options) is kept, because the scene is not reloaded.
- **Content is read-only at runtime.** `.tres` resources are cached and shared by `ResourceLoader`, so the reloaded Office gets the same `ChapterData` instances. No code writes to a content resource. All mutable state lives in `ChapterSession` and `Progress`. A test hashes the campaign before and after a playthrough (13.2).

---

## 8. Godot architecture

### 8.1 Scenes
- `scenes/main_menu/MainMenu.tscn`: the **main scene** (Project Settings → Application → Run). It pushes the `menu` context in `_ready()`.
- `scenes/office/Office.tscn`: gameplay. It persists across chapters 1→4 and is reloaded only on Restart Chapter. It pushes the `world` context in `_ready()`.
- `scenes/ending/Ending.tscn`: the good ending. It pushes `menu` in `_ready()`.
- The Game Over, Feedback, Compromise and Pause screens are overlays inside `Office.tscn`, so Restart can reload from there.

### 8.2 `Office.tscn` scene tree
```
Office (Node3D)                          office.gd: pushes `world`; reads Progress → INTRO or BRIEFING(pending_chapter)
├─ WorldEnvironment                      ambient, tonemap
├─ Sun (DirectionalLight3D) / CeilingLights (OmniLight3D ×n)
├─ Level (Node3D)
│  ├─ Visual                             greybox: office_greybox.tscn (CSG, use_collision until the M5 bake) → later office_shell wrapper
│  └─ WorldCollision (StaticBody3D, layer 1)   added by the collision bake at M5 close (12.3)
├─ Props (Node3D)
│  ├─ Workstation (Workstation.tscn)     player's desk
│  ├─ Telephone (Telephone.tscn)         on the same desk
│  ├─ DelaVegaFigure (StaticFigure.tscn) static, NOT interactable, no script logic
│  └─ Decor (Node3D)                     other desks, closed manager-office door (decoration only)
├─ Markers
│  ├─ IntroSpawn (Marker3D)              entrance
│  └─ ChapterSpawn (Marker3D)            next to the desk (restart spawn)
├─ Player (Player.tscn)
├─ ChapterDirector (Node)                chapter_director.gd
└─ UI (Node)
   ├─ HUD (CanvasLayer, layer 1)         Crosshair, InteractPrompt, ObjectiveLabel, ScoreProgress (all mouse_filter IGNORE)
   ├─ DesktopLayer (CanvasLayer, 5)      DesktopUI.tscn (hidden)
   ├─ CallLayer (CanvasLayer, 6)         CallUI.tscn (hidden)
   ├─ DialogueLayer (CanvasLayer, 7)     DialoguePanel.tscn
   └─ OverlayLayer (CanvasLayer, 8)      OutcomePanel, FeedbackScreen, CompromiseNotice, GameOverScreen, PauseMenu (process_mode ALWAYS)
```

**Props (logic scenes; art only under `Visual`):**
```
Workstation (StaticBody3D, interactable.gd, layer 3)   interaction_id=&"workstation", prompt_text "Use workstation"
├─ CollisionShape3D (BoxShape3D)   encloses monitor + keyboard, sits in front of/above the desk collider
├─ DeskBody (StaticBody3D, layer 1) + CollisionShape3D   desk and chair blocking
├─ Visual (Node3D)                 greybox_workstation.tscn → workstation_art.tscn
└─ ViewAnchor (Marker3D)           seated camera pose facing the monitor

Telephone (StaticBody3D, telephone.gd — the ONLY script; `extends Interactable`, layer 3)   interaction_id=&"telephone", prompt_text "Answer telephone"
├─ CollisionShape3D (BoxShape3D)
├─ Visual (Node3D)
├─ RingPlayer (AudioStreamPlayer3D)  ring.ogg, looped
├─ RingLight (OmniLight3D, small)    logic-owned; blinked by RingAnim
├─ RingAnim (AnimationPlayer)
└─ ViewAnchor (Marker3D)
```

**Collision layers:** 1 `world`, 2 `player`, 3 `interactable`.
- The **Interactable is the StaticBody3D itself** on layer 3. Its shape must enclose the monitor and phone and stand slightly proud of the desk collider, so the ray hits it before the prop's own world collider.
- The player is on layer 2 with mask = layer 1.
- The ray's mask covers layers 1 and 3 (bit value `0b101` = 5), with `collide_with_areas = false`. Walls block interaction.

### 8.3 Player and interactables
```
Player (CharacterBody3D, player.gd)  layer 2, mask 1
├─ CollisionShape3D   CapsuleShape3D r=0.3 h=1.7
└─ Head (Node3D, y=1.6)      pitch, clamped ±80°
   └─ Camera3D (fov 75)
      └─ InteractRay (RayCast3D) target (0,0,-2.0), collision_mask = 5
```
```gdscript
# scenes/player/player.gd (abridged)
extends CharacterBody3D
const SPEED := 3.0
const LOOK_SCALE := 0.002
@onready var head: Node3D = $Head
@onready var ray: RayCast3D = $Head/Camera3D/InteractRay
var _focused: Interactable = null
var _shown_prompt: String = "\u0001"   # sentinel: forces the first emit

func _unhandled_input(e: InputEvent) -> void:
	if not InputRouter.is_world_active(): return
	if e is InputEventMouseMotion:
		# screen_relative is not scaled by canvas_items stretch, so sensitivity
		# is the same at 1366x768 and 1920x1080, windowed or fullscreen.
		var m := e as InputEventMouseMotion
		rotate_y(-m.screen_relative.x * Settings.mouse_sensitivity * LOOK_SCALE)
		head.rotate_x(-m.screen_relative.y * Settings.mouse_sensitivity * LOOK_SCALE)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("interact") and _focused != null and _focused.enabled:
		_focused.interact()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not is_on_floor(): velocity += get_gravity() * delta
	var dir := Vector3.ZERO
	if InputRouter.is_world_active():
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(v.x, 0.0, v.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()
	_update_focus()

func _update_focus() -> void:
	var target: Interactable = null
	if InputRouter.is_world_active() and ray.is_colliding():
		target = ray.get_collider() as Interactable   # a wall returns null
	_focused = target
	var prompt := ""
	if target != null:
		prompt = ("[E] " + target.prompt_text) if target.enabled else target.disabled_prompt
	# Re-evaluated every physics frame: catches a change of target AND a change of
	# enabled/prompt_text on the target the player is already looking at.
	if prompt != _shown_prompt:
		_shown_prompt = prompt
		Events.interact_focus_changed.emit(prompt)
```
```gdscript
# scenes/props/interactable.gd
class_name Interactable extends StaticBody3D
@export var interaction_id: StringName
@export var prompt_text: String = "Use"
@export var disabled_prompt: String = ""   # shown without "[E]"; the director sets it to the current objective
@export var enabled: bool = true
func interact() -> void:
	if enabled: Events.interacted.emit(interaction_id)
```
```gdscript
# scenes/props/telephone/telephone.gd (the only script on the Telephone root)
class_name Telephone extends Interactable
@onready var _ring_player: AudioStreamPlayer3D = $RingPlayer
@onready var _ring_anim: AnimationPlayer = $RingAnim
@onready var _ring_light: OmniLight3D = $RingLight
func ring() -> void:
	_ring_player.play(); _ring_anim.play(&"blink")
func stop_ring() -> void:
	_ring_player.stop(); _ring_anim.stop(); _ring_light.visible = false
```
There is no jump, sprint or crouch, because the paper does not list them.

### 8.4 Autoloads (in registration order)

| Autoload | File | Responsibility | Key API |
|---|---|---|---|
| `Events` | `autoload/events.gd` | Signal bus only, no state | see 8.9 |
| `Settings` | `autoload/settings.gd` | Load, apply and save `user://settings.cfg` (`ConfigFile`). The only file writer in the project | `mouse_sensitivity: float`, `master_volume: float`, `fullscreen: bool`, `apply()`, `save()`, `reset_defaults()` |
| `InputRouter` | `autoload/input_router.gd` | Context stack: mouse mode and ESC routing. `process_mode = ALWAYS` | `push(id, captured, on_exit, esc_allowed)`, `pop(id)`, `reset()`, `top_id()`, `is_world_active()` |
| `SceneRouter` | `autoload/scene_router.tscn` (CanvasLayer 100 + `Fade` ColorRect + `scene_router.gd`) | Fade + threaded load + `change_scene_to_packed`, re-entrancy guard, load-failure fallback. `process_mode = ALWAYS` | `goto(path)`, `reload_office_at_chapter(n)`, `quit_game()` |
| `Progress` | `autoload/progress.gd` | Session-only score, completion, snapshot, log | `start_new_game()`, `begin_chapter(n)`, `add(delta, info)`, `complete_chapter(n)`, `restart_chapter()`, `all_complete()`, `score`, `completed: Array[bool]`, `score_log: Array[Dictionary]`, `pending_chapter`, `is_restart` |
| `GameClipboard` | `autoload/game_clipboard.gd` | In-game copy buffer; never touches the OS clipboard | `copy_link(link: LinkData)`, `text`, `link_id`, `clear()` |

**Not autoloads:**
- `ScoreRules` and `ChapterValidator` are static `class_name` scripts in `core/`, testable with no scene tree.
- `ChapterSession` is a `RefCounted` holding pure logic.
- `ChapterDirector` is a scene node that dies with the scene.

```gdscript
# core/score_rules.gd: the ONLY place point values exist
class_name ScoreRules extends RefCounted
const CORRECT := 10
const WRONG := -5
const UNSAFE := -5          # PROPOSED: counts as a wrong action (FR7)
const CHAPTER_COMPLETE := 20
static func delta_for(o: ChoiceData.Outcome) -> int:
	match o:
		ChoiceData.Outcome.CORRECT: return CORRECT
		ChoiceData.Outcome.WRONG: return WRONG
		_: return UNSAFE
```

### 8.5 InputRouter (mouse capture and ESC)
```gdscript
# autoload/input_router.gd (abridged)
extends Node
var _stack: Array[Dictionary] = []   # {id, captured, on_exit: Callable, esc_allowed}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # must still see ESC while the tree is paused

func push(id: StringName, captured: bool, on_exit: Callable = Callable(), esc_allowed: bool = true) -> void:
	_stack.append({id = id, captured = captured, on_exit = on_exit, esc_allowed = esc_allowed}); _apply()
func pop(id: StringName) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i].id == id: _stack.remove_at(i); break
	_apply()
func reset() -> void:                     # SceneRouter calls this right before every scene change
	_stack.clear(); _apply()
func top_id() -> StringName:
	return &"" if _stack.is_empty() else _stack.back().id
func is_world_active() -> bool:
	return top_id() == &"world"
func _apply() -> void:
	var cap: bool = not _stack.is_empty() and _stack.back().captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if cap else Input.MOUSE_MODE_VISIBLE
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: _apply()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func _input(e: InputEvent) -> void:      # _input runs before GUI, so ESC is reliable
	if not e.is_action_pressed("exit_interface") or _stack.is_empty(): return
	get_viewport().set_input_as_handled()
	var top: Dictionary = _stack.back()
	var cb: Callable = top.on_exit
	if top.esc_allowed and cb.is_valid():
		cb.call()
	else:
		Events.esc_blocked.emit(top.id)   # CallUI shows "Choose a response"
```

**Base contexts.** Each root scene pushes its own base context in `_ready()`: Office pushes `world` (captured, on_exit = open Pause), and MainMenu and Ending push `menu` (visible, no on_exit). Because `SceneRouter.goto()` calls `InputRouter.reset()` before every scene change, no stale entry or freed-node callable survives a reload.

| Context | Pushed by | Mouse | ESC |
|---|---|---|---|
| `menu` | MainMenu, Ending (base) | visible | nothing |
| `panel` | Instructions or Settings opened from MainMenu or Pause | visible | close the panel (back one level) |
| `world` | Office (base) | captured | opens Pause (PROPOSED). Under the strict alternative, nothing |
| `pause` | PauseMenu | visible | resume |
| `desktop` | sit-down sequence | visible | stand up (leave desk) |
| `dialogue` | DialoguePanel | visible | advance one line (same as E) |
| `notice` | OutcomePanel, FeedbackScreen | visible | Continue (dismiss) |
| `call` | CallUI | visible | **blocked**, because hang-up is a scored choice; shows "Choose a response" |
| `alert` | CompromiseNotice (2.5 s), GameOverScreen | visible | **blocked** |

ESC exits every interface screen, as the paper says, except the three blocked cases (PROPOSED — team to confirm, section 16 #13). If an embedded `PopupMenu` is open, the first ESC closes the popup, and the next ESC goes to the context.

### 8.6 Desktop and inspection

**Presentation.** The desktop is a full-screen `Control` on `DesktopLayer`, **not** an interactive SubViewport on the monitor mesh. That keeps the text crisp for reading URLs, gives native GUI input, embedded popups and focus, and makes it easy to test.

**Sit-down sequence:**
1. `InputRouter.push(&"desktop", false, stand_up)`.
2. `create_tween()` moves the camera's global transform to `Workstation/ViewAnchor` over 0.4 s.
3. Show `DesktopLayer` and tween `modulate.a` from 0 to 1 over 0.2 s.

`stand_up` reverses these steps. The 3D monitor shows a static emissive texture. There is no live SubViewport.

```
DesktopUI (Control, full rect, theme = vigilant_theme.tres, desktop_ui.gd)
├─ Wallpaper (TextureRect / ColorRect in greybox)
├─ AppHost (MarginContainer)        one app visible, maximised
│  ├─ MailApp     HSplitContainer: Inbox (ItemList) | MessageView:
│  │              Subject (Label), SenderButton (flat Button) → SenderDetails (monospace Label, hidden),
│  │              Body (RichTextLabel + link_body.gd)
│  ├─ MessagesApp ThreadList (ItemList) | Thread (VBoxContainer of bubbles):
│  │              SenderButton → SenderDetails, Body (RichTextLabel + link_body.gd)
│  └─ BrowserApp  Toolbar: Bookmarks (2 Buttons, FOCUS_NONE) · AddressField (custom) · PasteButton (FOCUS_NONE)
│                 PageHost (Control): InspectionView | WebPageView (static page from WebPageData)
├─ DecisionBar (PanelContainer, bottom) prompt + ChoiceList + "Inspect first: …" hint / wait_objective
├─ Taskbar (HBoxContainer)          Mail, Messages, Browser (badges), static clock, "Leave desk (Esc)"
├─ LinkMenu (PopupMenu)             ONE owner: DesktopUI. One item: "Copy link address"
└─ Toast (Label)                    "Link address copied"
```

**Link inspection (FR5):**
- Bodies are `RichTextLabel` with `bbcode_enabled = true`, `selection_enabled = false` and `context_menu_enabled = false`, so the engine can never copy text to the OS clipboard. Links are written `[url=c1_portal]Aegis Benefits Portal[/url]`. The real address is never shown on hover. Copying and pasting is how the player reads it.
- Left-click (`meta_clicked`) or right-click (tracked through `meta_hover_started`/`meta_hover_ended`) makes the body emit `link_menu_requested`. **DesktopUI** is the single owner of `LinkMenu`: it stores the pending link, opens the menu, and on **Copy link address** calls `GameClipboard.copy_link()` exactly once.
- The **AddressField** is a custom `Control` (`focus_mode = FOCUS_ALL`) with a monospace `RichTextLabel` child set to `mouse_filter = IGNORE`, so clicks reach the field. It is **not** a `LineEdit`, so there is no typing and no OS clipboard. Paste works through **Ctrl+V** (`ui_paste`) while the field has focus, or through the **Paste** button. There is no right-click paste menu. The field grabs focus when the Browser opens and on left-click. Pasting shows the full URL with the host in bold, and the game does not colour it red or call it fake.
- Pasting **never navigates**. It shows `InspectionView` ("Address shown for inspection only. This training desktop does not open outside pages.") and emits `inspection_done(&"link_revealed:<id>")`.
- `GameClipboard` is cleared at every chapter start, and `DesktopUI.load_chapter()` resets all link state.

```gdscript
# ui/desktop/link_body.gd
class_name LinkBody extends RichTextLabel
signal link_menu_requested(link: LinkData, at: Vector2)
var _links: Dictionary[StringName, LinkData] = {}
var _hover_meta: Variant = null

func _ready() -> void:
	bbcode_enabled = true
	selection_enabled = false
	context_menu_enabled = false
	meta_hover_started.connect(_on_hover_start)
	meta_hover_ended.connect(_on_hover_end)
	meta_clicked.connect(_on_meta_clicked)

func set_content(bbcode: String, links: Array[LinkData]) -> void:
	_links.clear(); _hover_meta = null
	for l in links: _links[l.id] = l
	text = bbcode

func _on_hover_start(m: Variant) -> void: _hover_meta = m
func _on_hover_end(_m: Variant) -> void: _hover_meta = null
func _on_meta_clicked(m: Variant) -> void: _request(StringName(str(m)))
func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and _hover_meta != null:
		_request(StringName(str(_hover_meta))); accept_event()
func _request(id: StringName) -> void:
	var l: LinkData = _links.get(id)
	if l != null: link_menu_requested.emit(l, get_viewport().get_mouse_position())
# Never call OS.shell_open. A meta click never opens anything.
```
```gdscript
# ui/desktop/desktop_ui.gd (excerpt): the single owner of LinkMenu
@onready var link_menu: PopupMenu = $LinkMenu
var _pending_link: LinkData = null

func _ready() -> void:
	link_menu.add_item("Copy link address", 0)
	link_menu.id_pressed.connect(_on_link_menu_id)
	for body: LinkBody in [%MailBody, %SmsBody]:
		body.link_menu_requested.connect(_on_link_menu_requested)

func _on_link_menu_requested(link: LinkData, at: Vector2) -> void:
	_pending_link = link
	link_menu.position = Vector2i(at)
	link_menu.popup()

func _on_link_menu_id(_id: int) -> void:
	if _pending_link == null: return
	GameClipboard.copy_link(_pending_link)
	_pending_link = null
	_show_toast("Link address copied")

func load_chapter(data: ChapterData) -> void:
	_pending_link = null
	link_menu.hide()
	%MailApp.load_chapter(data)       # calls LinkBody.set_content(...) or shows "No messages"
	%MessagesApp.load_chapter(data)
	%BrowserApp.reset()
```
```gdscript
# ui/desktop/address_field.gd
class_name AddressField extends Control
@onready var display: RichTextLabel = $Display
func _ready() -> void:
	focus_mode = FOCUS_ALL
	display.mouse_filter = MOUSE_FILTER_IGNORE      # otherwise the label eats the click and focus never arrives
	display.selection_enabled = false
	display.context_menu_enabled = false
func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		grab_focus(); accept_event()
	elif e.is_action_pressed("ui_paste"):
		paste(); accept_event()
func paste() -> void:
	if GameClipboard.link_id == &"": return
	display.text = UrlFormat.bold_host(GameClipboard.text)
	Events.inspection_done.emit(StringName("link_revealed:" + String(GameClipboard.link_id)))
```

**Other inspections:**
- **Sender (Mail):** clicking `SenderButton` toggles `SenderDetails`, which shows `From:` and `Reply-To:` in monospace, and emits `inspection_done(&"sender")`.
- **SMS:** clicking the sender label shows the full number and emits `&"sender_number"`.
- **Call:** clicking the caller-ID display shows the detail and emits `&"caller_id"`.

**Inbox content per chapter:** on each `BRIEFING(n)`, `DesktopUI.load_chapter(data)` rebuilds the apps from data:
- **Mail:** this chapter's email (Ch1, Ch4), otherwise "No messages".
- **Messages:** this chapter's SMS (Ch2), otherwise "No messages".
- **Browser:** always the two bookmarks.

This keeps every chapter deterministic, and the desktop shows no content outside the chapters.

### 8.7 Call UI
```
CallUI (Control on CallLayer)
├─ CallerIdDisplay (flat Button, LCD style, monospace, FOCUS_NONE)   click → inspection (Ch3); shows call_header (Ch4)
├─ PhoneCard (Label)        "IT Helpdesk 1100 · Security 1200"
├─ Transcript (RichTextLabel, selection off)  lines appended with a typewriter tween on visible_ratio + blip SFX
├─ EscHint (Label, hidden)  "Choose a response" (shown for 1.5 s on Events.esc_blocked(&"call"))
└─ ChoiceList (shared)
```
- **Incoming flow (Ch3):**
  1. The director calls `telephone.ring()` and enables the telephone.
  2. E stops the ring, plays the pickup SFX, tweens the camera to the phone's `ViewAnchor`, and calls `InputRouter.push(&"call", false, Callable(), false)`.
  3. `CallerIdDisplay` shows `call_script.caller_id_display`. The step's `context_lines` play, then the choices.
- **Outgoing flow (Ch4 step 2):** the telephone is enabled with `prompt_text = step.trigger_prompt`. The Call UI opens with `CallerIdDisplay` showing `step.call_header` (`EXT 2045: R. RAMOS`, not inspectable), then the step's `context_lines`, then the choices. Ch4 has no `CallScript`. The outgoing call uses **only** `DecisionStep.call_header` and `context_lines`.

### 8.8 Scenario data model (typed custom Resources, text `.tres`)

**Naming rule:** no Resource or Node member may reuse a native Object, Node or Resource member name (`call`, `name`, `get`, `set`, `free`, `emit_signal`, `owner`, `notification` and so on). GDScript 2.0 rejects these at parse time, which breaks every script that depends on the class.

```gdscript
class_name Campaign extends Resource
@export var intro: Array[DialogueLine] = []          # must name Black Veil
@export var chapters: Array[ChapterData] = []        # exactly 4, fixed order
@export var good_ending_lines: Array[DialogueLine] = []   # must name Black Veil

class_name ChapterData extends Resource
enum AttackType { EMAIL_PHISHING, SMISHING, VISHING, BEC }   # 4 values ONLY
enum Trigger { WORKSTATION, TELEPHONE }
@export var id: StringName
@export var index: int                               # 1..4
@export var title: String
@export var attack: AttackType
@export var trigger: Trigger
@export var objective_text: String                   # HUD objective; also the disabled device's prompt
@export var briefing: Array[DialogueLine] = []
@export var email: EmailMessage                      # Ch1, Ch4 only
@export var sms: SmsMessage                          # Ch2 only
@export var call_script: CallScript                  # Ch3 only (Ch4's outgoing call uses DecisionStep.call_header)
@export var required_inspections: Array[StringName] = []
@export var steps: Array[DecisionStep] = []          # steps[0] is the entry step
@export var debrief_lines: Array[DialogueLine] = []  # Dela Vega on the Feedback screen; must name Black Veil
@export var warning_signs: PackedStringArray
@export_multiline var tip: String
@export_multiline var compromise_text: String        # must name Black Veil
@export_multiline var bad_ending_text: String

class_name DecisionStep extends Resource
enum Surface { DESKTOP, CALL }
enum Wait { NONE, TELEPHONE }
@export var id: StringName
@export var surface: Surface
@export var wait_for: Wait = Wait.NONE               # Ch4 step 2: player must use the telephone first
@export var wait_objective: String                   # HUD + DecisionBar text while waiting; also the workstation's disabled prompt
@export var trigger_prompt: String                   # telephone prompt while waiting, e.g. "Call Mr. Ramos (ext. 2045)"
@export var call_header: String                      # e.g. "EXT 2045: R. RAMOS" for outgoing calls
@export var prompt: String
@export var context_lines: Array[DialogueLine] = []  # caller / Ramos lines before choices
@export var choices: Array[ChoiceData] = []

class_name ChoiceData extends Resource
enum Outcome { CORRECT, WRONG, UNSAFE }
@export var id: StringName
@export var label: String
@export var outcome: Outcome = Outcome.WRONG         # NO points field
@export_multiline var feedback: String
@export var response_lines: Array[DialogueLine] = [] # shown in the Outcome panel
@export var next_step: StringName                    # CORRECT only; &"" = chapter complete
@export var opens_page: StringName                   # e.g. &"courier_official"

class_name EmailMessage extends Resource   # from_name, from_address, reply_to, subject, date_text, body_bbcode, links: Array[LinkData]
class_name SmsMessage extends Resource     # sender_label, sender_number, body_bbcode, links: Array[LinkData]
class_name CallScript extends Resource     # caller_id_display, caller_id_detail
class_name LinkData extends Resource       # id, anchor_text, real_url
class_name WebPageData extends Resource    # id, url_display, title, body_bbcode (static; no input fields)
class_name DialogueLine extends Resource   # speaker: CharacterData, text
class_name CharacterData extends Resource  # display_name, role, portrait: Texture2D
```
The schema enforces the scope:
- There is no type for an NPC in 3D, a physical object, free text, a login form, an attachment, a download, or a message outside a chapter.
- `AttackType` has exactly 4 values.
- `WebPageData` has no form fields.

**Authoring rules for writers:**
- Content resources are read-only at runtime (7.6).
- When cloning a step, choice or line in the Inspector, use **Make Unique (Recursive)**. Copy and paste otherwise produces shared sub-resources, so editing one silently edits the other.

### 8.9 Signals (`Events`)
`interacted(id: StringName)`, `interact_focus_changed(prompt: String)`, `inspection_done(id: StringName)`, `link_copied(link_id: StringName)`, `choice_selected(choice: ChoiceData)`, `score_changed(score: int, delta: int, reason: StringName)`, `objective_changed(text: String)`, `chapter_started(n: int)`, `chapter_completed(n: int)`, `compromised(n: int)`, `page_opened(id: StringName)`, `desktop_opened()`, `desktop_closed()`, `call_started()`, `call_ended()`, `esc_blocked(context: StringName)`.

Rule: connect autoload signals to **methods**, never to lambdas that capture scene nodes. Godot drops method connections when the target node is freed, so reloads leave no stale callables.

### 8.10 Chapter logic and state machine

**Pure logic: `core/chapter_session.gd`.** It has no scene and is unit-tested directly. It never writes to `data`.
```gdscript
class_name ChapterSession extends RefCounted
enum Result { STAYED, ADVANCED, COMPLETED, COMPROMISED, IGNORED }
var data: ChapterData
var step: DecisionStep
var inspections: Dictionary[StringName, bool] = {}
var disabled: Dictionary[StringName, bool] = {}
func _init(d: ChapterData) -> void: data = d; step = d.steps[0]
func record_inspection(id: StringName) -> void: inspections[id] = true
func is_unlocked() -> bool:
	if step != data.steps[0]: return true
	return data.required_inspections.all(func(i: StringName) -> bool: return inspections.has(i))
func choose(c: ChoiceData) -> Result:
	if disabled.has(c.id) or not is_unlocked(): return Result.IGNORED
	match c.outcome:
		ChoiceData.Outcome.WRONG:
			disabled[c.id] = true; return Result.STAYED
		ChoiceData.Outcome.UNSAFE:
			return Result.COMPROMISED
		_:
			if c.next_step == &"": return Result.COMPLETED
			step = _find(c.next_step); return Result.ADVANCED
func _find(id: StringName) -> DecisionStep:
	for s in data.steps:
		if s.id == id: return s
	return null
```

**Wiring: `scenes/office/chapter_director.gd`.** It uses an enum plus `match`, not a node-based FSM.

| State | Entry actions | Exits to |
|---|---|---|
| `INTRO` | Player at `IntroSpawn`; DialoguePanel plays `Campaign.intro` (pushes `dialogue`) | `BRIEFING(1)` |
| `BRIEFING(n)` | `Progress.begin_chapter(n)` (snapshot); `GameClipboard.clear()`; new `ChapterSession`; `DesktopUI.load_chapter`; play the briefing (intercom portrait); set the HUD objective | `AWAIT_TRIGGER` |
| `AWAIT_TRIGGER` | Enable only the chapter's trigger device (Ch3: `telephone.ring()`). Disable the other device and set its `disabled_prompt = objective_text` | `ACTIVE` on `Events.interacted(trigger)` |
| `ACTIVE` | Open the step's surface (desktop app or Call UI); badge or deliver content; `ChoiceList.set_choices(step.choices, locked = not session.is_unlocked(), used = session.disabled)` | On `choice_selected` → `RESOLVING`; on `inspection_done` → refresh the lock |
| `RESOLVING` | `r = session.choose(c)`; `Progress.add(ScoreRules.delta_for(c.outcome), …)`; Outcome panel (`notice`: delta, response lines, feedback); `opens_page` → Browser | STAYED → `ACTIVE` (same step); ADVANCED → `ACTIVE`, or `AWAIT_STEP_TRIGGER` if `wait_for == TELEPHONE`; COMPLETED → `CHAPTER_COMPLETE`; COMPROMISED → `COMPROMISED` |
| `AWAIT_STEP_TRIGGER` | HUD objective and DecisionBar = `wait_objective`; the desktop stays open until the player leaves; the workstation is disabled with `disabled_prompt = wait_objective`; the telephone is enabled with `prompt_text = trigger_prompt` | `ACTIVE` (CALL surface) on `interacted(&"telephone")` |
| `CHAPTER_COMPLETE` | `Progress.complete_chapter(n)` (+20); close the desktop or call; stand up | `CHAPTER_FEEDBACK` |
| `CHAPTER_FEEDBACK` | `FeedbackScreen` (`notice`): `debrief_lines`, warning signs, tip, this chapter's `score_log` lines | n < 4 → `BRIEFING(n+1)`; n = 4 → `SceneRouter.goto(Paths.ENDING)` |
| `COMPROMISED` | `Events.compromised(n)`; `CompromiseNotice` (`alert`, 2.5 s) | `GAME_OVER` |
| `GAME_OVER` | `GameOverScreen` (`alert`: bad-ending text, warning signs, tip, score) | Restart → `Progress.restart_chapter()` + `SceneRouter.reload_office_at_chapter(n)`; Menu → `SceneRouter.goto(Paths.MAIN_MENU)`. Both buttons disable themselves on first press |

`office.gd._ready()` first pushes `world`. Then, if `Progress.is_restart`, it spawns the player at `ChapterSpawn`, clears `is_restart` and enters `BRIEFING(Progress.pending_chapter)`. Otherwise it enters `INTRO`.

**Dialogue and button input:**
- Dialogue advances in one place only: `DialoguePanel._unhandled_input` acts on `interact` or `ui_accept` only when `InputRouter.top_id() == &"dialogue"`. A click on the panel (`_gui_input`) or ESC (the `on_exit` callable) also advances. The first press finishes the typewriter line, and the next press advances.
- The Outcome and Feedback panels take `ui_accept` the same way, gated on `top_id() == &"notice"`.
- Next, Continue and every `ChoiceList` button use `focus_mode = FOCUS_NONE`. A Space or Enter press can therefore never activate a focused button, advance two lines, or fire a choice right after the Outcome panel closes. Choices are made with the mouse.

### 8.11 Scene transitions
```gdscript
# autoload/scene_router.gd (on scene_router.tscn: CanvasLayer layer 100 → Fade: ColorRect, full rect, alpha 0)
extends CanvasLayer
@onready var fade: ColorRect = $Fade
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func goto(path: String) -> void:
	if _busy: return                                  # double-click guard
	_busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP     # block clicks during the fade
	await _fade(1.0)
	var status := ResourceLoader.THREAD_LOAD_FAILED
	if ResourceLoader.load_threaded_request(path) == OK:
		status = ResourceLoader.load_threaded_get_status(path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(path)
	var packed: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		push_error("SceneRouter: could not load %s" % path)
		if path != Paths.MAIN_MENU: packed = load(Paths.MAIN_MENU) as PackedScene
	get_tree().paused = false
	InputRouter.reset()                               # the new root pushes its own base context
	if packed != null: get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await _fade(0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func reload_office_at_chapter(n: int) -> void:
	if _busy: return
	Progress.pending_chapter = n; Progress.is_restart = true
	goto(Paths.OFFICE)
```
**Pausing:** the Pause menu sets `get_tree().paused = true`. `InputRouter`, `SceneRouter` and `PauseMenu` run with `PROCESS_MODE_ALWAYS`. The Instructions and Settings panels instanced inside `PauseMenu` keep the default `INHERIT`, so they run while paused too.

### 8.12 Godot gotchas checklist (use in code review)
- No member may reuse a native Object, Node or Resource name (`call`, `name`, `get`, `set`, `free` ...).
- HUD Controls use `mouse_filter = MOUSE_FILTER_IGNORE`, and so does any label inside a custom clickable control (`AddressField/Display`), or the label eats the clicks.
- Every `RichTextLabel` has `selection_enabled = false` and `context_menu_enabled = false`, or Ctrl+C reaches the OS clipboard.
- No `LineEdit`, `TextEdit`, `CodeEdit`, `SpinBox` or `FileDialog` anywhere (SpinBox and FileDialog contain a hidden LineEdit).
- Buttons that must not react to Space or Enter use `focus_mode = FOCUS_NONE`.
- Autoloads that must work while paused (`InputRouter`, `SceneRouter`) and `PauseMenu` use `PROCESS_MODE_ALWAYS`.
- `SceneRouter.goto()` is the only way to change scenes, so `InputRouter.reset()` always runs.
- Autoload signals connect to methods, not to node-capturing lambdas.
- Use `create_tween()` on the owning node, so tweens die with the scene.
- Keep `PopupMenu` embedded. Verify its position under `canvas_items` stretch in the M0 spike. Each popup has exactly one owner that connects `id_pressed`.
- `RichTextLabel` has no right-click meta signal. Track `meta_hover_started/ended`. Never connect `meta_clicked` to `OS.shell_open`.
- Mouse look uses `screen_relative`, not `relative`.
- Recapture the mouse on `NOTIFICATION_APPLICATION_FOCUS_IN` only when the top context is captured (alt-tab on Windows).
- The interactable body's shape must be hit before the prop's own world collider.
- Content `.tres` files are never written at runtime. Clone sub-resources with Make Unique (Recursive).
- Lambdas in typed code need typed parameters (`func(i: StringName) -> bool:`).
- Never edit nodes inside an imported `.glb`. Use import settings or a wrapper scene.
- Commit `*.import` and `*.uid`. Ignore `.godot/`. Run `--import` before headless tests (13).
- Debug-only code is wrapped in `if OS.is_debug_build():`.

---

## 9. UI screens

| # (paper UI list) | Screen | Scene | Contents / behaviour |
|---|---|---|---|
| 1 | Main Menu | `MainMenu.tscn` | Title "Vigilant"; **Start** (always a new game), **Instructions**, **Settings**, **Exit**. No Continue, no Chapter Select |
| 2 | Instructions | `ui/common/InstructionsPanel.tscn` | Controls (WASD, mouse, E, ESC); how to play: walk to the device, press E, **inspect first** (click the sender; click a link → Copy link address → paste in the Browser address field with Ctrl+V or Paste; check the caller ID), then click a response; scoring (+10 correct, -5 wrong, +20 per chapter); an unsafe choice means a breach and game over, and you may restart the chapter; good ending after all 4 chapters; "This is an awareness game, not professional training." Back or ESC |
| 3 | Settings | `ui/common/SettingsPanel.tscn` | **Gap (d)**, see below. Back or ESC |
| 4 | 3D environment + HUD | `Office.tscn`, `ui/hud/HUD.tscn` | Crosshair; prompts "[E] Use workstation" / "[E] Answer telephone" / "[E] Call Mr. Ramos (ext. 2045)"; a disabled device shows the current objective without "[E]"; objective line; "Score 40 · Chapter 2 of 4" with 4 pips (done / current / locked) |
| 5 | Simulated Desktop | `ui/desktop/DesktopUI.tscn` | Mail, Messages, Browser, DecisionBar, Taskbar (8.6). ESC stands up |
| 6 | Dialogue and Choice Panel | `ui/common/DialoguePanel.tscn`, `ui/common/ChoiceList.tscn` | Portrait, name, typewriter text, Next (FOCUS_NONE); advance with E, Space, Enter, a click or ESC. `ChoiceList` (mouse-only buttons) is shared by the DecisionBar and the Call UI |
| 6b | Call UI | `ui/call/CallUI.tscn` | Caller-ID display or call header, phone card, transcript, choices; ESC shows "Choose a response" |
| — | Outcome panel | `ui/common/OutcomePanel.tscn` | Modal: "Correct +10" / "Wrong action -5", response lines, feedback text, Continue (or Enter or ESC) |
| 7 | Feedback Screen (chapter debrief) | `ui/screens/FeedbackScreen.tscn` | "Ms. Dela Vega" header with portrait and the chapter's `debrief_lines` (names Black Veil), warning signs list, tip, this chapter's score lines, chapter total, Continue (or Enter or ESC) |
| 8 | Score and Progress Display | HUD `ScoreProgress`; repeated on Feedback, Game Over and Ending | |
| 9 | Compromise notice | `ui/screens/CompromiseNotice.tscn` | Red full-screen security alert with the chapter text (names Black Veil). It is not a web page. ESC blocked |
| 9 | Game Over / Bad Ending | `ui/screens/GameOverScreen.tscn` | Gap (b): Black Veil logo, breach narration, warning signs, tip, score, Restart Chapter, Main Menu. ESC blocked |
| 9 | Good Ending | `scenes/ending/Ending.tscn` | "Vigilant Protocol passed", Dela Vega's closing lines (name Black Veil), final score / 150, 4 of 4, per-chapter breakdown, Main Menu, Exit |
| (nav) | Pause (PROPOSED — team to confirm) | `ui/screens/PauseMenu.tscn` | Resume, Instructions, Settings, Main Menu (with the confirm "Your progress in this session will be lost."). No other options. Trace: Scope 2 "access to instructions and settings" and NFR1 (a way to quit mid-session). It reuses the same Instructions and Settings panels |

**Gap (d): Settings contents. PROPOSED — team to confirm.** Kept minimal and saved to `user://settings.cfg`. Only `HSlider`, `OptionButton` and `Button` controls are used:
1. **Mouse sensitivity**: `HSlider`, 0.2x to 2.0x, default 1.0x.
2. **Master volume**: `HSlider`, 0-100%; sets `AudioServer.set_bus_volume_db(0, linear_to_db(v))`, muted at 0.
3. **Display mode**: `OptionButton` Windowed / Fullscreen; sets `DisplayServer.window_set_mode(...)`.
4. **Reset to defaults** and **Back**.

There is no key rebinding (the paper fixes the controls), no graphics presets, no language option and no text input. Saving device preferences locally is not an account and not saved progress. If the panel objects, settings become session-only with a one-line change in `Settings.save()`.

**Gap (e): desktop apps and web pages. PROPOSED — team to confirm.** There are exactly three apps:
- **Mail:** the Ch1 and Ch4 emails, one per chapter.
- **Messages:** the Ch2 SMS.
- **Browser**, with no free navigation:
  1. **Address inspection view.** It shows a pasted link's full address with the host in bold, for Ch1 and Ch2. It never loads a page.
  2. **SwiftParcel official site: Track a parcel.** Opened by the Ch2 CORRECT choice or its bookmark. Static, with no inputs.
  3. **Aegis Intranet: Staff Directory.** Opened by the Ch4 CORRECT choice or its bookmark. It is also the real-domain reference for the Ch1 HR address and the IT and Security extensions in Ch1 and Ch3 feedback.

A malicious link never renders a page. It can be opened only through the UNSAFE choice button, which goes straight to the Compromise notice. The validator rejects any `WebPageData` that no chapter references.

---

## 10. Input map

| Action | Binding | Used by |
|---|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D | `Input.get_vector(...)` in `player.gd` (FR1) |
| (mouse look) | `InputEventMouseMotion.screen_relative` | `player.gd`, `world` context only (FR1) |
| `interact` | **E** (exactly one key event) | Interaction ray (FR2); also advances dialogue |
| `exit_interface` | **Escape** | `InputRouter` per context (8.5) |
| `ui_accept` (built-in) | Enter / Space | Advance dialogue; dismiss Outcome and Feedback (gated on the top context, never through button focus) |
| `ui_paste` (built-in) | Ctrl+V | Paste into the focused `AddressField` |
| GUI clicks (built-in) | Left / right mouse | Buttons, choices, sender reveal, link menu |
| `debug_*` | Debug builds only | Optional chapter jump and state overlay behind `OS.is_debug_build()`; unreachable in the release export |

There is no jump, sprint or crouch, and F is not bound. The scope test checks the bindings (13.5).

---

## 11. Project folder structure

```
vigilant/                         git root = Godot project root (res://)
├─ project.godot  export_presets.cfg  GODOT_VERSION  README.md  run_tests.bat
├─ .gitignore     (.godot/, builds/)          .gitattributes (LFS: *.glb *.png *.ogg *.wav *.blend *.ttf)
├─ art_src/       Blender .blend + references; contains .gdignore
├─ builds/        (ignored) Windows exports
├─ addons/gut/    GUT test framework (pinned version; excluded from export)
├─ autoload/      events.gd settings.gd input_router.gd scene_router.gd scene_router.tscn progress.gd game_clipboard.gd
├─ core/          score_rules.gd chapter_session.gd chapter_validator.gd url_format.gd paths.gd content_hash.gd
├─ data/
│  ├─ schema/     campaign.gd chapter_data.gd decision_step.gd choice_data.gd email_message.gd sms_message.gd
│  │              call_script.gd link_data.gd web_page_data.gd dialogue_line.gd character_data.gd
│  ├─ campaign.tres
│  ├─ chapters/   ch1_email_phishing.tres ch2_smishing.tres ch3_vishing.tres ch4_bec.tres
│  ├─ characters/ dela_vega.tres ramos.tres it_caller.tres it_helpdesk.tres system.tres
│  └─ pages/      courier_official.tres intranet_directory.tres
├─ scenes/
│  ├─ main_menu/  MainMenu.tscn main_menu.gd
│  ├─ office/     Office.tscn office.gd chapter_director.gd
│  ├─ player/     Player.tscn player.gd
│  ├─ props/      interactable.gd  workstation/  telephone/ (Telephone.tscn telephone.gd)  static_figure/
│  ├─ ui/
│  │  ├─ common/  DialoguePanel.tscn ChoiceList.tscn OutcomePanel.tscn InstructionsPanel.tscn SettingsPanel.tscn
│  │  ├─ hud/     HUD.tscn
│  │  ├─ desktop/ DesktopUI.tscn desktop_ui.gd link_body.gd address_field.gd apps/mail/ apps/messages/ apps/browser/
│  │  ├─ call/    CallUI.tscn
│  │  └─ screens/ FeedbackScreen.tscn CompromiseNotice.tscn GameOverScreen.tscn PauseMenu.tscn
│  └─ ending/     Ending.tscn
├─ art/
│  ├─ greybox/    office_greybox.tscn greybox_*.tscn greybox_mats/
│  ├─ lowpoly/    *.glb (+ .import)
│  ├─ wrappers/   *_art.tscn (instance the .glb; these go into Visual slots)
│  ├─ materials/  extracted materials, palette.png
│  └─ ui/         theme/vigilant_theme.tres fonts/ (OFL sans + monospace) portraits/ icons/
├─ audio/         ring.ogg pickup.ogg dialtone.ogg alert.ogg ui_click.ogg blip.ogg
├─ tests/         (excluded from export)
│  ├─ unit/        test_score_rules.gd test_progress.gd test_chapter_session.gd test_clipboard.gd
│  │               test_input_router.gd test_settings.gd test_url_format.gd test_scene_router.gd
│  ├─ content/     test_chapter_data.gd (runs ChapterValidator on the real campaign) test_content_immutable.gd
│  ├─ integration/ test_interaction.gd test_playthrough.gd test_unsafe_restart.gd test_empty_visual.gd
│  └─ scope/       test_scope_guard.gd
└─ tools/         validate_content.gd (@tool EditorScript: File → Run, for writers; excluded from export)
```
Ownership: Systems owns `autoload/`, `core/`, `scenes/office/`, `tests/`. Interface owns `scenes/ui/`, `scenes/main_menu/`, `art/ui/`. Content & Art owns `data/`, `art/`, `audio/` and the level.

**Export preset (Windows, release):**
- `exclude_filter = "tests/*, addons/gut/*, tools/*, art_src/*"`. This keeps test code, the GUT framework and the EditorScript (which does not exist in export templates) out of the PCK.
- The GUT editor plugin is enabled only in the editor, and plugins never run in exports.
- `binary_format/embed_pck = true`, export with debug off.
- The exe icon: on the pinned version, check whether Editor Settings needs `rcedit` configured for the icon and metadata to embed. Check the icon on the first M0 export.

---

## 12. Art pipeline: greybox, then low-poly

### 12.1 Separation rule
- Every logic scene owns its script, collision, interaction body, markers, lights and audio. Art lives only under a child named `Visual`.
- **No gameplay script references a node inside `Visual`.** The ring light is a logic-owned `OmniLight3D`, not a mesh inside the art.
- `test_empty_visual.gd` instantiates every prop with `Visual`'s children removed and checks that interaction still works.

### 12.2 Greybox (M0-M5)
- **Office shell:** `CSGBox3D`/`CSGCombiner3D` with `use_collision = true` (until the M5 bake), about 14 x 10 m. It contains:
  - an entrance and reception area (intro, Dela Vega's static figure)
  - an open-plan area with 4-6 decor desks
  - the player's desk with the workstation and telephone, 8-10 m from the entrance
  - a closed manager-office door (decoration only)
- **Props:** `MeshInstance3D` with `BoxMesh`/`CylinderMesh`/`CapsuleMesh`. Colour code: interactables orange, walls light grey, floor dark grey, decor blue-grey, the figure a blue capsule. An optional `Label3D` tag during early playtests.
- **Dimensions locked at M1** (the contract for art; adjusted to existing models if 3.5 finds any): door 0.9 x 2.1 m, ceiling 2.8 m, desk height 0.75 m, monitor centre about 1.1 m and 0.55 m wide, eye height 1.6 m.
- **Greybox UI:** a default theme with flat `StyleBoxFlat`. Scripts never set styles directly, so the final `vigilant_theme.tres` drops in.

### 12.3 Low-poly (art track from M2, swap at M6)
1. **Blender:** 1 unit = 1 m. Apply transforms (Ctrl+A). Origin at the floor contact point. Front faces -Y in Blender, which becomes Godot's +Z (model front) after export. About 300-3,000 triangles per prop and about 15-25k for the shell.
2. **Materials:** one shared **256 px palette texture** with swatches of at least 16 px, and UV islands shrunk to the centre of their swatch. Most props get 1-2 materials and few draw calls. Flat shading. No LODs needed.
3. **Palette filtering:** in each extracted `StandardMaterial3D`, set `texture_filter = Nearest Mipmap` (or `Nearest`), because Godot 4 sets filtering per material, not on import. This stops neighbouring swatches bleeding at distance. If bleeding remains, disable mipmaps on the `palette.png` import.
4. **Export:** glTF 2.0 Binary (`.glb`), +Y up, apply modifiers, selection only, no cameras or lights, into `art/lowpoly/`. One `.glb` per prop plus `office_shell.glb`. Use `.glb`, not direct `.blend` import, so no teammate needs Blender configured in Godot.
5. **Collision:**
   - **Collision bake at M5 close**, in its own commit before the swap branch: select the greybox CSG root and use **Bake Collision Shape** (Godot 4.4+). Move the result into the logic-owned `Level/WorldCollision` (StaticBody3D, layer 1), then set `use_collision = false` on the CSG. From then on collision no longer depends on live CSG or on CSG visibility, and the swap deletes the CSG.
   - Alternative: `-colonly` boxes from `office_shell.glb`, moved into `WorldCollision`.
   - Prop collision is never taken from art.
6. **Import:** in Advanced Import Settings, extract materials to `art/materials/` and turn LOD generation off. Set Light Baking = Static Lightmaps for the shell (generates UV2) only if the optional `LightmapGI` bake is used.
7. **Wrapper scenes:** `art/wrappers/workstation_art.tscn` instances the `.glb`. Overrides go there, never inside the imported scene.
8. **Swap procedure:** in each logic scene, delete the greybox child of `Visual` and instance the wrapper. Collision, markers, scripts, lights and audio stay unchanged.
9. **Characters:** Dela Vega is one posed low-poly mesh with no rig, plus a 2D portrait for dialogue. Mr. Ramos is a portrait only. Black Veil is a logo on the Game Over screen and is named in text, never embodied.
10. **Budget:** the whole office under 60k triangles and under 20 materials, 60 fps at 1080p on the reference PC.

### 12.4 Art-swap acceptance check
- `git diff --stat` for the swap branch shows **no changes** in `autoload/`, `core/`, `data/` or any `.gd` file, and only `Visual` subtrees change in scenes. The collision bake is already merged before the branch starts.
- The full test suite passes, including `test_empty_visual.gd`.
- No palette bleeding when viewed from the far end of the office, so every material uses Nearest filtering. This is also part of each asset's 5-minute test swap.
- The performance budget holds.
- The full manual checklist passes again.

---

## 13. Testing and verification

**Framework:** GUT 9.x for Godot 4, pinned in `addons/gut/`. Tests run headless through `run_tests.bat` before every push:
```bat
@echo off
rem GODOT_BIN = the pinned CONSOLE executable (the GUI exe prints nothing to the console)
if "%GODOT_BIN%"=="" set GODOT_BIN=C:\Tools\Godot\Godot_v4.5.1-stable_win64_console.exe
rem 1) Import first: on a fresh clone .godot/ is missing, so class_name types and assets would not resolve
"%GODOT_BIN%" --headless --path . --import
rem 2) Run the suite
"%GODOT_BIN%" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
exit /b %ERRORLEVEL%
```
The default path matches `GODOT_VERSION`. Each teammate sets `GODOT_BIN` once if their install is elsewhere.

The content validator runs in two ways:
- as the GUT test `tests/content/test_chapter_data.gd`, headless with a SceneTree
- as an `@tool` EditorScript (`tools/validate_content.gd`) that writers run from the editor

### 13.1 Unit tests
- **`test_score_rules.gd`:**
  - pins `CORRECT == 10`, `WRONG == -5`, `UNSAFE == -5`, `CHAPTER_COMPLETE == 20`, so the paper's numbers cannot drift
  - `delta_for` maps each outcome correctly
- **`test_progress.gd`:**
  - the score carries across chapters
  - `complete_chapter` adds +20 once only (a second call is a no-op)
  - `restart_chapter()` restores `score_at_chapter_start`, trims that chapter's `score_log`, and is idempotent
  - `start_new_game()` resets everything
  - `all_complete()` is true only after 4 completions
  - chapters cannot complete out of order
- **`test_chapter_session.gd`:**
  - locked until every required inspection is recorded
  - WRONG returns STAYED and disables the option; picking it again returns IGNORED with no second penalty
  - CORRECT returns ADVANCED or COMPLETED
  - UNSAFE returns COMPROMISED
  - later steps are not gated
- **`test_clipboard.gd`:**
  - copy then paste emits `link_revealed:<id>`
  - pasting with an empty clipboard does nothing
  - `clear()` at chapter start
  - **cross-chapter:** after Ch1's link is copied and `DesktopUI.load_chapter(ch2)` runs, copying Ch2's link puts `c2_pay` in the clipboard exactly once (one `id_pressed` handler)
  - the OS clipboard is never read or written
- **`test_input_router.gd`:**
  - push and pop; `reset()` empties the stack and makes the mouse visible
  - ESC calls `on_exit` only when `esc_allowed`
  - ESC in `notice` calls Continue; ESC in `dialogue` advances; ESC in `panel` pops one level, back to `pause` or `menu`
  - ESC in `call` and `alert` does nothing except emit `esc_blocked`
  - **while paused:** with `get_tree().paused = true`, assert `InputRouter.can_process()`, feed an ESC event to `InputRouter._input()` directly, and assert `pause` was popped. The tree is unpaused in `after_each`, so the GUT runner never freezes
- **`test_scene_router.gd`:** a second `goto()` while busy is ignored; a missing path falls back to the main menu with a `push_error`; the fade's `mouse_filter` is IGNORE when idle.
- **`test_settings.gd`:** save and load round-trip on a temp path; values clamped; reset to defaults.
- **`test_url_format.gd`:** host extraction and bolding, with or without a scheme, with subdomains and lookalikes.

### 13.2 Content validator (`test_chapter_data.gd`) and immutability
- **Campaign shape:**
  - exactly 4 chapters, indices 1-4
  - `attack` order `[EMAIL_PHISHING, SMISHING, VISHING, BEC]`
  - triggers `[WORKSTATION, WORKSTATION, TELEPHONE, WORKSTATION]`
  - `ChapterData.AttackType.size() == 4`
- **Artifacts:** each chapter has exactly the artifact its attack needs: `email` for 1 and 4, `sms` for 2, `call_script` for 3, and no other.
- **Call steps:** a CALL-surface step in a chapter **with** a `call_script` uses it. A CALL-surface step in a chapter **without** a `call_script` (Ch4 step 2) has a non-empty `call_header`. `wait_for == TELEPHONE` appears only on a CALL-surface step, and that step has non-empty `wait_objective` and `trigger_prompt`.
- **Steps and choices:**
  - every step has at least 1 CORRECT, and every chapter has at least 1 UNSAFE
  - WRONG and UNSAFE have an empty `next_step`
  - every `next_step` resolves, every step is reachable from `steps[0]`, and every path ends in COMPLETED
  - choice and step ids are unique
- **Text:** every choice has feedback; every chapter has `debrief_lines`, warning signs, a tip, compromise text and bad-ending text.
- **Black Veil attribution:** `Campaign.intro`, every chapter's `debrief_lines`, every `compromise_text` and `Campaign.good_ending_lines` each contain the string "Black Veil".
- **Forbidden phrases** (case-insensitive scan of every text field in the campaign: labels, feedback, dialogue, bodies, page text): "login page", "log-in page", "sign-in page", "sign in page", "download", "attachment", "advertisement", "pop-up", "software update", "install", "usb", "malware", "virus". The list is a data constant in `ChapterValidator`. The manual content-review checklist (section 6) covers what a scan cannot catch.
- **Inspections:** every `required_inspections` entry can be produced by this chapter's content:
  - `sender` needs an email
  - `sender_number` needs an sms
  - `caller_id` needs a call_script
  - `link_revealed:X` needs a `LinkData` with id X in the chapter's message
- **Links:** every `[url=X]` in a body has a matching `LinkData`.
- **Pages:**
  - every `opens_page` exists
  - every `WebPageData` in `data/pages/` is referenced by at least one chapter
  - no scenario link's `real_url` host equals a page's host (malicious links are never real pages)
- **`test_content_immutable.gd`:** `ContentHash.of(campaign)` recursively serialises every stored property of the campaign and its sub-resources. Hash it, run the golden path plus one UNSAFE-then-restart through the director with stub UI, hash again, and assert the two are equal. A runtime write to any shared `.tres` fails the test.

### 13.3 Scoring truth table and playthroughs (`test_playthrough.gd`, parameterised from data)
The test drives `ChapterDirector` with stub UI and world nodes, feeding `interacted`, `inspection_done` and `choice_selected`. It enumerates every choice in every chapter from data, so new content is tested without new code.

| Case | Expected |
|---|---|
| Best path per chapter | Ch1 30, Ch2 40, Ch3 40, Ch4 40 |
| Golden path, whole game | Final score **150**; `completed == [T,T,T,T]`; Ending scene requested |
| Black Veil on the golden path | The FeedbackScreen text for **each** of the 4 chapters contains "Black Veil", and so do the intro and the Ending lines |
| Worst successful path per chapter (every WRONG first) | best - 5 x count(WRONG on that path): Ch1 20, Ch2 20, Ch3 25, Ch4 30 (total 95) |
| Every WRONG | Delta -5; same step; option disabled |
| Every UNSAFE | Delta -5; state `COMPROMISED` → `GAME_OVER`; chapter not completed |
| Gate | Choices are ignored until the required inspections are done |
| Ch4 telephone wait | After the step-1 CORRECT, choices cannot appear until `interacted(&"telephone")`; the workstation's `disabled_prompt` equals `wait_objective` |
| Order | Chapter n+1 never starts before n completes |

### 13.4 Integration tests
- **`test_unsafe_restart.gd`:**
  1. Complete Ch1 and Ch2 (score 70).
  2. In Ch3 pick a WRONG (65), then an UNSAFE (60). Assert the Compromise notice, then the Game Over screen.
  3. Press Restart. After the reload, assert that the score is 70, the current chapter is 3, the player is at `ChapterSpawn`, the clipboard is empty and the options are enabled again.
  4. Once the briefing dialogue finishes, assert the InputRouter stack is exactly `[world]` and the mouse is captured.
  5. Repeat the reload 10 times with no debugger errors.
- **`test_interaction.gd`:**
  - `Input.parse_input_event` presses W, and the player moves
  - facing the workstation within 2 m, E emits `interacted(&"workstation")`
  - with a wall between them, there is no prompt
  - while the player looks at the telephone, setting `enabled = false` changes the prompt within one physics frame to `disabled_prompt` with no "[E]". Setting it back to true restores "[E] …". Changing `prompt_text` while looking also refreshes the prompt
  - E on a disabled interactable emits nothing
- **`test_empty_visual.gd`:** each prop with `Visual` emptied still interacts.

### 13.5 Scope guard (`test_scope_guard.gd`)
**Static scan** of `.gd`, `.tscn` and `.tres` under `res://`, **excluding `res://tests/` and `res://addons/`**. The forbidden lists are data constants at the top of the test. It fails if any of these is found:
- **Networking, multiplayer and process APIs:** `HTTPRequest`, `HTTPClient`, `WebSocketPeer`, `WebSocketMultiplayerPeer`, `ENetMultiplayerPeer`, `ENetConnection`, `MultiplayerSpawner`, `MultiplayerSynchronizer`, `MultiplayerAPI`, `SceneMultiplayer`, `StreamPeerTCP`, `StreamPeerTLS`, `TCPServer`, `PacketPeerUDP`, `UDPServer`, `PacketPeerDTLS`, `DTLSServer`, `WebRTCPeerConnection`, `WebRTCMultiplayerPeer`, `JavaScriptBridge`, `OS.shell_open`, `OS.shell_show_in_file_manager`, `OS.execute`, `OS.execute_with_pipe`, `OS.create_process`, `OS.create_instance`, `OS.kill`.
- **OS clipboard:** `DisplayServer.clipboard_`.
- **NPC movement:** `NavigationAgent3D`.
- **Text-input and selectable-text controls:** any `LineEdit`, `TextEdit`, `CodeEdit`, `SpinBox` or `FileDialog` node or class reference; any `selection_enabled = true` or `context_menu_enabled = true`.
- **Writes:** `ConfigFile.save`, `.save(` on a ConfigFile, `ResourceSaver.save`, `DirAccess.` (any use), or `FileAccess.open` with `WRITE`, `READ_WRITE` or `WRITE_READ`, anywhere except `autoload/settings.gd`. `tools/` may read but not write.

**Runtime checks** in the same test:
- **Input map:** `InputMap.action_get_events(&"interact")` holds exactly one `InputEventKey` whose `keycode` or `physical_keycode` is `KEY_E` (69). `exit_interface` is exactly Escape. `move_*` are exactly W, S, A and D. No action is bound to F.
- **Selectable text:** instantiate every scene under `scenes/ui/`, plus `MainMenu`, `Ending` and `Office`. Walk the tree and assert that every `RichTextLabel` has `selection_enabled == false` and `context_menu_enabled == false`.
- **Interactables:** an instantiated `Office.tscn` contains exactly two nodes that are `Interactable`, with ids `workstation` and `telephone`.
- **Desktop:** `DesktopUI.tscn`'s `AppHost` children are exactly Mail, Messages and Browser.

The scan matches class and API names, not bare words like "multiplayer", to avoid false positives.

### 13.6 Manual QA and usability
- **Functional checklist per milestone,** mirroring FR1-10 and the evaluation form's Functionality items:
  - controls work; ESC exits every interface screen except call, compromise and game over
  - all 4 chapters can be reached and completed
  - score, feedback, game over, restart and endings are correct
  - settings persist
  - alt-tab in every context leaves no stuck cursor
  - 1366x768 and 1920x1080, windowed and fullscreen, with the same mouse-look feel
- **Traceability walkthrough:** check every row of section 4 by hand at M5 and M7.
- **Content review:** the section 6 checklist on all chapter text at M2 (Ch1) and M5 (all chapters).
- **Usability sessions** with 3-5 players aged 13+ in greybox (M5) and after the art swap (M7), think-aloud. Check that players find the inspection steps from the Instructions screen alone, that dialogue and choices are clear, and that players can say who was behind the attacks (Black Veil) at the end.
- **Performance:** exported release build on the reference PC, Profiler and Monitors. Steady 60 fps, and no frame over 50 ms when opening the desktop.
- **Offline:** launch and play the full game with the network unplugged.
- **Release build check:** debug helpers are unreachable (`OS.is_debug_build()` is false); the PCK contains no `tests/`, `addons/gut/` or `tools/` files; the exe icon is present.

---

## 14. Milestones (about 15 weeks; roles: Systems, Interface, Content & Art)

### 14.1 Calendar. PROPOSED — team to confirm before M0
The week numbers below count from kickoff. The team fills in fixed dates:

| Event | Date |
|---|---|
| Kickoff (week 1) | *team to supply* |
| Adviser sign-off of section 16 (before M2 starts, week 5) | *team to supply* |
| Phase 1 defense / first panel checkpoint | *team to supply* |
| Phase 2 defense | *team to supply* |
| External Google Forms evaluation sessions | *team to supply* |

Rules:
- M2 (the Ch1 vertical slice in an exported build) finishes **before** the first checkpoint the adviser or panel sees. If that checkpoint comes before week 7, M2 is cut down to fit, and M1's Pause menu and Settings persistence move after it.
- M7 finishes at least one week before the evaluation sessions.
- **If the window is shorter than 15 weeks**, cut in this order, decided at kickoff and not discovered at M5:
  1. the optional LightmapGI bake
  2. the low-poly office shell (keep the greybox shell, and swap only the workstation, telephone, desks and Dela Vega figure)
  3. the second usability session (keep the M5 session only)
  4. overlap M6 and M7

  Never cut a chapter, any Objective 1-7 feature, the scope guard, or the tests in 13.2 and 13.3.

### 14.2 Plan

| M | Weeks | Deliverables | Done when |
|---|---|---|---|
| **M0 Setup + risk spike** | 1-2 | Team inputs answered (language, Godot experience, evaluation PC and permission, calendar, existing material; 3.2-3.5, 14.1). Repo, LFS, pinned `GODOT_VERSION`, folder skeleton, autoload stubs, input map, `run_tests.bat` with `--import`, GUT headless, Windows export preset with exclude filter. Godot onboarding for anyone new. Spike on the four hardest parts: (1) FP controller + interaction ray + `Interactable` with a live prompt; (2) `InputRouter` with ESC, pause and alt-tab; (3) `RichTextLabel` link → DesktopUI-owned menu → `GameClipboard` → `AddressField` paste; (4) empty export running on the **reference PC** (renderer decided, exe allowed to run). Content & Art starts drafting all 4 chapter scripts from the existing material | Every teammate can **fresh-clone**, open, run `run_tests.bat` green and export. The empty export runs on the reference PC. The four spike items work in a throwaway scene |
| **M1 Walkable office + navigation** | 3-4 | Greybox office with locked dimensions; Workstation and Telephone props (`telephone.gd extends Interactable`); sit-down tween + empty desktop; telephone ring stub; `SceneRouter` with guard and fallback; Main Menu, Instructions, Settings (persisted), Pause with `panel` sub-contexts; HUD prompt | Objective 1 (except the call) and Objective 2 shown; `test_interaction.gd`, `test_input_router.gd`, `test_scene_router.gd` and `test_settings.gd` green |
| **M2 Chapter 1 vertical slice (MVP)** | 5-7 | Data schema, `Campaign`, Ch1 `.tres` (structure from section 6, wording from existing scripts), intro naming Black Veil; `ScoreRules`, `Progress`, `ChapterSession`, `ChapterDirector`; validator test; DialoguePanel; MailApp (sender reveal, link menu); BrowserApp (paste-only field, inspection view, directory page); DecisionBar gate; Outcome panel; Compromise notice; Game Over with restart rollback; Feedback screen with debrief lines; Good Ending (dev campaign holds only Ch1); HUD score and progress | In an **exported Windows build**, a tester plays Ch1 three ways (best, with wrong choices, unsafe then restart) and sees the right score each time. Objectives 1-7 each have a working path (telephone interaction still a stub). Unit, truth-table and immutability tests green. Content review of Ch1. **Demo to the adviser**, and section 16 signed |
| **M3 Chapter 2: Smishing** | 8 | MessagesApp (sender number reveal, link menu); courier page; Ch2 `.tres` | Ch1 flows into Ch2; score carries over; cross-chapter clipboard test green; Ch2 truth table green |
| **M4 Chapter 3: Vishing** | 9-10 | Telephone ring (3D audio + logic light); Call UI (caller ID, phone card, transcript, choices, ESC hint); ESC blocked in calls; post-call step; Ch3 `.tres` | Objective 1 fully met (telephone); Ch1-3 play through in order |
| **M5 Chapter 4 + content-complete greybox alpha** | 11 | Ch4 `.tres`; Reply-To reveal; directory page from a choice; `AWAIT_STEP_TRIGGER` + outgoing call to Mr. Ramos; final dialogue, debriefs, warning signs and tips; **collision bake commit** (12.3) | `test_playthrough` (150, Black Veil per chapter) and `test_unsafe_restart` green; `test_scope_guard` green; content review of all chapters; section 4 walkthrough signed by all three; first usability session held. **Feature freeze:** after M5 only art, audio, wording and bug fixes |
| **Art track (parallel)** | 4-12 | Blender props in priority order: workstation, telephone, desks and chairs, office shell, Dela Vega figure, portraits; `.glb` + wrappers with Nearest-filtered palette materials; final UI theme and fonts | Each asset passes a test swap in under 5 minutes, with no palette bleeding |
| **M6 Low-poly swap** | 12-13 | All `Visual` slots swapped; shell; optional LightmapGI bake; final theme | The art-swap check (12.4) passes; 60 fps on the reference PC |
| **M7 Polish + release candidate** | 14-15 | SFX (ring, pickup, alert, clicks, blips); wording fixes from the second usability session; bug fixing; release export (embedded PCK, exclude filter, icon); offline test on the evaluation machines | No known blocker or major bugs; build tagged and handed over for the external Google Forms evaluation |

---

## 15. What is left to the builder

These are deliberately open. Decide them without asking the team, as long as section 2's anti-goals and section 4's traceability still hold:
- **Wording:** the final dialogue, feedback, debrief and tip wording, from the content writer's drafts. Keep the gist, the Black Veil attribution and the classifications in section 6. A choice's outcome class changes only with team sign-off.
- **Look:** the visual style of the UI theme, wallpaper, the Aegis and Black Veil logos, portraits, and fonts (any OFL sans plus a monospace with clear `l`/`1`/`0`/`O`).
- **Timings and feel:** tween durations, typewriter speed, compromise-notice length (2-3 s), walking speed (3-3.5 m/s), sensitivity scaling.
- **Layout:** the exact office floor plan inside 12.2's constraints (two interactables, desk 8-10 m from the entrance, a static Dela Vega figure at reception).
- **Code structure:** the internal decomposition of UI scenes, helper scripts and private methods, and whether `ChoiceList` uses `Button` or a themed variation (always `FOCUS_NONE`).
- **Audio:** sound choice and mixing (one Master bus is enough).
- **Versions:** the exact GUT version that matches the pinned Godot version.
- **Performance:** optimisation choices that keep the budget (occlusion, baked vs dynamic lights).
- **Dev tooling:** debug-only tooling (chapter jump through a command-line flag, state overlay), as long as it is gated behind `OS.is_debug_build()` and lives outside `tests/` and `tools/` only if it is needed at runtime.

The builder must **not**:
- add screens, apps, pages, interactables, chapters, endings, characters in 3D, desktop messages, text inputs or persistence beyond what sections 6 and 9 list. The Pause menu is built as the PROPOSED default and removed if the team rejects it.
- change the scoring values
- render any page for a malicious link, or write content about login pages, downloads, attachments, ads or updates

---

## 16. Decisions for the team to confirm

**Who decides and when.**
- The recommendations below are the **working default**, and the builder builds them now.
- **Before M0 (week 1):** the team and adviser confirm #1 and #2, plus the team inputs in 3.3, 3.5 and 14.1.
- **Before M2 starts (week 5):** the adviser signs off this whole section. The decisions that shape the architecture are then **locked**: #4, #5, #6, #7, #10, #11, #12, #13 and #17. The M2 vertical slice hard-codes the gate, the restart rollback, the link-click behaviour, the ESC rules and the Game Over/bad-ending merge, so reversing any of them after M2 touches the director, Progress, the tests and the Ch4 data.
- **The panel** sees the confirmed answers at the Phase 1 defense. The team passes the confirmed answers (in particular #1, #6, #7, #8, #12 and #21) to the colleague revising the paper, so that the build and the paper match. This document does not plan the paper edits.

| # | Decision | Recommendation (this document) | Alternative | Lock by |
|---|---|---|---|---|
| 1 | Language | Typed GDScript (the paper says C#), standard Godot build, GUT | C# with the Godot .NET build + gdUnit4Net; never mix | Week 1 |
| 2 | Godot version | Latest 4.x stable at kickoff (4.5+), pinned exact patch | — | Week 1 |
| 3 | Renderer | Forward+, decided after the M0 reference-PC test | Compatibility if the GPU struggles | End of M0 |
| 4 | (a) WRONG vs UNSAFE | Attacker's goal achieved = UNSAFE (game over); not achieved but not the protocol = WRONG (-5, option disabled, stay) | — | Before M2 |
| 5 | UNSAFE points | -5 (a wrong action under FR7), rolled back on restart | 0 (only the game over) | Before M2 |
| 6 | (b) Bad ending vs restart | The Game Over screen *is* the bad ending, with Restart Chapter / Main Menu | Show the bad ending only when the player leaves to the Main Menu | Before M2 |
| 7 | (c) Score on restart | Roll back to the chapter-start snapshot | Keep the failed attempt's points | Before M2 |
| 8 | (d) Settings | Mouse sensitivity, master volume, display mode, reset | — | Before M2 |
| 9 | (e) Web pages | Paste-only inspection view + SwiftParcel official page + Aegis Staff Directory; no navigation; malicious links never render | — | Before M2 |
| 10 | Link clicks | Left/right click only opens "Copy link address"; opening the link is only the UNSAFE choice button | Left-click = UNSAFE "open link" (GDD "clicking malicious content") | Before M2 |
| 11 | Inspection gate | Choices locked until the required inspections are done | Choices always open (inspection optional) | Before M2 |
| 12 | Pause menu | ESC in free walk opens Resume / Instructions / Settings / Main Menu, nothing more. Trace: Scope 2 "access to instructions and settings" + NFR1 | **Strict-scope alternative:** no pause menu. ESC in the world does nothing, Instructions and Settings are reachable only from the Main Menu, and a session ends only from Game Over, the Ending, or closing the window | Before M2 |
| 13 | ESC exceptions | ESC exits every interface screen (dialogue advances one line; Outcome/Feedback = Continue; panels go back one level; desktop stands up), except: Call UI (hang-up is a scored choice; shows "Choose a response"), Compromise notice (2.5 s) and Game Over (explicit Restart/Menu choice) | Also block ESC on dialogue | Before M2 |
| 14 | Score floor | None | Floor at 0 | Before M5 |
| 15 | Ch1 structure | One step; Report and Delete both CORRECT (GDD "reports or deletes") | A second "report" step for all chapters (max 160) | Before M2 |
| 16 | Ch2 "Ignore it" | WRONG (the GDD expects verification) | CORRECT but incomplete | Before M3 |
| 17 | Ch4 verification | Directory lookup, then a desk-phone call to Mr. Ramos's known extension (`AWAIT_STEP_TRIGGER`) | Verification as a single choice with no phone step | Before M2 |
| 18 | Welcome email | **Remove it.** The inbox holds only the chapter's scenario email, and the Staff Directory is the real-domain reference | Keep one static email signed "Ms. Dela Vega, Security Office" (no invented first name), with a validator rule that no non-chapter message has links or choices | Before M2 |
| 19 | Characters | Dela Vega: static figure at reception during the intro, then intercom portrait; not interactable. Mr. Ramos: portrait or voice only, shown as "R. Ramos". Black Veil: never embodied; named in the intro, every debrief, every compromise text and the good ending | — | Before M2 |
| 20 | Placeholders | All names, `.example` domains, masked numbers and the amount (PHP 248,000) in section 6 | The writer's own fictional set, still non-real | Before M2 |
| 21 | Settings persistence vs Limitation 6 | Preferences are not progress, so a local `settings.cfg` is allowed | Session-only settings, no file at all | Before M2 |
| 22 | Content authority | Section 6 is authoritative for structure; the existing pre-production scripts supply the wording; conflicts are raised before Ch1's `.tres` (3.5) | The existing scripts are authoritative, and section 6 and the tests are updated to match | Before M2 |
