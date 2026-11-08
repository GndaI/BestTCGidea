extends TCGCardEffect

func limited_to_once_per_turn() -> bool:
	return true

func has_income_choice() -> bool:
	return card_data().id in ["potato", "bean"]

func production_bonus(unit: Dictionary) -> int:
	return 0

func resolve_income_choice(battle: TCGBattle, unit: Dictionary, grow: bool) -> void:
	var amount: int = battle.production(unit)
	if grow:
		var gain: int = 1 if unit.card.id == "potato" else amount
		unit.bonus += gain
		battle.note("%s: 생산력 +%d" % [unit.card.name, gain])
	else:
		unit.mana += amount

func modify_incoming_damage(amount: int) -> int:
	if card_data().id == "rock": return mini(1, amount)
	if card_data().id == "golem": return maxi(0, amount - 1)
	return amount

func on_turn_end(_battle: TCGBattle, unit: Dictionary) -> void:
	if unit.card.id == "assassin": unit.mana = 0

func on_deploy(battle: TCGBattle, owner: int, paired_spell: Dictionary) -> bool:
	if card_data().id != "student": return false
	battle.players[owner].used.append(paired_spell)
	battle.note("수습생: %s 주문을 사용됨으로 배치." % paired_spell.name)
	return true

func can_be_copied() -> bool:
	return card_data().id not in ["student", "thorn", "phoenix", "gambler"]
