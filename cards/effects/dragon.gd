extends "res://cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"dragon","name":"종말의 용","tier":6,"power":4,"health":15,"rules":"지속 - 상대 유닛이 죽으면, 양옆의 유닛에게 피해를 1 준다.\n소모 3 - 대상에게 피해를 6 준다.\n소모 10 - 다음 자신 턴까지 이 유닛이 살아있다면, 다른 모든 유닛을 처치한다.","spell_text":"대상에게 피해를 6 준다.","cost":3,"ability":"hit6","target":"unit","spell":"hit6","abilities":[{"effect":"hit6","cost":3,"target":"unit","text":"대상에게 피해를 6 준다"},{"effect":"arm_apocalypse","cost":10,"target":"none","text":"다음 자신 턴까지 살아있다면 다른 모든 유닛을 처치한다"}]}
	data.effect_handler = self
	return data
