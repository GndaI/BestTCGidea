extends "res://src/scenes/controllers/account_screen_controller.gd"

func _render_online_browser_content() -> void:
	# The public room browser intentionally owns the whole online page. Private
	# room codes are no longer part of the player-facing flow.
	var body := HBoxContainer.new()
	body.name = "OnlineBrowser"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)

	var room_panel := PanelContainer.new()
	room_panel.custom_minimum_size.x = 850
	room_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_panel.add_theme_stylebox_override("panel", box(Color("101b2e"), Color("3b5472")))
	body.add_child(room_panel)
	var room_col := VBoxContainer.new()
	room_col.add_theme_constant_override("separation", 14)
	room_panel.add_child(room_col)
	var room_header := row_at(room_col)
	var public_title := label_at(room_header, "공개 방", MENU_FONT_SIZE, GOLD)
	emphasize_label(public_title, 0.35)
	var refresh_note := label_at(room_header, "↻ 10초마다 자동 갱신", 17, MUTED)
	refresh_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	refresh_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var wake_note := label_at(room_col, "무료 서버가 쉬는 중이면 첫 연결만 최대 1분 걸릴 수 있습니다.", 16, MUTED)
	wake_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var room_scroll := ScrollContainer.new()
	room_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	room_col.add_child(room_scroll)
	public_room_list_box = VBoxContainer.new()
	public_room_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_room_list_box.add_theme_constant_override("separation", 12)
	room_scroll.add_child(public_room_list_box)
	public_room_list_status = label_at(room_col, "", 17, MUTED)
	public_room_list_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rebuild_public_room_list()

	var create_panel := PanelContainer.new()
	create_panel.custom_minimum_size.x = 420
	create_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	create_panel.add_theme_stylebox_override("panel", box(Color("101b2e"), Color("3b5472")))
	body.add_child(create_panel)
	var create_col := VBoxContainer.new()
	create_col.add_theme_constant_override("separation", 20)
	create_panel.add_child(create_col)
	var create_title := label_at(create_col, "방 만들기", MENU_FONT_SIZE, GOLD)
	emphasize_label(create_title, 0.35)
	var name_label := label_at(create_col, "방 이름", 18, Color("ecf2fc"))
	public_room_name_edit = LineEdit.new()
	public_room_name_edit.name = "PublicRoomNameEdit"
	public_room_name_edit.text = public_room_name
	public_room_name_edit.placeholder_text = "방 이름"
	public_room_name_edit.max_length = 20
	public_room_name_edit.custom_minimum_size.y = 58
	public_room_name_edit.text_changed.connect(func(value): public_room_name = value)
	public_room_name_edit.text_submitted.connect(func(_value): create_public_web_room())
	create_col.add_child(public_room_name_edit)
	label_at(create_col, "게임 모드", 18, Color("ecf2fc"))
	public_room_mode_select = OptionButton.new()
	public_room_mode_select.name = "PublicRoomModeSelect"
	public_room_mode_select.custom_minimum_size.y = 58
	selected_game_mode = GameModesScript.normalize(selected_game_mode)
	var selected_mode_index := 0
	for mode in GameModesScript.all():
		var mode_index := public_room_mode_select.item_count
		public_room_mode_select.add_item(str(mode.name))
		public_room_mode_select.set_item_metadata(mode_index, str(mode.id))
		if str(mode.id) == selected_game_mode:
			selected_mode_index = mode_index
	public_room_mode_select.select(selected_mode_index)
	create_col.add_child(public_room_mode_select)
	var mode_description := label_at(create_col, GameModesScript.description(selected_game_mode), 16, MUTED)
	mode_description.name = "PublicRoomModeDescription"
	mode_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	public_room_mode_select.item_selected.connect(func(index):
		selected_game_mode = GameModesScript.normalize(str(public_room_mode_select.get_item_metadata(index)))
		mode_description.text = GameModesScript.description(selected_game_mode)
	)
	var create_button := button_at(create_col, "방 만들기", create_public_web_room)
	create_button.name = "CreatePublicRoomButton"
	create_button.custom_minimum_size.y = 72
	create_button.add_theme_font_size_override("font_size", 24)
	create_button.add_theme_stylebox_override("normal", box(Color("3d3426"), GOLD.darkened(0.2)))
	if not online_notice.is_empty():
		var notice := label_at(create_col, online_notice, 17, Color("ffbd84"))
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	create_col.add_child(spacer)
	var connection := label_at(create_col, "● 서버 연결됨", 17, GREEN)
	connection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _render_online_lobby_content() -> void:
	screen_header_at("대기방", stop_network)
	var lobby := HBoxContainer.new()
	lobby.name = "OnlineLobby"
	lobby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby.add_theme_constant_override("separation", 22)
	root.add_child(lobby)
	var players_panel := PanelContainer.new()
	players_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_panel.add_theme_stylebox_override("panel", box(Color("101b2e"), Color("3b5472")))
	lobby.add_child(players_panel)
	var players_col := VBoxContainer.new()
	players_col.add_theme_constant_override("separation", 18)
	players_panel.add_child(players_col)
	var room_name := current_room_name if not current_room_name.is_empty() else "온라인 대기방"
	var name_label := label_at(players_col, room_name, MENU_FONT_SIZE, Color("c7d2e3"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var guest_connected := remote_peer_id > 0 or online_state == "lobby"
	_online_player_panel(players_col, 1, true, true, true, online_host)
	_online_player_panel(players_col, 2, guest_connected, remote_lobby_ready if online_host else local_lobby_ready, false, not online_host)
	var players_spacer := Control.new()
	players_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_col.add_child(players_spacer)

	var settings_panel := PanelContainer.new()
	settings_panel.custom_minimum_size.x = 420
	settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_panel.add_theme_stylebox_override("panel", box(Color("101b2e"), Color("3b5472")))
	lobby.add_child(settings_panel)
	var settings_col := VBoxContainer.new()
	settings_col.add_theme_constant_override("separation", 14)
	settings_panel.add_child(settings_col)
	var settings_title := label_at(settings_col, "게임 설정", MENU_FONT_SIZE, GOLD)
	emphasize_label(settings_title, 0.35)
	_online_setting_row(settings_col, "게임 모드", GameModesScript.display_name(current_game_mode))
	_online_setting_row(settings_col, "덱 구성", "방에서 선택")
	_online_setting_row(settings_col, "관전자", "없음")
	var settings_spacer := Control.new()
	settings_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_col.add_child(settings_spacer)
	if online_host:
		var start_button := button_at(settings_col, "덱 구성 시작", begin_online_draft, not guest_connected or not remote_lobby_ready)
		start_button.name = "StartOnlineDraftButton"
		start_button.custom_minimum_size.y = 76
		start_button.add_theme_font_size_override("font_size", 24)
	else:
		var waiting := button_at(settings_col, "방장이 시작하기를 기다리는 중…", func(): pass, true)
		waiting.custom_minimum_size.y = 76
	var status_text := "1/2명 접속 · 참가자를 기다리고 있습니다" if not guest_connected else ("2/2명 접속 · 모두 준비하면 시작할 수 있습니다" if not (remote_lobby_ready if online_host else local_lobby_ready) else "2/2명 접속 · 덱 구성을 시작할 수 있습니다")
	var status := label_at(root, "● %s" % status_text, 18, GREEN if guest_connected else MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _online_player_panel(parent: Node, player_number: int, connected: bool, ready: bool, is_host: bool, is_local: bool) -> void:
	var shell := PanelContainer.new()
	shell.custom_minimum_size.y = 174
	shell.add_theme_stylebox_override("panel", box(Color("14243b"), GOLD if is_host else BLUE))
	parent.add_child(shell)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	shell.add_child(row)
	var connection := label_at(row, "●\n%s" % ("접속됨" if connected else "대기 중"), 16, GREEN if connected else MUTED)
	connection.custom_minimum_size.x = 86
	connection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var avatar := Label.new()
	avatar.text = "●"
	avatar.custom_minimum_size = Vector2(92, 92)
	avatar.add_theme_font_size_override("font_size", 72)
	avatar.add_theme_color_override("font_color", GOLD if is_host else (BLUE if connected else MUTED))
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(avatar)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 230
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(identity)
	label_at(identity, "플레이어 %d" % player_number, 25, Color("f3f6fc") if connected else MUTED)
	label_at(identity, "♛ 방장" if is_host else ("참가자" if connected else "빈 자리"), 18, GOLD if is_host else MUTED)
	var deck_icons := label_at(row, "▣  ▣  ▣" if connected else "□  □  □", 30, Color("b8c5d8") if connected else MUTED)
	deck_icons.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_icons.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_local and not is_host and connected:
		var ready_button := button_at(row, "준비 취소" if ready else "준비", toggle_online_ready)
		ready_button.name = "OnlineReadyButton"
		ready_button.custom_minimum_size = Vector2(180, 66)
		ready_button.add_theme_font_size_override("font_size", 22)
	else:
		var state := label_at(row, "준비 완료" if ready else ("대기 중" if connected else "참가자 대기 중"), 22, GREEN if ready else MUTED)
		state.custom_minimum_size.x = 180
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _online_setting_row(parent: Node, title_text: String, value_text: String) -> void:
	var shell := PanelContainer.new()
	shell.custom_minimum_size.y = 76
	shell.add_theme_stylebox_override("panel", box(Color("14243b"), Color("2f4664")))
	parent.add_child(shell)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	shell.add_child(row)
	var title := label_at(row, title_text, 18, MUTED)
	var value := label_at(row, value_text, 19, Color("f3f6fc"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func start_ai_draft() -> void:
	ai_difficulty = "easy"
	_start_ai_draft()

func start_strong_ai_draft() -> void:
	ai_difficulty = "hard"
	_start_ai_draft()

func _start_ai_draft() -> void:
	start_screen = true
	online_mode = false
	ai_enabled = true
	drafting = true
	draft_player = 0
	deck_library_mode = "ai"
	start_page = "decks"
	editing_deck_index = -1
	deck_editor_notice = ""
	render()

func start_local_draft() -> void:
	start_screen = true
	online_mode = false
	ai_enabled = false
	drafting = true
	draft_player = 0
	reset_decks()
	deck_library_mode = "local"
	start_page = "decks"
	editing_deck_index = -1
	deck_editor_notice = ""
	render()

func start_host() -> void:
	if port_edit != null and port_edit.text.is_valid_int(): online_port = int(port_edit.text)
	if online_port < 1 or online_port > 65535:
		online_notice = "포트는 1~65535 사이 숫자로 입력하세요."
		render()
		return
	if OS.has_feature("web"):
		online_notice = "브라우저는 서버를 직접 열 수 없습니다. 웹 방 참가를 이용하세요."
		render()
		return
	var peer := WebSocketMultiplayerPeer.new()
	var result := peer.create_server(online_port)
	if result != OK:
		online_notice = "웹 테스트 서버를 열지 못했습니다. 포트가 사용 중인지 확인하세요. (%s)" % error_string(result)
		render()
		return
	multiplayer.multiplayer_peer = peer
	online_mode = true
	online_host = true
	local_player = 0
	online_state = "hosting"
	online_notice = ""
	render()

func signaling_url() -> String:
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/signal'", true)
		if value != null and not str(value).is_empty():
			return str(value)
	var base := _normalized_online_server_address()
	if base.begins_with("https://"):
		return "wss://" + base.trim_prefix("https://") + "/signal"
	return "ws://" + base.trim_prefix("http://") + "/signal"

func rooms_url() -> String:
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval("location.origin + '/rooms'", true)
		if value != null and not str(value).is_empty():
			return str(value)
	return _normalized_online_server_address() + "/rooms"

func _normalized_online_server_address() -> String:
	var value := online_server_address.strip_edges()
	while value.ends_with("/"):
		value = value.trim_suffix("/")
	return value if not value.is_empty() else DEFAULT_ONLINE_SERVER

func _load_online_server_address() -> void:
	if not FileAccess.file_exists(ONLINE_SERVER_PATH):
		return
	var value := FileAccess.get_file_as_string(ONLINE_SERVER_PATH).strip_edges()
	if "trycloudflare.com" in value or value in ["http://127.0.0.1:8000", "http://localhost:8000"]:
		online_server_address = DEFAULT_ONLINE_SERVER
		_write_online_server_address()
		return
	if value.begins_with("http://") or value.begins_with("https://"):
		online_server_address = value

func _write_online_server_address() -> void:
	var file := FileAccess.open(ONLINE_SERVER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(online_server_address)

func apply_online_server_address() -> void:
	var value := online_server_edit.text.strip_edges() if is_instance_valid(online_server_edit) else online_server_address
	while value.ends_with("/"):
		value = value.trim_suffix("/")
	if not value.begins_with("http://") and not value.begins_with("https://"):
		online_notice = "서버 주소는 http:// 또는 https://로 시작해야 합니다."
		render()
		return
	if room_list_request_busy:
		room_list_request.cancel_request()
		room_list_request_busy = false
	online_server_address = value
	_write_online_server_address()
	public_rooms.clear()
	online_notice = "서버 주소를 적용했습니다."
	render()
	fetch_public_rooms()

func fetch_public_rooms() -> void:
	if start_page != "online" or online_state != "idle" or room_list_request_busy:
		return
	room_list_request_busy = true
	if is_instance_valid(public_room_list_status):
		public_room_list_status.text = "서버와 방 목록을 확인하는 중…"
	var error := room_list_request.request(rooms_url())
	if error != OK:
		room_list_request_busy = false
		if is_instance_valid(public_room_list_status):
			public_room_list_status.text = "방 목록을 불러오지 못했습니다."

func _on_room_list_received(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	room_list_request_busy = false
	if response_code != 200:
		if is_instance_valid(public_room_list_status):
			public_room_list_status.text = "서버를 깨우는 중일 수 있습니다. 10초 뒤 다시 시도합니다."
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if not payload is Dictionary or not payload.get("rooms", []) is Array:
		if is_instance_valid(public_room_list_status):
			public_room_list_status.text = "방 목록 응답을 읽지 못했습니다."
		return
	public_rooms = payload.get("rooms", [])
	_rebuild_public_room_list()
	if is_instance_valid(public_room_list_status):
		public_room_list_status.text = "방 %d개 · 10초마다 자동 갱신" % public_rooms.size()

func _rebuild_public_room_list() -> void:
	if not is_instance_valid(public_room_list_box):
		return
	for child in public_room_list_box.get_children():
		child.queue_free()
	if public_rooms.is_empty():
		var empty := label_at(public_room_list_box, "현재 참가할 수 있는 공개 방이 없습니다.", 16, MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	for room_data in public_rooms:
		if not room_data is Dictionary:
			continue
		var code := str(room_data.get("code", ""))
		var players := int(room_data.get("players", 0))
		var waiting := str(room_data.get("status", "")) == "waiting" and players < 2
		var room_name := str(room_data.get("name", "이름 없는 방"))
		var game_mode := GameModesScript.display_name(str(room_data.get("mode", GameModesScript.DEFAULT_ID)))
		var shell := PanelContainer.new()
		shell.custom_minimum_size.y = 112
		shell.add_theme_stylebox_override("panel", box(Color("14243b"), Color("38516e")))
		public_room_list_box.add_child(shell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		shell.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_label := label_at(info, room_name, 23, Color("f3f6fc"))
		emphasize_label(name_label, 0.24)
		var seats := "●  ○" if players == 1 else ("●  ●" if players >= 2 else "○  ○")
		label_at(info, "%s · %s    %d/2명" % [game_mode, seats, players], 18, GOLD if waiting else MUTED)
		var state_text := "참가" if waiting else "진행 중"
		var room_button := button_at(row, state_text, join_public_room.bind(code), not waiting)
		room_button.custom_minimum_size = Vector2(160, 62)
		room_button.add_theme_font_size_override("font_size", 21)

func create_public_web_room() -> void:
	var room_name := public_room_name_edit.text.strip_edges() if public_room_name_edit != null else public_room_name.strip_edges()
	if room_name.is_empty():
		online_notice = "공개 방 이름을 입력해주세요."
		render()
		return
	public_room_name = room_name
	current_room_name = room_name
	current_game_mode = GameModesScript.normalize(selected_game_mode)
	local_lobby_ready = true
	remote_lobby_ready = false
	room_refresh_timer.stop()
	online_notice = ""
	current_room_code = ""
	online_state = "connecting"
	render()
	room_signaling.create_public_room(signaling_url(), room_name, current_game_mode)

func join_public_room(code: String) -> void:
	if code.length() != 6:
		return
	room_refresh_timer.stop()
	online_notice = ""
	current_room_code = code
	current_room_name = ""
	current_game_mode = GameModesScript.DEFAULT_ID
	for room_data in public_rooms:
		if room_data is Dictionary and str(room_data.get("code", "")) == code:
			current_room_name = str(room_data.get("name", ""))
			current_game_mode = GameModesScript.normalize(str(room_data.get("mode", GameModesScript.DEFAULT_ID)))
			break
	local_lobby_ready = false
	remote_lobby_ready = true
	online_state = "connecting"
	render()
	room_signaling.join_room(signaling_url(), code)

func _on_room_identity_ready(peer_id: int, code: String) -> void:
	current_room_code = code
	online_mode = true
	online_host = peer_id == 1
	local_player = 0 if online_host else 1
	local_lobby_ready = online_host
	remote_lobby_ready = not online_host
	online_state = "room_waiting" if online_host else "room_joining"
	online_notice = ""
	render()

func _on_room_status_changed(message: String) -> void:
	online_notice = message

func _on_room_failed(message: String) -> void:
	online_mode = false
	online_host = false
	online_state = "idle"
	current_room_code = ""
	current_room_name = ""
	current_game_mode = GameModesScript.DEFAULT_ID
	local_lobby_ready = false
	remote_lobby_ready = false
	online_notice = message
	render()

func _on_room_peer_connected(peer_id: int) -> void:
	remote_peer_id = peer_id
	if not online_host or online_state not in ["room_waiting", "hosting"]:
		return
	online_state = "lobby"
	start_screen = true
	drafting = true
	ai_enabled = false
	draft_player = local_player
	reset_decks()
	local_deck_submitted = false
	remote_deck_submitted = false
	local_lobby_ready = true
	remote_lobby_ready = false
	room_signaling.send_game("enter_lobby", {"name": current_room_name, "mode": current_game_mode})
	render()

func _on_room_peer_disconnected(peer_id: int) -> void:
	if peer_id != remote_peer_id:
		return
	_on_peer_disconnected(peer_id)

func _on_room_connection_lost(message: String) -> void:
	if online_state in ["connecting", "room_waiting", "room_joining"]:
		_on_room_failed(message)
	else:
		_on_server_disconnected()
		online_notice = message
		render()

func _on_room_game_message(kind: String, payload: Variant) -> void:
	var guest_to_host := kind in ["ready_state", "submit_deck", "intent", "request_state"]
	var host_to_guest := kind in ["enter_lobby", "start_draft", "state"]
	if (online_host and not guest_to_host) or (not online_host and not host_to_guest):
		return
	match kind:
		"enter_lobby":
			_rpc_enter_online_lobby(payload)
		"ready_state":
			if online_host and payload is bool:
				remote_lobby_ready = payload
				render()
		"start_draft":
			_rpc_start_online_draft()
		"submit_deck":
			if payload is Dictionary and payload.get("deck", []) is Array:
				_rpc_submit_online_deck(payload.get("deck", []))
		"intent":
			if payload is Dictionary:
				_rpc_submit_online_intent(payload)
		"state":
			if payload is Dictionary:
				_rpc_receive_online_state(payload)
		"request_state":
			_rpc_request_online_state()

func start_join() -> void:
	if address_edit != null and not address_edit.text.strip_edges().is_empty(): join_address = address_edit.text.strip_edges()
	if not join_address.begins_with("ws://") and not join_address.begins_with("wss://"):
		online_notice = "서버 주소는 ws:// 또는 wss://로 시작해야 합니다."
		render()
		return
	var peer := WebSocketMultiplayerPeer.new()
	var result := peer.create_client(join_address)
	if result != OK:
		online_notice = "접속을 시작하지 못했습니다. WebSocket 서버 주소를 확인하세요. (%s)" % error_string(result)
		render()
		return
	multiplayer.multiplayer_peer = peer
	online_mode = true
	online_host = false
	local_player = 1
	online_state = "connecting"
	online_notice = ""
	render()

func stop_network() -> void:
	if is_instance_valid(sync_timer): sync_timer.stop()
	if room_signaling != null:
		room_signaling.stop()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	online_mode = false
	online_host = false
	online_state = "idle"
	current_room_code = ""
	current_room_name = ""
	current_game_mode = GameModesScript.DEFAULT_ID
	remote_peer_id = 0
	local_lobby_ready = false
	remote_lobby_ready = false
	local_deck_submitted = false
	remote_deck_submitted = false
	waiting_for_sync = false
	sync_retry_count = 0
	start_screen = true
	drafting = true
	selection.clear()
	reset_decks()
	render()
	if start_page == "online":
		room_refresh_timer.start()
		fetch_public_rooms()

func _on_peer_connected(id: int) -> void:
	if not online_host or online_state not in ["hosting", "room_waiting"]: return
	remote_peer_id = id
	multiplayer.multiplayer_peer.refuse_new_connections = true
	online_state = "lobby"
	start_screen = true
	drafting = true
	ai_enabled = false
	draft_player = local_player
	reset_decks()
	local_deck_submitted = false
	remote_deck_submitted = false
	rpc_id(id, "_rpc_enter_online_lobby")
	render()

func _on_peer_disconnected(id: int) -> void:
	if id != remote_peer_id: return
	if is_instance_valid(sync_timer): sync_timer.stop()
	online_state = "disconnected"
	online_notice = "상대 연결이 끊어졌습니다. 대전을 계속할 수 없습니다."
	waiting_for_sync = false
	sync_retry_count = 0
	selection.clear()
	drag_source.clear()
	drag_moved = false
	action_menu_open = false
	render()

func _on_connected_to_server() -> void:
	local_player = 1
	online_state = "connecting"
	online_notice = "호스트에 연결되었습니다. 대전 설정을 기다리는 중…"
	render()

func _on_connection_failed() -> void:
	online_state = "idle"
	online_mode = false
	online_host = false
	online_notice = "연결에 실패했습니다. WebSocket 서버 주소와 ws/wss 설정을 확인하세요."
	selection.clear()
	drag_source.clear()
	drag_moved = false
	action_menu_open = false
	multiplayer.multiplayer_peer = null
	render()

func _on_server_disconnected() -> void:
	if is_instance_valid(sync_timer): sync_timer.stop()
	online_state = "disconnected"
	online_notice = "호스트 연결이 끊어졌습니다."
	waiting_for_sync = false
	sync_retry_count = 0
	selection.clear()
	drag_source.clear()
	drag_moved = false
	action_menu_open = false
	render()

@rpc("authority", "call_remote", "reliable")
func _rpc_enter_online_lobby(payload: Variant = {}) -> void:
	online_mode = true
	online_host = false
	local_player = 1
	online_state = "lobby"
	if payload is Dictionary:
		current_room_name = str(payload.get("name", current_room_name))
		current_game_mode = GameModesScript.normalize(str(payload.get("mode", current_game_mode)))
	start_screen = true
	drafting = true
	ai_enabled = false
	draft_player = local_player
	local_deck_submitted = false
	remote_deck_submitted = false
	local_lobby_ready = false
	remote_lobby_ready = true
	online_notice = "호스트와 연결되었습니다."
	render()

func toggle_online_ready() -> void:
	if online_host or online_state != "lobby" or remote_peer_id <= 0:
		return
	local_lobby_ready = not local_lobby_ready
	room_signaling.send_game("ready_state", local_lobby_ready)
	render()

func begin_online_draft() -> void:
	if not online_host or online_state != "lobby" or remote_peer_id <= 0 or not remote_lobby_ready: return
	room_signaling.seal_room()
	online_state = "draft"
	start_screen = true
	drafting = true
	draft_player = local_player
	reset_decks()
	local_deck_submitted = false
	remote_deck_submitted = false
	deck_library_mode = "online"
	start_page = "decks"
	editing_deck_index = -1
	room_signaling.send_game("start_draft")
	render()

@rpc("authority", "call_remote", "reliable")
func _rpc_start_online_draft() -> void:
	online_mode = true
	online_host = false
	local_player = 1
	online_state = "draft"
	start_screen = true
	drafting = true
	ai_enabled = false
	draft_player = local_player
	reset_decks()
	local_deck_submitted = false
	remote_deck_submitted = false
	deck_library_mode = "online"
	start_page = "decks"
	editing_deck_index = -1
	online_notice = "호스트에 연결되었습니다. 사용할 덱을 선택하세요."
	render()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_online_deck(deck: Array) -> void:
	if not online_host or not _valid_online_deck(deck): return
	decks[1] = deck.duplicate(true)
	remote_deck_submitted = true
	if local_deck_submitted:
		start_online_match()
	else:
		online_notice = "상대 덱을 받았습니다. 내 덱을 제출해 대전을 시작하세요."
		render()

func _valid_online_deck(deck: Array) -> bool:
	if deck.size() != 6: return false
	for position in range(6):
		if not (deck[position] is Array) or deck[position].size() != 2: return false
		var first: Dictionary = TCGCards.by_id(str(deck[position][0]))
		var second: Dictionary = TCGCards.by_id(str(deck[position][1]))
		if first.is_empty() or second.is_empty() or TCGCards.is_banned(str(first.id)) or TCGCards.is_banned(str(second.id)) or first.tier != position + 1 or second.tier != position + 1 or first.id == second.id:
			return false
	return true

func start_online_match() -> void:
	if not online_host or not local_deck_submitted or not remote_deck_submitted: return
	start_screen = false
	drafting = false
	ai_enabled = false
	covered = false
	online_state = "playing"
	waiting_for_sync = false
	selection.clear()
	info = ""
	online_notice = ""
	battle.presentation_enabled = effects_enabled
	battle.start(decks)
	_broadcast_online_state()
	render()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_online_intent(intent: Dictionary) -> void:
	if not online_host: return
	_apply_online_intent(1, intent)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_online_state(snapshot: Dictionary) -> void:
	if online_host: return
	if is_instance_valid(sync_timer): sync_timer.stop()
	sync_retry_count = 0
	if playing_effects:
		pending_online_snapshots.append(snapshot)
		return
	_restore_online_state(snapshot)
	start_screen = false
	drafting = false
	ai_enabled = false
	online_mode = true
	online_state = "playing"
	waiting_for_sync = false
	selection.clear()
	info = ""
	online_notice = ""
	render()

func _send_online_intent(intent: Dictionary) -> void:
	if not online_mode or online_state != "playing" or waiting_for_sync: return
	if online_host:
		_apply_online_intent(local_player, intent)
	else:
		waiting_for_sync = true
		sync_retry_count = 0
		info = "행동을 호스트에게 전달 중…"
		room_signaling.send_game("intent", intent)
		sync_timer.start()
		render()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_online_state() -> void:
	if not online_host or online_state != "playing": return
	room_signaling.send_game("state", _pack_online_state())

func _has_online_remote_peer() -> bool:
	if room_signaling != null and room_signaling.is_room_connected():
		return remote_peer_id in [1, 2]
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	var peers := multiplayer.get_peers()
	if online_host:
		return remote_peer_id > 0 and remote_peer_id in peers
	return multiplayer.get_unique_id() != 1 and 1 in peers

func _request_online_resync() -> void:
	if not online_mode or online_host: return
	if not _has_online_remote_peer():
		_on_server_disconnected()
		return
	online_state = "playing"
	waiting_for_sync = true
	info = "호스트에게 최신 전투 상태를 다시 요청하는 중…"
	room_signaling.send_game("request_state")
	sync_timer.start()
	render()

func _on_online_sync_timeout() -> void:
	if not waiting_for_sync or not online_mode or online_host: return
	if not _has_online_remote_peer():
		_on_server_disconnected()
		return
	sync_retry_count += 1
	if sync_retry_count <= ONLINE_SYNC_MAX_RETRIES:
		info = "응답이 늦어 최신 전투 상태를 다시 요청합니다. (%d/%d)" % [sync_retry_count, ONLINE_SYNC_MAX_RETRIES]
		room_signaling.send_game("request_state")
		sync_timer.start()
		render()
		return
	waiting_for_sync = false
	online_state = "sync_failed"
	online_notice = "호스트에게서 전투 상태를 받지 못했습니다."
	render()

func _return_to_online_menu() -> void:
	start_page = "online"
	stop_network()

func _apply_online_intent(player: int, intent: Dictionary) -> void:
	if not online_host or online_state != "playing" or player not in [0, 1]: return
	var before := battle.priority
	var accepted := false
	match str(intent.get("type", "")):
		"attack":
			if int(intent.get("owner", -1)) == player:
				accepted = battle.attack(player, int(intent.get("index", -1)), intent.get("target", []))
		"ability":
			if int(intent.get("owner", -1)) == player:
				accepted = battle.ability(player, int(intent.get("index", -1)), intent.get("target", []), str(intent.get("copied_id", "")), intent.get("copied_unit", []), str(intent.get("effect", "")))
		"spell":
			if int(intent.get("owner", -1)) == player:
				accepted = battle.cast_spell(player, int(intent.get("index", -1)), intent.get("target", []), intent.get("copied_unit", []))
		"pass":
			if battle.priority == player and battle.phase in ["action", "reaction"]:
				battle.pass_priority()
				accepted = true
		"end_turn":
			if battle.priority == player:
				accepted = battle.request_end()
		"growth":
			if battle.active == player and battle.phase == "growth":
				battle.grow_potato(bool(intent.get("grow", false)))
				accepted = true
		"deploy":
			if battle.active == player and battle.phase == "deploy":
				accepted = battle.deploy(int(intent.get("choice", -1)))
		"roll_target":
			if battle.priority == player: accepted = battle.choose_roll_target(intent.get("target", []))
		"roll_spell":
			if battle.priority == player: accepted = battle.choose_roll_spell(int(intent.get("index", -1)))
	waiting_for_sync = false
	selection.clear()
	info = "" if accepted else "행동을 수행할 수 없습니다. 최신 상태를 동기화합니다."
	_broadcast_online_state()
	after_action(before)

func _broadcast_online_state() -> void:
	if online_host and remote_peer_id > 0 and online_state == "playing":
		room_signaling.send_game("state", _pack_online_state())

func _pack_online_state() -> Dictionary:
	var packed_players: Array = []
	for owner in range(2):
		var p: Dictionary = battle.players[owner]
		var packed_units: Array = []
		for unit in p.units:
			var packed: Dictionary = unit.duplicate()
			packed.erase("card")
			packed.card_id = unit.card.id
			packed_units.append(packed)
		var deck: Array = p.deck.duplicate(true)
		var hand_ids: Array = p.hand.map(func(card): return card.id)
		if owner == local_player:
			deck.clear()
			hand_ids.clear()
		packed_players.append({"deck": deck, "units": packed_units, "hand": hand_ids, "hand_count": p.hand.size(), "used": p.used.map(func(card): return card.id), "revealed": p.revealed, "own_turn": p.own_turn, "special": p.special})
	var packed_stack: Array = []
	for action in battle.stack:
		var effect_card_id := ""
		var handler = action.get("effect_handler", null)
		if handler != null:
			effect_card_id = handler.card_data().id
		elif not action.source.is_empty():
			effect_card_id = battle.get_unit(action.source).card.id
		elif not action.spell.is_empty():
			effect_card_id = action.spell.id
		packed_stack.append({"owner": action.owner, "title": action.title, "effect": action.effect, "target": action.target, "amount": action.amount, "spell_id": action.spell.get("id", ""), "chain_card_id": action.get("chain_card", {}).get("id", ""), "source": action.source, "effect_card_id": effect_card_id})
	return {"players": packed_players, "active": battle.active, "priority": battle.priority, "turn_index": battle.turn_index, "phase": battle.phase, "stack": packed_stack, "passes": battle.passes, "ending": battle.ending, "winner": battle.winner, "history": battle.history, "visual_events": battle.visual_events, "choice": battle.choice, "income_choices": battle.income_choices, "reaction_window": battle.reaction_window, "pending_roll": battle.pending_roll}

func _restore_online_state(snapshot: Dictionary) -> void:
	battle.players.clear()
	for p in snapshot.players:
		var units: Array = []
		for unit in p.units:
			var card := TCGCards.by_id(unit.card_id)
			var restored: Dictionary = unit.duplicate()
			restored.erase("card_id")
			restored.card = card
			units.append(restored)
		var hand: Array = p.hand.map(func(id): return TCGCards.by_id(id))
		var used: Array = p.used.map(func(id): return TCGCards.by_id(id))
		battle.players.append({"deck": p.deck, "units": units, "hand": hand, "hand_count": p.hand_count, "used": used, "revealed": p.revealed, "own_turn": p.own_turn, "special": p.special})
	battle.stack.clear()
	for action in snapshot.stack:
		var spell: Dictionary = TCGCards.by_id(action.spell_id) if not str(action.spell_id).is_empty() else {}
		var chain_card: Dictionary = TCGCards.by_id(action.get("chain_card_id", "")) if not str(action.get("chain_card_id", "")).is_empty() else {}
		var effect_card: Dictionary = TCGCards.by_id(action.effect_card_id) if not str(action.effect_card_id).is_empty() else {}
		battle.stack.append({"owner": action.owner, "title": action.title, "effect": action.effect, "target": action.target, "amount": action.amount, "spell": spell, "chain_card": chain_card, "source": action.source, "effect_handler": effect_card.get("effect_handler", null)})
	battle.active = snapshot.active
	battle.priority = snapshot.priority
	battle.turn_index = snapshot.turn_index
	battle.phase = snapshot.phase
	battle.passes = snapshot.passes
	battle.ending = snapshot.ending
	battle.winner = snapshot.winner
	battle.history.clear()
	battle.history.assign(snapshot.history)
	battle.visual_events = snapshot.visual_events
	battle.choice = snapshot.get("choice", {})
	battle.pending_roll = snapshot.get("pending_roll", {})
	battle.income_choices = snapshot.get("income_choices", [])
	battle.reaction_window = snapshot.get("reaction_window", [])

