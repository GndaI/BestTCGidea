extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"mana_dragon","name":"나마나마나용","tier":5,"power":0,"health":12,"rules":"지속 - 자신 필드의 다른 모든 유닛의 생산력을 2 올린다.\n주마등 - 자신 필드의 다른 모든 유닛에게 마나를 2 준다.","spell_text":"","cost":0,"ability":"","target":"","spell":""}
	data.effect_handler = self
	return data
