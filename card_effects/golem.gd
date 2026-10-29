extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"golem","name":"철벽 골렘","tier":5,"power":3,"health":16,"rules":"지속 - 자신이 받는 피해가 1 감소한다.\n소모 5 - 자신의 지속 효과의 수치를 1 증가시킨다.","spell_text":"","cost":5,"ability":"increase_armor","target":"self","spell":"","abilities":[{"effect":"increase_armor","cost":5,"target":"self","text":"피해 감소량을 1 증가시킨다"}]}
	data.effect_handler = self
	return data
