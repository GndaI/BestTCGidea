extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"viper","name":"예민한 독사","tier":2,"power":1,"health":5,"rules":"지속 - 상대 턴의 종료에, 이 유닛의 생명력이 최대라면, 마나를 3 얻는다.\n소모 7 - 3턴 이하의 상대 유닛을 처치한다.","spell_text":"대상에게 ‘이 카드의 생명력이 최대인 동안, 생산력을 1 얻는다.’를 부여한다.","cost":7,"ability":"execute_low_tier","target":"enemy","spell":"full_bonus","abilities":[{"effect":"execute_low_tier","cost":7,"target":"enemy","text":"3턴 이하의 상대 유닛을 처치한다"}]}
	data.effect_handler = self
	return data
