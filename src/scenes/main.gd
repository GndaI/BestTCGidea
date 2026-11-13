extends "res://src/scenes/controllers/battle_action_controller.gd"

var active_render_key := ""

func _current_render_key() -> String:
	if info_screen_active:
		return "info:%s" % start_page
	if drafting:
		if start_screen:
			return "start:%s" % start_page
		return "draft"
	if covered:
		return "covered"
	return "battle"

func _refresh_active_render(render_key: String) -> bool:
	match render_key:
		"start:decks": return refresh_deck_library_screen()
		"start:deck_editor": return refresh_deck_editor_screen()
		"start:fate_deck_editor": return refresh_fate_deck_editor_screen()
		"battle": return refresh_battle_screen()
	return false

func render_start_screen() -> void:
	match start_page:
		"battle": render_battle_menu()
		"game_mode": render_game_mode_menu()
		"ai": render_ai_menu()
		"online": render_online_menu()
		"account": render_account()
		"decks": render_deck_library()
		"deck_editor": render_deck_editor()
		"fate_deck_editor": render_fate_deck_editor()
		"patch_notes": render_patch_notes()
		"settings": render_settings_screen()
		"rules": render_rules_screen()
		_: render_main_menu()

func render() -> void:
	action_button.hide()
	if playing_effects:
		return
	if effects_enabled and not drafting and not battle.visual_events.is_empty():
		play_combat_effects()
		return
	battle.visual_events.clear()
	draft_card_views.clear()
	deck_card_views.clear()
	_save_field_scrolls()
	drag_source.clear()
	spell_views.clear()
	used_spell_views.clear()
	hide_used_spells_popup()
	hide_battle_log_popup()
	used_archive_badge = null
	unit_views.clear()
	clear_chain_spells()
	hide_card_preview()
	auto_timer.stop()
	var render_key := _current_render_key()
	if render_key == active_render_key and _refresh_active_render(render_key):
		if render_key == "battle":
			if is_ai_turn() and ai_timer.is_stopped():
				ai_timer.start()
			elif can_auto_pass():
				auto_timer.start()
			if not online_host and not pending_online_snapshots.is_empty():
				call_deferred("_drain_online_snapshots")
		return
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	active_render_key = render_key
	if info_screen_active:
		if is_instance_valid(battle_log_badge): battle_log_badge.hide()
		overlay_layer.hide()
		board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		board_scroll.scroll_vertical = 0
		root.add_theme_constant_override("separation", 0)
		render_start_screen()
		return
	if drafting:
		if is_instance_valid(battle_log_badge): battle_log_badge.hide()
		overlay_layer.hide()
		if start_screen:
			board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			board_scroll.scroll_vertical = 0
			root.add_theme_constant_override("separation", 0)
			render_start_screen()
			return
		board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		root.add_theme_constant_override("separation", 12)
		render_draft()
		return
	if covered:
		if is_instance_valid(battle_log_badge): battle_log_badge.hide()
		overlay_layer.hide()
		label_at(root, "P%d에게 화면을 넘겨 주세요" % [battle.priority + 1], 32, BLUE)
		label_at(root, "준비를 누르면 해당 플레이어의 선택 카드와 패가 표시됩니다.", 19, MUTED)
		button_at(root, "P%d 준비" % [battle.priority + 1], func(): covered = false; render())
		return
	board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_scroll.scroll_vertical = 0
	root.add_theme_constant_override("separation", 5)
	if is_instance_valid(battle_log_badge):
		battle_log_badge.show()
		_update_battle_log_badge()
	render_battle()
	if is_ai_turn() and ai_timer.is_stopped():
		ai_timer.start()
	elif can_auto_pass():
		auto_timer.start()
	if not online_host and not pending_online_snapshots.is_empty():
		call_deferred("_drain_online_snapshots")
