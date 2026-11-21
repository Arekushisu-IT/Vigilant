extends Node
## Game feel: sound effects, ambience and music. Every sound is SYNTHESIZED IN CODE (16-bit PCM written into an
## AudioStreamWAV); there are no audio files and nothing is downloaded. Each stream is rendered once per run and
## cached. Long loops (music, ambience) are rendered on the WorkerThreadPool so the menu never stalls.
##
## Buses (created here): Master -> Music, SFX. Settings sets their volumes (master / music / sound effects).
## Headless (the smoke test, dummy audio driver): nothing is rendered or played, every call returns at once.
##
## API: play_sfx(name, volume_db, pitch), play_3d(name, world_pos, volume_db, pitch), get_stream(name),
## set_music(track) with a crossfade, stop_music(), start_ambient(), stop_ambient(), set_place_ambient(place),
## track_for_chapter(n), synth(name) (always renders; used by tests/render_audio_preview.gd).
## Music and ambience are chosen per chapter and per place only, never per message: the same ringtone and the same
## notification sound play for every item, so no sound can hint at an answer.

const SFX_RATE := 44100
const LOOP_RATE := 22050
const SFX_NAMES: Array[String] = ["footstep", "ui_click", "notify_ping", "phone_ring", "phone_pickup", "phone_hangup",
	"evidence_found", "copy", "paste", "correct", "wrong", "unsafe_alarm", "chapter_complete", "badge", "typing",
	"page_turn", "ui_hover", "app_switch", "desk_open", "desk_close", "gate_unlock", "tick", "stamp", "score_up",
	"score_down", "streak", "title_hit", "breach_hit", "game_over", "gold_badge", "achievement", "victory", "restart",
	"ringback", "no_answer", "dtmf_1", "dtmf_2", "dtmf_3", "dtmf_4", "dtmf_5", "dtmf_6", "dtmf_7", "dtmf_8", "dtmf_9",
	"dtmf_0", "dtmf_star", "dtmf_hash", "coffee_brew", "coffee_pour", "water_pour"]
const LOOP_NAMES: Array[String] = ["ambient", "ambient_home", "ambient_cafe", "day", "drive", "night"]
const LOOPING: Array[String] = ["phone_ring", "typing", "ambient", "ambient_home", "ambient_cafe", "day", "drive", "night"]
## Ambience per place: [loop name, level in dB]. Home is the room tone ~6 dB quieter with no aircon hum; the cafe
## is the room tone with a soft, constant murmur bed.
const PLACE_AMBIENT := {
	"office": ["ambient", -19.0],
	"home": ["ambient_home", -25.0],
	"cafe": ["ambient_cafe", -19.0],
}
const MUSIC_TRACKS: Array[String] = ["day", "drive", "night"]
## Major-scale steps (semitones) a run of correct answers climbs through.
const STREAK_STEPS: Array[int] = [0, 2, 4, 5, 7, 9, 12]
const STREAK_SHIMMER_AT := 3     ## correct answers in a row before the shimmer joins in
const EVIDENCE_STEPS: Array[int] = [0, 4, 7, 12]
const MUSIC_DB := -11.0          ## music player level before the Music bus slider (kept low on purpose)
const AMBIENT_DB := -19.0        ## office room tone + aircon hum, very quiet
const CROSSFADE := 2.5
const POOL_SIZE := 12
const SILENT_LINEAR := 0.0001

## The music track asked for last ("day", "night" or "" when stopped).
var current_track: String = ""
## The place whose ambience plays ("office", "home" or "cafe"); set by set_place_ambient(), kept headless too.
var ambient_place: String = "office"

var _silent := false
var _cache: Dictionary = {}           ## name -> AudioStreamWAV
var _pending: Dictionary = {}         ## name -> WorkerThreadPool task id
var _results: Dictionary = {}         ## name -> 16-bit PCM bytes (written by worker threads)
var _mutex := Mutex.new()
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _music_level: Array[float] = [0.0, 0.0]    ## linear fade level of each music player
var _active := 0
var _fade: Tween
var _ambient: AudioStreamPlayer
var _ambient_fade: Tween
var _want_ambient := false
var _streak := 0                 ## correct answers in a row (sound only: scoring never sees this)
var _duck_db := 0.0              ## extra music level while a big moment plays
var _duck: Tween


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	Settings.apply_audio()
	_silent = DisplayServer.get_name() == "headless"
	if not _silent:
		get_tree().node_added.connect(_on_node_added)


func _ready() -> void:
	set_process(false)
	if _silent:
		return
	for i: int in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i: int in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = linear_to_db(SILENT_LINEAR)
		add_child(m)
		_music.append(m)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "SFX"
	_ambient.volume_db = linear_to_db(SILENT_LINEAR)
	add_child(_ambient)
	# Warm the cache in the background: the menu track first, then the effects, the ambience and the night track.
	_request("day")
	for n: String in SFX_NAMES:
		_request(n)
	_request("ambient")
	_request("drive")
	_request("night")
	_request("ambient_home")
	_request("ambient_cafe")


func _exit_tree() -> void:
	for n: String in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(_pending[n])
	_pending.clear()


func is_silent() -> bool:
	return _silent


# =====================================================================================================
# Public API
# =====================================================================================================

## Plays a one-shot (non-positional) sound on the SFX bus.
func play_sfx(sfx: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _silent:
		return
	var s := get_stream(sfx)
	if s == null:
		return
	var p := _free_player()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.play()


## Plays a one-shot sound at a world position (frees itself when done).
func play_3d(sfx: String, world_pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _silent:
		return
	var s := get_stream(sfx)
	var scene := get_tree().current_scene
	if s == null or not (scene is Node3D):
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 3.0
	scene.add_child(p)
	p.global_position = world_pos
	p.finished.connect(p.queue_free)
	p.play()


## The cached stream of a sound (rendered now if it is not ready yet). Null when headless.
func get_stream(sfx: String) -> AudioStreamWAV:
	if _silent:
		return null
	if _cache.has(sfx):
		return _cache[sfx]
	if _pending.has(sfx):
		WorkerThreadPool.wait_for_task_completion(_pending[sfx])
		_pending.erase(sfx)
		_collect(sfx)
	if not _cache.has(sfx):
		_cache[sfx] = synth(sfx)
	return _cache[sfx]


## The right-answer chime, climbing in pitch through a run of correct answers. Only sound depends on the run.
func play_correct() -> void:
	var step: int = STREAK_STEPS[mini(_streak, STREAK_STEPS.size() - 1)]
	_streak += 1
	play_sfx("correct", -2.0, pow(2.0, step / 12.0))
	if _streak >= STREAK_SHIMMER_AT:
		play_sfx("streak", -5.0)
	duck_music(-6.0, 0.7)


func play_wrong() -> void:
	_streak = 0
	play_sfx("wrong", -3.0)


## A newly found piece of evidence; `index` is how many were found on this message, so each one rings higher.
func play_evidence(index: int) -> void:
	var step: int = EVIDENCE_STEPS[clampi(index, 0, EVIDENCE_STEPS.size() - 1)]
	play_sfx("evidence_found", -3.0, pow(2.0, step / 12.0))


func reset_streak() -> void:
	_streak = 0


func streak() -> int:
	return _streak


## Dips the music for a moment so a big sound lands.
func duck_music(db: float, seconds: float) -> void:
	if _silent:
		return
	if _duck != null:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_method(_set_duck, _duck_db, db, 0.06)
	_duck.tween_interval(seconds)
	_duck.tween_method(_set_duck, db, 0.0, 0.8)


## The floor drops out: the music stops almost at once (a breach). The next set_music() starts it again.
func cut_music() -> void:
	current_track = ""
	if _silent:
		return
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	for i: int in _music.size():
		_fade.tween_method(_set_music_level.bind(i), _music_level[i], 0.0, 0.12)
	_fade.chain().tween_callback(_stop_quiet_music)


## Crossfades to a music loop ("day", "drive" or "night"). Asking for the playing track does nothing.
func set_music(track: String) -> void:
	if track == current_track:
		return
	current_track = track
	if _silent:
		return
	if _cache.has(track):
		_crossfade_to(_cache[track])
	else:
		_request(track)        # _on_ready() starts it once rendered


func stop_music() -> void:
	current_track = ""
	if _silent:
		return
	_crossfade_to(null)


## The chapter's music track from the chapter data ("music": "day", "drive" or "night"; the menus and the ending use
## "day" or "night" directly). Without the key it falls back to tiers: "day" for 1-3, "drive" for 4-7, "night" from 8.
## It depends only on the chapter, never on a message, so it can't give away whether something is fake.
func track_for_chapter(n: int) -> String:
	var fallback := "night" if n >= 8 else ("drive" if n >= 4 else "day")
	if n < 1 or n > Campaign.CHAPTERS.size():
		return fallback
	var track := str(Campaign.chapter(n).get("music", fallback))
	return track if MUSIC_TRACKS.has(track) else fallback


## Quiet room tone of the current place (the office scene turns it on and off; see set_place_ambient()).
func start_ambient() -> void:
	_want_ambient = true
	if _silent:
		return
	if _cache.has(_ambient_sound()):
		_fade_ambient(true)
	else:
		_request(_ambient_sound())


## Picks the ambience for a place ("office", "home" or "cafe"; anything else counts as the office). If ambience is
## playing, it crossfades to the new place's bed. Chapter- and place-level only: identical for every item.
func set_place_ambient(place: String) -> void:
	var p := place if PLACE_AMBIENT.has(place) else "office"
	if p == ambient_place:
		return
	ambient_place = p
	if _silent or not _want_ambient:
		return
	if _cache.has(_ambient_sound()):
		_fade_ambient(true)
	else:
		_request(_ambient_sound())


func stop_ambient() -> void:
	_want_ambient = false
	if _silent:
		return
	_fade_ambient(false)


## Renders a sound or loop from scratch and returns it as a 16-bit WAV stream (no caching, works headless).
func synth(sfx: String) -> AudioStreamWAV:
	return _wav(_pcm16(AudioSynth.render(sfx)), AudioSynth.rate_of(sfx), LOOPING.has(sfx))


# =====================================================================================================
# Internals
# =====================================================================================================

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	if bus_name == "Music":
		var verb := AudioEffectReverb.new()
		verb.room_size = 0.55
		verb.damping = 0.6
		verb.wet = 0.18
		verb.dry = 0.95
		AudioServer.add_bus_effect(i, verb)


## Every button in the game gives a soft click (one helper instead of editing every button).
func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b != null and not b.pressed.is_connected(_on_button_pressed):
		b.pressed.connect(_on_button_pressed)
		b.mouse_entered.connect(_on_button_hovered.bind(b))


func _on_button_pressed() -> void:
	play_sfx("ui_click", -6.0, randf_range(0.97, 1.03))


## The same tick for every usable button, so hovering can never hint at an answer.
func _on_button_hovered(b: BaseButton) -> void:
	if not b.disabled:
		play_sfx("ui_hover", -10.0)


func _free_player() -> AudioStreamPlayer:
	for i: int in _pool.size():
		var p: AudioStreamPlayer = _pool[(_next + i) % _pool.size()]
		if not p.playing:
			_next = (_next + i + 1) % _pool.size()
			return p
	var oldest: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	return oldest


func _request(sfx: String) -> void:
	if _cache.has(sfx) or _pending.has(sfx):
		return
	_pending[sfx] = WorkerThreadPool.add_task(_render_task.bind(sfx), false, "synth " + sfx)
	set_process(true)


## Runs on a worker thread: pure math, no nodes touched.
func _render_task(sfx: String) -> void:
	var bytes := _pcm16(AudioSynth.render(sfx))
	_mutex.lock()
	_results[sfx] = bytes
	_mutex.unlock()


func _process(_delta: float) -> void:
	for sfx: String in _pending.keys():
		if WorkerThreadPool.is_task_completed(_pending[sfx]):
			WorkerThreadPool.wait_for_task_completion(_pending[sfx])
			_pending.erase(sfx)
			_collect(sfx)
			_on_ready(sfx)
	if _pending.is_empty():
		set_process(false)


func _collect(sfx: String) -> void:
	_mutex.lock()
	var bytes: PackedByteArray = _results.get(sfx, PackedByteArray())
	_results.erase(sfx)
	_mutex.unlock()
	if not bytes.is_empty():
		_cache[sfx] = _wav(bytes, AudioSynth.rate_of(sfx), LOOPING.has(sfx))


func _on_ready(sfx: String) -> void:
	if sfx == current_track and _cache.has(sfx):
		var playing := _music[_active].stream
		if playing != _cache[sfx]:
			_crossfade_to(_cache[sfx])
	elif sfx == _ambient_sound() and _want_ambient:
		_fade_ambient(true)


func _crossfade_to(stream: AudioStream) -> void:
	var old_i := _active
	var new_i := 1 - _active
	_active = new_i
	var incoming := _music[new_i]
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	if stream != null:
		incoming.stream = stream
		incoming.play()
		_fade.tween_method(_set_music_level.bind(new_i), _music_level[new_i], 1.0, CROSSFADE)
	_fade.tween_method(_set_music_level.bind(old_i), _music_level[old_i], 0.0, CROSSFADE)
	_fade.chain().tween_callback(_stop_quiet_music)


func _set_music_level(level: float, i: int) -> void:
	_music_level[i] = level
	_music[i].volume_db = MUSIC_DB + _duck_db + linear_to_db(maxf(level, SILENT_LINEAR))


func _set_duck(db: float) -> void:
	_duck_db = db
	for i: int in _music.size():
		_set_music_level(_music_level[i], i)


func _stop_quiet_music() -> void:
	for i: int in _music.size():
		if _music_level[i] <= 0.001:
			_music[i].stop()


func _fade_ambient(on: bool) -> void:
	if _ambient == null:
		return
	var stream: AudioStreamWAV = _cache.get(_ambient_sound()) if on else null
	if on and stream == null:
		return
	if _ambient_fade != null:
		_ambient_fade.kill()
	_ambient_fade = create_tween()
	if on:
		if not _ambient.playing:
			_start_ambient_stream(stream)
		elif _ambient.stream != stream:
			# Another place's bed is playing: dip it out, swap, and fade the new one in.
			_ambient_fade.tween_property(_ambient, "volume_db", linear_to_db(SILENT_LINEAR), 0.5)
			_ambient_fade.tween_callback(_start_ambient_stream.bind(stream))
		_ambient_fade.tween_property(_ambient, "volume_db", _ambient_db(), 1.5)
	else:
		_ambient_fade.tween_property(_ambient, "volume_db", linear_to_db(SILENT_LINEAR), 0.6)
		_ambient_fade.tween_callback(_ambient.stop)


func _start_ambient_stream(stream: AudioStreamWAV) -> void:
	_ambient.stream = stream
	_ambient.volume_db = linear_to_db(SILENT_LINEAR)
	_ambient.play()


## The loop name of the current place's ambience.
func _ambient_sound() -> String:
	return str(PLACE_AMBIENT.get(ambient_place, PLACE_AMBIENT["office"])[0])


## The level of the current place's ambience (the office one is AMBIENT_DB).
func _ambient_db() -> float:
	return float(PLACE_AMBIENT.get(ambient_place, PLACE_AMBIENT["office"])[1])


static func _pcm16(data: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i: int in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	return bytes


static func _wav(bytes: PackedByteArray, rate: int, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = bytes.size() >> 1
	return w
