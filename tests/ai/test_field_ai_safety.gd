extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + title)

func fixture() -> TCGBattle:
	var deck := [
		["vanilla_ice", "potato"], ["student", "tank"],
		["archer", "vanilla_latte"], ["mage", "bean"],
		["vanilla_flower", "mana_dragon"], ["dragon", "phoenix"],
	]
	var battle := TCGBattle.new()
	battle.start([deck, deck])
	for player in battle.players:
		player.units.clear()
		player.hand.clear()
		player.revealed = 6
	battle.phase = "action"
	battle.active = 0
	battle.priority = 0
	battle.stack.clear()
	return battle

func add_unit(battle: TCGBattle, owner: int, id: String, hp: int = -1, mana: int = 0) -> Dictionary:
	var unit := battle.make_unit(id)
	if hp >= 0: unit.hp = hp
	unit.mana = mana
	battle.players[owner].units.append(unit)
	return unit

func run() -> void:
	var battle := fixture()
	add_unit(battle, 0, "archer", -1, 2)
	var wounded_ally := add_unit(battle, 0, "vanilla_ice", 1)
	var enemy := add_unit(battle, 1, "vanilla_flower")
	var ai := TCGFieldAI.new()
	check(ai.step(battle, 0), "field AI takes a legal action with a damage ability")
	check(not battle.stack.is_empty(), "field AI queues its chosen damage action")
	check(battle.stack.back().target_uid == enemy.uid, "damage ability targets the enemy instead of a wounded ally")
	check(battle.stack.back().target_uid != wounded_ally.uid, "field AI never scores an allied kill as removal")

	battle = fixture()
	add_unit(battle, 0, "healer", -1, 1)
	var own_wounded := add_unit(battle, 0, "vanilla_ice", 2)
	var enemy_wounded := add_unit(battle, 1, "vanilla_flower", 2)
	ai = TCGFieldAI.new()
	check(ai.step(battle, 0), "field AI takes a legal action with a healing ability")
	check(not battle.stack.is_empty() and battle.stack.back().target_uid == own_wounded.uid, "healing ability targets an ally")
	check(battle.stack.back().target_uid != enemy_wounded.uid, "field AI does not support an enemy")

	print("FIELD AI SAFETY CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
