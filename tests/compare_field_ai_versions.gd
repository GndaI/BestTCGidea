extends SceneTree

const LegacyFieldAI = preload("res://tests/legacy_field_ai.gd")
const MATCH_LIMIT := 16000

func _initialize() -> void:
	call_deferred("run")

func test_deck(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck: Array = []
	for tier in range(1, 7):
		var pool: Array = TCGCards.pool(tier).filter(func(card): return card.id != "gambler")
		var first := rng.randi_range(0, pool.size() - 1)
		var second := (first + rng.randi_range(1, pool.size() - 1)) % pool.size()
		deck.append([pool[first].id, pool[second].id])
	return deck

func play(deck_a: Array, deck_b: Array, agents: Array, seed_value: int) -> Dictionary:
	var b := TCGBattle.new()
	b.start([deck_a.duplicate(true), deck_b.duplicate(true)])
	b.rng.seed = seed_value
	var steps := 0
	while b.phase != "over" and steps < MATCH_LIMIT:
		var owner: int = b.priority
		if not agents[owner].step(b, owner): break
		b.visual_events.clear()
		steps += 1
	return {"winner": b.winner, "turns": b.turn_index + 1, "complete": b.phase == "over"}

func run() -> void:
	var current_wins := 0
	var legacy_wins := 0
	var current_as_p1 := 0
	var current_as_p2 := 0
	var incomplete := 0
	var total_turns := 0
	for pairing in range(10):
		var deck_a := test_deck(3100 + pairing * 2)
		var deck_b := test_deck(3101 + pairing * 2)
		var seed_value := 9100 + pairing
		var first := play(deck_a, deck_b, [TCGFieldAI.new(), LegacyFieldAI.new()], seed_value)
		var second := play(deck_a, deck_b, [LegacyFieldAI.new(), TCGFieldAI.new()], seed_value)
		var pair_current := 0
		var pair_legacy := 0
		for entry in [{"result": first, "current_side": 0}, {"result": second, "current_side": 1}]:
			var result: Dictionary = entry.result
			if not result.complete:
				incomplete += 1
			elif result.winner == entry.current_side:
				current_wins += 1
				pair_current += 1
				if entry.current_side == 0: current_as_p1 += 1
				else: current_as_p2 += 1
			else:
				legacy_wins += 1
				pair_legacy += 1
			total_turns += result.turns
		print("PAIR %02d current=%d legacy=%d turns=%d/%d" % [pairing + 1, pair_current, pair_legacy, first.turns, second.turns])
	print("AI_VERSION_MATCH games=20 current_wins=%d (p1=%d,p2=%d) legacy_wins=%d incomplete=%d avg_turns=%.2f" % [current_wins, current_as_p1, current_as_p2, legacy_wins, incomplete, float(total_turns) / 20.0])
	quit(1 if incomplete else 0)
