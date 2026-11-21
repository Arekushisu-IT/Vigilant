# Vigilant: complete manuscript revision list (as of 2026-11-21)

For the colleague revising the paper. Every number comes from the finished game's data and its automated tests (5,920 checks pass).

**The game in one paragraph.**
- Vigilant is a Windows desktop game made in **Godot Engine 4.7.2 (GDScript)**, with **low-poly 3D** places modeled in **Blender**: the office, the player's home (a small condo) and a café.
- It has **10 chapters** over one work week (office chapters and "off the clock" Philippine chapters take turns), with **42 messages and calls** and **58 tasks**, and a **maximum score of 800**.
- At home and in the café the player uses their **phone** (Messages, Calls with a keypad, ChatLink chat, KwartaPay e-wallet, Browser, Mail, the BancoNation bank app, My Telco).
- **15 Fun Facts** about real scams in the Philippines, each naming its source, appear at chapter starts, on the results screen and on a Fun Facts page.
- Rewards: **10 chapter badges** and **10 achievements**. Help and navigation: a **guided tutorial**, **Chapter Select** (chapters unlock in order) and a **Review mode** for evaluators.
- All sound is generated in code. It runs offline and saves nothing to disk.

---

## A. Biggest changes (check these with your adviser first)

1. **Four chapters → ten chapters.** Social Media Impersonation and QR Code Phishing were added earlier. Now four **Philippine "off the clock" chapters** are added and the order changed (see section D). This changes **Objectives 1 and 4, Scope, Limitations 3 and 9, the RRL and GDD 6/8/13**.
   - **New places and a new device:** the player's home and a café, and the player's phone. Objective 1 must mention them.
   - **Philippine context:** e-wallet text scams, fake bank agents asking for OTPs, task scams and money mules (RA 12010, AFASA), and identity fraud. Each is backed by real PH sources (CICC, BSP, PSA, SEC, news) listed in `docs/PH-CHAPTERS-SCRIPT.md`. Add them to the RRL.
2. **New objective for badges and achievements.** The Google Forms evaluation becomes the last objective.
3. **Unity / C# → Godot / GDScript** everywhere, with Blender for the 3D models.
4. **Several tasks per chapter** instead of one message, plus a red-flag checklist, coworker advice and genuine messages.
5. **QR code phishing needs a real published source** in the literature review. None was added for you, so do not invent one.

---

## B. Objectives

### B1. Each objective and where the game applies it

| # | Objective | Applied in the game by | Revise? |
|---|---|---|---|
| 1 | 3D office, first-person movement, interact with the workstation and telephone | Low-poly 3D **office, home and café**, WASD + mouse look, **E** at the workstation, the desk phone and **the player's phone**, coworkers and café customers as background life, a usable pantry (coffee, water, notice board) | **Yes:** add the home, the café and the phone |
| 2 | Navigation interface: main menu with instructions and settings | Main menu: **Play** (Chapter Select), Instructions, Settings, Exit. Pause menu (ESC): Resume, Progress, Instructions, Settings, Chapter Select, Main Menu. A guided tutorial in Chapter 1 | **Yes:** add Chapter Select, the pause menu and the tutorial |
| 3 | Simulated desktop with email, messaging and web pages | Office desktop: Mail, Messages, **Chat**, Browser. **Phone:** Messages, Calls with keypad, ChatLink, **KwartaPay e-wallet**, Browser, Mail, BancoNation bank app, My Telco | **Yes:** add the chat app and the phone |
| 4 | Four scripted chapters | **Ten** chapters (six office, four Philippine "off the clock") | **Yes** |
| 5 | Inspect (sender, real link address) before choosing | Choices stay locked until inspected: sender, copy and paste a link in the Browser, caller ID, **chat profile**, **QR link preview**, coworker's quoted message | **Yes:** list the new inspections |
| 6 | Programmed rules: score, outcome notices, game over | +10 / −5 / +20, a result card after every choice, compromise notice + Game Over (bad ending), Restart Chapter, **−5 for over-reporting a genuine message, −5 for a wrong red-flag report** | **Yes:** add the two new rules |
| 7 | Track score and chapter completion | HUD score, "Chapter N of 10", progress dots, task list, feedback screen per task, **Progress page**, Chapter Select cards, ending summary | **Yes:** mention the task list and Progress page |
| 8 | Google Forms evaluation | Outside the game | Moves to **Objective 9**; update the form (section C, Appendix F) |

### B2. Copy-ready objective wording

- **Obj 2:** "Design and implement a navigation interface, including a main menu with chapter selection, instructions and settings, a pause menu, and a guided tutorial."
- **Obj 1:** "Develop low-poly 3D environments (an office, the player's home and a café) with first-person movement, where the user interacts with a workstation, a desk telephone and a personal mobile phone."
- **Obj 3:** "Create simulated desktop and mobile phone interfaces where scenarios are presented in formats resembling email, text messaging, a social chat application, an e-wallet, phone calls and web pages."
- **Obj 4:** "Develop ten scripted scenario chapters: email phishing, smishing, vishing, business email compromise (BEC), social media impersonation and QR code phishing in the workplace, and four Philippine scams outside work: e-wallet text scams, bank-agent OTP fraud, task scams with money muling, and identity fraud."
- **Obj 5:** "Implement decision-based gameplay in which users inspect each situation, such as checking the sender, the real address of a link or QR code, the caller ID, or a social media profile, before selecting from predefined actions, and distinguish genuine messages from fraudulent ones."
- **Obj 6:** add "…including penalties for over-reporting genuine messages and for incorrect warning-sign reports."
- **Obj 7:** "Track user performance through score, task and chapter completion."
- **New Obj 8:** "Implement a reward system of chapter badges and achievements that recognizes safe and accurate decisions."
- **Obj 9 (was 8):** the Google Forms evaluation, unchanged.

---

## C. Revisions, section by section

### Title page and Approval Sheet
- The paper title is unchanged. In the game, the main menu shows only "VIGILANT" and the tagline "Verify before you trust."; the long subtitle and the school footer were removed.
- Fix: the Approval Sheet title is missing "Vigilant:".

### Introduction: Project Context
- "four scripted scenarios" → **ten**. Add social media impersonation, QR code phishing and the four Philippine chapters (e-wallet texts, the bank agent, the easy sideline, identity fraud).
- Optional local note: e-wallet and QR payment scams are common in the Philippines. **Only with a real source.**

### Purpose and Description
- Unity / C# → **Godot Engine 4.7 / GDScript**; 3D models in **Blender**.
- Keep "presses **E**"; remove every "F to interact".
- **Flow:** Play → Chapter Select → chapter (briefing → inspect and decide at the desk or phone → feedback with badge) → next chapter → good ending.
- List the ten chapters and their tasks (section D).
- **Scoring:** +10 / −5 / +20, maximum **800** (was 150).
- Mention the badges, the achievements and the tutorial.

### Objectives
- See section B.

### Scope (modules)
1. **3D Virtual Environment:** low-poly office; day-to-night lighting by chapter; 5 coworkers as background life (two walk between the printer, pantry, whiteboard and reception; the seated ones type, stretch or swivel while on the phone). They never talk to the player or affect the score. The pantry's coffee maker, water dispenser and notice board can be used with **E**.
2. **System Navigation:**
   - main menu (Play, Instructions, Settings, Exit)
   - **Chapter Select:** chapters unlock in order; Review mode opens all of them
   - pause menu (Resume, Progress, Instructions, Settings, Chapter Select, Main Menu)
   - guided tutorial
   - **Settings:** mouse sensitivity, master volume, music volume, sound effects, fullscreen, Review mode
3. **Simulated Desktop Interface:** Mail, Messages, **Chat**, Browser; QR link preview in Mail.
4. **Interactive Scenario:** **ten** chapters in a fixed order, each with 4–5 messages or calls (genuine ones, the main attack, an extra fake, a coworker's question). Hints fade and fakes get subtler as the chapters go on.
5. **Decision-Based Gameplay:** inspect, then choose; red-flag checklist; coworker advice. Two endings (unchanged).
6. **Consequence Simulation:** unchanged, plus the two new −5 rules.
7. **Feedback and Tips:** per-chapter debrief from Ms. Dela Vega naming Black Veil, warning signs, tip, results per task, missed red flags; sound and visual feedback (see GDD 11).
8. **Progress Tracking and Evaluation:** HUD task list, Progress page, chapter cards, badges and achievements, ending summary.

### Limitations
- **L3:** "four predefined, scripted scenarios" → **ten**, and name them. Change "The chapter content and order are fixed" to: "The chapter content and order are fixed: chapters unlock one after another. A Review mode for evaluators opens any chapter or task directly." Keep "USB baiting or in-person impersonation are not covered".
- **L6:** add "Progress, badges and achievements last only while the game is open; nothing is saved."
- **L7:** feedback is limited to the ten chapters.
- **L9:** keep, reworded: "The coworkers in the office are background life only: some walk and move, but the player cannot talk to them, and they do not affect the score."
- Others are unchanged (offline, single player, no real tools, guided choices, Google Forms evaluation).

### Review of Related Literature
- **Badges and achievements:** support them with sources already cited: Deterding et al. (2011), Hamari, Koivisto and Sarsa (2014), and Sailer and Homner (2020).
- **Social media impersonation:** Salahdine and Kaabouch (2019) and Krombholz et al. (2015) already cover social media as an attack channel.
- **QR code phishing:** **add a real published source** (a study or a security agency advisory on "quishing").
- **Related Systems:** "four" → "ten"; the connected workplace story still sets Vigilant apart.

### Methodology (GDLC) and Calendar of Activities
- **Concept:** ten attacks.
- **Pre-production:** the design document and the chapter scripts.
- **Production:** Godot and GDScript; greybox prototype first, then low-poly models in Blender (glTF); sound generated in code.
- **Testing:** automated playthrough tests (best run, wrong-first run, inspection lock, unsafe → restart, Chapter Select), playtesting, and a Windows build test.
- **Calendar of Activities:** remove "malicious advertisements, and fake login pages".
- **Tense:** the Methodology is in past tense in a proposal; fix it if the paper is still a proposal.

### Technical Background and Table 1
- Unity → **Godot Engine 4.7.2**; C# → **GDScript**.
- Add **Blender** (3D modeling, glTF export).
- **Offline Windows desktop app:** `Vigilant.exe`, one file, about 110 MB.
- "four social engineering scenarios" → **ten**.

### Conceptual Framework (IPO)
- **Process:** "scripting the ten chapters", plus "rewarding safe decisions with badges and achievements".

### System Architecture (Figure 2)
- Narrative and Scenario Module: ten chapters (six at the office, four off the clock at home and in a café).
- Add a **Reward Module** (badges and achievements) and a **Navigation Module** (Chapter Select, Progress, tutorial).
- System Engine: **Godot**.

### Requirements Analysis and Documentation
- **FR1–FR2:** unchanged (WASD, mouse, E).
- **FR3:** add the chat app.
- **FR4:** ten scripted scenarios.
- **FR5:** add the caller ID, social media profile and QR code link preview, and **dialing a known extension on the desk phone keypad** to verify a request.
- **FR6:** add "submit a warning-sign report (checklist)" and "advise a coworker".
- **FR7:** unchanged values, plus the two new −5 rules.
- **FR10:** add "show the task list, Progress page, chapter badges and achievements".
- **New FR:** "Allow the user to select an unlocked chapter; allow evaluators to open any chapter or task in Review mode."
- **NFR2:** "a basic 3D application developed in **Godot**".
- **Wording:** Requirements Documentation calls the game a "simulator"; change it to "simulation game".

### Design: Flowchart (Figure 3) and UI Design
- **Flowchart:** Main menu → Chapter Select → chapter (several messages each) → feedback with badge → next chapter or Chapter Select → after ten chapters, the good ending. An unsafe choice leads to Game Over, then Restart Chapter or Main Menu.
- **UI components to add:**
  - Chapter Select (one big card at a time with ‹ › arrows, subquests listed inside)
  - the pause menu and Progress page
  - the tutorial prompts
  - the HUD task list
  - the chat app, the QR preview and the red-flag checklist panel
  - badges and achievements on the feedback and ending screens
  - chapter title cards with the time of day

### Table 3 (simulation game attributes)
- "four common social engineering attacks" → **ten**.
- **Rules and a goal:** add the checklist and genuine-message rules; the goal is completing all ten chapters safely.

### Appendix C: Game Design Document
- **GDD 4 and 14:** Godot 4.7 / GDScript, Blender low-poly, Windows .exe.
- **GDD 5:** "Across ten chapters in one work week…"; at the office Black Veil escalates from email and phone to social media and QR codes, and after work the player meets the scams common in the Philippines (e-wallet texts, fake bank agents, task scams, identity fraud); the days turn to night as the attacks get harder.
- **GDD 6:** Ms. Dela Vega stands at reception; four coworkers are background life: two walk fixed rounds (printer → reception → a desk; coffee maker → whiteboard → water dispenser), wait if the player is in the way and say "Excuse me"; the typist takes stretch breaks; the coworker on the phone swivels her chair. No one can be talked to. Coworkers also appear as messages (for example "Coworker – Finance").
- **GDD 7:** F → **E**; ESC opens the pause menu; tutorial prompts in Chapter 1.
- **GDD 8:** replace with the ten-chapter description (section D).
- **GDD 9:** values unchanged; maximum **800**; the two new −5 rules; Restart rolls back to the chapter-start score.
- **GDD 10:** two endings only; the Game Over screen is the bad ending.
- **GDD 11:** feedback screen, badge, achievements, and **sound feedback**:
  - evidence notes rise in pitch
  - the choices unlock with a sound
  - correct answers climb in pitch during a streak (sound only)
  - a breach hit with the music cut
  - fanfares
  - fairness rule: no sound hints at an answer before the player chooses
- **GDD 12:** add every new interface component (see Design).
- **GDD 13:** "only the ten scripted chapters".
- **New section, Rewards:** ten badges and ten achievements (section D).
- **New section, Places and phone:** the office, the home and the café; the phone apps; Fun Facts (section D).
- **New section, Art and sound:** low-poly Blender models; lighting by chapter; three music loops (calm for Ch1–2, livelier for Ch3–4, tense for Ch5–6) and all effects generated in code.
- **Remove:** the old Game Lore lures (fake login pages, ads, downloads, software-update lures, attachments), the Neutral and Perfect endings, "repeated unsafe actions" loses the game, the "Suggested 3D Gameplay Additions", and the duplicate Unity technical-specification block.

### Appendix D: Storyboard
- Replace the captions with screenshots from the final build. Remove the note "Replace or supplement the captions…".
- **Add frames:**
  - main menu
  - Chapter Select card
  - tutorial prompt
  - Chapter 5 chat profile check
  - Chapter 6 QR preview
  - red-flag checklist
  - feedback screen with badge
  - Progress page
  - ending with badges and achievements

### Appendix F: Evaluation form
- "The four scenario chapters can be accessed and completed" → **ten**.
- "email phishing, smishing, vishing, and BEC" → add **social media impersonation and QR code phishing**.
- Optional new items:
  - "The badges and achievements motivated me to make careful decisions."
  - "The tutorial helped me understand how to play."
- Remove the note "Existing pre-development interview questionnaire pages… are retained below."

### Other small fixes
- The table of contents page numbers are misaligned.
- Typos: "targetusers", "Pre -production".
- Rafael's tertiary dates read 2023–2025 (the others read 2023–2026).

---

## D. Gameplay facts (copy-ready)

**Chapters and their messages** (in the new order; genuine = safe and real; fake = attack; help = advise a coworker, friend or family member):

| # | Chapter | Place | When | Messages and calls (in play order) |
|---|---|---|---|---|
| 1 | Email Phishing | Office | Mon 08:30 AM | Genuine orientation email · **Main:** fake HR benefits email · Fake voucher email · Coworker (Sales) |
| 2 | Smishing | Office | Mon 12:00 PM | Genuine courier text · **Main:** fake courier fee text · Fake network-access text · Coworker (Admin) |
| 3 | E-wallet Texts | Home | Mon 07:30 PM | Genuine ₱500 from Mama · **Main:** fake "Calamity Assistance" text inside the real KwartaPay thread (check the app, report to 1326) · Fake "wrong send" refund request · Help your brother Migo (fake raffle wants his MPIN) |
| 4 | Vishing | Office | Tue afternoon | Genuine Facilities call · **Main:** fake "IT" call asking for a password · Fake "Security" call asking for a one-time code · Coworker (Marketing) · Genuine IT printer call (cool-down) |
| 5 | The Bank Agent | Home | Tue 08:00 PM | Genuine OTP for your own purchase · **Main:** fake "BancoNation Fraud Department" call asking for your OTP (hang up, dial the card hotline 8700) · Fake "security" chat asking you to join a video call and share your screen · Help Tita Nena (pension "code" call) |
| 6 | Business Email Compromise | Office | Wed late afternoon | Genuine expense-policy email · **Main:** fake manager payment request (verify by calling ext. 2045) · Fake CEO gift-card request · Coworker (Finance) · Genuine Finance invoice email (cool-down) |
| 7 | Social Media Impersonation | Office | Thu dusk | Genuine lunch invite · **Main:** copied coworker account asking for your OTP (verify by calling Sales) · Fake "HR" prize page · Coworker (Admin) asked to send e-wallet money |
| 8 | The Easy Sideline | Café | Fri 12:30 PM | Genuine job interview email · **Main:** "₱150 per like" task scam (refuse, dial 1326) · Fake "rent your account" offer (money mule, RA 12010) · Help your friend Carlo (asked for a "withdrawal fee") |
| 9 | QR Code Phishing | Office | Fri night | Genuine canteen-menu QR · **Main:** fake parking re-registration QR (verify with Facilities or the intranet) · Fake rice-allowance QR · Coworker (Marketing) with a parking-fee QR |
| 10 | Who Are You? | Café | Sat 06:30 PM | Genuine ID check inside the official bank app · **Main:** instant-loan "verification" asking for ID photos, a selfie holding your ID and your signature (check the SEC lender list, dial 1326) · Fake "SIM deactivation" text · Help Lola Ising (fake National ID "fast release") |

**Tasks in every chapter, same order:** warm-up genuine message → main attack (inspect, decide, verify through a known channel or official hotline, report the red flags with a checklist) → extra fake → help someone. Where a chapter has a second genuine message, it comes last as a cool-down.

**Difficulty ramp:**
- **Hints:** Chapters 1–3 name what to inspect (plus the tutorial in Chapter 1). Chapters 4–7 say only "Inspect before you decide". Chapters 8–10 give no hint.
- **Fakes:** they get subtler each chapter, down to one-character lookalike domains, faked caller IDs and scam texts placed inside a real thread.

**Scores:**

| Chapter | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | Total |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Maximum | 80 | 80 | 80 | 90 | 80 | 90 | 80 | 70 | 80 | 70 | **800** |
| Tasks | 5 | 6 | 6 | 7 | 6 | 7 | 6 | 5 | 5 | 5 | **58** |

**Badges** (one per chapter, gold when the chapter had no wrong choice): Phish Spotter, Text Guard, Wallet Watcher, Call Screener, Hang-Up Hero, Payment Protector, Profile Checker, Sideline Skeptic, QR Inspector, Identity Keeper.

**Achievements:**

| Achievement | Rule |
|---|---|
| First Day Survivor | Complete Chapter 1 |
| Clean Sweep | A chapter with no wrong choice |
| Comeback | Complete a chapter after restarting it from a breach |
| Eagle Eye | Every red-flag checklist right on the first try |
| No False Alarms | Every genuine message handled correctly the first time |
| Good Colleague | Every coworker, friend and family member given the right advice on the first try |
| Fully Vigilant | All chapters at the maximum score with no restarts |
| **OTP Bantay** (new) | Never share an OTP or MPIN |
| **Hotline Hero** (new) | Dial every official hotline right on the first try |
| **Not Your Mule** (new) | Turn down the "wrong send" and "rent your account" traps on the first try |

**Game overs off the clock:** at home and in the café, an unsafe choice ends with a personal loss (savings, identity) instead of the Aegis breach.

**Fun Facts:** 15 sourced facts (CICC, BSP, PSA, SEC, RA 12010, RA 11934, news reports). Two are marked "(reported)" because they come from secondary reports. Check those two against the original reports before the defense.

**Scope note:** every attack is still remote (calls, texts, chats, links, QR codes). Nothing asks the player to install software, and no one meets the player in person, so Limitations 3 and 4 stay true.

**Chapter Select and Review mode:**
- **Chapter Select:** Play shows one big card per chapter (‹ › arrows, dots), with its tasks listed inside.
- **Unlocking:** chapters unlock in order.
- **Review mode:** a Settings switch that is off each time the game starts. It opens every chapter and lets the panel start at any task; earlier messages are skipped and score nothing.

**Desk phone:**
- **Calls you place** (Ch1 HR 1300, Ch4 Mr. Ramos 2045, Ch5 Sales 2110, Ch6 Facilities 1400): you dial the extension yourself on an on-screen keypad with phone tones, and the digits show as you dial.
- **Wrong number:** it does not answer (no points lost), which reinforces checking the known number.
- **Incoming calls:** the caller's number shows under "RING!" and on the phone's screen. Players still check the caller ID in the call screen before answering.

**Office life (feel only, never scored):**
- **Walking coworkers:** two coworkers walk their rounds on fixed paths, step around nothing (the paths avoid all furniture), wait when the player blocks them and say "Excuse me".
- **Pantry (E):** brew coffee (the pot fills, steam rises) and pour a cup; get a cup of water from the dispenser.
- **Notice board (E):** six reminders from the Security Office that restate the game's lessons: IT never asks for passwords; verify on the phone card's extension; check the sender and links; confirm money requests by phone; don't scan unknown QR codes; report to Security (ext. 1200). It supports the awareness aim without giving any chapter's answer away.

**Tutorial:** six guided prompts in Chapter 1 (move, desk, sender, copy the link, paste it, choose), with a Skip button.

**Play time:** about 45–60 minutes for a full run.

**Delivery:** `Vigilant.exe`, a single file of about 110 MB. It runs offline on Windows. Windows may show "Windows protected your PC" because the app isn't signed; click More info → Run anyway.
