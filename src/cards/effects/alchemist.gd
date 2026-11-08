extends TCGCardEffect

func limited_to_once_per_turn() -> bool:
	return true

func card_data() -> Dictionary:
	return {
		"id": "alchemist",
		"name": "별빛 연금술사",
		"tier": 4,
		"power": 2,
		"health": 10,
		"rules": "소모 2: 아군 생명력 3 회복. 전체 턴당 1회.",
		"spell_text": "아군에게 마나 3 부여.",
		"cost": 2,
		"ability": "heal3",
		"target": "ally",
		"spell": "mana3",
		"effect_handler": self,
	}

func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
