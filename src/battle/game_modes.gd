class_name TCGGameModes
extends RefCounted

const DEFAULT_ID := "standard"
const MODES := [
	{
		"id": DEFAULT_ID,
		"name": "기본 모드",
		"description": "지금까지 만든 규칙으로 대전합니다.",
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
