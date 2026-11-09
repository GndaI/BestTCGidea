extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		push_error(title)

func run() -> void:
	var scene = load("res://src/scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.effects_enabled = false
	scene.open_deck_menu()
	await process_frame
	var library_screen: Node = scene.root.find_child("DeckLibraryScreen", true, false)
	var library_slot: Node = scene.root.find_child("DeckLibrarySlot0", true, false)
	scene.saved_decks = [{"name": "부분 갱신 덱", "cards": scene._default_deck()}]
	scene.render()
	await process_frame
	check(scene.root.find_child("DeckLibraryScreen", true, false) == library_screen, "deck library screen instance is reused")
	check(scene.root.find_child("DeckLibrarySlot0", true, false) == library_slot, "deck library slot frame is reused")
	var slot_labels: Array[Node] = scene.root.find_child("DeckLibrarySlot0", true, false).find_children("*", "Label", true, false)
	check(not slot_labels.is_empty() and "부분 갱신 덱" in slot_labels[0].text, "deck library slot text refreshes in place")

	scene.open_deck_editor(0)
	await process_frame
	var editor_screen: Node = scene.root.find_child("DeckEditorScreen", true, false)
	var editor_slot: Node = scene.root.find_child("EditorTier1Slot0", true, false)
	scene.saved_decks[0].cards[0].clear()
	scene.render()
	await process_frame
	check(scene.root.find_child("DeckEditorScreen", true, false) == editor_screen, "deck editor screen instance is reused")
	check(scene.root.find_child("EditorTier1Slot0", true, false) == editor_slot, "deck editor slot frame is reused")
	check(editor_slot.find_children("*", "TCGCardView", true, false).is_empty(), "only the changed deck slot content is replaced")

	scene.ai_enabled = false
	scene.decks = [scene._default_deck(), scene._default_deck()]
	scene.begin_game()
	await process_frame
	await process_frame
	var battle_screen: Node = scene.root.find_child("BattleScreen", true, false)
	var battle_host: Node = scene.root.find_child("BattleRefreshHost", true, false)
	var field_before: Control = scene.root.find_child("FieldPanel0", true, false)
	var field_y_before := field_before.global_position.y
	scene.render()
	await process_frame
	check(scene.root.find_child("BattleScreen", true, false) == battle_screen, "battle screen instance is reused")
	check(scene.root.find_child("BattleRefreshHost", true, false) == battle_host, "battle outer refresh host is reused")
	scene.battle.phase = "reaction"
	scene.render()
	await process_frame
	var reaction_hint: Label = scene.root.find_child("BattleReactionHint", true, false)
	var field_after: Control = scene.root.find_child("FieldPanel0", true, false)
	check(is_instance_valid(reaction_hint) and reaction_hint.visible, "reaction guidance appears as an overlay")
	check(reaction_hint.get_parent() != battle_host, "reaction guidance stays outside the battle layout flow")
	check(absf(field_after.global_position.y - field_y_before) <= 1.0, "reaction guidance does not push the field")

	print("PARTIAL REFRESH CHECKS: 11 | FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
