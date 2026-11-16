class_name TCGGameModes
extends RefCounted

const DEFAULT_ID := "standard"
const FATE_ID := "fate"
const MODES := [
	{
		"id": DEFAULT_ID,
		"name": "기본 모드",
		"description": "운명 카드 없이 기존 유닛 전투 규칙으로 대전합니다.",
	},
	{
		"id": FATE_ID,
		"name": "운명 모드",
		"description": "유닛 덱과 운명 덱을 조합해 대전합니다.",
	},
]

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mode in MODES:
		result.append(mode)
	return result

static func normalize(mode_id: String) -> String:
	for mode in MODES:
		if str(mode.id) == mode_id:
			return mode_id
	return DEFAULT_ID

static func display_name(mode_id: String) -> String:
	var normalized := normalize(mode_id)
	for mode in MODES:
		if str(mode.id) == normalized:
			return str(mode.name)
	return "기본 모드"

static func description(mode_id: String) -> String:
	var normalized := normalize(mode_id)
	for mode in MODES:
		if str(mode.id) == normalized:
			return str(mode.description)
	return ""

static func uses_fates(mode_id: String) -> bool:
	return normalize(mode_id) == FATE_ID
