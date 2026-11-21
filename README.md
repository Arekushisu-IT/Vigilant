# Vigilant

A 3D desktop simulation game that teaches social engineering awareness. BSIT capstone project, STI College General Santos.

You play a new employee at Aegis Solutions over one work week. At the office you deal with emails, texts, chats, calls and QR codes. After work, at home and in a café, you face the scams Filipinos meet most often: e-wallet texts, fake bank agents asking for your OTP, task scams and money mules, and identity fraud. For each message you inspect first (sender, real link address, caller ID, profile), then choose what to do.

- **10 chapters**, 42 messages and calls, 58 tasks, maximum score 800
- **Places:** a low-poly office, the player's home and a café
- **Devices:** the office workstation, the desk phone and the player's phone (Messages, Calls, ChatLink, KwartaPay e-wallet, Browser and more)
- **Rewards:** 10 chapter badges and 10 achievements
- **Fun Facts:** 15 real facts about scams in the Philippines, each with its source
- **Help:** a guided tutorial, Chapter Select and a Review mode for evaluators
- Offline, single player, nothing saved to disk. All sound is generated in code.

## Download

Get `Vigilant.exe` from the [Releases](../../releases) page. It runs on Windows with no install. Windows may warn that the app isn't signed; click **More info → Run anyway**.

## Build from source

- **Engine:** Godot 4.7.2 (GDScript). Open `game/project.godot`.
- **Art:** low-poly models made by script in Blender 5.1 (`art/blender/build_assets.py`), exported to `game/assets/models/`.
- **Run:** press F5 in Godot.
- **Tests:** from `game/`, run `godot --headless --path . --script res://tests/smoke_test.gd` (about 5,900 checks).
- **See the places in the editor:** open `game/tests/previews/office_preview.scn`, `home_preview.scn` or `cafe_preview.scn`. The game builds its places in code, so its own scenes look empty in the editor.
- **Export:** `godot --headless --path game --export-release "Windows Desktop" ../build/Vigilant.exe`

## Docs

- `docs/PH-CHAPTERS-SCRIPT.md`: the scripts of the four Philippine chapters and the Fun Facts sources
- `docs/MANUSCRIPT-REVISIONS.md`: what changed compared with the paper
- `game/CONTRACT.md`: how the code is organised

All company, bank and e-wallet names in the game (Aegis Solutions, BancoNation, KwartaPay, ShopKo) are made up. Real agencies (CICC, BSP, PSA, SEC) appear only in the Fun Facts, with their sources. The anti-scam hotline 1326 is real.
