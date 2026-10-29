extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"vanilla_ice","name":"바닐라 아이스크림","tier":1,"power":1,"health":4,"rules":"지속 - 달달하다.","spell_text":"","cost":0,"ability":"","target":"","spell":""}
	data.effect_handler = self
	return data
