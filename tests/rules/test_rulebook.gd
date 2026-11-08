extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + title)

func decks() -> Array:
	var result: Array = [[], []]
	for owner in range(2):
		for tier in range(1, 7):
			var pool := TCGCards.pool(tier)
			result[owner].append([pool[0].id, pool[1].id])
	return result

func fixture(ids0: Array, ids1: Array) -> TCGBattle:
	var b := TCGBattle.new()
	b.start(decks())
	for id in ids0: b.players[0].units.append(b.make_unit(id))
	for id in ids1: b.players[1].units.append(b.make_unit(id))
	b.phase = "action"
	return b

func resolve(b: TCGBattle) -> void:
	b.pass_priority()
	b.pass_priority()

func hit(b: TCGBattle, target: Array, amount: int, source: Array = []) -> void:
	b.apply_standard_effect({"title": "test", "effect": "damage", "amount": amount, "target": target, "source": source, "owner": 0})

func run() -> void:
	print("RULEBOOK: start")
	check(TCGCards.all().size() == 22, "22 registered rulebook cards")
	for tier in range(1, 7):
		var expected_pool_size := 2 if tier == 6 else (4 if tier in [1, 3, 4, 5] else 3)
		check(TCGCards.pool(tier).size() == expected_pool_size, "pool tier %d" % tier)
	var b := TCGBattle.new()
	print("RULEBOOK: catalog loaded")
	b.start(decks())
	var order: Array = []
	for i in range(20):
		order.append(b.active)
		while b.phase == "growth": b.grow_potato(false)
		if b.phase == "deploy": b.deploy(0)
		check(b.request_end(), "turn end %d" % i)
		b.pass_priority()
	check(order == [0,1,1,0,0,1,1,0,0,1,1,0,1,0,1,0,1,0,1,0], "strict alternation after six")
	check(b.players[0].hand.size() == 2, "student sends tier-two spell to used")
	check(b.players[0].used.size() == 1, "used spell")
	b = TCGBattle.new()
	b.start(decks())
	b.visual_events.clear()
	b.presentation_enabled = true
	b.phase = "deploy"
	check(b.deploy(0), "normal unit deploys for presentation check")
	check(b.visual_events.any(func(event): return event.kind == "unit_arrival"), "every normal deployed unit queues the shared center arrival")
	check("사용된 주문 1개" in TCGGambleFX.RESULTS[3] and "미정" not in TCGGambleFX.RESULTS[3], "roulette result four has its confirmed spell-copy text")
	print("RULEBOOK: turn flow checked")
	b = fixture(["healer", "tank"], ["vanilla_flower"])
	b.players[0].units[0].mana = 5
	b.players[0].units[1].hp = 2
	check(b.ability(0, 0, [0, 1]), "healer ability")
	resolve(b)
	check(b.get_unit([0,1]).hp == 4, "heal two")
	check(not b.ability(0, 0, [0, 1]), "once per turn, even after chain")
	b.turn_index = 1
	b.begin_turn()
	b.phase = "action"
	b.priority = 0
	check(b.ability(0, 0, [0, 1]), "reset on each player's turn")
	check(not b.attack(0, 0, [1,0]), "non-active cannot attack")
	b = fixture(["archer"], ["tank"])
	b.get_unit([0,0]).mana = 6
	b.get_unit([1,0]).mana = 6
	check(b.attack(0,0,[1,0]), "attack")
	check(b.ability(1,0,[1,0]), "shield chain")
	check(not b.attack(0,0,[1,0]), "no chained basic attack")
	resolve(b)
	check(b.get_unit([1,0]).hp == 1, "shield reduces by two")
	b = fixture(["potato","bean"], ["vanilla_flower"])
	b.turn_index = 3
	b.begin_turn()
	check(b.income_choices.size() == 2, "potato and bean both have growth decisions")
	b.grow_potato(true)
	check(b.phase == "growth" and b.get_unit([0,0]).bonus == 1, "potato grows before bean choice")
	b.grow_potato(false)
	check(b.phase != "growth" and b.get_unit([0,1]).mana == 2 and b.get_unit([0,1]).bonus == 0, "bean can choose normal mana production")
	b.turn_index = 4
	b.begin_turn()
	b.grow_potato(false)
	b.grow_potato(true)
	check(b.get_unit([0,1]).mana == 2 and b.production(b.get_unit([0,1])) == 4, "bean can convert its production into equal growth")
	b = fixture(["viper","mana_dragon"], ["vanilla_flower"])
	check(b.production(b.get_unit([0,0])) == 3, "viper receives mana dragon aura")
	hit(b,[0,0],1)
	check(b.production(b.get_unit([0,0])) == 3, "viper loses full-health bonus")
	b.defeat([0,1])
	check(b.production(b.get_unit([0,0])) == 1, "aura removed when source dies")
	check(b.get_unit([0,0]).mana == 2, "mana dragon death grants mana")
	b.players[0].hand.append(TCGCards.by_id("viper"))
	check(b.cast_spell(0,0,[0,0]), "viper buff spell")
	resolve(b)
	b.get_unit([0,0]).hp = 5
	check(b.production(b.get_unit([0,0])) == 2, "viper spell grants conditional bonus")
	b = fixture(["rock","golem"], ["vanilla_flower"])
	hit(b,[0,0],20)
	check(b.get_unit([0,0]).hp == 2, "rock damage one")
	hit(b,[0,1],4)
	check(b.get_unit([0,1]).hp == 13, "iron damage minus one")
	b.get_unit([0,0]).shield = 3
	hit(b,[0,0],2)
	check(b.get_unit([0,0]).hp == 2 and b.get_unit([0,0]).shield == 2, "rock reduces damage first and spends one shield")
	b.apply_standard_effect({"owner":0,"title":"shield two","effect":"shield2","amount":0,"target":[0,1],"source":[]})
	b.apply_standard_effect({"owner":0,"title":"shield three","effect":"shield3","amount":0,"target":[0,1],"source":[]})
	check(b.get_unit([0,1]).shield == 5, "shields stack additively")
	b = fixture(["traveler"], ["vanilla_flower"])
	b.players[0].units.clear()
	b.players[0].units = [b.make_unit("healer"),b.make_unit("tank")]
	b.players[0].revealed = 2
	b.players[0].deck[2] = ["traveler","rock"]
	b.phase = "deploy"
	b.deploy(0)
	check(b.players[0].revealed == 4 and b.get_unit([0,3]).card.id == "skipped", "traveler skips fourth pair")
	check(b.get_unit([0,4]).is_empty(), "no immediate fifth unit")
	b.turn_index = 4
	b.begin_turn()
	b.deploy(0)
	check(b.get_unit([0,4]).card.tier == 5, "fifth unit next turn")
	b = fixture(["traitor"], ["mana_dragon"])
	b.get_unit([0,0]).mana = 8
	b.get_unit([1,0]).mana = 7
	check(b.ability(0,0,[1,0]), "swap declaration")
	resolve(b)
	check(b.get_unit([0,0]).card.id == "mana_dragon" and b.get_unit([0,0]).mana == 7, "other unit mana retained")
	check(b.get_unit([1,0]).card.id == "traitor" and b.get_unit([1,0]).mana == 3 and b.get_unit([1,0]).turn_used, "swap pays five and keeps once-per-turn flag")
	b.priority = 1
	b.get_unit([1,0]).mana = 10
	check(not b.ability(1,0,[0,0]), "cannot re-use after control exchange")
	b = fixture(["mana_dragon"], ["traitor"])
	b.get_unit([0,0]).mana = 4
	b.get_unit([1,0]).mana = 5
	var original_target: int = b.get_unit([1,0]).uid
	check(b.attack(0,0,[1,0]), "attack before swap")
	check(b.ability(1,0,[0,0]), "swap in response to attack")
	resolve(b)
	check(b.get_unit(b.locate(original_target)).hp == 11, "queued target follows unit across exchange")
	check(b.get_unit([1,0]).hp == 12, "new occupant not accidentally hit")
	b = fixture(["assassin","tank"], ["tank"])
	b.get_unit([0,0]).mana = 7
	b.get_unit([0,1]).shield = 3
	b.get_unit([1,0]).shield = 2
	b.finish_turn()
	check(b.get_unit([0,0]).mana == 0, "assassin loses mana at own turn end")
	check(b.get_unit([0,1]).shield == 0 and b.get_unit([1,0]).shield == 0, "both shields expire at turn end")
	b = fixture(["student","mage"], ["dragon"])
	b.players[0].used = [TCGCards.by_id("thorn"), TCGCards.by_id("phoenix"),TCGCards.by_id("mage")]
	b.get_unit([0,0]).mana = 8
	check(not b.ability(0,0,[1,0],"thorn"), "no conditional replay")
	check(b.ability(0,0,[1,0],"mage"), "normal replay")
	resolve(b)
	check(b.get_unit([1,0]).hp == 11, "copied damage")
	b.players[0].hand.append(TCGCards.by_id("student"))
	check(not b.cast_spell(0,0,[1,0],[1,0]), "copy only allied unit")
	check(b.cast_spell(0,0,[1,0],[0,1]), "copy allied mage")
	resolve(b)
	check(b.get_unit([1,0]).hp == 7, "copied ally spell")
	b = fixture(["thorn"], ["thorn"])
	b.apply_standard_effect({"owner":0,"title":"ability damage","effect":"damage","amount":1,"target":[1,0],"source":[0,0],"damage_kind":"ability"})
	check(b.get_unit([0,0]).hp == 10 and b.get_unit([1,0]).hp == 11, "reflection stops without infinite loop")
	b = fixture(["thorn"], ["thorn"])
	b.apply_standard_effect({"owner":0,"title":"spell damage","effect":"damage","amount":1,"target":[1,0],"source":[0,0],"damage_kind":"spell"})
	check(b.get_unit([0,0]).hp == 12 and b.get_unit([1,0]).hp == 11 and b.reactions.is_empty(), "spell damage does not trigger thorn")
	b = fixture(["vanilla_flower"], ["tank"])
	b.players[1].hand = [TCGCards.by_id("thorn")]
	check(not b.cast_spell(1,0,[0,0]), "reaction not playable early")
	b.get_unit([0,0]).mana = 2
	b.attack(0,0,[1,0])
	resolve(b)
	check(b.phase == "reaction" and b.priority == 1, "pause immediately after damage")
	check(b.cast_spell(1,0,[0,0]), "reaction spell")
	resolve(b)
	check(b.get_unit([0,0]).hp == 12 and b.phase == "action", "retaliation resolves and resumes")
	b = fixture(["phoenix","vanilla_flower"], ["dragon"])
	b.get_unit([0,0]).bonus = 5
	b.defeat([0,0])
	b.turn_index = 1
	b.begin_turn()
	check(not b.get_unit([0,0]).alive, "opponent turn not counted")
	b.turn_index = 3
	b.begin_turn()
	check(b.get_unit([0,0]).alive and b.get_unit([0,0]).mana == 0 and b.get_unit([0,0]).bonus == 0, "phoenix revives reset after own production")
	b = fixture(["healer","vanilla_flower"], ["dragon"])
	b.players[0].hand = [TCGCards.by_id("phoenix")]
	b.defeat([0,0])
	b.open_reactions()
	check(b.cast_spell(0,0,[0,0]), "revival spell on fresh death")
	resolve(b)
	b.turn_index = 3
	b.begin_turn()
	check(not b.get_unit([0,0]).alive, "not revived at first own turn")
	b.turn_index = 4
	b.begin_turn()
	check(b.get_unit([0,0]).alive and b.get_unit([0,0]).mana == 0, "revived at second own production end")
	b = fixture(["phoenix"], ["dragon"])
	b.players[0].revealed = 6
	b.players[1].revealed = 6
	b.defeat([0,0])
	b.check_victory()
	check(b.winner == 1, "pending resurrection does not prevent loss")
	b = fixture(["healer"], ["dragon"])
	b.players[0].revealed = 6
	b.players[1].revealed = 5
	b.defeat([0,0])
	b.check_victory()
	check(b.winner == -1, "wait until both reveal procedures finish")
	b.players[1].units = []
	for id in ["healer","tank","archer","mage","golem"]: b.players[1].units.append(b.make_unit(id))
	b.active = 1
	b.phase = "deploy"
	b.deploy(0)
	check(b.winner == 1, "victory checked immediately after final reveal")
	b = fixture(["gambler"], ["dragon"])
	b.finishing = true
	b.end_rolls = [{"uid":b.get_unit([0,0]).uid,"roll":1},{"uid":b.get_unit([0,0]).uid,"roll":2},{"uid":b.get_unit([0,0]).uid,"roll":6},{"uid":b.get_unit([0,0]).uid,"roll":5}]
	b.process_end_rolls()
	check(b.players[0].units.size() == 9 and b.get_unit([0,0]).dice == 2, "summons and next-turn extra die")
	hit(b,[0,0],99)
	check(b.get_unit([0,0]).hp == 16, "guard protects demon")
	check(b.phase == "choice" and b.choose_roll_target([1,0]), "die five selectable target")
	check(b.get_unit([0,0]).max_hp == 22 and b.get_unit([1,0]).hp == 9, "die five raises maximum and damages")
	b = fixture(["gambler", "token_guard"], ["dragon"])
	b.players[0].special = true
	b.get_unit([0,0]).board_slot = TCGBattle.BOARD_DOCK
	b.get_unit([0,1]).board_slot = 0
	b.defeat([0,1])
	check(b.get_unit([0,1]).board_slot == TCGBattle.BOARD_DOCK and b.board_card_count(0) == 0, "defeated units leave demon-board cells empty")
	check(not b.get_unit([0,1]).alive and b.get_unit([0,1]).card.id == "token_guard", "cleared demon-board corpses remain recorded for revival")
	b = fixture(["gambler"], ["dragon"])
	b.players[1].used = [TCGCards.by_id("mage")]
	b.finishing = true
	b.apply_roll({"uid":b.get_unit([0,0]).uid,"roll":4})
	check(b.phase == "choice" and b.roll_four_spell_choices() == [0], "die four lists applicable opponent used spell")
	check(b.choose_roll_spell(0) and b.choice_targets().has([1,0]), "die four proceeds to copied spell target")
	b.choose_roll_target([1,0])
	check(b.get_unit([1,0]).hp == 11, "die four applies selected opponent spell")
	b = fixture(["healer"], ["dragon"])
	b.players[0].hand = [TCGCards.by_id("gambler")]
	check(TCGCards.by_id("gambler").spell.is_empty() and TCGCards.by_id("gambler").spell_text == "주문 효과 없음.", "gambler currently has no spell effect")
	check(not b.cast_spell(0,0,[]) and b.players[0].hand.size() == 1, "effectless gambler spell cannot be cast")
	b = fixture(["gambler"], ["healer"])
	b.defeat([1,0])
	var duplicate_healer := b.make_unit("healer")
	duplicate_healer.alive = false
	duplicate_healer.hp = 0
	b.players[1].units.append(duplicate_healer)
	b.finishing = true
	b.end_rolls = [{"uid":b.get_unit([0,0]).uid,"roll":3}]
	b.process_end_rolls()
	check(b.choice_targets().size() == 1, "duplicate defeated unit types appear once")
	check(b.choose_roll_target([1,0]), "enemy resurrection selected")
	check(b.players[0].units.any(func(unit): return unit.alive and unit.card.id == "healer"), "enemy unit revives on gambler owner's field")
	check(not b.players[1].units.any(func(unit): return unit.alive and unit.card.id == "healer"), "enemy unit does not revive on original field")
	while b.board_card_count(0) < TCGBattle.BASE_BOARD_SLOTS:
		var token := b.make_unit("token_guard")
		token.board_slot = b.next_free_board_slot(0)
		b.players[0].units.append(token)
	b.phase = "choice"
	b.choice = {"uid":b.get_unit([0,0]).uid,"roll":3}
	check(b.choice_targets().is_empty(), "full nine-card board blocks external resurrection")
	var ai := TCGRandomAI.new()
	print("RULEBOOK: individual effects checked")
	ai.rng.seed = 42
	var seen := {}
	for game in range(12):
		print("RULEBOOK: AI game ", game)
		b = TCGBattle.new()
		var random_decks := [ai.random_deck(),ai.random_deck()]
		# The unlimited summoner can intentionally create non-terminating matches.
		# Its die outcomes are tested above; ordinary decks test match completion.
		for deck in random_decks: deck[5] = ["dragon", "phoenix"]
		b.start(random_decks)
		b.rng.seed = game + 1
		for step in range(1400):
			if b.phase == "over": break
			for action in TCGRandomAI.legal_actions(b,b.priority): seen[action.type] = true
			check(ai.step(b,b.priority), "AI advances game %d step %d" % [game,step])
			b.visual_events.clear()
			if failures > 10: break
		check(b.phase == "over", "random match terminates %d" % game)
	check(seen.has("spell") and seen.has("ability") and seen.has("attack"), "AI covers all actions")
	print("RULEBOOK CHECKS: %d | FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
