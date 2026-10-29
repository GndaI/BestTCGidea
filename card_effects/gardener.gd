extends TCGCardEffect

func card_data() -> Dictionary:
	return {
		"id": "gardener",
		"name": "마나 정원사",
		"tier": 3,
		"power": 2,
		"health": 8,
		"rules": "소모 2: 다른 아군에게 마나 2 전달.",
		"spell_text": "",
		"cost": 2,
		"ability": "mana2",
		"target": "other_ally",
		"spell": "",
		"effect_handler": self,
	}

func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
