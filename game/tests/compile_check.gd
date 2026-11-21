extends SceneTree
## Loads every script under res:// with the autoloads present, so compile errors show up.

func _initialize() -> void:
	var bad := 0
	for p: String in _scripts("res://"):
		var s := load(p) as GDScript
		if s == null or not s.can_instantiate():
			print("COMPILE FAIL ", p)
			bad += 1
	print("compile check done, failures: ", bad)
	quit(1 if bad > 0 else 0)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d: String in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		out.append_array(_scripts(dir.path_join(d)))
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
