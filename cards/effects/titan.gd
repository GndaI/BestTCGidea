extends TCGCardEffect

func card_data() -> Dictionary:
	return {
		"id": "titan",
		"name": "마나 거신",
		"tier": 6,
		"power": 4,
		"health": 19,
		"rules": "소모 3: 아군의 이번 턴 다음 피해를 4 감소. 중첩 불가.",
		"spell_text": "아군에게 마나 5 부여.",
		"cost": 3,
		"ability": "shield4",
		"target": "ally",
		"spell": "mana5",
		"effect_handler": self,
	}

func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
