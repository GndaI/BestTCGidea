extends "res://cards/effects/rulebook_effect.gd"

func card_data() -> Dictionary:
	var data: Dictionary = {"id":"gambler","name":"갬블의 악마","tier":6,"power":0,"health":16,"rules":"출현 - 다른 아군을 모두 처치하고 특별 소환 칸을 연다.\n자신 턴 종료에 룰렛을 굴린다.\n1: 악마를 보호하는 0/1 하수인 6 소환.\n2: 6/6 둘 소환.\n3: 양쪽의 처치된 유닛 중 한 종류를 골라 자신의 필드에 부활.\n4: 상대의 사용된 주문 하나를 골라 적용.\n5: 대상 피해 6, 자신의 현재/최대 생명력 +6.\n6: 다음 자신의 턴부터 룰렛 횟수 +1.","spell_text":"주문 효과 없음.","cost":0,"ability":"","target":"","spell":""}
	data.effect_handler = self
	return data

func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
