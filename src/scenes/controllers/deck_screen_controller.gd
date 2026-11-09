extends "res://src/scenes/controllers/online_screen_controller.gd"

var deck_editor_toast: PanelContainer
var deck_editor_toast_tween: Tween
var deck_editor_name_edit: LineEdit
var deck_editor_browser: HBoxContainer
var deck_editor_filter_buttons: Array[Button] = []
var deck_editor_slots: Dictionary = {}
var deck_library_title: Label
var deck_library_guide: Label
var deck_library_slots: Array[Dictionary] = []

func reset_decks() -> void:
	decks = [[], []]
	for p in range(2):
		decks[p] = _default_deck()

func is_ai_turn() -> bool:
	return not online_mode and ai_enabled and not drafting and battle.phase != "over" and battle.priority == 1

func ai_step() -> void:
	if playing_effects or not is_ai_turn():
		return
	selection = {}
	ai.step(battle)
	render()

func _load_saved_decks() -> void:
	saved_decks.clear()
	var load_path := SAVED_DECKS_PATH
	var imported_legacy := false
	if not FileAccess.file_exists(load_path):
		var legacy_path := OS.get_user_data_dir().get_base_dir().path_join("TWELVE").path_join("saved_decks.json")
		if not FileAccess.file_exists(legacy_path):
			return
		load_path = legacy_path
		imported_legacy = true
	var file := FileAccess.open(load_path, FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary): return
	for entry in parsed.get("decks", []):
		if saved_decks.size() >= MAX_CUSTOM_DECKS: break
		if entry is Dictionary and _valid_saved_deck_structure(entry.get("cards", [])):
			saved_decks.append({"name": str(entry.get("name", "이름 없는 덱")), "cards": entry.cards.duplicate(true)})
	if imported_legacy and not saved_decks.is_empty():
		_write_saved_decks(false)

func _write_saved_decks(sync_cloud: bool = true) -> bool:
	var file := FileAccess.open(SAVED_DECKS_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": 1, "decks": saved_decks}, "  "))
	if sync_cloud and account_auth != null and cloud_decks != null and account_auth.is_signed_in():
		cloud_decks.queue_save(saved_decks, account_auth.access_token(), account_auth.user_id())
		cloud_deck_notice = "변경한 덱을 클라우드에 저장하는 중…"
	return true

func _empty_deck() -> Array:
	return [[], [], [], [], [], []]

func _default_deck() -> Array:
	var deck: Array = []
	for tier in range(1, 7):
		var pool := TCGCards.pool(tier)
		deck.append([pool[0].id, pool[1].id])
	return deck

func _default_deck_entry() -> Dictionary:
	return {"name": "기본 덱", "cards": _default_deck()}

func _valid_saved_deck_structure(deck: Array) -> bool:
	if deck.size() != 6: return false
	for position in range(6):
		if not (deck[position] is Array) or deck[position].size() > 2: return false
		var seen: Array[String] = []
		for id_value in deck[position]:
			var card: Dictionary = TCGCards.by_id(str(id_value))
			if card.is_empty() or int(card.tier) != position + 1 or str(card.id) in seen:
				return false
			seen.append(str(card.id))
	return true

func _deck_count(deck: Array) -> int:
	var count := 0
	for pair in deck: count += pair.size()
	return count

func _deck_tooltip(entry: Dictionary) -> String:
	var lines: Array[String] = ["%s · %d / 12장" % [_deck_display_name(entry), _deck_count(entry.cards)], ""]
	for tier in range(1, 7):
		var names: Array[String] = []
		for id_value in entry.cards[tier - 1]:
			var card: Dictionary = TCGCards.by_id(str(id_value))
			if not card.is_empty(): names.append(str(card.name))
		lines.append("%d턴 · %s" % [tier, " / ".join(names) if not names.is_empty() else "비어 있음"])
	return "\n".join(lines)

func _deck_display_name(entry: Dictionary) -> String:
	var value := str(entry.get("name", "")).strip_edges()
	return value if not value.is_empty() else "이름 없는 덱"

func render_deck_library() -> void:
	_render_in_screen(DeckLibraryScreenScene, _render_deck_library_content)

func _render_deck_library_content() -> void:
	var title := "덱" if deck_library_mode == "manage" else ("P%d 덱 선택" % [draft_player + 1] if deck_library_mode == "local" else "사용할 덱 선택")
	var header := screen_header_at(title, back_from_deck_library)
	deck_library_title = header.get_node("ScreenTitle") as Label
	var page := VBoxContainer.new()
	page.name = "SavedDeckLibrary"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	root.add_child(page)
	var guide_text := "덱에 커서를 올리면 포함된 카드가 표시됩니다."
	if deck_library_mode == "ai": guide_text = "완성된 덱을 누르면 바로 AI 대전을 시작합니다."
	elif deck_library_mode == "online": guide_text = "완성된 덱을 누르면 즉시 제출됩니다."
	elif deck_library_mode == "local": guide_text = "P%d이 사용할 완성된 덱을 선택하세요." % [draft_player + 1]
	var guide := label_at(page, guide_text, BODY_FONT_SIZE, MUTED)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_library_guide = guide
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(grid_center)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.custom_minimum_size = Vector2(1030, 620)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid_center.add_child(grid)
	deck_library_slots.clear()
	for slot in range(9):
		_build_deck_library_slot(grid, slot)
	refresh_deck_library_screen()

func _build_deck_library_slot(parent: Node, slot_index: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "BuiltinDefaultDeckSlot" if slot_index == 8 else "DeckLibrarySlot%d" % slot_index
	panel.custom_minimum_size = Vector2(330, 190)
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := row_at(col)
	var deck_name := label_at(top, "", BODY_FONT_SIZE, GOLD)
	deck_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var remove := button_at(top, "삭제", func(): confirm_delete_saved_deck(slot_index))
	remove.custom_minimum_size = Vector2(76, 42)
	var badge := label_at(top, "기본 제공", 18, Color("fff0c2"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var status := label_at(col, "", BODY_FONT_SIZE, MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var action := button_at(col, "", func(): _activate_deck_library_slot(slot_index))
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	var plus := button_at(panel, "+", func(): create_empty_deck())
	plus.add_theme_font_size_override("font_size", 54)
	deck_library_slots.append({
		"panel": panel,
		"content": col,
		"name": deck_name,
		"remove": remove,
		"badge": badge,
		"status": status,
		"action": action,
		"plus": plus,
	})

func _activate_deck_library_slot(slot_index: int) -> void:
	if slot_index == 8:
		choose_default_deck()
	elif slot_index >= 0 and slot_index < saved_decks.size():
		choose_saved_deck(slot_index)

func refresh_deck_library_screen() -> bool:
	if not is_instance_valid(deck_library_title) or not is_instance_valid(deck_library_guide) or deck_library_slots.size() != 9:
		return false
	deck_library_title.text = "덱" if deck_library_mode == "manage" else ("P%d 덱 선택" % [draft_player + 1] if deck_library_mode == "local" else "사용할 덱 선택")
	var guide_text := "덱에 커서를 올리면 포함된 카드가 표시됩니다."
	if deck_library_mode == "ai": guide_text = "완성된 덱을 누르면 바로 AI 대전을 시작합니다."
	elif deck_library_mode == "online": guide_text = "완성된 덱을 누르면 즉시 제출됩니다."
	elif deck_library_mode == "local": guide_text = "P%d이 사용할 완성된 덱을 선택하세요." % [draft_player + 1]
	deck_library_guide.text = guide_text
	for slot_index in range(9):
		var refs: Dictionary = deck_library_slots[slot_index]
		var panel: PanelContainer = refs.panel
		var content: VBoxContainer = refs.content
		var deck_name: Label = refs.name
		var remove: Button = refs.remove
		var badge: Label = refs.badge
		var status: Label = refs.status
		var action: Button = refs.action
		var plus: Button = refs.plus
		if not is_instance_valid(panel): return false
		var is_default := slot_index == 8
		var has_custom := slot_index < saved_decks.size() and not is_default
		var is_empty := not is_default and not has_custom
		content.visible = not is_empty
		plus.visible = is_empty
		if is_empty:
			panel.add_theme_stylebox_override("panel", box(Color("111c2e"), Color("293c55")))
			plus.disabled = deck_library_mode != "manage" or saved_decks.size() >= MAX_CUSTOM_DECKS
			plus.tooltip_text = "빈 덱 만들기" if deck_library_mode == "manage" else "대전에서는 완성된 덱만 선택할 수 있습니다."
			panel.tooltip_text = ""
			continue
		var entry: Dictionary = _default_deck_entry() if is_default else saved_decks[slot_index]
		var valid := _valid_online_deck(entry.cards)
		panel.tooltip_text = _deck_tooltip(entry)
		deck_name.text = "기본 덱" if is_default else _deck_display_name(entry)
		remove.visible = not is_default
		badge.visible = is_default
		status.text = "%d / 12장 · %s" % [_deck_count(entry.cards), "대전 가능" if valid else "제작 중"]
		status.add_theme_color_override("font_color", GREEN if valid else MUTED)
		var action_text := "복사해서 편집" if is_default else "편집하기"
		if deck_library_mode == "ai": action_text = "선택하고 대전 시작"
		elif deck_library_mode == "online": action_text = "선택하고 제출"
		elif deck_library_mode == "local": action_text = "P%d 덱으로 선택" % [draft_player + 1]
		var selection_locked := deck_library_mode == "online" and local_deck_submitted
		var custom_limit_reached := is_default and deck_library_mode == "manage" and saved_decks.size() >= MAX_CUSTOM_DECKS
		action.text = "제출 완료" if selection_locked else action_text
		action.disabled = selection_locked or custom_limit_reached
		action.tooltip_text = "사용자 덱은 8개까지 만들 수 있습니다." if custom_limit_reached else _deck_tooltip(entry)
		if is_default:
			var default_style := box(Color("1d2b42"), GOLD.darkened(0.35))
			default_style.set_border_width_all(3)
			panel.add_theme_stylebox_override("panel", default_style)
		else:
			panel.add_theme_stylebox_override("panel", box(Color("17263d"), Color("3b5473")))
	return true

func _render_deck_slot(parent: Node, index: int) -> void:
	var entry: Dictionary = saved_decks[index]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 190)
	panel.add_theme_stylebox_override("panel", box(Color("17263d"), Color("3b5473")))
	panel.tooltip_text = _deck_tooltip(entry)
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := row_at(col)
	var deck_name := label_at(top, _deck_display_name(entry), BODY_FONT_SIZE, GOLD)
	deck_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var remove := button_at(top, "삭제", func(): confirm_delete_saved_deck(index))
	remove.custom_minimum_size = Vector2(76, 42)
	var count := _deck_count(entry.cards)
	var status := label_at(col, "%d / 12장 · %s" % [count, "대전 가능" if _valid_online_deck(entry.cards) else "제작 중"], BODY_FONT_SIZE, GREEN if _valid_online_deck(entry.cards) else MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var action_text := "편집하기"
	if deck_library_mode == "ai": action_text = "선택하고 대전 시작"
	elif deck_library_mode == "online": action_text = "선택하고 제출"
	elif deck_library_mode == "local": action_text = "P%d 덱으로 선택" % [draft_player + 1]
	var selection_locked := deck_library_mode == "online" and local_deck_submitted
	var action := button_at(col, "제출 완료" if selection_locked else action_text, func(): choose_saved_deck(index), selection_locked)
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	action.tooltip_text = _deck_tooltip(entry)

func _render_empty_deck_slot(parent: Node, _slot: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 190)
	panel.add_theme_stylebox_override("panel", box(Color("111c2e"), Color("293c55")))
	parent.add_child(panel)
	var plus := button_at(panel, "+", create_empty_deck, deck_library_mode != "manage" or saved_decks.size() >= MAX_CUSTOM_DECKS)
	plus.add_theme_font_size_override("font_size", 54)
	plus.tooltip_text = "빈 덱 만들기" if deck_library_mode == "manage" else "대전에서는 완성된 덱만 선택할 수 있습니다."

func _render_default_deck_slot(parent: Node) -> void:
	var entry := _default_deck_entry()
	var panel := PanelContainer.new()
	panel.name = "BuiltinDefaultDeckSlot"
	panel.custom_minimum_size = Vector2(330, 190)
	var panel_style := box(Color("1d2b42"), GOLD.darkened(0.35))
	panel_style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.tooltip_text = _deck_tooltip(entry)
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := row_at(col)
	var deck_name := label_at(top, "기본 덱", BODY_FONT_SIZE, GOLD)
	deck_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var badge := label_at(top, "기본 제공", 18, Color("fff0c2"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var status := label_at(col, "12 / 12장 · 대전 가능", BODY_FONT_SIZE, GREEN)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var action_text := "복사해서 편집"
	if deck_library_mode == "ai": action_text = "선택하고 대전 시작"
	elif deck_library_mode == "online": action_text = "선택하고 제출"
	elif deck_library_mode == "local": action_text = "P%d 덱으로 선택" % [draft_player + 1]
	var selection_locked := deck_library_mode == "online" and local_deck_submitted
	var custom_limit_reached := deck_library_mode == "manage" and saved_decks.size() >= MAX_CUSTOM_DECKS
	var action := button_at(col, "제출 완료" if selection_locked else action_text, choose_default_deck, selection_locked or custom_limit_reached)
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	action.tooltip_text = "사용자 덱은 8개까지 만들 수 있습니다." if custom_limit_reached else _deck_tooltip(entry)

func create_empty_deck() -> void:
	if deck_library_mode != "manage" or saved_decks.size() >= MAX_CUSTOM_DECKS: return
	var number := saved_decks.size() + 1
	saved_decks.append({"name": "새 덱 %d" % number, "cards": _empty_deck()})
	_write_saved_decks()
	open_deck_editor(saved_decks.size() - 1)

func choose_saved_deck(index: int) -> void:
	if index < 0 or index >= saved_decks.size(): return
	if deck_library_mode == "online" and local_deck_submitted: return
	if deck_library_mode == "manage":
		open_deck_editor(index)
		return
	var chosen: Array = saved_decks[index].cards.duplicate(true)
	if not _valid_online_deck(chosen):
		_show_deck_editor_toast("12장을 모두 채운 덱만 대전에 사용할 수 있습니다.")
		return
	_use_chosen_deck(chosen)

func choose_default_deck() -> void:
	if deck_library_mode == "online" and local_deck_submitted: return
	var chosen := _default_deck()
	if deck_library_mode == "manage":
		if saved_decks.size() >= MAX_CUSTOM_DECKS: return
		saved_decks.append({"name": "기본 덱 복사본", "cards": chosen.duplicate(true)})
		_write_saved_decks()
		open_deck_editor(saved_decks.size() - 1)
		return
	_use_chosen_deck(chosen)

func _use_chosen_deck(chosen: Array) -> void:
	decks[draft_player] = chosen.duplicate(true)
	if deck_library_mode == "online":
		submit_selected_online_deck()
	elif deck_library_mode == "local" and draft_player == 0:
		draft_player = 1
		render()
		_show_deck_editor_toast("P1 덱 선택 완료 · 이제 P2 덱을 선택하세요.")
	else:
		start_screen = false
		online_mode = false
		ai_enabled = deck_library_mode == "ai"
		drafting = true
		begin_game()

func submit_selected_online_deck() -> void:
	local_deck_submitted = true
	if online_host:
		if remote_deck_submitted:
			start_online_match()
		else:
			online_notice = "내 덱을 제출했습니다. 상대 덱 제출을 기다리는 중…"
			render()
			_show_deck_editor_toast(online_notice)
	else:
		room_signaling.send_game("submit_deck", {"deck": decks[local_player]})
		online_notice = "덱을 제출했습니다. 호스트가 대전을 시작할 때까지 기다려 주세요."
		render()
		_show_deck_editor_toast(online_notice)

func back_from_deck_library() -> void:
	deck_editor_notice = ""
	if deck_library_mode == "manage":
		back_to_main_menu()
	elif deck_library_mode == "ai":
		start_page = "ai"
		render()
	elif deck_library_mode == "local":
		if draft_player == 1:
			draft_player = 0
			deck_editor_notice = ""
			render()
		else:
			back_to_battle_menu()
	else:
		start_page = "online"
		stop_network()

func back_to_deck_library() -> void:
	editing_deck_index = -1
	deck_search_text = ""
	deck_filter_tiers.clear()
	deck_editor_notice = ""
	start_page = "decks"
	render()

func open_deck_editor(index: int) -> void:
	if index < 0 or index >= saved_decks.size(): return
	deck_library_mode = "manage"
	editing_deck_index = index
	deck_search_text = ""
	deck_filter_tiers.clear()
	deck_editor_notice = ""
	start_page = "deck_editor"
	render()

func render_deck_editor() -> void:
	_render_in_screen(DeckEditorScreenScene, _render_deck_editor_content)

func _render_deck_editor_content() -> void:
	if editing_deck_index < 0 or editing_deck_index >= saved_decks.size():
		back_to_deck_library()
		return
	screen_header_at("덱 제작", back_to_deck_library)
	deck_editor_slots.clear()
	deck_editor_filter_buttons.clear()
	var body := HBoxContainer.new()
	body.name = "DeckEditor"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(535, 710)
	left_panel.add_theme_stylebox_override("panel", box(Color("142238"), Color("344b68")))
	body.add_child(left_panel)
	var left := VBoxContainer.new()
	left.name = "EditorDeckColumn"
	left.add_theme_constant_override("separation", 0)
	left_panel.add_child(left)
	var name_row := row_at(left)
	var name_edit := LineEdit.new()
	name_edit.name = "DeckNameEdit"
	name_edit.text = str(saved_decks[editing_deck_index].name)
	name_edit.placeholder_text = "덱 이름"
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(380, 46)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(update_edited_deck_name)
	name_row.add_child(name_edit)
	deck_editor_name_edit = name_edit
	var delete_button := button_at(name_row, "삭제", func(): confirm_delete_saved_deck(editing_deck_index))
	delete_button.custom_minimum_size = Vector2(90, 46)
	var deck: Array = saved_decks[editing_deck_index].cards
	for tier in range(1, 7):
		_add_deck_editor_vertical_spacer(left, "LeftDeckGap%d" % tier)
		_render_editor_tier(left, deck, tier)
	_add_deck_editor_vertical_spacer(left, "LeftDeckGapBottom")
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", box(Color("142238"), Color("344b68")))
	body.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right_panel.add_child(right)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 7)
	right.add_child(search_row)
	var search := LineEdit.new()
	search.name = "DeckCardSearch"
	search.placeholder_text = "카드 이름이나 효과 검색"
	search.text = deck_search_text
	search.custom_minimum_size.y = 50
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	search_row.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.name = "AllCardsHorizontalScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep the card rows at the same height even when filtering leaves too few
	# cards to require horizontal scrolling.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var browser := HBoxContainer.new()
	browser.name = "DeckCardBrowser"
	browser.add_theme_constant_override("separation", 12)
	browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(browser)
	deck_editor_browser = browser
	var filter_buttons: Array[Button] = []
	for filter_tier in range(7):
		var filter_value := filter_tier
		var filter_button := Button.new()
		filter_button.name = "DeckTierFilter%d" % filter_value
		filter_button.text = "전체" if filter_value == 0 else "%d턴" % filter_value
		filter_button.custom_minimum_size = Vector2(58, 50)
		filter_button.add_theme_font_size_override("font_size", 16)
		filter_button.toggle_mode = true
		filter_button.button_pressed = deck_filter_tiers.is_empty() if filter_value == 0 else filter_value in deck_filter_tiers
		filter_button.pressed.connect(func():
			if filter_value == 0:
				deck_filter_tiers.clear()
			elif filter_value in deck_filter_tiers:
				deck_filter_tiers.clear()
			else:
				deck_filter_tiers.clear()
				deck_filter_tiers.append(filter_value)
			for button in filter_buttons:
				var button_tier := int(button.name.trim_prefix("DeckTierFilter"))
				button.button_pressed = deck_filter_tiers.is_empty() if button_tier == 0 else button_tier in deck_filter_tiers
			_rebuild_deck_card_browser(browser)
		)
		filter_buttons.append(filter_button)
		deck_editor_filter_buttons.append(filter_button)
		search_row.add_child(filter_button)
	_rebuild_deck_card_browser(browser)
	search.text_changed.connect(func(value):
		deck_search_text = value
		_rebuild_deck_card_browser(browser)
	)

func _show_deck_editor_toast(message: String) -> void:
	if message.is_empty() or not is_instance_valid(hover_layer): return
	if is_instance_valid(deck_editor_toast_tween):
		deck_editor_toast_tween.kill()
	if is_instance_valid(deck_editor_toast):
		deck_editor_toast.queue_free()
	var toast := PanelContainer.new()
	toast.name = "DeckEditorToast"
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.anchor_top = 0.5
	toast.anchor_bottom = 0.5
	toast.offset_left = -300
	toast.offset_right = 300
	toast.offset_top = -42
	toast.offset_bottom = 42
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 100
	var toast_style := box(Color(0.025, 0.045, 0.08, 0.72), Color(1.0, 0.74, 0.46, 0.34))
	toast_style.set_border_width_all(1)
	toast_style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	toast_style.shadow_size = 18
	toast.add_theme_stylebox_override("panel", toast_style)
	hover_layer.add_child(toast)
	deck_editor_toast = toast
	var toast_label := label_at(toast, message, 22, Color(1.0, 0.94, 0.83, 0.94))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.modulate.a = 0.0
	deck_editor_toast_tween = create_tween()
	deck_editor_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.12)
	deck_editor_toast_tween.tween_interval(0.98)
	deck_editor_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deck_editor_toast_tween.tween_callback(func():
		if is_instance_valid(toast): toast.queue_free()
		if deck_editor_toast == toast: deck_editor_toast = null
		deck_editor_toast_tween = null
	)

func _add_deck_editor_vertical_spacer(parent: Node, spacer_name: String = "") -> Control:
	var spacer := Control.new()
	spacer.name = spacer_name
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer

func _render_editor_tier(parent: Node, deck: Array, tier: int) -> void:
	var tier_panel := PanelContainer.new()
	tier_panel.name = "EditorTier%d" % tier
	tier_panel.custom_minimum_size = Vector2(500, 104)
	var tier_style := box(Color("182940"), Color("2c425e"))
	tier_style.set_content_margin_all(3)
	tier_panel.add_theme_stylebox_override("panel", tier_style)
	parent.add_child(tier_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tier_panel.add_child(row)
	var tier_label := label_at(row, "%d턴" % tier, TURN_FONT_SIZE, Color("ffe0a0"))
	tier_label.custom_minimum_size.x = 92
	tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emphasize_label(tier_label, 0.9)
	for position in range(2):
		var slot := Control.new()
		slot.name = "EditorTier%dSlot%d" % [tier, position]
		slot.custom_minimum_size = Vector2(196, 98)
		slot.clip_contents = true
		row.add_child(slot)
		deck_editor_slots["%d:%d" % [tier, position]] = slot
		_refresh_editor_slot(slot, deck, tier, position)

func _refresh_editor_slot(slot: Control, deck: Array, tier: int, position: int) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	if position >= deck[tier - 1].size():
		var empty := Label.new()
		empty.text = "빈 카드 칸"
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
		empty.add_theme_color_override("font_color", Color("6f829b"))
		slot.add_child(empty)
		return
	var id_value := str(deck[tier - 1][position])
	var card: Dictionary = TCGCards.by_id(id_value)
	var card_row := HBoxContainer.new()
	card_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_row.add_theme_constant_override("separation", 6)
	slot.add_child(card_row)
	var view := add_card(card_row, card)
	view.custom_minimum_size = Vector2(70, 98)
	view.tooltip_text = ""
	view.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			remove_editor_card(tier, id_value, view)
	)
	var card_name := label_at(card_row, str(card.name), 20, Color("e8eef8"))
	card_name.custom_minimum_size = Vector2(120, 98)
	card_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_name.max_lines_visible = 2
	card_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func refresh_deck_editor_screen() -> bool:
	if editing_deck_index < 0 or editing_deck_index >= saved_decks.size(): return false
	if not is_instance_valid(deck_editor_browser) or deck_editor_slots.size() != 12: return false
	var deck: Array = saved_decks[editing_deck_index].cards
	if is_instance_valid(deck_editor_name_edit) and not deck_editor_name_edit.has_focus():
		deck_editor_name_edit.text = str(saved_decks[editing_deck_index].name)
	for tier in range(1, 7):
		for position in range(2):
			var slot: Control = deck_editor_slots.get("%d:%d" % [tier, position])
			if not is_instance_valid(slot): return false
			_refresh_editor_slot(slot, deck, tier, position)
	for button in deck_editor_filter_buttons:
		if not is_instance_valid(button): return false
		var button_tier := int(button.name.trim_prefix("DeckTierFilter"))
		button.button_pressed = deck_filter_tiers.is_empty() if button_tier == 0 else button_tier in deck_filter_tiers
	_rebuild_deck_card_browser(deck_editor_browser)
	return true

func _rebuild_deck_card_browser(browser: HBoxContainer) -> void:
	for child in browser.get_children():
		browser.remove_child(child)
		child.queue_free()
	var query := deck_search_text.strip_edges().to_lower()
	var selected_ids: Array[String] = []
	if editing_deck_index >= 0 and editing_deck_index < saved_decks.size():
		for pair in saved_decks[editing_deck_index].cards:
			for id_value in pair:
				selected_ids.append(str(id_value))
	var visible_cards: Array[Dictionary] = []
	for tier in range(1, 7):
		if not deck_filter_tiers.is_empty() and tier not in deck_filter_tiers: continue
		for card_value in TCGCards.pool(tier):
			var card: Dictionary = card_value
			if str(card.id) in selected_ids: continue
			var haystack := (str(card.name) + " " + str(card.get("rules", "")) + " " + str(card.get("spell_text", "")) + " " + str(card.id)).to_lower()
			if not query.is_empty() and not query in haystack: continue
			visible_cards.append(card)
	for column_start in range(0, visible_cards.size(), 2):
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 200
		column.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		browser.add_child(column)
		_add_deck_editor_vertical_spacer(column, "CardGapTop")
		for offset in range(2):
			var card_index := column_start + offset
			if card_index < visible_cards.size():
				var card: Dictionary = visible_cards[card_index]
				var view := add_card(column, card)
				view.custom_minimum_size = Vector2(200, 280)
				view.tooltip_text = ""
				var card_id := str(card.id)
				var card_tier := int(card.tier)
				view.gui_input.connect(func(event):
					if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
						add_editor_card(card_tier, card_id, view)
				)
			else:
				var empty_card_space := Control.new()
				empty_card_space.custom_minimum_size = Vector2(200, 280)
				empty_card_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
				column.add_child(empty_card_space)
			_add_deck_editor_vertical_spacer(column, "CardGapMiddle" if offset == 0 else "CardGapBottom")

func _editor_card_hover_text(card: Dictionary, action_text: String) -> String:
	var lines: Array[String] = [str(card.name)]
	if not str(card.get("rules", "")).is_empty(): lines.append("능력 · " + str(card.rules))
	if not str(card.get("spell_text", "")).is_empty(): lines.append("주문 · " + str(card.spell_text))
	if lines.size() == 1: lines.append("효과 없음")
	lines.append("")
	lines.append(action_text)
	return "\n".join(lines)

func update_edited_deck_name(value: String) -> void:
	if editing_deck_index < 0 or editing_deck_index >= saved_decks.size(): return
	saved_decks[editing_deck_index].name = value
	_write_saved_decks()

func add_editor_card(tier: int, id_value: String, source_view: Control = null) -> void:
	if deck_transfer_active or editing_deck_index < 0 or editing_deck_index >= saved_decks.size(): return
	var pair: Array = saved_decks[editing_deck_index].cards[tier - 1]
	if id_value in pair:
		_show_deck_editor_toast("이미 이 턴에 들어 있는 카드입니다.")
		return
	elif pair.size() >= 2:
		_show_deck_editor_toast("%d턴은 이미 2장입니다. 왼쪽에서 카드 하나를 먼저 빼세요." % tier)
		return
	deck_transfer_active = true
	await _animate_editor_card_transfer(source_view, root.find_child("EditorTier%d" % tier, true, false), TCGCards.by_id(id_value))
	pair.append(id_value)
	var saved_ok := _write_saved_decks()
	deck_transfer_active = false
	render()
	if not saved_ok:
		_show_deck_editor_toast("덱 저장 파일을 갱신할 수 없습니다.")

func remove_editor_card(tier: int, id_value: String, source_view: Control = null) -> void:
	if deck_transfer_active or editing_deck_index < 0 or editing_deck_index >= saved_decks.size(): return
	var pair: Array = saved_decks[editing_deck_index].cards[tier - 1]
	deck_transfer_active = true
	await _animate_editor_card_transfer(source_view, root.find_child("DeckCardBrowser", true, false), TCGCards.by_id(id_value))
	pair.erase(id_value)
	var saved_ok := _write_saved_decks()
	deck_transfer_active = false
	render()
	if not saved_ok:
		_show_deck_editor_toast("덱 저장 파일을 갱신할 수 없습니다.")

func _animate_editor_card_transfer(source: Control, destination: Control, card: Dictionary) -> void:
	if not is_instance_valid(source) or not is_instance_valid(destination) or card.is_empty(): return
	hide_card_preview()
	var source_rect := source.get_global_rect()
	var destination_rect := destination.get_global_rect()
	var flying := TCGCardView.new()
	flying.configure(card)
	flying.size = source_rect.size
	flying.custom_minimum_size = source_rect.size
	flying.global_position = source_rect.position
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying.z_index = 95
	hover_layer.add_child(flying)
	await get_tree().process_frame
	var target_size := Vector2(70, 98) if destination.name.begins_with("EditorTier") else Vector2(91, 127)
	var target_scale := Vector2(target_size.x / maxf(1.0, flying.size.x), target_size.y / maxf(1.0, flying.size.y))
	var target_position := destination_rect.get_center() - flying.size * target_scale * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flying, "global_position", target_position, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "scale", target_scale, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "modulate:a", 0.25, 0.32)
	await tween.finished
	flying.queue_free()

func save_current_deck() -> void:
	if online_mode and local_deck_submitted: return
	var name := deck_name_text.strip_edges()
	if name.is_empty():
		info = "저장할 덱 이름을 입력하세요."
		render()
		return
	var current: Array = decks[draft_player].duplicate(true)
	if not _valid_online_deck(current):
		info = "각 단계의 카드 두 장을 모두 선택해야 저장할 수 있습니다."
		render()
		return
	var replaced := false
	for index in range(saved_decks.size()):
		if str(saved_decks[index].name) == name:
			saved_decks[index].cards = current
			replaced = true
			break
	if not replaced:
		saved_decks.append({"name": name, "cards": current})
	info = ("저장된 덱을 수정했습니다: " if replaced else "덱을 저장했습니다: ") + name
	if not _write_saved_decks(): info = "덱 저장 파일을 만들 수 없습니다."
	render()

func load_saved_deck(index: int) -> void:
	if index < 0 or index >= saved_decks.size() or (online_mode and local_deck_submitted): return
	decks[draft_player] = saved_decks[index].cards.duplicate(true)
	deck_name_text = str(saved_decks[index].name)
	info = "저장된 덱을 불러왔습니다. 카드를 바꾼 뒤 같은 이름으로 저장하면 수정됩니다."
	render()

func confirm_delete_saved_deck(index: int) -> void:
	if index < 0 or index >= saved_decks.size(): return
	var dialog := ConfirmationDialog.new()
	dialog.title = "저장 덱 삭제"
	dialog.dialog_text = "‘%s’ 덱을 삭제할까요?" % str(saved_decks[index].name)
	dialog.confirmed.connect(func(): delete_saved_deck(index))
	add_child(dialog)
	dialog.popup_centered(Vector2i(430, 180))
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func delete_saved_deck(index: int) -> void:
	if index < 0 or index >= saved_decks.size(): return
	var removed_name := str(saved_decks[index].name)
	var deleting_open_editor := start_page == "deck_editor" and editing_deck_index == index
	saved_decks.remove_at(index)
	if editing_deck_index > index: editing_deck_index -= 1
	if deck_name_text == removed_name: deck_name_text = ""
	info = "저장된 덱을 삭제했습니다: " + removed_name
	deck_editor_notice = info
	if not _write_saved_decks(): info = "덱 목록 파일을 갱신할 수 없습니다."
	if deleting_open_editor:
		editing_deck_index = -1
		start_page = "decks"
	render()

func render_saved_decks() -> void:
	var library := panel_at(root, Color("8e75d5"))
	library.name = "SavedDeckLibrary"
	label_at(library, "덱 보관함", 22, Color("d8c7ff"))
	var save_row := row_at(library)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "덱 이름"
	name_edit.text = deck_name_text
	name_edit.custom_minimum_size = Vector2(280, 42)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(value): deck_name_text = value)
	save_row.add_child(name_edit)
	button_at(save_row, "현재 덱 저장 / 수정", save_current_deck, online_mode and local_deck_submitted)
	if saved_decks.is_empty():
		label_at(library, "아직 저장된 덱이 없습니다.", 14, MUTED)
		return
	for index in range(saved_decks.size()):
		var saved_index := index
		var entry: Dictionary = saved_decks[index]
		var row := row_at(library)
		label_at(row, str(entry.name), 16, GOLD)
		button_at(row, "불러오기 · 수정", func(): load_saved_deck(saved_index), online_mode and local_deck_submitted)
		button_at(row, "삭제", func(): confirm_delete_saved_deck(saved_index))

func render_draft() -> void:
	_render_in_screen(DraftScreenScene, _render_draft_content)

func _render_draft_content() -> void:
	var header := screen_header_at("덱 제작", restart_game)
	var rules_button := button_at(header, "정보", show_rules)
	rules_button.custom_minimum_size = Vector2(150, 48)
	rules_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rules_button.offset_left = -150
	rules_button.offset_right = 0
	rules_button.offset_top = 0
	rules_button.offset_bottom = 48
	label_at(root, "P%d의 12장 덱 구성" % [draft_player + 1], 25, BLUE)
	label_at(root, "각 단계의 카드 중 2장을 선택하세요. 하나는 유닛, 짝수 단계의 나머지 하나는 주문이 됩니다.", 17, MUTED)
	if online_mode:
		label_at(root, "P2P · P%d 플레이어 덱" % [local_player + 1], 17, GOLD)
		if local_deck_submitted:
			label_at(root, "덱 제출 완료 · 상대 플레이어를 기다리는 중…", 16, GREEN)
		if not online_notice.is_empty(): label_at(root, online_notice, 15, MUTED)
	else:
		var actions := row_at(root)
		button_at(actions, "기본 덱으로 바로 시작", func(): begin_game())
		var ai_check := CheckButton.new()
		ai_check.text = "P2 %s AI" % ("필드 장악 · 강함" if ai_difficulty == "hard" else "랜덤 · 쉬움")
		ai_check.button_pressed = ai_enabled
		ai_check.toggled.connect(func(value): ai_enabled = value; draft_player = 0; render())
		actions.add_child(ai_check)
		var check := CheckButton.new()
		check.text = "화면 넘김 모드 (행동권 변경 시 패 가리기)"
		check.button_pressed = privacy
		check.disabled = ai_enabled
		check.toggled.connect(func(value): privacy = value)
		actions.add_child(check)
	for tier in range(1, 7):
		label_at(root, "위치 %02d · %s" % [tier, "유닛 + 주문" if tier % 2 == 0 else "유닛 선택"], 19, GOLD)
		var row := row_at(root)
		for c in TCGCards.pool(tier):
			var selected: bool = c.id in decks[draft_player][tier - 1]
			var col := panel_at(row, GREEN if selected else Color.TRANSPARENT)
			var chosen_style := box(Color("17382d") if selected else PANEL, GREEN if selected else Color("33425a"))
			chosen_style.set_border_width_all(3 if selected else 1)
			col.get_parent().add_theme_stylebox_override("panel", chosen_style)
			label_at(col, "✓ 선택됨" if selected else "선택 가능", 17, GREEN if selected else MUTED)
			var view := add_card(col, c, -1, -1, -1, false, false, "", false, 0, selected)
			view.modulate = Color.WHITE if selected else Color(0.78, 0.81, 0.86)
			draft_card_views.append(view)
			button_at(col, "✓ 선택됨 · 제외" if selected else "+ 덱에 선택", func(): toggle_draft(tier, c.id), online_mode and local_deck_submitted)
	render_deck_overview()
	var valid := true
	for pair in decks[draft_player]:
		if pair.size() != 2:
			valid = false
	var ai_name := "필드 장악 AI · 강함" if ai_difficulty == "hard" else "랜덤 AI · 쉬움"
	var confirm_text := "덱 제출" if online_mode else ("덱 확정 → %s와 대전" % ai_name if ai_enabled else ("P1 확정 → P2 덱 구성" if draft_player == 0 else "P2 확정 → 전투 시작"))
	button_at(root, confirm_text, func(): confirm_draft(), not valid or (online_mode and local_deck_submitted))
	if not info.is_empty():
		label_at(root, info, 17, GOLD)

func card_summary(parent: Node, c: Dictionary) -> void:
	add_card(parent, c)

func render_deck_overview() -> void:
	deck_overview = panel_at(root, GOLD)
	deck_overview.name = "DeckOverview"
	var count := 0
	for pair in decks[draft_player]: count += pair.size()
	label_at(deck_overview, "완성 덱 · P%d · %d / 12장" % [draft_player + 1, count], 25, GOLD)
	label_at(deck_overview, "선택한 카드 전체를 단계별로 확인하세요. 카드에 커서를 올리면 효과가 표시됩니다.", 16, MUTED)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	deck_overview.add_child(grid)
	for tier in range(1, 7):
		var group := panel_at(grid, BLUE)
		label_at(group, "%d단계 · %d / 2장" % [tier, decks[draft_player][tier - 1].size()], 18, BLUE)
		var row := row_at(group)
		for position in range(2):
			var pair: Array = decks[draft_player][tier - 1]
			var view: TCGCardView
			if position < pair.size():
				view = add_card(row, TCGCards.by_id(pair[position]), -1, -1, -1, false, false, "", false, 0, true)
				deck_card_views.append(view)
			else:
				view = add_card(row, {}, -1, -1, -1, false, true, "미선택")
			view.custom_minimum_size = Vector2(140, 196)

func _save_field_scrolls() -> void:
	for owner in field_scrolls:
		if is_instance_valid(field_scrolls[owner]):
			field_scroll_positions[owner] = field_scrolls[owner].scroll_horizontal
	field_scrolls.clear()
	field_panels.clear()
	field_slot_holders.clear()
	gambler_docks.clear()

func toggle_draft(tier: int, id: String) -> void:
	if online_mode and local_deck_submitted: return
	var pair: Array = decks[draft_player][tier - 1]
	if id in pair:
		pair.erase(id)
	elif pair.size() < 2:
		pair.append(id)
	else:
		info = "선택된 카드 하나를 먼저 제외하세요. 각 위치에는 두 장이 필요합니다."
	render()

func confirm_draft() -> void:
	info = ""
	if online_mode:
		local_deck_submitted = true
		if online_host:
			if remote_deck_submitted:
				start_online_match()
			else:
				online_notice = "내 덱을 제출했습니다. 상대 덱 제출을 기다리는 중…"
				render()
		else:
			room_signaling.send_game("submit_deck", {"deck": decks[local_player]})
			online_notice = "덱을 제출했습니다. 호스트가 대전을 시작할 때까지 기다려 주세요."
			render()
		return
	if draft_player == 0 and not ai_enabled:
		draft_player = 1
		render()
	else:
		begin_game()

func begin_game() -> void:
	auto_timer.stop()
	ai_timer.stop()
	ai = TCGFieldAI.new() if ai_difficulty == "hard" else TCGRandomAI.new()
	if ai_enabled:
		decks[1] = ai.random_deck()
	# Quick start also fills any incomplete pair back to its default.
	for p in range(2):
		for t in range(6):
			if decks[p][t].size() != 2:
				var pool := TCGCards.pool(t + 1)
				decks[p][t] = [pool[0].id, pool[1].id]
	drafting = false
	selection = {}
	info = ""
	battle.start(decks)
	covered = privacy and not ai_enabled
	battle.presentation_enabled = effects_enabled
	render()

