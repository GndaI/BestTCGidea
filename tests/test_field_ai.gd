extends SceneTree

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

func living_count(b: TCGBattle, owner: int) -> int:
	return b.players[owner].units.filter(func(unit): return unit.alive).size()

func play_match(deck: Array, agents: Array, seed_value: int) -> Dictionary:
	var b := TCGBattle.new()
	b.start([deck.duplicate(true), deck.duplicate(true)])
	b.rng.seed = seed_value
	if agents[0] is TCGRandomAI: agents[0].rng.seed = seed_value * 2 + 11
	if agents[1] is TCGRandomAI: agents[1].rng.seed = seed_value * 2 + 12
	var steps := 0
	while b.phase != "over" and steps < MATCH_LIMIT:
		var owner: int = b.priority
		if not agents[owner].step(b, owner): break
		b.visual_events.clear()
		steps += 1
	return {
		"battle": b,
		"winner": b.winner,
		"turns": b.turn_index + 1,
		"steps": steps,
		"complete": b.phase == "over",
		"living": [living_count(b, 0), living_count(b, 1)],
	}

func run() -> void:
	var field_wins := 0
	var field_wins_as_p1 := 0
	var field_wins_as_p2 := 0
	var random_wins := 0
	var incomplete := 0
	var total_turns := 0
	var versus_games := 24
	for game in range(versus_games):
		var field_side := game % 2
		var agents: Array = [TCGRandomAI.new(), TCGRandomAI.new()]
		agents[field_side] = TCGFieldAI.new()
		var result := play_match(test_deck(1000 + game / 2), agents, 5000 + game / 2)
		if not result.complete:
			incomplete += 1
		elif result.winner == field_side:
			field_wins += 1
			if field_side == 0: field_wins_as_p1 += 1
			else: field_wins_as_p2 += 1
		else:
			random_wins += 1
		total_turns += result.turns
	print("FIELD_VS_RANDOM games=%d field_wins=%d (p1=%d,p2=%d) random_wins=%d incomplete=%d avg_turns=%.2f" % [versus_games, field_wins, field_wins_as_p1, field_wins_as_p2, random_wins, incomplete, float(total_turns) / versus_games])

	var p1_wins := 0
	var p2_wins := 0
	var self_incomplete := 0
	var self_turns := 0
	var min_turns := 999999
	var max_turns := 0
	var sample: Dictionary = {}
	var self_games := 20
	for game in range(self_games):
		var result := play_match(test_deck(2000 + game), [TCGFieldAI.new(), TCGFieldAI.new()], 7000 + game)
		if not result.complete:
			self_incomplete += 1
		elif result.winner == 0:
			p1_wins += 1
		else:
			p2_wins += 1
		self_turns += result.turns
		min_turns = mini(min_turns, result.turns)
		max_turns = maxi(max_turns, result.turns)
		if sample.is_empty() and result.complete:
			sample = result
			sample.deck = test_deck(2000 + game)
	print("FIELD_SELF_PLAY games=%d p1_wins=%d p2_wins=%d incomplete=%d avg_turns=%.2f min_turns=%d max_turns=%d" % [self_games, p1_wins, p2_wins, self_incomplete, float(self_turns) / self_games, min_turns, max_turns])
	if not sample.is_empty():
		var b: TCGBattle = sample.battle
		print("SAMPLE_RESULT winner=P%d turns=%d steps=%d living=%s" % [sample.winner + 1, sample.turns, sample.steps, str(sample.living)])
		print("SAMPLE_DECK %s" % str(sample.deck))
		print("SAMPLE_HISTORY_BEGIN")
		for line in b.history:
			if line.begins_with("──") or "출현" in line or "선언:" in line or "재기불능" in line or "승리!" in line:
				print(line)
		print("SAMPLE_HISTORY_END")
	quit(0 if incomplete == 0 and self_incomplete == 0 else 1)
