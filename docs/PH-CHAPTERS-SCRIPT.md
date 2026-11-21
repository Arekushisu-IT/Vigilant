# Vigilant Part 2: "Off the Clock" (chapters 7–10), draft scripts for review

Status: **draft for review. Nothing is built yet.** Chapters 1–6 (the office) do not change.

## Proposed new order (all 10 chapters): one work week, office and off the clock taking turns
Instead of six office chapters followed by four home chapters, the chapters alternate. Each attack type at work is followed by its Philippine "at home" version, so the lesson carries over. Difficulty still rises from chapter to chapter, and so do the hint levels:
- chapters 1–3: hints
- chapters 4–7: fewer hints
- chapters 8–10: none

| New # | Chapter | Place | When | Builds on |
|---|---|---|---|---|
| 1 | Email Phishing *(old 1)* | Office | Mon 8:30 AM | basics: sender and links |
| 2 | Smishing *(old 2)* | Office | Mon noon | texts |
| 3 | **E-wallet Texts** *(new, script 8 below)* | Home | Mon evening | smishing, plus spoofed threads and "wrong send" |
| 4 | Vishing *(old 3)* | Office | Tue afternoon | calls |
| 5 | **The Bank Agent** *(new, script 7 below)* | Home | Tue night | vishing, plus OTP and remote-access apps |
| 6 | Business Email Compromise *(old 4)* | Office | Wed late afternoon | verify by calling |
| 7 | Social Media Impersonation *(old 5)* | Office | Thu dusk | fake accounts |
| 8 | **The Easy Sideline** *(new, script 9 below)* | Café | Fri lunch break | fake accounts, plus task scams and money mules |
| 9 | QR Code Phishing *(old 6)* | Office | Fri night (neon) | links in disguise |
| 10 | **Who Are You?** *(new, script 10 below)* | Café | Sat evening | the finale: your identity, and everything learned so far |

- The lighting follows the time of day in each chapter: office chapters keep their day-to-night look; home and café get their own lighting.
- Chapter 10 ends the game. Ms. Dela Vega's "scammers don't stop at 5 PM" line moves to the end of Chapter 2, before the first home chapter.
- In the scripts below, the new chapters keep their working numbers (7–10). The table above gives their final place.

### Same task order inside every chapter
Every chapter, old and new, will use the same order, so players learn the rhythm:
1. **Warm-up:** a genuine message (learn that not everything is a scam).
2. **Main attack:** inspect, decide, verify, then report the warning signs (checklist).
3. **Extra fake:** a subtler second attack.
4. **Help someone:** advise a coworker (office) or a family member or friend (home and café).

The old chapters whose order differs today (for example, the old Chapter 4 starts with the main attack) are rearranged to match. Their content stays the same. Where an old chapter has a second genuine message, it moves to the end as a "cool-down", after the main attack.

## The idea
After Chapter 6, Ms. Dela Vega's last line is: *"You kept Aegis safe. But scammers don't stop at 5 PM. Be careful at home too."*

Part 2 follows the same player outside work, in General Santos, through the scams Filipinos meet most often:
- fake bank agents
- e-wallet texts
- task scams and money mules
- identity fraud

All four were chosen from what PH agencies and news report most often (sources at the end).

**Places:**
- **Your home**, a small condo: Chapters 7 and 8.
- **A café**: Chapters 9 and 10.

The office stays the main place.

**Device:** your **phone**, shown on screen. It has five apps:
- **Messages** (SMS)
- **Calls**, with a keypad (the same dialing as the desk phone)
- **ChatLink**, a chat app
- **KwartaPay**, an e-wallet
- **Browser**

**Made-up brands:**
- **BancoNation**: a bank. Its hotline is printed on the back of your card: **8700**.
- **KwartaPay**: an e-wallet. Hotline **2299**, plus a "Report a scam" button in the app.
- **ShopKo**: an online shop.

**Real numbers used:**
- **1326**, the government's 24/7 anti-scam hotline (CICC). The player dials it to report.
- No real bank or e-wallet names appear in the scam messages. Real names appear only in the Fun Facts, with their sources.

**Rules carried over from the paper:**
- Inspect first, then choose.
- +10 for a correct choice, −5 for a wrong one.
- An **unsafe** choice means you're compromised and get the bad ending for that chapter.
- +20 for finishing a chapter.
- Each chapter has a genuine message, the main attack, an extra fake and someone to advise. Here that's a family member or friend instead of a coworker.

**Language:** the game stays in English. Scam messages use a little Taglish, as real ones do.

---

## Chapter 7: The Bank Agent (vishing, OTP, remote-access app)
**Home, Tuesday 8:00 PM.** You just ordered a rice cooker on ShopKo with your BancoNation debit card.
**Briefing (text from Ms. Dela Vega):** "Reminder from Security: scammers call people at home too. Stay sharp."
**Objective:** Check your phone.

### 7.1 Genuine: your real OTP (`c7_otp`)
**SMS, in the BancoNation thread:**
> BancoNation: Your OTP for your ₱2,450.00 purchase at ShopKo is 482913. Do NOT share this code with anyone, including bank staff.

**Inspect:**
- the sender
- the amount and shop, which match the order you're placing in the ShopKo checkout you opened yourself

| Choice | Result | Why |
|---|---|---|
| Type the code into the ShopKo checkout you opened yourself | **Correct** | You started this payment; the amount and shop match. Using your own OTP in your own checkout is fine. Never *tell* it to anyone. |
| Report it to BancoNation as a scam | Wrong | It matches the purchase you're making right now; it's genuine. |
| Forward the code to a friend to "check if it's real" | Wrong | An OTP is for you only. Forwarding it is how accounts get taken. |

### 7.2 Main: the "Fraud Department" call (`c7_agent`)
**Incoming call.** Caller ID: **09XX-XXX-7781 (mobile number)**.
> "Good evening po, this is Allan from the BancoNation Fraud Department. We detected an unauthorized ₱48,000 transfer from your account. To block it, I need the 6-digit code we just sent you. If not blocked in 30 minutes, your account will be closed."

**Inspect:** the caller ID (a mobile number, not the hotline on your card).

**Step 1: respond**

| Choice | Result | Why |
|---|---|---|
| Hang up | **Correct** | Banks never call to ask for your OTP. |
| Ask for his full name and employee ID | Wrong | He answers, "Allan Reyes, ID 2231. Quick po, 25 minutes na lang!" Anyone can make up an ID; talking longer only gives him more time to pressure you. |
| Read him the code | **Unsafe** | He used the code to approve the ₱48,000 transfer himself. *Bad ending: "Your savings were transferred out in minutes."* |

**Step 2: what next?** You dial on the phone keypad.

| Choice | Result | Why |
|---|---|---|
| Call the hotline on the back of your BancoNation card (8700) | **Correct** | The bank says: "There is no such transaction, and we never call for OTPs. We've flagged that number." |
| Call back 09XX-XXX-7781 | Wrong | That's the scammer's number. |
| Do nothing, since you hung up | Wrong | Report it so the bank can warn others and watch your account. |

**Step 3: report the warning signs (checklist) to the bank agent**

Real warning signs:
- The call came from a mobile number, not the bank's hotline.
- He asked for your OTP.
- A threat that your account will be closed in 30 minutes.
- A big transaction you know nothing about, used to scare you.

Not proof either way:
- He knew your name. *Names leak easily.*
- He said "po" and sounded polite. *Scammers are polite too.*
- He called at night. *Real and fake calls come at any hour.*

### 7.3 Extra fake: the "security app" (`c7_app`)
**ChatLink message from "BancoNation Security ✔" (a new contact).**
> "Sir/Ma'am, to fully secure your account after tonight's incident, install BN Secure Shield and allow screen sharing so our agent can verify your device: bn-secureshield.app/download"

**Inspect:**
- the contact (new, not saved; a check mark in a name is just text)
- the real link address (not the bank's official site)

| Choice | Result | Why |
|---|---|---|
| Don't install; block the contact and report it to BancoNation (8700) | **Correct** | Banks never ask you to install apps from a link or share your screen. |
| Install it, since it's for security | **Unsafe** | It was a remote-access app; they watched you log in and emptied your account. |
| Ask if the app is free | Wrong | Price isn't the problem. Any app from a chat link that wants your screen is a trap. |

### 7.4 Advise family: Tita Nena (`c7_tita`)
**ChatLink from "Tita Nena" (saved contact).**
> "Iha/Iho, may tumawag sa akin, taga-bangko daw. My pension account will be closed unless I give the code they texted. He knew my full name. Ibibigay ko na ba?" ("Someone called me, said he's from the bank. Should I just give it?")

**Inspect:** her quoted message (the caller asked for the texted code).

| Choice | Result | Why |
|---|---|---|
| Tell her not to give it, hang up, call the number on the back of her card, and report it to 1326 | **Correct** | No real bank asks for that code, even if the caller knows your name. |
| Tell her to give it, since he knows her name | **Unsafe** | Tita's pension was withdrawn. |
| Tell her to ask for his ID first | Wrong | IDs can be made up. Hang up and call the bank directly. |

**Debrief:** "Allan" and "BancoNation Security" were the same scam: get the OTP, or get onto your phone. Your OTP text was real because you started that purchase yourself.

**Tip:** Your bank will never call, text or chat to ask for your OTP, to install an app or to share your screen. Hang up and call the number on your card.

---

## Chapter 8: The E-wallet Texts (spoofed sender, fake "ayuda", "wrong send")
**Home, Monday 7:30 PM.**
**Objective:** Check your messages and your KwartaPay app.

### 8.1 Genuine: money from Mama (`c8_cashin`)
**SMS in the KwartaPay thread:**
> "You have received ₱500.00 from M\*\*\*A D. Ref 7781 2260 1193."

**Inspect:** the KwartaPay app's history (open the app yourself). The same ₱500 from Mama's saved number is there.

| Choice | Result | Why |
|---|---|---|
| Message Mama "Thank you po!" | **Correct** | It matches the app's history. |
| Report it as a scam | Wrong | The app itself shows it. It's genuine. |
| Send it back in case it's a trick | Wrong | It's genuine. Always check in the app first. |

### 8.2 Main: "Calamity Assistance" in the real thread (`c8_ayuda`)
**SMS that arrives *inside* the same KwartaPay thread as 8.1:**
> "KwartaPay: Congrats! You qualify for ₱3,500 Calamity Assistance. Claim before 11:59PM tonight or it expires: kwartapay-ayuda.click/claim"

**Inspect:**
- the real link address (not KwartaPay's official site)
- the KwartaPay app's own inbox (no such promo)

**Step 1: respond**

| Choice | Result | Why |
|---|---|---|
| Don't tap it; open the KwartaPay app yourself and check its inbox | **Correct** | Checking in the official app you open yourself is how you confirm it. |
| Tap the link and log in with your MPIN to claim | **Unsafe** | The page stole your MPIN, and your balance was sent out. |
| Reply "STOP" | Wrong | Replying tells them your number is active. |
| Forward it to the family group chat so everyone can claim | Wrong | Now your family is exposed too. |

**Step 2 (in the KwartaPay app): no promo exists. What next?**

| Choice | Result | Why |
|---|---|---|
| Report it with the app's "Report a scam" and to 1326 | **Correct** | Reporting helps stop the sender. |
| Just delete it | Wrong | Others in your area may get the same text. Report it. |

**Step 3: report the warning signs (checklist)**

Real warning signs:
- The link isn't KwartaPay's official site.
- Free money you never applied for.
- "Expires today" pressure.
- It asks you to log in through a link.

Not proof either way:
- *"It arrived in the real KwartaPay thread."* Explanation in the game: fake text towers (IMSI catchers) can put a scam text inside a real thread, so where it lands proves nothing.
- It used your first name.

### 8.3 Extra fake: the "wrong send" (`c8_wrongsend`)
Your KwartaPay history shows **+₱1,000 from "J\*\*\*N R." (09XX-XXX-5520)**. Then an SMS arrives from **09XX-XXX-2210**:
> "Hi po! Nawrong send ko po ₱1,000 sa inyo, pang-tuition ng anak ko 🙏 Pakibalik po sa number na ito, 09XX-XXX-2210. Salamat po!" ("I sent ₱1,000 to you by mistake, it's for my child's tuition. Please send it back to this number.")

**Inspect:**
- the history (the money came from a *different* name and number than the one texting)
- the texter's number

| Choice | Result | Why |
|---|---|---|
| Don't send it anywhere; report it in KwartaPay so they handle it through the official process | **Correct** | Transfers can't simply be undone; the official process returns the money to whoever really sent it. |
| Send ₱1,000 to 09XX-XXX-2210 | **Unsafe** | The ₱1,000 was stolen from another victim. KwartaPay reversed it from your account, so the ₱1,000 you "returned" is lost and your account is flagged as a money mule. |
| Send it back to the number that sent it | Wrong | Better, but still do it only through KwartaPay's official process. Scammers sometimes use stolen accounts. |

### 8.4 Advise family: your brother Migo (`c8_migo`)
> "Kuya/Ate! I won the KwartaPay raffle daw, ₱10,000! They just need my MPIN to deposit the prize. Legit ba?"

| Choice | Result | Why |
|---|---|---|
| Tell him no real prize needs his MPIN; check the app himself and report it | **Correct** | An MPIN is like a password. Nobody legitimate asks for it. |
| Tell him to give it, since it's just to deposit the prize | **Unsafe** | His wallet was emptied. |
| Tell him to ask them to send proof first | Wrong | Proof is easy to fake. The MPIN request alone settles it. |

**Debrief:** The "ayuda" text even showed up in the real thread, but the app itself had no such promo. The "wrong send" was a trap to make you pass stolen money along.

**Tip:** Check e-wallet news only inside the app you open yourself. Never send "wrong send" money to a new number; use the official report.

---

## Chapter 9: The Easy Sideline (task scam, money mule)
**Café, Friday 12:30 PM (lunch break).**
**Objective:** Check your chats.

### 9.1 Genuine: a real job invite (`c9_job`)
**Email from careers@mindanaobpohub.com.ph:**
> "Thank you for applying for Customer Support Associate. Your interview is on Monday, 10 AM at our office, 3rd floor, GenSan Business Park. There are no fees at any stage."

**Inspect:**
- the sender's domain (matches the company site you applied on)
- no fees

| Choice | Result | Why |
|---|---|---|
| Confirm the interview on the company's official site | **Correct** | It matches the company and asks for nothing. |
| Report it as a scam | Wrong | It's genuine. |
| Ignore it | Wrong | It's genuine. |

### 9.2 Main: "Earn ₱150 per like" (`c9_task`)
**ChatLink from "HR Ella | ShopKo Partner" (unknown):**
> "Hi! 😊 Earn ₱150 per task! Just like 3 product videos and send a screenshot. Work from home, 1–2 hrs/day, earn ₱3,000–5,000 daily! Join our Telegram team now ➡️"

**Inspect:**
- the contact (not on ShopKo's official page)
- the offer (pay for "likes")

**Step 1: respond**

| Choice | Result | Why |
|---|---|---|
| Don't join; block and report | **Correct** | Real jobs don't pay for likes, and they don't recruit you through random chats. |
| Try the free tasks; you can stop anytime | Wrong | The scammer pays ₱150 at first, then asks: "VIP task: deposit ₱2,000 to unlock ₱3,800 commission!" The small payment is bait. Pick again. |
| Deposit ₱2,000 for the VIP task | **Unsafe** | Each "recharge" asks for more. You lost ₱2,000, then more. |

**Step 2: dial 1326 (the government anti-scam hotline) and tell the agent the warning signs (checklist)**

Real warning signs:
- A job offer you never applied for, sent by chat.
- Pay for "liking" videos.
- Big money for little work.
- They move you to a Telegram group.
- You must deposit money to "unlock" earnings.

Not proof either way:
- The message used emojis.
- It came on a weekend.
- They used a real shop's name. *Anyone can type a brand name.*

### 9.3 Extra fake: "Rent your account" (`c9_mule`)
**ChatLink from "Easy Income PH ✨":**
> "Earn ₱500 every week with NO work! Just lend us your KwartaPay or bank account so we can receive payments for our business. Totally safe po!"

| Choice | Result | Why |
|---|---|---|
| Refuse and report | **Correct** | Lending your account makes you a "money mule", which is a crime under RA 12010 (AFASA). |
| Accept, since it's easy money | **Unsafe** | Your account received money stolen from scam victims. It was frozen, and you face charges. |
| Ask how much more they would pay | Wrong | No amount makes it safe or legal. |

### 9.4 Advise a friend: Carlo (`c9_carlo`)
> "Pre, I've been doing this like-and-earn sideline. They owe me ₱4,000 but I have to pay a ₱2,000 'withdrawal fee' first. Bayaran ko na lang para makuha ko?" ("Should I just pay so I can get it?")

| Choice | Result | Why |
|---|---|---|
| Tell him not to pay; stop, save screenshots and report to 1326 | **Correct** | The "earnings" don't exist; every fee only adds to the loss. |
| Tell him to pay once to get his money out | **Unsafe** | Carlo lost ₱2,000 more. |
| Tell him to ask for a smaller fee | Wrong | Any fee is the scam. |

**Debrief:** The "₱150 per like" paid a little first so you would trust it, then asked for deposits. "Rent your account" would have made *you* the criminal. The job email was real: a real company domain and no fees.

**Tip:** Real jobs never charge you to work or to withdraw pay. Never lend or sell your bank or e-wallet account.

---

## Chapter 10: Who Are You? (identity fraud)
**Café, Saturday 6:30 PM.**
**Objective:** Check your phone.

### 10.1 Genuine: opening an account in the official app (`c10_kyc`)
You opened the **BancoNation app yourself** to open a savings account. The app asks you to scan your ID and take a selfie inside the app.

**Inspect:** the app's details (official publisher BancoNation; you opened it yourself).

| Choice | Result | Why |
|---|---|---|
| Scan your ID inside the official app | **Correct** | You started it, inside the bank's own app. This is normal ID verification. |
| Refuse and report it as a scam | Wrong | It's the real app you opened yourself. |

### 10.2 Main: the instant-loan "verification" (`c10_loan`)
**ChatLink from "Kwik Cash Lending 💸":**
> "Your ₱20,000 loan is PRE-APPROVED! ✅ For release in 5 mins, send: (1) clear photo of your ID front and back, (2) selfie holding your ID, (3) your signature on white paper."

**Inspect:**
- the lender (not on the SEC's list of registered lending companies, shown in the game's browser)
- the request (all three are exactly what identity thieves need)

**Step 1: respond**

| Choice | Result | Why |
|---|---|---|
| Don't send anything; check the SEC list | **Correct** | It isn't on the list. A selfie holding your ID plus your signature lets someone *become* you. |
| Send them, since it's just verification | **Unsafe** | Your ID, selfie and signature were used to register SIMs and take out loans in your name. |
| Send only the ID photo, not the selfie | Wrong | Even one ID photo can be misused. Don't send any. |

**Step 2: report it (dial 1326) and name the warning signs (checklist)**

Real warning signs:
- A loan you never applied for, "pre-approved".
- They asked for a selfie holding your ID.
- They asked for your signature.
- "Release in 5 minutes" pressure.
- The lender isn't registered.

Not proof either way:
- It used a check mark ✅. *Anyone can type one.*
- It replied quickly.

### 10.3 Extra fake: "SIM deactivation" (`c10_sim`)
**SMS:**
> "Your SIM will be DEACTIVATED in 24 hrs due to incomplete registration. Re-verify now: simreg-update.ph-verify.com"

**Inspect:** the real link address (not your telco's official site or app).

| Choice | Result | Why |
|---|---|---|
| Ignore the link; check in your telco's official app | **Correct** | Your SIM registration is shown in the telco's own app. |
| Open the link and upload your ID again | **Unsafe** | Your ID was used for fake SIM registrations. |
| Reply with your full name and birthday | Wrong | That's personal data handed to a stranger. |

### 10.4 Advise family: Lola Ising (`c10_lola`)
> "Apo, someone on Facebook says they can get my National ID released fast for ₱300. They need my birth certificate and a photo. Should I send?"

| Choice | Result | Why |
|---|---|---|
| Tell her not to send or pay; the National ID only goes through official PSA channels, so report the page | **Correct** | The PSA warns that offers to "help" with National ID processing are scams. |
| Tell her to send them, since ₱300 is cheap | **Unsafe** | Her birth certificate and photo were used to make a fake ID. |
| Tell her to meet them in person to be safe | Wrong | Meeting doesn't make it official. Only PSA channels are. |

**Debrief:** Your ID, a selfie with it and your signature are the keys to your identity. Only give ID inside official apps or offices you went to yourself.

**Tip:** Never send ID photos, a selfie with your ID or your signature through chat. Check that lenders are SEC-registered. Report to 1326.

**Ending (all 10 chapters done):** "From the office to your phone at home, you stopped every scam. Black Veil and the scammers off the clock all failed. Stay Vigilant." The bad endings stay per item, as now.

---

## New tasks, score and rewards (estimates; exact numbers after building)
- **New tasks:** about 18 more (36 → about 54).
- **New scored steps:** 22 → +220 points, plus +80 for 4 chapters. **Maximum about 800** (was 500).
- **New badges:** one per chapter, for chapters 7–10.
- **New achievements:**
  - **OTP Bantay:** never shared an OTP or MPIN in chapters 7–8.
  - **Hotline Hero:** dialed every official hotline correctly on the first try.
  - **Not Your Mule:** turned down the "wrong send" and "rent your account" traps on the first try.

---

## Fun Facts (shown at chapter start, on the results screen and on a Fun Facts page)
Every fact has a source. In the game, each one names its source in small text. ✔ = confirmed in the source; ⚠ = reported by a secondary source (marked "reported" in the game).

| # | Fact (as shown in the game) | Source |
|---|---|---|
| 1 | ✔ Consumer fraud (online selling and delivery scams) was the most reported cybercrime to the CICC in 2025. | [GMA News](https://www.gmanetwork.com/news/topstories/nation/973804/consumer-fraud-topped-cybercrime-complaints-in-2025-cicc/story) |
| 2 | ✔ Your bank or e-wallet will never call, text or email you to ask for your OTP. (BSP) | [BSP SecuriTips via Standard Chartered PH](https://www.sc.com/ph/?p=3750) |
| 3 | ✔ Scammers posing as bank staff may ask you to read an OTP, share your screen or install an app. | [Philstar (BPI)](https://www.philstar.com/business/2025/10/23/2481805/imsi-catchers-ai-scams-bpi-tags-latest-threats-digital-banking-security) |
| 4 | ✔ Fake cell towers called IMSI catchers can send scam texts that appear in a real bank or e-wallet thread. | [PCIJ](https://pcij.org/?p=25610) |
| 5 | ✔ Police have seized at least five IMSI catchers and 53 text blasters since 2024. | [PCIJ](https://pcij.org/?p=25610) |
| 6 | ✔ Fake "Calamity Assistance" e-wallet texts with links or QR codes circulated in 2025. | [Interaksyon/Philstar](https://interaksyon.philstar.com/?p=300161) |
| 7 | ✔ Report scams 24/7, toll-free, to hotline 1326 (CICC Inter-Agency Response Center). | [ABS-CBN](https://www.abs-cbn.com/business/2024/11/10/cicc-report-scams-to-government-instead-of-ranting-on-social-media-951), [PNA](https://alpha.pna.gov.ph/articles/1207775) |
| 8 | ✔ Under RA 12010 (AFASA, 2024), lending or selling your bank or e-wallet account to others ("money muling") is a crime. | [LawPhil RA 12010](https://lawphil.net/statutes/repacts/ra2024/ra_12010_2024.html), [ABS-CBN (SEC)](https://www.abs-cbn.com/news/business/2025/5/30/-money-muling-letting-others-use-your-accounts-might-be-a-crime-sec-warns-1255) |
| 9 | ✔ An e-wallet transfer can't simply be reversed; use the official process if money was sent to the wrong number. | [GMA News](https://www.gmanetwork.com/news/money/companies/983056/what-to-do-if-money-sent-to-wrong-number-gcash-outlines-steps/story) |
| 10 | ✔ Task scams pay a small amount first, then ask for "recharge" deposits that keep growing. (SEC) | [Inquirer](https://newsinfo.inquirer.net/2074569/watchdog-more-task-scams-emerging-on-online-messaging-apps) |
| 11 | ✔ The PSA warns that offers to help with National ID processing are fraudulent. | [Manila Bulletin](https://mb.com.ph/2025/3/12/psa-warns-national-id-scams-on-the-rise-stay-vigilant) |
| 12 | ✔ The SIM Registration Act (RA 11934) was the first law signed by President Marcos Jr., on October 10, 2022. | [Inquirer](https://newsinfo.inquirer.net/1678018/sim-card-registration-law-signed-amid-privacy-concerns) |
| 13 | ✔ Stolen identities have been used to make fake IDs for SIM registration. (DICT) | [Inquirer](https://newsinfo.inquirer.net/1831067/dict-says-identity-theft-used-in-creating-ids-for-sim-registration) |
| 14 | ⚠ Scam calls reportedly rose about 225% from early 2024 to early 2025. (Whoscall) | [ABS-CBN](https://abs-cbn.com/news/nation/2025/4/2/public-warned-scam-calls-on-the-rise-1847) |
| 15 | ⚠ A 2025 report estimated Filipinos lost ₱280 billion to scammers. | [Philstar](https://www.philstar.com/business/2025/11/26/2489831/pinoys-lose-p280-billion-scammers-report) |

**To check before using:**
- #14 and #15: open the original reports and confirm the exact figures.
- 10.4 says "official PSA channels only". Confirm the PSA's wording on its own site before final.

**For chapters 1–6:** facts #1, #2 and #7 also fit Chapters 2–3. Chapter 6 (QR codes) still needs a real published source; the search found a 2026 Philstar report on GCash and "quishing" that the colleague can check.

---

## What changes in the paper (for the colleague)
- **Objective 1:** the 3D office *and* two more places (home, café), plus a phone device.
- **Objective 4:** 10 chapters, in two parts (at work; off the clock).
- **Scope and limitations:** add the phone and the PH-specific attacks. The L3 note about in-person attacks stays true: all attacks are still remote (calls, texts, chats, links).
- **Related literature:** add the PH sources above (CICC, BSP, PSA, SEC, RA 12010, RA 11934).
- **New objective wording:** Fun Facts are part of the awareness content.
