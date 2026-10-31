extends "res://cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"vanilla_latte","name":"바닐라 라떼","tier":3,"power":3,"health":11,"rules":"지속 - 따뜻하다.","spell_text":"","cost":0,"ability":"","target":"","spell":""}
	data.effect_handler = self
	return data
