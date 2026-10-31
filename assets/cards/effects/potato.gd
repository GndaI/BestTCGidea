extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"potato","name":"최강의 감자","tier":1,"power":1,"health":3,"rules":"지속 - 자신의 턴 시작에, 마나를 얻는 대신 자신의 생산력을 1 높일 수 있다.\n소모 9 - 자신의 생산력을 2배로 한다.\n주마등 - 자신의 생산력만큼 다른 무작위 아군 유닛에게 마나를 더한다.","spell_text":"","cost":9,"ability":"double_production","target":"self","spell":"","abilities":[{"effect":"double_production","cost":9,"target":"self","text":"생산력을 2배로 한다"}]}
	data.effect_handler = self
	return data
