class_name AudioSynth
extends RefCounted
## Synthesizes every sound of the game as mono float samples (-1..1): no audio files, nothing downloaded.
## Pure static functions with no shared state, so the Audio autoload can run them on worker threads.
## Short effects render at 44.1 kHz; long loops (ring, typing, ambience, music) at 22.05 kHz to keep startup cheap.
## Loops are seamless: notes wrap around the buffer end and noise beds are crossfaded at the seam.

const SFX_RATE := 44100
const LOOP_RATE := 22050
const LOOP_SOUNDS: Array[String] = ["phone_ring", "typing", "ambient", "ambient_home", "ambient_cafe", "day", "drive", "night"]

## Timbres as [multiple, amplitude] pairs.
const BELL: Array[float] = [1.0, 1.0, 2.0, 0.28, 3.01, 0.08]
const SOFT_BELL: Array[float] = [1.0, 1.0, 2.0, 0.2]
const PAD: Array[float] = [1.0, 1.0, 2.0, 0.22, 3.0, 0.06]
const DARK_PAD: Array[float] = [1.0, 1.0, 2.0, 0.1]
const KEYS: Array[float] = [1.0, 1.0, 2.0, 0.18, 4.0, 0.04]
const PLUCK: Array[float] = [1.0, 1.0, 2.0, 0.35, 3.0, 0.12]
const BASS: Array[float] = [1.0, 1.0, 2.0, 0.25]
const BUZZ: Array[float] = [1.0, 1.0, 3.0, 0.22, 5.0, 0.08]
const ALARM: Array[float] = [1.0, 1.0, 3.0, 0.18]
const BRASS: Array[float] = [1.0, 1.0, 2.0, 0.62, 3.0, 0.42, 4.0, 0.24, 5.0, 0.12]


static func rate_of(sound: String) -> int:
	return LOOP_RATE if LOOP_SOUNDS.has(sound) else SFX_RATE


static func render(sound: String) -> PackedFloat32Array:
	if sound.begins_with("dtmf_"):
		return _dtmf(sound.substr(5))
	match sound:
		"ringback":
			return _ringback()
		"no_answer":
			return _no_answer()
		"coffee_brew":
			return _coffee_brew()
		"coffee_pour":
			return _coffee_pour()
		"water_pour":
			return _water_pour()
		"footstep":
			return _footstep()
		"ui_click":
			return _ui_click()
		"notify_ping":
			return _notify_ping()
		"phone_ring":
			return _phone_ring()
		"phone_pickup":
			return _phone_pickup()
		"phone_hangup":
			return _phone_hangup()
		"evidence_found":
			return _evidence_found()
		"copy":
			return _blip(560.0, 880.0, false)
		"paste":
			return _blip(880.0, 560.0, true)
		"correct":
			return _correct()
		"wrong":
			return _wrong()
		"unsafe_alarm":
			return _unsafe_alarm()
		"chapter_complete":
			return _chapter_complete()
		"badge":
			return _badge()
		"typing":
			return _typing()
		"page_turn":
			return _page_turn()
		"ambient_home":
			return _ambient_home()
		"ambient_cafe":
			return _ambient_cafe()
		"ambient":
			return _ambient()
		"ui_hover":
			return _ui_hover()
		"app_switch":
			return _app_switch()
		"desk_open":
			return _desk_open()
		"desk_close":
			return _desk_close()
		"gate_unlock":
			return _gate_unlock()
		"tick":
			return _tick()
		"stamp":
			return _stamp()
		"score_up":
			return _score_up()
		"score_down":
			return _score_down()
		"streak":
			return _streak()
		"title_hit":
			return _title_hit()
		"breach_hit":
			return _breach_hit()
		"game_over":
			return _game_over()
		"gold_badge":
			return _gold_badge()
		"achievement":
			return _achievement()
		"victory":
			return _victory()
		"restart":
			return _restart()
		"drive":
			return _music_drive()
		"day":
			return _music_day()
		"night":
			return _music_night()
	return PackedFloat32Array()


# =====================================================================================================
# Effects
# =====================================================================================================

## Soft, low "tup": low-passed noise and a short 80 Hz thump.
static func _footstep() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.18, r)
	var rng := _rng(7)
	var lp1 := 0.0
	var lp2 := 0.0
	for i: int in b.size():
		var t := float(i) / r
		lp1 += 0.12 * (rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += 0.12 * (lp1 - lp2)
		var env := minf(1.0, t / 0.003) * exp(-t * 38.0)
		var thump := sin(TAU * 80.0 * t) * exp(-t * 45.0) * minf(1.0, t / 0.002)
		b[i] = lp2 * 4.0 * env + thump * 0.5
	_fade_tail(b, r, 0.03)
	_normalize(b, 0.55)
	return b


static func _ui_click() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.06, r)
	var rng := _rng(3)
	for i: int in b.size():
		var t := float(i) / r
		var env := minf(1.0, t / 0.001) * exp(-t * 90.0)
		var v := sin(TAU * 1900.0 * t) * 0.6 + sin(TAU * 2850.0 * t) * 0.25 * exp(-t * 160.0)
		if t < 0.002:
			v += rng.randf_range(-1.0, 1.0) * 0.25
		b[i] = v * env
	_fade_tail(b, r, 0.01)
	_normalize(b, 0.32)
	return b


## Two soft bell notes, C6 then G6.
static func _notify_ping() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.95, r)
	_note(b, r, 0.0, 0.7, 1046.5, 1.0, 0.004, 7.0, 0.05, BELL)
	_note(b, r, 0.12, 0.8, 1568.0, 0.9, 0.004, 6.0, 0.05, BELL)
	_normalize(b, 0.42)
	return b


## Desk-phone ring, one 3 s period (ring 0-0.4 s and 0.6-1.0 s, matching the blinking ring light).
## 440 + 480 Hz with a soft 20 Hz trill; every frequency completes whole cycles in 3 s, so it loops cleanly.
static func _phone_ring() -> PackedFloat32Array:
	var r := LOOP_RATE
	var b := _buf(3.0, r)
	for i: int in b.size():
		var t := float(i) / r
		var e := _ring_env(t)
		if e <= 0.0:
			continue
		var trill := 0.62 + 0.38 * sin(TAU * 20.0 * t)
		b[i] = (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t)) * 0.5 * trill * e
	_normalize(b, 0.45)
	return b


static func _ring_env(t: float) -> float:
	var fade := 0.02
	for seg: Vector2 in [Vector2(0.0, 0.4), Vector2(0.6, 1.0)]:
		if t >= seg.x and t < seg.y:
			return clampf(minf(t - seg.x, seg.y - t) / fade, 0.0, 1.0)
	return 0.0


## Handset lifted: a plastic click and a low thunk.
static func _phone_pickup() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.35, r)
	_clunk(b, r, 0.0, 170.0, 110.0, 1.0)
	_click(b, r, 0.06, 0.45, 11)
	_normalize(b, 0.5)
	return b


## Handset down: a clunk, then two soft "call ended" beeps.
static func _phone_hangup() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.75, r)
	_clunk(b, r, 0.0, 140.0, 90.0, 1.0)
	_note(b, r, 0.28, 0.12, 425.0, 0.35, 0.01, 0.0, 0.03, SOFT_BELL)
	_note(b, r, 0.48, 0.12, 425.0, 0.35, 0.01, 0.0, 0.03, SOFT_BELL)
	_normalize(b, 0.45)
	return b


## A short bright two-note tick (G6, C7) when a new inspection is recorded.
static func _evidence_found() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.42, r)
	_note(b, r, 0.0, 0.25, 1568.0, 0.8, 0.002, 16.0, 0.03, SOFT_BELL)
	_note(b, r, 0.07, 0.32, 2093.0, 1.0, 0.002, 12.0, 0.04, SOFT_BELL)
	_normalize(b, 0.4)
	return b


## Copy (rising) and paste (falling, with a soft click) blips.
static func _blip(f0: float, f1: float, with_click: bool) -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.15, r)
	_sweep(b, r, 0.0, 0.14, f0, f1, 1.0, 0.004, 26.0)
	if with_click:
		_click(b, r, 0.0, 0.25, 5)
	_fade_tail(b, r, 0.02)
	_normalize(b, 0.3)
	return b


## Rising chime C5 E5 G5 C6 with a soft thump under it, so a right answer lands with weight.
static func _correct() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(1.25, r)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for k: int in notes.size():
		_note(b, r, k * 0.07, 0.95, notes[k], 0.8 + 0.03 * k, 0.003, 4.0, 0.1, BELL)
	_thump(b, r, 0.0, 130.0, 60.0, 0.75, 0.16)
	_note(b, r, 0.28, 0.8, 2093.0, 0.28, 0.003, 6.0, 0.1, SOFT_BELL)
	_normalize(b, 0.55)
	return b


## A dull thud, then a soft low "bup-bup" (slightly detuned so it beats), low-passed so it never stings.
static func _wrong() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.55, r)
	_thump(b, r, 0.0, 110.0, 50.0, 0.9, 0.14)
	for p: Vector3 in [Vector3(0.02, 0.16, 233.0), Vector3(0.2, 0.28, 185.0)]:
		_note(b, r, p.x, p.y, p.z, 0.7, 0.012, 3.0, 0.06, BUZZ)
		_note(b, r, p.x, p.y, p.z + 3.0, 0.45, 0.012, 3.0, 0.06, BUZZ)
	_lowpass(b, 0.22)
	_normalize(b, 0.5)
	return b


## Two-tone alarm (F#5 / C#5, 0.3 s each, never faster than 3 Hz) over a low rumble; fades out at the end.
static func _unsafe_alarm() -> PackedFloat32Array:
	var r := SFX_RATE
	var dur := 2.4
	var b := _buf(dur, r)
	for k: int in 8:
		var f := 740.0 if k % 2 == 0 else 554.37
		_note(b, r, k * 0.3, 0.3, f, 0.7, 0.02, 0.8, 0.04, ALARM)
	_note(b, r, 0.0, dur, 70.0, 0.5, 0.15, 0.4, 0.5, BASS)
	_lowpass(b, 0.35)
	_fade_tail(b, r, 0.45)
	_normalize(b, 0.55)
	return b


## Fanfare: brass pickup G4 G4 C5, a timpani thump, then a held C major chord with a bell run on top.
static func _chapter_complete() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(2.4, r)
	var pick: Array[Vector2] = [Vector2(0.0, 392.0), Vector2(0.13, 392.0), Vector2(0.26, 523.25)]
	for p: Vector2 in pick:
		_note(b, r, p.x, 0.16, p.y, 0.5, 0.008, 3.0, 0.04, BRASS)
	for f: float in [261.63, 329.63, 392.0, 523.25]:
		_note(b, r, 0.42, 1.8, f, 0.3, 0.015, 1.6, 0.5, BRASS)
	_note(b, r, 0.42, 1.9, 65.41, 0.8, 0.008, 2.2, 0.5, BASS)
	_thump(b, r, 0.42, 150.0, 55.0, 1.0, 0.3)
	var run: Array[float] = [1046.5, 1318.5, 1568.0, 2093.0]
	for k: int in run.size():
		_note(b, r, 0.46 + k * 0.08, 1.1, run[k], 0.3, 0.003, 3.5, 0.2, BELL)
	_lowpass(b, 0.55)
	_drive(b, 1.4)
	_normalize(b, 0.68)
	return b


## Sparkle for a badge or achievement: a quick pentatonic run up high and a faint shimmer.
static func _badge() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(1.3, r)
	var notes: Array[float] = [1568.0, 1760.0, 2093.0, 2349.3, 2637.0, 3136.0, 3520.0]
	for k: int in notes.size():
		_note(b, r, k * 0.05, 0.7, notes[k], 0.6 - 0.05 * k, 0.003, 7.0, 0.08, SOFT_BELL)
	var rng := _rng(5)
	var lp := 0.0
	for i: int in int(1.0 * r):
		var t := float(i) / r
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.3 * (x - lp)
		b[i] += (x - lp) * 0.06 * pow(sin(PI * t), 2.0)
	_normalize(b, 0.38)
	return b


## Barely-there tick when the mouse moves onto a button (the same on every button: it must never hint at an answer).
static func _ui_hover() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.035, r)
	_note(b, r, 0.0, 0.03, 2400.0, 0.5, 0.001, 110.0, 0.005, SOFT_BELL)
	_normalize(b, 0.16)
	return b


## Quick airy swipe when changing desktop apps.
static func _app_switch() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.17, r)
	_whoosh(b, r, 0.0, 0.15, 1.0, 0.1, 0.5, 21)
	_sweep(b, r, 0.0, 0.1, 500.0, 900.0, 0.4, 0.003, 30.0)
	_fade_tail(b, r, 0.03)
	_normalize(b, 0.3)
	return b


## Sitting down at the computer: a whoosh in, then a soft power-on (rising fifth).
static func _desk_open() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.8, r)
	_whoosh(b, r, 0.0, 0.3, 0.8, 0.05, 0.35, 23)
	_note(b, r, 0.2, 0.5, 523.25, 0.55, 0.01, 5.0, 0.12, BELL)
	_note(b, r, 0.3, 0.5, 783.99, 0.6, 0.01, 5.0, 0.12, BELL)
	_thump(b, r, 0.2, 120.0, 70.0, 0.45, 0.1)
	_normalize(b, 0.42)
	return b


## Leaving the computer: the same idea falling.
static func _desk_close() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.5, r)
	_note(b, r, 0.0, 0.3, 783.99, 0.5, 0.005, 9.0, 0.08, SOFT_BELL)
	_note(b, r, 0.08, 0.3, 523.25, 0.5, 0.005, 9.0, 0.08, SOFT_BELL)
	_whoosh(b, r, 0.1, 0.3, 0.7, 0.3, 0.05, 25)
	_normalize(b, 0.34)
	return b


## The reward for finishing an inspection: a latch clunk, then a bright rising E6 G6 C7. The choices just unlocked.
static func _gate_unlock() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.8, r)
	_click(b, r, 0.0, 1.0, 31)
	_thump(b, r, 0.0, 240.0, 90.0, 0.8, 0.07)
	_click(b, r, 0.07, 0.8, 33)
	var notes: Array[float] = [1318.5, 1568.0, 2093.0]
	for k: int in notes.size():
		_note(b, r, 0.11 + k * 0.065, 0.6, notes[k], 0.55 + 0.1 * k, 0.002, 6.5, 0.1, BELL)
	_normalize(b, 0.55)
	return b


## Pen tick for a checklist box.
static func _tick() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.09, r)
	_click(b, r, 0.0, 1.0, 35)
	_sweep(b, r, 0.0, 0.07, 1500.0, 2400.0, 0.5, 0.002, 45.0)
	_fade_tail(b, r, 0.015)
	_normalize(b, 0.28)
	return b


## Rubber stamp on paper for submitting a report.
static func _stamp() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.4, r)
	_thump(b, r, 0.0, 170.0, 55.0, 1.0, 0.2)
	_noise_burst(b, r, 0.0, 0.1, 0.8, 0.35, 45.0, 37)
	_click(b, r, 0.0, 0.8, 39)
	_lowpass(b, 0.6)
	_fade_tail(b, r, 0.05)
	_normalize(b, 0.6)
	return b


## Coin-like blip as points land in the score (B5 then E6).
static func _score_up() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.42, r)
	_note(b, r, 0.0, 0.08, 987.77, 0.6, 0.001, 8.0, 0.01, PLUCK)
	_note(b, r, 0.07, 0.33, 1318.5, 0.75, 0.001, 9.0, 0.06, PLUCK)
	_normalize(b, 0.3)
	return b


## Points lost: a small falling blip.
static func _score_down() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.24, r)
	_sweep(b, r, 0.0, 0.22, 420.0, 180.0, 0.8, 0.004, 9.0)
	_fade_tail(b, r, 0.04)
	_lowpass(b, 0.4)
	_normalize(b, 0.28)
	return b


## Shimmer on top of the chime during a run of correct answers.
static func _streak() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.9, r)
	var run: Array[float] = [2093.0, 2637.0, 3136.0, 4186.0]
	for k: int in run.size():
		_note(b, r, k * 0.045, 0.6, run[k], 0.5, 0.002, 7.0, 0.08, SOFT_BELL)
	_whoosh(b, r, 0.0, 0.5, 0.3, 0.4, 0.75, 27)
	_normalize(b, 0.3)
	return b


## Chapter title card: a rising whoosh into a deep boom.
static func _title_hit() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(2.2, r)
	_whoosh(b, r, 0.0, 0.55, 0.9, 0.04, 0.5, 29)
	_thump(b, r, 0.5, 95.0, 38.0, 1.0, 1.0)
	_note(b, r, 0.5, 1.6, 65.41, 0.55, 0.01, 2.0, 0.5, BASS)
	_note(b, r, 0.5, 1.6, 196.0, 0.14, 0.05, 1.8, 0.5, PAD)
	_note(b, r, 0.5, 1.6, 261.63, 0.12, 0.05, 1.8, 0.5, PAD)
	_normalize(b, 0.6)
	return b


## The breach: a hard, distorted hit with digital glitch stutters and a sub drop. The scariest sound in the game.
static func _breach_hit() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(1.6, r)
	_thump(b, r, 0.0, 180.0, 28.0, 1.3, 1.2)
	_noise_burst(b, r, 0.0, 0.3, 1.0, 0.8, 11.0, 41)
	var rng := _rng(43)
	var t := 0.04
	while t < 0.62:
		var hold := rng.randi_range(6, 40)      # sample-and-hold: harsh, digital
		var n := int(rng.randf_range(0.018, 0.05) * r)
		var s0 := int(t * r)
		var amp := 0.75 * (1.0 - t)
		var v := 0.0
		for i: int in n:
			if s0 + i >= b.size():
				break
			if i % hold == 0:
				v = rng.randf_range(-1.0, 1.0)
			b[s0 + i] += v * amp
		t += rng.randf_range(0.05, 0.13)
	_note(b, r, 0.0, 1.4, 92.5, 0.5, 0.005, 1.8, 0.5, BUZZ)
	_note(b, r, 0.0, 1.4, 98.0, 0.5, 0.005, 1.8, 0.5, BUZZ)
	_drive(b, 2.6)
	_lowpass(b, 0.7)
	_fade_tail(b, r, 0.4)
	_normalize(b, 0.8)
	return b


## Game over: a dark minor chord sinking over a low drone.
static func _game_over() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(3.2, r)
	var notes: Array[float] = [220.0, 261.63, 329.63]
	for f: float in notes:
		_glide(b, r, 0.0, 3.0, f, f * 0.84, 0.3, 0.2, 0.9)
	_note(b, r, 0.0, 3.1, 55.0, 0.7, 0.05, 0.7, 0.9, BASS)
	_thump(b, r, 0.0, 90.0, 35.0, 0.9, 0.9)
	_lowpass(b, 0.3)
	_normalize(b, 0.55)
	return b


## Flawless chapter: the badge sparkle with a warm bell chord under it.
static func _gold_badge() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(1.8, r)
	for f: float in [1046.5, 1318.5, 1568.0]:
		_note(b, r, 0.0, 1.6, f, 0.4, 0.004, 2.5, 0.4, BELL)
	var run: Array[float] = [2093.0, 2349.3, 2637.0, 3136.0, 3520.0, 4186.0]
	for k: int in run.size():
		_note(b, r, 0.1 + k * 0.06, 0.8, run[k], 0.42, 0.002, 6.0, 0.1, SOFT_BELL)
	_thump(b, r, 0.0, 140.0, 70.0, 0.5, 0.15)
	_normalize(b, 0.5)
	return b


## Achievement unlocked: a quick "ta-da" pop.
static func _achievement() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.8, r)
	_note(b, r, 0.0, 0.12, 783.99, 0.6, 0.003, 5.0, 0.03, BELL)
	_note(b, r, 0.1, 0.65, 1174.66, 0.7, 0.003, 4.0, 0.15, BELL)
	_note(b, r, 0.1, 0.65, 1567.98, 0.55, 0.003, 4.0, 0.15, BELL)
	_thump(b, r, 0.1, 150.0, 80.0, 0.4, 0.09)
	_normalize(b, 0.42)
	return b


## The good ending: a full brass fanfare, C - F - G - C, with timpani and a long bell finish.
static func _victory() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(5.0, r)
	var chords: Array = [[0.0, [261.63, 329.63, 392.0], 65.41], [0.5, [349.23, 440.0, 523.25], 87.31],
		[1.0, [392.0, 493.88, 587.33], 98.0]]
	for c: Array in chords:
		for f: float in c[1]:
			_note(b, r, c[0], 0.46, f, 0.3, 0.01, 1.5, 0.08, BRASS)
		_note(b, r, c[0], 0.46, c[2], 0.75, 0.01, 2.0, 0.08, BASS)
		_thump(b, r, c[0], 150.0, 55.0, 0.85, 0.25)
	for f: float in [261.63, 329.63, 392.0, 523.25, 659.25]:
		_note(b, r, 1.5, 3.3, f, 0.28, 0.02, 0.9, 1.0, BRASS)
	_note(b, r, 1.5, 3.3, 65.41, 0.8, 0.01, 1.1, 1.0, BASS)
	_thump(b, r, 1.5, 150.0, 45.0, 1.2, 0.5)
	var run: Array[float] = [1046.5, 1318.5, 1568.0, 2093.0, 2637.0, 3136.0]
	for k: int in run.size():
		_note(b, r, 1.55 + k * 0.09, 2.2, run[k], 0.26, 0.003, 1.8, 0.5, BELL)
	_lowpass(b, 0.55)
	_drive(b, 1.3)
	_normalize(b, 0.7)
	return b


## Restart Chapter: a quick rewind sweep up.
static func _restart() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(0.5, r)
	_sweep(b, r, 0.0, 0.42, 180.0, 1500.0, 0.8, 0.01, 2.0)
	_whoosh(b, r, 0.0, 0.42, 0.5, 0.05, 0.6, 45)
	_fade_tail(b, r, 0.08)
	_normalize(b, 0.34)
	return b


## Telephone keypad tone (DTMF): the two standard frequencies of the key, short and soft.
static func _dtmf(key: String) -> PackedFloat32Array:
	var layout := "123456789*0#"
	var i := layout.find(key if key.length() == 1 else ("*" if key == "star" else "#"))
	if i < 0:
		i = 0
	var rows: Array[float] = [697.0, 770.0, 852.0, 941.0]
	var cols: Array[float] = [1209.0, 1336.0, 1477.0]
	var r := SFX_RATE
	var b := _buf(0.14, r)
	_note(b, r, 0.0, 0.14, rows[i / 3], 0.5, 0.004, 0.0, 0.02, [1.0, 1.0])
	_note(b, r, 0.0, 0.14, cols[i % 3], 0.5, 0.004, 0.0, 0.02, [1.0, 1.0])
	_normalize(b, 0.3)
	return b


## Outgoing ringback heard while a placed call connects: one ring (440 + 480 Hz).
static func _ringback() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(1.15, r)
	_note(b, r, 0.0, 0.9, 440.0, 0.5, 0.02, 0.0, 0.05, [1.0, 1.0])
	_note(b, r, 0.0, 0.9, 480.0, 0.5, 0.02, 0.0, 0.05, [1.0, 1.0])
	_normalize(b, 0.3)
	return b


## A number that does not answer: three short low beeps (480 + 620 Hz).
static func _no_answer() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(1.2, r)
	for k: int in 3:
		_note(b, r, k * 0.4, 0.22, 480.0, 0.5, 0.01, 0.0, 0.03, [1.0, 1.0])
		_note(b, r, k * 0.4, 0.22, 620.0, 0.5, 0.01, 0.0, 0.03, [1.0, 1.0])
	_normalize(b, 0.3)
	return b


## Coffee maker brewing (4.5 s): a soft hiss, gurgling bubbles that build and settle, then a few drips.
static func _coffee_brew() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(4.7, r)
	var rng := _rng(31)
	_whoosh(b, r, 0.0, 4.4, 0.05, 0.02, 0.08, 32)
	var t := 0.15
	while t < 3.9:
		var u := t / 3.9
		var dens := sin(PI * minf(1.0, u * 1.15))
		_bubble(b, r, t, rng.randf_range(140.0, 260.0), rng.randf_range(320.0, 560.0), rng.randf_range(0.03, 0.07),
			rng.randf_range(0.25, 0.5) * (0.4 + dens))
		t += rng.randf_range(0.03, 0.09) / maxf(0.25, dens)
	for k: int in 4:
		_bubble(b, r, 4.0 + k * 0.17 + rng.randf() * 0.05, 1300.0 - k * 90.0, 900.0, 0.05, 0.22)
	_lowpass(b, 0.45)
	_fade_tail(b, r, 0.1)
	_normalize(b, 0.4)
	return b


## Pouring a cup of coffee (1.2 s): a liquid rush whose ring rises as the cup fills.
static func _coffee_pour() -> PackedFloat32Array:
	return _pour(1.2, 300.0, 820.0, 41, 0.4)


## Getting a cup of water (2.2 s): the cup drops onto the tray, the stream fills it, the bottle glugs once.
static func _water_pour() -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _pour(2.2, 380.0, 1000.0, 51, 0.36)
	_click(b, r, 0.02, 0.5, 52)
	_bubble(b, r, 1.3, 110.0, 190.0, 0.12, 0.6)
	_bubble(b, r, 1.45, 130.0, 220.0, 0.1, 0.45)
	_normalize(b, 0.4)
	return b


## A stream of liquid into a cup: noise through a resonance that climbs from f0 to f1, with small bubbles.
static func _pour(dur: float, f0: float, f1: float, seed_value: int, peak: float) -> PackedFloat32Array:
	var r := SFX_RATE
	var b := _buf(dur + 0.1, r)
	var rng := _rng(seed_value)
	var y1 := 0.0
	var y2 := 0.0
	var n := int(dur * r)
	var start := int(0.2 * r)
	for i: int in n:
		if start + i >= b.size():
			break
		var u := float(i) / n
		var f := lerpf(f0, f1, u * u)
		var q := 0.985
		var w := TAU * f / r
		var x := rng.randf_range(-1.0, 1.0)
		var y := x * (1.0 - q) + 2.0 * q * cos(w) * y1 - q * q * y2
		y2 = y1
		y1 = y
		var env := minf(1.0, u * 12.0) * minf(1.0, (1.0 - u) * 8.0)
		b[start + i] += y * env * 3.0 + x * env * 0.04
	var t := 0.25
	while t < dur:
		_bubble(b, r, t, rng.randf_range(500.0, 900.0), rng.randf_range(1000.0, 1600.0), 0.025, 0.08)
		t += rng.randf_range(0.04, 0.12)
	_fade_tail(b, r, 0.08)
	_normalize(b, peak)
	return b


## One bubble: a short sine whose pitch rises from f0 to f1 as it decays.
static func _bubble(b: PackedFloat32Array, rate: int, start: float, f0: float, f1: float, dur: float, amp: float) -> void:
	var s0 := int(start * rate)
	var n := int(dur * rate)
	var phase := 0.0
	for i: int in n:
		if s0 + i >= b.size():
			break
		var u := float(i) / n
		phase += TAU * lerpf(f0, f1, u) / rate
		b[s0 + i] += sin(phase) * amp * (1.0 - u) * (1.0 - u) * minf(1.0, float(i) / 40.0)


## 4 s of keyboard typing with pauses, for the typing coworker (looped by a 3D player).
static func _typing() -> PackedFloat32Array:
	var r := LOOP_RATE
	var b := _buf(4.0, r)
	var rng := _rng(11)
	var t := 0.05
	while t < 3.9:
		var tf := rng.randf_range(1500.0, 2600.0)
		var space := rng.randf() < 0.15
		var n := int(0.03 * r)
		var s0 := int(t * r)
		var lp := 0.0
		var level := rng.randf_range(0.6, 1.0)
		for i: int in n:
			if s0 + i >= b.size():
				break
			var tt := float(i) / r
			var x := rng.randf_range(-1.0, 1.0)
			lp += 0.25 * (x - lp)
			var v := (x - lp) * exp(-tt * 350.0) + sin(TAU * tf * tt) * exp(-tt * 500.0) * 0.25
			if space:
				v += sin(TAU * 300.0 * tt) * exp(-tt * 120.0) * 0.4
			b[s0 + i] += v * level
		if rng.randf() < 0.12:
			t += rng.randf_range(0.35, 0.7)
		else:
			t += rng.randf_range(0.075, 0.17)
	_normalize(b, 0.5)
	return b


## Soft paper swish for a dialogue line advance.
static func _page_turn() -> PackedFloat32Array:
	var r := SFX_RATE
	var dur := 0.32
	var b := _buf(dur, r)
	var rng := _rng(9)
	var slow := 0.0
	var smooth := 0.0
	for i: int in b.size():
		var t := float(i) / r
		var x := rng.randf_range(-1.0, 1.0)
		slow += 0.05 * (x - slow)
		smooth += 0.35 * ((x - slow) - smooth)
		var env := pow(sin(PI * minf(t / (dur - 0.02), 1.0)), 2.0) * (1.0 - 0.6 * t / dur)
		b[i] = smooth * env
	_normalize(b, 0.25)
	return b


# =====================================================================================================
# Ambience and music (loops)
# =====================================================================================================

## 8 s office room tone: brown-noise room bed, low-passed aircon airflow with a slow swell and a faint hum.
static func _ambient() -> PackedFloat32Array:
	var r := LOOP_RATE
	var n := 8 * r
	var f := r >> 1
	var out := _loop_seam(_room_tone(n + f, 2.5, 0.035), n, f)
	_normalize(out, 0.5)
	return out


## 8 s home room tone: the same room bed with only a little air and no aircon hum (Audio plays it ~6 dB quieter).
static func _ambient_home() -> PackedFloat32Array:
	var r := LOOP_RATE
	var n := 8 * r
	var f := r >> 1
	var out := _loop_seam(_room_tone(n + f, 0.9, 0.0), n, f)
	_normalize(out, 0.5)
	return out


## 8 s cafe ambience: the room tone plus a soft, constant murmur of many far-off voices (band-passed noise
## "voices" with slow syllable-rate swells that average out). No events: no clinks, no words, nothing that could
## line up with a message.
static func _ambient_cafe() -> PackedFloat32Array:
	var r := LOOP_RATE
	var n := 8 * r
	var f := r >> 1
	var room := _room_tone(n + f, 1.6, 0.0)
	_normalize(room, 1.0)
	var babble := _buf(float(n + f) / r, r)
	var rng := _rng(77)
	for v: int in 7:
		var fc := rng.randf_range(320.0, 950.0)
		var k := 2.0 * sin(PI * fc / r)
		var low := 0.0
		var band := 0.0
		var env := 0.0
		var target := 0.5
		var next_change := 0
		for i: int in babble.size():
			if i >= next_change:
				target = rng.randf_range(0.25, 1.0)
				next_change = i + int(rng.randf_range(0.09, 0.28) * r)
			env += 0.0009 * (target - env)
			var x := rng.randf_range(-1.0, 1.0)
			low += k * band
			var high := x - low - 1.1 * band
			band += k * high
			babble[i] += band * env
	_lowpass(babble, 0.35)
	_normalize(babble, 1.0)
	var mix := _buf(float(n + f) / r, r)
	for i: int in mix.size():
		mix[i] = room[i] * 0.6 + babble[i] * 0.42
	var out := _loop_seam(mix, n, f)
	_normalize(out, 0.5)
	return out


## `samples` of room tone: a brown-noise bed, low-passed airflow (`air`) with a slow swell and a mains hum (`hum`).
## The office loop uses air 2.5 and hum 0.035 (unchanged from before the home and cafe beds existed).
static func _room_tone(samples: int, air_amp: float, hum_amp: float) -> PackedFloat32Array:
	var r := LOOP_RATE
	var b := _buf(float(samples) / r, r)
	var rng := _rng(21)
	var br := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	for i: int in b.size():
		var t := float(i) / r
		br = (br + 0.02 * rng.randf_range(-1.0, 1.0)) * 0.995
		lp1 += 0.06 * (rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += 0.06 * (lp1 - lp2)
		var air := lp2 * (0.85 + 0.15 * sin(TAU * 0.25 * t))
		var hum := 0.5 * sin(TAU * 100.0 * t) + 0.25 * sin(TAU * 200.0 * t) + 0.12 * sin(TAU * 300.0 * t)
		b[i] = br * 0.7 + air * air_amp + hum * hum_amp
	return b


## Calm, warm, slow: Cmaj7 - Am7 - Fmaj7 - G6, 4 s each (16 s loop), soft pad, round bass and sparse keys.
static func _music_day() -> PackedFloat32Array:
	var r := LOOP_RATE
	var b := _buf(16.0, r)
	var bass: Array[int] = [36, 33, 29, 31]
	var pads: Array = [[52, 55, 59, 64], [52, 55, 60, 64], [52, 57, 60, 64], [50, 55, 59, 62]]
	var keys: Array = [[71, 67, 64, 67], [72, 67, 64, 69], [69, 72, 64, 67], [71, 67, 62, 74]]
	var key_times: Array[float] = [0.5, 1.5, 2.25, 3.0]
	for c: int in 4:
		var start := c * 4.0
		_note(b, r, start, 4.3, _midi(bass[c]), 0.5, 0.05, 0.45, 0.6, BASS, true)
		for m: int in pads[c]:
			var hz := _midi(m)
			_note(b, r, start, 4.9, hz, 0.2, 1.3, 0.05, 1.2, PAD, true)
			_note(b, r, start, 4.9, hz * 1.0035, 0.12, 1.3, 0.05, 1.2, PAD, true)
		for k: int in key_times.size():
			_note(b, r, start + key_times[k], 1.9, _midi(float(keys[c][k])), 0.16, 0.006, 2.2, 0.3, KEYS, true)
	_normalize(b, 0.6)
	return b


## Chapters 3-4: the day progression with a soft kick, off-beat hats and a running arpeggio, so the game picks up.
static func _music_drive() -> PackedFloat32Array:
	var r := LOOP_RATE
	var b := _buf(16.0, r)
	var bass: Array[int] = [36, 33, 29, 31]
	var pads: Array = [[52, 55, 59, 64], [52, 55, 60, 64], [52, 57, 60, 64], [50, 55, 59, 62]]
	var arps: Array = [[64, 67, 71, 76], [64, 69, 72, 76], [65, 69, 72, 77], [62, 67, 71, 74]]
	for c: int in 4:
		var start := c * 4.0
		for m: int in pads[c]:
			_note(b, r, start, 4.9, _midi(m), 0.15, 1.0, 0.05, 1.2, PAD, true)
		for k: int in 8:
			var at := start + k * 0.5
			_note(b, r, at, 0.45, _midi(bass[c]), 0.42 if k % 2 == 0 else 0.26, 0.006, 3.5, 0.06, BASS, true)
		for k: int in 16:
			var note: int = arps[c][k % 4]
			_note(b, r, start + k * 0.25, 0.3, _midi(note), 0.14, 0.004, 7.0, 0.05, PLUCK, true)
		for k: int in 4:
			_thump(b, r, start + k, 110.0, 50.0, 0.62, 0.13)
			_noise_burst(b, r, start + k + 0.5, 0.05, 0.13, 0.9, 60.0, 51 + k)
	_normalize(b, 0.6)
	return b


## Tense, low: Am - Fmaj7 - Dm - E7 over a sub drone and a steady eighth-note pulse (16 s loop).
static func _music_night() -> PackedFloat32Array:
	var r := LOOP_RATE
	var b := _buf(16.0, r)
	var roots: Array[int] = [33, 29, 38, 28]
	var pads: Array = [[52, 57, 60, 64], [53, 57, 60, 64], [50, 53, 57, 62], [52, 56, 59, 62]]
	for c: int in 4:
		var start := c * 4.0
		var root := _midi(roots[c])
		_note(b, r, start, 4.3, root, 0.45, 0.3, 0.1, 0.4, [1.0, 1.0], true)
		for m: int in pads[c]:
			var hz := _midi(m)
			_note(b, r, start, 4.9, hz, 0.12, 1.6, 0.05, 1.3, DARK_PAD, true)
			_note(b, r, start, 4.9, hz * 0.997, 0.08, 1.6, 0.05, 1.3, DARK_PAD, true)
		for k: int in 16:
			var accent := 0.5 if k % 4 == 0 else 0.3
			_note(b, r, start + k * 0.25, 0.22, root * 2.0, accent, 0.004, 10.0, 0.04, PLUCK, true)
	var pings: Array[Vector2] = [Vector2(3.5, 659.25), Vector2(7.5, 523.25), Vector2(11.5, 698.46), Vector2(15.25, 622.25)]
	for p: Vector2 in pings:
		_note(b, r, p.x, 1.5, p.y, 0.12, 0.005, 3.0, 0.3, SOFT_BELL, true)
	_normalize(b, 0.6)
	return b


# =====================================================================================================
# Building blocks
# =====================================================================================================

static func _buf(seconds: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(1, int(seconds * rate)))
	b.fill(0.0)
	return b


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Adds one note to `b`. `partials` are [multiple, amplitude] pairs. Envelope: linear attack, exponential decay,
## linear release over the last `release` s of `dur`. With `wrap` the note continues from the buffer start
## (seamless loops).
static func _note(b: PackedFloat32Array, rate: int, start: float, dur: float, freq: float, amp: float,
		attack: float, decay: float, release: float, partials: Array, wrap: bool = false) -> void:
	var size := b.size()
	var s0 := int(start * rate)
	var n := int(dur * rate)
	var inv := 1.0 / rate
	var pc := partials.size() >> 1
	var ws := PackedFloat32Array()
	var amps := PackedFloat32Array()
	for k: int in pc:
		ws.append(TAU * freq * float(partials[k * 2]))
		amps.append(float(partials[k * 2 + 1]))
	var rel := maxf(release, 0.005)
	var rel_start := dur - rel
	var att := maxf(attack, 0.0005)
	for i: int in n:
		var idx := s0 + i
		if idx >= size:
			if not wrap:
				break
			idx = idx % size
		var t := i * inv
		var env := amp
		if t < att:
			env *= t / att
		if decay > 0.0:
			env *= exp(-t * decay)
		if t > rel_start:
			env *= (dur - t) / rel
		var v := 0.0
		for k: int in pc:
			v += amps[k] * sin(ws[k] * t)
		b[idx] += v * env


## A sine sweeping from f0 to f1 (phase-continuous), attack and exponential decay.
static func _sweep(b: PackedFloat32Array, rate: int, start: float, dur: float, f0: float, f1: float, amp: float,
		attack: float, decay: float) -> void:
	var s0 := int(start * rate)
	var n := int(dur * rate)
	var phase := 0.0
	for i: int in n:
		if s0 + i >= b.size():
			break
		var t := float(i) / rate
		phase += TAU * lerpf(f0, f1, t / dur) / rate
		var env := amp * minf(1.0, t / attack) * exp(-t * decay)
		b[s0 + i] += (sin(phase) + 0.2 * sin(phase * 2.0)) * env


## A low, falling thunk with a click on top (handset on the cradle).
static func _clunk(b: PackedFloat32Array, rate: int, start: float, f0: float, f1: float, amp: float) -> void:
	_sweep(b, rate, start, 0.25, f0, f1, amp, 0.002, 22.0)
	_click(b, rate, start, 0.6 * amp, 13)


## A very short high-passed noise click.
static func _click(b: PackedFloat32Array, rate: int, start: float, amp: float, seed_value: int) -> void:
	var rng := _rng(seed_value)
	var s0 := int(start * rate)
	var lp := 0.0
	for i: int in int(0.02 * rate):
		if s0 + i >= b.size():
			break
		var t := float(i) / rate
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.2 * (x - lp)
		b[s0 + i] += (x - lp) * amp * exp(-t * 300.0)


## A falling sine kick: the "weight" under a hit. Skipped past the buffer end.
static func _thump(b: PackedFloat32Array, rate: int, start: float, f0: float, f1: float, amp: float, dur: float) -> void:
	var s0 := int(start * rate)
	var phase := 0.0
	var k := 1.0 / maxf(dur, 0.01)
	for i: int in int(dur * rate):
		if s0 + i >= b.size():
			break
		var t := float(i) / rate
		var u := t * k
		phase += TAU * lerpf(f0, f1, minf(1.0, u * 2.0)) / rate
		b[s0 + i] += sin(phase) * amp * minf(1.0, t / 0.002) * (1.0 - u) * (1.0 - u)


## Filtered noise that sweeps from dark to bright (or back), shaped like a breath: a "whoosh".
static func _whoosh(b: PackedFloat32Array, rate: int, start: float, dur: float, amp: float, a0: float, a1: float, seed_value: int) -> void:
	var rng := _rng(seed_value)
	var s0 := int(start * rate)
	var n := int(dur * rate)
	var lp := 0.0
	for i: int in n:
		if s0 + i >= b.size():
			break
		var u := float(i) / n
		lp += lerpf(a0, a1, u) * (rng.randf_range(-1.0, 1.0) - lp)
		b[s0 + i] += lp * amp * 3.0 * sin(PI * u)


## A decaying burst of filtered noise. Wraps around in looping buffers.
static func _noise_burst(b: PackedFloat32Array, rate: int, start: float, dur: float, amp: float, a: float, decay: float, seed_value: int) -> void:
	var rng := _rng(seed_value)
	var s0 := int(start * rate)
	var lp := 0.0
	for i: int in int(dur * rate):
		var t := float(i) / rate
		var x := rng.randf_range(-1.0, 1.0)
		lp += a * (x - lp)
		b[(s0 + i) % b.size()] += lp * amp * exp(-t * decay)


## A note that slides in pitch, with slow attack and release.
static func _glide(b: PackedFloat32Array, rate: int, start: float, dur: float, f0: float, f1: float, amp: float, attack: float, release: float) -> void:
	var s0 := int(start * rate)
	var n := int(dur * rate)
	var phase := 0.0
	for i: int in n:
		if s0 + i >= b.size():
			break
		var t := float(i) / rate
		phase += TAU * lerpf(f0, f1, float(i) / n) / rate
		var env := amp * minf(1.0, t / attack) * minf(1.0, (dur - t) / release)
		b[s0 + i] += (sin(phase) + 0.4 * sin(phase * 2.0) + 0.15 * sin(phase * 3.0)) * env


## Soft-clipping saturation: thickens a sound and keeps it from peaking.
static func _drive(b: PackedFloat32Array, k: float) -> void:
	for i: int in b.size():
		var x := b[i] * k
		b[i] = x / (1.0 + absf(x))


## One-pole low-pass over the whole buffer (0 < a <= 1, smaller = darker).
static func _lowpass(b: PackedFloat32Array, a: float) -> void:
	var y := 0.0
	for i: int in b.size():
		y += a * (b[i] - y)
		b[i] = y


## Linear fade over the last `seconds`.
static func _fade_tail(b: PackedFloat32Array, rate: int, seconds: float) -> void:
	var n := mini(int(seconds * rate), b.size())
	var size := b.size()
	for i: int in n:
		b[size - n + i] *= 1.0 - float(i + 1) / n


## Scales so the loudest sample is `peak`.
static func _normalize(b: PackedFloat32Array, peak: float) -> void:
	var m := 0.0
	for v: float in b:
		m = maxf(m, absf(v))
	if m <= 0.0:
		return
	var k := peak / m
	for i: int in b.size():
		b[i] *= k


## `b` holds n + f samples: the first f samples are crossfaded with the f past the loop end, so sample n-1 runs
## straight into sample 0. Returns the n-sample loop.
static func _loop_seam(b: PackedFloat32Array, n: int, f: int) -> PackedFloat32Array:
	var out := b.slice(0, n)
	for i: int in f:
		var k := float(i) / f
		out[i] = b[n + i] * (1.0 - k) + b[i] * k
	return out
