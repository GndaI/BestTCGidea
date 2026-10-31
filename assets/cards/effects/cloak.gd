extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"cloak","name":"보호의 망토","tier":4,"power":3,"health":3,"rules":"지속 - 모든 유닛이 받는 피해가 1 감소한다.\n소모 3 - 이 카드를 주문 상태로 패에 넣는다.","spell_text":"4단계에 이 카드를 배치한다.","cost":3,"ability":"cloak_to_hand","target":"none","spell":"deploy_cloak","abilities":[{"effect":"cloak_to_hand","cost":3,"target":"none","text":"이 카드를 주문 상태로 패에 넣는다"}]}
	data.effect_handler = self
	return data
