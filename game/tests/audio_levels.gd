extends SceneTree
## Measures every synthesized sound: peak, loudness (RMS), pops at the end, and loop seams. Prints PROBLEM lines.
##   Godot --headless --path <game> --script res://tests/audio_levels.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var audio: Node = root.get_node("/root/Audio")
	var names: Array[String] = []
	names.append_array(audio.SFX_NAMES)
	names.append_array(audio.LOOP_NAMES)
	var problems := 0
	for n: String in names:
		var d: PackedFloat32Array = AudioSynth.render(n)
		var peak := 0.0
		var sum := 0.0
		var nan := false
		for v: float in d:
			if is_nan(v):
				nan = true
			peak = maxf(peak, absf(v))
			sum += v * v
		var rms := sqrt(sum / d.size())
		var looping: bool = audio.LOOPING.has(n)
		var jump := absf(d[0] - d[d.size() - 1])
		var notes := ""
		if nan:
			notes += " NaN"
		if peak >= 0.99:
			notes += " CLIP"
		if not looping and absf(d[d.size() - 1]) > 0.03:
			notes += " END_POP"
		if looping and jump > 0.08:
			notes += " SEAM"
		if notes != "":
			problems += 1
		print("%-17s peak %.2f  rms %.3f  end/seam %.3f%s" % [n, peak, rms, jump if looping else absf(d[d.size() - 1]), (" PROBLEM" + notes) if notes != "" else ""])
	print("levels done, problems: ", problems)
	quit(0)
