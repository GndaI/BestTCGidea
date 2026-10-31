extends "res://cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"bean","name":"최강의 콩나무","tier":4,"power":2,"health":12,"rules":"지속 - 자신의 턴 시작에 마나를 얻는 대신 얻을 마나만큼 생산력을 높일 수 있다.","spell_text":"대상의 생산력을 2 올린다.","cost":0,"ability":"","target":"","spell":"power2"}
	data.effect_handler = self
	return data
