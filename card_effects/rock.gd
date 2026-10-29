extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"rock","name":"바위 골렘","tier":3,"power":3,"health":3,"rules":"지속 - 자신이 받는 피해가 1을 넘길 수 없다.\n소모 2 - 자신의 체력을 1 회복한다.","spell_text":"","cost":2,"ability":"heal1","target":"self","spell":"","abilities":[{"effect":"heal1","cost":2,"target":"self","text":"자신의 체력을 1 회복한다"}]}
	data.effect_handler = self
	return data
