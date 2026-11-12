extends Control

const TCGSoundFXScript = preload("res://src/effects/sound/sound_fx.gd")
const GameModesScript = preload("res://src/battle/game_modes.gd")
const RoomSignalingScript = preload("res://src/online/rooms/room_signaling.gd")
const SupabaseAuthScript = preload("res://src/online/account/supabase_auth.gd")
const CloudDecksScript = preload("res://src/online/decks/cloud_decks.gd")
const PatchNotesData = preload("res://src/ui/screens/patch_notes/patch_notes.gd")
const MainMenuScene = preload("res://src/scenes/screens/main_menu/main_menu.tscn")
const BattleModeMenuScene = preload("res://src/scenes/screens/menu/battle_mode_menu.tscn")
const GameModeSelectScreenScene = preload("res://src/scenes/screens/menu/game_mode_select_screen.tscn")
const AIModeMenuScene = preload("res://src/scenes/screens/menu/ai_mode_menu.tscn")
const SettingsScreenScene = preload("res://src/scenes/screens/settings/settings_screen.tscn")
const RulesScreenScene = preload("res://src/scenes/screens/rules/rules_screen.tscn")
const PatchNotesScreenScene = preload("res://src/scenes/screens/patch_notes/patch_notes_screen.tscn")
const AccountScreenScene = preload("res://src/scenes/screens/account/account_screen.tscn")
const OnlineBrowserScreenScene = preload("res://src/scenes/screens/online/online_browser_screen.tscn")
const OnlineLobbyScreenScene = preload("res://src/scenes/screens/online/online_lobby_screen.tscn")
const DeckLibraryScreenScene = preload("res://src/scenes/screens/decks/deck_library_screen.tscn")
const DeckEditorScreenScene = preload("res://src/scenes/screens/decks/deck_editor_screen.tscn")
const FateDeckEditorScreenScene = preload("res://src/scenes/screens/decks/fate_deck_editor_screen.tscn")
const DraftScreenScene = preload("res://src/scenes/screens/draft/draft_screen.tscn")
const BattleScreenScene = preload("res://src/scenes/screens/battle/battle_screen.tscn")
const ResultOverlayScene = preload("res://src/scenes/overlays/result_overlay/result_overlay.tscn")
const PATCH_NOTES := PatchNotesData.ENTRIES
const UI_FONT = preload("res://src/assets/fonts/NotoSansKR-Variable.ttf")
const BG := Color("0c1424")
const PANEL := Color("17243a")
const MUTED := Color("c4d0df")
const BLUE := Color("71b9ff")
const GOLD := Color("f6d98d")
const GREEN := Color("76dbbc")
const MENU_BUTTON := Color("20344d")
const MENU_BUTTON_HOVER := Color("2c4968")
const MENU_BUTTON_PRESSED := Color("365473")
const TITLE_FONT_SIZE := 85
const MENU_FONT_SIZE := 35
const BODY_FONT_SIZE := 25
const TURN_FONT_SIZE := 30
const HAND_AREA_HEIGHT := 116.0
const FIELD_CARD_SCALE := 1.0
const FIELD_CARD_ASPECT := 280.0 / 200.0
const FIELD_CARD_GAP := 16.0 / 3.0
const SAVED_DECKS_PATH := "user://saved_decks.json"
const ONLINE_SERVER_PATH := "user://online_server.txt"
const DEFAULT_ONLINE_SERVER := "https://besttcgidea-render-server.onrender.com"
const MAX_CUSTOM_DECKS := 8
const MAX_FATE_DECKS := 9
const ONLINE_SYNC_TIMEOUT := 4.0
const ONLINE_SYNC_MAX_RETRIES := 2

class PatchItemMarker:
	extends Control
	var marker_kind := "change"
	var marker_color := Color("71b9ff")

	func _draw() -> void:
		var center := Vector2(10, 10)
		if marker_kind == "change":
			_draw_arc_arrow(center, 6.0, deg_to_rad(200.0), deg_to_rad(345.0))
			_draw_arc_arrow(center, 6.0, deg_to_rad(20.0), deg_to_rad(165.0))
		elif marker_kind == "add":
			draw_line(Vector2(4, 10), Vector2(16, 10), marker_color, 2.5, true)
			draw_line(Vector2(10, 4), Vector2(10, 16), marker_color, 2.5, true)
		else:
			draw_line(Vector2(4, 10), Vector2(16, 10), marker_color, 2.5, true)

	func _draw_arc_arrow(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
		draw_arc(center, radius, start_angle, end_angle, 18, marker_color, 2.5, true)
		var direction := Vector2(-sin(end_angle), cos(end_angle))
		var tip := center + Vector2(cos(end_angle), sin(end_angle)) * radius + direction * 2.0
		var base := tip - direction * 4.5
		var side := Vector2(-direction.y, direction.x) * 2.8
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), marker_color)

var battle := TCGBattle.new()
var root: VBoxContainer
var decks: Array = [[], []]
var draft_player := 0
var drafting := true
var selection: Dictionary = {}
var info := ""
var privacy := false
var covered := false
var ai_enabled := true
var ai_difficulty := "easy"
var ai: Variant = TCGRandomAI.new()
var ai_timer: Timer
var auto_pass := true
var auto_timer: Timer
var hover_layer: Control
var hover_source: TCGCardView
var hover_card: TCGCardView
var hover_spell: PanelContainer
var hover_backdrop: ColorRect
var overlay_card_views: Array[TCGCardView] = []
var draft_card_views: Array[TCGCardView] = []
var deck_card_views: Array[TCGCardView] = []
var deck_overview: VBoxContainer
var field_scrolls: Dictionary = {}
var field_scroll_positions: Dictionary = {}
var field_panels: Dictionary = {}
var field_slot_holders: Dictionary = {}
var gambler_docks: Dictionary = {}
var pending_online_snapshots: Array = []
var overlay_shade: ColorRect
var overlay_center: CenterContainer
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_body: VBoxContainer
var board_view_button: Button
var board_view_visible := false
var effects_enabled := true
var playing_effects := false
var unit_views: Dictionary = {}
var chain_card_views: Array[TCGCardView] = []
var chain_action_links: Array[Dictionary] = []
var chain_layer: Control
var chain_backdrop: ColorRect
var chain_fade_tween: Tween
var chain_left_lane: VBoxContainer
var chain_right_lane: VBoxContainer
var chain_center_badge: PanelContainer
var board_scroll: ScrollContainer
var effect_blocker: Control
var arrow_layer: TCGTargetArrow
var overlay_layer: Control
var overlay_content: VBoxContainer
var action_menu_open := false
var action_button: Button
var drag_source: Array = []
var drag_origin := Vector2.ZERO
var drag_moved := false
var resolving_event: Dictionary = {}
var spell_views: Dictionary = {}
var used_spell_views: Array[TCGCardView] = []
var used_archive_badge: Control
var used_archive_popup: PanelContainer
var battle_log_badge: PanelContainer
var battle_log_label: Label
var battle_log_popup: PanelContainer
var sound_fx: Node
var last_chain_signature := ""
var start_screen := true
var start_page := "home"
var info_screen_active := false
var info_return_start_screen := true
var info_return_page := "home"
var online_mode := false
var online_host := false
var local_player := 0
var remote_peer_id := 0
var online_state := "idle"
var online_notice := ""
var local_deck_submitted := false
var remote_deck_submitted := false
var waiting_for_sync := false
var sync_timer: Timer
var sync_retry_count := 0
var join_address := "ws://127.0.0.1:24680"
var online_server_address := DEFAULT_ONLINE_SERVER
var online_port := 24680
var address_edit: LineEdit
var online_server_edit: LineEdit
var port_edit: LineEdit
var join_port_field: LineEdit
var public_room_name_edit: LineEdit
var public_room_name := ""
var public_room_mode_select: OptionButton
var selected_game_mode := GameModesScript.DEFAULT_ID
var current_game_mode := GameModesScript.DEFAULT_ID
var pending_battle_type := ""
var public_rooms: Array = []
var public_room_list_box: VBoxContainer
var public_room_list_status: Label
var room_list_request: HTTPRequest
var room_list_request_busy := false
var room_refresh_timer: Timer
var room_signaling: Node
var current_room_code := ""
var current_room_name := ""
var local_lobby_ready := false
var remote_lobby_ready := false
var account_auth: Node
var cloud_decks: Node
var account_mode := "login"
var account_email_text := ""
var account_password_text := ""
var account_password_confirm_text := ""
var account_nickname_text := ""
var account_remember := true
var account_busy := false
var account_notice := ""
var cloud_deck_notice := "로컬 덱을 사용하고 있습니다."
var cloud_deck_syncing := false
var saved_decks: Array = []
var saved_fate_decks: Array = []
var deck_name_text := ""
var deck_library_mode := "manage"
var editing_deck_index := -1
var editing_fate_deck_index := -1
var deck_search_text := ""
var deck_filter_tiers: Array[int] = []
var deck_editor_notice := ""
var deck_transfer_active := false

func _ready() -> void:
	auto_timer = Timer.new()
	auto_timer.one_shot = true
	# Leave enough time to read the board before an empty action or response passes itself.
	auto_timer.wait_time = 1.0
	auto_timer.timeout.connect(auto_step)
	add_child(auto_timer)
	ai_timer = Timer.new()
	ai_timer.one_shot = true
	ai_timer.wait_time = 0.55
	ai_timer.timeout.connect(ai_step)
	add_child(ai_timer)
	sync_timer = Timer.new()
	sync_timer.one_shot = true
	sync_timer.wait_time = ONLINE_SYNC_TIMEOUT
	sync_timer.timeout.connect(_on_online_sync_timeout)
	add_child(sync_timer)
	var ui_theme := Theme.new()
	var readable_font := FontVariation.new()
	readable_font.base_font = UI_FONT
	readable_font.variation_embolden = 0.28
	ui_theme.default_font_size = 17
	ui_theme.default_font = readable_font
	ui_theme.set_color("font_color", "Label", Color("f1f5fb"))
	ui_theme.set_constant("outline_size", "Label", 0)
	ui_theme.set_color("font_color", "Button", Color("f5f8ff"))
	ui_theme.set_color("font_hover_color", "Button", Color("ffffff"))
	ui_theme.set_color("font_pressed_color", "Button", Color("fff1cf"))
	ui_theme.set_constant("outline_size", "Button", 0)
	ui_theme.set_color("font_disabled_color", "Button", Color("8798af"))
	ui_theme.set_stylebox("normal", "Button", box(Color("1f334c"), Color("3d5878")))
	ui_theme.set_stylebox("hover", "Button", box(Color("345379"), BLUE))
	ui_theme.set_stylebox("pressed", "Button", box(Color("365879"), GOLD))
	ui_theme.set_stylebox("disabled", "Button", box(Color("152238")))
	theme = ui_theme
	board_scroll = $BoardScroll
	root = $BoardScroll/PageMargin/ScreenHost
	hover_layer = Control.new()
	hover_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hover_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_layer.z_index = 20
	add_child(hover_layer)
	arrow_layer = TCGTargetArrow.new()
	arrow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Keep targeting lines above side-chain cards and combat effects.
	arrow_layer.z_index = 31
	add_child(arrow_layer)
	chain_layer = Control.new()
	chain_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chain_layer.z_index = 7
	add_child(chain_layer)
	chain_backdrop = ColorRect.new()
	chain_backdrop.color = Color(0.01, 0.015, 0.03, 0.62)
	chain_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chain_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chain_layer.add_child(chain_backdrop)
	chain_left_lane = VBoxContainer.new()
	chain_left_lane.anchor_left = 1.0
	chain_left_lane.anchor_right = 1.0
	chain_left_lane.offset_left = -170
	chain_left_lane.offset_right = -18
	chain_left_lane.offset_top = 26
	chain_left_lane.offset_bottom = 760
	chain_left_lane.alignment = BoxContainer.ALIGNMENT_BEGIN
	chain_left_lane.add_theme_constant_override("separation", 6)
	chain_layer.add_child(chain_left_lane)
	chain_right_lane = VBoxContainer.new()
	chain_right_lane.anchor_left = 0.5
	chain_right_lane.anchor_right = 0.5
	chain_right_lane.anchor_top = 0.5
	chain_right_lane.anchor_bottom = 0.5
	chain_right_lane.offset_left = -320
	chain_right_lane.offset_right = 320
	chain_right_lane.offset_top = -310
	chain_right_lane.offset_bottom = 335
	chain_right_lane.alignment = BoxContainer.ALIGNMENT_CENTER
	chain_right_lane.add_theme_constant_override("separation", 10)
	chain_layer.add_child(chain_right_lane)
	chain_layer.hide()
	effect_blocker = Control.new()
	effect_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	effect_blocker.z_index = 30
	effect_blocker.hide()
	add_child(effect_blocker)
	action_button = Button.new()
	action_button.text = "패스"
	action_button.hide()
	action_button.custom_minimum_size = Vector2(330, 60)
	action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.offset_left = -350
	action_button.offset_right = -20
	action_button.offset_top = -132
	action_button.offset_bottom = -72
	action_button.z_index = 8
	action_button.pressed.connect(_on_primary_action_pressed)
	add_child(action_button)
	sound_fx = TCGSoundFXScript.new()
	add_child(sound_fx)
	_create_battle_log_badge()
	overlay_layer = ResultOverlayScene.instantiate()
	add_child(overlay_layer)
	overlay_shade = overlay_layer.get_node("Shade")
	overlay_center = overlay_layer.get_node("Center")
	overlay_panel = overlay_layer.get_node("Center/Panel")
	overlay_panel.add_theme_stylebox_override("panel", box(PANEL, GOLD))
	overlay_content = overlay_layer.get_node("Center/Panel/Content")
	overlay_title = overlay_layer.get_node("Center/Panel/Content/Header/Title")
	board_view_button = overlay_layer.get_node("Center/Panel/Content/Header/BoardViewButton")
	board_view_button.pressed.connect(_toggle_board_view)
	overlay_body = overlay_layer.get_node("Center/Panel/Content/Body")
	_load_saved_decks()
	_load_online_server_address()
	reset_decks()
	room_signaling = RoomSignalingScript.new()
	room_signaling.identity_ready.connect(_on_room_identity_ready)
	room_signaling.status_changed.connect(_on_room_status_changed)
	room_signaling.failed.connect(_on_room_failed)
	room_signaling.peer_connected.connect(_on_room_peer_connected)
	room_signaling.peer_disconnected.connect(_on_room_peer_disconnected)
	room_signaling.game_message.connect(_on_room_game_message)
	room_signaling.connection_lost.connect(_on_room_connection_lost)
	add_child(room_signaling)
	account_auth = SupabaseAuthScript.new()
	account_auth.auth_finished.connect(_on_account_auth_finished)
	add_child(account_auth)
	cloud_decks = CloudDecksScript.new()
	cloud_decks.configure(DEFAULT_ONLINE_SERVER)
	cloud_decks.sync_finished.connect(_on_cloud_deck_sync_finished)
	cloud_decks.save_finished.connect(_on_cloud_deck_save_finished)
	add_child(cloud_decks)
	account_auth.restore_session()
	room_list_request = HTTPRequest.new()
	room_list_request.timeout = 75.0
	room_list_request.request_completed.connect(_on_room_list_received)
	add_child(room_list_request)
	room_refresh_timer = Timer.new()
	room_refresh_timer.wait_time = 10.0
	room_refresh_timer.timeout.connect(fetch_public_rooms)
	add_child(room_refresh_timer)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	render()

func box(color: Color, edge: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.set_border_width_all(1)
	style.border_color = edge
	return style

func label_at(parent: Node, text: String, size: int = BODY_FONT_SIZE, color: Color = Color("ecf2fc")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func emphasize_label(label: Label, strength: float = 0.75) -> void:
	var bold_font := FontVariation.new()
	bold_font.base_font = UI_FONT
	bold_font.variation_embolden = strength
	label.add_theme_font_override("font", bold_font)
	# A surrounding outline intrudes into counters such as 3/6/8/9 and Latin
	# letters at small sizes. A one-direction shadow keeps emphasis without
	# painting inside the glyphs.
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0.035, 0.065, 0.11, 0.58))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 0)

func button_at(parent: Node, text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func row_at(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row

func panel_at(parent: Node, edge: Color = Color.TRANSPARENT) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", box(PANEL, edge))
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	return col


# Virtual hooks implemented by the specialized controller layers.
func main_menu_button(parent: Node, text: String, callback: Callable) -> Button:
	return null

func back_button_at(parent: Node, callback: Callable) -> Button:
	return null

func render_main_menu() -> void:
	pass

func _render_in_screen(screen_scene: PackedScene, renderer: Callable) -> void:
	pass

func _on_main_menu_action(action: String) -> void:
	pass

func render_patch_notes() -> void:
	pass

func _render_patch_notes_content() -> void:
	pass

func patch_note_from_data(parent: Node, note: Dictionary, is_latest: bool = false) -> Control:
	return null

func patch_note_entry(parent: Node, version: String, patch_date: String, title_text: String, title_size: int, title_color: Color, overview: Array, show_developer_note: bool, developer_note: Array, sections: Array, accent: Color, is_latest: bool = false) -> Control:
	return null

func _patch_note_item_kind(item_text: String) -> String:
	return ""

func screen_header_at(title_text: String, back_callback: Callable) -> Control:
	return null

func submenu_at(title_text: String, back_callback: Callable) -> VBoxContainer:
	return null

func render_battle_menu() -> void:
	pass

func render_game_mode_menu() -> void:
	pass

func render_ai_menu() -> void:
	pass

func render_online_menu() -> void:
	pass

func _render_online_menu_content() -> void:
	pass

func open_battle_menu() -> void:
	pass

func open_game_mode_menu(battle_type: String) -> void:
	pass

func open_ai_menu() -> void:
	pass

func open_online_menu() -> void:
	pass

func open_patch_notes() -> void:
	pass

func back_to_main_menu() -> void:
	pass

func back_to_battle_menu() -> void:
	pass

func go_back_from_start_page() -> void:
	pass

func open_deck_menu() -> void:
	pass

func show_settings() -> void:
	pass

func render_settings_screen() -> void:
	pass

func _on_setting_changed(setting_name: String, enabled: bool) -> void:
	pass

func _open_info_screen(page: String) -> void:
	pass

func back_from_info_screen() -> void:
	pass

func show_rules() -> void:
	pass

func render_rules_screen() -> void:
	pass

func open_account() -> void:
	pass

func render_account() -> void:
	pass

func _render_account_content() -> void:
	pass

func _account_benefit(parent: Node, icon_text: String, title_text: String, detail_text: String) -> void:
	pass

func _render_account_form(parent: VBoxContainer) -> void:
	pass

func _account_line_edit(parent: VBoxContainer, title_text: String, placeholder: String, value: String, secret: bool) -> LineEdit:
	return null

func _render_signed_in_account(parent: VBoxContainer) -> void:
	pass

func set_account_mode(mode: String) -> void:
	pass

func submit_account_form() -> void:
	pass

func request_account_password_reset() -> void:
	pass

func request_account_sign_out() -> void:
	pass

func _on_account_auth_finished(action: String, ok: bool, _payload: Dictionary, message: String) -> void:
	pass

func _sync_account_decks() -> void:
	pass

func _on_cloud_deck_sync_finished(ok: bool, decks_value: Array, message: String) -> void:
	pass

func _on_cloud_deck_save_finished(ok: bool, message: String) -> void:
	pass

func _render_online_browser_content() -> void:
	pass

func _render_online_lobby_content() -> void:
	pass

func _online_player_panel(parent: Node, player_number: int, connected: bool, ready: bool, is_host: bool, is_local: bool) -> void:
	pass

func _online_setting_row(parent: Node, title_text: String, value_text: String) -> void:
	pass

func start_ai_draft() -> void:
	pass

func start_strong_ai_draft() -> void:
	pass

func _start_ai_draft() -> void:
	pass

func start_local_draft() -> void:
	pass

func start_host() -> void:
	pass

func signaling_url() -> String:
	return ""

func rooms_url() -> String:
	return ""

func _normalized_online_server_address() -> String:
	return ""

func _load_online_server_address() -> void:
	pass

func _write_online_server_address() -> void:
	pass

func apply_online_server_address() -> void:
	pass

func fetch_public_rooms() -> void:
	pass

func _on_room_list_received(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	pass

func _rebuild_public_room_list() -> void:
	pass

func create_public_web_room() -> void:
	pass

func join_public_room(code: String) -> void:
	pass

func _on_room_identity_ready(peer_id: int, code: String) -> void:
	pass

func _on_room_status_changed(message: String) -> void:
	pass

func _on_room_failed(message: String) -> void:
	pass

func _on_room_peer_connected(peer_id: int) -> void:
	pass

func _on_room_peer_disconnected(peer_id: int) -> void:
	pass

func _on_room_connection_lost(message: String) -> void:
	pass

func _on_room_game_message(kind: String, payload: Variant) -> void:
	pass

func start_join() -> void:
	pass

func stop_network() -> void:
	pass

func _on_peer_connected(id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	pass

func _on_connected_to_server() -> void:
	pass

func _on_connection_failed() -> void:
	pass

func _on_server_disconnected() -> void:
	pass

func _rpc_enter_online_lobby(payload: Variant = {}) -> void:
	pass

func toggle_online_ready() -> void:
	pass

func begin_online_draft() -> void:
	pass

func _rpc_start_online_draft() -> void:
	pass

func _rpc_submit_online_deck(deck: Array) -> void:
	pass

func _valid_online_deck(deck: Array) -> bool:
	return false

func start_online_match() -> void:
	pass

func _rpc_submit_online_intent(intent: Dictionary) -> void:
	pass

func _rpc_receive_online_state(snapshot: Dictionary) -> void:
	pass

func _send_online_intent(intent: Dictionary) -> void:
	pass

func _rpc_request_online_state() -> void:
	pass

func _has_online_remote_peer() -> bool:
	return false

func _request_online_resync() -> void:
	pass

func _on_online_sync_timeout() -> void:
	pass

func _return_to_online_menu() -> void:
	pass

func _apply_online_intent(player: int, intent: Dictionary) -> void:
	pass

func _broadcast_online_state() -> void:
	pass

func _pack_online_state() -> Dictionary:
	return {}

func _restore_online_state(snapshot: Dictionary) -> void:
	pass

func reset_decks() -> void:
	pass

func is_ai_turn() -> bool:
	return false

func ai_step() -> void:
	pass

func _load_saved_decks() -> void:
	pass

func _write_saved_decks(sync_cloud: bool = true) -> bool:
	return false

func _empty_deck() -> Array:
	return []

func _default_deck() -> Array:
	return []

func _default_deck_entry() -> Dictionary:
	return {}

func _valid_saved_deck_structure(deck: Array) -> bool:
	return false

func _deck_count(deck: Array) -> int:
	return 0

func _deck_tooltip(entry: Dictionary) -> String:
	return ""

func _deck_display_name(entry: Dictionary) -> String:
	return ""

func render_deck_library() -> void:
	pass

func _render_deck_library_content() -> void:
	pass

func _render_deck_slot(parent: Node, index: int) -> void:
	pass

func _render_empty_deck_slot(parent: Node, _slot: int) -> void:
	pass

func _render_default_deck_slot(parent: Node) -> void:
	pass

func create_empty_deck() -> void:
	pass

func choose_saved_deck(index: int) -> void:
	pass

func choose_default_deck() -> void:
	pass

func _use_chosen_deck(chosen: Array) -> void:
	pass

func submit_selected_online_deck() -> void:
	pass

func back_from_deck_library() -> void:
	pass

func back_to_deck_library() -> void:
	pass

func back_to_fate_deck_library() -> void:
	pass

func open_deck_editor(index: int) -> void:
	pass

func render_deck_editor() -> void:
	pass

func render_fate_deck_editor() -> void:
	pass

func refresh_fate_deck_editor_screen() -> bool:
	return false

func _render_deck_editor_content() -> void:
	pass

func _add_deck_editor_vertical_spacer(parent: Node, spacer_name: String = "") -> Control:
	return null

func _render_editor_tier(parent: Node, deck: Array, tier: int) -> void:
	pass

func _rebuild_deck_card_browser(browser: HBoxContainer) -> void:
	pass

func _editor_card_hover_text(card: Dictionary, action_text: String) -> String:
	return ""

func update_edited_deck_name(value: String) -> void:
	pass

func add_editor_card(tier: int, id_value: String, source_view: Control = null) -> void:
	pass

func remove_editor_card(tier: int, id_value: String, source_view: Control = null) -> void:
	pass

func _animate_editor_card_transfer(source: Control, destination: Control, card: Dictionary) -> void:
	pass

func save_current_deck() -> void:
	pass

func load_saved_deck(index: int) -> void:
	pass

func confirm_delete_saved_deck(index: int) -> void:
	pass

func delete_saved_deck(index: int) -> void:
	pass

func render_saved_decks() -> void:
	pass

func render_draft() -> void:
	pass

func _render_draft_content() -> void:
	pass

func card_summary(parent: Node, c: Dictionary) -> void:
	pass

func render_deck_overview() -> void:
	pass

func _save_field_scrolls() -> void:
	pass

func toggle_draft(tier: int, id: String) -> void:
	pass

func confirm_draft() -> void:
	pass

func begin_game() -> void:
	pass

func _notification(what: int) -> void:
	pass

func _input(event: InputEvent) -> void:
	pass

func begin_drag(source: Array, point: Vector2) -> bool:
	return false

func target_at(point: Vector2) -> Array:
	return []

func finish_drag(point: Vector2) -> void:
	pass

func cancel_drag() -> void:
	pass

func cancel_targeting() -> void:
	pass

func cancel_selection() -> void:
	pass

func anchor_for(source: Array, owner: int = 0) -> Vector2:
	return Vector2.ZERO

func arrow_for(action: Dictionary, title: String = "") -> Dictionary:
	return {}

func _chain_target_key(target: Array) -> String:
	return ""

func _chain_final_previews() -> Dictionary:
	return {}

func _process(delta: float) -> void:
	pass

func _update_hover_preview(point: Vector2 = Vector2.INF) -> void:
	pass

func _create_battle_log_badge() -> void:
	pass

func _update_battle_log_badge() -> void:
	pass

func show_battle_log_popup() -> void:
	pass

func hide_battle_log_popup() -> void:
	pass

func _drain_online_snapshots() -> void:
	pass

func can_auto_pass() -> bool:
	return false

func play_combat_effects() -> void:
	pass

func _event_target_view(event: Dictionary) -> TCGCardView:
	return null

func _show_unit_arrival(destination: TCGCardView, event: Dictionary) -> void:
	pass

func _show_turn_banner(event: Dictionary) -> void:
	pass

func _rebuild_effect_board() -> void:
	pass

func _ensure_effect_visible(view: Control, owner: int) -> void:
	pass

func auto_step() -> void:
	pass

func add_card(parent: Node, c: Dictionary, power: int = -1, hp: int = -1, mana: int = -1, spell: bool = false, face_down: bool = false, caption: String = "미공개", highlight: bool = false, shield: int = 0, draft_selected: bool = false) -> TCGCardView:
	return null

func show_card_preview(source: TCGCardView) -> void:
	pass

func hide_card_preview() -> void:
	pass

func render_battle() -> void:
	pass

func _render_battle_content() -> void:
	pass

func render_turn_status() -> void:
	pass

func _board_slot_map(owner: int) -> Dictionary:
	return {}

func _render_empty_board_slot(parent: Node, board_slot: int) -> TCGCardView:
	return null

func _make_board_slot_holder(parent: Container, owner: int, board_slot: int, special: bool, has_next: bool, slot_width: float) -> CenterContainer:
	return null

func _resize_field_card(view: TCGCardView, slot_width: float, special: bool) -> void:
	pass

func render_gambler_dock(parent: Node, owner: int) -> void:
	pass

func _has_selectable_defeated_units(owner: int) -> bool:
	return false

func render_defeated_target_picker(parent: Node, owner: int) -> void:
	pass

func render_chain_spells() -> void:
	pass

func clear_chain_spells() -> void:
	pass

func _chain_display_card(action: Dictionary) -> Dictionary:
	return {}

func add_chain_card(parent: Node, spell: Dictionary, action: Dictionary, pending: bool = false, chain_number: int = 0) -> TCGCardView:
	return null

func add_chain_focus_card(parent: Node, spell: Dictionary, action: Dictionary, pending: bool = false, chain_number: int = 0) -> TCGCardView:
	return null

func _show_chain_center(chain_count: int) -> void:
	pass

func _update_action_button() -> void:
	pass

func _on_primary_action_pressed() -> void:
	pass

func _build_overlay(title: String, allow_board_view: bool = true) -> VBoxContainer:
	return null

func _toggle_board_view() -> void:
	pass

func _set_board_view_visible(show_board: bool) -> void:
	pass

func _render_battle_overlay() -> void:
	pass

func phase_hint() -> String:
	return ""

func render_unit(parent: Node, owner: int, slot: int) -> void:
	pass

func render_controls() -> void:
	pass

func render_hand(parent: Node = root) -> void:
	pass

func render_used_spell_badge(parent: Node) -> void:
	pass

func show_used_spells_popup(source: Control) -> void:
	pass

func hide_used_spells_popup() -> void:
	pass

func select_ability(owner: int, slot: int) -> void:
	pass

func choose_ability_option(option: Dictionary) -> void:
	pass

func submit_selected_ability(target) -> void:
	pass

func select_attack(owner: int, slot: int) -> void:
	pass

func select_spell(index: int) -> void:
	pass

func select_replay(c: Dictionary) -> void:
	pass

func target_eligible(target: Array) -> bool:
	return false

func choose_target(target: Array) -> void:
	pass

func choose_gamble(target: Array) -> void:
	pass

func choose_gamble_spell(index: int) -> void:
	pass

func pass_action() -> void:
	pass

func end_action() -> void:
	pass

func choose_growth(grow: bool) -> void:
	pass

func choose_deploy(choice: int) -> void:
	pass

func after_action(before: int) -> void:
	pass

func confirm_restart() -> void:
	pass

func restart_game() -> void:
	pass

func render_start_screen() -> void:
	pass

func render() -> void:
	pass

