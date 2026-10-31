extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.auto_pass = false
	scene.begin_game()
	for i in range(8):
		if scene.battle.phase == "growth": scene.battle.grow_potato(false)
		if scene.battle.phase == "deploy": scene.battle.deploy(0)
		scene.battle.request_end()
		scene.battle.pass_priority()
	if scene.battle.phase == "growth": scene.battle.grow_potato(false)
	if scene.battle.phase == "deploy": scene.battle.deploy(0)
	scene.render()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://tests/battle-preview.png")
	print("PREVIEW_SAVED: ", result)
	for view in scene.find_children("*", "Control", true, false):
		if view is TCGCardView and not view.face_down:
			scene.show_card_preview(view)
			break
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/card-hover-preview.png")
	quit(result)
