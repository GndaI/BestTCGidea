extends "res://card_effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"traitor","name":"적당한 배신자","tier":5,"power":3,"health":15,"rules":"소모 5 - 살아 있는 상대 5단계 유닛과 소유권을 교환한다. 남은 마나와 상태 유지. (턴당 1회)","spell_text":"","cost":5,"ability":"swap","target":"enemy","spell":""}
	data.effect_handler = self
	return data
