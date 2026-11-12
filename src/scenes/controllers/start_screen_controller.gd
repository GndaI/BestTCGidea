extends "res://src/scenes/controllers/app_controller.gd"

func main_menu_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := button_at(parent, text, callback)
	button.custom_minimum_size = Vector2(480, 86)
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	button.add_theme_color_override("font_color", Color("f7f9fd"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_stylebox_override("normal", box(MENU_BUTTON, Color("496684")))
	button.add_theme_stylebox_override("hover", box(MENU_BUTTON_HOVER, Color("5d789a")))
	button.add_theme_stylebox_override("pressed", box(MENU_BUTTON_PRESSED, GOLD.darkened(0.25)))
	return button

func back_button_at(parent: Node, callback: Callable) -> Button:
	var button := button_at(parent, "← 뒤로", callback)
	button.name = "BackButton"
	button.custom_minimum_size = Vector2(150, 48)
	button.add_theme_font_size_override("font_size", 18)
	if parent is Control and not parent is Container:
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = 0
		button.offset_right = 150
		button.offset_top = 16
		button.offset_bottom = 64
	return button

func render_main_menu() -> void:
	var screen = MainMenuScene.instantiate()
	screen.action_requested.connect(_on_main_menu_action)
	root.add_child(screen)

func _render_in_screen(screen_scene: PackedScene, renderer: Callable) -> void:
	var screen_host := root
	var screen := screen_scene.instantiate()
	screen_host.add_child(screen)
	var content := screen.get_node("Content") as VBoxContainer
	root = content
	renderer.call()
	root = screen_host

func _on_main_menu_action(action: String) -> void:
	match action:
		"battle": open_battle_menu()
		"decks": open_deck_menu()
		"rules": show_rules()
		"settings": show_settings()
		"account": open_account()
		"patch_notes": open_patch_notes()

func render_patch_notes() -> void:
	_render_in_screen(PatchNotesScreenScene, _render_patch_notes_content)

func _render_patch_notes_content() -> void:
	screen_header_at("패치노트", back_to_main_menu)
	var page := MarginContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("margin_left", 170)
	page.add_theme_constant_override("margin_right", 170)
	page.add_theme_constant_override("margin_top", 12)
	page.add_theme_constant_override("margin_bottom", 40)
	root.add_child(page)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(PANEL, Color("344d6b")))
	page.add_child(panel)
	var panel_layout := VBoxContainer.new()
	panel_layout.add_theme_constant_override("separation", 8)
	panel.add_child(panel_layout)
	var version_toolbar := HBoxContainer.new()
	version_toolbar.alignment = BoxContainer.ALIGNMENT_END
	panel_layout.add_child(version_toolbar)
	var version_menu := MenuButton.new()
	version_menu.name = "PatchVersionMenu"
	version_menu.text = "버전 찾기 ▼"
	version_menu.tooltip_text = "원하는 버전의 패치 내용으로 바로 이동합니다."
	version_menu.custom_minimum_size = Vector2(210, 44)
	version_menu.add_theme_font_size_override("font_size", 18)
	version_toolbar.add_child(version_menu)
	var scroll_row := HBoxContainer.new()
	scroll_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_row.add_theme_constant_override("separation", 0)
	panel_layout.add_child(scroll_row)
	var scroll := ScrollContainer.new()
	scroll.name = "PatchNotesScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_row.add_child(scroll)
	var scroll_marker_slot := Control.new()
	scroll_marker_slot.custom_minimum_size.x = 104
	scroll_marker_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_row.add_child(scroll_marker_slot)
	var scroll_marker := PanelContainer.new()
	scroll_marker.name = "PatchScrollPositionMarker"
	scroll_marker.custom_minimum_size = Vector2(96, 54)
	scroll_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_marker.modulate.a = 0.0
	scroll_marker.add_theme_stylebox_override("panel", box(Color("182a43"), Color("76dbbc")))
	scroll_marker_slot.add_child(scroll_marker)
	var scroll_marker_label := label_at(scroll_marker, "", 17, Color("dffcf3"))
	scroll_marker_label.name = "PatchScrollPositionLabel"
	scroll_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll_marker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scroll_marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll_marker_timer := Timer.new()
	scroll_marker_timer.name = "PatchScrollMarkerHideTimer"
	scroll_marker_timer.one_shot = true
	scroll_marker_timer.wait_time = 0.8
	panel_layout.add_child(scroll_marker_timer)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	scroll.add_child(margin)
	var notes := VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_constant_override("separation", 16)
	margin.add_child(notes)
	var latest := label_at(notes, "최근 업데이트", MENU_FONT_SIZE, GOLD)
	latest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var version_targets: Array[Control] = []
	var scroll_version_anchors: Array[Dictionary] = []
	if not PATCH_NOTES.is_empty():
		var latest_entry := patch_note_from_data(notes, PATCH_NOTES[0], true)
		version_targets.append(latest_entry)
		scroll_version_anchors.append({"note_index": 0, "entry": latest_entry})
	var divider := HSeparator.new()
	divider.modulate = Color("526b89")
	notes.add_child(divider)
	var history := label_at(notes, "버전 기록", 24, MUTED)
	history.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for note_index in range(PATCH_NOTES.size()):
		var history_entry := patch_note_from_data(notes, PATCH_NOTES[note_index], note_index == 0)
		scroll_version_anchors.append({"note_index": note_index, "entry": history_entry})
		if note_index > 0:
			version_targets.append(history_entry)
	var version_popup := version_menu.get_popup()
	for note_index in range(PATCH_NOTES.size()):
		var note: Dictionary = PATCH_NOTES[note_index]
		var menu_text := ("최신 · " if note_index == 0 else "") + str(note.get("version", "")) + " — " + str(note.get("summary", ""))
		version_popup.add_check_item(menu_text, note_index)
		version_popup.set_item_checked(note_index, note_index == 0)
	var marker_state := {"fade_tween": null}
	var show_scroll_position := func(scroll_value: float):
		var current_note := 0
		var probe_y := scroll_value + scroll.size.y * 0.5
		var nearest_distance := INF
		for anchor in scroll_version_anchors:
			var entry: Control = anchor["entry"]
			var entry_center := entry.position.y + entry.size.y * 0.5
			var distance := absf(entry_center - probe_y)
			if distance < nearest_distance:
				nearest_distance = distance
				current_note = int(anchor["note_index"])
		var current_version := str(PATCH_NOTES[current_note].get("version", ""))
		scroll_marker_label.text = current_version + ("\n최신" if current_note == 0 else "")
		for item_index in range(version_popup.item_count):
			version_popup.set_item_checked(item_index, item_index == current_note)
		version_menu.text = current_version + " 보는 중 ▼"
		var vertical_bar := scroll.get_v_scroll_bar()
		var scroll_range := maxf(vertical_bar.max_value - vertical_bar.page, 1.0)
		var track_height := maxf(scroll_marker_slot.size.y - scroll_marker.size.y, 0.0)
		scroll_marker.position = Vector2(4, track_height * clampf(scroll_value / scroll_range, 0.0, 1.0))
		var previous_tween: Tween = marker_state["fade_tween"]
		if is_instance_valid(previous_tween):
			previous_tween.kill()
		marker_state["fade_tween"] = null
		scroll_marker.modulate.a = 1.0
		scroll_marker_timer.start()
	scroll.get_v_scroll_bar().value_changed.connect(show_scroll_position)
	scroll_marker_timer.timeout.connect(func():
		var fade_tween := create_tween()
		marker_state["fade_tween"] = fade_tween
		fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(scroll_marker, "modulate:a", 0.0, 0.65)
	)
	version_popup.id_pressed.connect(func(note_index: int):
		if note_index < 0 or note_index >= version_targets.size():
			return
		version_menu.text = str(PATCH_NOTES[note_index].get("version", "")) + " 보는 중 ▼"
		scroll.ensure_control_visible(version_targets[note_index])
	)

func patch_note_from_data(parent: Node, note: Dictionary, is_latest: bool = false) -> Control:
	return patch_note_entry(
		parent,
		str(note.get("version", "")),
		str(note.get("date", "")),
		str(note.get("summary", "")),
		int(note.get("summary_size", 22)),
		Color(str(note.get("summary_color", "edf4ff"))),
		note.get("overview", []),
		bool(note.get("show_developer_note", false)),
		note.get("developer_note", []),
		note.get("sections", []),
		Color(str(note.get("accent", "9aa9bc"))),
		is_latest
	)

func patch_note_entry(parent: Node, version: String, patch_date: String, title_text: String, title_size: int, title_color: Color, overview: Array, show_developer_note: bool, developer_note: Array, sections: Array, accent: Color, is_latest: bool = false) -> Control:
	var entry := PanelContainer.new()
	entry.name = "PatchNoteVersion" + version.replace(".", "_") + ("Latest" if is_latest else "")
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entry_style := box(Color("111d31"), Color(accent, 0.7))
	entry_style.set_border_width_all(2)
	entry.add_theme_stylebox_override("panel", entry_style)
	parent.add_child(entry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	entry.add_child(row)
	var version_badge := PanelContainer.new()
	version_badge.custom_minimum_size = Vector2(142, 90 if is_latest else 78)
	version_badge.add_theme_stylebox_override("panel", box(Color(accent, 0.12), accent))
	row.add_child(version_badge)
	var badge_content := VBoxContainer.new()
	badge_content.alignment = BoxContainer.ALIGNMENT_CENTER
	version_badge.add_child(badge_content)
	var version_label := label_at(badge_content, version, 26, accent)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_latest:
		var latest_label := label_at(badge_content, "최신", 15, Color("76dbbc"))
		latest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	row.add_child(content)
	if not patch_date.is_empty():
		label_at(content, "패치 날짜: " + patch_date, 18, Color("9fb0c5"))
	label_at(content, title_text, title_size, title_color)
	if not overview.is_empty():
		var overview_text := "\n".join(overview.map(func(line): return str(line)))
		var overview_label := label_at(content, overview_text, 20, Color("d9e4f2"))
		overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if show_developer_note:
		label_at(content, "개발자의 말:", 24, Color("f2b866"))
		if not developer_note.is_empty():
			var developer_text := "\n".join(developer_note.map(func(line): return str(line)))
			var developer_label := label_at(content, developer_text, 20, MUTED)
			developer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for section in sections:
		var category := label_at(content, str(section.get("category", "")), 24, accent)
		category.add_theme_constant_override("outline_size", 0)
		var active_item_kind := "change"
		for item in section.get("items", []):
			var item_text := str(item.get("text", "")) if item is Dictionary else str(item)
			var item_style := str(item.get("style", "")) if item is Dictionary else ""
			var item_kind := str(item.get("kind", "")) if item is Dictionary else _patch_note_item_kind(item_text)
			if item_style == "subheading":
				var subsection_color := Color("71b9ff")
				if item_kind == "add":
					subsection_color = Color("76db8f")
				elif item_kind == "remove":
					subsection_color = Color("ff6b72")
				var subsection := label_at(content, item_text, 23, subsection_color)
				subsection.name = "PatchSubheading" + item_kind.capitalize()
				subsection.add_theme_constant_override("outline_size", 0)
				continue
			if item_style == "card":
				active_item_kind = item_kind
				var card_name := label_at(content, item_text, 22, Color("c8b6ff"))
				card_name.add_theme_constant_override("outline_size", 0)
				continue
			var show_marker := bool(item.get("marker", true)) if item is Dictionary else true
			if item_style == "detail" and not show_marker:
				var detail_margin := MarginContainer.new()
				detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				detail_margin.add_theme_constant_override("margin_left", 30)
				content.add_child(detail_margin)
				var detail := label_at(detail_margin, item_text, 19, MUTED)
				detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				continue
			if item_style == "detail":
				if item_kind.is_empty():
					item_kind = active_item_kind
			var item_row := HBoxContainer.new()
			item_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_row.custom_minimum_size.y = 28
			item_row.add_theme_constant_override("separation", 2)
			content.add_child(item_row)
			var icon_color := Color("71b9ff")
			if item_kind == "add":
				icon_color = Color("76db8f")
			elif item_kind == "remove":
				icon_color = Color("ff6b72")
			var icon := PatchItemMarker.new()
			icon.name = "PatchItemIcon" + item_kind.capitalize()
			icon.marker_kind = item_kind
			icon.marker_color = icon_color
			icon.custom_minimum_size = Vector2(20, 20)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item_row.add_child(icon)
			var line_color := MUTED
			var line_size := 19 if item_style == "detail" else 20
			var line := label_at(item_row, item_text, line_size, line_color)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_EXPAND_FILL
			line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return entry

func _patch_note_item_kind(item_text: String) -> String:
	if "추가" in item_text:
		return "add"
	if "제거" in item_text or "빠짐" in item_text:
		return "remove"
	return "change"

func screen_header_at(title_text: String, back_callback: Callable) -> Control:
	var header := Control.new()
	header.custom_minimum_size.y = 140
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)
	back_button_at(header, back_callback)
	var title := label_at(header, title_text, TITLE_FONT_SIZE, GOLD)
	title.name = "ScreenTitle"
	emphasize_label(title, 0.42)
	title.anchor_left = 0.2
	title.anchor_right = 0.8
	title.offset_top = 12
	title.offset_bottom = 136
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return header

func submenu_at(title_text: String, back_callback: Callable) -> VBoxContainer:
	screen_header_at(title_text, back_callback)
	var page := Control.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 18)
	center.add_child(menu)
	return menu

func render_battle_menu() -> void:
	var screen = BattleModeMenuScene.instantiate()
	screen.back_requested.connect(back_to_main_menu)
	screen.action_requested.connect(func(action: String):
		match action:
			"ai": open_game_mode_menu("ai")
			"local": open_game_mode_menu("local")
			"online": open_online_menu()
	)
	root.add_child(screen)

func render_game_mode_menu() -> void:
	_render_in_screen(GameModeSelectScreenScene, _render_game_mode_menu_content)

func _render_game_mode_menu_content() -> void:
	screen_header_at("게임 모드", back_to_battle_menu)
	var page := CenterContainer.new()
	page.name = "GameModeSelectPage"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 420)
	panel.add_theme_stylebox_override("panel", box(PANEL, Color("3b5472")))
	page.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	panel.add_child(content)
	var battle_type_label := label_at(content, "AI 대전" if pending_battle_type == "ai" else "로컬 대전", MENU_FONT_SIZE, GOLD)
	battle_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_at(content, "게임 모드", 19, Color("ecf2fc"))
	var mode_select := OptionButton.new()
	mode_select.name = "OfflineGameModeSelect"
	mode_select.custom_minimum_size.y = 62
	selected_game_mode = GameModesScript.normalize(selected_game_mode)
	var selected_mode_index := 0
	for mode in GameModesScript.all():
		var mode_index := mode_select.item_count
		mode_select.add_item(str(mode.name))
		mode_select.set_item_metadata(mode_index, str(mode.id))
		if str(mode.id) == selected_game_mode:
			selected_mode_index = mode_index
	mode_select.select(selected_mode_index)
	content.add_child(mode_select)
	var description := label_at(content, GameModesScript.description(selected_game_mode), 18, MUTED)
	description.name = "OfflineGameModeDescription"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_select.item_selected.connect(func(index):
		selected_game_mode = GameModesScript.normalize(str(mode_select.get_item_metadata(index)))
		description.text = GameModesScript.description(selected_game_mode)
	)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var next_text := "AI 난이도 선택" if pending_battle_type == "ai" else "덱 선택"
	var confirm_button := main_menu_button(content, next_text, confirm_game_mode_selection)
	confirm_button.name = "ConfirmGameModeButton"
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func render_ai_menu() -> void:
	var screen = AIModeMenuScene.instantiate()
	screen.back_requested.connect(back_to_game_mode_menu)
	screen.action_requested.connect(func(action: String):
		match action:
			"ai_easy": start_ai_draft()
			"ai_hard": start_strong_ai_draft()
	)
	root.add_child(screen)

func render_online_menu() -> void:
	if online_state in ["lobby", "room_waiting"]:
		_render_in_screen(OnlineLobbyScreenScene, _render_online_lobby_content)
		return
	_render_in_screen(OnlineBrowserScreenScene, _render_online_menu_content)

func _render_online_menu_content() -> void:
	if online_state == "idle":
		screen_header_at("온라인", back_to_battle_menu)
		_render_online_browser_content()
		return
	var menu := submenu_at("온라인", back_to_battle_menu)
	menu.custom_minimum_size.x = 560
	if online_state == "room_joining":
		var joining := label_at(menu, "공개 방에 연결하는 중…", BODY_FONT_SIZE, GOLD)
		joining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "연결 취소", stop_network)
	elif online_state == "hosting":
		label_at(menu, "참가자를 기다리는 중", BODY_FONT_SIZE, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "대기 취소", stop_network)
	elif online_state == "connecting":
		label_at(menu, "온라인 서버에 연결 중…", BODY_FONT_SIZE, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "연결 취소", stop_network)
	else:
		label_at(menu, "온라인 연결 상태를 확인하고 있습니다.", BODY_FONT_SIZE, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not online_notice.is_empty():
		var notice := label_at(menu, online_notice, BODY_FONT_SIZE, Color("ffbd84"))
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func open_battle_menu() -> void:
	pending_battle_type = ""
	start_page = "battle"
	render()

func open_game_mode_menu(battle_type: String) -> void:
	if battle_type not in ["ai", "local"]:
		return
	pending_battle_type = battle_type
	start_page = "game_mode"
	render()

func confirm_game_mode_selection() -> void:
	current_game_mode = GameModesScript.normalize(selected_game_mode)
	if pending_battle_type == "ai":
		open_ai_menu()
	elif pending_battle_type == "local":
		start_local_draft()

func open_ai_menu() -> void:
	pending_battle_type = "ai"
	start_page = "ai"
	render()

func back_to_game_mode_menu() -> void:
	open_game_mode_menu("ai")

func open_online_menu() -> void:
	start_page = "online"
	online_notice = ""
	render()
	room_refresh_timer.start()
	fetch_public_rooms()

func open_patch_notes() -> void:
	start_page = "patch_notes"
	render()

func back_to_main_menu() -> void:
	room_refresh_timer.stop()
	start_page = "home"
	if online_state != "idle":
		stop_network()
	render()

func back_to_battle_menu() -> void:
	room_refresh_timer.stop()
	start_page = "battle"
	if online_state != "idle":
		stop_network()
	render()

func go_back_from_start_page() -> void:
	if start_page == "deck_editor":
		back_to_deck_library()
	elif start_page == "fate_deck_editor":
		back_to_fate_deck_library()
	elif start_page == "decks":
		back_from_deck_library()
	elif start_page in ["ai", "online"]:
		back_to_battle_menu()
	elif start_page in ["settings", "rules"]:
		back_from_info_screen()
	elif start_page in ["battle", "patch_notes", "account"]:
		back_to_main_menu()

func open_deck_menu() -> void:
	start_screen = true
	online_mode = false
	drafting = true
	deck_library_mode = "manage"
	start_page = "decks"
	editing_deck_index = -1
	deck_editor_notice = ""
	render()

func show_settings() -> void:
	_open_info_screen("settings")

func render_settings_screen() -> void:
	var screen = SettingsScreenScene.instantiate()
	screen.configure({"effects_enabled": effects_enabled, "auto_pass": auto_pass, "privacy": privacy})
	screen.back_requested.connect(back_from_info_screen)
	screen.setting_changed.connect(_on_setting_changed)
	root.add_child(screen)

func _on_setting_changed(setting_name: String, enabled: bool) -> void:
	match setting_name:
		"effects_enabled": effects_enabled = enabled
		"auto_pass": auto_pass = enabled
		"privacy": privacy = enabled

func _open_info_screen(page: String) -> void:
	if start_page not in ["settings", "rules"]:
		info_return_start_screen = start_screen
		info_return_page = start_page
	playing_effects = false
	battle.visual_events.clear()
	if is_instance_valid(effect_blocker):
		effect_blocker.hide()
	info_screen_active = true
	start_page = page
	render()

func back_from_info_screen() -> void:
	info_screen_active = false
	start_screen = info_return_start_screen
	start_page = info_return_page
	render()

func show_rules() -> void:
	_open_info_screen("rules")

func render_rules_screen() -> void:
	var screen = RulesScreenScene.instantiate()
	screen.back_requested.connect(back_from_info_screen)
	root.add_child(screen)
