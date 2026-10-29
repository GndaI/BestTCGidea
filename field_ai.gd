class_name TCGFieldAI
extends RefCounted

# Board-control test AI. It values confirmed removals before raw damage and
# never reads the opponent's hand.
var last_turn := -1
var actions_this_turn := 0
var rng := RandomNumberGenerator.new()
const ACTION_LIMIT := 24
const MIN_ACTION_SCORE := 1.0

func _init() -> void:
	rng.randomize()

func random_deck() -> Array:
	var deck: Array = []
	for tier in range(1, 7):
		var pool := TCGCards.pool(tier)
		var first := rng.randi_range(0, pool.size() - 1)
		var second := (first + rng.randi_range(1, pool.size() - 1)) % pool.size()
		deck.append([pool[first].id, pool[second].id])
	return deck

func _unit_threat(b: TCGBattle, target: Array) -> float:
	var unit := b.get_unit(target)
	if unit.is_empty() or not unit.alive:
		return 0.0
	var score := float(unit.card.tier * 140 + b.production(unit) * 110 + unit.mana * 35)
	if unit.card.id == "mana_dragon": score += 850.0
	if unit.card.id == "gambler": score += 900.0
	if unit.card.id == "token_guard": score += 700.0
	if unit.card.id == "phoenix": score -= 180.0
	return score

func _unit_card_score(card: Dictionary) -> float:
	var score := float(card.health * 28 + card.power * 95 + card.tier * 45)
	if card.ability != "": score += 180.0
	if card.id == "mana_dragon": score += 650.0
	if card.id == "rock": score += 420.0
	return score

func _spell_card_score(card: Dictionary) -> float:
	if card.spell == "": return 0.0
	if card.spell in ["hit4", "hit6", "retaliate"]: return 600.0
	if card.spell == "revive_later": return 720.0
	if card.spell.begins_with("heal"): return 360.0
	if card.spell.begins_with("shield"): return 330.0
	if card.spell.begins_with("mana"): return 300.0
	if card.spell in ["copy", "power2", "full_bonus"]: return 280.0
	return 100.0

func _deploy_score(b: TCGBattle, choice_index: int) -> float:
	var tier: int = b.players[b.active].revealed + 1
	var pair: Array = b.players[b.active].deck[tier - 1]
	var unit_card := TCGCards.by_id(pair[choice_index])
	var score := _unit_card_score(unit_card)
	if unit_card.id == "gambler":
		var own_alive: int = b.players[b.active].units.filter(func(unit): return unit.alive).size()
		var enemy_alive: int = b.players[1 - b.active].units.filter(func(unit): return unit.alive).size()
		# The demon destroys the current allied field, so it is a comeback choice,
		# not an automatic high-tier deployment.
		score = 1400.0 + float(enemy_alive * 220 - own_alive * 900)
	if tier % 2 == 0:
		score += _spell_card_score(TCGCards.by_id(pair[1 - choice_index]))
	return score

func _action_effect(b: TCGBattle, action: Dictionary) -> String:
	if action.type == "attack": return "damage"
	if action.type == "ability":
		var source := b.get_unit([action.owner, action.index])
		if source.is_empty(): return ""
		if source.card.ability == "replay":
			for card in b.players[action.owner].used:
				if card.id == action.get("copied_id", ""): return card.spell
		if source.card.ability == "copy":
			return b.copy_effect(action.get("copied_unit", []))
		return str(action.get("effect", source.card.ability))
	if action.type == "spell":
		if action.index < 0 or action.index >= b.players[action.owner].hand.size(): return ""
		var card: Dictionary = b.players[action.owner].hand[action.index]
		if card.spell == "copy": return b.copy_effect(action.get("copied_unit", []))
		return card.spell
	return ""

func _damage_amount(b: TCGBattle, action: Dictionary, effect: String) -> int:
	if action.type == "attack":
		return int(b.get_unit([action.owner, action.index]).get("mana", 0))
	if effect == "retaliate": return 6
	if effect == "full_hit": return 2
	if effect.begins_with("hit"): return int(effect.substr(3))
	return 0

func _effective_damage(b: TCGBattle, target: Array, amount: int) -> int:
	var unit := b.get_unit(target)
	if unit.is_empty() or not unit.alive: return 0
	if unit.card.id == "gambler":
		for ally in b.players[target[0]].units:
			if ally.alive and ally.card.id == "token_guard": return 0
	var after_shield := maxi(0, amount - int(unit.shield))
	return int(unit.card.effect_handler.modify_incoming_damage(after_shield))

func _pending_damage_to(b: TCGBattle, target: Array) -> int:
	var uid: int = b.get_unit(target).get("uid", -1)
	var total := 0
	for pending in b.stack:
		if pending.get("target_uid", -2) != uid: continue
		var effect: String = pending.effect
		if effect == "damage": total += int(pending.amount)
		elif effect == "full_hit": total += 2
		elif effect == "retaliate": total += 6
		elif effect.begins_with("hit"): total += int(effect.substr(3))
	return total

func _action_key(action: Dictionary) -> String:
	return "%s:%d:%s" % [action.type, int(action.get("index", -1)), str(action.get("copied_id", ""))]

func _combo_damage(b: TCGBattle, action: Dictionary, target: Array, first_damage: int) -> int:
	var total := first_damage
	var seen := {_action_key(action): true}
	for candidate in TCGRandomAI.legal_actions(b, action.owner):
		if candidate.get("target", []) != target: continue
		var key := _action_key(candidate)
		if seen.has(key): continue
		var effect := _action_effect(b, candidate)
		var amount := _effective_damage(b, target, _damage_amount(b, candidate, effect))
		if amount <= 0: continue
		seen[key] = true
		total += amount
	return total

func _action_resource_penalty(b: TCGBattle, action: Dictionary, target_hp: int, damage: int) -> float:
	var penalty := 0.0
	if action.type == "spell":
		# A spell is a one-shot resource; prefer reusable mana when both secure the same removal.
		penalty += 850.0
	elif action.type == "ability":
		var source := b.get_unit([action.owner, action.index])
		if not source.is_empty(): penalty += float(source.card.cost * 55)
	elif action.type == "attack":
		# Basic attacks consume the entire mana bank. Penalize only the portion that
		# does not contribute to the removal heavily, while retaining a small cost
		# for mana that could have threatened a stronger unit later.
		var spent := _damage_amount(b, action, "damage")
		penalty += float(maxi(0, spent - target_hp) * 420 + mini(spent, target_hp) * 12)
	return penalty

func score_action(b: TCGBattle, action: Dictionary) -> float:
	var effect := _action_effect(b, action)
	var target: Array = action.get("target", [])
	if not target.is_empty() and target[0] is Array:
		var total := 0.0
		for single_target in target:
			var single_action := action.duplicate(true)
			single_action.target = single_target
			total += score_action(b, single_action)
		return total
	if target.is_empty():
		if effect == "arm_apocalypse": return 5000.0
		if effect == "guard_allies": return 850.0 if not b.stack.is_empty() else 180.0
		if effect == "cloak_to_hand": return 420.0
		return -50.0
	var unit := b.get_unit(target)
	if unit.is_empty(): return -1000000.0
	var score := 0.0
	var damage := _effective_damage(b, target, _damage_amount(b, action, effect))
	if damage > 0:
		var kills := damage >= int(unit.hp)
		if kills:
			# A removal is valuable, but the victim's threat and wasted resources must
			# decide which removal is actually best.
			score += 12000.0 + _unit_threat(b, target) * 5.0
			if unit.card.id == "token_guard": score += 900.0
			if unit.card.id == "phoenix": score -= 350.0
			score -= _action_resource_penalty(b, action, int(unit.hp), damage)
		else:
			var combo_damage := _combo_damage(b, action, target, damage)
			if combo_damage >= int(unit.hp):
				# Spend resources when the currently available sequence can finish the unit.
				score = 5200.0 + _unit_threat(b, target) * 2.0 + float(damage * 30)
				score -= _action_resource_penalty(b, action, int(unit.hp), damage)
			elif effect == "retaliate":
				# This reaction window expires; useful retaliation need not be hoarded forever.
				score = float(damage * 60) + _unit_threat(b, target) * 0.2
			elif action.type == "ability":
				var source := b.get_unit([action.owner, action.index])
				var cost: int = int(source.card.cost) if not source.is_empty() else 0
				score = float(damage * 55 - cost * 70)
			elif unit.card.id == "viper" and unit.hp == unit.max_hp:
				score = 420.0 + float(damage * 20)
			elif action.type == "attack":
				var source := b.get_unit([action.owner, action.index])
				# Assassin mana disappears at turn end, so spending it is not a lost bank.
				score = float(damage * 20) if not source.is_empty() and source.card.id == "assassin" else -300.0
			else:
				# Preserve one-shot damage spells until they kill or complete a kill sequence.
				score = -650.0
		return score
	if effect == "swap":
		var source := b.get_unit([action.owner, action.index])
		return 2500.0 + _unit_threat(b, target) - _unit_card_score(source.card)
	if effect == "revive_later":
		return 15000.0 + float(unit.card.tier * 250)
	if effect == "execute_low_tier":
		return 14000.0 + _unit_threat(b, target) if target[0] != action.owner else -10000.0
	if effect == "steal_life2":
		return 900.0 + _unit_threat(b, target) * 0.1 if target[0] != action.owner else -800.0
	if effect == "grant_life2":
		return 520.0 + _unit_threat(b, target) * 0.08 if target[0] == action.owner else -800.0
	if effect in ["double_production", "increase_reflect", "increase_armor"]:
		return 700.0
	if effect.begins_with("heal"):
		var amount := 1 if effect == "heal" else int(effect.substr(4))
		var missing: int = maxi(0, int(unit.max_hp) - int(unit.hp))
		if missing == 0: return -500.0
		var restored: int = mini(amount, missing)
		score = float(restored * 55)
		if int(unit.hp) <= 6: score += 500.0 + _unit_threat(b, target) * 0.25
		if action.type == "spell" and int(unit.hp) > 6: score -= 650.0
		return score
	if effect.begins_with("shield"):
		var amount := 1 if effect == "shield" else int(effect.substr(6))
		var incoming := _pending_damage_to(b, target)
		if incoming <= 0: return -400.0
		score = float(mini(amount, incoming) * 65)
		if incoming >= int(unit.hp) and incoming - amount < int(unit.hp): score += 12000.0
		return score
	if effect.begins_with("mana"):
		var amount := int(effect.substr(4))
		for enemy_index in range(b.players[1 - action.owner].units.size()):
			var enemy := b.get_unit([1 - action.owner, enemy_index])
			if enemy.alive and _effective_damage(b, [1 - action.owner, enemy_index], int(unit.mana) + amount) >= int(enemy.hp):
				return 1800.0 + _unit_threat(b, [1 - action.owner, enemy_index])
		return -450.0 if action.type == "spell" else 80.0
	if effect in ["power2", "full_bonus"]:
		return 260.0 + _unit_threat(b, target) * 0.06
	return -50.0

func _best_choice_target(b: TCGBattle, owner: int) -> Array:
	var targets := b.choice_targets()
	if targets.is_empty(): return []
	var best: Array = targets[0]
	var best_score := -1000000.0
	for target in targets:
		var unit := b.get_unit(target)
		var value := _unit_card_score(unit.card)
		var score := value if b.choice.roll == 3 and target[0] == owner else -value
		if b.choice.roll == 5:
			var damage := _effective_damage(b, target, 6)
			score = (20000.0 + _unit_threat(b, target) if target[0] != owner and damage >= unit.hp else float(damage * 35))
			if target[0] == owner: score -= 20000.0
		if score > best_score:
			best_score = score
			best = target
	return best

func step(b: TCGBattle, owner: int = 1) -> bool:
	if b.phase == "over" or b.priority != owner: return false
	if last_turn != b.turn_index:
		last_turn = b.turn_index
		actions_this_turn = 0
	if b.phase == "growth":
		var unit := b.get_unit(b.locate(b.income_choices.front()))
		var grow: bool = int(unit.bonus) < (2 if unit.card.id == "potato" else 6) and b.players[owner].own_turn <= 4
		b.grow_potato(grow)
		return true
	if b.phase == "deploy":
		return b.deploy(0 if _deploy_score(b, 0) >= _deploy_score(b, 1) else 1)
	if b.phase == "choice":
		return b.choose_roll_target(_best_choice_target(b, owner))
	if b.phase not in ["action", "reaction"]: return false
	var best_action: Dictionary = {}
	var best_score := -1000000.0
	for action in TCGRandomAI.legal_actions(b, owner):
		var action_score := score_action(b, action)
		if action_score > best_score:
			best_score = action_score
			best_action = action
	if not best_action.is_empty() and actions_this_turn < ACTION_LIMIT and best_score >= MIN_ACTION_SCORE:
		if TCGRandomAI.perform(b, best_action):
			actions_this_turn += 1
			return true
	if b.phase == "action" and b.active == owner and b.stack.is_empty():
		return b.request_end()
	b.note("P%d 필드 AI: 유리한 대응이 없어 패스." % [owner + 1])
	b.pass_priority()
	return true
