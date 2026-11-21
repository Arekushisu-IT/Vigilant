# Vigilant: "more tasks per chapter" build spec (TASKS-SPEC.md)

Single source of truth for the four builders. Where this file and `CONTRACT.md` differ, **this file wins** for the
items listed here; everything else in `CONTRACT.md` (Godot 4.7.2, static typing, tabs, UIStyle, nodes built in code,
greybox `Visual`/`Collision`, the "never use / never add" lists, the input and mouse rules) still applies unchanged.

**Top rule (non-negotiable): the paper's Objectives 1-7 and its scope.** Still exactly **four scripted chapters in a
fixed order** (email phishing, smishing, vishing, BEC: Objective 4, Scope module 4, Limitation 3, GDD 13). Every new
task lives **inside** one of these four chapters and uses **the same attack type** as its chapter. No new attack types,
no adaptive/random content, no typing, no OS clipboard, no saving, no online, no new endings, no timers.

Scoring is unchanged (FR7, GDD 9): **+10** correct action, **-5** wrong action, **+20** per completed chapter (= the
chapter's scenario, once), score carries across chapters. One **unsafe** choice = compromise notice + game over (bad
ending) with Restart Chapter (score rolls back to the chapter start) / Main Menu.

Computed from the data in section B (verify with `Game.max_score()`):

| | Ch1 | Ch2 | Ch3 | Ch4 | Total |
|---|---|---|---|---|---|
| Items (inbox/phone entries) | 4 | 4 | 4 | 4 | 16 |
| HUD tasks (`task_count()`) | 5 | 6 | 6 | 6 | 23 |
| Correct decisions in a best run | 6 | 6 | 6 | 6 | **24** |
| **Best-run (max) score** | 80 | 80 | 80 | 80 | **320** |
| Wrong decisions in a wrong-first run | 10 | 12 | 10 | 11 | 43 |
| **Every-wrong-first score** | 30 | 20 | 30 | 25 | **105** |

Every correct path through an item has the same number of decisions, so **every flawless run scores 320**, whichever
correct route the player takes (Ch1: verify with HR first or report straight away; Ch3: call IT back or report straight
to Security). There is no "shorter correct path" that loses points.

---------------------------------------------------------------------------------------------------------------------

## A. Data model

### A.1 Chapter (changes from today in **bold**)

```
id, title, device, app, briefing, objective, debrief, warning_signs, tip, bad_ending   # same meaning as today
"hint_level": "full" | "generic" | "none"                                              # NEW (difficulty ramp)
"items": Array[Dictionary]                                                             # NEW, replaces message / call / steps / required_inspections
```

- `device` keeps its meaning for Restart Chapter aiming (where the chapter's first item lives): Ch3 `"telephone"`, the others `"workstation"`.
- `app` is the chapter's main channel (`"mail"`, `"messages"`, `"call"`).
- `warning_signs`, `tip`, `bad_ending`, `debrief` stay chapter-level and describe the **main attack**. An item may override `warning_signs`, `tip`, `bad_ending` for the game-over screen when the unsafe choice happened in that item.
- The keys `message`, `call`, `steps`, `required_inspections` are **removed from the chapter** and live in items.
- `Campaign.MAX_SCORE` is **removed in the merge step** (C.1), once `ending.gd` no longer reads it; the max is computed (`Game.max_score()`).

### A.2 Item (one inbox entry, text thread or phone call = one task, possibly with sub-tasks)

| Key | Type | Meaning |
|---|---|---|
| `id` | String | Unique in the whole campaign, e.g. `"c1_benefits"` |
| `role` | String | `"genuine"`, `"fake"`, `"main"` (exactly one per chapter: the paper's GDD 8 scenario) or `"coworker"`. Shown only after the chapter (feedback screen). |
| `kind` | String | `"email"`, `"sms"`, `"call"` or `"coworker"` |
| `app` | String | Where it lives: `"mail"`, `"messages"` (desktop) or `"call"` (desk phone) |
| `task` | String | HUD / feedback label. **Neutral wording**: never says "fake", "real", "scam", never quotes the message's content and contains **no quote characters** (`'`, `"`, `’`). It is shown before the item is opened, so it may only say where the item is and in what order it came (e.g. "Check the first courier text", "Answer the second call"). |
| `unlock_after` | Array[String] | Item ids that must be **resolved** before this item appears. `[]` = available at chapter start |
| `required_inspections` | Array[String] | Gate on the item's **step 0** (see A.5) |
| `message` | Dictionary | For `email`, `sms`, `coworker` (A.3) |
| `call` | Dictionary | For `call` (A.3) |
| `steps` | Array[Dictionary] | At least one (A.4) |
| `bad_ending`, `warning_signs`, `tip` | optional | Game-over overrides for an unsafe choice in this item |

Item order in the data is the order in the inbox / thread list and the ring order; the genuine item is **not** always
first (Ch1 and Ch3 first, Ch2 second, Ch4 third). `time` values ascend in data order within an app.

### A.3 Content shapes

Email (`app = "mail"`): `time, from_name, from_addr, reply_to, to, subject, body, links` (same as today plus `time`, e.g. `"08:47"`).

SMS (`app = "messages"`): `time, sender_label, sender_number, sender_info, body, links` (same as today plus `time`).

Coworker (`kind = "coworker"`): an email or SMS shape **plus** `quote`:
```
"quote": {
	"label": "Forwarded message",          # small heading of the quoted block
	"details": [String, ...],              # monospace lines hidden until inspected ("quote")
	"body": String,                         # BBCode, may contain [url=<id>]..[/url]; its ids are in message.links
}
```

Call (`app = "call"`): `caller_id, caller_id_info, caller_name, lines` (same as today's `chapter.call`).

Body links: `[url=<link id>]text[/url]`; the real URL is in `message.links[<link id>]`. **Link ids are unique in the
whole campaign and never equal an item id** (the session uses them to find the owning item; logs stay unambiguous).

Always read these keys with `.get("call", {})` / `.get("message", {})`, never `item.call` (`.call` on a Dictionary
Variant is ambiguous).

### A.4 Steps

Common keys: `surface` (`"desktop"` | `"call"`), `question`, optional `kind` (`"choices"` default | `"checklist"`),
optional `task` (sub-task label, A.7), optional `wait_for` (`"telephone"`) + `wait_objective` + `trigger_prompt`,
optional `call_header`, optional **`call_name`** (NEW: the name shown for the person on the line, e.g. `"HR"`,
`"Security Office"`; used instead of parsing `call_header`), optional `call_lines`.

`kind = "choices"`: `choices: Array[Dictionary]`, each
`text, outcome ("correct" | "wrong" | "unsafe"), feedback`, optional `next_step: int` (a correct choice without it **resolves the item**),
`opens` (`"courier"` | `"directory"`), `response_line` (shown in the outcome panel for any outcome, as today; on a wrong
choice during an open call it is also added to the transcript), `compromise` (unsafe only; must name Black Veil).

`kind = "checklist"` (NEW):
```
{
	"surface": "desktop" | "call",
	"kind": "checklist",
	"task": "Report its warning signs",
	"question": "Report to Security: tick every warning sign in the benefits email.",
	"submit_text": "Submit report",
	"options": [ {"text": String, "real": bool, "why": String}, ... ],   # 6-8 options: the real signs + 2-3 decoys
	"feedback": String,                                                  # shown on a correct submit
	# optional "next_step": int  (none in this campaign: every checklist resolves its item)
}
```
Submit is **correct (+10)** only if the ticked set equals exactly the set of `real` options. Otherwise **wrong (-5)**:
the feedback explains each **ticked decoy** by name with its `why`, but gives only the **number** of missed real signs
(A.4 feedback format in C.2). The ticks stay and the player tries again. Submit is disabled while nothing is ticked,
while **every** box is ticked (hint "Tick only the real warning signs."), and for a set already submitted wrong. A
checklist never has an unsafe outcome. The full list of warning signs with explanations is on the chapter feedback
screen (FR9).

**Data invariants** (the smoke test checks every one in scenario (i)):
1. Every `choices` step has at least one correct choice; **the first correct choice in list order lies on a longest correct path** (so "first correct everywhere" = the max score). In this campaign every correct path of an item has the same length.
2. `genuine` items have no unsafe choice and exactly 4 choices; any choice whose lowercase text contains `"report"`, `"delete"` or `"block"` is `wrong`.
3. Every `compromise`, `bad_ending` and `debrief` contains `"Black Veil"`.
4. Within a chapter, the items that have any `call`-surface step form a chain: each one transitively `unlock_after`s the previous one in data order (so at most one call is ever pending).
5. Every `unlock_after` id is an earlier item of the same chapter. Every `link:<id>` key exists in that item's `links`. Link ids are unique campaign-wide and differ from every item id.
6. Every match of `(?i)\b[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}\b(?!@)` in any string ends in `.example` (the `(?!@)` skips the local part of an email address such as `r.ramos@`). No string matches `(\+63|\b0)9\d`, and no string has 7 or more consecutive digits once spaces and dashes are removed.
7. No forbidden phrase anywhere (design doc 13.2 list), case-insensitive: "login page", "log-in page", "sign-in page", "sign in page", "download", "attachment", "advertisement", "pop-up", "software update", "install", "usb", "malware", "virus".
8. Every `next_step` is greater than its own step index and less than `steps.size()` (else `Game.item_max` would recurse forever).
9. Step 0's surface matches the item's app: `app == "call"` <-> step 0 `surface == "call"`.
10. A `call` step that can be entered from a `desktop` step has `wait_for: "telephone"`.
11. Every step carrying `task` lies on **every** correct path of its item (no skippable task steps).
12. Every checklist has 6-8 options, at least 2 `real` and at least 2 decoys (`real: false`).
13. No `item.task` or `step.task` contains `'`, `"` or `’`.
14. `required_inspections` equals, as a set: the sender key (`"sender"` for mail, `"sender_number"` for messages, `"caller_id"` for calls) + `"quote"` for coworker items + `"link:<id>"` for every id in the item's `links`. This is exactly the rule stated in HOW TO PLAY (C.13).

### A.5 Inspection keys and the gate

Keys: `"sender"` (mail items: reveals from_addr + Reply-To), `"sender_number"` (messages items: reveals number + info),
`"caller_id"` (call items, step 0), `"link:<id>"` (set when that link is pasted in the Browser), **`"quote"`** (NEW,
coworker items: reveals the forwarded message's `details`).

Inspections are stored **per item**. `mark("link:<id>")` is credited to the item that owns that link id (whichever item is
selected); every other key is credited to the selected item. Only **step 0** of an item is gated by its
`required_inspections` (same rule as today, per item).

Hint text while the gate is closed (`ChapterSession.gate_hint()`):
- `full` (Ch1): `"Inspect first: "` + the display names of **`missing()`** (so the list shrinks as you inspect), in `required_inspections` order, joined with `", "`. Names: `sender`, `sender number`, `caller ID`, `forwarded message details`, `link (copy it and paste it in the Browser)`.
- `generic` (Ch2, Ch3): `"Inspect before you decide."`
- `none` (Ch4): `"Responses locked."` (fixed and non-specific, so the locked buttons look deliberate; it never says what to inspect).

When the gate is open the hint is `"Choose a response."` at every level. On a checklist step the hint is
`session.checklist_hint()` (C.2) in both UIs.

### A.6 Order rules and "chapter complete"

- An item is **available** when every id in its `unlock_after` is resolved. Available items stay listed after they are resolved (shown with a tick).
- All available desktop items can be worked in any order; the player switches between them freely; each keeps its own step, inspections, disabled choices and checklist ticks.
- Call items ring one at a time (invariant 4). **The phone rings** while `phone_incoming()` is true: an available, unresolved call item is at **step 0** (which has no `wait_for`) and the call UI is not open. A call never closes mid-item except through resolving the item, the advance-to-desktop path (A.8) or a compromise.
- A desktop item whose current step has `wait_for: "telephone"` enables the telephone (prompt = `trigger_prompt`); the player may work other desktop items meanwhile.
- An item is **resolved** by a correct choice without `next_step`, or a correct checklist submit without `next_step`.
- **Chapter complete** = every item of the chapter is resolved. Then +20 (once), the feedback screen, and the next chapter (or the good ending after Ch4).
- An unsafe choice in **any** item ends the chapter (compromise, game over); Restart Chapter replays the whole chapter from its start score.

Per-chapter order (from the data):

| Ch | At start (data / list order) | Unlocks later |
|---|---|---|
| 1 | `c1_orientation` (genuine), `c1_benefits` (main), `c1_voucher` (fake) | `c1_coworker` after `c1_benefits` |
| 2 | `c2_redeliver` (main), `c2_delivery` (genuine), `c2_access` (fake) | `c2_coworker` after `c2_redeliver` |
| 3 | `c3_facilities` (genuine call) | `c3_mark` (main call) after `c3_facilities`; then `c3_security` (fake call) **and** `c3_coworker` (Messages) after `c3_mark` |
| 4 | `c4_supplier` (main), `c4_giftcards` (fake), `c4_policy` (genuine) | `c4_coworker` after `c4_supplier` |

### A.7 Tasks (Objective 7 tracking)

For each item: if none of its steps has a `task` key, the item is one task (`item.task`, done when the item is resolved).
Otherwise the item contributes one task per step that has `task`:
- a step task is **listed** once the item is unlocked and its current step index is >= that step's index (so later sub-task labels never give the answer away);
- it is **done** when the item is resolved, or when the item's current step index is >= the index of the **next** step after it that carries a `task` (a step without `task` in between, such as an extra call, belongs to the task before it).

`task_count()` counts every task of every item, locked or not (5 + 6 + 6 + 6 = 23). `tasks_done()` is the number of
`done` entries in `task_list()`. The HUD shows `"Tasks D/T"` plus the listed tasks with ticks.

### A.8 The exact shape: one full item (Chapter 1 main attack)

```gdscript
{
	"id": "c1_benefits",
	"role": "main",
	"kind": "email",
	"app": "mail",
	"task": "Check the benefits email",
	"unlock_after": [],
	"required_inspections": ["sender", "link:c1_portal"],
	"message": {
		"time": "08:47",
		"from_name": "Aegis HR Benefits",
		"from_addr": "hr-benefits@aegis-solutions-hr.example",
		"reply_to": "",
		"to": "you@aegis-solutions.example",
		"subject": "ACTION REQUIRED: Confirm your benefits within 24 hours",
		"body": "Dear Employee,\n\nOur records show your benefits enrollment is incomplete. You must confirm your benefits enrollment within 24 hours or your coverage will be canceled.\n\nUse the secure link below:\n[url=c1_portal]Aegis Benefits Portal[/url]\n\nThank you,\nHR Benefits Team",
		"links": {"c1_portal": "http://aegis-benefits-verify.example/confirm?emp=2291"},
	},
	"steps": [
		{	# 0
			"surface": "desktop",
			"task": "Check the benefits email",
			"question": "What will you do with this email?",
			"choices": [
				{"text": "Reply to ask HR if it is real", "outcome": "wrong",
					"feedback": "Replying goes to the sender, who will say yes. Check through a contact you already know."},
				{"text": "Look up HR in the Staff Directory and call their extension", "outcome": "correct", "next_step": 1, "opens": "directory",
					"feedback": "Use contact details you already trust, not the ones in the email. HR's extension is in the Staff Directory."},
				{"text": "Report it to Security as phishing now", "outcome": "correct", "next_step": 2,
					"feedback": "The evidence is enough to report: a lookalike sender and a link to an outside site. Calling HR on ext. 1300 would also have confirmed it."},
				{"text": "Forward it to a coworker to ask", "outcome": "wrong",
					"feedback": "Forwarding spreads the link to someone who may click it."},
				{"text": "Open the link and confirm your benefits details", "outcome": "unsafe",
					"feedback": "The link led to Black Veil, not HR.",
					"compromise": "Your employee details were sent to Black Veil."},
			],
		},
		{	# 1: the HR call (verify path)
			"surface": "call",
			"wait_for": "telephone",
			"wait_objective": "Call HR on ext. 1300 using your desk phone",
			"trigger_prompt": "Call HR (ext. 1300)",
			"call_header": "EXT 1300: HR",
			"call_name": "HR",
			"call_lines": [
				"HR here. No, we didn't send that. Benefits enrollment is done in person at your orientation.",
				"Please don't click anything in it.",
			],
			"question": "HR never sent it. What do you do with the email?",
			"choices": [
				{"text": "Report it to Security as phishing", "outcome": "correct", "next_step": 3,
					"feedback": "Reporting lets Security warn everyone and block the sender. File the report at your desk."},
				{"text": "Leave it in the inbox for now", "outcome": "wrong",
					"feedback": "Leaving it there keeps the link one click away, and nobody else gets warned."},
				{"text": "Delete the email", "outcome": "correct", "next_step": 3,
					"feedback": "Safe: you did not engage. Security still needs a report so they can warn others. File it at your desk."},
			],
		},
		{	# 2: the email itself (report path; same number of decisions as the verify path)
			"surface": "desktop",
			"question": "Security has your report. What will you do with the email itself?",
			"choices": [
				{"text": "Keep it in the inbox in case HR asks about it", "outcome": "wrong",
					"feedback": "Leaving it there keeps the link one click away. Security already has everything it needs."},
				{"text": "Delete the email", "outcome": "correct", "next_step": 3,
					"feedback": "Right. Security has the report, so the email can go. Now list its warning signs for them."},
				{"text": "Forward it to HR so they know about it", "outcome": "wrong",
					"feedback": "Forwarding spreads the live link. Security warns HR and everyone else safely."},
			],
		},
		{	# 3
			"surface": "desktop",
			"kind": "checklist",
			"task": "Report its warning signs",
			"question": "Report to Security: tick every warning sign in the benefits email.",
			"submit_text": "Submit report",
			"options": [
				{"text": "The sender's domain is aegis-solutions-hr.example, not aegis-solutions.example", "real": true,
					"why": "Real HR mail comes from @aegis-solutions.example."},
				{"text": "It was sent to your work address", "real": false,
					"why": "Every work email is. That tells you nothing."},
				{"text": "A generic greeting: \"Dear Employee\"", "real": true,
					"why": "HR knows your name."},
				{"text": "A 24-hour deadline with a threat to cancel your coverage", "real": true,
					"why": "Pressure is meant to stop you from checking."},
				{"text": "It is about benefits enrollment, a real new-hire task", "real": false,
					"why": "Attackers pick believable topics. The topic alone is not evidence."},
				{"text": "The link's real address is aegis-benefits-verify.example, not an Aegis site", "real": true,
					"why": "The domain right before the first single slash decides where a link goes."},
				{"text": "It arrived during office hours", "real": false,
					"why": "Real and fake emails arrive at any time."},
			],
			"feedback": "Report filed. Security blocked aegis-solutions-hr.example and warned all staff.",
		},
	],
}
```

Flow of this item: inspect sender + paste link -> step 0. Two correct routes, each three decisions (30 points):
- **Verify route**: Directory choice (opens the Staff Directory in the Browser) -> the DecisionBar shows "Call HR on ext. 1300 using your desk phone", the telephone is enabled -> E on the phone opens the Call UI with step 1's lines -> correct -> the call closes, the camera turns back to the monitor and the desktop opens **on the Mail app with this item selected**, showing the checklist (step 3). The Browser keeps the Directory page for when the player clicks the Browser rail button.
- **Report route** (GDD 8: "checks the sender and the full link address, then reports or deletes the message"): Report now -> step 2 (delete it) -> step 3.

A correct submit resolves the item and unlocks `c1_coworker`. HUD tasks of this item: "Check the benefits email" (done
on reaching step 3) and "Report its warning signs".

---------------------------------------------------------------------------------------------------------------------

## B. Complete content (paste into `data/campaign.gd`)

`INTRO` and `SECURITY` stay exactly as today. `MAX_SCORE` stays until the merge step (C.1), then is deleted.
`PHONE_CARD` becomes (the same extensions as the Staff Directory, so Ch3 has the evidence on the device itself):

```gdscript
const PHONE_CARD: Array[String] = [
	"IT Helpdesk: ext. 1100",
	"Security Office: ext. 1200",
	"HR: ext. 1300",
	"Facilities: ext. 1400",
]
```

Add (phase 0 writes this function; see C.1):

```gdscript
static func item(n: int, id: String) -> Dictionary:
	for it: Dictionary in chapter(n).get("items", []):
		if it.id == id:
			return it
	return {}
```

Update the key reference comment at the top of the file to describe A.1-A.5.

### B.1 Shared pages and the ending

```gdscript
const GOOD_ENDING: Array[String] = [
	"You stopped every one of Black Veil's attempts this week: the fake HR, voucher and payroll emails, the courier and 'IT' texts, the fake IT and Security calls, and the fake payment requests.",
	"You handled the real messages normally and helped four coworkers stay safe.",
	"You've passed the Vigilant Protocol. Welcome to Aegis Solutions.",
]

const PAGES := {
	"directory": {
		"title": "Aegis Intranet: Staff Directory",
		"url": "https://intranet.aegis-solutions.example/directory",
		"columns": ["Name", "Department", "Email", "Extension"],
		"rows": [
			["HR", "Human Resources", "hr@aegis-solutions.example", "1300"],
			["IT Helpdesk", "Information Technology", "it.helpdesk@aegis-solutions.example", "1100"],
			["Ms. Dela Vega", "Security Office", "security@aegis-solutions.example", "1200"],
			["Facilities", "Facilities", "facilities@aegis-solutions.example", "1400"],
			["Office of the CEO", "Executive", "ceo.office@aegis-solutions.example", "2000"],
			["R. Ramos", "Management", "r.ramos@aegis-solutions.example", "2045"],
			["Sales team", "Sales", "sales.team@aegis-solutions.example", "2110"],
			["Admin team", "Administration", "admin.team@aegis-solutions.example", "2120"],
			["Marketing team", "Marketing", "marketing.team@aegis-solutions.example", "2130"],
			["Finance team", "Finance", "finance.team@aegis-solutions.example", "2140"],
		],
		"lines": [
			"Supplier on file (kept by Finance): Kestrel Office Supplies, accounts@kestrel-supplies.example, phone 09XX-XXX-5600.",
		],
	},
	"courier": {
		"title": "SwiftParcel: Aegis Solutions business account",
		"url": "https://www.swiftparcel.example/track",
		"lines": [
			"Parcel SP-4417 (welcome kit): Out for delivery today, 13:00-17:00. No fees due.",
			"Parcel SP-9902 (Admin team): Delivered yesterday. No fees due.",
			"SwiftParcel never asks for payment by text message, and never texts from a mobile number.",
		],
	},
}
```

### B.2 `CHAPTERS` (final wording, American spelling throughout)

```gdscript
const CHAPTERS: Array[Dictionary] = [
	# ======================================================================== Chapter 1: Email Phishing
	{
		"id": 1,
		"title": "Email Phishing",
		"device": "workstation",
		"app": "mail",
		"hint_level": "full",
		"briefing": [
			{"speaker": SECURITY, "text": "Chapter 1. HR is contacting new hires about orientation and benefits this week. Check your inbox."},
			{"speaker": SECURITY, "text": "Not every email is an attack. Handle real ones normally, and report or delete the fakes."},
			{"speaker": SECURITY, "text": "If something looks off, check with the sender through the Staff Directory, never through the email itself."},
		],
		"objective": "Check your email at your workstation",
		"items": [
			{
				"id": "c1_orientation",
				"role": "genuine",
				"kind": "email",
				"app": "mail",
				"task": "Check the orientation email",
				"unlock_after": [],
				"required_inspections": ["sender", "link:c1_agenda"],
				"message": {
					"time": "08:31",
					"from_name": "Aegis HR",
					"from_addr": "hr@aegis-solutions.example",
					"reply_to": "",
					"to": "you@aegis-solutions.example",
					"subject": "Your orientation: Thursday 10:00, Meeting Room 2",
					"body": "Hi,\n\nWelcome to Aegis Solutions! Your new-hire orientation is on Thursday at 10:00 in Meeting Room 2.\n\nWe will do your benefits enrollment together there, so there is nothing to fill in online before then.\n\nThe agenda is on the intranet:\n[url=c1_agenda]Orientation agenda[/url]\n\nSee you Thursday,\nHR (ext. 1300)",
					"links": {"c1_agenda": "https://intranet.aegis-solutions.example/hr/orientation"},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "What will you do with this email?",
						"choices": [
							{"text": "Report it to Security as phishing", "outcome": "wrong",
								"feedback": "This one is real: it comes from hr@aegis-solutions.example and its link stays on intranet.aegis-solutions.example. Reporting is never dangerous, but here the evidence showed it was genuine. Treat real mail as real."},
							{"text": "Open the agenda link and keep the email for Thursday", "outcome": "correct",
								"feedback": "Right. The sender and the link are both real Aegis addresses, the link goes to the intranet, and it asks for nothing. Keep it."},
							{"text": "Delete it to be safe", "outcome": "wrong",
								"feedback": "This one is real, and deleting it loses your orientation details. The sender and the link were genuine Aegis addresses: the evidence showed it was safe."},
							{"text": "Forward it to IT and ask them to check it", "outcome": "wrong",
								"feedback": "The evidence already showed it was genuine: hr@aegis-solutions.example and an intranet link. Use what you inspected instead of passing it on."},
						],
					},
				],
			},
			# c1_benefits: exactly the item in section A.8 (copy it here unchanged).
			{
				"id": "c1_voucher",
				"role": "fake",
				"kind": "email",
				"app": "mail",
				"task": "Check the voucher email",
				"unlock_after": [],
				"required_inspections": ["sender", "link:c1_claim"],
				"message": {
					"time": "08:52",
					"from_name": "Aegis Welcome Rewards",
					"from_addr": "rewards@aegis-welcome-gifts.example",
					"reply_to": "",
					"to": "you@aegis-solutions.example",
					"subject": "Congratulations! Claim your PHP 2,000 welcome voucher",
					"body": "Dear Valued Employee,\n\nAs a new hire you have been selected for a PHP 2,000 shopping voucher!\n\nClaim it before midnight tonight or it goes to the next employee:\n[url=c1_claim]Claim my voucher[/url]\n\nHave your employee ID and bank card ready.\n\nAegis Rewards Team",
					"links": {"c1_claim": "http://aegis-welcome-gifts.example/claim?emp=2291"},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "What will you do with this email?",
						"choices": [
							{"text": "Claim the voucher through the link", "outcome": "unsafe",
								"feedback": "The claim form belonged to Black Veil, not Aegis.",
								"compromise": "Your employee ID and bank card details were sent to Black Veil."},
							{"text": "Report it to Security as phishing", "outcome": "correct",
								"feedback": "Right: an outside sender domain, a prize you never entered for, a midnight deadline and a request for your bank card."},
							{"text": "Forward it to the other new hires so they can claim one too", "outcome": "wrong",
								"feedback": "Forwarding spreads the link to people who may click it. Report it instead."},
							{"text": "Delete the email", "outcome": "correct",
								"feedback": "Safe: you did not engage. From the next chapter on, report scams as well so Security can warn others."},
						],
					},
				],
				"bad_ending": "Black Veil used your employee ID to pose as you inside Aegis and your bank card to make purchases. Aegis Solutions has been breached.",
				"warning_signs": [
					"A sender domain that is not Aegis (aegis-welcome-gifts.example)",
					"A generic greeting: \"Dear Valued Employee\"",
					"A generic greeting: \"Dear Valued Employee\"",
					"A prize you never entered for",
					"A deadline: \"before midnight tonight\"",
					"A request for your bank card",
				],
				"tip": "Free money plus a deadline is a classic lure. Check the sender's domain, and never give card details through an email link.",
			},
			{
				"id": "c1_coworker",
				"role": "coworker",
				"kind": "coworker",
				"app": "mail",
				"task": "Help a coworker (Sales)",
				"unlock_after": ["c1_benefits"],
				"required_inspections": ["sender", "quote", "link:c1_cw_pay"],
				"message": {
					"time": "09:20",
					"from_name": "Coworker - Sales",
					"from_addr": "sales.team@aegis-solutions.example",
					"reply_to": "",
					"to": "you@aegis-solutions.example",
					"subject": "Is this legit?",
					"body": "Hi! I saw Security's warning about the fake HR email. Then this one arrived, supposedly from Payroll. I nearly clicked it. Is it legit?",
					"quote": {
						"label": "Forwarded message",
						"details": [
							"From: Aegis Payroll <payroll@aegis-payroll-portal.example>",
							"Subject: Your November salary is on hold",
						],
						"body": "Your November salary is on hold because your bank details could not be confirmed.\nConfirm them today to receive your pay: [url=c1_cw_pay]Confirm my bank details[/url]",
					},
					"links": {"c1_cw_pay": "http://aegis-payroll-portal.example/salary/confirm?team=sales"},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "What do you tell your coworker?",
						"choices": [
							{"text": "Tell them to reply to Payroll first, then report it if it seems off", "outcome": "wrong",
								"feedback": "A reply goes to the sender, not to Payroll: the attacker would answer and keep the trick going. Report it straight away instead."},
							{"text": "Tell them to confirm their bank details so their salary is paid", "outcome": "unsafe",
								"feedback": "The link belonged to Black Veil, not Payroll.",
								"compromise": "Your coworker's bank details were sent to Black Veil, and their salary was redirected."},
							{"text": "Tell them not to click it and to report it to Security (ext. 1200)", "outcome": "correct",
								"response_line": "Coworker - Sales: Thanks! Reporting it now.",
								"feedback": "Exactly. The forwarded sender is aegis-payroll-portal.example and the link goes there too. Real Aegis mail comes from @aegis-solutions.example."},
							{"text": "Tell them to forward it to the whole team so nobody else falls for it", "outcome": "wrong",
								"feedback": "Forwarding spreads the live link to everyone. Security can warn the team safely."},
						],
					},
				],
				"bad_ending": "Black Veil redirected a coworker's salary and used their details to target the Sales team. Aegis Solutions has been breached.",
				"warning_signs": [
					"A sender domain that is not Aegis (aegis-payroll-portal.example)",
					"A threat: your salary is on hold",
					"A request to confirm bank details through a link",
					"A link whose real address is not Aegis",
				],
				"tip": "When a coworker asks, read the forwarded sender and link with them, then send them to Security. Never call a link fine without reading its real address.",
			},
		],
		"debrief": "That benefits email came from Black Veil. They copied the look of our HR messages to collect your details. The voucher email and the 'Payroll' email your coworker got were theirs too, but the orientation email was real. Telling them apart is the job.",
		"warning_signs": [
			"A lookalike sender domain (aegis-solutions-hr.example)",
			"A generic greeting: \"Dear Employee\"",
			"24-hour pressure",
			"A link whose real address is not Aegis",
		],
		"tip": "Before you click, read the real address. Copy the link and look at the domain right before the first single slash.",
		"bad_ending": "Black Veil used your employee details to pose as you and trick coworkers into trusting their messages. Aegis Solutions has been breached.",
	},
	# ======================================================================== Chapter 2: Smishing
	{
		"id": 2,
		"title": "Smishing",
		"device": "workstation",
		"app": "messages",
		"hint_level": "generic",
		"briefing": [
			{"speaker": SECURITY, "text": "Chapter 2. Your welcome kit ships by courier this week. Your phone's messages sync to the desktop."},
			{"speaker": SECURITY, "text": "Some texts are real and some are not. Check each one before you act."},
			{"speaker": SECURITY, "text": "From now on, deleting a scam is not enough: report it so Security can warn everyone."},
		],
		"objective": "Check your messages at your workstation",
		"items": [
			{
				"id": "c2_redeliver",
				"role": "main",
				"kind": "sms",
				"app": "messages",
				"task": "Check the first courier text",
				"unlock_after": [],
				"required_inspections": ["sender_number", "link:c2_pay"],
				"message": {
					"time": "08:15",
					"sender_label": "SwftParcel",
					"sender_number": "09XX-XXX-7731",
					"sender_info": "Number type: mobile number.",
					"body": "SwftParcel: Parcel SP-4417 is ON HOLD. Pay PHP 45 redelivery fee within 2 hrs: [url=c2_pay]swftparcel-redeliver[/url]",
					"links": {"c2_pay": "http://swiftparcel-redeliver.example/pay?ref=4417"},
				},
				"steps": [
					{
						"surface": "desktop",
						"task": "Check the first courier text",
						"question": "How will you handle this text?",
						"choices": [
							{"text": "Check the parcel on SwiftParcel's official website", "outcome": "correct", "next_step": 1, "opens": "courier",
								"feedback": "Use the official site you find yourself, never the link in the text. It shows no fees due."},
							{"text": "Reply \"Who is this?\"", "outcome": "wrong",
								"feedback": "Replying confirms your number is active and invites more scams."},
							{"text": "Ignore it and do nothing", "outcome": "wrong",
								"feedback": "You avoided the trap, but the protocol is to verify through the official channel and report it."},
							{"text": "Open the link and pay the fee", "outcome": "unsafe",
								"feedback": "The payment page belonged to Black Veil.",
								"compromise": "Your card details were sent to Black Veil."},
						],
					},
					{
						"surface": "desktop",
						"task": "Decide what to do with the text",
						"question": "The official site shows no fees due. What now?",
						"choices": [
							{"text": "Report the text to Security and delete it", "outcome": "correct", "next_step": 2,
								"feedback": "Reporting helps others who got the same text. Tell Security what you noticed."},
							{"text": "Keep it in case it is needed later", "outcome": "wrong",
								"feedback": "Keeping it leaves the link one tap away."},
							{"text": "Forward it to coworkers as a warning", "outcome": "wrong",
								"feedback": "Forwarding spreads the live link. Report it so Security can warn people safely."},
						],
					},
					{
						"surface": "desktop",
						"kind": "checklist",
						"task": "Report its warning signs",
						"question": "Report to Security: tick every warning sign in the parcel-on-hold text.",
						"submit_text": "Submit report",
						"options": [
							{"text": "It came from an ordinary mobile number", "real": true,
								"why": "SwiftParcel never texts from a mobile number: its official site says so."},
							{"text": "It mentions your real parcel number, SP-4417", "real": false,
								"why": "Attackers can know or guess real details. A real detail is not proof either way."},
							{"text": "The brand is misspelled: \"SwftParcel\"", "real": true,
								"why": "Real companies spell their own name right."},
							{"text": "An unexpected fee (PHP 45)", "real": true,
								"why": "The official site shows no fees due."},
							{"text": "The text is short", "real": false,
								"why": "Most texts are short, real or fake."},
							{"text": "A 2-hour deadline", "real": true,
								"why": "Pressure is meant to stop you from checking."},
							{"text": "The link's real address is swiftparcel-redeliver.example, not www.swiftparcel.example", "real": true,
								"why": "Only www.swiftparcel.example is SwiftParcel's site."},
							{"text": "Your welcome kit really is on its way", "real": false,
								"why": "Attackers time their texts to match real deliveries. That alone is not a warning sign."},
						],
						"feedback": "Report filed. Security blocked swiftparcel-redeliver.example and warned all staff about the text.",
					},
				],
			},
			{
				"id": "c2_delivery",
				"role": "genuine",
				"kind": "sms",
				"app": "messages",
				"task": "Check the second courier text",
				"unlock_after": [],
				"required_inspections": ["sender_number", "link:c2_track"],
				"message": {
					"time": "09:05",
					"sender_label": "SwiftParcel",
					"sender_number": "SwiftParcel (sender name)",
					"sender_info": "Number type: business sender name.",
					"body": "SwiftParcel: Parcel SP-4417 is out for delivery today, 13:00-17:00. No action needed. Track it: [url=c2_track]swiftparcel.example/track[/url]",
					"links": {"c2_track": "https://www.swiftparcel.example/track?id=SP-4417"},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "How will you handle this text?",
						"choices": [
							{"text": "Report it to Security as a scam", "outcome": "wrong",
								"feedback": "This one is real: it asks for nothing, charges no fee, and its link stays on www.swiftparcel.example. Reporting is never dangerous, but here the evidence showed it was genuine."},
							{"text": "Keep the text and check SP-4417 on the official SwiftParcel site", "outcome": "correct", "opens": "courier",
								"feedback": "Right. It asks for nothing, charges no fee, and its link would stay on www.swiftparcel.example. The official site, which you opened yourself, shows the same delivery window."},
							{"text": "Delete it and block the sender", "outcome": "wrong",
								"feedback": "This one is real, and blocking it means missing real delivery updates. The evidence showed it was genuine: no request, no fee, an official link."},
							{"text": "Reply \"Is this really SwiftParcel?\"", "outcome": "wrong",
								"feedback": "A reply cannot prove who sent a text. Here the evidence already showed it was genuine: no request, no fee and an official link."},
						],
					},
				],
			},
			{
				"id": "c2_access",
				"role": "fake",
				"kind": "sms",
				"app": "messages",
				"task": "Check the network access text",
				"unlock_after": [],
				"required_inspections": ["sender_number", "link:c2_keep"],
				"message": {
					"time": "09:12",
					"sender_label": "Aegis IT",
					"sender_number": "09XX-XXX-2290",
					"sender_info": "Number type: mobile number. Not in your contacts.",
					"body": "Aegis IT: Your new-hire network access will be suspended tonight. Keep it active here: [url=c2_keep]aegis-solutions.access-check.example[/url]",
					"links": {"c2_keep": "http://aegis-solutions.access-check.example/keep?emp=2291"},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "How will you handle this text?",
						"choices": [
							{"text": "Reply STOP to stop these texts", "outcome": "wrong",
								"feedback": "Replying tells the sender your number is active. Report it instead."},
							{"text": "Open the link and enter your details to keep your access active", "outcome": "unsafe",
								"feedback": "The form belonged to Black Veil, not Aegis IT.",
								"compromise": "Your employee ID and personal details were sent to Black Veil."},
							{"text": "Delete the text", "outcome": "wrong",
								"feedback": "Deleting it is not enough any more: report it so Security can warn everyone else who got it."},
							{"text": "Report the text to Security and delete it", "outcome": "correct",
								"feedback": "Right. It came from an unknown mobile number, and the link's real domain is access-check.example: \"aegis-solutions\" is only the first part of the address."},
						],
					},
				],
				"bad_ending": "Black Veil used your employee details to pose as you to the IT Helpdesk. Aegis Solutions has been breached.",
				"warning_signs": [
					"An ordinary mobile number posing as Aegis IT",
					"A threat: access suspended tonight",
					"A link whose real domain is access-check.example, with \"aegis-solutions\" only in front",
				],
				"tip": "Read the whole host name. The real domain is the last part before the first single slash, not the first words you see.",
			},
			{
				"id": "c2_coworker",
				"role": "coworker",
				"kind": "coworker",
				"app": "messages",
				"task": "Help a coworker (Admin)",
				"unlock_after": ["c2_redeliver"],
				"required_inspections": ["sender_number", "quote", "link:c2_cw_pay"],
				"message": {
					"time": "09:40",
					"sender_label": "Coworker - Admin",
					"sender_number": "09XX-XXX-3108",
					"sender_info": "Saved contact: Coworker - Admin (Aegis Admin team, ext. 2120 in the Staff Directory).",
					"body": "Hi! Security says you reported a fake courier text. This one came from SwiftParcel's own name, about the Admin team's parcel. It's only PHP 60, so I was about to pay. Is it legit?",
					"quote": {
						"label": "Forwarded text",
						"details": [
							"From: SwiftParcel (sender name)",
							"Received: today 09:31",
						],
						"body": "SwiftParcel: Parcel SP-9902 has a customs fee of PHP 60. Pay by 18:00 today or it will be returned: [url=c2_cw_pay]swiftparcel.customs-fee.example[/url]",
					},
					"links": {"c2_cw_pay": "http://swiftparcel.customs-fee.example/pay?sp=9902"},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "What do you tell your coworker?",
						"choices": [
							{"text": "Tell them to pay it: the text came from SwiftParcel's name", "outcome": "unsafe",
								"feedback": "The payment page belonged to Black Veil.",
								"compromise": "Your coworker paid the fake fee, and their card details went to Black Veil."},
							{"text": "Tell them to reply and ask SwiftParcel for a receipt first", "outcome": "wrong",
								"feedback": "A reply cannot prove who sent a text, and it tells the sender the number is active."},
							{"text": "Tell them to pay at the courier's counter instead, and report the text", "outcome": "wrong",
								"feedback": "The fee itself is fake: the official site shows SP-9902 already delivered, so paying anywhere loses money. Just report the text."},
							{"text": "Tell them not to tap it, to check the official site and report it", "outcome": "correct",
								"response_line": "Coworker - Admin: The official site says it was delivered yesterday. Reporting it now!",
								"feedback": "Exactly. Sender names can be faked: the link's real domain is customs-fee.example, and the official site shows SP-9902 delivered with no fees. Security is on ext. 1200."},
						],
					},
				],
				"bad_ending": "Black Veil used your coworker's card and contact list to target more Aegis staff. Aegis Solutions has been breached.",
				"warning_signs": [
					"A SwiftParcel sender name, but the link's real domain is customs-fee.example",
					"An unexpected fee with a same-day deadline",
					"The official site shows SP-9902 already delivered",
				],
				"tip": "A sender name can be faked. Check parcels only on the courier's official site, which you open yourself. A small fee is still a trap.",
			},
		],
		"debrief": "Black Veil sent the parcel-on-hold text, the 'Aegis IT' text and your coworker's 'customs fee' text. When email didn't work, they tried your phone. The delivery update that asked for nothing and linked to www.swiftparcel.example was real.",
		"warning_signs": [
			"An unknown mobile number posing as a courier",
			"A misspelled brand name (SwftParcel)",
			"An unexpected small fee",
			"Time pressure (2 hours)",
			"A link to a non-official domain",
		],
		"tip": "Couriers do not collect fees through text links. Check the tracking number on the courier's official website.",
		"bad_ending": "Black Veil charged your card and used your details to target Aegis staff. Aegis Solutions has been breached.",
	},
	# ======================================================================== Chapter 3: Vishing
	{
		"id": 3,
		"title": "Vishing",
		"device": "telephone",
		"app": "call",
		"hint_level": "generic",
		"briefing": [
			{"speaker": SECURITY, "text": "Chapter 3. Your desk phone is now connected. Answer calls as they come in."},
			{"speaker": SECURITY, "text": "Keep an eye on your messages too."},
		],
		"objective": "Answer the ringing telephone",
		"items": [
			{
				"id": "c3_facilities",
				"role": "genuine",
				"kind": "call",
				"app": "call",
				"task": "Answer the first call",
				"unlock_after": [],
				"required_inspections": ["caller_id"],
				"call": {
					"caller_id": "EXT 1400",
					"caller_id_info": "Line type: internal extension 1400.",
					"caller_name": "Facilities",
					"lines": [
						"Hi, Facilities here. We connected your desk phone this morning.",
						"Can you hear me clearly? That's all I need to know, thanks.",
					],
				},
				"steps": [
					{
						"surface": "call",
						"question": "How do you respond?",
						"choices": [
							{"text": "Hang up and report it to Security as a scam", "outcome": "wrong",
								"feedback": "This call was real: Facilities on ext. 1400, asking for nothing sensitive. Reporting is never dangerous, but here the evidence showed it was genuine."},
							{"text": "Refuse to talk until they prove who they are", "outcome": "wrong",
								"feedback": "Asking for proof is right when a caller wants something sensitive. This one only asked if the line works."},
							{"text": "Answer their question: tell them the line is clear", "outcome": "correct",
								"feedback": "Right. They asked for nothing sensitive, and the caller ID matches Facilities on your phone card. A normal call deserves a normal answer. If a caller ever wants something sensitive, caller ID alone is not proof."},
							{"text": "Put them on hold and call Security to check the caller", "outcome": "wrong",
								"feedback": "Checking is right when a caller wants something sensitive. Here the evidence showed a genuine call that asked for nothing."},
						],
					},
				],
			},
			{
				"id": "c3_mark",
				"role": "main",
				"kind": "call",
				"app": "call",
				"task": "Answer the second call",
				"unlock_after": ["c3_facilities"],
				"required_inspections": ["caller_id"],
				"call": {
					"caller_id": "OUTSIDE LINE 09XX-XXX-0381",
					"caller_id_info": "Line type: outside line, 09XX-XXX-0381.",
					"caller_name": "Mark from IT Support",
					"lines": [
						"Hi, this is Mark from IT Support.",
						"We've detected suspicious logins on your account. It locks in 5 minutes unless I verify you.",
						"Tell me your password now.",
					],
				},
				"steps": [
					{	# 0
						"surface": "call",
						"task": "Answer the second call",
						"question": "How do you respond?",
						"choices": [
							{"text": "Refuse and hang up", "outcome": "correct", "next_step": 1,
								"feedback": "IT never asks for your password. Ending the call is the right move."},
							{"text": "Ask him to prove he is from IT", "outcome": "wrong",
								"response_line": "There's no time, your account locks in 3 minutes!",
								"feedback": "Keeping a scam caller talking gives them more chances to pressure you."},
							{"text": "Tell him your password", "outcome": "unsafe",
								"feedback": "The caller works for Black Veil.",
								"compromise": "Black Veil logged in to your account with your password."},
						],
					},
					{	# 1: both correct routes (GDD 8: "hang up and report the call or call IT back through a known number") lead to step 2
						"surface": "call",
						"task": "Follow up on the call",
						"call_header": "CALL ENDED",
						"question": "You hung up. What next?",
						"choices": [
							{"text": "Call the IT Helpdesk on the known ext. 1100", "outcome": "correct", "next_step": 2,
								"response_line": "IT Helpdesk: No, we haven't called you today, and we never ask for passwords. I'll put you through to Security.",
								"feedback": "Calling back on a number you already trust confirms the truth. IT is putting you through to Security on ext. 1200."},
							{"text": "Report the call to Security (ext. 1200)", "outcome": "correct", "next_step": 2,
								"feedback": "Security can warn others about this caller. Tell them what you noticed."},
							{"text": "Call back the number that called you", "outcome": "wrong",
								"feedback": "That number belongs to the attacker."},
							{"text": "Do nothing", "outcome": "wrong",
								"feedback": "Unreported calls let the attacker try your coworkers next."},
						],
					},
					{	# 2
						"surface": "call",
						"kind": "checklist",
						"task": "Tell Security the warning signs",
						"call_header": "EXT 1200: SECURITY OFFICE",
						"call_name": "Security Office",
						"call_lines": [
							"Security Office, Dela Vega speaking. Thank you for calling it in.",
							"Which warning signs did you notice on that call?",
						],
						"question": "Tell Security every warning sign you noticed on the second call.",
						"submit_text": "Tell Security",
						"options": [
							{"text": "The caller ID showed an outside line (09XX-XXX-0381), not a 4-digit internal extension", "real": true,
								"why": "Internal Aegis calls show a 4-digit extension."},
							{"text": "He gave his first name, Mark", "real": false,
								"why": "Anyone can say a name. It proves nothing either way."},
							{"text": "An unexpected call about a problem you never reported", "real": true,
								"why": "Real IT rarely calls out of the blue about your account."},
							{"text": "A lockout threat with a 5-minute deadline", "real": true,
								"why": "Pressure is meant to stop you from checking."},
							{"text": "He called your desk phone, not your mobile", "real": false,
								"why": "Real and fake calls can reach any phone. Where it rang proves nothing."},
							{"text": "He asked for your password", "real": true,
								"why": "IT never asks for your password."},
							{"text": "He knew you work at Aegis Solutions", "real": false,
								"why": "Where you work is easy to find out. It proves nothing either way."},
						],
						"feedback": "Thank you. Security has warned all staff about the fake IT Support caller.",
					},
				],
			},
			{
				"id": "c3_security",
				"role": "fake",
				"kind": "call",
				"app": "call",
				"task": "Answer the third call",
				"unlock_after": ["c3_mark"],
				"required_inspections": ["caller_id"],
				"call": {
					"caller_id": "AEGIS SECURITY 09XX-XXX-1200",
					"caller_id_info": "Line type: mobile number, 09XX-XXX-1200.",
					"caller_name": "Security Office",
					"lines": [
						"Hello, this is the Security Office, following up on the call you just reported.",
						"To close your report, we've sent a 6-digit code to your phone. Please read it to me.",
					],
				},
				"steps": [
					{
						"surface": "call",
						"question": "How do you respond?",
						"choices": [
							{"text": "Ask which code they mean", "outcome": "wrong",
								"response_line": "The one that just arrived. Read it out quickly, before it expires.",
								"feedback": "Keeping the caller talking gives them more chances to pressure you. Security never asks for codes."},
							{"text": "Refuse, hang up and report it to Security on ext. 1200", "outcome": "correct",
								"feedback": "Right. The caller ID was an outside mobile number dressed up with a Security name, and a one-time code is as secret as a password."},
							{"text": "Read out the code", "outcome": "unsafe",
								"feedback": "The caller works for Black Veil.",
								"compromise": "Black Veil used your one-time code to reset your password and take over your Aegis account."},
						],
					},
				],
				"bad_ending": "Black Veil used your one-time code to reset your password, take over your account and read Security's incident reports. Aegis Solutions has been breached.",
				"warning_signs": [
					"Caller ID showed an outside mobile number, even though the name said Aegis Security",
					"A request for a one-time code",
					"Pressure: read it before it expires",
				],
				"tip": "A caller ID name proves nothing. Never read out a one-time code; hang up and call the known extension yourself.",
			},
			{
				"id": "c3_coworker",
				"role": "coworker",
				"kind": "coworker",
				"app": "messages",
				"task": "Help a coworker (Marketing)",
				"unlock_after": ["c3_mark"],
				"required_inspections": ["sender_number", "quote"],
				"message": {
					"time": "10:05",
					"sender_label": "Coworker - Marketing",
					"sender_number": "09XX-XXX-3341",
					"sender_info": "Saved contact: Coworker - Marketing (Aegis Marketing team, ext. 2130 in the Staff Directory).",
					"body": "Quick one! Someone just left me a voicemail saying he's from IT. He says my account locks in 10 minutes unless I give him my password, and he left a callback number. Should I call him back and give it?",
					"quote": {
						"label": "Their voicemail notes",
						"details": [
							"Caller ID shown: OUTSIDE LINE 09XX-XXX-0381",
							"Callback number given: 09XX-XXX-0381",
						],
						"body": "\"This is Mark from IT Support. Your account locks in 10 minutes. Call me back and verify your password.\"",
					},
					"links": {},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "What do you tell your coworker?",
						"choices": [
							{"text": "Tell them to call back on the number he left, to check first", "outcome": "wrong",
								"feedback": "That number belongs to the attacker. Use the extension you already know."},
							{"text": "Tell them not to share it, to call IT on ext. 1100 and report it", "outcome": "correct",
								"response_line": "Coworker - Marketing: Calling 1100 now. Thanks!",
								"feedback": "Exactly. It is the same outside number that called you, and real IT never needs a password. Security is on ext. 1200."},
							{"text": "Tell them to give it: IT needs it to unlock the account", "outcome": "unsafe",
								"feedback": "The caller works for Black Veil.",
								"compromise": "Your coworker gave their password to Black Veil, who logged in as them."},
							{"text": "Tell them to ask the caller for his staff ID, and report him if he has none", "outcome": "wrong",
								"feedback": "Anyone can make up a staff ID, so asking proves nothing. Real IT never needs a password: call IT on ext. 1100 and report it."},
						],
					},
				],
				"bad_ending": "Black Veil logged in as your coworker and moved through Aegis systems. Aegis Solutions has been breached.",
				"warning_signs": [
					"The same outside number that called you",
					"A lockout threat with a deadline",
					"A request for a password",
					"A callback number given by the caller",
				],
				"tip": "Only call back on numbers you already know, such as IT on ext. 1100. Never share a password, even with someone who says they are IT.",
			},
		],
		"debrief": "That 'IT' caller works for Black Veil, and so does the fake 'Security' caller who wanted your code. Real IT never needs your password, and Security never asks for codes. The Facilities call was genuine.",
		"warning_signs": [
			"An unexpected call from an outside line claiming to be internal IT",
			"Urgency and a lockout threat",
			"A request for your password",
		],
		"tip": "No real IT team asks for your password. Caller ID can be faked, so if a caller wants anything sensitive, hang up and call back on a number you already know.",
		"bad_ending": "Black Veil used your password to enter Aegis systems. Aegis Solutions has been breached.",
	},
	# ======================================================================== Chapter 4: Business Email Compromise
	{
		"id": 4,
		"title": "Business Email Compromise",
		"device": "workstation",
		"app": "mail",
		"hint_level": "none",
		"briefing": [
			{"speaker": SECURITY, "text": "Chapter 4. Managers may send you finance tasks this week. Check your inbox."},
			{"speaker": SECURITY, "text": "This is your last chapter. There are no more hints: inspect everything yourself."},
		],
		"objective": "Check your email at your workstation",
		"items": [
			{
				"id": "c4_supplier",
				"role": "main",
				"kind": "email",
				"app": "mail",
				"task": "Check the supplier payment email",
				"unlock_after": [],
				"required_inspections": ["sender"],
				"message": {
					"time": "08:40",
					"from_name": "R. Ramos",
					"from_addr": "r.ramos@aegis-so1utions.example",
					"reply_to": "rramos.office@securemail-box.example",
					"to": "you@aegis-solutions.example",
					"subject": "Urgent and confidential: supplier payment",
					"body": "I'm in a board meeting and can't take calls. Kestrel Office Supplies changed their bank account. Update their details and pay PHP 248,000 today.\n\nKeep this between us until it's done.\n\nR. Ramos",
					"links": {},
				},
				"steps": [
					{
						"surface": "desktop",
						"task": "Check the supplier payment email",
						"question": "How will you handle this request?",
						"choices": [
							{"text": "Look up Mr. Ramos in the Staff Directory and call his extension", "outcome": "correct", "next_step": 1, "opens": "directory",
								"feedback": "Use contact details you already trust, not the ones in the email. His extension is in the Staff Directory."},
							{"text": "Reply to the email to confirm it is really from Mr. Ramos", "outcome": "wrong",
								"response_line": "Reply from R. Ramos: Yes, do it now. I'm counting on you.",
								"feedback": "The reply went to the attacker's Reply-To address, so of course they said yes."},
							{"text": "Update the supplier's bank details and process the payment", "outcome": "unsafe",
								"feedback": "The new bank account belonged to Black Veil.",
								"compromise": "PHP 248,000 was sent to an account controlled by Black Veil."},
						],
					},
					{
						"surface": "call",
						"wait_for": "telephone",
						"task": "Check with Mr. Ramos",
						"wait_objective": "Call Mr. Ramos on ext. 2045 using your desk phone",
						"trigger_prompt": "Call Mr. Ramos (ext. 2045)",
						"call_header": "EXT 2045: R. RAMOS",
						"call_name": "R. Ramos",
						"call_lines": ["I never sent that email. Don't pay anything, and please report it."],
						"question": "What do you do with the email?",
						"choices": [
							{"text": "Report the email to Security (Ms. Dela Vega)", "outcome": "correct", "next_step": 2,
								"feedback": "Security can block the lookalike domain and alert Finance. File the report at your desk."},
							{"text": "Delete it and say nothing", "outcome": "wrong",
								"feedback": "The attacker will try someone else in Finance next."},
							{"text": "Forward it to Finance as a warning", "outcome": "wrong",
								"feedback": "Forwarding spreads the request to more people who might act on it. Security warns Finance safely."},
						],
					},
					{
						"surface": "desktop",
						"kind": "checklist",
						"task": "Report its warning signs",
						"question": "Report to Security: tick every warning sign in the payment email.",
						"submit_text": "Submit report",
						"options": [
							{"text": "The domain is aegis-so1utions.example: the digit 1 instead of the letter l", "real": true,
								"why": "One character is enough to make a different domain."},
							{"text": "It is signed R. Ramos, your real manager's name", "real": false,
								"why": "Anyone can type a name. The address matters, not the signature."},
							{"text": "Replies go to an outside address (securemail-box.example)", "real": true,
								"why": "A Reply-To outside Aegis sends your answer to the attacker."},
							{"text": "Urgency plus secrecy: pay today and keep it between us", "real": true,
								"why": "Secrecy stops you from checking with others."},
							{"text": "It names Kestrel Office Supplies, a real supplier", "real": false,
								"why": "Attackers research real suppliers. A real name is not proof either way."},
							{"text": "\"Can't take calls\", so you cannot check by phone", "real": true,
								"why": "Blocking the easiest check is a classic trick."},
							{"text": "A change of bank details together with a payment", "real": true,
								"why": "Bank-detail changes must always be verified through a known channel."},
							{"text": "It contains no link", "real": false,
								"why": "Business email compromise often has no link at all: the danger is the request itself."},
						],
						"feedback": "Report filed. Security blocked aegis-so1utions.example and warned Finance.",
					},
				],
			},
			{
				"id": "c4_giftcards",
				"role": "fake",
				"kind": "email",
				"app": "mail",
				"task": "Check the Office of the CEO email",
				"unlock_after": [],
				"required_inspections": ["sender"],
				"message": {
					"time": "09:02",
					"from_name": "Office of the CEO",
					"from_addr": "ceo.office@aegis-solution.example",
					"reply_to": "",
					"to": "you@aegis-solutions.example",
					"subject": "Quick favor (are you at your desk?)",
					"body": "Hi,\n\nAre you at your desk? I need a quick favor for a client visit this afternoon.\n\nPlease buy six PHP 5,000 gift cards and reply with the card codes. Finance will pay you back tomorrow.\n\nI'm in meetings all day, so email only, please.\n\nOffice of the CEO",
					"links": {},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "How will you handle this request?",
						"choices": [
							{"text": "Reply to ask what the gift cards are for", "outcome": "wrong",
								"response_line": "Reply from Office of the CEO: For a client. Please hurry and send the codes as soon as you have them.",
								"feedback": "Your reply went to the sender's lookalike domain, so of course they pushed harder."},
							{"text": "Report it to Security as business email compromise", "outcome": "correct",
								"feedback": "Right. aegis-solution.example is missing an s (the Staff Directory lists ceo.office@aegis-solutions.example), and gift-card codes by email with \"email only\" is a classic trick."},
							{"text": "Buy the gift cards and email the codes", "outcome": "unsafe",
								"feedback": "The codes went to Black Veil, not the CEO's office.",
								"compromise": "PHP 30,000 in gift card codes went to Black Veil."},
							{"text": "Delete it", "outcome": "wrong",
								"feedback": "You avoided the trap, but with a payment request the protocol is to report it so Security can block the domain."},
						],
					},
				],
				"bad_ending": "Black Veil cashed the gift cards and used the same 'CEO' trick on other staff. Aegis Solutions has suffered a costly breach.",
				"warning_signs": [
					"A lookalike domain (aegis-solution.example, missing the s)",
					"Gift-card codes requested by email",
					"\"Email only\": no way to check by phone",
					"Urgency: this afternoon",
				],
				"tip": "No real manager asks for gift-card codes by email. Verify through a known channel and report it.",
			},
			{
				"id": "c4_policy",
				"role": "genuine",
				"kind": "email",
				"app": "mail",
				"task": "Check the expense policy email",
				"unlock_after": [],
				"required_inspections": ["sender", "link:c4_expense"],
				"message": {
					"time": "09:15",
					"from_name": "R. Ramos",
					"from_addr": "r.ramos@aegis-solutions.example",
					"reply_to": "",
					"to": "you@aegis-solutions.example",
					"subject": "Updated expense policy: please read by Friday",
					"body": "Hi team,\n\nFinance has updated the expense policy. Please read it on the intranet by Friday and reply \"Noted\" so I can tick you off my list:\n[url=c4_expense]Expense policy (intranet)[/url]\n\nThanks,\nR. Ramos\nManager, ext. 2045",
					"links": {"c4_expense": "https://intranet.aegis-solutions.example/finance/expense-policy"},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "What will you do with this email?",
						"choices": [
							{"text": "Report it to Security as business email compromise", "outcome": "wrong",
								"feedback": "This one is real: r.ramos@aegis-solutions.example, no outside Reply-To, an intranet link, and no money involved. Reporting is never dangerous, but here the evidence showed it was genuine."},
							{"text": "Ask Mr. Ramos to resend it from his real address", "outcome": "wrong",
								"feedback": "It already is his real address: r.ramos@aegis-solutions.example, with replies going back to it. The evidence showed it was genuine."},
							{"text": "Open the policy link, read it, and reply \"Noted\"", "outcome": "correct",
								"feedback": "Right. The sender is the real aegis-solutions.example address, replies go back to it, and the link stays on the intranet, so it is safe to open. It asks for nothing risky."},
							{"text": "Delete it", "outcome": "wrong",
								"feedback": "This one is real, and deleting it means ignoring real work from your manager. The evidence showed it was genuine."},
						],
					},
				],
			},
			{
				"id": "c4_coworker",
				"role": "coworker",
				"kind": "coworker",
				"app": "mail",
				"task": "Help a coworker (Finance)",
				"unlock_after": ["c4_supplier"],
				"required_inspections": ["sender", "quote"],
				"message": {
					"time": "10:10",
					"from_name": "Coworker - Finance",
					"from_addr": "finance.team@aegis-solutions.example",
					"reply_to": "",
					"to": "you@aegis-solutions.example",
					"subject": "Supplier bank change: is this real?",
					"body": "Hi, I heard you caught the fake payment email. I just got this from Kestrel Office Supplies. It quotes our real purchase order number, so it looks real. Should I update their bank account before I pay the invoice?",
					"quote": {
						"label": "Forwarded message",
						"details": [
							"From: Kestrel Office Supplies <billing@kestrel-supplies-ph.example>",
							"Subject: New bank details for invoice KS-2231",
						],
						"body": "Dear Aegis Finance,\n\nOur bank details have changed. Please pay invoice KS-2231 for PO 7710 (PHP 86,500) to our new account from today.\n\nRegards,\nKestrel Billing",
					},
					"links": {},
				},
				"steps": [
					{
						"surface": "desktop",
						"question": "What do you tell your coworker?",
						"choices": [
							{"text": "Tell them to call Kestrel on the number on file and report it", "outcome": "correct",
								"response_line": "Coworker - Finance: Calling the number on file now. Thank you!",
								"feedback": "Exactly. The sender is kestrel-supplies-ph.example, not the supplier on file (kestrel-supplies.example in the Staff Directory). Bank changes are always verified on a known number."},
							{"text": "Tell them to reply to Kestrel to confirm, then report it if it is fake", "outcome": "wrong",
								"feedback": "A reply goes to whoever sent it. If that is Black Veil, they will confirm, and nothing gets reported."},
							{"text": "Tell them to update the account: the PO number matches", "outcome": "unsafe",
								"feedback": "The new account belonged to Black Veil.",
								"compromise": "Finance paid PHP 86,500 into an account controlled by Black Veil."},
							{"text": "Tell them to ask Kestrel to send the new details on letterhead first", "outcome": "wrong",
								"feedback": "A letterhead is easy to fake and would come from the same sender. Verify on the number Finance already has on file."},
						],
					},
				],
				"bad_ending": "Black Veil received PHP 86,500 meant for Kestrel Office Supplies, and the real supplier was never paid. Aegis Solutions has suffered a costly breach.",
				"warning_signs": [
					"A sender domain that is not the supplier on file (kestrel-supplies-ph.example)",
					"A change of bank details together with a payment",
					"\"From today\": pressure to switch accounts at once",
				],
				"tip": "Any change of bank details is verified by calling the supplier on the number already on file, never through the email.",
			},
		],
		"debrief": "Black Veil pretended to be Mr. Ramos, the CEO's office and a supplier to steal money. Checking addresses against the Staff Directory and calling known numbers stopped them. Mr. Ramos's expense policy email was real.",
		"warning_signs": [
			"A lookalike domain (aegis-so1utions with the digit 1)",
			"A Reply-To address outside Aegis",
			"Urgency plus secrecy",
			"\"Can't take calls\"",
			"A change of bank details together with a payment",
		],
		"tip": "Verify any payment or bank-detail change through a known channel, such as a phone number you already have, before acting.",
		"bad_ending": "Black Veil received the payment, and the real supplier was never paid. Aegis Solutions has suffered a costly breach.",
	},
]
```

### B.3 Content checks (why each item is inspectable and follows the outcome rule)

| Item | Role | Evidence the inspection reveals | Correct | Wrong | Unsafe |
|---|---|---|---|---|---|
| c1_orientation | genuine | `hr@aegis-solutions.example` (matches the Directory); link on `intranet.aegis-solutions.example` | open the agenda link and keep it | report, delete, forward to IT (evidence ignored) | none |
| c1_benefits | main | `aegis-solutions-hr.example`; link host `aegis-benefits-verify.example`; HR ext. 1300 says it is not theirs | verify via Directory + call 1300, or report at once; report or delete; checklist | reply, forward, leave it, keep it, forward to HR | open link |
| c1_voucher | fake | `aegis-welcome-gifts.example`; link on the same outside domain | report, delete (GDD 8 Ch1 allows both; the feedback announces that Ch2+ needs a report) | forward | claim |
| c1_coworker | coworker | the coworker is the real `sales.team@` (Directory); quoted sender + link on `aegis-payroll-portal.example` | protocol advice | reply asking for ID, forward to team | "looks fine" |
| c2_redeliver | main | mobile number; link host `swiftparcel-redeliver.example`; courier page: no fees, out for delivery, never texts from a mobile | official site; report; checklist | reply, ignore, keep, forward | pay |
| c2_delivery | genuine | sender name (a hint only), **no request, no fee**, link on `www.swiftparcel.example` | keep it and check SP-4417 on the official site you open yourself (never the text's link, as everywhere in Ch2) | report, delete + block, reply (evidence ignored) | none |
| c2_access | fake | mobile number; host `aegis-solutions.access-check.example` (real domain is `access-check.example`) | report + delete | reply STOP, delete only | enter details |
| c2_coworker | coworker | saved contact; quote shows the **SwiftParcel sender name** (spoofable); host `swiftparcel.customs-fee.example`; courier page: SP-9902 delivered | protocol advice | reply for receipt, pay at counter | "fine to pay" |
| c3_facilities | genuine | caller ID `EXT 1400` (Facilities on the phone card and in the Directory); asks nothing sensitive | answer normally | report, refuse, put on hold and check (evidence ignored) | none |
| c3_mark | main | outside line 09XX-XXX-0381 | hang up; call IT 1100 (who transfer you) or report to 1200; checklist | ask proof, call back, do nothing | password |
| c3_security | fake | name "AEGIS SECURITY" but an outside mobile 09XX-XXX-1200, not ext. 1200 | refuse + report | ask which code | read the code |
| c3_coworker | coworker | saved contact; quoted caller ID = the same outside line that called you | protocol advice | call back, ask for staff ID | "fine to give it" |
| c4_supplier | main | `aegis-so1utions.example` + outside Reply-To; Mr. Ramos on ext. 2045 says he never sent it | verify + call 2045; report; checklist | reply, delete and say nothing, forward to Finance | pay |
| c4_giftcards | fake | `aegis-solution.example` (missing s) vs. the Directory's `ceo.office@aegis-solutions.example` | report | reply, delete | buy cards |
| c4_policy | genuine | `r.ramos@aegis-solutions.example`, no Reply-To, intranet link | open the policy link, read it, reply "Noted" | report, ask to resend, delete (evidence ignored) | none |
| c4_coworker | coworker | the coworker is the real `finance.team@`; quoted sender `kestrel-supplies-ph.example` vs. the supplier on file in the Directory | protocol advice | reply, ask for letterhead | "update the account" |

Answer patterns that must NOT give the answer away (checked by review):
- Every genuine item has a correct choice that looks like the attacker's request (open the link, reply, answer the caller), so "is there a click/pay/answer option" does not separate real from fake.
- Every genuine item and every coworker item has 4 choices; the correct choice sits at a different position in each coworker item (3rd, 4th, 2nd, 1st) and in the genuine items (2nd, 2nd, 3rd, 3rd).
- In coworker items the correct option is no longer than the longest other option; the evidence is in the feedback, not in the choice text.
- In every coworker item one wrong option also mentions reporting ("..., then report it"), so "the only choice that says report" is never the answer; no unsafe option says "fine".
- Every main-attack decision has at least 3 choices (`c4_supplier` step 1 has a third: forward it to Finance), and the Ch4 verify choice no longer names the protocol ("through a known channel").
- Task labels are neutral and quote-free (invariant 13); checklist decoys are never reused between chapters.

Difficulty ramp (GDD 5 "increasingly convincing attacks"): Ch1 fakes use obviously foreign domains and "Dear Employee";
Ch2 adds a subdomain trick (`aegis-solutions.access-check.example`, `swiftparcel.customs-fee.example`) and a spoofed
sender name in the coworker's text; Ch3 adds a spoofed caller-ID name ending in 1200; Ch4 uses one-character lookalikes
(`so1utions`, `solution`) and a genuine email from the same display name "R. Ramos". Hints: Ch1 names every missing
inspection, Ch2-3 say "Inspect before you decide.", Ch4 only "Responses locked.". The genuine item's position moves
(Ch1 first, Ch2 second, Ch3 first call, Ch4 third). Revealed facts are neutral from Ch2 on: a text shows only its
number and "Number type: ..." and a call only "Line type: ..." (never "not a business sender" or "external, internal
calls show an extension"); the courier page, the phone card and the Staff Directory carry the evidence, and the
outcome feedback explains it. Masked numbers use one format everywhere: `09XX-XXX-####`.

### B.4 Score worksheet

C = correct +10, W = wrong -5. Best run = first correct choice everywhere. Wrong-first = every wrong choice of the
step in list order, then the first correct one; a checklist counts as one wrong submit (a set with one real sign
missing and one decoy added), then the exact set. Every correct path of an item has the same number of decisions,
so the best run is also the score of any flawless run.

| Item | Best: C -> points | Wrong-first: W count -> item total |
|---|---|---|
| c1_orientation | 1 -> 10 | 3 -> -5 |
| c1_benefits (steps 0, 1, 3; or 0, 2, 3) | 3 -> 30 | 2 + 1 + 1 = 4 -> 10 |
| c1_voucher | 1 -> 10 | 1 -> 5 |
| c1_coworker | 1 -> 10 | 2 -> 0 |
| **Ch1** (+20) | **6 -> 80** | **10 -> 30** |
| c2_redeliver (0, 1, 2) | 3 -> 30 | 2 + 2 + 1 = 5 -> 5 |
| c2_delivery | 1 -> 10 | 3 -> -5 |
| c2_access | 1 -> 10 | 2 -> 0 |
| c2_coworker | 1 -> 10 | 2 -> 0 |
| **Ch2** (+20) | **6 -> 80** | **12 -> 20** |
| c3_facilities | 1 -> 10 | 3 -> -5 |
| c3_mark (0, 1, 2 by either route) | 3 -> 30 | 1 + 2 + 1 = 4 -> 10 |
| c3_security | 1 -> 10 | 1 -> 5 |
| c3_coworker | 1 -> 10 | 2 -> 0 |
| **Ch3** (+20) | **6 -> 80** | **10 -> 30** |
| c4_supplier (0, 1, 2) | 3 -> 30 | 1 + 2 + 1 = 4 -> 10 |
| c4_giftcards | 1 -> 10 | 2 -> 0 |
| c4_policy | 1 -> 10 | 3 -> -5 |
| c4_coworker | 1 -> 10 | 2 -> 0 |
| **Ch4** (+20) | **6 -> 80** | **11 -> 25** |
| **Game** | **24 correct -> 320** | **24 correct + 43 wrong -> 105** |

Check: each wrong adds -5 on top of the same 24 correct decisions and 4 completions, so wrong-first =
320 - 43 x 5 = **105**; per chapter 80 - 10 x 5 = 30, 80 - 12 x 5 = 20, 80 - 10 x 5 = 30, 80 - 11 x 5 = 25.

Unsafe-and-restart (Ch2, `c2_redeliver` step 0 unsafe, after a best Ch1): 80 -> 75 -> restart -> 80 -> best Ch2 -> 160.

---------------------------------------------------------------------------------------------------------------------

## C. Behavior changes per file, public APIs, and ownership

### C.1 File ownership and build order

**Phase 0 (lead, before any builder starts; about 30 minutes).** Godot 4 checks members of typed classes and autoloads at
parse time, so every cross-file API must exist before the builders work in parallel. The lead writes
**signature-only stubs** (correct signature, `pass` or a typed default return such as `return ""`, `return []`,
`return {}`, `return 0`, `return false`) for:
- `scripts/core/chapter_session.gd`: every new function and property of C.2 (existing ones keep working);
- `autoload/game.gd`: the C.3 additions (`apply_outcome` gains the optional `item_id`, plus `item_log`, `item_total`, `item_max`, `chapter_max`, `max_score`);
- `data/campaign.gd`: `static func item()` (B, real 5-line body); **`MAX_SCORE` stays**;
- `scripts/ui/desktop_ui.gd`: `signal item_selected(item_id: String)`, `signal checklist_submitted(ticked: Array[int])`, `func notify(text: String) -> void`;
- `scripts/ui/call_ui.gd`: `signal checklist_submitted(ticked: Array[int])`;
- `scripts/ui/hud.gd`: `func set_tasks(tasks: Array[Dictionary], total: int) -> void`;
- **new** `scripts/ui/checklist_view.gd`: the full C.8 surface (both signals, `setup`, `set_locked`, `get_ticked`) with stub bodies. It has **no `class_name`**: hosts use `const ChecklistView := preload("res://scripts/ui/checklist_view.gd")`, so no global class cache entry is needed.

Then the lead runs, in this order, and commits nothing until both pass:
1. `"C:/Users/ADMIN/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:/Users/ADMIN/Desktop/Dev Apps/Vigilant/game" --import` (refreshes `.godot/global_script_class_cache.cfg` and creates the `.uid` file for the new script; if `--import` is not accepted, use `--headless --editor --quit`);
2. `tests/compile_check.gd` (0 failures). The old smoke test still passes at this point, because the stubs change no behavior.

**Phases 1-4 (builders, in parallel).** Each builder replaces **only the bodies** in its own files. `compile_check` must
pass after every save. Anyone who adds a new script file reruns the `--import` command before `compile_check` and the
smoke test.

| Builder | Owns (only these files) | Depends on (read-only) |
|---|---|---|
| **Lead (phase 0 + merge)** | the phase-0 stubs above; at the merge: delete `Campaign.MAX_SCORE`, run `--import`, `compile_check`, the smoke test; update `CONTRACT.md` (Modules B, C, E and the objective checklist) to point at this file | all |
| **1 content** | `data/campaign.gd` (`MAX_SCORE` stays until the merge) | sections A, B |
| **2 flow** | `scripts/core/chapter_session.gd`, `autoload/game.gd`, `scripts/office/office.gd`, `scripts/office/office_builder.gd` (two small changes, C.6), `tests/smoke_test.gd` (section D, finished last, after the others merge), `tests/capture.gd` and `tests/capture_play.gd` (C.14) | DesktopUI, CallUI, HUD, ChecklistView APIs |
| **3 desktop** | `scripts/ui/desktop_ui.gd` | ChapterSession API (C.2), ChecklistView API (C.8) |
| **4 panels** | `scripts/ui/call_ui.gd`, `scripts/ui/hud.gd`, `scripts/ui/feedback_screen.gd`, `scripts/menus/ending.gd`, `scripts/ui/instructions_panel.gd`, `scripts/ui/checklist_view.gd` (bodies) | ChapterSession API (C.2), Game API (C.3) |

Unchanged: `main_menu.gd`, `game_over_screen.gd` (it receives `session.failure_context()`, which has the same keys as a
chapter), `outcome_panel.gd` (the smoke test checks its Continue button stays on screen after the worst-case checklist
feedback; if that check fails, the lead fixes it at the merge), `compromise_notice.gd`, `dialogue_panel.gd`,
`pause_menu.gd`, `settings_panel.gd`, `overlay.gd`, `ui_style.gd`, `player.gd`, `interactable.gd`, `office_builder.gd`
apart from C.6, autoloads `settings.gd` / `router.gd`, `tests/compile_check.gd`.

### C.2 `ChapterSession` (builder 2) — exact public API

```gdscript
class_name ChapterSession
extends RefCounted

var chapter: Dictionary
var item_id: String = ""            ## the selected item ("" = none)
var clipboard: String = ""          ## shared in-game clipboard (never the OS clipboard)
var pasted_url: String = ""
var page: String = ""               ## "", "courier" or "directory" (chapter-wide Browser state)

## Compatibility properties: they read the SELECTED item's state (references, so .has()/.append() work).
## With no item selected the getters return fresh typed empties (0, {}, an empty Array[int]).
var step_index: int:                ## current step of the selected item
	get: ...
var inspected: Dictionary:          ## key -> true, for the selected item
	get: ...
var disabled: Array[int]:           ## disabled choice indices of the selected item's current step
	get: ...

func _init(ch: Dictionary) -> void
	## creates a state per item from TYPED locals (a literal [] inside a Dictionary is untyped and would raise a
	## runtime type error when returned through `var disabled: Array[int]`):
	##   var d: Array[int] = []; var t: Array[int] = []
	##   _states[id] = {"step": 0, "inspected": {}, "disabled": d, "ticks": t, "tried": [], "seen": false, "done": false}

# --- items ---
func items() -> Array                               ## chapter.items
func item(id: String = "") -> Dictionary            ## "" = selected item; {} if unknown/none
func item_step(id: String) -> Dictionary            ## that item's current step ({} if done/unknown)
func item_step_index(id: String) -> int             ## that item's current step index (0 if unknown)
func is_unlocked(id: String) -> bool                ## every unlock_after id is done
func is_done(id: String) -> bool
func status(id: String) -> String                   ## "locked" | "new" (unseen) | "open" | "done"
func available_items(app: String = "") -> Array     ## unlocked items (done ones included), data order; filtered by item.app if app != ""
func select_item(id: String) -> bool                ## false if unknown or locked; sets item_id and seen = true
func item_surface(id: String = "") -> String        ## current step's surface ("desktop"/"call"), "" if done/unknown
func next_desktop_item() -> String                  ## first unlocked, not-done item whose current surface is "desktop"; "" if none
func desktop_pending() -> bool                      ## next_desktop_item() != ""
func new_desktop_count() -> int                     ## unlocked, unseen, not-done items with app "mail"/"messages"
func phone_item() -> String                         ## first unlocked, not-done item whose current surface is "call"; ""
func phone_incoming() -> bool
	## phone_item() != "" and item_step_index(phone_item()) == 0 and item_step(phone_item()).get("wait_for", "") == ""
func all_links() -> Dictionary                      ## link id -> url over all unlocked items
func link_owner(link_id: String) -> String          ## item id owning that link ("" if none)

# --- the selected item's current step (same names and meaning as today) ---
func step() -> Dictionary                           ## {} if none selected or done
func required() -> Array                            ## item.required_inspections if its step == 0, else []
func missing() -> Array                             ## required() minus inspected, in required_inspections order
func gate_open() -> bool
func mark(key: String) -> bool                      ## "link:<id>" -> credited to link_owner(id); other keys -> selected item. True the first time
func is_disabled(index: int) -> bool
func disable_choice(index: int) -> void
func advance_to(next: int) -> void                  ## sets step, clears disabled, ticks and tried
func waits_for_telephone() -> bool                  ## step().get("wait_for", "") == "telephone"
func gate_hint() -> String                          ## A.5: full -> "Inspect first: " + names of missing(); generic -> "Inspect before you decide."; none -> "Responses locked."; gate open -> "Choose a response."
func resolve_current() -> void                      ## marks the selected item done
func all_done() -> bool                             ## every item done = chapter complete

# --- checklist (selected item's current step) ---
func is_checklist() -> bool                         ## step().get("kind", "choices") == "checklist"
func ticks() -> Array[int]
func set_ticks(t: Array[int]) -> void               ## stored sorted (a typed copy)
func tried() -> Array                               ## Array of sorted Array[int] already submitted wrong
func can_submit(t: Array[int]) -> bool              ## not empty, t.size() < options.size() (not every box), sorted(t) not in tried()
func checklist_hint(t: Array[int] = []) -> String
	## the ONE checklist hint string, used by both UIs:
	## t.size() == options.size()  -> "Tick only the real warning signs."
	## sorted(t) in tried()        -> "You already sent that report. Change your ticks."
	## else                        -> "Tick every warning sign you found, then submit."
func check(t: Array[int]) -> Dictionary             ## {"correct": bool, "missed": Array[int], "decoys": Array[int]} (option indices)
func record_try(t: Array[int]) -> void
func checklist_feedback(result: Dictionary) -> String
	## lines joined by "\n":
	##   "Not quite: your report does not match the evidence."
	##   one "Not a warning sign: <text>. <why>" per ticked decoy (the player's own wrong ticks are explained)
	##   if missed > 0: "You missed %d warning sign(s). Look again at what you inspected and at the wording."
	##   "Change your ticks and submit again."
	## It never names a missed real sign (that list is on the chapter feedback screen).
func checklist_log_text(result: Dictionary) -> String
	## "Warning-sign report: correct" or "Warning-sign report: %d missed, %d not signs"

# --- tracking (Objective 7) ---
func task_list() -> Array[Dictionary]               ## [{"text": String, "done": bool, "item": String}] per A.7, listed tasks only, data order
func task_count() -> int                            ## all tasks of all items, locked or not (5 / 6 / 6 / 6). Pure: callable on a fresh session
func tasks_done() -> int                            ## number of done entries in task_list()
func task_label_for_step(item_id: String, step: int) -> String
	## the task of the nearest step at or before `step` that has one, else item.task (used by the feedback screen)
func objective() -> String
	## phone_incoming() -> "Answer the ringing telephone"
	## elif phone_item() != "" -> item_step(phone_item()).wait_objective
	## elif desktop_pending() -> "Check your email at your workstation" (next desktop item app "mail")
	##                           or "Check your messages at your workstation" ("messages")
	## else ""
func failure_context() -> Dictionary                ## chapter.duplicate() with the selected item's bad_ending / warning_signs / tip overriding
```

### C.3 `Game` autoload (builder 2)

```gdscript
func apply_outcome(outcome: String, step: int, choice_text: String, item_id: String = "") -> int   ## log entry gains "item"
func item_log(n: int, item_id: String) -> Array[Dictionary]
func item_total(n: int, item_id: String) -> int
func item_max(item: Dictionary) -> int      ## CORRECT x (length of the longest chain of correct decisions from step 0)
	## best(i) = CORRECT + max(0, best(next_step) over the correct choices of step i / the checklist's next_step)
	## terminates because every next_step > its index (invariant 8)
func chapter_max(n: int) -> int             ## sum of item_max over the chapter's items + COMPLETE  (= 80 each)
func max_score() -> int                     ## sum of chapter_max(1..4)  (= 320)
```
Log entry: `{"chapter", "item", "step", "choice", "delta", "reason"}`; the completion entry has `"item": ""`.
Everything else (`start_new_game`, `begin_chapter`, `complete_chapter`, `next_chapter`, `restart_chapter`,
`chapter_total`, `chapter_log`, constants, `score_changed`) is unchanged.

### C.4 `office.gd` (builder 2) — flow changes

New / changed private flow (names are guidance; the public hooks in D.1 are binding):

- `_build()`: also connect `desktop.item_selected -> _on_item_selected`, `desktop.checklist_submitted -> _on_checklist_submitted`, `call_ui.checklist_submitted -> _on_checklist_submitted`.
- `_start_chapter(n)`: **`hud.set_tasks([], 0)` before the briefing** (the HUD must not show the previous chapter's tasks); as today up to the briefing; then `_update_world()` instead of the device branch; ACTIVE.
- **`_update_world()`** (call after every transition):
  - telephone: enabled iff `session.phone_item() != ""` and the call is not open; prompt = `"Answer the telephone"` if `phone_incoming()`, else that step's `trigger_prompt`; `disabled_prompt = session.objective()`.
  - workstation: enabled iff `session.desktop_pending()`; prompt `"Use workstation"`; `disabled_prompt = session.objective()`.
  - `builder.set_phone_ringing(session.phone_incoming() and not call_ui.is_open())`; if ringing just started and the desktop is open, `desktop.notify("Your desk phone is ringing")`.
  - `builder.set_monitor_alert(n > 0 and not desktop.is_open(), n)` with `n = session.new_desktop_count()`.
  - `hud.set_objective(session.objective())`, `hud.set_tasks(session.task_list(), session.task_count())`, `hud.refresh()`.
- `_use_device`: workstation opens when enabled and the desktop is closed (no longer requires the "current step" to be desktop). Telephone opens when enabled.
- `_open_workstation()`: if `session.item_id` is "" or done or its surface is not "desktop", `session.select_item(session.next_desktop_item())`; then as today.
- `_open_telephone()`: `session.select_item(session.phone_item())`, then as today (close the desktop first), then `_update_world()`.
- **`_on_item_selected(id)`**: ignored unless ACTIVE, not busy and the desktop is open; `session.select_item(id)` (only items whose app is mail/messages), `desktop.refresh()`, `_update_world()`.
- `_on_inspected(key)`: unchanged (`session.mark(key)` already routes link keys); then `_refresh_surfaces()` and `_update_world()`.
- `_can_choose(index)`: as today, plus: the step's surface must be the open surface (`desktop` -> desktop open, `call` -> call open); not a checklist step.
- `_resolve_choice(index)`: `Game.apply_outcome(outcome, session.step_index, choice.text, session.item_id)`; correct with `next_step` -> `await _advance_step(choice)`; correct without -> **`await _resolve_item(); return`**; wrong / unsafe as today.
- **`_on_checklist_submitted(ticked)`** -> `_resolve_checklist(ticked)`: guard `_can_submit(ticked)` (ACTIVE, not busy, `session.is_checklist()`, gate open, the step's surface open, `session.can_submit(ticked)`); `session.set_ticks(ticked)`; `result = session.check(ticked)`; outcome `correct`/`wrong`; `Game.apply_outcome(outcome, session.step_index, session.checklist_log_text(result), session.item_id)`; feedback = `step.feedback` if correct else `session.checklist_feedback(result)`; outcome panel; await; correct -> `await _advance_step(step)` if the step has `next_step`, else **`await _resolve_item(); return`**; wrong -> `session.record_try(ticked)`, unlock + refresh, ACTIVE.
- **`_advance_step(src: Dictionary)`** (coroutine; `src` is the choice or the checklist step): `session.advance_to(src.next_step)`; `opens` -> set `session.page` and call `desktop.show_page(page)` if the desktop is open (the only place a Browser page is shown automatically); then
  - new step waits for the telephone -> unlock + refresh the desktop (it shows the wait objective);
  - new step surface `call` and the call is open -> `call_ui.open_session(session)` (plays the next lines);
  - **new step surface `desktop` and the call is open** -> cinematic: `call_ui.close()`, `await player.focus_camera_on(builder.monitor_point, FOCUS_TIME)`, `desktop.open_session(session)` (opens on the item's own app, C.7);
  - else unlock + refresh. Then `_update_world()`, ACTIVE, not busy.
- **`_resolve_item()`**: `session.resolve_current()`; **`if session.all_done(): await _complete_chapter(); return`** (unchanged: +20, feedback, next chapter or ending; nothing after it may touch state, the mouse or `_busy`, because after Ch4 the state is LEAVING and the scene is changing). Only when not all done: if the call is open -> cinematic `call_ui.close()` + `await player.release_camera(RELEASE_TIME)`; else unlock + refresh the desktop; then `_update_world()`, `_set_state(S_ACTIVE)`, `_busy = false`.
- `_compromise(choice)`: `game_over.show_game_over(session.failure_context(), Game.score)`.
- `_stay_on_step`: `response_line` on an open call -> `call_ui.add_line(_caller_name(), line)` where `_caller_name()` = step `call_name`, else `session.item().get("call", {}).get("caller_name", "")`, else `message.from_name` / `sender_label`.
- `_begin()` (restart aim) unchanged: it reads `Campaign.chapter(n).device`.

### C.5 Signals between modules (exact)

| Emitter | Signal | Receiver |
|---|---|---|
| DesktopUI | `inspected(key: String)` (unchanged; paste emits `"link:<id>"` for any link in `session.all_links()`) | office `_on_inspected` |
| DesktopUI | `choice_selected(index: int)` (unchanged) | office `_on_choice_selected` |
| DesktopUI | `close_requested` (unchanged) | office |
| DesktopUI | **`item_selected(item_id: String)`** | office `_on_item_selected` |
| DesktopUI | **`checklist_submitted(ticked: Array[int])`** | office `_on_checklist_submitted` |
| CallUI | `inspected(key: String)`, `choice_selected(index: int)` (unchanged) | office |
| CallUI | **`checklist_submitted(ticked: Array[int])`** | office `_on_checklist_submitted` |
| ChecklistView | `ticks_changed(ticked: Array[int])`, `submitted(ticked: Array[int])` | its host (DesktopUI / CallUI) |

UI modules may write only these session fields: `clipboard`, `pasted_url`, `page` (desktop, when the player navigates
the Browser), and `set_ticks()` (desktop and call). Selection, inspections, steps and outcomes are changed only by the office.

### C.6 `office_builder.gd` (builder 2, two small changes)

- `set_phone_ringing(on)`: return early if `on` equals the current state (`_update_world` calls it often; the ring must not restart).
- `set_monitor_alert(on: bool, count: int = 1)`: the label shows `"%d new" % count`. Existing callers keep working.

### C.7 `desktop_ui.gd` (builder 3)

Public API: today's (`open_session`, `refresh`, `set_choices_locked`, `show_page`, `handle_back`, signals) **plus**
`signal item_selected(item_id: String)`, `signal checklist_submitted(ticked: Array[int])`, `func notify(text: String) -> void` (shows the existing toast).
Uses `const ChecklistView := preload("res://scripts/ui/checklist_view.gd")`.

- **`open_session(s)`**: store the session; **always** select the app of `session.item()` (`mail` / `messages`); `refresh()`; `show_overlay()`. It never selects the Browser by itself: the Browser keeps `session.page` and `session.pasted_url` and shows them when the player clicks the Browser rail button. Pages are switched to automatically only by `show_page()` (called by the office for `opens` while the desktop is open).
- **`refresh()`**: if the selected id or the set of available / done ids changed since the last build, rebuild the rail badges, the Mail and Messages lists and the reading panes **deferred** (`call_deferred("_rebuild")`), so a button's own `pressed` callback never frees the node that emitted it and the reading pane does not lose its scroll; otherwise update in place (DecisionBar, lock state, task counter, sender/quote visibility). Keeps the Browser state.
- **New-message toast**: when a session is opened for the first time (a new `ChapterSession` object), record all currently available ids as known, with no toast. Afterwards toast `"New message: <from_name or sender_label>"` only for ids that become available later.
- **Top bar**: add a label `"Tasks %d/%d" % [session.tasks_done(), session.task_count()]` left of the user address. The clock shows the latest `time` among available mail/messages items (`"08:00"` if none), instead of a fixed `09:00`.
- **Rail badges**: per app, the number of available, not-done items in that app (hidden when 0); the badge text is `str(count)`.
- **Mail app**: the inbox list = `session.available_items("mail")` in data order, inside a **ScrollContainer** (`SIZE_EXPAND_FILL`, `custom_minimum_size.y = 0`). Each row is one **56 px** `Button` **named `"Item_<id>"` with empty `text`** (labels are children with `MOUSE_FILTER_IGNORE`, so tests' text searches never hit a row): status glyph (`•` new in ACCENT, nothing when open, `✓` done in GOOD), a 28 px avatar tile, `from_name` on the first line (full width, so display names are not cut), then the `subject` on a second line trimmed with an ellipsis (`text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`, 13 px), `time` right-aligned. Selected row has the ACCENT border; done rows `modulate.a = 0.7` but stay clickable to reread. Header `"Inbox"` + `"%d new"`. Pressing a row emits `item_selected(id)`. The reading pane (in its own ScrollContainer, as today) renders the selected item if its app is `mail` (today's layout: subject, From button -> details with From and Reply-To, To, body); otherwise a `"Select a message"` placeholder.
- **Messages app**: the same list pattern (ScrollContainer, 56 px two-line rows `"Item_<id>"`, `sender_label` over a trimmed plain-text preview, `time`); the conversation pane renders the selected item if its app is `messages` (today's header with the sender button -> number + info, and the bubble).
- **Coworker items** (`kind == "coworker"`): below the body (mail) or below the bubble (messages) a quote block: PanelContainer with a left accent border, the `quote.label` heading, a link-style `Button` `"Show forwarded details  ▾"` (`▴` when open) that reveals `quote.details` in monospace; then `quote.body` rendered with `_body()` (its links get Copy link address like any other).
- **Sender and quote reveal state**: a local toggle per rendered item, **initialized** to `session.inspected.has(key)` when the item is rendered, so it stays collapsible; `inspected(key)` is emitted only when it is opened.
- Sender key per item: `"sender_number"` if the item's app is `messages`, else `"sender"`.
- **Links**: `_message()` = `session.item().get("message", {})`. **Paste**: `session.pasted_url = session.clipboard`; if it equals any URL in `session.all_links()`, emit `inspected("link:" + id)` for that id.
- **DecisionBar** for `session.item()`:
  - none selected -> question `"Select a message to work on."`, no choices, empty hint;
  - item done -> question `"Done: " + item.task`; hint `"Select another message."` if `session.desktop_pending()`, else `"All messages handled. Leave the desk (Esc)."`;
  - waits for the telephone -> today's behavior (wait objective, "Leave the desk (Esc) to use your desk phone.");
  - **checklist** -> question = `step.question`; hide the choice flow; show a `ChecklistView` built with `setup(step, session.ticks(), session.tried(), 2, 200.0)`, `set_locked(_locked or not session.gate_open())`; `ticks_changed` -> `session.set_ticks(t)` and hint = `session.checklist_hint(t)`; `submitted` -> `checklist_submitted.emit(t)`; initial hint `session.checklist_hint(session.ticks())`;
  - choices -> today's behavior, but the choice buttons sit in an **HFlowContainer**, each with `autowrap_mode = AUTOWRAP_WORD_SMART` and `custom_minimum_size.x = 360`, so 4 long choices take at most 2 rows of 1-2 lines; the hint text comes from `session.gate_hint()` (`"Responses locked."` in Ch4 while locked).
- `set_choices_locked(locked)` also locks the ChecklistView.
- **Vertical budget at 1280x720**: about 624 px for the app area plus the DecisionBar. The lists and the reading pane scroll; the DecisionBar (question + choices or checklist + Submit + hint) must always end inside the viewport. Smoke check in D.3 (k).

### C.8 `checklist_view.gd` (builder 4, NEW; no `class_name`)

```gdscript
extends VBoxContainer
## Tick-box report of warning signs (no typing). Used inside the DecisionBar and the Call UI.
## Hosts: const ChecklistView := preload("res://scripts/ui/checklist_view.gd")

signal ticks_changed(ticked: Array[int])
signal submitted(ticked: Array[int])

func setup(step: Dictionary, ticked: Array[int], tried: Array, columns: int = 2, scroll_height: float = 200.0) -> void
	## Builds its children immediately (does not rely on _ready):
	##   ScrollContainer (custom_minimum_size.y = scroll_height, horizontal scroll off)
	##     GridContainer (columns = `columns`, SIZE_EXPAND_FILL)
	##       one CheckBox per step.options[i]: name "Check_%d" % i, text = option.text, 14 px font,
	##       focus_mode FOCUS_NONE, autowrap_mode AUTOWRAP_WORD_SMART, SIZE_EXPAND_FILL, custom_minimum_size.x = 1
	##   Submit Button BELOW the scroll (always visible): UIStyle.button, name "Submit",
	##   text = step.get("submit_text", "Submit report")
	## Pre-ticks `ticked`. Toggling emits ticks_changed(sorted ticks) and updates Submit.
func set_locked(locked: bool) -> void       ## disables every CheckBox and Submit
func get_ticked() -> Array[int]            ## sorted
## Submit is enabled iff not locked, at least one box is ticked, NOT every box is ticked, and the sorted ticks are
## not in `tried`. Pressing it emits submitted(get_ticked()). It never shows which options are real.
```

### C.9 `call_ui.gd` (builder 4)

- Add `signal checklist_submitted(ticked: Array[int])`. Uses `const ChecklistView := preload("res://scripts/ui/checklist_view.gd")`.
- Call data comes from **`session.item().get("call", {})`** (not `chapter.call`): header inspectable iff that dictionary is not empty and `session.step_index == 0`; `_step_lines()` = `call.lines` at step 0, else `step.call_lines`.
- `_caller()`: `step.call_name` if present; else `call.caller_name` if the item has a call; else the parsed header (today's fallback).
- `open_session(s)`: `same_call := s == session and is_open() and s.item_id == _rendered_item` (new field); clear the transcript when it is not the same call. When the step's `call_header` differs from the last rendered one within the same call, append a small divider line (e.g. `"— EXT 1200: SECURITY OFFICE —"`, muted) before playing the new lines.
- Status chip: `"Incoming call"` (step 0 of a call item), `"Outgoing call"` (a `wait_for` step), `"Call ended"` (no `call_lines` and no `call_name`), else `"On call"`.
- The phone card lists all four `Campaign.PHONE_CARD` lines (B).
- **Checklist step**: question = `step.question`; instead of choice buttons, a `ChecklistView` in the decision column built with `setup(step, session.ticks(), session.tried(), 1, 260.0)` (**single column**, 14 px); **the phone card is hidden while `session.is_checklist()`**; locked while playing / locked / gate closed; `ticks_changed` -> `session.set_ticks` and hint = `session.checklist_hint(t)`; `submitted` -> `checklist_submitted.emit`. Pressing Submit appends a "You" line `"(tells Security the warning signs)"`. The Submit button must lie inside 1280x720 (D.3 (k)).
- The gate hint uses `session.gate_hint()` (full, generic or "Responses locked.").

### C.10 `hud.gd` (builder 4)

- New `func set_tasks(tasks: Array[Dictionary], total: int) -> void`: a panel under the chapter pips (top-right) with a header label `"Tasks %d/%d" % [done, total]` (done = count of `done` in `tasks`) and one line per task: `"✓ " + text` (GOOD) or `"• " + text` (TEXT). Hidden when `tasks` is empty (so `set_tasks([], 0)` hides it during briefings). `mouse_filter` IGNORE like the rest of the HUD.
- `refresh()` unchanged otherwise.

### C.11 `feedback_screen.gd` (builder 4)

`show_feedback(chapter)` (same signature): keep title, debrief, warning signs (chapter level, the full list, FR9), tip.
Replace the flat breakdown with **per-task results, matching the HUD's task list**: for each item of `chapter.items` in
data order, a header row `item.task + "  ·  " + role label` (role labels: genuine -> "Genuine", fake -> "Fake",
main -> "Main attack", coworker -> "Coworker") with `Game.item_total(n, item.id)` on the right. Under it, the item's
`Game.item_log(n, id)` entries **grouped by task label** (`session`-free: use
`ChapterSession.new(chapter).task_label_for_step(id, entry.step)`): one `"✓ <task label>"` sub-header per group, then
its lines indented (`choice` text and the signed delta). Then `"Chapter (scenario) complete  +20"`, then
`"Chapter score: %s / %d" % [signed total, Game.chapter_max(n)]` and the totals line.
Put the rows in a ScrollContainer with **`custom_minimum_size.y = 300`** (inside a CenterContainer an expand flag gives it
no height). The whole card stays under 700 px (Ch4: 5 warning signs + 3-line debrief + tip + 300 px scroll + buttons).

### C.12 `ending.gd` (builder 4)

- Final score tile: `"%d / %d" % [Game.score, Game.max_score()]` (no `Campaign.MAX_SCORE`).
- Per-chapter breakdown: each chapter row shows title, complete/incomplete, `Game.chapter_total(n)` / `Game.chapter_max(n)`; under it one compact line per item: `"✓ <task>  <signed Game.item_total(n, id)>"`. Wrap the breakdown in a ScrollContainer with **`custom_minimum_size.y = 220`**.
- Keep "Chapters completed: N of 4". Add a tile `"Tasks completed: %d of %d"`: the total is `ChapterSession.new(Campaign.chapter(n)).task_count()` summed over n = 1..4 (23; the rule lives only in ChapterSession, never re-implemented here). Done = the same sum over chapters with `Game.completed[n - 1]` true (a chapter is only complete when all its tasks are done).

### C.13 `instructions_panel.gd` (builder 4)

HOW TO PLAY becomes (wording final):
1. "Walk to your workstation or the telephone and press E."
2. "Each chapter is a workday with several tasks. Some messages and calls are real and some are attacks. The task list at the top right shows your progress."
3. "Inspect before you decide. Click the sender to see the full address. Click a link, choose Copy link address, then open the Browser and Paste to read where it really goes. On a call, check the caller ID."
4. "The responses unlock once you have checked the sender (or caller ID), pasted every link in the Browser, and opened any forwarded details. Handle real messages normally: reporting or deleting a real one counts as a wrong action."
5. "When something seems off, verify it through a channel you already trust: the Staff Directory, the official SwiftParcel site, or a known extension on your desk phone."
6. "When you report an attack, tick exactly the warning signs you found. Coworkers may ask for your advice too. Later chapters give fewer hints."

Passing box: "Finish every task in all four chapters safely to pass the Vigilant Protocol." SCORING: the `Game.COMPLETE`
row label becomes **"Chapter (scenario) complete"**; the other rows and the controls are unchanged.

### C.14 `tests/capture.gd`, `tests/capture_play.gd` (builder 2, after the smoke test passes)

Both read `Campaign.chapter(n).message` and click links on a desktop that now needs a selected item. Switch them to
`Campaign.item(n, "<main item id>").get("message", {})` and call `office.debug_select_item(id)` before clicking a
sender or calling `_open_link_menu("c1_portal")`. They compile either way (untyped access) and are not part of the
smoke test; if time is short, leave them and mark them "not maintained" in `CONTRACT.md` at the merge.
Status: `tests/capture.gd` is ported (all 16 items through the real buttons, PNGs in `tests/shots/tasks/`) and
`tests/capture_menu_tasks.gd` covers the instructions panel and a coworker game over. `tests/capture_play.gd` still
reads the old one-message keys and is obsolete: do not run it.

### C.15 Review fixes (after the merge; all inside Objectives 1-7)

- `office.gd`: a correct choice's `opens` also works on a choice that resolves the item (`c2_delivery`); a correct
  call choice's `response_line` ("IT Helpdesk: ...") is added to the call transcript under a divider named from the
  phone card (`CallUI.add_reply(line)`, "— EXT 1100: IT HELPDESK —") before the next call part plays; sitting down at
  the desktop while the phone already rings shows the toast "Your desk phone is ringing", and a finished desktop
  then says "Your desk phone is ringing. Leave the desk (Esc).".
- `desktop_ui.gd`: the toast sits in the empty left part of the top bar (after "Aegis Workstation", growing right), so
  it never hides "Tasks D/T" or the Browser address bar; inbox rows are two-line (name over subject); bubbles take 80 %
  of the thread and a coworker's forwarded block is full width; on a Messages checklist step the revealed number is
  folded (the header button reopens it); the DecisionBar checklist scroll is 184 px.
- `call_ui.gd`: the call checklist scroll is 320 px (all seven options visible; the phone card is hidden there).
- `checklist_view.gd`: unticked boxes use a light outline icon. `hud.gd`: "+ N more later" under the listed tasks.
- `ending.gd`: item lines show their sub-task count ("Check the benefits email  (2 tasks)"), so they add up to
  "Tasks completed: 23 of 23". `compromise_notice.gd`: the title has no second warning icon.
- `chapter_session.gd`: wrong report log line "Warning-sign report: N missed, M wrongly ticked".

---------------------------------------------------------------------------------------------------------------------

## D. Test hooks and smoke-test scenarios

### D.1 Hooks on `office.gd` (public; the old ones keep working)

| Hook | Behavior |
|---|---|
| `var state`, `var session`, `debug_state()` | unchanged |
| `debug_interact(device_id)` | unchanged (coroutine; telephone closes the desktop first) |
| `debug_inspect(key)` | `_on_inspected(key)`: credited to the selected item (links to their owner) |
| `debug_choose(index)` | the selected item's current step; ignored (printed) when locked/disabled/wrong surface |
| `debug_advance()` | unchanged |
| **`debug_select_item(id: String) -> bool`** | same as clicking the inbox row: only while ACTIVE, not busy, the desktop open and `id` an available mail/messages item; returns success |
| **`debug_check(indices: Array[int]) -> void`** | same as ticking exactly those boxes and pressing Submit: first `_can_submit(indices)` (which includes `session.can_submit`); if false, print and return **without** touching the ticks; else `_resolve_checklist(indices)` |
| **`debug_item() -> String`** | `session.item_id` |
| **`debug_tasks() -> String`** | `"%d/%d" % [session.tasks_done(), session.task_count()]` |

### D.2 Driver rules for the rewritten `tests/smoke_test.gd`

- `TOTAL_TIMEOUT` 600 s, `WAIT_TIMEOUT` 15 s. Headless viewport is 1280x720.
- **Play an item** (generic, from data): if `item.app == "call"` -> `await debug_interact("telephone")`, skip the call lines; else open the desktop if closed (`debug_interact("workstation")`) and `debug_select_item(id)`. Check the gate (choices / checklist locked, hint per `hint_level`), inspect every `required_inspections` key, then follow the path: at each step, if `wait_for` -> `await debug_interact("telephone")`; `choices` -> (wrong-first: each wrong in order, checking -5, ACTIVE, disabled, cannot re-pick) then the first correct; `checklist` -> (wrong-first: `debug_check(W)` where W = the real indices minus the first one plus the first decoy, checking -5, feedback contains `"Not a warning sign"` and `"You missed 1"`, then `debug_check(W)` again is ignored with the score unchanged) then `debug_check(real indices)`; next step = the picked choice's `next_step`. After a call-to-desktop step, `_wait(desktop.is_open() and state == "ACTIVE")`.
- **Play a chapter**: repeatedly play the first available, unresolved item in data order until FEEDBACK.

### D.3 Scenarios (each starts a new game)

| # | Scenario | Key checks |
|---|---|---|
| (i) | **Data validation** (no scene) | the 14 invariants of A.4; 4 chapters in order with titles Email Phishing, Smishing, Vishing, Business Email Compromise; exactly one `main` item each; `Game.chapter_max` = [80, 80, 80, 80], `Game.max_score()` == 320; `ChapterSession.new(ch).task_count()` = [5, 6, 6, 6]; no British spellings in any string ("enrolment", "favour", "misspelt", "colour", "behaviour", "cancelled") |
| (a) | **Best run** | every item via first-correct + exact checklist; `chapter_total(n) == chapter_max(n)` for n = 1..4; final score 320 == `Game.max_score()`; `all_complete()`; after the Ch4 feedback Continue, `state == "LEAVING"` on every frame until the ending scene loads (no ACTIVE, mouse not captured); the ending scene shows `"320 / 320"` and `"Tasks completed: 23 of 23"` |
| (b) | **Wrong-first run** | chapter totals [30, 20, 30, 25]; final 105; ending scene |
| (c) | **Gate per chapter** (inside (a)) | for the first item in data order of every chapter (`c1_orientation`, `c2_redeliver`, `c3_facilities`, `c4_supplier`): choose before inspecting -> no score, state ACTIVE, buttons disabled; Ch1: hint `"Inspect first: sender, link (copy it and paste it in the Browser)"`, after inspecting the sender the hint is `"Inspect first: link (copy it and paste it in the Browser)"` and still locked; Ch2/Ch3: `gate_hint() == "Inspect before you decide."` and it is visible; Ch4: `gate_hint() == "Responses locked."` and no visible text on the desktop contains `"Inspect"`; after all inspections the buttons are enabled and the hint is `"Choose a response."` |
| (d) | **Unsafe + restart in Ch2** | best Ch1 (80); Ch2 select `c2_redeliver`, inspect, choose the unsafe choice -> OUTCOME -> COMPROMISED -> GAME_OVER; score 75; the game-over text is Ch2's `bad_ending`; desktop and call closed; press the real Restart Chapter button -> new office, score 80, chapter 2, intro skipped, chapter-2 log empty, chapter 1 still complete, spawn at the desk; play Ch2 best -> 160; Ch3 starts next |
| (d2) | **Unsafe in a coworker item uses its override** | best Ch1 up to `c1_coworker`, choose its unsafe choice -> the game-over text equals `c1_coworker.bad_ending` |
| (e) | **Checklist rules** (Ch1 `c1_benefits` step 3, reached by the verify route) | `debug_check([0..6])` (every box) -> ignored, score unchanged, `checklist_hint([0..6]) == "Tick only the real warning signs."` and the real Submit button is disabled with every CheckBox pressed; `debug_check([0, 1, 2, 3])` (sign 5 missing, decoy 1 ticked) -> -5, outcome feedback contains `"Not a warning sign: It was sent to your work address"` and `"You missed 1 warning sign(s)"` and does **not** contain `"aegis-benefits-verify"` (missed signs are not named), still step 3, ACTIVE; the same set again -> ignored, score unchanged; `debug_check([0, 2, 3, 5])` -> +10, item done, `c1_coworker` becomes available; the CheckBoxes `Check_0`..`Check_6` and the `"Submit report"` button exist in the desktop |
| (e2) | **Equal routes** | Ch1 `c1_benefits` by the report route (step 0 "Report it to Security as phishing now" -> step 2 "Delete the email" -> step 3 exact): `Game.item_total(1, "c1_benefits") == 30 == Game.item_max(...)`, the telephone was never needed; Ch3 `c3_mark` by the Security route (step 1 "Report the call to Security (ext. 1200)") -> step 2 checklist; item total 30 |
| (f) | **Genuine item reported = -5** | Ch1 `c1_orientation`: choose "Report it to Security as phishing" -> -5, wrong, disabled; "Open the agenda link and keep the email for Thursday" -> +10; item done; `debug_tasks() == "1/5"`; the inbox row `Item_c1_orientation` shows `✓` |
| (g) | **Order rules** | Ch1: `c1_coworker` not in `available_items()` and not on screen until `c1_benefits` is done; chapter not complete with 3 of 4 items done (state ACTIVE, no FEEDBACK); Ch1 step-1 wait: telephone enabled with prompt "Call HR (ext. 1300)", then the call -> after the correct choice the desktop reopens with `desktop._app == "mail"` (not the Browser, although `session.page == "directory"`), `debug_item() == "c1_benefits"`, showing the checklist; Ch2: the inbox order is `c2_redeliver`, `c2_delivery`, `c2_access`; Ch3: phone rings at start (`c3_facilities`), workstation disabled; after Facilities the phone rings again for `c3_mark`; during `c3_mark` steps 1-2 `phone_incoming()` is false; after `c3_mark`, the phone rings for `c3_security` **and** the workstation is enabled for `c3_coworker`; the HUD shows `"Tasks D/T"` matching `debug_tasks()`; during the Ch2 briefing the HUD task panel is hidden |
| (h) | **UI inspections through real controls** (Ch1-3 main items) | press the row `Item_<id>`, the sender button (or the caller ID button), the coworker `"Show forwarded details"` button for `c1_coworker`, Copy link address + Paste; the gate opens; finish the item with the real buttons and the real ChecklistView; score after Ch1-3 best = 240 |
| (j) | **Scope guard** | no `LineEdit`, `TextEdit`, `CodeEdit`, `SpinBox`, `FileDialog` anywhere in the office tree; no RichTextLabel with `selection_enabled`; HUD and menus still instantiate |
| (k) | **Layout at 1280x720** (inside (a) and (e)) | after every desktop refresh that shows a choices or checklist step: the DecisionBar's `get_global_rect().end.y <= 720` and, on a checklist, the Submit button's global rect lies inside the viewport; on the Call UI checklist (`c3_mark` step 2) Submit lies inside the viewport and the phone card is hidden; after the worst-case wrong submit (`c4_supplier` step 2 with only the 3 decoys ticked) the outcome panel's Continue button lies inside the viewport; on the feedback screen and the ending the breakdown ScrollContainer has rect height > 0 and Continue lies inside the viewport |

---------------------------------------------------------------------------------------------------------------------

## E. Traceability and what we are NOT adding

### E.1 Every new task -> the paper

| New task / mechanic | Objective | Scope module | Paper line it serves |
|---|---|---|---|
| Inbox / thread / phone triage (3-4 items per channel, genuine + fake) | 3, 4, 5 | 3 Simulated Desktop; 4 Interactive Scenario; 5 Decision Based Gameplay | Obj. 5 "users inspect each situation ... before selecting from predefined actions"; GDD 11 "recognizing suspicious senders and links"; GDD 7 "inspects each scenario before choosing" |
| Genuine items (handling them normally is correct; reporting/deleting them = -5 because the evidence showed they were genuine) | 5, 6 | 5, 6 Consequence Simulation | Obj. 5 "inspect each situation ... before selecting"; GDD 11 "recognizing suspicious senders and links ... making safer decisions"; GDD 5 "increasingly convincing attacks" (telling real from fake is what makes them convincing); FR7 "-5 for a wrong action". The feedback says reporting is never dangerous (Scope 7 correct guidance) |
| More fakes of the same attack type per chapter | 4 | 4 | Obj. 4 / Scope 4 "four fixed, scripted chapters"; GDD 5 "increasingly convincing attacks"; Limitation 3 (content fixed, same four types) |
| Main attack (same scenario, same classes) | 4, 5, 6 | 4, 5, 6 | GDD 8 chapter descriptions. Ch1 keeps the paper's action at step 0 ("checks the sender and the full link address, then reports or deletes the message"); the HR call is an equal-value alternative. Ch3 keeps both paper routes ("hang up and report the call or call IT back through a known number") at equal value |
| Report the red flags (checklist, no typing) | 5, 6, 7 | 5, 6, 7 Feedback and Tips | GDD 11 "the game explains the warning signs"; Obj. 5 "predefined actions" (tick boxes are predefined); FR9 "feedback and explanations" (the full sign list is on the chapter feedback screen) |
| Verify through a known channel (Staff Directory + HR ext. 1300, official SwiftParcel site, IT ext. 1100 / Security ext. 1200, Mr. Ramos ext. 2045) | 1, 3, 5 | 1 3D Environment (telephone); 3 (web pages); 5 | GDD 8 Ch2 "verifies delivery through the courier's official channel", Ch3 "call IT back through a known number", Ch4 "verifies the request through a known channel"; GDD 11 "verifying unusual payment requests"; Obj. 1 "interact with ... the telephone". Mandatory in Ch2 and Ch4 (as GDD 8 says); in Ch3 both correct routes are calls to known extensions; in Ch1 it is one of the two correct routes (GDD 8 Ch1 does not require it) |
| Help a coworker (a real colleague forwards Black Veil's attack of the chapter's own type) | 4, 5, 6 | 4, 5, 6, 7 | Obj. 5 "inspect each situation ... before selecting from predefined actions" (the player inspects the forwarded sender, link and details); GDD 11 "recognizing suspicious senders and links ... making safer decisions"; Scope 6 "an unsafe choice shows a compromise notification and game over" (the coworker's compromise is still Black Veil's goal achieved); Scope 7 "explains the result of each decision and provides cybersecurity guidance" (the advice is the guidance) |
| Per-item compromise text + bad ending override | 6 | 6 | Scope 6; GDD 10 bad ending "an unsafe choice results in a simulated company breach" (still the one bad ending) |
| Hint ramp full -> generic -> none | 5 | 5 | GDD 5 "increasingly convincing attacks"; choices stay locked until inspected (Obj. 5); the unlock rule is written in HOW TO PLAY (NFR1 clear interface) |
| HUD task list "Tasks D/T", desktop task counter | 7 | 8 Progress Tracking | Obj. 7 "track user performance through score and chapter completion"; GDD 12 "score and progress display" |
| Per-task results on the feedback screen and ending; max computed from data | 7 | 7, 8 | FR9, FR10 "track progress through score and chapter completion and show a good or bad ending"; Scope 7 "explains the result of each decision" |
| Instructions text update | 2 | 2 System Navigation | Obj. 2 "main menu with instructions" |

### E.2 What we are NOT adding (checked by review and test (i)/(j))

- No new chapters, no fifth attack type, no change of chapter order (Objective 4, Limitation 3, GDD 13).
- No USB, ID cards, sticky notes, QR codes, packages, fake login pages or credential forms, ads, pop-ups, downloads, attachments, software updates, in-person impersonation, NPC attackers, walking NPCs, office "security check" rounds (none of these are in GDD 8; Limitation 3 excludes other attacks).
- No adaptive, random, shuffled or AI-generated content: every item, option order and outcome is fixed data (Limitation 3).
- No free-text input (no LineEdit/TextEdit/CodeEdit/SpinBox); the checklist uses CheckBoxes (Limitation 9: predefined choices only).
- No OS clipboard (the in-game clipboard only), no `OS.shell_open`, no HTTP, nothing online (Limitation 1, NFR offline).
- No saving of progress, accounts or cloud (Limitation 6). Restart still rolls back to the chapter start in memory.
- No new endings: only the good ending and the bad ending (GDD 10). No neutral/perfect ending, no "coworker saved" ending.
- No timers, countdowns or time pressure mechanics; "5 minutes", "before it expires" are only words inside attack text (urgency as a warning sign).
- No new scoring values: +10 / -5 / +20 only; the checklist and coworker advice use the same values.
- No new devices or apps: still the workstation (Mail, Messages, Browser) and the desk telephone; no dialing keypad (calls to known extensions are a predefined choice or the existing `wait_for` telephone step). The phone card only lists the same extensions as the Staff Directory.
- No real brands, people or numbers: `.example` domains, masked numbers, role labels for coworkers ("Coworker - Sales"), Black Veil named in every compromise text and debrief.
- No low-poly art in this pass (it comes later and replaces `Visual` nodes only).
- The paper's old "Game Lore" section is not cited anywhere; GDD 5, 8, 10, 11 and 13 overrule it.

### E.3 Paper alignment notes (for the panel; optional paper edits)

- **Defense line**: "A scenario is a chapter: the paper uses 'four scripted scenarios' and 'four chapters' for the same thing. Each chapter contains several tasks of the same attack type, and the +20 is awarded once, when the chapter's scenario is complete. A safe choice still lets the player continue (Scope 6); the next chapter starts once every task of the current one is handled safely."
- **Optional sentence for GDD 8** (end of the chapter descriptions): "Each chapter also includes genuine messages to tell apart from the attack, a report of the attack's warning signs, and a coworker's question about an attack of the same type."
- The SCORING row on the instructions screen reads "Chapter (scenario) complete" (C.13), so the game's wording matches FR7 / GDD 9 "+20 for a completed scenario".
- **Interact key (paper edit recommended)**: GDD 7 says the player "presses F to interact"; the game, the instructions screen and the paper's own flowchart use **E** (the user's decision; the controls are still WASD / mouse / E / ESC). Edit GDD 7 to "presses E", or use the defense line: "Interaction moved from F to E so one key both interacts and advances dialogue, as in the flowchart."
- **Verify-through-a-known-channel in Ch1 (decision recorded)**: the agreed design asks for a verify step in every chapter. Ch2 (official courier site) and Ch4 (Mr. Ramos on ext. 2045) require it, and in Ch3 both correct routes are calls to known extensions (IT ext. 1100, which transfers you to Security, or Security ext. 1200). In **Ch1 it stays one of two equal correct routes** (Staff Directory + HR ext. 1300, or report at once), because GDD 8 Ch1 says the player "checks the sender and the full link address, then reports or deletes the message": marking an immediate report wrong would contradict the paper, and the paper wins (top rule). Defense line: "Chapter 1 follows GDD 8 exactly: reporting is correct, and verifying with HR first is an equally scored alternative that the briefing recommends." If the panel or the user wants it strict, the change is data-only: make `c1_benefits` step 0 "Report it to Security as phishing now" `wrong` and drop step 2 (wrong-first 105 -> 100).

## Addendum 2026-11-03: more items in later chapters
- Ch3 adds `c3_printer` (genuine call from IT ext. 1100, unlocks after `c3_security`). Ch4 adds `c4_delivery` (genuine Finance email about invoice KS-2231, no bank change, unlocks after `c4_giftcards`).
- Items per chapter: 4 / 4 / 5 / 5. HUD tasks: 5 / 6 / 7 / 7. Chapter max: 80 / 80 / 90 / 90 = **340**. Wrong-first: 30 / 20 / 25 / 20 = **95**.

## Addendum 2026-11-03 (b): Chapters 5 and 6 (requested by the user; this overrides "exactly four chapters" in E.2)
Six chapters in this fixed order: 1 Email Phishing, 2 Smishing, 3 Vishing, 4 BEC, **5 Social Media Impersonation**,
**6 QR Code Phishing**. Both are phishing-based social engineering on the desktop only (no posters, no NPCs, no free text),
`hint_level: "none"`. Briefings: Ms. Dela Vega says Black Veil escalated after the email/phone attacks failed.
`Game.CHAPTER_COUNT = 6` (checked against `Campaign.CHAPTERS.size()` in `Game._ready()` and the smoke test; GDScript
constants cannot call `size()`); `Game.completed` is sized from it.

**New app and content shapes.** Desktop rail: Mail, Messages, **Chat** (Kumusta Chat, fictional), Browser. Chat item
(`app: "chat"`, `kind: "chat"` or `"coworker"`): `message = {time, sender_label, handle, profile: [lines], body, links,
optional request {label, details}, coworker quote}`. An email may carry `qrs: {<qr id>: url}`, drawn as a deterministic
fake QR pattern (`scripts/ui/qr_code.gd`, cannot be scanned) with a **Preview QR link** button that shows the real
address (host highlighted) and "The website was not opened." New Browser page/bookmark `facilities`
(intranet Facilities page: parking access never needs renewing, staff parking is free, canteen menu link, ext. 1400).

**New inspection keys** (invariant 14 extended): `"profile"` (sender key of chat items: the name button opens the profile),
`"request"` (chat items with `message.request`: "Check the request"), `"qr:<id>"` (one per `message.qrs` entry; credited to
the owning item via `ChapterSession.qr_owner()`, like links). QR ids are unique and differ from item and link ids.

| Ch5 item | Role | Evidence | Correct | Unsafe |
|---|---|---|---|---|
| c5_lunch | genuine | saved contact @coworker_sales, on Kumusta Chat since 2021, 36 mutual friends; intranet link | reply you will join (4th) | none |
| c5_otp | main | same name, handle @coworker_sales_ph, 2 days old, 2 mutual friends, not in contacts; request = the code texted to your own phone | Directory + call Sales ext. 2110 (wait_for telephone) -> report and block -> checklist (5 real + 3 decoys) | send the code |
| c5_prize | fake | "Aegis Solutions HR" page 6 days old; form link on claim-form.example (personal details form) | report and block | fill in the form |
| c5_coworker | coworker (after c5_otp) | Admin's cousin on a day-old account, 0 mutual friends, "don't call", PayBuddy transfer | don't send, call her usual number, report | send it now |

| Ch6 item | Role | Evidence | Correct | Unsafe |
|---|---|---|---|---|
| c6_parking | main | sender aegis-facilities-desk.example; QR -> aegis-parking.qr-renew.example | call Facilities ext. 1400 (step 1) **or** intranet Facilities page (step 2), both -> report -> checklist (4 real + 3 decoys); equal value 30 | scan and re-register |
| c6_rice | fake | hr@aegis-solutons.example (missing i); QR -> aegis-solutions.rice-claim.example | report | scan and enter PayBuddy details |
| c6_menu | genuine | facilities@aegis-solutions.example; QR -> intranet.aegis-solutions.example/facilities/canteen-menu | scan to see the menu, keep it (1st) | none |
| c6_coworker | coworker (after c6_parking) | Marketing forwards billing@aegis-parking-office.example with a fee QR; Facilities page: staff parking is free | don't scan, call Facilities 1400, report | scan and pay |

**Scores** (computed): chapter max 80 / 80 / 90 / 90 / **80 / 80** = **500**. Wrong-first 30 / 20 / 25 / 20 / **20 / 20** =
**135** (Ch5: 3 + 5 + 2 + 2 = 12 wrong; Ch6: 5 + 2 + 3 + 2 = 12 wrong). HUD tasks 5 / 6 / 7 / 7 / **6 / 5** = **36**.
`Campaign.GOOD_ENDING` covers all six chapters ("helped six coworkers"). Smoke test: scenario (i) checks the extended
invariants, (a)/(b) run all six chapters, the gate is checked for every Ch5/Ch6 item ("Responses locked.", no visible
"Inspect"), and a new UI run starts at Ch5 (as Restart Chapter does) and plays Ch5-6 through the real Chat profile /
request buttons and Preview QR link, with c6_parking by the intranet route. Screenshots: `tests/capture_ch56.gd` ->
`tests/shots/ch56/`.
