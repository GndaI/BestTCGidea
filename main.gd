extends Control

const TCGSoundFXScript = preload("res://sound_fx.gd")
const RoomSignalingScript = preload("res://room_signaling.gd")
const PatchNotesData = preload("res://patch_notes.gd")
const PATCH_NOTES := PatchNotesData.ENTRIES
const UI_FONT = preload("res://assets/fonts/NotoSansKR-Variable.ttf")
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
const MAX_CUSTOM_DECKS := 8
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
var online_server_address := "http://127.0.0.1:8000"
var online_port := 24680
var address_edit: LineEdit
var online_server_edit: LineEdit
var port_edit: LineEdit
var join_port_field: LineEdit
var room_code_edit: LineEdit
var public_room_name_edit: LineEdit
var public_room_name := ""
var public_rooms: Array = []
var public_room_list_box: VBoxContainer
var public_room_list_status: Label
var room_list_request: HTTPRequest
var room_list_request_busy := false
var room_refresh_timer: Timer
var room_signaling: Node
var current_room_code := ""
var saved_decks: Array = []
var deck_name_text := ""
var deck_library_mode := "manage"
var editing_deck_index := -1
var deck_search_text := ""
var deck_filter_tiers: Array[int] = []
var deck_editor_notice := ""
var deck_transfer_active := false

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
	if not can_attack and not battle.can_ability(source[0], source[1]): return false
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
	if not moved and source.size() == 2 and battle.can_ability(source[0], source[1]):
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
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	board_scroll = scroll
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8 if side in ["top", "bottom"] else 24)
	scroll.add_child(margin)
	root = VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
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
	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.z_index = 10
	overlay_layer.hide()
	add_child(overlay_layer)
	var shade := ColorRect.new()
	overlay_shade = shade
	shade.color = Color(0.015, 0.025, 0.045, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(shade)
	overlay_center = CenterContainer.new()
	overlay_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_center.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(overlay_center)
	overlay_panel = PanelContainer.new()
	overlay_panel.custom_minimum_size = Vector2(480, 160)
	overlay_panel.add_theme_stylebox_override("panel", box(PANEL, GOLD))
	overlay_center.add_child(overlay_panel)
	overlay_content = VBoxContainer.new()
	overlay_content.add_theme_constant_override("separation", 14)
	overlay_panel.add_child(overlay_content)
	var overlay_header := HBoxContainer.new()
	overlay_header.add_theme_constant_override("separation", 10)
	overlay_content.add_child(overlay_header)
	overlay_title = label_at(overlay_header, "", 24, GOLD)
	board_view_button = Button.new()
	board_view_button.text = "보드 보기"
	board_view_button.custom_minimum_size = Vector2(170, 48)
	board_view_button.visible = false
	board_view_button.pressed.connect(_toggle_board_view)
	overlay_header.add_child(board_view_button)
	overlay_body = VBoxContainer.new()
	overlay_body.add_theme_constant_override("separation", 14)
	overlay_content.add_child(overlay_body)
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
	room_list_request = HTTPRequest.new()
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

func reset_decks() -> void:
	decks = [[], []]
	for p in range(2):
		decks[p] = _default_deck()

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

func render_start_screen() -> void:
	match start_page:
		"battle": render_battle_menu()
		"ai": render_ai_menu()
		"online": render_online_menu()
		"decks": render_deck_library()
		"deck_editor": render_deck_editor()
		"patch_notes": render_patch_notes()
		_: render_main_menu()

func render_main_menu() -> void:
	var canvas := Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(canvas)

	var logo_panel := PanelContainer.new()
	logo_panel.anchor_left = 0.5
	logo_panel.anchor_right = 0.5
	logo_panel.anchor_top = 0.08
	logo_panel.anchor_bottom = 0.08
	logo_panel.offset_left = -430
	logo_panel.offset_right = 430
	logo_panel.offset_top = 0
	logo_panel.offset_bottom = 170
	logo_panel.add_theme_stylebox_override("panel", box(Color("111d31"), Color("2d405b")))
	canvas.add_child(logo_panel)
	var logo_column := VBoxContainer.new()
	logo_column.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_column.add_theme_constant_override("separation", 2)
	logo_panel.add_child(logo_column)
	var logo := label_at(logo_column, "TWELVE", TITLE_FONT_SIZE, GOLD)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emphasize_label(logo, 0.42)
	var subtitle := label_at(logo_column, "최고의 TCG IDEA", BODY_FONT_SIZE, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emphasize_label(subtitle, 0.24)

	var account := Button.new()
	account.text = "계정"
	account.custom_minimum_size = Vector2(126, 52)
	account.add_theme_font_size_override("font_size", 19)
	account.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	account.offset_left = -142
	account.offset_right = -16
	account.offset_top = 16
	account.offset_bottom = 68
	account.pressed.connect(show_account)
	canvas.add_child(account)

	var photo_specs := [
		{"path": "res://assets/ui/main_left.jpg", "left": 0.035, "right": 0.255},
		{"path": "res://assets/ui/main_right.jpg", "left": 0.745, "right": 0.965},
	]
	for photo_spec in photo_specs:
		var photo_frame := PanelContainer.new()
		photo_frame.anchor_left = photo_spec.left
		photo_frame.anchor_right = photo_spec.right
		photo_frame.anchor_top = 0.31
		photo_frame.anchor_bottom = 0.90
		photo_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var photo_style := box(Color("101a2b"), Color("435a76"))
		photo_style.set_border_width_all(3)
		photo_style.set_corner_radius_all(16)
		photo_frame.add_theme_stylebox_override("panel", photo_style)
		canvas.add_child(photo_frame)
		var photo := TextureRect.new()
		photo.texture = load(photo_spec.path)
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.set_clip_contents(true)
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo_frame.add_child(photo)

	var menu_center := CenterContainer.new()
	menu_center.anchor_right = 1.0
	menu_center.anchor_bottom = 1.0
	menu_center.offset_top = 280
	menu_center.offset_bottom = -36
	canvas.add_child(menu_center)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 18)
	menu_center.add_child(menu)
	main_menu_button(menu, "대전", open_battle_menu)
	main_menu_button(menu, "덱", open_deck_menu)
	main_menu_button(menu, "정보", show_rules)
	main_menu_button(menu, "설정", show_settings)

	var patch_notes_button := button_at(canvas, "패치노트", open_patch_notes)
	patch_notes_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	patch_notes_button.offset_left = 18
	patch_notes_button.offset_right = 168
	patch_notes_button.offset_top = -66
	patch_notes_button.offset_bottom = -18
	patch_notes_button.add_theme_font_size_override("font_size", 18)

func render_patch_notes() -> void:
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
	var menu := submenu_at("대전", back_to_main_menu)
	main_menu_button(menu, "AI", open_ai_menu)
	main_menu_button(menu, "로컬", start_local_draft)
	main_menu_button(menu, "온라인", open_online_menu)

func render_ai_menu() -> void:
	var menu := submenu_at("AI", back_to_battle_menu)
	main_menu_button(menu, "AI 초급", start_ai_draft)
	main_menu_button(menu, "AI 고급", start_strong_ai_draft)

func render_online_menu() -> void:
	var menu := submenu_at("온라인", back_to_battle_menu)
	menu.custom_minimum_size.x = 560
	if online_state == "lobby":
		render_online_lobby()
		return
	if online_state == "room_waiting":
		var code := label_at(menu, "방 코드  %s" % current_room_code, BODY_FONT_SIZE, GOLD)
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var waiting := label_at(menu, "친구의 참가를 기다리는 중입니다.", BODY_FONT_SIZE, MUTED)
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "대기 취소", stop_network)
	elif online_state == "room_joining":
		var joining := label_at(menu, "방 %s에 연결하는 중…" % current_room_code, BODY_FONT_SIZE, GOLD)
		joining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "연결 취소", stop_network)
	elif online_state == "hosting":
		label_at(menu, "참가자를 기다리는 중", BODY_FONT_SIZE, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "대기 취소", stop_network)
	elif online_state == "connecting":
		label_at(menu, "온라인 서버에 연결 중…", BODY_FONT_SIZE, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "연결 취소", stop_network)
	else:
		if not OS.has_feature("web"):
			var server_row := row_at(menu)
			server_row.custom_minimum_size = Vector2(560, 52)
			online_server_edit = LineEdit.new()
			online_server_edit.text = online_server_address
			online_server_edit.placeholder_text = "서버 주소 · https://… 또는 http://…"
			online_server_edit.custom_minimum_size = Vector2(420, 52)
			online_server_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			online_server_edit.text_submitted.connect(func(_value): apply_online_server_address())
			server_row.add_child(online_server_edit)
			var apply_button := button_at(server_row, "적용", apply_online_server_address)
			apply_button.custom_minimum_size = Vector2(120, 52)
		var public_title := label_at(menu, "공개 방", MENU_FONT_SIZE, BLUE)
		public_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var refresh_note := label_at(menu, "목록은 10초마다 자동으로 새로 불러옵니다.", BODY_FONT_SIZE, MUTED)
		refresh_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var create_row := row_at(menu)
		create_row.custom_minimum_size = Vector2(560, 58)
		public_room_name_edit = LineEdit.new()
		public_room_name_edit.text = public_room_name
		public_room_name_edit.placeholder_text = "공개 방 이름"
		public_room_name_edit.max_length = 20
		public_room_name_edit.custom_minimum_size = Vector2(365, 58)
		public_room_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		public_room_name_edit.text_changed.connect(func(value): public_room_name = value)
		create_row.add_child(public_room_name_edit)
		var create_button := button_at(create_row, "방 만들기", create_public_web_room)
		create_button.custom_minimum_size = Vector2(175, 58)
		var room_scroll := ScrollContainer.new()
		room_scroll.custom_minimum_size = Vector2(560, 220)
		room_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		menu.add_child(room_scroll)
		public_room_list_box = VBoxContainer.new()
		public_room_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		public_room_list_box.add_theme_constant_override("separation", 8)
		room_scroll.add_child(public_room_list_box)
		public_room_list_status = label_at(menu, "", BODY_FONT_SIZE, MUTED)
		public_room_list_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rebuild_public_room_list()
		var private_title := label_at(menu, "비공개 방 · 방 코드로 참가", BODY_FONT_SIZE, GOLD)
		private_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_menu_button(menu, "비공개 방 만들기", create_web_room)
		var room_row := row_at(menu)
		room_row.custom_minimum_size = Vector2(560, 58)
		room_code_edit = LineEdit.new()
		room_code_edit.placeholder_text = "방 코드 6자리"
		room_code_edit.max_length = 6
		room_code_edit.custom_minimum_size = Vector2(365, 58)
		room_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		room_row.add_child(room_code_edit)
		var join_button := button_at(room_row, "참가", join_web_room)
		join_button.custom_minimum_size = Vector2(175, 58)
	if not online_notice.is_empty():
		var notice := label_at(menu, online_notice, BODY_FONT_SIZE, Color("ffbd84"))
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func open_battle_menu() -> void:
	start_page = "battle"
	render()

func open_ai_menu() -> void:
	start_page = "ai"
	render()

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
	elif start_page == "decks":
		back_from_deck_library()
	elif start_page in ["ai", "online"]:
		back_to_battle_menu()
	elif start_page in ["battle", "patch_notes"]:
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
	var dialog := AcceptDialog.new()
	dialog.title = "설정"
	dialog.min_size = Vector2i(480, 330)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 18)
	var heading := label_at(settings, "게임 설정", 27, GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var effects_check := CheckButton.new()
	effects_check.text = "전투 연출 사용"
	effects_check.button_pressed = effects_enabled
	effects_check.toggled.connect(func(value): effects_enabled = value)
	settings.add_child(effects_check)
	var auto_check := CheckButton.new()
	auto_check.text = "행동이 없으면 자동으로 넘기기"
	auto_check.button_pressed = auto_pass
	auto_check.toggled.connect(func(value): auto_pass = value)
	settings.add_child(auto_check)
	var privacy_check := CheckButton.new()
	privacy_check.text = "로컬 대전에서 행동권 변경 시 패 가리기"
	privacy_check.button_pressed = privacy
	privacy_check.toggled.connect(func(value): privacy = value)
	settings.add_child(privacy_check)
	dialog.add_child(settings)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 360))
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func show_account() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "계정"
	dialog.dialog_text = "현재 덱은 이 기기에 저장됩니다.\n온라인 계정 연동 기능은 추후 추가할 예정입니다.\n\n저장된 덱: %d개" % saved_decks.size()
	add_child(dialog)
	dialog.popup_centered(Vector2i(500, 240))
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func render_online_lobby() -> void:
	var lobby := panel_at(root, GREEN)
	lobby.name = "OnlineLobby"
	label_at(lobby, "친구와 연결 · 대기방", MENU_FONT_SIZE, GREEN)
	label_at(lobby, "● P1 호스트 · 연결됨", BODY_FONT_SIZE, GOLD)
	label_at(lobby, "● P2 참가자 · 연결됨", BODY_FONT_SIZE, BLUE)
	label_at(lobby, "두 플레이어의 연결을 확인했습니다.", BODY_FONT_SIZE, MUTED)
	if online_host:
		button_at(lobby, "덱 구성 시작", begin_online_draft)
	else:
		var waiting := button_at(lobby, "호스트가 덱 구성을 시작하기를 기다리는 중…", func(): pass, true)
		waiting.custom_minimum_size.y = 50
	button_at(lobby, "대기방 나가기", stop_network)

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
	return value if not value.is_empty() else "http://127.0.0.1:8000"

func _load_online_server_address() -> void:
	if not FileAccess.file_exists(ONLINE_SERVER_PATH):
		return
	var value := FileAccess.get_file_as_string(ONLINE_SERVER_PATH).strip_edges()
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
		public_room_list_status.text = "방 목록을 불러오는 중…"
	var error := room_list_request.request(rooms_url())
	if error != OK:
		room_list_request_busy = false
		if is_instance_valid(public_room_list_status):
			public_room_list_status.text = "방 목록을 불러오지 못했습니다."

func _on_room_list_received(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	room_list_request_busy = false
	if response_code != 200:
		if is_instance_valid(public_room_list_status):
			public_room_list_status.text = "방 목록을 불러오지 못했습니다. 10초 뒤 다시 시도합니다."
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
		var state_text := "입장 가능" if waiting else "진행 중"
		var title := "%s     %d/2명 · %s" % [str(room_data.get("name", "이름 없는 방")), players, state_text]
		var room_button := button_at(public_room_list_box, title, join_public_room.bind(code), not waiting)
		room_button.custom_minimum_size = Vector2(560, 54)

func create_public_web_room() -> void:
	var room_name := public_room_name_edit.text.strip_edges() if public_room_name_edit != null else public_room_name.strip_edges()
	if room_name.is_empty():
		online_notice = "공개 방 이름을 입력해주세요."
		render()
		return
	public_room_name = room_name
	room_refresh_timer.stop()
	online_notice = ""
	current_room_code = ""
	online_state = "connecting"
	render()
	room_signaling.create_public_room(signaling_url(), room_name)

func join_public_room(code: String) -> void:
	if code.length() != 6:
		return
	room_refresh_timer.stop()
	online_notice = ""
	current_room_code = code
	online_state = "connecting"
	render()
	room_signaling.join_room(signaling_url(), code)

func create_web_room() -> void:
	room_refresh_timer.stop()
	online_notice = ""
	current_room_code = ""
	online_state = "connecting"
	render()
	room_signaling.create_room(signaling_url())

func join_web_room() -> void:
	var code := room_code_edit.text.strip_edges().to_upper() if room_code_edit != null else ""
	if code.length() != 6:
		online_notice = "방 코드는 여섯 자리입니다. 다시 확인해주세요."
		render()
		return
	online_notice = ""
	room_refresh_timer.stop()
	current_room_code = code
	online_state = "connecting"
	render()
	room_signaling.join_room(signaling_url(), code)

func _on_room_identity_ready(peer_id: int, code: String) -> void:
	current_room_code = code
	online_mode = true
	online_host = peer_id == 1
	local_player = 0 if online_host else 1
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
	room_signaling.send_game("enter_lobby")
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
	var guest_to_host := kind in ["submit_deck", "intent", "request_state"]
	var host_to_guest := kind in ["enter_lobby", "start_draft", "state"]
	if (online_host and not guest_to_host) or (not online_host and not host_to_guest):
		return
	match kind:
		"enter_lobby":
			_rpc_enter_online_lobby()
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
	remote_peer_id = 0
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
func _rpc_enter_online_lobby() -> void:
	online_mode = true
	online_host = false
	local_player = 1
	online_state = "lobby"
	start_screen = true
	drafting = true
	ai_enabled = false
	draft_player = local_player
	local_deck_submitted = false
	remote_deck_submitted = false
	online_notice = "호스트와 연결되었습니다."
	render()

func begin_online_draft() -> void:
	if not online_host or online_state != "lobby" or remote_peer_id <= 0: return
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
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
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
		var header := screen_header_at("덱 제작", restart_game)
		var rules_button := button_at(header, "정보", show_rules)
		rules_button.custom_minimum_size = Vector2(150, 48)
		rules_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		rules_button.offset_left = -150
		rules_button.offset_right = 0
		rules_button.offset_top = 0
		rules_button.offset_bottom = 48
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
	if not FileAccess.file_exists(SAVED_DECKS_PATH): return
	var file := FileAccess.open(SAVED_DECKS_PATH, FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary): return
	for entry in parsed.get("decks", []):
		if saved_decks.size() >= MAX_CUSTOM_DECKS: break
		if entry is Dictionary and _valid_saved_deck_structure(entry.get("cards", [])):
			saved_decks.append({"name": str(entry.get("name", "이름 없는 덱")), "cards": entry.cards.duplicate(true)})

func _write_saved_decks() -> bool:
	var file := FileAccess.open(SAVED_DECKS_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": 1, "decks": saved_decks}, "  "))
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
	var title := "덱" if deck_library_mode == "manage" else ("P%d 덱 선택" % [draft_player + 1] if deck_library_mode == "local" else "사용할 덱 선택")
	screen_header_at(title, back_from_deck_library)
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
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(grid_center)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.custom_minimum_size = Vector2(1030, 620)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid_center.add_child(grid)
	for slot in range(9):
		if slot == 8:
			_render_default_deck_slot(grid)
		elif slot < saved_decks.size():
			_render_deck_slot(grid, slot)
		else:
			_render_empty_deck_slot(grid, slot)
	if not deck_editor_notice.is_empty():
		var notice := label_at(page, deck_editor_notice, BODY_FONT_SIZE, Color("ffbd84"))
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
		deck_editor_notice = "12장을 모두 채운 덱만 대전에 사용할 수 있습니다."
		render()
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
		deck_editor_notice = "P1 덱 선택 완료 · 이제 P2 덱을 선택하세요."
		render()
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
			deck_editor_notice = online_notice
			render()
	else:
		room_signaling.send_game("submit_deck", {"deck": decks[local_player]})
		online_notice = "덱을 제출했습니다. 호스트가 대전을 시작할 때까지 기다려 주세요."
		deck_editor_notice = online_notice
		render()

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
	if editing_deck_index < 0 or editing_deck_index >= saved_decks.size():
		back_to_deck_library()
		return
	screen_header_at("덱 제작", back_to_deck_library)
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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var browser := HBoxContainer.new()
	browser.name = "DeckCardBrowser"
	browser.add_theme_constant_override("separation", 12)
	browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(browser)
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
				deck_filter_tiers.erase(filter_value)
			else:
				deck_filter_tiers.append(filter_value)
				deck_filter_tiers.sort()
			for button in filter_buttons:
				var button_tier := int(button.name.trim_prefix("DeckTierFilter"))
				button.button_pressed = deck_filter_tiers.is_empty() if button_tier == 0 else button_tier in deck_filter_tiers
			_rebuild_deck_card_browser(browser)
		)
		filter_buttons.append(filter_button)
		search_row.add_child(filter_button)
	_rebuild_deck_card_browser(browser)
	search.text_changed.connect(func(value):
		deck_search_text = value
		_rebuild_deck_card_browser(browser)
	)
	var notice := label_at(right, deck_editor_notice, BODY_FONT_SIZE, Color("ffbd84"))
	notice.name = "DeckEditorNotice"
	notice.visible = not deck_editor_notice.is_empty()
	notice.custom_minimum_size.y = 46 if notice.visible else 0

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
		if position < deck[tier - 1].size():
			var id_value := str(deck[tier - 1][position])
			var card: Dictionary = TCGCards.by_id(id_value)
			var slot := VBoxContainer.new()
			slot.custom_minimum_size = Vector2(196, 98)
			row.add_child(slot)
			var card_row := HBoxContainer.new()
			slot.add_child(card_row)
			var view := add_card(card_row, card)
			view.custom_minimum_size = Vector2(70, 98)
			view.tooltip_text = ""
			view.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					remove_editor_card(tier, id_value, view)
			)
			var card_name := label_at(card_row, str(card.name), 20, Color("e8eef8"))
			card_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_name.max_lines_visible = 2
			card_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		else:
			var empty := Label.new()
			empty.text = "빈 카드 칸"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.custom_minimum_size = Vector2(196, 98)
			empty.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
			empty.add_theme_color_override("font_color", Color("6f829b"))
			row.add_child(empty)

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
		deck_editor_notice = "이미 이 턴에 들어 있는 카드입니다."
	elif pair.size() >= 2:
		deck_editor_notice = "%d턴은 이미 2장입니다. 왼쪽에서 카드 하나를 먼저 빼세요." % tier
	else:
		deck_transfer_active = true
		await _animate_editor_card_transfer(source_view, root.find_child("EditorTier%d" % tier, true, false), TCGCards.by_id(id_value))
		pair.append(id_value)
		deck_editor_notice = "%d턴에 카드를 추가했습니다." % tier
		_write_saved_decks()
		deck_transfer_active = false
	render()

func remove_editor_card(tier: int, id_value: String, source_view: Control = null) -> void:
	if deck_transfer_active or editing_deck_index < 0 or editing_deck_index >= saved_decks.size(): return
	var pair: Array = saved_decks[editing_deck_index].cards[tier - 1]
	deck_transfer_active = true
	await _animate_editor_card_transfer(source_view, root.find_child("DeckCardBrowser", true, false), TCGCards.by_id(id_value))
	pair.erase(id_value)
	deck_editor_notice = "%d턴에서 카드를 뺐습니다." % tier
	_write_saved_decks()
	deck_transfer_active = false
	render()

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

func render_battle() -> void:
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
		var ability_menu := _build_overlay("소모 효과 선택 · 우클릭 취소")
		var ability_unit: Dictionary = battle.get_unit([selection.owner, selection.index])
		for option in selection.get("options", []):
			button_at(ability_menu, "마나 %d · %s" % [int(option.get("cost", 0)), str(option.get("text", ""))], func(): choose_ability_option(option), ability_unit.mana < int(option.get("cost", 0)))
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

func select_ability(owner: int, slot: int) -> void:
	var unit: Dictionary = battle.get_unit([owner, slot])
	var c: Dictionary = unit.card
	var available: Array = battle.ability_options(c)
	if available.size() > 1:
		selection = {"action":"ability","owner":owner,"index":slot,"mode":"ability_choice","options":available}
		return
	if available.is_empty(): return
	selection = {"action":"ability","owner":owner,"index":slot}
	choose_ability_option(available[0])

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
	if online_mode:
		var intent := {"type":"ability","owner":selection.owner,"index":selection.index,"target":target,"effect":selection.effect}
		selection.clear()
		_send_online_intent(intent)
		return
	var before := battle.priority
	var accepted := battle.ability(selection.owner, selection.index, target, str(selection.get("copied_id", "")), selection.get("copied_unit", []), str(selection.get("effect", "")))
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
		if online_mode:
			_send_online_intent({"type": "spell", "owner": owner, "index": index, "target": []})
		else:
			var before := battle.priority
			var accepted := battle.cast_spell(owner, index, [])
			info = "" if accepted else "지금은 이 주문을 사용할 수 없습니다."
			if accepted: after_action(before)
		return
	selection = {"action": "spell", "owner": owner, "index": index, "mode": "target", "kind": spell_kind, "effect": c.spell}
	if c.spell == "copy":
		selection.mode = "copy"
		selection.prompt = "주문 효과를 빌릴 아군 유닛을 선택하세요. 수습생과 조건부 주문은 제외됩니다."
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
	if mode != "target": return false
	if target in selection.get("chosen_targets", []): return false
	var action := str(selection.get("action", ""))
	var index := int(selection.get("index", -1))
	if action not in ["attack", "ability", "spell"]: return false
	if action != "spell" and index < 0: return false
	var is_replayed_spell: bool = action == "ability" and not str(selection.get("copied_id", "")).is_empty()
	var source: Array = [] if action == "spell" or is_replayed_spell else [owner, index]
	return battle.valid_target(owner, source, target, str(selection.get("kind", "")), str(selection.get("effect", "")))

func choose_target(target: Array) -> void:
	var mode := str(selection.get("mode", ""))
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
	if online_mode:
		var intent := {"type": selection.action, "owner": selection.owner, "index": selection.index, "target": target, "copied_id": selection.get("copied_id", ""), "copied_unit": selection.get("copied_unit", []), "effect":selection.get("effect", "")}
		selection.clear()
		_send_online_intent(intent)
		return
	var before := battle.priority
	var accepted := false
	match selection.action:
		"attack": accepted = battle.attack(selection.owner, selection.index, target)
		"ability": accepted = battle.ability(selection.owner, selection.index, target, selection.get("copied_id", ""), [], selection.get("effect", ""))
		"spell": accepted = battle.cast_spell(selection.owner, selection.index, target, selection.get("copied_unit", []))
	selection = {}
	info = "" if accepted else "지금은 수행할 수 없는 행동입니다. 대상과 마나를 확인하세요."
	after_action(before)

func choose_gamble(target: Array) -> void:
	if online_mode:
		_send_online_intent({"type": "roll_target", "target": target})
		return
	var before := battle.priority
	battle.choose_roll_target(target)
	after_action(before)

func choose_gamble_spell(index: int) -> void:
	if online_mode:
		_send_online_intent({"type": "roll_spell", "index": index})
		return
	var before := battle.priority
	battle.choose_roll_spell(index)
	after_action(before)

func pass_action() -> void:
	if online_mode:
		_send_online_intent({"type": "pass"})
		return
	var before := battle.priority
	battle.pass_priority()
	after_action(before)

func end_action() -> void:
	if online_mode:
		_send_online_intent({"type": "end_turn"})
		return
	var before := battle.priority
	battle.request_end()
	after_action(before)

func choose_growth(grow: bool) -> void:
	if online_mode:
		_send_online_intent({"type": "growth", "grow": grow})
	else:
		battle.grow_potato(grow)
		render()

func choose_deploy(choice: int) -> void:
	if online_mode:
		_send_online_intent({"type": "deploy", "choice": choice})
	else:
		battle.deploy(choice)
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

func show_rules() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "TWELVE · 최신 규칙"
	dialog.min_size = Vector2i(700, 600)
	var text_view := RichTextLabel.new()
	text_view.custom_minimum_size = Vector2(780, 600)
	text_view.text = FileAccess.get_file_as_string("res://RULEBOOK.md")
	text_view.add_theme_font_size_override("normal_font_size", 18)
	dialog.add_child(text_view)
	add_child(dialog)
	dialog.popup_centered(Vector2i(850, 700))
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())
