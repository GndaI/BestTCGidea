extends SceneTree

var failures := 0
var checks := 0
var ai_spell_count := 0
var ai_ability_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + title)

func unit(id: String, mana: int = 0) -> Dictionary:
	var c := TCGCards.by_id(id)
	return {"card": c, "hp": c.health, "mana": mana, "bonus": 0, "alive": true, "shield": 0, "chain_used": false, "turn_used": false}

func fixture() -> TCGBattle:
	var b := TCGBattle.new()
	var ai := TCGRandomAI.new()
	b.start([ai.random_deck(), ai.random_deck()])
	b.players[0].units = [unit("phoenix", 8), unit("mage", 8)]
	b.players[1].units = [unit("phoenix", 8), unit("healer", 8)]
	b.players[0].units[0].hp = 5
	b.phase = "action"
	return b

func resolve(b: TCGBattle) -> void:
	b.pass_priority()
	b.pass_priority()

func run() -> void:
	# Every even-tier spell is actually cast, resolved and moved out of hand.
	for c in TCGCards.all():
		if c.spell == "": continue
		var b := fixture()
		b.players[0].hand = [c]
		var target := [0, 0]
		if TCGCards.spell_target(c.spell) == "enemy": target = [1, 0]
		var copy_source: Array = [1, 1] if c.spell == "copy" else []
		var before: Dictionary = b.get_unit(target).duplicate(true)
		check(b.cast_spell(0, 0, target, copy_source), c.name + " spell accepted")
		check(b.stack.size() == 1 and b.players[0].hand.is_empty(), c.name + " enters chain")
		resolve(b)
		var after := b.get_unit(target)
		match c.spell:
			"heal3", "copy": check(after.hp == before.hp + 3, c.name + " heals 3")
			"heal6": check(after.hp == before.hp + 6, c.name + " heals 6")
			"full_hit": check(after.hp == before.hp - 2, c.name + " hits 2")
			"hit4": check(after.hp == before.hp - 4, c.name + " hits 4")
			"hit6": check(after.hp == before.hp - 6, c.name + " hits 6")
			"shield4": check(after.shield == 4, c.name + " grants shield")
			"mana3": check(after.mana == before.mana + 3, c.name + " grants 3 mana")
			"mana5": check(after.mana == before.mana + 5, c.name + " grants 5 mana")
		check(b.players[0].used.size() == 1, c.name + " spent after resolving")
	var b := fixture()
	b.players[0].hand = [TCGCards.by_id("viper")]
	b.players[1].units[0].hp -= 1
	check(not b.cast_spell(0, 0, [1, 0]), "viper rejects injured target without consuming card")
	check(b.players[0].hand.size() == 1, "invalid spell retains card")
	b = fixture()
	b.players[0].hand = [TCGCards.by_id("mage")]
	b.players[1].hand = [TCGCards.by_id("guardian")]
	b.cast_spell(0, 0, [1, 0])
	b.cast_spell(1, 0, [1, 0])
	resolve(b)
	check(b.players[1].units[0].hp == 17, "counterspell shield resolves before damage")
	# Deterministic random matches exercise spells, abilities, responses and all phases.
	for seed_value in range(24):
		var agents := [TCGRandomAI.new(), TCGRandomAI.new()]
		agents[0].rng.seed = seed_value * 2 + 100
		agents[1].rng.seed = seed_value * 2 + 101
		b = TCGBattle.new()
		b.start([agents[0].random_deck(), agents[1].random_deck()])
		var progressed := true
		for step_index in range(12000):
			if b.phase == "over": break
			var owner := b.priority
			if not agents[owner].step(b, owner):
				progressed = false
				break
		check(progressed and b.phase == "over", "random match %d completes" % seed_value)
		for line in b.history:
			if "선언:" in line and "주문" in line: ai_spell_count += 1
			if "선언:" in line and "소모 효과" in line: ai_ability_count += 1
	check(ai_spell_count > 0, "AI actually casts spells")
	check(ai_ability_count > 0, "AI actually uses abilities")
	# UI input path: click the spell card, then choose a board target.
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.auto_pass = false
	scene.ai_enabled = false
	scene.drafting = false
	scene.battle = fixture()
	scene.battle.players[0].hand = [TCGCards.by_id("alchemist")]
	scene.render()
	await process_frame
	var spell_view: TCGCardView
	for node in scene.find_children("*", "Control", true, false):
		if node is TCGCardView and node.spell_face: spell_view = node
	check(spell_view != null, "spell card rendered")
	if spell_view != null:
		check(spell_view.get_global_rect().position.y < 600, "spell accessible above fields")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		spell_view.gui_input.emit(click)
		check(scene.selection.get("action", "") == "spell", "spell card starts selection")
		var cancel_click := InputEventMouseButton.new()
		cancel_click.button_index = MOUSE_BUTTON_RIGHT
		cancel_click.pressed = true
		scene._input(cancel_click)
		check(scene.selection.is_empty(), "right-click cancels spell targeting")
		scene.select_spell(0)
		scene.choose_target([0, 0])
		resolve(scene.battle)
		check(scene.battle.players[0].units[0].mana == 11, "UI spell changes mana")
	# Real timer integration: P2 deploys and requests end without human input.
	scene.ai_enabled = true
	scene.begin_game()
	scene.battle.deploy(0)
	scene.end_action()
	await create_timer(2.4).timeout
	check(scene.battle.players[1].revealed == 1, "timer automatically deploys P2")
	check(scene.battle.priority == 0, "AI hands priority back to human")
	check(scene.battle.ending, "AI automatically requests end with no legal actions")
	scene.ai_timer.stop()
	scene.queue_free()
	await process_frame
	print("SPELL/AI CHECKS: %d | FAILURES: %d | AI spells: %d | AI abilities: %d" % [checks, failures, ai_spell_count, ai_ability_count])
	quit(1 if failures else 0)
