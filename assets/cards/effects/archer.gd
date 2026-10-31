extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"archer","name":"바람 궁수","tier":3,"power":2,"health":9,"rules":"소모 2 - 유닛에게 피해를 3 준다.\n소모 3 - 유닛 둘에게 피해를 2 준다.","spell_text":"","cost":2,"ability":"hit3","target":"unit","spell":"","abilities":[{"effect":"hit3","cost":2,"target":"unit","text":"유닛에게 피해를 3 준다"},{"effect":"hit2_two","cost":3,"target":"unit","targets":2,"text":"서로 다른 유닛 둘에게 피해를 2 준다"}]}
	data.effect_handler = self
	return data
