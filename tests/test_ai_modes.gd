extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures := 0
	var checks := 0
	var scene = load("res://scenes/main.tscn").instantiate()
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
	scene.choose_saved_deck(0)
	checks += 1
	if scene.draft_player != 1 or not scene.start_screen or scene.decks[0] != p1_deck:
		failures += 1
		push_error("FAIL: choosing P1 deck must advance to P2 deck selection")
	scene.choose_saved_deck(1)
	checks += 1
	if scene.drafting or scene.ai_enabled or scene.decks[1] != p2_deck:
		failures += 1
		push_error("FAIL: choosing P2 deck must start a local battle with both selected decks")

	scene.ai_timer.stop()
	scene.auto_timer.stop()
	scene.queue_free()
	await process_frame
	print("AI/LOCAL MODE CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
