extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + title)

func decks() -> Array:
	var result: Array = [[], []]
	for p in range(2):
		for tier in range(1, 7):
			var pool := TCGCards.pool(tier)
			result[p].append([pool[0].id, pool[1].id])
	return result

func unit(id: String, mana: int = 0) -> Dictionary:
	var c := TCGCards.by_id(id)
	return {"card": c, "hp": c.health, "mana": mana, "bonus": 0, "alive": true, "shield": 0, "chain_used": false, "turn_used": false}

func fixture() -> TCGBattle:
	var b := TCGBattle.new()
	b.start(decks())
	b.players[0].units = [unit("tank", 5), unit("healer", 5)]
	b.players[1].units = [unit("tank", 5), unit("healer", 5)]
	b.phase = "action"
	return b

func resolve(b: TCGBattle) -> void:
	b.pass_priority()
	b.pass_priority()

func run() -> void:
	var b := TCGBattle.new()
	b.start(decks())
	var order: Array = []
	for i in range(14):
		order.append(b.active)
		if b.phase == "growth": b.grow_potato(false)
		if b.phase == "deploy": b.deploy(0)
		check(b.request_end(), "end declaration %d" % i)
		b.pass_priority()
	check(order == [0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1], "snake turn order including after tier six")
	check(b.players[0].revealed == 6 and b.players[1].revealed == 6, "all units revealed")
	check(b.players[0].hand.size() == 3, "three even-tier spells")
	b = TCGBattle.new()
	b.start(decks())
	b.deploy(0)
	check(b.players[0].units[0].mana == 0, "new units do not immediately produce")
	b.defeat([0, 0])
	b.check_victory()
	check(b.winner == -1, "no early victory before six reveals")
	b = fixture()
	check(b.attack(0, 0, [1, 0]), "declare attack")
	check(b.players[0].units[0].mana == 0, "pay all mana immediately")
	check(not b.attack(1, 0, [0, 0]), "nonturn player cannot basic attack")
	check(b.ability(1, 0, [1, 0]), "defender chains shield")
	resolve(b)
	check(not b.players[1].units[0].alive, "lethal attack after shield")
	check(b.priority == b.active, "priority returns to turn player")
	b = fixture()
	b.players[0].units[0].mana = 2
	b.attack(0, 0, [1, 0])
	b.ability(1, 0, [1, 0])
	check(not b.can_ability(1, 0), "same unit cannot repeat in same chain")
	resolve(b)
	check(b.players[1].units[0].hp == 2, "shield resolves before attack")
	check(not b.players[1].units[0].chain_used, "chain restriction resets")
	b = fixture()
	b.request_end()
	check(b.ability(1, 0, [1, 0]), "respond to end declaration")
	check(not b.ending, "response cancels end")
	resolve(b)
	check(b.turn_index == 0, "cancelled end does not advance")
	b.request_end()
	b.pass_priority()
	check(b.players[1].units[0].shield == 0, "shields expire at turn end")
	b = fixture()
	b.players[0].units[0] = unit("archer", 2)
	b.players[0].units[0].hp = 1
	b.players[1].units[0] = unit("archer", 2)
	b.ability(0, 0, [1, 0])
	b.ability(1, 0, [0, 0])
	resolve(b)
	check(not b.players[0].units[0].alive and b.players[1].units[0].hp == 4, "queued effect survives defeated source")
	b = fixture()
	b.players[0].units[0] = unit("student", 8)
	b.players[0].used = [TCGCards.by_id("student"), TCGCards.by_id("mage")]
	check(not b.ability(0, 0, [1, 0], "student"), "student cannot replay itself")
	check(b.ability(0, 0, [1, 0], "mage"), "student replays spent spell")
	resolve(b)
	check(not b.can_ability(0, 0), "student once per turn")
	check(b.players[0].used.size() == 2, "copy does not consume spent card")
	b = fixture()
	b.players[0].hand = [TCGCards.by_id("student")]
	b.players[0].units[0] = unit("student", 0)
	check(not b.cast_spell(0, 0, [0, 1], [0, 0]), "student spell cannot copy student")
	b.players[0].units[1].hp = 1
	check(b.cast_spell(0, 0, [0, 1], [1, 1]), "copy opponent healer spell")
	check(b.players[0].used.is_empty(), "spell not spent until resolution")
	resolve(b)
	check(b.players[0].units[1].hp == 4 and b.players[0].used.size() == 1, "copied spell resolves and is spent")
	b = fixture()
	b.players[0].units[0] = unit("viper")
	check(b.production(b.players[0].units[0]) == 4, "viper full life bonus")
	b.players[0].units[0].hp -= 1
	check(b.production(b.players[0].units[0]) == 1, "viper bonus lost when damaged")
	b.players[0].units[1] = unit("berserker")
	b.defeat([0, 0])
	check(b.production(b.players[0].units[1]) == 2, "berserker gains base production only")
	b = fixture()
	b.players[0].units[0] = unit("potato", 2)
	b.begin_turn()
	b.grow_potato(true)
	check(b.players[0].units[0].mana == 2 and b.production(b.players[0].units[0]) == 2, "growth replaces income")
	b = fixture()
	b.players[0].units[0] = unit("assassin", 5)
	b.finish_turn()
	check(b.players[0].units[0].mana == 0, "assassin loses remaining mana")
	b = fixture()
	b.players[1].units = []
	for i in range(6): b.players[1].units.append(unit("tank"))
	b.players[1].revealed = 6
	for i in range(6): b.defeat([1, i])
	b.check_victory()
	check(b.winner == 0 and b.phase == "over", "six defeated units ends game")
	b = fixture()
	b.players[0].units = [unit("gardener", 4), unit("captain", 4)]
	check(not b.ability(0, 0, [0, 0]), "mana transfer cannot target itself")
	b.ability(0, 0, [0, 1])
	resolve(b)
	b.ability(0, 1, [0, 0])
	resolve(b)
	check(b.players[0].units[0].mana + b.players[0].units[1].mana == 8, "transfer cycle cannot create mana")
	# Deterministic full games exercise progression, legal targeting, mana and lethal state.
	for seed_value in range(18):
		play_match(seed_value)
	# Build all UI phases to catch runtime and signal construction errors.
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.begin_game()
	scene.battle.deploy(0)
	scene.render()
	scene.select_attack(0, 0)
	scene.selection = {}
	scene.battle = fixture()
	scene.battle.players[0].hand = [TCGCards.by_id("student")]
	scene.select_spell(0)
	scene.choose_target([1, 1])
	scene.render()
	scene.queue_free()
	await process_frame
	print("CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)

func play_match(seed_value: int) -> void:
	var b := TCGBattle.new()
	var match_decks := decks()
	for p in range(2):
		for t in range(6):
			var pool := TCGCards.pool(t + 1)
			var offset := (seed_value + p + t) % 3
			match_decks[p][t] = [pool[offset].id, pool[(offset + 1) % 3].id]
	b.start(match_decks)
	for step in range(800):
		if b.phase == "over": break
		if b.phase == "growth": b.grow_potato(false)
		if b.phase == "deploy": b.deploy(seed_value % 2)
		var owner := b.active
		for i in range(b.players[owner].units.size()):
			if b.phase == "over": break
			for j in range(b.players[1 - owner].units.size()):
				if b.attack(owner, i, [1 - owner, j]):
					resolve(b)
					break
		if b.phase != "over":
			b.request_end()
			b.pass_priority()
	check(b.phase == "over", "complete match %d reaches victory" % seed_value)
