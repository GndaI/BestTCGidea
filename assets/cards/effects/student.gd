extends "res://assets/cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"student","name":"성실한 수습생","tier":2,"power":2,"health":5,"rules":"출현 - 짝 주문을 패 대신 사용됨 상태로 둔다.\n소모 2 - 사용된 자신의 주문 하나의 효과를 적용한다. 조건부 주문 제외. (턴당 1회)","spell_text":"수습생 이외의 아군 유닛의 주문 효과를 적용한다. 조건부 주문은 복사할 수 없다.","cost":2,"ability":"replay","target":"","spell":"copy"}
	data.effect_handler = self
	return data
