extends TCGCardEffect

func card_data() -> Dictionary:
	return {
		"id": "hunter",
		"name": "황혼의 사냥꾼",
		"tier": 5,
		"power": 4,
		"health": 10,
		"rules": "소모 3: 적에게 피해 4.",
		"spell_text": "",
		"cost": 3,
		"ability": "hit4",
		"target": "enemy",
		"spell": "",
		"effect_handler": self,
	}

func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
