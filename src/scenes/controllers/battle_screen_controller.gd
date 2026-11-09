extends "res://src/scenes/controllers/battle_input_effects_controller.gd"

const AbilityChoiceCardScene = preload("res://src/ui/components/ability_choice_card.tscn")
var battle_refresh_host: VBoxContainer

func render_battle() -> void:
	_render_in_screen(BattleScreenScene, _render_battle_content)

func _render_battle_content() -> void:
	battle_refresh_host = VBoxContainer.new()
	battle_refresh_host.name = "BattleRefreshHost"
	battle_refresh_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_refresh_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_refresh_host.add_theme_constant_override("separation", 5)
	root.add_child(battle_refresh_host)
	refresh_battle_screen()

func refresh_battle_screen() -> bool:
	if not is_instance_valid(battle_refresh_host): return false
	for child in battle_refresh_host.get_children():
		battle_refresh_host.remove_child(child)
		child.queue_free()
	var screen_root := root
	root = battle_refresh_host
	_populate_battle_content()
	root = screen_root
	return true

func _populate_battle_content() -> void:
	if battle.phase == "reaction":
		label_at(root, "피해/처치 직후 · 조건부 주문을 사용하거나 패스하세요.", 17, GOLD)
	render_turn_status()
	render_chain_spells()
	var field_center := VBoxContainer.new()
	field_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(field_center)
	var field_centerer := CenterContainer.new()
	field_centerer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_centerer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_center.add_child(field_centerer)
	var vertical_balance := MarginContainer.new()
	vertical_balance.add_theme_constant_override("margin_top", 78)
	field_centerer.add_child(vertical_balance)
	var field_rows := VBoxContainer.new()
	field_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_rows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field_rows.add_theme_constant_override("separation", 5)
	vertical_balance.add_child(field_rows)
	var viewer := local_player if online_mode else 0
	for owner in [1 - viewer, viewer]:
		battle.normalize_board_slots(owner)
		var is_turn_owner: bool = battle.phase != "over" and owner == battle.active
		var player_color: Color = GOLD if owner == 0 else BLUE
		var player_zone := PanelContainer.new()
		player_zone.name = "PlayerZone%d" % owner
		player_zone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var zone_style := StyleBoxFlat.new()
		zone_style.bg_color = Color(player_color, 0.055 if is_turn_owner else 0.012)
		zone_style.set_corner_radius_all(12)
		zone_style.set_content_margin_all(0)
		zone_style.set_border_width_all(2 if is_turn_owner else 0)
		zone_style.border_color = Color(player_color, 0.72)
		if is_turn_owner:
			zone_style.shadow_color = Color(player_color, 0.42)
			zone_style.shadow_size = 14
		player_zone.add_theme_stylebox_override("panel", zone_style)
		field_rows.add_child(player_zone)
		var zone_rows := VBoxContainer.new()
		zone_rows.add_theme_constant_override("separation", 0)
		player_zone.add_child(zone_rows)
		if owner != viewer: render_gambler_dock(zone_rows, owner)
		var field_panel := PanelContainer.new()
		field_panel.name = "FieldPanel%d" % owner
		field_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var special: bool = battle.players[owner].get("special", false)
		var field_style := box(Color("2b1c49") if special and is_turn_owner else (Color("23183d") if special else (Color("172b45") if is_turn_owner else Color("111d31"))), player_color if is_turn_owner else (Color("b58aff") if special else Color("355174")))
		if is_turn_owner:
			field_style.set_border_width_all(3)
			field_style.shadow_color = Color(player_color, 0.48)
			field_style.shadow_size = 10
		field_panel.add_theme_stylebox_override("panel", field_style)
		zone_rows.add_child(field_panel)
		field_panels[owner] = field_panel
		var lane := ScrollContainer.new()
		lane.name = "FieldLane%d" % owner
		lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		lane.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		field_panel.add_child(lane)
		field_scrolls[owner] = lane
		var board_units := _board_slot_map(owner)
		var left_edge := 0
		var right_edge := (TCGBattle.BASE_BOARD_SLOTS - 1) if special else (TCGBattle.NORMAL_BOARD_SLOTS - 1)
		for board_slot in board_units:
			right_edge = maxi(right_edge, int(board_slot))
		var board_grid := GridContainer.new()
		board_grid.columns = TCGBattle.BASE_BOARD_SLOTS if special else TCGBattle.NORMAL_BOARD_SLOTS
		board_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		board_grid.add_theme_constant_override("h_separation", 0)
		board_grid.add_theme_constant_override("v_separation", 4)
		var board_center := CenterContainer.new()
		board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lane.add_child(board_center)
		board_center.add_child(board_grid)
		var row_count := ceili(float(right_edge + 1) / float(board_grid.columns))
		var available_width := get_viewport_rect().size.x - 184.0
		var slot_width := minf(200.0 + FIELD_CARD_GAP, available_width / float(board_grid.columns))
		var card_width := slot_width - FIELD_CARD_GAP
		var grid_width := slot_width * float(board_grid.columns)
		board_center.custom_minimum_size.x = grid_width
		field_panel.custom_minimum_size.x = grid_width + 24.0
		var slot_height := card_width * FIELD_CARD_ASPECT * FIELD_CARD_SCALE + (18.0 if special else 2.0)
		lane.custom_minimum_size = Vector2(0, slot_height * row_count)
		for board_slot in range(left_edge, right_edge + 1):
			var continues_row := board_slot < right_edge and posmod(board_slot + 1, board_grid.columns) != 0
			var card_holder := _make_board_slot_holder(board_grid, owner, board_slot, special, continues_row, slot_width)
			if board_units.has(board_slot):
				render_unit(card_holder, owner, int(board_units[board_slot]))
				_resize_field_card(unit_views["%d:%d" % [owner, int(board_units[board_slot])]], slot_width, special)
			else:
				var empty := _render_empty_board_slot(card_holder, board_slot)
				_resize_field_card(empty, slot_width, special)
		lane.set_deferred("scroll_horizontal", 0)
		if special and _has_selectable_defeated_units(owner):
			render_defeated_target_picker(zone_rows, owner)
		if owner == viewer: render_gambler_dock(zone_rows, owner)
	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "BattleBottomBar"
	bottom_bar.custom_minimum_size.y = HAND_AREA_HEIGHT
	bottom_bar.add_theme_constant_override("separation", 6)
	root.add_child(bottom_bar)
	render_hand(bottom_bar)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer)
	_update_action_button()
	_render_battle_overlay()

func render_turn_status() -> void:
	if battle.phase == "over": return
	var top_bar := HBoxContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_theme_constant_override("separation", 6)
	root.add_child(top_bar)
	var left_balance := Control.new()
	left_balance.custom_minimum_size.x = 210
	left_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(left_balance)
	var status := PanelContainer.new()
	status.custom_minimum_size = Vector2(430, 38)
	var player_color: Color = GOLD if battle.active == 0 else BLUE
	var status_style := box(Color("132238"), player_color)
	status_style.shadow_color = Color(player_color, 0.28)
	status_style.shadow_size = 6
	status.add_theme_stylebox_override("panel", status_style)
	top_bar.add_child(status)
	var status_label := label_at(status, "행동 턴 %d · P%d의 차례 · P%d의 %d번째 턴" % [battle.turn_index + 1, battle.active + 1, battle.active + 1, battle.players[battle.active].own_turn], 15, player_color)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	render_used_spell_badge(top_bar)

func _board_slot_map(owner: int) -> Dictionary:
	var result := {}
	for unit_index in range(battle.players[owner].units.size()):
		var unit: Dictionary = battle.get_unit([owner, unit_index])
		if unit.is_empty() or unit.card.id in ["gambler", "skipped"]: continue
		var board_slot := int(unit.get("board_slot", TCGBattle.BOARD_UNSET))
		if board_slot in [TCGBattle.BOARD_UNSET, TCGBattle.BOARD_DOCK]: continue
		result[board_slot] = unit_index
	return result

func _render_empty_board_slot(parent: Node, board_slot: int) -> TCGCardView:
	var caption := "%d턴" % [board_slot + 1] if board_slot in range(TCGBattle.BASE_BOARD_SLOTS) else ""
	var empty := add_card(parent, {}, -1, -1, -1, false, true, caption)
	empty.modulate = Color(0.84, 0.76, 1.0, 0.72) if board_slot not in range(TCGBattle.BASE_BOARD_SLOTS) else Color(1, 1, 1, 0.82)
	return empty

func _make_board_slot_holder(parent: Container, owner: int, board_slot: int, special: bool, has_next: bool, slot_width: float) -> CenterContainer:
	var shell := Control.new()
	var card_width := slot_width - FIELD_CARD_GAP
	var card_height := card_width * FIELD_CARD_ASPECT
	var scale_margin := card_height * (FIELD_CARD_SCALE - 1.0)
	shell.custom_minimum_size = Vector2(slot_width, card_height * FIELD_CARD_SCALE + (18.0 if special else 2.0))
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shell)
	var offsets := [9.0, 1.0, 13.0, 4.0, 16.0, 2.0, 11.0, 0.0, 14.0, 5.0, 12.0, 2.0]
	var normalized := posmod(board_slot, offsets.size())
	var y_offset: float = offsets[normalized] if special else 0.0
	if has_next:
		var next_normalized := posmod(board_slot + 1, offsets.size())
		var next_offset: float = offsets[next_normalized] if special else 0.0
		var connector := Line2D.new()
		connector.width = 8.0 if special else 4.0
		connector.default_color = Color("9465cc") if special else Color("355174")
		connector.points = PackedVector2Array([Vector2(slot_width * 0.5, y_offset + card_height * 0.5), Vector2(slot_width * 1.5, next_offset + card_height * 0.5)])
		connector.z_index = 0
		shell.add_child(connector)
		if special:
			var glow := Line2D.new()
			glow.width = 2.0
			glow.default_color = Color("ebc7ff")
			glow.points = connector.points
			glow.z_index = 0
			shell.add_child(glow)
	var holder := CenterContainer.new()
	holder.position = Vector2(FIELD_CARD_GAP * 0.5, y_offset + scale_margin * 0.5)
	holder.size = Vector2(card_width, card_height)
	holder.z_index = 1
	shell.add_child(holder)
	field_slot_holders["%d:%d" % [owner, board_slot]] = shell
	return holder

func _resize_field_card(view: TCGCardView, slot_width: float, special: bool) -> void:
	var card_width := slot_width - FIELD_CARD_GAP
	view.custom_minimum_size = Vector2(card_width, card_width * FIELD_CARD_ASPECT)
	view.visual_scale = FIELD_CARD_SCALE
	view.fit_content()
	view.queue_redraw()

func render_gambler_dock(parent: Node, owner: int) -> void:
	for slot in range(battle.players[owner].units.size()):
		var u := battle.get_unit([owner, slot])
		if u.card.id != "gambler": continue
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(center)
		var dock := VBoxContainer.new()
		dock.name = "GamblerDock%d" % owner
		dock.alignment = BoxContainer.ALIGNMENT_CENTER
		center.add_child(dock)
		var title := label_at(dock, "P%d · 갬블의 악마 · 주사위 %d개" % [owner + 1, u.get("dice", 1)], 12, Color("c6a0ff"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		render_unit(dock, owner, slot)
		var view: TCGCardView = unit_views["%d:%d" % [owner, slot]]
		view.custom_minimum_size = Vector2(124, 174)
		view.visual_scale = 1.0
		view.fit_content()
		view.queue_redraw()
		gambler_docks[owner] = dock

func _has_selectable_defeated_units(owner: int) -> bool:
	if selection.is_empty(): return false
	for slot in range(battle.players[owner].units.size()):
		var unit := battle.get_unit([owner, slot])
		if not unit.is_empty() and not unit.alive and int(unit.get("board_slot", TCGBattle.BOARD_UNSET)) == TCGBattle.BOARD_DOCK and target_eligible([owner, slot]):
			return true
	return false

func render_defeated_target_picker(parent: Node, owner: int) -> void:
	var defeated: Array[int] = []
	for slot in range(battle.players[owner].units.size()):
		var unit := battle.get_unit([owner, slot])
		if not unit.is_empty() and not unit.alive and unit.card.id not in ["skipped", "gambler"] and int(unit.get("board_slot", TCGBattle.BOARD_UNSET)) == TCGBattle.BOARD_DOCK:
			defeated.append(slot)
	if defeated.is_empty(): return
	var panel := PanelContainer.new()
	panel.name = "DefeatedTargetPicker%d" % owner
	panel.add_theme_stylebox_override("panel", box(Color("101827"), Color("5b6880")))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	label_at(column, "P%d · 부활할 재기불능 유닛 선택" % [owner + 1], 11, MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	for slot in defeated:
		var target := [owner, slot]
		var unit := battle.get_unit(target)
		var eligible := target_eligible(target)
		var corpse := add_card(row, unit.card, -1, -1, -1, false, true, "부활 대기" if unit.get("revive_at", -1) >= 0 else "재기불능", eligible)
		corpse.custom_minimum_size = Vector2(46, 64)
		unit_views["%d:%d" % [owner, slot]] = corpse
		corpse.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and target_eligible(target):
				choose_target(target)
		)

func render_chain_spells() -> void:
	clear_chain_spells()
	var chain_entries: Array[Dictionary] = []
	for chain_index in range(battle.stack.size()):
		var action: Dictionary = battle.stack[chain_index]
		var chain_card := _chain_display_card(action)
		if not chain_card.is_empty():
			chain_entries.append({"action": action, "number": chain_index + 1, "card": chain_card, "pending": false})
	var pending_card: Dictionary = {}
	var pending_owner := -1
	if selection.get("mode", "") == "target" and selection.action == "ability" and not str(selection.get("copied_id", "")).is_empty():
		pending_owner = int(selection.owner)
		for card in battle.players[pending_owner].used:
			if card.id == selection.copied_id and card.effect_handler.can_be_copied():
				pending_card = card
				break
	if not pending_card.is_empty():
		chain_entries.append({"action": {"owner": pending_owner, "title": pending_card.name + " 주문"}, "number": battle.stack.size() + 1, "card": pending_card, "pending": true})
	if chain_entries.is_empty():
		last_chain_signature = ""
		return
	var previous_count := chain_entries.size() - 1
	if previous_count > 0:
		var previous_title := label_at(chain_left_lane, "이전 체인", 18, Color("d9c9ef"))
		previous_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var previous_start := maxi(0, previous_count - 3)
		if previous_start > 0:
			var more_label := label_at(chain_left_lane, "+%d개" % previous_start, 16, MUTED)
			more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for entry_index in range(previous_start, previous_count):
			var previous_entry: Dictionary = chain_entries[entry_index]
			add_chain_card(chain_left_lane, previous_entry.card, previous_entry.action, false, int(previous_entry.number))
	var current_entry: Dictionary = chain_entries.back()
	var focus_view := add_chain_focus_card(chain_right_lane, current_entry.card, current_entry.action, bool(current_entry.pending), int(current_entry.number))
	if bool(current_entry.pending):
		selection.pending_replay_view = focus_view
	_show_chain_center(int(current_entry.number))
	if not battle.stack.is_empty():
		var signature_parts: Array[String] = []
		for action in battle.stack: signature_parts.append("%d:%s" % [int(action.owner), str(action.title)])
		var signature := "|".join(signature_parts)
		if signature != last_chain_signature:
			sound_fx.play_cue("chain")
			last_chain_signature = signature
	if is_instance_valid(chain_fade_tween):
		chain_fade_tween.kill()
	chain_layer.modulate = Color.WHITE
	chain_layer.show()
	chain_fade_tween = create_tween()
	chain_fade_tween.tween_interval(1.0)
	chain_fade_tween.tween_property(chain_layer, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	chain_fade_tween.tween_callback(func(): if is_instance_valid(chain_layer): chain_layer.hide())

func clear_chain_spells() -> void:
	if is_instance_valid(chain_fade_tween):
		chain_fade_tween.kill()
	chain_fade_tween = null
	for lane in [chain_left_lane, chain_right_lane]:
		if not is_instance_valid(lane): continue
		for child in lane.get_children():
			lane.remove_child(child)
			child.queue_free()
	chain_card_views.clear()
	chain_action_links.clear()
	if is_instance_valid(chain_center_badge): chain_center_badge.queue_free()
	chain_center_badge = null
	if is_instance_valid(chain_layer):
		chain_layer.modulate = Color.WHITE
		chain_layer.hide()

func _chain_display_card(action: Dictionary) -> Dictionary:
	var display_card: Dictionary = action.get("chain_card", {})
	if display_card.is_empty(): display_card = action.get("spell", {})
	if display_card.is_empty():
		var source: Array = action.get("source", [])
		var source_unit := battle.get_unit(source)
		if not source_unit.is_empty(): display_card = source_unit.card
	return display_card

func add_chain_card(parent: Node, spell: Dictionary, action: Dictionary, pending: bool = false, chain_number: int = 0) -> TCGCardView:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box(Color(0.05, 0.08, 0.15, 0.94), Color("f1ca7b") if int(action.owner) == 0 else BLUE))
	parent.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	frame.add_child(column)
	var number_label := label_at(column, "CHAIN %d%s" % [chain_number, " · 선택 중" if pending else ""], 15, GOLD if int(action.owner) == 0 else BLUE)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var view := TCGCardView.new()
	var spell_face: bool = pending or not action.get("chain_card", {}).is_empty() or not action.get("spell", {}).is_empty()
	view.configure(spell, -1, -1, -1, spell_face)
	view.custom_minimum_size = Vector2(76, 106)
	view.size = Vector2(76, 106)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.mouse_entered.connect(func(): show_card_preview(view))
	view.mouse_exited.connect(func(): if hover_source == view: hide_card_preview())
	column.add_child(view)
	chain_card_views.append(view)
	if not pending:
		chain_action_links.append({"owner": action.owner, "title": action.title, "view": view})
	return view

func add_chain_focus_card(parent: Node, spell: Dictionary, action: Dictionary, pending: bool = false, chain_number: int = 0) -> TCGCardView:
	var owner_color := GOLD if int(action.owner) == 0 else BLUE
	var focus_frame := PanelContainer.new()
	focus_frame.custom_minimum_size.x = 570
	focus_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var focus_style := box(Color(0.025, 0.045, 0.085, 0.98), owner_color)
	focus_style.set_border_width_all(4)
	focus_style.shadow_color = Color(owner_color, 0.62)
	focus_style.shadow_size = 24
	focus_frame.add_theme_stylebox_override("panel", focus_style)
	parent.add_child(focus_frame)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	focus_frame.add_child(column)
	var state_text := " · 대상 선택 중" if pending else " · 현재 발동"
	var number_label := label_at(column, "CHAIN %d%s" % [chain_number, state_text], 31, owner_color)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card_center := CenterContainer.new()
	card_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(card_center)
	var view := TCGCardView.new()
	var spell_face: bool = pending or not action.get("chain_card", {}).is_empty() or not action.get("spell", {}).is_empty()
	view.configure(spell, -1, -1, -1, spell_face)
	view.custom_minimum_size = Vector2(220, 308)
	view.size = Vector2(220, 308)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_center.add_child(view)
	var description_panel := PanelContainer.new()
	description_panel.custom_minimum_size = Vector2(520, 94)
	description_panel.add_theme_stylebox_override("panel", box(Color("08111f"), owner_color.darkened(0.2)))
	column.add_child(description_panel)
	var description_column := VBoxContainer.new()
	description_column.add_theme_constant_override("separation", 6)
	description_panel.add_child(description_column)
	var title := label_at(description_column, str(action.get("title", spell.get("name", "체인 효과"))), 25, owner_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var effect_lines: Array[String] = []
	if spell_face and not str(spell.get("spell_text", "")).is_empty():
		effect_lines.append(str(spell.spell_text))
	elif not str(spell.get("rules", "")).is_empty():
		effect_lines.append(str(spell.rules))
	if effect_lines.is_empty() and int(action.get("amount", 0)) > 0:
		effect_lines.append("대상에게 피해 %d" % int(action.amount))
	if effect_lines.is_empty():
		effect_lines.append(str(action.get("title", "효과 처리")))
	var effect_label := label_at(description_column, "\n".join(effect_lines), 21, Color("f4f7fc"))
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not pending:
		chain_action_links.append({"owner": action.owner, "title": action.title, "view": view})
	focus_frame.pivot_offset = Vector2(285, 250)
	focus_frame.scale = Vector2.ONE * 0.82
	var appear := create_tween()
	appear.tween_property(focus_frame, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return view

func _show_chain_center(chain_count: int) -> void:
	chain_center_badge = PanelContainer.new()
	chain_center_badge.anchor_left = 0.5
	chain_center_badge.anchor_right = 0.5
	chain_center_badge.offset_left = -150
	chain_center_badge.offset_right = 150
	chain_center_badge.offset_top = 20
	chain_center_badge.offset_bottom = 108
	chain_center_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chain_center_badge.z_index = 3
	var center_style := box(Color(0.055, 0.04, 0.12, 0.96), Color("e0c0ff"))
	center_style.set_border_width_all(2)
	center_style.shadow_color = Color(0.55, 0.35, 0.85, 0.55)
	center_style.shadow_size = 16
	chain_center_badge.add_theme_stylebox_override("panel", center_style)
	chain_layer.add_child(chain_center_badge)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	chain_center_badge.add_child(column)
	var chain_label := label_at(column, "CHAIN %d" % chain_count, 35, Color("f2d58e"))
	chain_label.custom_minimum_size = Vector2(260, 44)
	chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chain_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var order_label := label_at(column, "마지막 효과부터 역순으로 해결", 14, Color("d9c9ef"))
	order_label.custom_minimum_size = Vector2(260, 22)
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	chain_center_badge.pivot_offset = Vector2(150, 44)
	chain_center_badge.scale = Vector2.ONE * 0.78
	var appear := create_tween()
	appear.tween_property(chain_center_badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_action_button() -> void:
	var has_priority := not online_mode or battle.priority == local_player
	action_button.visible = battle.phase in ["action", "reaction"] and has_priority and not waiting_for_sync and not is_ai_turn() and selection.is_empty()
	if not action_button.visible: return
	var response_priority := battle.phase == "reaction" or battle.ending or not battle.stack.is_empty()
	if response_priority:
		var bright := box(Color("74501c"), Color("fff0a6"))
		bright.set_border_width_all(3)
		bright.shadow_color = Color(1.0, 0.72, 0.2, 0.72)
		bright.shadow_size = 16
		action_button.add_theme_stylebox_override("normal", bright)
		action_button.add_theme_stylebox_override("hover", box(Color("916624"), Color.WHITE))
		action_button.add_theme_color_override("font_color", Color("fff7d6"))
	else:
		action_button.remove_theme_stylebox_override("normal")
		action_button.remove_theme_stylebox_override("hover")
		action_button.remove_theme_color_override("font_color")
	if battle.phase == "reaction":
		action_button.text = "지금 내 대응 차례 · 조건부 주문 패스 (Enter)"
	elif battle.ending:
		action_button.text = "지금 내 대응 차례 · 종료 승인 (Enter)"
	elif battle.priority == battle.active and battle.stack.is_empty():
		action_button.text = "턴 종료 (Enter)"
	else:
		action_button.text = "지금 내 대응 차례 · 패스 / 대응 안 함 (Enter)"

func _on_primary_action_pressed() -> void:
	if battle.phase == "reaction" or battle.ending:
		pass_action()
	elif battle.priority == battle.active and battle.stack.is_empty():
		end_action()
	else:
		pass_action()

func _build_overlay(title: String, allow_board_view: bool = true) -> VBoxContainer:
	for child in overlay_body.get_children():
		overlay_body.remove_child(child)
		child.queue_free()
	overlay_card_views.clear()
	overlay_layer.show()
	overlay_panel.show()
	board_view_button.visible = allow_board_view
	overlay_title.text = title
	board_view_visible = false
	_set_board_view_visible(false)
	return overlay_body

func _toggle_board_view() -> void:
	board_view_visible = not board_view_visible
	_set_board_view_visible(board_view_visible)

func _set_board_view_visible(show_board: bool) -> void:
	if not is_instance_valid(overlay_panel): return
	overlay_body.visible = not show_board
	overlay_title.visible = not show_board
	overlay_panel.custom_minimum_size = Vector2.ZERO if show_board else Vector2(480, 160)
	if show_board:
		overlay_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		overlay_panel.add_theme_stylebox_override("panel", box(PANEL, GOLD))
	overlay_shade.color = Color(0.015, 0.025, 0.045, 0.0 if show_board else 0.78)
	board_view_button.text = "보드 숨기기" if show_board else "보드 보기"

func _render_battle_overlay() -> void:
	if is_ai_turn():
		overlay_layer.hide()
		board_view_button.hide()
		return
	if online_mode and online_state == "disconnected":
		var disconnected := _build_overlay("연결이 끊어졌습니다", false)
		label_at(disconnected, online_notice, 18, MUTED)
		button_at(disconnected, "온라인 메뉴로 돌아가기", _return_to_online_menu)
		return
	if online_mode and online_state == "sync_failed":
		var failed_sync := _build_overlay("전투 상태를 받지 못했습니다", false)
		label_at(failed_sync, "연결은 유지 중입니다. 다시 동기화하거나 대전을 나갈 수 있습니다.", 18, MUTED)
		button_at(failed_sync, "다시 동기화", _request_online_resync)
		button_at(failed_sync, "온라인 메뉴로 돌아가기", _return_to_online_menu)
		return
	if waiting_for_sync:
		_build_overlay("전투 상태 동기화 중…", false)
		return
	if battle.phase == "over":
		var result := _build_overlay("P%d 승리" % [battle.winner + 1], false)
		button_at(result, "게임 모드 선택", restart_game)
		return
	if battle.phase == "growth" and (not online_mode or battle.active == local_player):
		var growing := battle.get_unit(battle.locate(battle.income_choices[0]))
		var growth := _build_overlay(growing.card.name)
		label_at(growth, "생산력을 올리거나 이번 턴 마나를 생산하세요.", 16, MUTED)
		var gain: int = 1 if growing.card.id == "potato" else battle.production(growing)
		button_at(growth, "성장 · 생산력 +%d" % gain, func(): choose_growth(true))
		button_at(growth, "마나 생산", func(): choose_growth(false))
		return
	if battle.phase == "choice" and (not online_mode or battle.priority == local_player):
		if int(battle.choice.get("roll", 0)) == 5:
			overlay_layer.hide()
			return
		if int(battle.choice.get("roll", 0)) == 4 and battle.choice.get("stage", "") == "spell":
			var spell_choices := _build_overlay("갬블의 악마 · 상대의 사용된 주문 선택")
			var opponent := 1 - battle.priority
			for index in battle.roll_four_spell_choices():
				var used_card: Dictionary = battle.players[opponent].used[index]
				button_at(spell_choices, used_card.name + " · " + used_card.spell_text, func(): choose_gamble_spell(index))
			return
		var choice_name := "부활" if int(battle.choice.get("roll", 0)) == 3 else ("복사한 주문" if int(battle.choice.get("roll", 0)) == 4 else "피해 6")
		var choices := _build_overlay("갬블의 악마 · %s 대상" % choice_name)
		var target_scroll := ScrollContainer.new()
		target_scroll.custom_minimum_size = Vector2(500, minf(360, get_viewport_rect().size.y * 0.45))
		target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		choices.add_child(target_scroll)
		var target_list := VBoxContainer.new()
		target_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_scroll.add_child(target_list)
		for target in battle.choice_targets():
			var u := battle.get_unit(target)
			button_at(target_list, "P%d · 칸 %d · %s" % [target[0] + 1, target[1] + 1, u.card.name], func(): choose_gamble(target))
		return
	if battle.phase == "deploy" and (not online_mode or battle.active == local_player):
		var deploy := _build_overlay("카드 선택")
		var candidates := row_at(deploy)
		var p: Dictionary = battle.players[battle.active]
		for index in range(2):
			var pair: Array = p.deck[p.revealed]
			var card := TCGCards.by_id(pair[index])
			var choice := panel_at(candidates, GOLD)
			var choice_card := add_card(choice, card)
			choice_card.custom_minimum_size = Vector2(160, 224)
			choice_card.size = Vector2(160, 224)
			overlay_card_views.append(choice_card)
			if card.tier % 2 == 0:
				var other := TCGCards.by_id(pair[1 - index])
				label_at(choice, "짝 주문: " + other.name, 14, MUTED)
			button_at(choice, "이 카드 출현", func(): choose_deploy(index))
		return
	if selection.get("mode", "") == "replay":
		var replay := _build_overlay("대신 발동할 주문 선택 · 우클릭 취소")
		for card in battle.players[selection.owner].used:
			if card.effect_handler.can_be_copied() and not str(card.spell).is_empty():
				button_at(replay, card.name + " · " + card.spell_text, func(): select_replay(card))
		if replay.get_child_count() == 1:
			label_at(replay, "대신 발동할 수 있는 주문이 없습니다.", 16, MUTED)
		return
	if selection.get("mode", "") == "ability_choice":
		var ability_unit: Dictionary = battle.get_unit([selection.owner, selection.index])
		var ability_menu := _build_overlay("%s · 소모 효과 선택" % str(ability_unit.card.name))
		overlay_panel.custom_minimum_size = Vector2(760, 420)
		var guide := label_at(ability_menu, "사용할 효과를 누르세요 · 우클릭으로 취소", 16, MUTED)
		guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var effect_scroll := ScrollContainer.new()
		effect_scroll.name = "AbilityChoiceScroll"
		effect_scroll.custom_minimum_size = Vector2(700, 326)
		effect_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		effect_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ability_menu.add_child(effect_scroll)
		var effect_center := CenterContainer.new()
		effect_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		effect_scroll.add_child(effect_center)
		var effect_row := HBoxContainer.new()
		effect_row.name = "AbilityChoiceCards"
		effect_row.add_theme_constant_override("separation", 18)
		effect_center.add_child(effect_row)
		for option in selection.get("options", []):
			var unavailable_reason := ""
			if ability_unit.turn_used:
				unavailable_reason = "이번 턴에 이미 사용함"
			elif ability_unit.chain_used:
				unavailable_reason = "이 체인에서 이미 사용함"
			elif ability_unit.mana < int(option.get("cost", 0)):
				unavailable_reason = "마나 부족 · %d / %d" % [ability_unit.mana, int(option.get("cost", 0))]
			var choice_card = AbilityChoiceCardScene.instantiate()
			effect_row.add_child(choice_card)
			choice_card.configure(str(ability_unit.card.name), option, int(ability_unit.mana), unavailable_reason)
			choice_card.pressed.connect(func(): choose_ability_option(option))
		return
	if action_menu_open:
		var menu := _build_overlay("메뉴 · Esc로 닫기", false)
		var auto_check := CheckButton.new()
		auto_check.text = "행동 없으면 자동 넘김"
		auto_check.button_pressed = auto_pass
		auto_check.toggled.connect(func(value): auto_pass = value)
		menu.add_child(auto_check)
		button_at(menu, "규칙", show_rules)
		button_at(menu, "새 게임", confirm_restart)
		button_at(menu, "닫기", func(): action_menu_open = false; render())
		return
	overlay_layer.hide()
	board_view_button.hide()

func phase_hint() -> String:
	match battle.phase:
		"growth": return "턴 시작 · 감자의 생산력을 올릴지, 마나를 받을지 선택하세요."
		"deploy": return "출현 · 두 후보 중 필드에 놓을 유닛을 고르세요. 새 유닛의 첫 생산은 다음 자신의 턴입니다."
		"action":
			if battle.ending: return "턴 종료 요청 · 상대는 주문/소모 효과로 대응하거나 종료를 승인할 수 있습니다."
			if not battle.stack.is_empty(): return "체인 대응 · 효과를 추가하거나 패스하세요. 양측 연속 패스 시 역순으로 해결합니다."
			return "행동권이 있을 때 적 유닛 위로 드래그해 기본 공격 · 내 유닛을 탭해 소모 효과 · 주문은 아래 패에서 선택"
	return "전투 종료"

func render_unit(parent: Node, owner: int, slot: int) -> void:
	var target := [owner, slot]
	var u := battle.get_unit(target)
	var eligible := target_eligible(target)
	if u.is_empty():
		add_card(parent, {}, -1, -1, -1, false, true, "위치 %d\n미공개" % [slot + 1])
		return
	if not u.alive:
		var corpse := add_card(parent, u.card, -1, -1, -1, false, true, "건너뜀" if u.card.id == "skipped" else ("부활 대기" if u.get("revive_at", -1) >= 0 else "재기불능"), eligible)
		unit_views["%d:%d" % [owner, slot]] = corpse
		corpse.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and target_eligible(target):
				choose_target(target)
		)
		return
	var display_card: Dictionary = u.card.duplicate()
	display_card["current_max_hp"] = u.get("max_hp", u.card.health)
	var view := add_card(parent, display_card, battle.production(u), u.hp, u.mana, false, false, "", eligible, u.shield)
	unit_views["%d:%d" % [owner, slot]] = view
	view.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not selection.is_empty() and target_eligible(target):
				choose_target(target)
			elif begin_drag(target, get_global_mouse_position()):
				view.accept_event()
	)

func render_controls() -> void:
	if is_ai_turn():
		return
	if online_mode and waiting_for_sync:
		label_at(root, "상태 동기화를 기다리는 중…", 16, GOLD)
		return
	if online_mode and battle.phase in ["growth", "deploy"] and battle.active != local_player:
		label_at(root, "P%d 플레이어의 선택을 기다리는 중…" % [battle.active + 1], 16, GOLD)
		return
	if online_mode and battle.phase == "action" and battle.priority != local_player:
		label_at(root, "P%d 플레이어의 행동을 기다리는 중…" % [battle.priority + 1], 16, GOLD)
		return
	if battle.phase == "growth":
		var row := row_at(root)
		button_at(row, "감자 성장 · 이번 생산 포기 / 생산력 +1", func(): choose_growth(true))
		button_at(row, "마나 생산", func(): choose_growth(false))
	elif battle.phase == "deploy":
		var p: Dictionary = battle.players[battle.active]
		var row := row_at(root)
		for i in range(2):
			var c := TCGCards.by_id(p.deck[p.revealed][i])
			var col := panel_at(row, GOLD)
			card_summary(col, c)
			if c.tier % 2 == 0:
				var other := TCGCards.by_id(p.deck[p.revealed][1 - i])
				label_at(col, ("짝 주문은 사용됨으로: " if c.id == "student" else "패에 들어올 주문: ") + other.name, 16, GOLD)
			button_at(col, "유닛으로 출현", func(): choose_deploy(i))
	elif battle.phase == "action":
		if selection.get("mode", "") == "replay":
			var row := row_at(root)
			var available := false
			for c in battle.players[battle.priority].used:
				if c.effect_handler.can_be_copied() and not str(c.spell).is_empty():
					available = true
					button_at(row, c.name + " · " + c.spell_text, func(): select_replay(c))
			if not available:
				label_at(root, "대신 발동할 사용된 주문이 없습니다. 우클릭으로 취소하세요.", 17, GOLD)
		if selection.is_empty():
			var row := row_at(root)
			button_at(row, "종료 승인" if battle.ending else "패스 / 대응하지 않기", pass_action)
			button_at(row, "턴 종료 선언", end_action, battle.priority != battle.active or not battle.stack.is_empty())

func render_hand(parent: Node = root) -> void:
	var hand_area := PanelContainer.new()
	hand_area.name = "UnusedSpellArea"
	hand_area.custom_minimum_size = Vector2(330, HAND_AREA_HEIGHT)
	hand_area.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hand_area.add_theme_stylebox_override("panel", box(Color("101a2b"), GOLD))
	parent.add_child(hand_area)
	var hand_column := VBoxContainer.new()
	hand_column.add_theme_constant_override("separation", 2)
	hand_area.add_child(hand_column)
	label_at(hand_column, "안 쓴 주문", 12, GOLD)
	var owner := local_player if online_mode else (0 if ai_enabled else battle.priority)
	var p: Dictionary = battle.players[owner]
	if not p.hand.is_empty():
		var hand := HBoxContainer.new()
		hand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hand.add_theme_constant_override("separation", 3)
		hand_column.add_child(hand)
		for i in range(p.hand.size()):
			var c: Dictionary = p.hand[i]
			var spell_view := add_card(hand, c, -1, -1, -1, true)
			spell_view.custom_minimum_size = Vector2(66, 92)
			spell_views[i] = spell_view
			var can_target := not TCGRandomAI.spell_actions(battle, owner, i).is_empty()
			if not can_target:
				spell_view.modulate = Color(0.55, 0.58, 0.64, 0.8)
			spell_view.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					select_spell(i)
					spell_view.accept_event()
			)
	else:
		label_at(hand_column, "없음", 11, MUTED)

func render_used_spell_badge(parent: Node) -> void:
	var badge := PanelContainer.new()
	badge.name = "UsedSpellArchiveBadge"
	badge.custom_minimum_size = Vector2(210, 38)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.add_theme_stylebox_override("panel", box(Color("132238"), Color("7086a3")))
	parent.add_child(badge)
	var count0: int = battle.players[0].used.size()
	var count1: int = battle.players[1].used.size()
	var badge_label := label_at(badge, "썼던 주문들 · P1 %d / P2 %d" % [count0, count1], 12, MUTED)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_entered.connect(func(): show_used_spells_popup(badge))
	used_archive_badge = badge

func show_used_spells_popup(source: Control) -> void:
	if not is_instance_valid(source): return
	hide_used_spells_popup()
	used_spell_views.clear()
	var archive := PanelContainer.new()
	archive.name = "UsedSpellArchive"
	archive.custom_minimum_size = Vector2(720, 146)
	archive.size = archive.custom_minimum_size
	archive.add_theme_stylebox_override("panel", box(Color("101a2b"), Color("405878")))
	hover_layer.add_child(archive)
	used_archive_popup = archive
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	archive.add_child(column)
	label_at(column, "사용한 주문 · 효과 기록", 13, GOLD)
	var players_row := HBoxContainer.new()
	players_row.add_theme_constant_override("separation", 5)
	column.add_child(players_row)
	for owner in range(2):
		var player_panel := PanelContainer.new()
		player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_panel.add_theme_stylebox_override("panel", box(Color("16243a"), BLUE if owner == 1 else GOLD))
		players_row.add_child(player_panel)
		var player_column := VBoxContainer.new()
		player_column.add_theme_constant_override("separation", 2)
		player_panel.add_child(player_column)
		label_at(player_column, "P%d 사용 주문" % [owner + 1], 11, GOLD if owner == 0 else BLUE)
		if battle.players[owner].used.is_empty():
			label_at(player_column, "없음", 11, MUTED)
			continue
		var used_row := HBoxContainer.new()
		used_row.add_theme_constant_override("separation", 3)
		player_column.add_child(used_row)
		for card in battle.players[owner].used:
			var entry := VBoxContainer.new()
			entry.add_theme_constant_override("separation", 3)
			used_row.add_child(entry)
			var used_view := add_card(entry, card, -1, -1, -1, true)
			used_view.custom_minimum_size = Vector2(52, 73)
			used_view.get_parent().custom_minimum_size = Vector2(56, 77)
			used_view.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			used_spell_views.append(used_view)
			var effect_text := VBoxContainer.new()
			effect_text.custom_minimum_size.x = 94
			entry.add_child(effect_text)
			label_at(effect_text, card.name, 10, Color("f3e1b0"))
			label_at(effect_text, card.spell_text if not str(card.spell_text).is_empty() else "효과 없음", 9, MUTED)
	await get_tree().process_frame
	var viewport_size := get_viewport_rect().size
	archive.size = archive.get_combined_minimum_size()
	archive.global_position = Vector2(viewport_size.x - archive.size.x - 16, source.get_global_rect().end.y + 5)

func hide_used_spells_popup() -> void:
	if is_instance_valid(used_archive_popup):
		used_archive_popup.queue_free()
	used_archive_popup = null
	used_spell_views.clear()

