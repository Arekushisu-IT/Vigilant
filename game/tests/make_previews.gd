extends SceneTree
## Saves each place (office, home, cafe) as a plain scene you can open in the Godot editor's 3D view:
##   res://tests/previews/office_preview.scn, home_preview.scn, cafe_preview.scn
## The game builds its places in code while it runs, so the real scenes look empty in the editor. This script
## builds each place the same way (LocationBuilder.create), lights it with one of its chapter moods, removes the
## game scripts (so nothing runs in the editor) and saves the result. Static preview only: nothing moves.
## Re-run after changing the art or the builders:
##   Godot --headless --path <game> --script res://tests/make_previews.gd
## (tests/ is excluded from the Windows export, so these files never ship.)

const OUT := "res://tests/previews/"
## The chapter whose lighting each preview uses (the first chapter at that place).
const MOOD_CHAPTER := {"office": 1, "home": 3, "cafe": 8}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var lb: Variant = load("res://scripts/world/location_builder.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := true
	for place: String in ["office", "home", "cafe"]:
		var b: Node3D = lb.create(place)
		root.add_child(b)
		for i in 5:
			await process_frame
		b.apply_chapter_mood(int(MOOD_CHAPTER[place]))
		for i in 5:
			await process_frame
		root.remove_child(b)
		_strip(b)
		_own(b, b)
		b.name = place.capitalize() + "Preview"
		var packed := PackedScene.new()
		var err := packed.pack(b)
		var path := OUT + place + "_preview.scn"
		if err == OK:
			err = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
		var count := b.find_children("*", "MeshInstance3D", true, false).size()
		print("%s: %s (%d meshes) -> %s" % [place, "OK" if err == OK else "ERROR %d" % err, count, path])
		ok = ok and err == OK
		b.free()
	print("PREVIEWS OK" if ok else "PREVIEWS FAILED")
	quit(0 if ok else 1)


## Removes every game script (builders, people, pantry, interactables) so the saved scene is pure geometry,
## lights and labels; also drops audio players and colliders, which the editor view does not need.
func _strip(n: Node) -> void:
	for c: Node in n.get_children():
		_strip(c)
	if n is AudioStreamPlayer3D or n is AudioStreamPlayer or n is CollisionObject3D:
		n.get_parent().remove_child(n)
		n.queue_free()
		return
	if n.get_script() != null:
		n.set_script(null)


## Makes every node part of the saved scene. Model instances (.glb) are made local, so the changes the builders
## made inside them (screens, mug colours, materials) are kept.
func _own(n: Node, owner_root: Node) -> void:
	for c: Node in n.get_children():
		c.scene_file_path = ""
		c.owner = owner_root
		_own(c, owner_root)
