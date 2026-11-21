extends SceneTree
## Renders every synthesized sound and music loop to res://tests/audio_preview/<name>.wav so a human can listen.
##   Godot --headless --path <game> --script res://tests/render_audio_preview.gd
## The folder has a .gdignore, so Godot never imports the previews.

const OUT := "res://tests/audio_preview/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var audio: Node = root.get_node("/root/Audio")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var gdignore := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	if gdignore != null:
		gdignore.close()
	var names: Array[String] = []
	names.append_array(audio.SFX_NAMES)
	names.append_array(audio.LOOP_NAMES)
	var bad := 0
	for n: String in names:
		var t0 := Time.get_ticks_msec()
		var wav: AudioStreamWAV = audio.synth(n)
		var ms := Time.get_ticks_msec() - t0
		var err := wav.save_to_wav(ProjectSettings.globalize_path(OUT + n + ".wav"))
		var secs := wav.data.size() / 2.0 / wav.mix_rate
		print("%-17s %5.2f s  %5d ms  %s" % [n, secs, ms, "ok" if err == OK and secs > 0.0 else "ERR %d" % err])
		if err != OK or secs <= 0.0:
			bad += 1
	print("audio preview done, failures: ", bad)
	quit(1 if bad > 0 else 0)
