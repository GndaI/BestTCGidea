class_name TCGRandomAI
extends RefCounted

var rng := RandomNumberGenerator.new()
var last_turn := -1
var actions_this_turn := 0
const ACTION_LIMIT := 16

func _init() -> void:
	rng.randomize()

func random_deck() -> Array:
	var deck: Array = []
	for tier in range(1, 7):
		var pool := TCGCards.pool(tier)
		var first := rng.randi_range(0, pool.size() - 1)
		var second := (first + rng.randi_range(1, pool.size() - 1)) % pool.size()
		deck.append([pool[first].id, pool[second].id])
	return deck

# Only the acting player's hand/used cards and the public board are inspected.
# This list is also used by the UI to detect spells without a legal target.
static func spell_actions(b: TCGBattle, owner: int, index: int) -> Array:
	var result: Array = []
	if index < 0 or index >= b.players[owner].hand.size():
		return result
	var c: Dictionary = b.players[owner].hand[index]
	if c.spell.is_empty() or (b.phase == "reaction" and c.spell not in ["retaliate", "revive_later"]): return result
	var base := {"type": "spell", "owner": owner, "index": index}
	if c.spell == "copy":
		for p in [owner]:
			for slot in range(b.players[p].units.size()):
				var effect := b.copy_effect([p, slot])
				if effect != "":
					var action := base.duplicate(true)
					action.copied_unit = [p, slot]
					append_targets(result, b, action, effect, TCGCards.spell_target(effect))
	else:
		var kind := TCGCards.spell_target(c.spell)
		if kind == "none":
			var action := base.duplicate(true)
			action.target = []
			result.append(action)
		else:
			append_targets(result, b, base, c.spell, kind)
	return result

static func append_targets(result: Array, b: TCGBattle, base: Dictionary, effect: String, kind: String) -> void:
	var source: Array = [] if base.type == "spell" or base.get("use_spell_source", false) else [base.owner, base.index]
	for p in range(2):
		for slot in range(b.players[p].units.size()):
			var target := [p, slot]
			if b.valid_target(base.owner, source, target, kind, effect):
				var action := base.duplicate(true)
				action.target = target
				result.append(action)

static func legal_actions(b: TCGBattle, owner: int) -> Array:
	var result: Array = []
	if b.phase not in ["action", "reaction"] or b.priority != owner:
		return result
	for i in range(b.players[owner].units.size()):
		var u := b.get_unit([owner, i])
		if b.phase == "action" and owner == b.active and b.stack.is_empty() and u.alive and u.mana > 0:
			append_targets(result, b, {"type": "attack", "owner": owner, "index": i}, "damage", "enemy")
		if b.can_ability(owner, i):
			for option in b.ability_options(u.card):
				if u.mana < int(option.get("cost", 0)): continue
				var effect := str(option.get("effect", ""))
				var kind := str(option.get("target", ""))
				var base := {"type":"ability","owner":owner,"index":i,"effect":effect}
				if effect == "replay":
					for c in b.players[owner].used:
						if c.effect_handler.can_be_copied() and not str(c.spell).is_empty():
							var action := base.duplicate(true)
							action.copied_id = c.id
							action.use_spell_source = true
							append_targets(result, b, action, c.spell, TCGCards.spell_target(c.spell))
				elif kind == "none":
					var action := base.duplicate(true)
					action.target = []
					result.append(action)
				elif int(option.get("targets", 1)) == 2:
					var singles: Array = []
					append_targets(singles, b, base, effect, kind)
					for first in range(singles.size()):
						for second in range(first + 1, singles.size()):
							var action := base.duplicate(true)
							action.target = [singles[first].target, singles[second].target]
							result.append(action)
				else:
					append_targets(result, b, base, effect, kind)
	for i in range(b.players[owner].hand.size()):
		result.append_array(spell_actions(b, owner, i))
	return result

static func perform(b: TCGBattle, action: Dictionary) -> bool:
	match action.type:
		"attack": return b.attack(action.owner, action.index, action.target)
		"ability": return b.ability(action.owner, action.index, action.target, action.get("copied_id", ""), [], action.get("effect", ""))
		"spell": return b.cast_spell(action.owner, action.index, action.target, action.get("copied_unit", []))
	return false

func step(b: TCGBattle, owner: int = 1) -> bool:
	if b.phase == "over" or b.priority != owner:
		return false
	if last_turn != b.turn_index:
		last_turn = b.turn_index
		actions_this_turn = 0
	if b.phase == "growth":
		b.grow_potato(rng.randi_range(0, 1) == 1)
		return true
	if b.phase == "deploy":
		return b.deploy(rng.randi_range(0, 1))
	if b.phase == "choice":
		if int(b.choice.get("roll", 0)) == 4 and b.choice.get("stage", "") == "spell":
			var spells := b.roll_four_spell_choices()
			if spells.is_empty(): return false
			return b.choose_roll_spell(spells[rng.randi_range(0, spells.size() - 1)])
		var targets := b.choice_targets()
		if targets.is_empty(): return false
		return b.choose_roll_target(targets[rng.randi_range(0, targets.size() - 1)])
	if b.phase not in ["action", "reaction"]:
		return false
	var actions := legal_actions(b, owner)
	# A hard budget prevents endless mana-transfer cycles or repeated end responses.
	if not actions.is_empty() and actions_this_turn < ACTION_LIMIT and rng.randf() >= 0.22:
		var action: Dictionary = actions[rng.randi_range(0, actions.size() - 1)]
		if perform(b, action):
			actions_this_turn += 1
			return true
	if b.phase == "action" and b.active == owner and b.stack.is_empty():
		return b.request_end()
	b.note("P%d AI: 대응하지 않고 패스." % [owner + 1])
	b.pass_priority()
	return true
