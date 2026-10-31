extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"tank","name":"탱커","tier":2,"power":2,"health":5,"rules":"소모 1 - 유닛에게 보호막을 2 부여한다.\n소모 3 - 다른 아군 유닛은 이번 턴에 기본 공격으로 피해를 받지 않는다.","spell_text":"유닛에게 보호막을 3 부여한다.","cost":1,"ability":"shield2","target":"unit","spell":"shield3","abilities":[{"effect":"shield2","cost":1,"target":"unit","text":"유닛에게 보호막을 2 부여한다"},{"effect":"guard_allies","cost":3,"target":"none","text":"다른 아군이 이번 턴 기본 공격 피해를 받지 않는다"}]}
	data.effect_handler = self
	return data
