extends "res://cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"phoenix","name":"불사조","tier":6,"power":9,"health":5,"rules":"출현 - 죽는다.\n소모 3 - 유닛의 생명력을 2 가져온다.\n주마등 - 다음 턴 생산 시기 종료에, 자신은 부활한다.","spell_text":"아군 유닛이 죽었을 때 발동. 그 유닛은 2턴 뒤의 생산 시기 종료에 부활한다.","cost":3,"ability":"steal_life2","target":"other_unit","spell":"revive_later","abilities":[{"effect":"steal_life2","cost":3,"target":"other_unit","text":"유닛의 생명력을 2 가져온다"}]}
	data.effect_handler = self
	return data
