class_name TCGBattle
extends RefCounted

const BOARD_DOCK := 1000000
const BOARD_UNSET := 999999
const NORMAL_BOARD_SLOTS := 6
const BASE_BOARD_SLOTS := 9
const CENTER_BOARD_ORDER := [0, 1, 2, 3, 4, 5, 6, 7, 8]

var players: Array = []
var active := 0
var priority := 0
var turn_index := 0
var phase := "deploy"
var stack: Array = []
var passes := 0
var ending := false
var winner := -1
var history: Array[String] = []
var visual_events: Array = []
var next_uid := 1
var income_choices: Array = []
var reactions: Array = []
var reaction_window: Array = []
var end_rolls: Array = []
var choice: Dictionary = {}
var finishing := false
var rng := RandomNumberGenerator.new()
var presentation_enabled := false
var pending_roll: Dictionary = {}

func start(decks: Array) -> void:
	next_uid = 1
	income_choices.clear()
	reactions.clear()
	reaction_window.clear()
	end_rolls.clear()
	choice.clear()
	pending_roll.clear()
	finishing = false
	rng.randomize()
	players.clear()
	for p in range(2):
		players.append({"deck": decks[p].duplicate(true), "units": [], "hand": [], "used": [], "revealed": 0, "own_turn": 0, "special": false})
	active = 0
	priority = 0
	turn_index = 0
	stack.clear()
	history.clear()
	visual_events.clear()
	winner = -1
	begin_turn()

func note(message: String) -> void:
	history.append(message)

func production(unit: Dictionary) -> int:
	var result: int = unit.card.power + unit.bonus + unit.card.effect_handler.production_bonus(unit)
	if unit.hp == unit.get("max_hp", unit.card.health):
		result += unit.get("full_bonus", 0)
	var pos := locate(unit.get("uid", -1))
	if not pos.is_empty():
		for ally in players[pos[0]].units:
			if ally.alive and ally.uid != unit.uid and ally.card.id == "mana_dragon": result += 2
	return result

func make_unit(id: String) -> Dictionary:
	var c := TCGCards.by_id(id)
	var u := {"uid": next_uid, "card": c, "hp": c.health, "max_hp": c.health, "mana": 0, "bonus": 0, "full_bonus": 0, "alive": id != "skipped", "withdrawn": false, "shield": 0, "chain_used": false, "turn_used": false, "revive_at": -1, "dice": 1, "reflect_bonus": 0, "armor_bonus": 0, "doom_at": -1, "attack_immune_turn": -1, "board_slot": BOARD_UNSET, "home_slot": BOARD_UNSET}
	next_uid += 1
	return u

func normalize_board_slots(owner: int) -> void:
	var occupied := {}
	for unit in players[owner].units:
		if not unit.has("board_slot"): unit.board_slot = BOARD_UNSET
		if not unit.has("home_slot"): unit.home_slot = BOARD_UNSET
		if unit.card.id == "gambler":
			unit.board_slot = BOARD_DOCK
		elif int(unit.board_slot) != BOARD_UNSET and int(unit.board_slot) != BOARD_DOCK:
			occupied[int(unit.board_slot)] = true
	for index in range(players[owner].units.size()):
		var unit: Dictionary = players[owner].units[index]
		if unit.card.id in ["gambler", "skipped"] or int(unit.board_slot) != BOARD_UNSET: continue
		var preferred := index if index < BASE_BOARD_SLOTS else BOARD_UNSET
		if preferred != BOARD_UNSET and not occupied.has(preferred):
			unit.board_slot = preferred
			unit.home_slot = preferred
			occupied[preferred] = true
		else:
			unit.board_slot = _next_free_board_slot_from(occupied)
			occupied[int(unit.board_slot)] = true

func next_free_board_slot(owner: int) -> int:
	normalize_board_slots(owner)
	var occupied := {}
	for unit in players[owner].units:
		if unit.card.id not in ["gambler", "skipped"] and int(unit.get("board_slot", BOARD_UNSET)) not in [BOARD_UNSET, BOARD_DOCK]:
			occupied[int(unit.board_slot)] = true
	return _next_free_board_slot_from(occupied)

func board_card_count(owner: int) -> int:
	normalize_board_slots(owner)
	var count := 0
	for unit in players[owner].units:
		if unit.card.id in ["gambler", "skipped"]: continue
		if int(unit.get("board_slot", BOARD_UNSET)) in [BOARD_UNSET, BOARD_DOCK]: continue
		count += 1
	return count

func _next_free_board_slot_from(occupied: Dictionary) -> int:
	for slot in CENTER_BOARD_ORDER:
		if not occupied.has(slot): return slot
	var overflow := BASE_BOARD_SLOTS
	while occupied.has(overflow):
		overflow += 1
	return overflow

func locate(uid: int) -> Array:
	if uid < 0: return []
	for owner in range(players.size()):
		for slot in range(players[owner].units.size()):
			if players[owner].units[slot].get("uid", -2) == uid: return [owner, slot]
	return []

func begin_turn() -> void:
	active = [0, 1, 1, 0][turn_index % 4] if turn_index < 12 else (1 if turn_index % 2 == 0 else 0)
	players[active].own_turn += 1
	priority = active
	passes = 0
	ending = false
	phase = "deploy"
	income_choices.clear()
	note("── 행동 턴 %d / P%d ──" % [turn_index + 1, active + 1])
	if presentation_enabled and turn_index > 0:
		visual_events.append({"kind": "turn_start", "target": [], "uid": -1, "amount": turn_index + 1, "hp": players[active].own_turn, "source": [], "owner": active, "title": "P%d의 차례" % [active + 1]})
	# Once-per-turn effects reset on every player's turn.
	for p in players:
		for u in p.units:
			u.turn_used = false
			u.chain_used = false
	resolve_apocalypse()
	if phase == "over": return
	for u in players[active].units:
		if not u.alive:
			continue
		if u.card.effect_handler.has_income_choice():
			phase = "growth"
			income_choices.append(u.uid)
		else:
			u.mana += production(u)
	if phase != "growth":
		after_income()

func resolve_apocalypse() -> void:
	var sources: Array = []
	for slot in range(players[active].units.size()):
		var unit: Dictionary = players[active].units[slot]
		if unit.alive and unit.card.id == "dragon" and int(unit.get("doom_at", -1)) >= 0 and int(unit.doom_at) <= players[active].own_turn:
			sources.append([active, slot])
	for source in sources:
		var dragon := get_unit(source)
		if dragon.is_empty() or not dragon.alive: continue
		dragon.doom_at = -1
		note("종말의 용: 종말이 발동합니다.")
		for owner in range(players.size()):
			for slot in range(players[owner].units.size()):
				if [owner, slot] != source and players[owner].units[slot].alive:
					defeat([owner, slot])
	check_victory()

func grow_potato(grow: bool) -> void:
	if phase != "growth":
		return
	var u := get_unit(locate(income_choices.pop_front()))
	if not u.is_empty() and u.alive:
		u.card.effect_handler.resolve_income_choice(self, u, grow)
	if income_choices.is_empty(): after_income()

func after_income() -> void:
	for slot in range(players[active].units.size()):
		var u: Dictionary = players[active].units[slot]
		if not u.alive and u.get("revive_at", -1) >= 0 and u.revive_at <= players[active].own_turn:
			revive([active, slot])
	phase = "deploy" if players[active].revealed < 6 else "action"

func deploy(choice: int) -> bool:
	if phase != "deploy" or choice not in [0, 1]:
		return false
	var p: Dictionary = players[active]
	var tier: int = p.revealed + 1
	var pair: Array = p.deck[tier - 1]
	var c: Dictionary = TCGCards.by_id(pair[choice])
	var deployed := make_unit(c.id)
	deployed.board_slot = tier - 1
	deployed.home_slot = tier - 1
	p.units.append(deployed)
	var deployed_index: int = p.units.size() - 1
	p.revealed += 1
	if tier % 2 == 0:
		var spell := TCGCards.by_id(pair[1 - choice])
		if not c.effect_handler.on_deploy(self, active, spell):
			p.hand.append(spell)
	note("P%d: %s 출현 (마나 0)." % [active + 1, c.name])
	phase = "action"
	if c.id == "traveler":
		var skipped := make_unit("skipped")
		skipped.board_slot = 3
		skipped.home_slot = 3
		p.units.append(skipped)
		p.revealed = 4
		note("시간여행자: 4단계 두 카드를 건너뜁니다. 다음 자신의 턴에 5단계 공개.")
	if c.id == "gambler":
		p.special = true
		deployed.board_slot = BOARD_DOCK
		var destroyed := 0
		for slot in range(p.units.size() - 1):
			if p.units[slot].alive:
				defeat([active, slot])
				destroyed += 1
			p.units[slot].board_slot = BOARD_DOCK
		if presentation_enabled:
			var location := [active, p.units.size() - 1]
			visual_events.append({"kind": "field_destroy", "target": location, "uid": get_unit(location).uid, "amount": destroyed, "hp": c.health, "source": [], "owner": active, "title": "악마의 필드 재구성"})
			visual_events.append({"kind": "arrival", "target": location, "uid": get_unit(location).uid, "amount": 0, "hp": c.health, "source": [], "owner": active, "title": "갬블의 악마 출현"})
	elif presentation_enabled:
		var location := [active, deployed_index]
		visual_events.append({"kind": "unit_arrival", "target": location, "uid": deployed.uid, "amount": 0, "hp": deployed.hp, "source": [], "owner": active, "title": "%s 출현" % c.name})
	if c.id == "phoenix" and deployed.alive:
		defeat([active, deployed_index])
	check_victory()
	if phase != "over": open_reactions()
	return true

func get_unit(target: Array) -> Dictionary:
	if target.size() != 2 or target[0] < 0 or target[0] > 1:
		return {}
	if target[1] < 0 or target[1] >= players[target[0]].units.size():
		return {}
	return players[target[0]].units[target[1]]

func valid_target(owner: int, source: Array, target: Array, kind: String, effect: String = "") -> bool:
	if effect.is_empty(): return false
	if kind == "none": return target.is_empty()
	var u := get_unit(target)
	if effect in ["retaliate", "revive_later"]:
		return reaction_target(owner, effect, target)
	if kind == "dead":
		return not u.is_empty() and not u.alive and u.card.id != "skipped"
	if u.is_empty() or not u.alive:
		return false
	if kind == "self" and source != target:
		return false
	if kind == "other_unit" and source == target:
		return false
	if kind == "enemy" and target[0] == owner:
		return false
	if kind in ["ally", "other_ally"] and target[0] != owner:
		return false
	if kind == "other_ally" and source == target:
		return false
	if effect == "swap" and (u.card.tier != 5 or target[0] == owner): return false
	if effect == "execute_low_tier" and (target[0] == owner or int(u.card.tier) > 3): return false
	if effect == "full_hit" and u.hp != u.card.health:
		return false
	return true

func can_ability(owner: int, index: int) -> bool:
	var u := get_unit([owner, index])
	if phase != "action" or priority != owner or u.is_empty() or not u.alive:
		return false
	if u.chain_used or u.turn_used:
		return false
	for option in ability_options(u.card):
		if not str(option.get("effect", "")).is_empty() and u.mana >= int(option.get("cost", 0)):
			return true
	return false

func ability_options(card: Dictionary) -> Array:
	if card.has("abilities"): return card.abilities
	if str(card.get("ability", "")).is_empty(): return []
	return [{"effect": card.ability, "cost": int(card.get("cost", 0)), "target": str(card.get("target", "")), "text": str(card.get("rules", ""))}]

# All costs are paid at declaration; a defeated source does not cancel a queued effect.
func attack(owner: int, index: int, target: Array) -> bool:
	var u := get_unit([owner, index])
	if phase != "action" or owner != active or not stack.is_empty() or priority != owner or u.is_empty() or not u.alive or u.mana <= 0:
		return false
	if not valid_target(owner, [owner, index], target, "enemy", "damage"):
		return false
	var damage: int = u.mana
	u.mana = 0
	queue_action(owner, u.card.name + " 기본 공격", "damage", target, damage, {}, [owner, index])
	stack.back()["damage_kind"] = "attack"
	return true

func ability(owner: int, index: int, target: Array, copied_id: String = "", copied_unit: Array = [], chosen_effect: String = "") -> bool:
	if not can_ability(owner, index):
		return false
	var u := get_unit([owner, index])
	var selected: Dictionary = {}
	for option in ability_options(u.card):
		if chosen_effect.is_empty() or str(option.get("effect", "")) == chosen_effect:
			selected = option
			break
	if selected.is_empty(): return false
	var effect: String = str(selected.get("effect", u.card.ability))
	var kind: String = str(selected.get("target", u.card.target))
	var cost: int = int(selected.get("cost", u.card.cost))
	if u.mana < cost: return false
	var effect_handler = u.card.effect_handler
	var replay_card: Dictionary = {}
	var target_source: Array = [owner, index]
	if effect == "replay":
		for c in players[owner].used:
			if c.id == copied_id and c.effect_handler.can_be_copied() and not str(c.spell).is_empty():
				replay_card = c
				effect = c.spell
				effect_handler = c.effect_handler
		if replay_card.is_empty():
			return false
		kind = TCGCards.spell_target(effect)
		target_source = []
	if effect == "copy":
		if copied_unit.size() != 2 or copied_unit[0] != owner: return false
		effect = copy_effect(copied_unit)
		kind = TCGCards.spell_target(effect)
		var copied_source := get_unit(copied_unit)
		if not copied_source.is_empty(): effect_handler = copied_source.card.effect_handler
	var target_count: int = int(selected.get("targets", 1))
	var targets: Array = target if target_count > 1 else [target]
	if effect == "" or targets.size() != target_count:
		return false
	for chosen_target in targets:
		if not chosen_target is Array or not valid_target(owner, target_source, chosen_target, kind, effect): return false
	if target_count > 1 and targets.duplicate().filter(func(value): return targets.count(value) > 1).size() > 0: return false
	u.mana -= cost
	u.chain_used = true
	u.turn_used = true
	if not replay_card.is_empty():
		queue_action(owner, replay_card.name + " 주문", effect, target, 0, {}, [owner, index], effect_handler)
		stack.back()["chain_card"] = replay_card
		stack.back()["damage_kind"] = "spell"
	else:
		queue_action(owner, u.card.name + " 소모 효과", effect, targets[0] if not targets.is_empty() else [], 0, {}, [owner, index], effect_handler)
		if target_count > 1: stack.back()["targets"] = targets.duplicate(true)
		stack.back()["damage_kind"] = "ability"
	return true

func copy_effect(source: Array) -> String:
	var u := get_unit(source)
	if u.is_empty() or not u.alive or not u.card.effect_handler.can_be_copied():
		return ""
	return u.card.spell

func cast_spell(owner: int, hand_index: int, target: Array, copied_unit: Array = []) -> bool:
	if phase not in ["action", "reaction"] or priority != owner or hand_index < 0 or hand_index >= players[owner].hand.size():
		return false
	var c: Dictionary = players[owner].hand[hand_index]
	var effect: String = c.spell
	var effect_handler = c.effect_handler
	if phase == "reaction" and effect not in ["retaliate", "revive_later"]: return false
	if effect == "copy":
		if copied_unit.size() != 2 or copied_unit[0] != owner: return false
		effect = copy_effect(copied_unit)
		var copied_source := get_unit(copied_unit)
		if not copied_source.is_empty(): effect_handler = copied_source.card.effect_handler
	if effect == "" or not valid_target(owner, [], target, TCGCards.spell_target(effect), effect):
		return false
	players[owner].hand.remove_at(hand_index)
	# The physical card enters the used zone only when this chain link resolves.
	queue_action(owner, c.name + " 주문", effect, target, 0, c, [], effect_handler)
	stack.back()["damage_kind"] = "spell"
	if effect == "revive_later":
		stack.back()["revive_owner"] = owner
	return true

func queue_action(owner: int, title: String, effect: String, target: Array, amount: int = 0, spell: Dictionary = {}, source: Array = [], effect_handler = null) -> void:
	stack.append({"owner": owner, "title": title, "effect": effect, "target": target.duplicate(), "amount": amount, "spell": spell, "source": source.duplicate(), "effect_handler": effect_handler})
	stack.back()["target_uid"] = get_unit(target).get("uid", -1)
	stack.back()["source_uid"] = get_unit(source).get("uid", -1)
	var target_name := "대상 없음" if target.is_empty() else str(get_unit(target).get("card", {}).get("name", "유효하지 않은 대상"))
	note("P%d 선언: %s → %s" % [owner + 1, title, target_name])
	if ending:
		note("대응 행동으로 턴 종료가 취소됨.")
	ending = false
	passes = 0
	priority = 1 - owner

func pass_priority() -> void:
	if phase not in ["action", "reaction"]:
		return
	passes += 1
	if passes == 2:
		passes = 0
		if phase == "reaction":
			reaction_window.clear()
			phase = "action"
			resolve_chain()
			return
		if not stack.is_empty():
			resolve_chain()
		elif ending:
			finish_turn()
		else:
			priority = active
			note("양측 패스. 턴 플레이어가 행동 또는 턴 종료를 선택하세요.")
	else:
		priority = 1 - priority

func request_end() -> bool:
	if phase != "action" or priority != active or not stack.is_empty():
		return false
	ending = true
	passes = 1
	priority = 1 - active
	note("P%d 턴 종료 선언. 상대는 대응하거나 종료를 승인하세요." % [active + 1])
	return true

func resolve_chain() -> void:
	while not stack.is_empty():
		var action: Dictionary = stack.pop_back()
		apply_effect(action)
		if not action.spell.is_empty():
			players[action.owner].used.append(action.spell)
		check_victory()
		if phase == "over":
			stack.clear()
			return
		if open_reactions(): return
	for p in players:
		for u in p.units:
			u.chain_used = false
	priority = active
	if finishing: process_end_rolls()

func apply_effect(action: Dictionary) -> void:
	for field in ["target", "source"]:
		if action.get(field + "_uid", -1) >= 0:
			action[field] = locate(action[field + "_uid"])
	var handler = action.get("effect_handler", null)
	if handler == null:
		var source: Array = action.get("source", [])
		if not source.is_empty():
			handler = get_unit(source).card.get("effect_handler", null)
		elif not action.get("spell", {}).is_empty():
			handler = action.spell.get("effect_handler", null)
	if handler != null:
		handler.resolve(self, action)
	else:
		apply_standard_effect(action)

func apply_standard_effect(action: Dictionary) -> void:
	var u := get_unit(action.target)
	if action.effect == "deploy_cloak":
		for index in range(players[action.owner].units.size() - 1, -1, -1):
			var old_cloak: Dictionary = players[action.owner].units[index]
			if old_cloak.card.id == "cloak" and bool(old_cloak.get("withdrawn", false)):
				players[action.owner].units.remove_at(index)
				break
		var cloak := make_unit("cloak")
		cloak.board_slot = next_free_board_slot(action.owner)
		cloak.home_slot = 3
		players[action.owner].units.append(cloak)
		note("보호의 망토: 4단계 유닛으로 배치.")
		return
	if action.effect == "guard_allies":
		for ally in players[action.owner].units:
			if ally.alive and ally.uid != int(action.get("source_uid", -1)):
				ally.attack_immune_turn = turn_index
		note("탱커: 다른 아군이 이번 턴 기본 공격 피해를 받지 않습니다.")
		return
	if action.effect == "cloak_to_hand":
		players[action.owner].hand.append(TCGCards.by_id("cloak"))
		var cloak_source := get_unit(action.get("source", []))
		if not cloak_source.is_empty():
			cloak_source.alive = false
			cloak_source.withdrawn = true
			cloak_source.hp = 0
			cloak_source.mana = 0
			cloak_source.board_slot = BOARD_DOCK
		note("보호의 망토를 주문 상태로 패에 넣었습니다.")
		return
	if action.effect == "arm_apocalypse":
		var doom_source := get_unit(action.get("source", []))
		if not doom_source.is_empty():
			doom_source.doom_at = players[action.owner].own_turn + 1
			note("종말의 용: 다음 자신의 턴에 종말을 예약.")
		return
	if action.effect == "hit2_two":
		for chosen_target in action.get("targets", []):
			apply_standard_effect({"owner":action.owner,"title":action.title,"effect":"damage","amount":2,"target":chosen_target,"source":action.get("source", []),"damage_kind":"ability"})
		return
	if action.effect == "revive_later":
		if not u.is_empty() and not u.alive:
			var scheduled: int = int(players[action.get("revive_owner", action.owner)].own_turn) + 2
			u.revive_at = scheduled if int(u.get("revive_at", -1)) < 0 else mini(int(u.revive_at), scheduled)
			note("%s: 자신의 2턴 뒤 부활 예약." % u.card.name)
		return
	if u.is_empty() or not u.alive:
		note("%s: 대상이 재기불능이어서 불발." % action.title)
		return
	var effect: String = action.effect
	var amount: int = action.amount
	if effect == "double_production":
		u.bonus += production(u)
		note("%s: 생산력을 2배로 증가." % u.card.name)
		return
	if effect == "increase_reflect":
		u.reflect_bonus = int(u.get("reflect_bonus", 0)) + 1
		note("가시 골렘: 반사 피해 %d." % (2 + int(u.reflect_bonus)))
		return
	if effect == "increase_armor":
		u.armor_bonus = int(u.get("armor_bonus", 0)) + 1
		note("철벽 골렘: 피해 감소 %d." % (1 + int(u.armor_bonus)))
		return
	if effect == "execute_low_tier":
		if int(u.card.tier) <= 3 and action.target[0] != action.owner:
			defeat(action.target)
		return
	if effect == "grant_life2":
		u.max_hp += 2
		u.hp += 2
		visual_events.append(visual_event(action, "heal", 2, int(u.hp)))
		note("%s: 최대·현재 생명력 +2." % u.card.name)
		return
	if effect == "steal_life2":
		var source_unit := get_unit(action.get("source", []))
		u.max_hp -= 2
		u.hp -= 2
		visual_events.append(visual_event(action, "damage", 2, maxi(0, int(u.hp))))
		if not source_unit.is_empty() and source_unit.alive:
			source_unit.max_hp += 2
			source_unit.hp += 2
			note("불사조: %s의 생명력 2를 가져옴." % u.card.name)
		if u.hp <= 0 or u.max_hp <= 0: defeat(action.target)
		return
	if effect == "swap":
		var source: Array = action.get("source", [])
		var actor := get_unit(source)
		if not actor.is_empty() and actor.alive and u.card.tier == 5 and source[0] != action.target[0]:
			players[source[0]].units[source[1]] = u
			players[action.target[0]].units[action.target[1]] = actor
			note("배신자: 마나와 상태를 유지하며 소유권 교환.")
		return
	if effect == "power2":
		u.bonus += 2
		note("%s: 생산력 +2." % u.card.name)
		return
	if effect == "full_bonus":
		u.full_bonus = u.get("full_bonus", 0) + 1
		note("%s: 최대 생명력일 때 생산력 +1 부여." % u.card.name)
		return
	if effect == "retaliate":
		effect = "hit6"
	if effect == "full_hit" and u.hp != u.card.health:
		note("%s: 대상의 생명력이 최대가 아니어서 불발." % action.title)
		return
	if effect.begins_with("hit"):
		amount = int(effect.substr(3))
	if effect == "full_hit":
		amount = 2
	if effect == "damage" or effect.begins_with("hit") or effect == "full_hit":
		var reduced_damage: int = maxi(0, amount)
		if u.card.id == "rock": reduced_damage = mini(1, reduced_damage)
		elif u.card.id == "golem": reduced_damage = maxi(0, reduced_damage - 1 - int(u.get("armor_bonus", 0)))
		var cloaks := 0
		for player in players:
			for unit in player.units:
				if unit.alive and unit.card.id == "cloak": cloaks += 1
		reduced_damage = maxi(0, reduced_damage - cloaks)
		var absorbed: int = mini(u.shield, reduced_damage)
		u.shield -= absorbed
		var damage: int = reduced_damage - absorbed
		if str(action.get("damage_kind", "")) == "attack" and int(u.get("attack_immune_turn", -1)) == turn_index:
			damage = 0
		if u.card.id == "gambler" and players[action.target[0]].units.any(func(ally): return ally.alive and ally.card.id == "token_guard"):
			damage = 0
		u.hp -= damage
		visual_events.append(visual_event(action, "damage", damage, maxi(0, int(u.hp))))
		note("%s: %s 피해 %d." % [action.title, u.card.name, damage])
		if u.hp <= 0:
			defeat(action.target)
		var source: Array = action.get("source", [])
		var damage_kind := str(action.get("damage_kind", ""))
		if damage > 0 and damage_kind in ["attack", "ability"] and not get_unit(source).is_empty():
			reactions.append({"owner": action.target[0], "effect": "retaliate", "target": source.duplicate()})
			if u.card.id == "thorn" and not action.get("reflected", false):
				apply_standard_effect({"owner": action.target[0], "title": "가시 골렘 반사", "effect": "damage", "amount": 2 + int(u.get("reflect_bonus", 0)), "target": source, "source": action.target, "reflected": true, "damage_kind": "reflection"})
	elif effect.begins_with("heal"):
		amount = 1 if effect == "heal" else int(effect.substr(4))
		var healed: int = maxi(0, mini(amount, u.get("max_hp", u.card.health) - u.hp))
		u.hp += healed
		visual_events.append(visual_event(action, "heal", healed, int(u.hp)))
		note("%s: %s 회복 %d." % [action.title, u.card.name, healed])
	elif effect.begins_with("shield"):
		amount = 1 if effect == "shield" else int(effect.substr(6))
		u.shield += amount
		visual_events.append(visual_event(action, "shield", amount, int(u.hp)))
		note("%s: %s 방어막 %d." % [action.title, u.card.name, u.shield])
	elif effect.begins_with("mana"):
		amount = int(effect.substr(4))
		u.mana += amount
		visual_events.append(visual_event(action, "mana", amount, int(u.hp)))
		note("%s: %s 마나 +%d." % [action.title, u.card.name, amount])

func visual_event(action: Dictionary, kind: String, amount: int, hp: int) -> Dictionary:
	return {"kind": kind, "target": action.target.duplicate(), "amount": amount, "hp": hp, "source": action.get("source", []).duplicate(), "owner": action.get("owner", 0), "title": action.title}

func defeat(target: Array) -> void:
	var u := get_unit(target)
	if u.is_empty() or not u.alive: return
	var last_production := production(u)
	var defeated_board_slot := int(u.get("board_slot", BOARD_UNSET))
	u.alive = false
	u.hp = 0
	u.mana = 0
	u.shield = 0
	if players[target[0]].get("special", false) and u.card.id != "gambler":
		# The demon board keeps defeated cards as revival records, but frees their cells.
		u.board_slot = BOARD_DOCK
	note("%s 재기불능!" % u.card.name)
	reactions.append({"owner": target[0], "effect": "revive_later", "target": target.duplicate()})
	if u.card.id == "phoenix":
		u.revive_at = players[target[0]].own_turn + 1
	if u.card.id == "potato":
		var allies: Array = []
		for slot in range(players[target[0]].units.size()):
			if slot != target[1] and players[target[0]].units[slot].alive: allies.append([target[0], slot])
		if not allies.is_empty():
			var chosen: Array = allies[rng.randi_range(0, allies.size() - 1)]
			get_unit(chosen).mana += last_production
			note("최강의 감자 주마등: %s에게 마나 +%d." % [get_unit(chosen).card.name, last_production])
	if u.card.id == "mana_dragon":
		for ally in players[target[0]].units:
			if ally.alive:
				ally.mana += 2
		note("나마나마나용 주마등: 다른 모든 아군에게 마나 +2.")
	for ally in players[target[0]].units:
		if ally.alive:
			ally.card.effect_handler.on_ally_defeated(self, target[0], ally, u)
	# Every living enemy Dragon of the End splashes the two physical neighbours.
	for dragon_slot in range(players[1 - target[0]].units.size()):
		var dragon: Dictionary = players[1 - target[0]].units[dragon_slot]
		if not dragon.alive or dragon.card.id != "dragon": continue
		for neighbour_slot in [defeated_board_slot - 1, defeated_board_slot + 1]:
			for victim_index in range(players[target[0]].units.size()):
				var victim: Dictionary = players[target[0]].units[victim_index]
				if victim.alive and int(victim.get("board_slot", BOARD_UNSET)) == neighbour_slot:
					apply_standard_effect({"owner":1 - target[0],"title":"종말의 용 연쇄","effect":"damage","amount":1,"target":[target[0], victim_index],"source":[1 - target[0], dragon_slot],"damage_kind":"triggered"})
					break

func check_victory() -> void:
	for owner in range(2):
		if players.all(func(p): return p.revealed >= 6) and players[owner].units.all(func(u): return not u.alive):
			winner = 1 - owner
			phase = "over"
			note("P%d 승리! 상대 필드의 모든 유닛이 재기불능." % [winner + 1])
			return

func finish_turn() -> void:
	finishing = true
	for u in players[1 - active].units:
		if u.alive and u.card.id == "viper" and u.hp == u.get("max_hp", u.card.health):
			u.mana += 3
			note("예민한 독사: 상대 턴 종료에 마나 +3.")
	for u in players[active].units:
		if not u.alive: continue
		u.card.effect_handler.on_turn_end(self, u)
		if u.card.id == "gambler":
			for die in range(u.dice):
				end_rolls.append({"uid": u.uid, "roll": rng.randi_range(1, 6)})
	process_end_rolls()

func advance_turn() -> void:
	finishing = false
	for p in players:
		for u in p.units:
			u.shield = 0
	turn_index += 1
	begin_turn()

func revive(target: Array) -> void:
	var u := get_unit(target)
	if u.is_empty() or u.alive or u.card.id == "skipped": return
	var uid: int = u.uid
	var home_slot: int = int(u.get("home_slot", BOARD_UNSET))
	var current_board_slot: int = int(u.get("board_slot", BOARD_UNSET))
	var fresh := make_unit(u.card.id)
	fresh.uid = uid
	fresh.home_slot = home_slot
	if fresh.card.id == "gambler":
		fresh.board_slot = BOARD_DOCK
	elif current_board_slot not in [BOARD_UNSET, BOARD_DOCK]:
		# Special-board corpses already occupy a physical slot, so revival reuses it.
		fresh.board_slot = current_board_slot
	else:
		var preferred_free := home_slot != BOARD_UNSET
		if preferred_free:
			for other in players[target[0]].units:
				if other.alive and other.uid != uid and int(other.get("board_slot", BOARD_UNSET)) == home_slot:
					preferred_free = false
					break
		fresh.board_slot = home_slot if preferred_free else next_free_board_slot(target[0])
	# A revived unit must not recover an already spent once-per-turn activation.
	fresh.turn_used = u.turn_used
	players[target[0]].units[target[1]] = fresh
	visual_events.append({"kind": ("arrival" if fresh.card.id == "gambler" else "unit_arrival") if presentation_enabled else "heal", "target": target.duplicate(), "uid": uid, "amount": fresh.hp, "hp": fresh.hp, "source": [], "owner": target[0], "title": "부활"})
	note("%s 초기 상태로 부활 (마나 0)." % fresh.card.name)

func revive_for(owner: int, target: Array) -> void:
	if target.size() < 2 or target[0] < 0 or target[0] >= players.size(): return
	if target[1] < 0 or target[1] >= players[target[0]].units.size(): return
	if target[0] == owner:
		revive(target)
		return
	if board_card_count(owner) >= BASE_BOARD_SLOTS:
		note("악마의 놀이판 9칸이 가득 차 부활할 수 없습니다.")
		return
	var corpse: Dictionary = get_unit(target)
	if corpse.is_empty() or corpse.alive or corpse.card.id == "skipped": return
	var fresh := make_unit(corpse.card.id)
	fresh.turn_used = corpse.turn_used
	if fresh.card.id == "gambler":
		fresh.board_slot = BOARD_DOCK
	else:
		fresh.board_slot = next_free_board_slot(owner)
	players[target[0]].units.remove_at(target[1])
	players[owner].units.append(fresh)
	var revived_target := [owner, players[owner].units.size() - 1]
	visual_events.append({"kind": ("arrival" if fresh.card.id == "gambler" else "unit_arrival") if presentation_enabled else "heal", "target": revived_target, "uid": fresh.uid, "amount": fresh.hp, "hp": fresh.hp, "source": [], "owner": owner, "title": "부활"})
	note("%s을 P%d의 필드에 초기 상태로 부활 (마나 0)." % [fresh.card.name, owner + 1])

func reaction_target(owner: int, effect: String, target: Array) -> bool:
	if phase != "reaction": return false
	for event in reaction_window:
		if event.owner != owner or event.effect != effect or event.target != target: continue
		var u := get_unit(target)
		if u.is_empty(): continue
		if effect == "retaliate": return u.alive
		return not u.alive and u.card.id != "skipped"
	return false

func open_reactions() -> bool:
	if reactions.is_empty(): return false
	reaction_window = reactions.duplicate(true)
	reactions.clear()
	phase = "reaction"
	for event in reaction_window:
		for card in players[event.owner].hand:
			if card.spell == event.effect and reaction_target(event.owner, card.spell, event.target):
				priority = event.owner
				passes = 0
				note("피해/처치 직후: 조건부 주문을 사용하거나 패스하세요.")
				return true
	reaction_window.clear()
	phase = "action"
	return false

func choice_targets() -> Array:
	var result: Array = []
	if phase != "choice": return result
	var revive_types := {}
	var revive_owner := int(choice.get("owner", -1))
	var choice_source := locate(int(choice.get("uid", -1)))
	if revive_owner < 0 and not choice_source.is_empty(): revive_owner = choice_source[0]
	for owner in range(2):
		for slot in range(players[owner].units.size()):
			var u: Dictionary = players[owner].units[slot]
			if choice.roll == 3 and not u.alive and u.card.id != "skipped" and not bool(u.get("withdrawn", false)):
				var already_on_board := owner == revive_owner and int(u.get("board_slot", BOARD_UNSET)) not in [BOARD_UNSET, BOARD_DOCK]
				if not already_on_board and (revive_owner < 0 or board_card_count(revive_owner) >= BASE_BOARD_SLOTS): continue
				if revive_types.has(u.card.id): continue
				revive_types[u.card.id] = true
				result.append([owner, slot])
			elif choice.roll == 4 and choice.get("stage", "") == "target" and u.alive:
				var copied := TCGCards.by_id(str(choice.get("spell_id", "")))
				if not copied.is_empty() and valid_target(revive_owner, [], [owner, slot], TCGCards.spell_target(copied.spell), copied.spell):
					result.append([owner, slot])
			elif choice.roll == 5 and u.alive:
				result.append([owner, slot])
	return result

func roll_four_spell_choices() -> Array:
	var result: Array = []
	if phase != "choice" or int(choice.get("roll", 0)) != 4 or choice.get("stage", "") != "spell": return result
	var owner := _roll_owner(choice)
	if owner not in [0, 1]: return result
	var opponent := 1 - owner
	for index in range(players[opponent].used.size()):
		var card: Dictionary = players[opponent].used[index]
		var effect := str(card.get("spell", ""))
		# These effects require a separate timing or nested-copy procedure, so the roll is a dud for them.
		if effect.is_empty() or effect in ["copy", "retaliate", "revive_later"]: continue
		var has_target := false
		for target_owner in range(2):
			for slot in range(players[target_owner].units.size()):
				if valid_target(owner, [], [target_owner, slot], TCGCards.spell_target(effect), effect):
					has_target = true
					break
			if has_target: break
		if has_target: result.append(index)
	return result

func choose_roll_spell(index: int) -> bool:
	if index not in roll_four_spell_choices(): return false
	var owner := _roll_owner(choice)
	var card: Dictionary = players[1 - owner].used[index]
	choice.stage = "target"
	choice.spell_id = card.id
	if choice_targets().is_empty():
		note("갬블의 악마 4: 조건을 만족하는 대상이 없어 꽝.")
		var finished := choice.duplicate()
		choice.clear()
		phase = "action"
		_resume_after_roll(finished)
	return true

func _roll_owner(roll: Dictionary) -> int:
	var owner := int(roll.get("owner", -1))
	if owner in [0, 1]: return owner
	var source := locate(int(roll.get("uid", -1)))
	return int(source[0]) if not source.is_empty() else -1

func _resume_after_roll(roll: Dictionary) -> void:
	if bool(roll.get("from_spell", false)):
		phase = "action"
		priority = active
	else:
		process_end_rolls()

func choose_roll_target(target: Array) -> bool:
	if target not in choice_targets(): return false
	var finished := choice.duplicate()
	var source := locate(int(choice.get("uid", -1)))
	var u := get_unit(source)
	var owner := _roll_owner(choice)
	var roll: int = int(choice.roll)
	choice.clear()
	phase = "action"
	if roll == 3:
		revive_for(owner, target)
	elif roll == 4:
		var copied := TCGCards.by_id(str(finished.get("spell_id", "")))
		if not copied.is_empty():
			var copied_action := {"owner": owner, "title": "갬블의 악마 · 4 · " + copied.name, "effect": copied.spell, "amount": 0, "target": target, "source": source, "damage_kind": "spell"}
			copied.effect_handler.resolve(self, copied_action)
	elif roll == 5 and not u.is_empty() and u.alive:
		u.max_hp += 6
		u.hp += 6
		apply_standard_effect({"owner": owner, "title": "갬블의 악마 · 5", "effect": "damage", "amount": 6, "target": target, "source": source, "damage_kind": "triggered"})
	check_victory()
	if phase == "over": return true
	if not open_reactions(): _resume_after_roll(finished)
	return true

func process_end_rolls() -> void:
	while not end_rolls.is_empty():
		var roll: Dictionary = end_rolls.pop_front()
		var source := locate(roll.uid)
		var u := get_unit(source)
		if u.is_empty() or not u.alive: continue
		if presentation_enabled:
			pending_roll = roll
			phase = "roulette"
			priority = source[0]
			visual_events.append({"kind": "roulette", "target": source, "uid": u.uid, "amount": roll.roll, "hp": u.hp, "source": [], "owner": source[0], "title": "갬블의 악마 룰렛"})
			return
		apply_roll(roll)
		if phase == "choice": return
	check_victory()
	if phase != "over": advance_turn()

func complete_roll() -> bool:
	if phase != "roulette" or pending_roll.is_empty(): return false
	var roll := pending_roll.duplicate()
	pending_roll.clear()
	phase = "action"
	apply_roll(roll)
	if phase != "choice": _resume_after_roll(roll)
	return true

func apply_roll(roll: Dictionary) -> void:
	var source := locate(int(roll.get("uid", -1)))
	var u := get_unit(source)
	var owner := _roll_owner(roll)
	if owner not in [0, 1]: return
	if not bool(roll.get("from_spell", false)) and (u.is_empty() or not u.alive): return
	note("갬블의 악마 주사위: %d" % roll.roll)
	match int(roll.roll):
		1, 2:
			for n in range(6 if roll.roll == 1 else 2):
				if board_card_count(owner) >= BASE_BOARD_SLOTS:
					note("악마의 놀이판 9칸이 가득 차 더 소환할 수 없습니다.")
					break
				var unit := make_unit("token_guard" if roll.roll == 1 else "token_six")
				unit.board_slot = next_free_board_slot(owner)
				players[owner].units.append(unit)
				if presentation_enabled:
					visual_events.append({"kind": "summon", "target": [owner, players[owner].units.size() - 1], "uid": unit.uid, "amount": 0, "hp": unit.hp, "source": source, "owner": owner, "title": "하수인 소환"})
		3:
			choice = roll.duplicate(true)
			phase = "choice"
			priority = owner
			if not choice_targets().is_empty(): return
			note("갬블의 악마 3: 부활할 유닛이 없어 꽝.")
			choice.clear()
			phase = "action"
		4:
			choice = roll.duplicate(true)
			choice.stage = "spell"
			phase = "choice"
			priority = owner
			if not roll_four_spell_choices().is_empty(): return
			note("갬블의 악마 4: 적용할 수 있는 상대 주문이 없어 꽝.")
			choice.clear()
			phase = "action"
		5:
			if u.is_empty() or not u.alive:
				note("갬블의 악마 5: 강화할 악마가 없어 꽝.")
				return
			choice = roll.duplicate(true)
			phase = "choice"
			priority = owner
			if not choice_targets().is_empty(): return
			note("갬블의 악마 5: 피해를 줄 대상이 없어 꽝.")
			choice.clear()
			phase = "action"
		6:
			if u.is_empty() or not u.alive:
				note("갬블의 악마 6: 주사위를 늘릴 악마가 없어 꽝.")
			else:
				u.dice += 1
