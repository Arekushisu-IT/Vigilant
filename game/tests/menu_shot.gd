extends SceneTree
## Saves screenshots of the main menu, Chapter Select (a locked card: Chapter 4 after Chapters 1-2; Chapter 5 at
## home and Chapter 8 at the cafe in Review mode) and the Fun Facts page to res://tests/shots/ (run without --headless).

func _initialize() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(2.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/main_menu.png")
	var game: Node = root.get_node("Game")
	game.completed[0] = true
	game.completed[1] = true
	current_scene._show_select()
	await create_timer(0.4).timeout
	current_scene.find_child("ChapterSelect", true, false).show_chapter(4)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/chapter_select_locked.png")
	root.get_node("Settings").set_review_mode(true)
	current_scene._show_select()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/chapter_select.png")
	current_scene.find_child("ChapterSelect", true, false).show_chapter(5)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/chapter_select_5.png")
	# Chapter 8 (The Easy Sideline): an off-the-clock card at the cafe.
	current_scene.find_child("ChapterSelect", true, false).show_chapter(8)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/chapter_select_8.png")
	# The Fun Facts page.
	current_scene._show_menu()
	current_scene._show_fun_facts()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/fun_facts.png")
	game.start_new_game()
	root.get_node("Settings").set_review_mode(false)
	current_scene._on_settings()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/shots/settings_review.png")
	print("MENU SHOT OK")
	quit(0)
