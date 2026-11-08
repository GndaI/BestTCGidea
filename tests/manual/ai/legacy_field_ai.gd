extends TCGFieldAI

# Snapshot of the first field-control scoring rule, before mana and spell
# preservation were added. Used only for regression matches.
func score_action(b: TCGBattle, action: Dictionary) -> float:
	var effect := _action_effect(b, action)
	var target: Array = action.get("target", [])
	var unit := b.get_unit(target)
	if unit.is_empty(): return -1000000.0
	var score := 0.0
	var damage := _effective_damage(b, target, _damage_amount(b, action, effect))
	if damage > 0:
		var kills := damage >= int(unit.hp)
		if kills:
			score += 20000.0 + _unit_threat(b, target)
			if unit.card.id == "token_guard": score += 900.0
			if unit.card.id == "phoenix": score -= 350.0
		else:
			score += float(damage * 34)
			if unit.card.id == "viper" and unit.hp == unit.max_hp: score += 500.0
			if int(unit.hp) - damage <= 6: score += 280.0
		if action.type == "attack":
			score -= float(_damage_amount(b, action, effect) * (18 if not kills else 5))
		return score
	if effect == "swap":
		var source := b.get_unit([action.owner, action.index])
		return 2500.0 + _unit_threat(b, target) - _unit_card_score(source.card)
	if effect == "revive_later":
		return 15000.0 + float(unit.card.tier * 250)
	if effect.begins_with("heal"):
		var amount := 1 if effect == "heal" else int(effect.substr(4))
		var missing: int = maxi(0, int(unit.max_hp) - int(unit.hp))
		if missing == 0: return -500.0
		var restored: int = mini(amount, missing)
		score = float(restored * 55)
		if int(unit.hp) <= 6: score += 500.0 + _unit_threat(b, target) * 0.25
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
		return float(amount * 45) + _unit_threat(b, target) * 0.08
	if effect in ["power2", "full_bonus"]:
		return 260.0 + _unit_threat(b, target) * 0.06
	return -50.0
