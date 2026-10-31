extends TCGCardEffect

func card_data() -> Dictionary:
	return {
		"id": "guardian",
		"name": "새벽의 수호자",
		"tier": 4,
		"power": 3,
		"health": 10,
		"rules": "소모 2: 아군의 이번 턴 다음 피해를 3 감소. 중첩 불가.",
		"spell_text": "아군의 이번 턴 다음 피해를 4 감소. 중첩 불가.",
		"cost": 2,
		"ability": "shield3",
		"target": "ally",
		"spell": "shield4",
		"effect_handler": self,
	}

func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
