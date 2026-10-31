extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + title)

func decks() -> Array:
	var result := [[], []]
	for owner in range(2):
		for tier in range(1, 7):
			var pool := TCGCards.pool(tier)
			result[owner].append([pool[0].id, pool[1].id])
	return result

func fixture(ids0: Array, ids1: Array) -> TCGBattle:
	var battle := TCGBattle.new()
	battle.start(decks())
	battle.players[0].units.clear()
	battle.players[1].units.clear()
	for id in ids0: battle.players[0].units.append(battle.make_unit(id))
	for id in ids1: battle.players[1].units.append(battle.make_unit(id))
	battle.phase = "action"
	battle.active = 0
	battle.priority = 0
	return battle

func resolve(battle: TCGBattle) -> void:
	battle.pass_priority()
	battle.pass_priority()

func hit(battle: TCGBattle, target: Array, amount: int, source: Array = []) -> void:
	battle.apply_standard_effect({"owner":0,"title":"test","effect":"damage","amount":amount,"target":target,"source":source,"damage_kind":"ability"})

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var b := fixture(["healer"], ["vanilla_flower"])
	check(TCGCards.is_banned("gambler"), "gambler is temporarily banned")
	check(TCGCards.pool(6).all(func(card): return card.id != "gambler"), "banned gambler is absent from deck pools")
	check(TCGCards.by_id("mana_dragon").name == "나마나마나용", "mana dragon renamed")
	check(TCGCards.by_id("bean").name == "최강의 콩나무", "bean remains its own card")
	check(TCGCards.by_id("cloak").name == "보호의 망토", "cloak is a new separate card")
	b.get_unit([0,0]).mana = 2
	check(b.ability(0,0,[1,0],"",[],"grant_life2"), "healer grants life")
	resolve(b)
	check(b.get_unit([1,0]).hp == 20 and b.get_unit([1,0]).max_hp == 20, "grant raises current and maximum life")

	b = fixture(["phoenix"], ["tank"])
	b.get_unit([0,0]).mana = 3
	check(b.ability(0,0,[1,0],"",[],"steal_life2"), "phoenix steals life")
	resolve(b)
	check(b.get_unit([0,0]).hp == 7 and b.get_unit([0,0]).max_hp == 7, "steal grants phoenix current and maximum life")
	check(b.get_unit([1,0]).hp == 3 and b.get_unit([1,0]).max_hp == 3, "steal lowers target current and maximum life")

	b = fixture(["potato","healer"], ["tank"])
	b.get_unit([0,0]).mana = 9
	check(b.ability(0,0,[0,0],"",[],"double_production"), "potato doubles production")
	resolve(b)
	check(b.production(b.get_unit([0,0])) == 2, "potato production doubled")
	b.defeat([0,0])
	check(b.get_unit([0,1]).mana == 2, "potato death gives its production as mana")

	b = fixture(["viper"], ["tank","rock"])
	b.active = 1
	b.finish_turn()
	check(b.get_unit([0,0]).mana == 3, "viper gains mana at opponent turn end while full")
	b.phase = "action"; b.active = 0; b.priority = 0; b.get_unit([0,0]).mana = 7
	check(b.ability(0,0,[1,0],"",[],"execute_low_tier"), "viper declares execute")
	resolve(b)
	check(not b.get_unit([1,0]).alive, "viper executes tier three or lower")

	b = fixture(["tank","healer"], ["archer"])
	b.get_unit([0,0]).mana = 3
	check(b.ability(0,0,[],"",[],"guard_allies"), "tank guards other allies")
	resolve(b)
	b.get_unit([1,0]).mana = 5; b.active = 1; b.priority = 1
	check(b.attack(1,0,[0,1]), "guarded ally can be attacked")
	resolve(b)
	check(b.get_unit([0,1]).hp == 3, "guarded ally takes no basic attack damage")

	b = fixture(["archer"], ["tank","rock"])
	b.get_unit([0,0]).mana = 3
	check(b.ability(0,0,[[1,0],[1,1]],"",[],"hit2_two"), "archer chooses two targets")
	resolve(b)
	check(b.get_unit([1,0]).hp == 3 and b.get_unit([1,1]).hp == 2, "archer damages both targets with mitigation")

	b = fixture(["rock","thorn","golem"], ["archer"])
	b.get_unit([0,0]).hp = 1; b.get_unit([0,0]).mana = 2
	check(b.ability(0,0,[0,0],"",[],"heal1"), "rock heals itself")
	resolve(b)
	check(b.get_unit([0,0]).hp == 2, "rock restored one life")
	b.priority = 0; b.get_unit([0,1]).mana = 3
	check(b.ability(0,1,[0,1],"",[],"increase_reflect"), "thorn increases reflection")
	resolve(b)
	hit(b,[0,1],2,[1,0])
	check(b.get_unit([1,0]).hp == 6, "thorn reflects increased amount")
	b.priority = 0; b.get_unit([0,2]).mana = 5
	check(b.ability(0,2,[0,2],"",[],"increase_armor"), "golem increases armor")
	resolve(b)
	hit(b,[0,2],5)
	check(b.get_unit([0,2]).hp == 13, "golem reduces damage by two")

	b = fixture(["cloak"], ["tank"])
	hit(b,[1,0],3)
	check(b.get_unit([1,0]).hp == 3, "cloak reduces damage to every unit")
	b.get_unit([0,0]).mana = 3
	check(b.ability(0,0,[],"",[],"cloak_to_hand"), "cloak returns as spell")
	resolve(b)
	check(b.players[0].hand.size() == 1 and b.get_unit([0,0]).withdrawn, "cloak leaves field and enters hand")
	b.phase = "action"; b.priority = 0
	check(b.cast_spell(0,0,[]), "cloak spell can be cast")
	resolve(b)
	check(b.players[0].units.any(func(unit): return unit.alive and unit.card.id == "cloak"), "cloak spell redeploys cloak")

	b = fixture(["mana_dragon","healer"], ["tank"])
	check(b.production(b.get_unit([0,0])) == 0 and b.production(b.get_unit([0,1])) == 3, "mana dragon buffs only other allies")
	b.defeat([0,0])
	check(b.get_unit([0,1]).mana == 2 and b.production(b.get_unit([0,1])) == 1, "mana dragon death gives mana and removes aura")

	b = fixture(["dragon"], ["healer","tank","rock"])
	for slot in range(3): b.get_unit([1,slot]).board_slot = slot
	b.defeat([1,1])
	check(b.get_unit([1,0]).hp == 2 and b.get_unit([1,2]).hp == 2, "dragon splashes both neighbours on enemy death")
	b.get_unit([0,0]).mana = 10; b.phase = "action"; b.priority = 0
	check(b.ability(0,0,[],"",[],"arm_apocalypse"), "dragon arms apocalypse")
	resolve(b)
	b.players[0].own_turn += 1
	b.resolve_apocalypse()
	check(b.get_unit([0,0]).alive and b.players[1].units.all(func(unit): return not unit.alive), "apocalypse leaves only its dragon")

	b = TCGBattle.new(); b.start(decks())
	b.players[0].revealed = 5; b.players[0].deck[5] = ["phoenix","dragon"]; b.phase = "deploy"; b.active = 0
	check(b.deploy(0), "phoenix deploys")
	var phoenix: Dictionary = b.players[0].units.filter(func(unit): return unit.card.id == "phoenix")[0]
	check(not phoenix.alive and phoenix.revive_at == b.players[0].own_turn + 1, "phoenix dies on arrival and schedules revival")

	print("CARD REWORK CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
