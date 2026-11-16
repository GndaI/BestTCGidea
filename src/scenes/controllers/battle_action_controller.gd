extends "res://src/scenes/controllers/battle_screen_controller.gd"

func select_ability(owner: int, slot: int) -> void:
	var unit: Dictionary = battle.get_unit([owner, slot])
	if battle.phase != "action" or owner != battle.priority or unit.is_empty() or not unit.alive or is_ai_turn() or waiting_for_sync:
		return
	if online_mode and owner != local_player:
		return
	var c: Dictionary = unit.card
	var available: Array = battle.ability_options(c)
	if available.is_empty(): return
	selection = {"action":"ability","owner":owner,"index":slot,"mode":"ability_choice","options":available}

func choose_ability_option(option: Dictionary) -> void:
	selection.mode = "target"
	selection.kind = str(option.get("target", ""))
	selection.effect = str(option.get("effect", ""))
	selection.targets = int(option.get("targets", 1))
	selection.chosen_targets = []
	selection.erase("options")
	if selection.effect == "replay":
		selection.mode = "replay"
		selection.prompt = "아래에서 복사할 사용된 주문을 선택하세요."
	elif selection.kind == "none":
		submit_selected_ability([])
		return
	elif selection.kind == "self":
		submit_selected_ability([selection.owner, selection.index])
		return
	render()

func submit_selected_ability(target) -> void:
	var before := battle.priority
	var accepted := battle.submit_command(selection.owner, {"type":"activate_ability","index":selection.index,"target":target,"copied_id":str(selection.get("copied_id", "")),"copied_unit":selection.get("copied_unit", []),"effect":str(selection.get("effect", ""))})
	selection.clear()
	info = "" if accepted else "지금은 수행할 수 없는 행동입니다. 대상과 마나를 확인하세요."
	after_action(before)

func select_attack(owner: int, slot: int) -> void:
	if battle.phase != "action" or is_ai_turn() or waiting_for_sync or (online_mode and (owner != local_player or battle.priority != local_player)):
		return
	selection = {"action": "attack", "owner": owner, "index": slot, "mode": "target", "kind": "enemy", "effect": "attack"}
	render()

func select_spell(index: int) -> void:
	if battle.phase not in ["action", "reaction"] or is_ai_turn() or waiting_for_sync or (online_mode and battle.priority != local_player):
		return
	var owner := battle.priority
	if index < 0 or index >= battle.players[owner].hand.size() or TCGRandomAI.spell_actions(battle, owner, index).is_empty():
		return
	var c: Dictionary = battle.players[owner].hand[index]
	var spell_kind := TCGCards.spell_target(c.spell)
	if spell_kind == "none":
		var before := battle.priority
		var accepted := battle.submit_command(owner, {"type":"cast_spirit","index":index,"target":[]})
		info = "" if accepted else "지금은 이 영혼을 사용할 수 없습니다."
		if accepted: after_action(before)
		return
	selection = {"action": "spell", "owner": owner, "index": index, "mode": "target", "kind": spell_kind, "effect": c.spell}
	if c.spell == "copy":
		selection.mode = "copy"
		selection.prompt = "주문 효과를 빌릴 아군 유닛을 선택하세요. 수습생과 조건부 주문은 제외됩니다."
	render()

func select_fate(index: int) -> void:
	var owner := battle.active
	if battle.phase != "action" or battle.priority != owner or not battle.stack.is_empty() or waiting_for_sync or is_ai_turn(): return
	if online_mode and owner != local_player: return
	var hand: Array = battle.players[owner].get("fate_hand", [])
	if index < 0 or index >= hand.size(): return
	var fate := FateCatalog.by_id(str(hand[index]))
	if fate.is_empty(): return
	selection = {"action":"fate", "owner":owner, "index":index, "mode":"payer", "kind":"ally", "effect":str(fate.effect), "fate":fate}
	selection.prompt = "비용 %d을 전부 지불할 아군 유닛을 선택하세요." % int(fate.cost)
	render()

func select_replay(c: Dictionary) -> void:
	selection.copied_id = c.id
	selection.effect = c.spell
	selection.kind = TCGCards.spell_target(c.spell)
	selection.mode = "target"
	selection.erase("prompt")
	render()

func target_eligible(target: Array) -> bool:
	if selection.is_empty() or target.size() != 2:
		return false
	var mode := str(selection.get("mode", ""))
	var owner := int(selection.get("owner", -1))
	if owner not in [0, 1]: return false
	if mode == "copy":
		return target[0] == owner and battle.copy_effect(target) != ""
	if mode == "payer":
		var payer := battle.get_unit(target)
		return selection.action == "fate" and target[0] == owner and not payer.is_empty() and payer.alive and int(payer.mana) >= int(selection.fate.cost)
	if mode != "target": return false
	if target in selection.get("chosen_targets", []): return false
	var action := str(selection.get("action", ""))
	var index := int(selection.get("index", -1))
	if action not in ["attack", "ability", "spell", "fate"]: return false
	if action != "spell" and index < 0: return false
	var is_replayed_spell: bool = action == "ability" and not str(selection.get("copied_id", "")).is_empty()
	var source: Array = [] if action in ["spell", "fate"] or is_replayed_spell else [owner, index]
	return battle.valid_target(owner, source, target, str(selection.get("kind", "")), str(selection.get("effect", "")))

func choose_target(target: Array) -> void:
	var mode := str(selection.get("mode", ""))
	if mode == "payer":
		if not target_eligible(target):
			selection.clear()
			render()
			return
		selection.payer = target.duplicate()
		var fate: Dictionary = selection.fate
		var target_kind := str(fate.target)
		if target_kind == "payer":
			_submit_selected_fate(target)
			return
		if target_kind == "none":
			_submit_selected_fate([])
			return
		selection.mode = "target"
		selection.kind = target_kind
		selection.prompt = "운명의 대상을 선택하세요: " + str(fate.text)
		render()
		return
	if mode == "copy":
		selection.copied_unit = target
		selection.effect = battle.copy_effect(target)
		selection.kind = TCGCards.spell_target(selection.effect)
		selection.mode = "target"
		selection.prompt = "복사한 주문의 대상을 선택하세요: " + battle.get_unit(target).card.spell_text
		render()
		return
	if mode != "target" or not target_eligible(target):
		selection.clear()
		info = "대상 선택 상태가 끝나 공격을 취소했습니다."
		render()
		return
	if selection.action == "ability" and int(selection.get("targets", 1)) > 1:
		selection.chosen_targets.append(target.duplicate())
		if selection.chosen_targets.size() < int(selection.targets):
			selection.prompt = "대상을 %d개 더 선택하세요." % (int(selection.targets) - selection.chosen_targets.size())
			render()
			return
		submit_selected_ability(selection.chosen_targets.duplicate(true))
		return
	var before := battle.priority
	var accepted := false
	var command_type: String = str({"attack":"attack", "ability":"activate_ability", "spell":"cast_spirit", "fate":"activate_fate"}.get(selection.action, ""))
	if selection.action == "fate":
		accepted = battle.submit_command(selection.owner, {"type":"activate_fate", "index":selection.index, "payer":selection.payer, "target":target})
	else:
		accepted = battle.submit_command(selection.owner, {"type":command_type,"index":selection.index,"target":target,"copied_id":selection.get("copied_id", ""),"copied_unit":selection.get("copied_unit", []),"effect":selection.get("effect", "")})
	selection = {}
	info = "" if accepted else "지금은 수행할 수 없는 행동입니다. 대상과 마나를 확인하세요."
	after_action(before)

func _submit_selected_fate(target: Array) -> void:
	var before := battle.priority
	var accepted := battle.submit_command(selection.owner, {"type":"activate_fate", "index":selection.index, "payer":selection.payer, "target":target})
	selection.clear()
	info = "" if accepted else "운명을 사용할 수 없습니다. 지불 유닛과 대상을 확인하세요."
	after_action(before)

func choose_gamble(target: Array) -> void:
	var before := battle.priority
	battle.submit_command(battle.priority, {"type":"choose_roll_target","target":target})
	after_action(before)

func choose_gamble_spell(index: int) -> void:
	var before := battle.priority
	battle.submit_command(battle.priority, {"type":"choose_roll_spirit","index":index})
	after_action(before)

func pass_action() -> void:
	var before := battle.priority
	battle.submit_command(battle.priority, {"type":"pass"})
	after_action(before)

func end_action() -> void:
	var before := battle.priority
	battle.submit_command(battle.priority, {"type":"end_turn"})
	after_action(before)

func choose_growth(grow: bool) -> void:
	battle.submit_command(battle.active, {"type":"choose_turn_start","grow":grow})
	render()

func choose_deploy(choice: int) -> void:
	battle.submit_command(battle.active, {"type":"deploy","choice":choice})
	render()

func after_action(before: int) -> void:
	if not battle.stack.is_empty() and str(battle.stack.back().get("title", "")).ends_with("기본 공격"):
		sound_fx.play_cue("attack")
	covered = not online_mode and privacy and not ai_enabled and before != battle.priority and battle.phase != "over"
	render()

func confirm_restart() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "새 게임"
	dialog.dialog_text = "현재 대전을 마치고 게임 모드 선택으로 돌아갈까요?"
	dialog.confirmed.connect(restart_game)
	add_child(dialog)
	dialog.popup_centered()
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func restart_game() -> void:
	ai_timer.stop()
	if online_mode:
		stop_network()
		return
	drafting = true
	start_screen = true
	start_page = "home"
	draft_player = 0
	covered = false
	selection.clear()
	info = ""
	reset_decks()
	render()

