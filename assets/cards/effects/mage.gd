extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"mage","name":"번개술사","tier":4,"power":4,"health":10,"rules":"소모 3 - 대상에게 피해 4. (턴당 1회)","spell_text":"대상에게 피해 4.","cost":3,"ability":"hit4","target":"enemy","spell":"hit4"}
	data.effect_handler = self
	return data
