extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		push_error(title)

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.auto_pass = false
	scene.ai_enabled = false
	scene.effects_enabled = false
	scene.begin_game()
	scene.battle.deploy(1)
	scene.battle.request_end()
	scene.battle.pass_priority()
	scene.battle.deploy(1)
	scene.battle.active = 0
	scene.battle.priority = 0
	scene.battle.players[0].units[0].mana = 2
	scene.render()
	await process_frame
	await process_frame
	var attacker: TCGCardView = scene.unit_views["0:0"]
	scene.board_scroll.ensure_control_visible(attacker)
	await process_frame
	check(not scene.begin_drag([1, 0], Vector2.ZERO), "cannot drag opponent unit")
	check(scene.begin_drag([0, 0], Vector2.ZERO), "can start with live own unit and mana")
	scene.drag_moved = true
	scene.finish_drag(Vector2(5, 5))
	check(scene.battle.stack.is_empty() and scene.battle.players[0].units[0].mana == 2, "invalid drop cancels without spending")
	await process_frame
	attacker = scene.unit_views["0:0"]
	var target: TCGCardView = scene.unit_views["1:0"]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	attacker.gui_input.emit(press)
	check(scene.drag_source == [0, 0], "card mouse press initiates drag")
	var motion := InputEventMouseMotion.new()
	motion.position = target.get_global_rect().get_center()
	scene._input(motion)
	check(scene.drag_moved, "drag threshold detects movement")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	release.pressed = false
	scene._input(release)
	check(scene.battle.stack.size() == 1, "release on enemy declares attack")
	check(scene.battle.stack[0].source == [0, 0] and scene.battle.stack[0].target == [1, 0], "attack stores exact source and target")
	check(scene.battle.players[0].units[0].mana == 0 and scene.battle.players[1].units[0].hp == 3, "cost paid but damage waits for chain")
	check("패스 / 대응" in scene.action_button.text, "shared action button becomes a bright response prompt")
	await process_frame
	scene._process(0)
	check(scene.arrow_layer.arrows.size() == 1, "queued attack has arrow")
	check(scene.arrow_layer.arrows[0].title.contains("피해 2"), "attack arrow shows base-attack damage")
	check(scene.arrow_layer.arrows[0].impact_text == "-2", "chain target previews final health change")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/attack-arrow-preview.png")
	scene.battle.pass_priority()
	scene.battle.pass_priority()
	check(scene.battle.visual_events[0].source == [0, 0], "resolved damage retains source")
	scene.render()
	check(scene.action_button.text.begins_with("턴 종료"), "shared action button becomes turn end with empty chain")
	check(not scene.begin_drag([0, 0], Vector2.ZERO), "zero mana cannot drag attack")
	scene.battle.players[0].units[0].mana = 3
	check(scene.begin_drag([0, 0], Vector2.ZERO), "can prepare cancel test")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene._input(escape)
	check(scene.drag_source.is_empty() and scene.battle.players[0].units[0].mana == 3, "escape cancels for free")
	scene.battle.phase = "action"
	scene.battle.active = 0
	scene.battle.priority = 0
	scene.battle.stack.clear()
	scene.battle.players[0].units[0] = scene.battle.make_unit("tank")
	scene.battle.players[0].units[0].mana = 3
	check(scene.battle.ability(0, 0, [0, 0]), "ability can be prepared for metadata test")
	check(not scene.battle.stack.is_empty() and scene.battle.stack[0].source == [0, 0], "ability retains its source")
	scene.battle.pass_priority()
	scene.battle.pass_priority()
	check(scene.battle.visual_events[0].kind == "shield" and scene.battle.visual_events[0].source == [0, 0], "shield resolution has target arrow metadata")
	scene.battle.stack.clear()
	scene.battle.visual_events.clear()
	scene.battle.phase = "action"
	scene.battle.active = 1
	scene.battle.priority = 1
	scene.battle.players[1].units[0].mana = 2
	scene.render()
	await process_frame
	var opponent_center: Vector2 = scene.unit_views["1:0"].get_global_rect().get_center()
	check(scene.battle.attack(1, 0, [0, 0]), "opponent basic attack can be prepared for arrow test")
	scene.render()
	await process_frame
	scene._process(0)
	check(scene.arrow_layer.arrows.size() == 1, "opponent basic attack has a visible arrow")
	check(scene.arrow_layer.arrows[0].start.distance_to(opponent_center) < 2.0, "opponent basic-attack arrow begins at the attacking unit")
	check(scene.arrow_layer.z_index > scene.chain_layer.z_index and scene.arrow_layer.z_index > scene.effect_blocker.z_index, "attack arrows render above chain cards and combat effects")
	scene.battle.stack.clear()
	scene.battle.phase = "action"
	scene.battle.active = 0
	scene.battle.priority = 0
	scene.battle.players[0].units[0].mana = 2
	scene.online_mode = true
	scene.online_host = true
	scene.online_state = "playing"
	scene.local_player = 0
	scene.render()
	await process_frame
	var online_target: TCGCardView = scene.unit_views["1:0"]
	check(scene.begin_drag([0, 0], scene.unit_views["0:0"].get_global_rect().get_center()), "online host attack drag starts")
	scene.drag_moved = true
	scene.finish_drag(online_target.get_global_rect().get_center())
	check(scene.selection.is_empty(), "online drag attack leaves no partial target-selection state")
	check(scene.battle.stack.size() == 1 and scene.battle.stack[0].source == [0, 0], "online drag attack reaches the authoritative battle immediately")
	scene.queue_free()
	await process_frame
	print("DRAG/ARROW FAILURES: ", failures)
	quit(1 if failures else 0)
