extends "res://src/scenes/controllers/deck_screen_controller.gd"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not drag_source.is_empty():
		cancel_drag()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_targeting()
		get_viewport().set_input_as_handled()
		return
	if playing_effects:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if is_instance_valid(action_button) and action_button.visible and not drafting and not covered and selection.is_empty() and drag_source.is_empty():
			_on_primary_action_pressed()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not drag_source.is_empty(): cancel_drag()
		elif not selection.is_empty(): cancel_selection()
		elif action_menu_open:
			action_menu_open = false
			render()
		elif info_screen_active:
			back_from_info_screen()
		elif drafting and start_screen and start_page != "home":
			go_back_from_start_page()
		elif drafting and not start_screen:
			restart_game()
		elif not drafting and not waiting_for_sync and not is_ai_turn() and battle.phase == "action" and (not online_mode or battle.priority == local_player):
			action_menu_open = true
			render()
		get_viewport().set_input_as_handled()
		return
	if drag_source.is_empty(): return
	if event is InputEventMouseMotion:
		drag_moved = drag_moved or event.position.distance_to(drag_origin) > 7
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_drag()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			finish_drag(event.position)
			get_viewport().set_input_as_handled()

func begin_drag(source: Array, point: Vector2) -> bool:
	var u := battle.get_unit(source)
	if playing_effects or drafting or covered or is_ai_turn() or waiting_for_sync or not selection.is_empty(): return false
	if online_mode and source[0] != local_player: return false
	if u.is_empty() or not u.alive: return false
	var gamble_targeting := battle.phase == "choice" and int(battle.choice.get("roll", 0)) == 5 and source == battle.locate(int(battle.choice.get("uid", -1)))
	if gamble_targeting:
		drag_source = source.duplicate()
		drag_origin = point
		drag_moved = false
		auto_timer.stop()
		hide_card_preview()
		return true
	if battle.phase != "action": return false
	var can_attack: bool = u.mana > 0 and source[0] == battle.priority and source[0] == battle.active and battle.stack.is_empty()
	var can_open_ability_menu: bool = source[0] == battle.priority and not battle.ability_options(u.card).is_empty()
	if not can_attack and not can_open_ability_menu: return false
	drag_source = source.duplicate()
	drag_origin = point
	drag_moved = false
	auto_timer.stop()
	hide_card_preview()
	return true

func target_at(point: Vector2) -> Array:
	if not get_viewport_rect().has_point(point): return []
	for key in unit_views:
		var view: TCGCardView = unit_views[key]
		if is_instance_valid(view) and view.get_global_rect().has_point(point):
			var parts: PackedStringArray = key.split(":")
			return [int(parts[0]), int(parts[1])]
	return []

func finish_drag(point: Vector2) -> void:
	var source := drag_source.duplicate()
	var target := target_at(point)
	var moved := drag_moved
	drag_source.clear()
	drag_moved = false
	var gamble_targeting := battle.phase == "choice" and int(battle.choice.get("roll", 0)) == 5 and source == battle.locate(int(battle.choice.get("uid", -1)))
	if gamble_targeting:
		if moved and target in battle.choice_targets():
			choose_gamble(target)
		else:
			render()
		return
	if not moved and source.size() == 2 and source[0] == battle.priority and not battle.ability_options(battle.get_unit(source).card).is_empty():
		select_ability(source[0], source[1])
		render()
		return
	if moved and not source.is_empty() and not target.is_empty():
		if online_mode:
			# A drag attack already has both endpoints. Send it directly instead of
			# creating a partial target-selection Dictionary with no `mode` field.
			selection.clear()
			_send_online_intent({"type": "attack", "owner": source[0], "index": source[1], "target": target.duplicate()})
			return
		var before := battle.priority
		if battle.attack(source[0], source[1], target):
			after_action(before)
			return
	render()

func cancel_drag() -> void:
	drag_source.clear()
	drag_moved = false
	render()

func cancel_targeting() -> void:
	var had_targeting := not drag_source.is_empty() or not selection.is_empty()
	drag_source.clear()
	drag_moved = false
	selection.clear()
	action_menu_open = false
	info = ""
	if had_targeting: render()

func cancel_selection() -> void:
	selection.clear()
	action_menu_open = false
	info = ""
	render()

func anchor_for(source: Array, owner: int = 0) -> Vector2:
	var bounds := get_viewport_rect().size
	if source.size() == 2:
		var view: TCGCardView = unit_views.get("%d:%d" % [source[0], source[1]])
		if is_instance_valid(view):
			var center := view.get_global_rect().get_center()
			return Vector2(clampf(center.x, 20, bounds.x - 20), clampf(center.y, 70, bounds.y - 25))
	return Vector2(bounds.x - 210, 105 if owner == 1 else bounds.y - 70)

func arrow_for(action: Dictionary, title: String = "") -> Dictionary:
	var effect: String = action.get("effect", action.get("kind", "damage"))
	var color := Color("ff816d") if effect == "damage" or effect.begins_with("hit") or effect == "full_hit" else GREEN
	var arrow_title := title if title != "" else str(action.get("title", ""))
	var start := anchor_for(action.get("source", []), action.get("owner", 0))
	var is_basic_attack := str(action.get("title", "")).ends_with("기본 공격")
	# A basic-attack arrow starts at the actual unit; effect chains start at their side card.
	if not is_basic_attack:
		for link in chain_action_links:
			if int(link.owner) == int(action.get("owner", -1)) and str(link.title) == str(action.get("title", "")):
				var spell_view: TCGCardView = link.view
				if is_instance_valid(spell_view) and spell_view.is_visible_in_tree():
					start = spell_view.get_global_rect().get_center()
					break
	if is_basic_attack:
		arrow_title += " · 피해 %d" % int(action.get("amount", 0))
	return {"start": start, "end": anchor_for(action.target), "color": color, "title": arrow_title}

func _chain_target_key(target: Array) -> String:
	return "%d:%d" % [int(target[0]), int(target[1])] if target.size() == 2 else ""

func _chain_final_previews() -> Dictionary:
	var states: Dictionary = {}
	for action in battle.stack:
		var target: Array = action.get("target", [])
		var target_uid := int(action.get("target_uid", -1))
		if target_uid >= 0:
			target = battle.locate(target_uid)
		var key := _chain_target_key(target)
		if key.is_empty() or states.has(key):
			continue
		var unit: Dictionary = battle.get_unit(target)
		if unit.is_empty():
			continue
		states[key] = {
			"target": target.duplicate(),
			"unit": unit,
			"hp": int(unit.hp),
			"initial_hp": int(unit.hp),
			"max_hp": int(unit.get("max_hp", unit.card.health)),
			"shield": int(unit.get("shield", 0)),
			"initial_shield": int(unit.get("shield", 0)),
			"mana": int(unit.get("mana", 0)),
			"initial_mana": int(unit.get("mana", 0)),
			"alive": bool(unit.get("alive", true)),
		}
	for action_index in range(battle.stack.size() - 1, -1, -1):
		var action: Dictionary = battle.stack[action_index]
		var target: Array = action.get("target", [])
		var target_uid := int(action.get("target_uid", -1))
		if target_uid >= 0:
			target = battle.locate(target_uid)
		var key := _chain_target_key(target)
		if key.is_empty() or not states.has(key):
			continue
		var state: Dictionary = states[key]
		if not state.alive:
			continue
		var effect := str(action.get("effect", ""))
		var amount := int(action.get("amount", 0))
		if effect == "retaliate":
			effect = "hit6"
		if effect == "full_hit" and int(state.hp) != int(state.max_hp):
			continue
		if effect.begins_with("hit"):
			amount = int(effect.substr(3))
		elif effect == "full_hit":
			amount = 2
		if effect == "damage" or effect.begins_with("hit") or effect == "full_hit":
			var unit: Dictionary = state.unit
			var damage := maxi(0, amount)
			var handler = unit.card.get("effect_handler", null)
			if handler != null:
				damage = int(handler.modify_incoming_damage(damage))
			var absorbed := mini(int(state.shield), damage)
			state.shield = int(state.shield) - absorbed
			damage -= absorbed
			if unit.card.id == "gambler" and battle.players[target[0]].units.any(func(ally): return ally.alive and ally.card.id == "token_guard"):
				damage = 0
			state.hp = maxi(0, int(state.hp) - damage)
			if int(state.hp) <= 0:
				state.alive = false
		elif effect.begins_with("heal"):
			amount = 1 if effect == "heal" else int(effect.substr(4))
			state.hp = mini(int(state.max_hp), int(state.hp) + maxi(0, amount))
		elif effect.begins_with("shield"):
			amount = 1 if effect == "shield" else int(effect.substr(6))
			state.shield = int(state.shield) + amount
		elif effect.begins_with("mana"):
			amount = int(effect.substr(4))
			state.mana = int(state.mana) + amount
	var previews: Dictionary = {}
	for key in states:
		var state: Dictionary = states[key]
		var hp_delta := int(state.hp) - int(state.initial_hp)
		var shield_delta := int(state.shield) - int(state.initial_shield)
		var mana_delta := int(state.mana) - int(state.initial_mana)
		if hp_delta < 0:
			previews[key] = {"text": str(hp_delta), "color": Color("ff626b")}
		elif hp_delta > 0:
			previews[key] = {"text": "+%d" % hp_delta, "color": Color("73e6a1")}
		elif shield_delta != 0:
			previews[key] = {"text": "방어막 %s%d" % ["+" if shield_delta > 0 else "", shield_delta], "color": Color("69b7ff")}
		elif mana_delta != 0:
			previews[key] = {"text": "마나 %s%d" % ["+" if mana_delta > 0 else "", mana_delta], "color": Color("6fcfff")}
	return previews

func _process(delta: float) -> void:
	_update_hover_preview()
	if is_instance_valid(used_archive_popup) and is_instance_valid(used_archive_badge):
		var pointer := get_global_mouse_position()
		if not used_archive_badge.get_global_rect().has_point(pointer) and not used_archive_popup.get_global_rect().has_point(pointer):
			hide_used_spells_popup()
	if is_instance_valid(battle_log_popup) and is_instance_valid(battle_log_badge):
		var log_pointer := get_global_mouse_position()
		if not battle_log_badge.get_global_rect().has_point(log_pointer) and not battle_log_popup.get_global_rect().has_point(log_pointer):
			hide_battle_log_popup()
	if not is_instance_valid(arrow_layer): return
	var arrows: Array = []
	if not drafting and not covered:
		if not drag_source.is_empty():
			var point := get_global_mouse_position()
			for lane in field_scrolls.values():
				var bounds: Rect2 = lane.get_global_rect()
				if point.y >= bounds.position.y and point.y <= bounds.end.y:
					if point.x < bounds.position.x + 45: lane.scroll_horizontal -= int(650 * delta)
					elif point.x > bounds.end.x - 45: lane.scroll_horizontal += int(650 * delta)
			var target := target_at(point)
			var source_unit := battle.get_unit(drag_source)
			var gamble_targeting := battle.phase == "choice" and int(battle.choice.get("roll", 0)) == 5 and drag_source == battle.locate(int(battle.choice.get("uid", -1)))
			var can_attack: bool = not source_unit.is_empty() and source_unit.mana > 0 and drag_source[0] == battle.priority and battle.priority == battle.active and battle.stack.is_empty()
			var legal := target in battle.choice_targets() if gamble_targeting else (battle.valid_target(drag_source[0], drag_source, target, "enemy", "damage") if can_attack else false)
			var drag_title := "갬블의 악마 · 피해 6 대상을 선택" if gamble_targeting else ("기본 공격 · 피해 %d" % int(source_unit.get("mana", 0)) if can_attack else "짧게 눌러 효과 선택 · 우클릭 취소")
			arrows.append({"start": anchor_for(drag_source), "end": point, "color": Color("ff816d") if legal else GOLD, "title": drag_title if legal or not can_attack else "적 카드 위에 놓으세요 · 우클릭 취소"})
		elif not resolving_event.is_empty():
			arrows.append(arrow_for(resolving_event))
		elif not selection.is_empty() and selection.get("mode", "") in ["target", "copy"]:
			var replay_target: bool = selection.action == "ability" and not str(selection.get("copied_id", "")).is_empty()
			var source: Array = [] if selection.action == "spell" or replay_target else [selection.owner, selection.index]
			var start := anchor_for(source, selection.owner)
			if selection.action == "spell" and spell_views.has(selection.index):
				start = spell_views[selection.index].get_global_rect().get_center()
			elif replay_target and is_instance_valid(selection.get("pending_replay_view", null)):
				start = selection.pending_replay_view.get_global_rect().get_center()
			var selection_title := "대상을 선택하세요 · 우클릭 취소"
			if selection.action == "attack":
				selection_title = "기본 공격 · 피해 %d · 우클릭 취소" % int(battle.get_unit([selection.owner, selection.index]).get("mana", 0))
			arrows.append({"start": start, "end": get_global_mouse_position(), "color": GOLD, "title": selection_title})
		elif not battle.stack.is_empty():
			var previews := _chain_final_previews()
			var last_arrow_for_target: Dictionary = {}
			for i in range(battle.stack.size()):
				var preview_target: Array = battle.stack[i].get("target", [])
				var preview_uid := int(battle.stack[i].get("target_uid", -1))
				if preview_uid >= 0:
					preview_target = battle.locate(preview_uid)
				last_arrow_for_target[_chain_target_key(preview_target)] = i
			for i in range(battle.stack.size()):
				var action: Dictionary = battle.stack[i]
				var arrow := arrow_for(action, "%d · P%d %s" % [i + 1, action.owner + 1, action.title])
				var target: Array = action.get("target", [])
				var target_uid := int(action.get("target_uid", -1))
				if target_uid >= 0:
					target = battle.locate(target_uid)
				var key := _chain_target_key(target)
				if last_arrow_for_target.get(key, -1) == i and previews.has(key):
					arrow["impact_text"] = previews[key].text
					arrow["impact_color"] = previews[key].color
				arrows.append(arrow)
	arrow_layer.arrows = arrows
	arrow_layer.queue_redraw()

func _update_hover_preview(point: Vector2 = Vector2.INF) -> void:
	if covered or playing_effects or not drag_source.is_empty():
		if is_instance_valid(hover_source): hide_card_preview()
		return
	# Start-screen deck-editor cards are not part of the battle/draft view arrays.
	# Their mouse-entered/exited signals own the same floating preview directly.
	if start_screen and start_page == "deck_editor":
		return
	if point == Vector2.INF: point = get_global_mouse_position()
	var hovered: TCGCardView
	if drafting:
		for view in draft_card_views + deck_card_views:
			if is_instance_valid(view) and view.is_visible_in_tree() and view.get_global_rect().has_point(point) and board_scroll.get_global_rect().has_point(point):
				hovered = view
				break
		if hovered != hover_source:
			if is_instance_valid(hover_source): hide_card_preview()
			if is_instance_valid(hovered): show_card_preview(hovered)
		return
	var board_preview_allowed := not overlay_layer.visible or board_view_visible
	if not board_preview_allowed:
		# A modal blocks the board: only cards inside the modal can produce previews.
		for view in overlay_card_views:
			if is_instance_valid(view) and view.is_visible_in_tree() and view.get_global_rect().has_point(point):
				hovered = view
				break
	else:
		# Check spells first because their row can overlap the top edge of the field.
		for view_variant in spell_views.values():
			var view: TCGCardView = view_variant
			if is_instance_valid(view) and view.is_visible_in_tree() and view.get_global_rect().has_point(point):
				hovered = view
				break
		if not is_instance_valid(hovered):
			for view in chain_card_views:
				if is_instance_valid(view) and view.is_visible_in_tree() and view.get_global_rect().has_point(point):
					hovered = view
					break
		if not is_instance_valid(hovered):
			for view in used_spell_views:
				if is_instance_valid(view) and view.is_visible_in_tree() and view.get_global_rect().has_point(point):
					hovered = view
					break
	if board_preview_allowed and not is_instance_valid(hovered):
		for view_variant in unit_views.values():
			var view: TCGCardView = view_variant
			if is_instance_valid(view) and view.is_visible_in_tree() and view.get_global_rect().has_point(point):
				hovered = view
				break
	if hovered == hover_source:
		return
	if is_instance_valid(hover_source): hide_card_preview()
	if is_instance_valid(hovered): show_card_preview(hovered)

func _create_battle_log_badge() -> void:
	battle_log_badge = PanelContainer.new()
	battle_log_badge.name = "BattleLogBadge"
	battle_log_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	battle_log_badge.offset_left = -222
	battle_log_badge.offset_right = -18
	battle_log_badge.offset_top = -55
	battle_log_badge.offset_bottom = -15
	battle_log_badge.z_index = 8
	var book_style := box(Color("241b35"), Color("b594e8"))
	book_style.shadow_color = Color(0.48, 0.28, 0.72, 0.42)
	book_style.shadow_size = 8
	battle_log_badge.add_theme_stylebox_override("panel", book_style)
	add_child(battle_log_badge)
	battle_log_label = label_at(battle_log_badge, "✦ 전투 기록", 13, Color("e3c9ff"))
	battle_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_log_badge.mouse_entered.connect(show_battle_log_popup)
	battle_log_badge.hide()

func _update_battle_log_badge() -> void:
	if is_instance_valid(battle_log_label):
		battle_log_label.text = "✦ 전투 기록 · %d" % battle.history.size()

func show_battle_log_popup() -> void:
	hide_battle_log_popup()
	var panel := PanelContainer.new()
	panel.name = "BattleLogPopup"
	panel.size = Vector2(470, 330)
	panel.custom_minimum_size = panel.size
	panel.z_index = 2
	var spellbook_style := box(Color("171124"), Color("c7a4f4"))
	spellbook_style.set_border_width_all(2)
	spellbook_style.shadow_color = Color(0.42, 0.22, 0.68, 0.52)
	spellbook_style.shadow_size = 13
	panel.add_theme_stylebox_override("panel", spellbook_style)
	hover_layer.add_child(panel)
	battle_log_popup = panel
	var viewport_size := get_viewport_rect().size
	panel.global_position = Vector2(viewport_size.x - panel.size.x - 18, viewport_size.y - panel.size.y - 62)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title := label_at(column, "✦  전투의 마법서  ✦", 18, Color("ead7ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := HSeparator.new()
	column.add_child(rule)
	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(log_scroll)
	var history_text := RichTextLabel.new()
	history_text.bbcode_enabled = true
	history_text.fit_content = true
	history_text.scroll_active = false
	history_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_text.add_theme_font_size_override("normal_font_size", 13)
	history_text.add_theme_color_override("default_color", Color("d7cae8"))
	var lines: Array[String] = []
	var first := maxi(0, battle.history.size() - 50)
	for index in range(first, battle.history.size()):
		var color := "#f2d28c" if "──" in battle.history[index] else ("#ff9d91" if "피해" in battle.history[index] or "재기불능" in battle.history[index] else "#d7cae8")
		lines.append("[color=%s]%s[/color]" % [color, battle.history[index]])
	history_text.text = "\n".join(lines) if not lines.is_empty() else "아직 기록된 행동이 없습니다."
	log_scroll.add_child(history_text)
	log_scroll.set_deferred("scroll_vertical", 100000)

func hide_battle_log_popup() -> void:
	if is_instance_valid(battle_log_popup): battle_log_popup.queue_free()
	battle_log_popup = null

func _drain_online_snapshots() -> void:
	if not playing_effects and not pending_online_snapshots.is_empty():
		_rpc_receive_online_state(pending_online_snapshots.pop_front())

func can_auto_pass() -> bool:
	return auto_pass and not action_menu_open and drag_source.is_empty() and not playing_effects and not drafting and not covered and not waiting_for_sync and not is_ai_turn() and (not online_mode or battle.priority == local_player) and battle.phase in ["action", "reaction"] and selection.is_empty() and TCGRandomAI.legal_actions(battle, battle.priority).is_empty()

func play_combat_effects() -> void:
	playing_effects = true
	ai_timer.stop()
	auto_timer.stop()
	hide_card_preview()
	overlay_layer.hide()
	effect_blocker.show()
	var events := battle.visual_events.duplicate(true)
	battle.visual_events.clear()
	while not events.is_empty():
		var event: Dictionary = events.pop_front()
		sound_fx.play_cue(str(event.get("kind", "")))
		if event.kind == "turn_start":
			_rebuild_effect_board()
			await get_tree().process_frame
			await _show_turn_banner(event)
			continue
		if event.kind == "field_destroy":
			await get_tree().process_frame
			var break_effects: Array[TCGGambleFX] = []
			for board_slot in range(TCGBattle.NORMAL_BOARD_SLOTS):
				var holder: Control = field_slot_holders.get("%d:%d" % [event.owner, board_slot])
				if not is_instance_valid(holder): continue
				var slot_fx := TCGGambleFX.new()
				slot_fx.kind = "slot_break"
				slot_fx.size = holder.size
				slot_fx.z_index = 8
				holder.add_child(slot_fx)
				break_effects.append(slot_fx)
				holder.pivot_offset = holder.size * 0.5
				var crack_shake := create_tween()
				for angle in [0.018, -0.024, 0.016, -0.012, 0.0]:
					crack_shake.tween_property(holder, "rotation", angle, 0.1)
				crack_shake.tween_property(holder, "modulate:a", 0.08, 0.55).set_delay(0.15)
			await get_tree().create_timer(1.3).timeout
			for slot_fx in break_effects:
				if is_instance_valid(slot_fx): slot_fx.queue_free()
			_rebuild_effect_board()
			continue
		if event.kind in ["arrival", "summon", "unit_arrival"]:
			_rebuild_effect_board()
			for pending in [event] + events:
				if pending.kind in ["arrival", "summon", "unit_arrival"]:
					var hidden: TCGCardView = unit_views.get("%d:%d" % [pending.target[0], pending.target[1]])
					if is_instance_valid(hidden): hidden.modulate.a = 0.0
		var view: TCGCardView = _event_target_view(event)
		if event.kind == "roulette":
			if is_instance_valid(view): await _ensure_effect_visible(view, event.owner)
			var roulette := TCGGambleFX.new()
			roulette.result = event.amount
			roulette.player_index = event.owner
			roulette.size = Vector2(530, 350)
			var bounds := get_viewport_rect().size
			var center := view.get_global_rect().get_center() if is_instance_valid(view) else bounds * 0.5
			roulette.position = Vector2((bounds.x - roulette.size.x) * 0.5, clampf(center.y - roulette.size.y * 0.5, 12, bounds.y - roulette.size.y - 12))
			effect_blocker.add_child(roulette)
			await get_tree().create_timer(roulette.duration).timeout
			roulette.queue_free()
			if not online_mode or online_host:
				battle.complete_roll()
				_broadcast_online_state()
				events.append_array(battle.visual_events.duplicate(true))
				battle.visual_events.clear()
			continue
		if not is_instance_valid(view): continue
		await _ensure_effect_visible(view, event.target[0])
		if event.kind in ["summon", "unit_arrival"]:
			await _show_unit_arrival(view, event)
			continue
		if event.kind in ["arrival", "summon"]:
			var portal := TCGGambleFX.new()
			portal.kind = event.kind
			portal.size = view.size
			view.add_child(portal)
			view.pivot_offset = view.size * 0.5
			var rest_scale := view.scale
			view.scale = rest_scale * 0.65
			view.modulate.a = 0.15
			var appear := create_tween().set_parallel(true)
			appear.tween_property(view, "scale", rest_scale, portal.duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			appear.tween_property(view, "modulate:a", 1.0, portal.duration * 0.65)
			await get_tree().create_timer(portal.duration).timeout
			view.scale = rest_scale
			view.modulate.a = 1.0
			portal.queue_free()
			continue
		resolving_event = event
		view.update_health(event.hp)
		var fx := TCGCombatFX.new()
		fx.kind = event.kind
		fx.amount = event.amount
		fx.lethal = event.kind == "damage" and event.hp == 0
		fx.size = view.size
		view.add_child(fx)
		if event.kind == "damage" and event.amount > 0:
			view.pivot_offset = view.size * 0.5
			var shake := create_tween()
			for angle in [0.045, -0.04, 0.025, -0.015, 0.0]:
				shake.tween_property(view, "rotation", angle, 0.055)
		await get_tree().create_timer(fx.duration).timeout
		if is_instance_valid(view): view.rotation = 0
		if is_instance_valid(fx): fx.queue_free()
	effect_blocker.hide()
	resolving_event = {}
	playing_effects = false
	if not pending_online_snapshots.is_empty():
		_drain_online_snapshots()
	else:
		render()

func _event_target_view(event: Dictionary) -> TCGCardView:
	var event_target: Array = event.get("target", [])
	if event_target.size() != 2: return null
	return unit_views.get("%d:%d" % [event_target[0], event_target[1]])

func _show_unit_arrival(destination: TCGCardView, event: Dictionary) -> void:
	var unit := battle.get_unit(event.target)
	if unit.is_empty():
		destination.modulate.a = 1.0
		return
	var floating := TCGCardView.new()
	floating.name = "UnitArrivalCard"
	floating.configure(unit.card, battle.production(unit), unit.hp, unit.mana)
	floating.shield = int(unit.get("shield", 0))
	floating.size = Vector2(172, 241)
	floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating.z_index = 4
	effect_blocker.add_child(floating)
	await get_tree().process_frame
	floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating.pivot_offset = floating.size * 0.5
	var screen_center := effect_blocker.get_global_rect().get_center()
	floating.global_position = screen_center - floating.size * 0.5 - Vector2(0, 42)
	floating.scale = Vector2.ONE * 0.82
	floating.modulate.a = 0.0
	var appear := create_tween().set_parallel(true)
	appear.tween_property(floating, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(floating, "modulate:a", 1.0, 0.14)
	await appear.finished
	await get_tree().create_timer(0.32).timeout
	var destination_rect := destination.get_global_rect()
	var target_scale_value := minf(destination_rect.size.x / floating.size.x, destination_rect.size.y / floating.size.y)
	var target_scale := Vector2.ONE * target_scale_value
	var target_position := destination_rect.get_center() - floating.size * 0.5
	var approach := create_tween().set_parallel(true)
	approach.tween_property(floating, "global_position", target_position - Vector2(0, 48), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	approach.tween_property(floating, "scale", target_scale, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await approach.finished
	var land := create_tween().set_parallel(true)
	land.tween_property(floating, "global_position", target_position, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(floating, "modulate:a", 0.15, 0.16)
	land.tween_property(destination, "modulate:a", 1.0, 0.12)
	await land.finished
	destination.modulate.a = 1.0
	floating.queue_free()

func _show_turn_banner(event: Dictionary) -> void:
	var glow_color: Color = GOLD if int(event.owner) == 0 else BLUE
	var banner := PanelContainer.new()
	banner.name = "TurnBanner"
	banner.custom_minimum_size = Vector2(560, 150)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.offset_left = -280
	banner.offset_right = 280
	banner.offset_top = -75
	banner.offset_bottom = 75
	var banner_style := box(Color(0.035, 0.065, 0.12, 0.97), glow_color)
	banner_style.set_border_width_all(3)
	banner_style.shadow_color = Color(glow_color, 0.6)
	banner_style.shadow_size = 18
	banner.add_theme_stylebox_override("panel", banner_style)
	effect_blocker.add_child(banner)
	var text_column := VBoxContainer.new()
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(text_column)
	var turn_label := label_at(text_column, "행동 턴 %d" % int(event.amount), 25, MUTED)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var player_label := label_at(text_column, "P%d의 차례" % [int(event.owner) + 1], 38, glow_color)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var own_turn_label := label_at(text_column, "P%d의 %d번째 턴" % [int(event.owner) + 1, int(event.hp)], 17, Color("dce8f8"))
	own_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2.ONE * 0.82
	banner.modulate.a = 0.0
	var appear := create_tween().set_parallel(true)
	appear.tween_property(banner, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(banner, "modulate:a", 1.0, 0.18)
	await get_tree().create_timer(0.95).timeout
	var leave := create_tween().set_parallel(true)
	leave.tween_property(banner, "scale", Vector2.ONE * 1.06, 0.22)
	leave.tween_property(banner, "modulate:a", 0.0, 0.22)
	await leave.finished
	banner.queue_free()

func _rebuild_effect_board() -> void:
	_save_field_scrolls()
	unit_views.clear()
	spell_views.clear()
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	render_battle()
	overlay_layer.hide()
	action_button.hide()

func _ensure_effect_visible(view: Control, owner: int) -> void:
	await get_tree().process_frame
	var lane: ScrollContainer = field_scrolls.get(owner)
	if is_instance_valid(lane) and lane.is_ancestor_of(view):
		lane.ensure_control_visible(view)
	board_scroll.ensure_control_visible(view)
	await get_tree().process_frame

func auto_step() -> void:
	if not can_auto_pass():
		return
	var before := battle.priority
	battle.note("P%d: 가능한 행동이 없어 자동 넘김." % [before + 1])
	if battle.phase == "action" and battle.priority == battle.active and battle.stack.is_empty():
		end_action()
	else:
		pass_action()

func add_card(parent: Node, c: Dictionary, power: int = -1, hp: int = -1, mana: int = -1, spell: bool = false, face_down: bool = false, caption: String = "미공개", highlight: bool = false, shield: int = 0, draft_selected: bool = false) -> TCGCardView:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var view := TCGCardView.new()
	view.configure(c, power, hp, mana, spell)
	view.face_down = face_down
	view.caption = caption
	view.highlighted = highlight
	view.shield = shield
	view.draft_selected = draft_selected
	# Deck-editor tooltips are assigned only by the editor; battle cards use the large preview below.
	view.tooltip_text = ""
	center.add_child(view)
	view.mouse_entered.connect(func(): show_card_preview(view))
	view.mouse_exited.connect(func(): if hover_source == view: hide_card_preview())
	return view

func show_card_preview(source: TCGCardView) -> void:
	if playing_effects or not drag_source.is_empty():
		return
	var deck_editor_preview := start_screen and start_page == "deck_editor"
	if overlay_layer.visible and not board_view_visible and not overlay_layer.is_ancestor_of(source) and not deck_editor_preview:
		return
	hide_card_preview()
	if source.face_down and source.card.is_empty():
		return
	hover_source = source
	# Deck-editor cards now use the same floating preview treatment as field cards.
	var editor_preview := false
	hover_card = TCGCardView.new()
	# Preview the printed card values, matching the card picker, not in-play changes.
	hover_card.configure(source.card, -1, -1, -1, source.spell_face)
	var PREVIEW_WIDTH := 260.0 if source.card.id == "gambler" else (300.0 if editor_preview else 330.0)
	var PREVIEW_HEIGHT := PREVIEW_WIDTH * 1.4
	hover_card.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	hover_card.size = Vector2(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	hover_card.z_index = 80
	hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_layer.add_child(hover_card)
	var rect := source.get_global_rect()
	var limit := get_viewport_rect().size
	var x := rect.end.x + 14.0
	if x + PREVIEW_WIDTH > limit.x: x = rect.position.x - PREVIEW_WIDTH - 14.0
	var effect_width := minf(700.0 if source.card.id == "gambler" else (650.0 if editor_preview else 560.0), limit.x - 16.0)
	var effect_height := 350.0 if source.card.id == "gambler" else (300.0 if editor_preview else 260.0)
	var card_y_max := maxf(8.0, limit.y - PREVIEW_HEIGHT - effect_height - 18.0)
	hover_card.position = Vector2(clampf(x, 8, maxf(8.0, limit.x - PREVIEW_WIDTH - 8.0)), clampf(rect.position.y - 60, 8, card_y_max))
	hover_spell = PanelContainer.new()
	hover_spell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_spell.z_index = 80
	var effect_style := box(Color("0b1424") if editor_preview else PANEL, GOLD)
	if editor_preview:
		effect_style.set_border_width_all(3)
		effect_style.shadow_color = Color(0, 0, 0, 0.9)
		effect_style.shadow_size = 18
	hover_spell.add_theme_stylebox_override("panel", effect_style)
	var effect_x := clampf(hover_card.position.x - (effect_width - PREVIEW_WIDTH) / 2.0, 8, maxf(8.0, limit.x - effect_width - 8.0))
	var effect_y := minf(hover_card.position.y + PREVIEW_HEIGHT + 10.0, limit.y - effect_height - 8.0)
	hover_spell.position = Vector2(effect_x, effect_y)
	hover_spell.size = Vector2(effect_width, effect_height)
	hover_spell.custom_minimum_size = Vector2(effect_width, effect_height)
	hover_layer.add_child(hover_spell)
	var effect_margin := MarginContainer.new()
	effect_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_margin.add_theme_constant_override("margin_left", 26 if editor_preview else 18)
	effect_margin.add_theme_constant_override("margin_right", 26 if editor_preview else 18)
	effect_margin.add_theme_constant_override("margin_top", 20 if editor_preview else 14)
	effect_margin.add_theme_constant_override("margin_bottom", 20 if editor_preview else 14)
	hover_spell.add_child(effect_margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 16 if editor_preview else 10)
	effect_margin.add_child(col)
	var title := label_at(col, "카드 효과 · " + source.card.name, 30 if editor_preview else 24, GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emphasize_label(title, 0.65)
	var effect_lines: Array[String] = []
	if source.spell_face:
		if not source.card.spell_text.is_empty(): effect_lines.append(source.card.spell_text)
	else:
		if not source.card.rules.is_empty(): effect_lines.append("능력 · " + source.card.rules)
		if not source.card.spell_text.is_empty(): effect_lines.append("주문 · " + source.card.spell_text)
	var description
	var description_text := "\n".join(effect_lines) if not effect_lines.is_empty() else "효과 없음"
	if source.card.id == "gambler":
		var rich_description := RichTextLabel.new()
		rich_description.bbcode_enabled = true
		rich_description.text = description_text.replace("6", "[color=#ff5364]6[/color]")
		rich_description.fit_content = true
		rich_description.scroll_active = false
		rich_description.add_theme_font_size_override("normal_font_size", 25 if editor_preview else 18)
		rich_description.add_theme_color_override("default_color", Color("f3f6fc") if editor_preview else MUTED)
		rich_description.add_theme_constant_override("line_separation", 8 if editor_preview else 3)
		rich_description.add_theme_constant_override("outline_size", 2 if editor_preview else 0)
		rich_description.add_theme_color_override("font_outline_color", Color("070d17"))
		col.add_child(rich_description)
		description = rich_description
	else:
		description = label_at(col, description_text, BODY_FONT_SIZE if editor_preview else 20, Color("f3f6fc") if editor_preview else MUTED)
		if editor_preview:
			emphasize_label(description, 0.35)
			description.add_theme_constant_override("line_spacing", 8)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func hide_card_preview() -> void:
	if is_instance_valid(hover_backdrop):
		hover_backdrop.hide()
		hover_backdrop.queue_free()
	hover_backdrop = null
	if is_instance_valid(hover_spell):
		hover_spell.hide()
		hover_spell.queue_free()
	hover_spell = null
	if is_instance_valid(hover_card):
		hover_card.hide()
		hover_card.queue_free()
	hover_card = null
	hover_source = null

