class_name TCGCards
extends RefCounted
static var cache: Dictionary = {}

const CARD_IDS := [
	"vanilla_ice", "potato", "healer", "assassin", "student", "viper", "tank", "vanilla_latte", "archer", "rock", "traveler", "mage", "bean", "cloak", "thorn", "vanilla_flower", "golem", "mana_dragon", "traitor", "dragon", "phoenix", "gambler",
]
const BANNED_CARD_IDS := ["gambler"]

static func all() -> Array:
	var cards: Array = []
	for id in CARD_IDS:
		cards.append(by_id(id))
	return cards

static func pool(tier: int) -> Array:
	return all().filter(func(c): return c.tier == tier and not is_banned(str(c.id)))

static func is_banned(id: String) -> bool:
	return id in BANNED_CARD_IDS

static func by_id(id: String) -> Dictionary:
	if id in ["token_guard", "token_six", "skipped"]:
		var handler = load("res://card_effects/card_effect.gd").new()
		return {"id": id, "name": {"token_guard": "악마의 수호자", "token_six": "악마의 하수인", "skipped": "건너뛴 단계"}[id], "tier": 6 if id != "skipped" else 4, "power": 6 if id == "token_six" else 0, "health": 6 if id == "token_six" else 1, "rules": "지속 - 아군 갬블의 악마는 피해를 받지 않는다." if id == "token_guard" else "", "spell_text": "", "ability": "", "cost": 0, "target": "", "spell": "", "effect_handler": handler}
	if id in CARD_IDS:
		if not cache.has(id):
			cache[id] = load("res://card_effects/%s.gd" % id).new().card_data()
		return cache[id].duplicate(true)
	return {}

static func spell_target(effect: String) -> String:
	if effect == "revive_later": return "dead_ally"
	if effect == "retaliate": return "enemy"
	if effect == "deploy_cloak": return "none"
	return "enemy" if effect in ["hit4", "full_hit"] else "unit"
