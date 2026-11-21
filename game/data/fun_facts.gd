class_name FunFacts
extends RefCounted
## Fun Facts: short, sourced awareness facts about scams in the Philippines (docs/PH-CHAPTERS-SCRIPT.md, Fun Facts
## table). They are shown on the title card at a chapter's start, on the chapter results screen and on the Fun Facts
## page of the main menu. They are never input, never score and play no sound.
##
## Each fact: {id, text, source, year, status, chapters, spoils}
## - text: as shown in the game (American spelling). Real organisation names appear only here and in "source",
##   never in scenario text.
## - source: the short outlet name shown in small text ("Source: GMA News, 2025"). The full links stay in
##   docs/PH-CHAPTERS-SCRIPT.md: no URL is stored in the game.
## - status: "confirmed" (checked in the source) or "reported" (secondary report; shown with " (reported)").
## - chapters: chapter keys (Campaign chapter "key") the fact belongs to, or "general".
## - spoils: chapter keys whose answer the fact would give away if shown at that chapter's START.
## Pure data and static helpers, with no autoload references, so tests can use it from a --script run.

const FACTS: Array[Dictionary] = [
	{
		"id": "ff_consumer_fraud",
		"text": "Consumer fraud (online selling and delivery scams) was the most reported cybercrime to the CICC in 2025.",
		"source": "GMA News",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["smishing", "general"],
		"spoils": [],
	},
	{
		"id": "ff_otp_never",
		"text": "Your bank or e-wallet will never call, text or email you to ask for your OTP. (BSP)",
		"source": "BSP SecuriTips via Standard Chartered PH",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["bank_agent", "ewallet", "smishing", "vishing"],
		"spoils": ["bank_agent", "vishing"],
	},
	{
		"id": "ff_bank_staff_asks",
		"text": "Scammers posing as bank staff may ask you to read an OTP, share your screen or set up an app.",
		"source": "Philstar (BPI)",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["bank_agent"],
		"spoils": ["bank_agent"],
	},
	{
		"id": "ff_imsi_thread",
		"text": "Fake cell towers called IMSI catchers can send scam texts that appear in a real bank or e-wallet thread.",
		"source": "PCIJ",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["ewallet"],
		"spoils": ["ewallet"],
	},
	{
		"id": "ff_imsi_seized",
		"text": "Police have seized at least five IMSI catchers and 53 text blasters since 2024.",
		"source": "PCIJ",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["ewallet"],
		"spoils": [],
	},
	{
		"id": "ff_calamity_texts",
		"text": "Fake \"Calamity Assistance\" e-wallet texts with links or QR codes circulated in 2025.",
		"source": "Interaksyon/Philstar",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["ewallet"],
		"spoils": ["ewallet"],
	},
	{
		"id": "ff_hotline_1326",
		"text": "Report scams 24/7, toll-free, to hotline 1326 (CICC Inter-Agency Response Center).",
		"source": "ABS-CBN, PNA",
		"year": 2024,
		"status": "confirmed",
		"chapters": ["general", "ewallet", "bank_agent", "sideline", "identity", "smishing", "vishing"],
		"spoils": [],
	},
	{
		"id": "ff_money_mule",
		"text": "Under RA 12010 (AFASA, 2024), lending or selling your bank or e-wallet account to others (\"money muling\") is a crime.",
		"source": "LawPhil RA 12010; ABS-CBN (SEC)",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["sideline"],
		"spoils": ["sideline"],
	},
	{
		"id": "ff_wrong_send",
		"text": "An e-wallet transfer can't simply be reversed; use the official process if money was sent to the wrong number.",
		"source": "GMA News",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["ewallet"],
		"spoils": ["ewallet"],
	},
	{
		"id": "ff_task_scam",
		"text": "Task scams pay a small amount first, then ask for \"recharge\" deposits that keep growing. (SEC)",
		"source": "Inquirer",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["sideline"],
		"spoils": ["sideline"],
	},
	{
		"id": "ff_psa_national_id",
		"text": "The PSA warns that offers to help with National ID processing are fraudulent.",
		"source": "Manila Bulletin",
		"year": 2025,
		"status": "confirmed",
		"chapters": ["identity"],
		"spoils": ["identity"],
	},
	{
		"id": "ff_sim_law",
		"text": "The SIM Registration Act (RA 11934) was the first law signed by President Marcos Jr., on October 10, 2022.",
		"source": "Inquirer",
		"year": 2022,
		"status": "confirmed",
		"chapters": ["identity"],
		"spoils": [],
	},
	{
		"id": "ff_fake_ids_sim",
		"text": "Stolen identities have been used to make fake IDs for SIM registration. (DICT)",
		"source": "Inquirer",
		"year": 2023,
		"status": "confirmed",
		"chapters": ["identity"],
		"spoils": [],
	},
	{
		"id": "ff_scam_calls_rise",
		"text": "Scam calls rose about 225% from early 2024 to early 2025.",
		"source": "ABS-CBN (Whoscall data)",
		"year": 2025,
		"status": "reported",
		"chapters": ["vishing", "bank_agent"],
		"spoils": [],
	},
	{
		"id": "ff_losses_280b",
		"text": "A 2025 report estimated Filipinos lost ₱280 billion to scammers.",
		"source": "Philstar",
		"year": 2025,
		"status": "reported",
		"chapters": ["general"],
		"spoils": [],
	},
]


## Every fact, in table order (copies).
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in FACTS:
		out.append(f.duplicate(true))
	return out


## The facts tagged with chapter n's key, in table order. Empty when the chapter has no key or no fact.
static func for_chapter(n: int) -> Array[Dictionary]:
	return for_key(_key_of(n))


## The facts tagged with a chapter key (or "general"), in table order.
static func for_key(key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if key == "":
		return out
	for f: Dictionary in FACTS:
		if (f.get("chapters", []) as Array).has(key):
			out.append(f.duplicate(true))
	return out


## The fact for chapter n in a slot, deterministic (no randomness):
## - "results": the chapter's first fact that differs from its start fact (else its first fact; else the first
##   general fact). It may give the answer away: the chapter is over.
## - "start": the chapter's first fact that does not spoil the chapter; else the first general fact that differs
##   from the results fact, so the two screens show different facts.
## Returns {} only when there are no facts at all.
static func pick(n: int, slot: String) -> Dictionary:
	var key := _key_of(n)
	var mine := for_key(key)
	var general := for_key("general")
	var start: Dictionary = {}
	for f: Dictionary in mine:
		if not (f.get("spoils", []) as Array).has(key):
			start = f
			break
	var results: Dictionary = {}
	for f: Dictionary in mine:
		if start.is_empty() or f.id != start.id:
			results = f
			break
	if results.is_empty():
		results = mine[0] if not mine.is_empty() else (general[0] if not general.is_empty() else {})
	if slot == "results":
		return results
	if start.is_empty():
		for f: Dictionary in general:
			if results.is_empty() or f.id != results.id:
				return f
		return general[0] if not general.is_empty() else {}
	return start


## The fact text as shown: " (reported)" is added to facts that come from a secondary report.
static func display_text(f: Dictionary) -> String:
	var text := str(f.get("text", ""))
	if str(f.get("status", "")) == "reported":
		text += " (reported)"
	return text


## "Source: GMA News, 2025".
static func source_line(f: Dictionary) -> String:
	return "Source: %s, %d" % [str(f.get("source", "")), int(f.get("year", 0))]


## Campaign chapter n's key ("" when n is out of range or the chapter has none).
static func _key_of(n: int) -> String:
	if n < 1 or n > Campaign.CHAPTERS.size():
		return ""
	return str(Campaign.chapter(n).get("key", ""))
