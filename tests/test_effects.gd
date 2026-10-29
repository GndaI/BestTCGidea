extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		push_error(title)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.auto_pass = false
	scene.ai_enabled = false
	scene.begin_game()
	var c := TCGCards.by_id("healer")
	scene.battle.players[0].units = [{"card": c, "hp": 4, "mana": 3, "bonus": 0, "alive": true, "shield": 0, "chain_used": false, "turn_used": false}]
	scene.battle.phase = "action"
	scene.render()
	await process_frame
	var view: TCGCardView = scene.unit_views["0:0"]
	view.mouse_entered.emit()
	check(scene.hover_spell != null, "field hover includes spell panel")
	var spell_text := ""
	for label in scene.hover_spell.find_children("*", "Label", true, false): spell_text += label.text
	check("생명력을 3" in spell_text or "생명력 3" in spell_text, "healer spell text shown")
	scene.hide_card_preview()
	scene.battle.apply_effect({"target": [0, 0], "effect": "damage", "amount": 2, "title": "test"})
	scene.battle.apply_effect({"target": [0, 0], "effect": "heal3", "amount": 0, "title": "test"})
	check(scene.battle.visual_events.size() == 2, "both damage and healing recorded")
	check(scene.battle.visual_events[0].amount == 2 and scene.battle.visual_events[1].amount == 3, "actual amounts recorded")
	scene.render()
	await create_timer(0.2).timeout
	check(scene.playing_effects and view.health == 2, "damage snapshot plays before healing")
	check(scene.effect_blocker.visible and scene.ai_timer.is_stopped() and scene.auto_timer.is_stopped(), "input and automatic turns paused during effects")
	await capture("damage-preview")
	await create_timer(0.9).timeout
	check(scene.playing_effects and view.health == 5, "healing follows damage")
	await capture("heal-preview")
	await create_timer(0.9).timeout
	check(not scene.playing_effects and not scene.effect_blocker.visible, "input resumes after sequence")
	var refreshed: TCGCardView = scene.unit_views["0:0"]
	scene.show_card_preview(refreshed)
	await capture("field-spell-preview")
	scene.hide_card_preview()
	scene.battle.players[0].units[0].shield = 4
	scene.battle.apply_effect({"target": [0, 0], "effect": "damage", "amount": 1, "title": "test"})
	check(scene.battle.visual_events[0].amount == 0, "blocked damage displayed as zero")
	scene.battle.visual_events.clear()
	scene.battle.apply_effect({"target": [0, 0], "effect": "heal3", "amount": 0, "title": "test"})
	check(scene.battle.visual_events[0].amount == 0, "full health does not show fake healing")
	scene.battle.visual_events.clear()
	scene.battle.apply_effect({"target": [0, 0], "effect": "damage", "amount": 9, "title": "test"})
	scene.render()
	await create_timer(1.0).timeout
	check(not scene.playing_effects and not scene.battle.players[0].units[0].alive, "lethal effect finishes and unit becomes face down")
	scene.queue_free()
	await process_frame
	print("EFFECTS/HOVER FAILURES: ", failures)
	quit(1 if failures else 0)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + filename + ".png")
