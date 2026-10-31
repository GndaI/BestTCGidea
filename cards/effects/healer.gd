extends "res://cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"healer","name":"치유사","tier":1,"power":1,"health":3,"rules":"소모 1 - 유닛을 2 회복한다.\n소모 2 - 유닛에게 생명력을 2 부여한다.","spell_text":"","cost":1,"ability":"heal2","target":"unit","spell":"","abilities":[{"effect":"heal2","cost":1,"target":"unit","text":"유닛을 2 회복한다"},{"effect":"grant_life2","cost":2,"target":"unit","text":"유닛에게 생명력을 2 부여한다"}]}
	data.effect_handler = self
	return data
