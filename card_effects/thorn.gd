extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"thorn","name":"가시 골렘","tier":4,"power":2,"health":12,"rules":"지속 - 자신이 유닛에 의해 피해를 받은 후, 그 유닛에게 피해를 2 준다.\n소모 3 - 자신의 지속 효과의 수치를 1 증가시킨다.","spell_text":"자신 유닛이 유닛에 의해 피해를 받으면 발동. 공격한 유닛에게 피해를 6 준다.","cost":3,"ability":"increase_reflect","target":"self","spell":"retaliate","abilities":[{"effect":"increase_reflect","cost":3,"target":"self","text":"반사 피해를 1 증가시킨다"}]}
	data.effect_handler = self
	return data
