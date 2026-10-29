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
		["vanilla_latte", "rock"], ["mage", "bean"],
		["vanilla_flower", "mana_dragon"], ["dragon", "phoenix"],
	]
	var b := TCGBattle.new()
	b.start([deck, deck])
	b.players[0].units.clear()
	b.players[1].units.clear()
	b.players[0].hand.clear()
	b.players[1].hand.clear()
	b.players[0].revealed = 6
	b.players[1].revealed = 6
	b.phase = "action"
	b.active = 0
	b.priority = 0
	b.stack.clear()
	return b

func add_unit(b: TCGBattle, owner: int, id: String, hp: int = -1, mana: int = 0) -> Dictionary:
	var unit := b.make_unit(id)
	if hp >= 0: unit.hp = hp
	unit.mana = mana
	b.players[owner].units.append(unit)
	return unit

func run() -> void:
	var b := fixture()
	add_unit(b, 0, "vanilla_flower", -1, 10)
	add_unit(b, 1, "vanilla_ice", 1)
	var strong := add_unit(b, 1, "mana_dragon", 10)
	var ai := TCGFieldAI.new()
	check(ai.step(b, 0), "AI acts when two removals are available")
	check(not b.stack.is_empty() and b.stack.back().target_uid == strong.uid, "high-threat removable unit is chosen over weak overkill")

	b = fixture()
	add_unit(b, 0, "vanilla_flower", -1, 4)
	add_unit(b, 1, "dragon", 15)
	ai = TCGFieldAI.new()
	check(ai.step(b, 0), "AI can finish a turn while banking mana")
	check(b.stack.is_empty() and b.ending, "nonlethal basic attack is held for a future removal")

	b = fixture()
	add_unit(b, 0, "vanilla_ice")
	add_unit(b, 1, "dragon", 15)
	b.players[0].hand = [TCGCards.by_id("dragon")]
	ai = TCGFieldAI.new()
	check(ai.step(b, 0), "AI evaluates a nonlethal damage spell")
	check(b.players[0].hand.size() == 1 and b.stack.is_empty() and b.ending, "nonlethal one-shot damage spell is preserved")

	b = fixture()
	add_unit(b, 0, "vanilla_ice")
	var kill_target := add_unit(b, 1, "mage", 6)
	b.players[0].hand = [TCGCards.by_id("dragon")]
	ai = TCGFieldAI.new()
	check(ai.step(b, 0), "AI uses a spell that secures a removal")
	check(b.players[0].hand.is_empty() and not b.stack.is_empty() and b.stack.back().target_uid == kill_target.uid, "lethal spell is spent on the removable threat")

	print("FIELD AI TACTIC CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
