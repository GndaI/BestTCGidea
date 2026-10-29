extends SceneTree

var failed := 0
func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed += 1
		push_error(message)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(is_equal_approx(scene.auto_timer.wait_time, 1.0), "automatic empty action waits one second")
	scene.effects_enabled = false
	scene.ai_enabled = false
	scene.begin_game()
	check(scene.overlay_layer.visible, "deployment choices open as overlay")
	check(not scene.can_auto_pass(), "do not skip deployment")
	scene.battle.deploy(0)
	check(scene.can_auto_pass(), "zero mana and no spells allows auto end")
	var menu_key := InputEventKey.new()
	menu_key.keycode = KEY_ESCAPE
	menu_key.pressed = true
	scene._input(menu_key)
	check(scene.action_menu_open and scene.overlay_layer.visible, "escape opens action overlay")
	check(scene.action_button.visible and scene.action_button.text.begins_with("턴 종료"), "single turn-action button remains at the fixed lower-right position")
	check(scene.action_button.anchor_left == 1.0 and scene.action_button.anchor_top == 1.0, "turn-action button uses a stable bottom-right anchor")
	scene._input(menu_key)
	check(not scene.action_menu_open and not scene.overlay_layer.visible, "escape closes action overlay")
	scene.auto_step()
	check(scene.battle.ending and scene.battle.priority == 1, "auto requests end")
	scene.auto_step()
	check(scene.battle.phase == "deploy" and scene.battle.active == 1, "auto approves end")
	scene.battle.deploy(0)
	scene.battle.players[1].hand = [TCGCards.by_id("mage")]
	check(not scene.can_auto_pass(), "legal spell prevents auto pass")
	scene.battle.players[1].hand.clear()
	scene.battle.players[1].units[0].mana = 2
	check(not scene.can_auto_pass(), "legal attack prevents auto pass")
	scene.battle.attack(1, 0, [0, 0])
	check(scene.can_auto_pass(), "no response permits pass in chain")
	scene.auto_step()
	scene.auto_step()
	check(scene.battle.stack.is_empty(), "auto resolves chain with consecutive passes")
	scene.selection = {"mode": "target"}
	check(not scene.can_auto_pass(), "never interrupt target selection")
	scene.selection = {}
	scene.auto_pass = false
	check(not scene.can_auto_pass(), "toggle disables automatic behavior")
	scene.render()
	await process_frame
	var found := false
	for node in scene.find_children("*", "Control", true, false):
		if node is TCGCardView and not node.face_down:
			found = true
			node.mouse_entered.emit()
			check(is_instance_valid(scene.hover_card), "hover opens enlarged card")
			check(scene.hover_card.size.x > node.size.x, "preview is larger")
			check(scene.hover_card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "preview does not intercept input")
			check(scene.hover_card.production == node.production and scene.hover_card.health == node.health, "preview matches current stats")
			node.mouse_exited.emit()
			check(scene.hover_card == null, "hover exit removes preview")
			break
	check(found, "field contains card views")
	scene.queue_free()
	await process_frame
	print("CARD/AUTO FAILURES: ", failed)
	quit(1 if failed else 0)
