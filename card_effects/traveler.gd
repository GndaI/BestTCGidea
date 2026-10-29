extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"traveler","name":"시간여행자","tier":3,"power":3,"health":9,"rules":"출현 - 4단계를 건너뛴다. 다음 자신의 턴에 5단계 카드를 공개한다.","spell_text":"","cost":0,"ability":"","target":"","spell":""}
	data.effect_handler = self
	return data
