extends TCGCardEffect

func on_ally_defeated(battle: TCGBattle, _owner: int, unit: Dictionary, defeated: Dictionary) -> void:
	if unit.alive:
		unit.bonus += defeated.card.power
		battle.note("광전사: 기본 생산력 %d 흡수." % defeated.card.power)

func card_data() -> Dictionary:
	return {
		"id": "berserker",
		"name": "열성적인 광전사",
		"tier": 3,
		"power": 1,
		"health": 10,
		"rules": "다른 아군이 재기불능이 되면 그 카드의 기본 생산력을 영구히 얻는다.",
		"spell_text": "",
		"cost": 0,
		"ability": "",
		"target": "",
		"spell": "",
		"effect_handler": self,
	}

func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
