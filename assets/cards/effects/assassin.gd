extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"assassin","name":"한밤의 암살자","tier":1,"power":2,"health":2,"rules":"지속 - 자신의 턴 종료에 자신의 마나는 0이 된다.","spell_text":"","cost":0,"ability":"","target":"","spell":""}
	data.effect_handler = self
	return data
