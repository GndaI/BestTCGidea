extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures := 0
	var checks := 0
	var scene = load("res://src/scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	scene.start_ai_draft()
	scene.begin_game()
	checks += 1
	if not scene.ai is TCGRandomAI:
		failures += 1
		push_error("FAIL: easy mode must keep the original random AI")

	scene.start_strong_ai_draft()
	scene.begin_game()
	checks += 1
	if not scene.ai is TCGFieldAI:
		failures += 1
		push_error("FAIL: hard mode must use the field-control AI")
	checks += 1
	if scene.ai_difficulty != "hard":
		failures += 1
		push_error("FAIL: hard difficulty selection must be retained")

	scene.current_game_mode = scene.GameModesScript.DEFAULT_ID
	scene.start_local_draft()
	checks += 1
	if not scene.start_screen or scene.deck_library_mode != "local" or scene.draft_player != 0:
		failures += 1
		push_error("FAIL: local mode must open the P1 saved-deck selection screen")
	var p1_deck: Array = scene.decks[0].duplicate(true)
	var p2_deck: Array = scene.decks[1].duplicate(true)
	p2_deck[0] = [p2_deck[0][1], p2_deck[0][0]]
	scene.saved_decks = [
		{"name": "P1 시험 덱", "cards": p1_deck},
		{"name": "P2 시험 덱", "cards": p2_deck},
	]
	scene.deck_library_mode = "online"
	scene.local_deck_submitted = false
	scene._use_chosen_deck(p1_deck)
	checks += 1
	if scene.deck_selection_stage != "cards" or not scene.local_deck_submitted:
		failures += 1
		push_error("FAIL: standard online mode must submit after the unit deck without opening fate selection")
	scene.start_local_draft()
	scene.choose_saved_deck(0)
	checks += 1
	if scene.draft_player != 1 or scene.deck_selection_stage != "cards" or not scene.start_screen or scene.decks[0] != p1_deck:
		failures += 1
		push_error("FAIL: standard mode must advance directly from P1 unit deck to P2 unit deck")
	scene.choose_saved_deck(1)
	checks += 1
	if scene.drafting or scene.decks[1] != p2_deck or not scene.fate_decks[0].is_empty() or not scene.fate_decks[1].is_empty() or scene.battle.game_mode != scene.GameModesScript.DEFAULT_ID:
		failures += 1
		push_error("FAIL: standard mode must start without fate decks")

	scene.current_game_mode = scene.GameModesScript.FATE_ID
	scene.start_local_draft()
	scene.choose_saved_deck(0)
	await create_timer(0.6).timeout
	checks += 1
	if scene.draft_player != 0 or scene.deck_selection_stage != "fate" or scene.deck_library_section != "fate" or not is_instance_valid(scene.root.find_child("BuiltinDefaultFateDeckSlot", true, false)) or not scene.start_screen or scene.decks[0] != p1_deck:
		failures += 1
		push_error("FAIL: fate mode must replace the unit deck page with P1 fate deck selection")
	scene.choose_default_fate_deck()
	await create_timer(0.6).timeout
	checks += 1
	if scene.draft_player != 1 or scene.deck_selection_stage != "cards" or scene.deck_library_section != "cards" or not is_instance_valid(scene.root.find_child("BuiltinDefaultDeckSlot", true, false)):
		failures += 1
		push_error("FAIL: completing P1 fate deck must replace the page with P2 unit deck selection")
	scene.choose_saved_deck(1)
	await create_timer(0.6).timeout
	checks += 1
	if scene.draft_player != 1 or scene.deck_selection_stage != "fate" or scene.decks[1] != p2_deck:
		failures += 1
		push_error("FAIL: fate mode must advance from P2 unit deck to P2 fate deck selection")
	scene.choose_default_fate_deck()
	checks += 1
	if scene.drafting or scene.ai_enabled or scene.decks[1] != p2_deck or scene.fate_decks[0].size() != 12 or scene.fate_decks[1].size() != 12 or scene.battle.game_mode != scene.GameModesScript.FATE_ID:
		failures += 1
		push_error("FAIL: choosing P2 fate deck must start a local battle with both deck pairs")

	var fate_battle: TCGBattle = scene.battle
	fate_battle.players[0].units.append(fate_battle.make_unit("healer"))
	fate_battle.players[0].fate_hand = ["recharge"]
	fate_battle.active = 0
	fate_battle.priority = 0
	fate_battle.phase = "action"
	fate_battle.turn_phase = TCGBattle.ACTION
	fate_battle.stack.clear()
	fate_battle.ending = false
	scene.select_fate(0)
	checks += 1
	if scene.selection.get("mode", "") != "payer":
		failures += 1
		push_error("FAIL: recharge must ask for the life that will recover its own mana")
	scene.choose_target([0, 0])
	checks += 1
	if not scene.selection.is_empty() or fate_battle.stack.size() != 1 or fate_battle.stack[0].get("source", []) != [0, 0] or fate_battle.stack[0].get("target", []) != [0, 0]:
		failures += 1
		push_error("FAIL: choosing recharge's payer must declare it immediately without a second target")

	scene.ai_timer.stop()
	scene.auto_timer.stop()
	scene.queue_free()
	await process_frame
	print("AI/LOCAL MODE CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
