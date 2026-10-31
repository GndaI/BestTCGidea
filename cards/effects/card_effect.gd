extends RefCounted
class_name TCGCardEffect

func card_data() -> Dictionary:
	return {}

func has_income_choice() -> bool:
	return false

func production_bonus(_unit: Dictionary) -> int:
	return 0

func limited_to_once_per_turn() -> bool:
	return false

func resolve_income_choice(_battle: TCGBattle, _unit: Dictionary, _grow: bool) -> void:
	pass

func modify_incoming_damage(amount: int) -> int:
	return amount

func on_ally_defeated(_battle: TCGBattle, _owner: int, _unit: Dictionary, _defeated: Dictionary) -> void:
	pass

func on_turn_end(_battle: TCGBattle, _unit: Dictionary) -> void:
	pass

func on_deploy(_battle: TCGBattle, _owner: int, _paired_spell: Dictionary) -> bool:
	return false

func can_be_copied() -> bool:
	return true

# Override this in a card file when it needs behavior beyond the shared primitives.
func resolve(battle: TCGBattle, action: Dictionary) -> void:
	battle.apply_standard_effect(action)
