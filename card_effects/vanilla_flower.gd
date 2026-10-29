extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"vanilla_flower","name":"바닐라 꽃","tier":5,"power":5,"health":18,"rules":"지속 - 향기롭다.","spell_text":"","cost":0,"ability":"","target":"","spell":""}
	data.effect_handler = self
	return data
