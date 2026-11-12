class_name TCGFates
extends RefCounted

const ORDER := [
	"growth", "insight", "flame", "recharge", "guard", "mending", "destruction",
]

const DATA := {
	"growth": {"id":"growth", "name":"성장", "cost":3, "target":"ally", "effect":"grant_stats1", "text":"아군 유닛 하나에게 생산력 1과 생명력 1을 부여한다."},
	"insight": {"id":"insight", "name":"통찰", "cost":3, "target":"none", "effect":"draw_fate2", "text":"운명을 2장 뽑는다."},
	"flame": {"id":"flame", "name":"화염", "cost":3, "target":"unit", "effect":"damage4", "text":"유닛 하나에게 피해를 4 준다."},
	"recharge": {"id":"recharge", "name":"재충전", "cost":0, "target":"ally", "effect":"mana1", "text":"아군 유닛 하나의 마나를 1 회복한다."},
	"guard": {"id":"guard", "name":"방어", "cost":0, "target":"ally", "effect":"shield2", "text":"아군 유닛 하나에게 방어막을 2 부여한다."},
	"mending": {"id":"mending", "name":"자가 치유", "cost":1, "target":"payer", "effect":"heal3", "text":"비용을 지불한 유닛을 3 회복한다."},
	"destruction": {"id":"destruction", "name":"파괴", "cost":4, "target":"unit", "effect":"damage6", "text":"유닛 하나에게 피해를 6 준다."},
}

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id_value in ORDER:
		result.append(by_id(id_value))
	return result

static func by_id(id_value: String) -> Dictionary:
	if not DATA.has(id_value):
		return {}
	return (DATA[id_value] as Dictionary).duplicate(true)

static func is_valid_id(id_value: String) -> bool:
	return DATA.has(id_value)
