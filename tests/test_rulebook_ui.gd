extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + title)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.theme.get_constant("outline_size", "Label") == 0 and scene.theme.get_constant("outline_size", "Button") == 0, "ordinary labels and buttons avoid black outlines that fill counters and Latin letter interiors")
	var font_import_settings := FileAccess.get_file_as_string("res://assets/fonts/NotoSansKR-Variable.ttf.import")
	check("multichannel_signed_distance_field=false" in font_import_settings and "oversampling=2.0" in font_import_settings, "web fonts use color-safe high-resolution rasterization instead of artifact-prone multichannel distance fields")
	var emphasis_probe := Label.new()
	scene.emphasize_label(emphasis_probe, 0.42)
	check(emphasis_probe.get_theme_constant("outline_size") == 0 and emphasis_probe.get_theme_constant("shadow_offset_x") == 1 and emphasis_probe.get_theme_constant("shadow_offset_y") == 2, "emphasized text such as TWELVE uses an offset shadow instead of an intrusive outline")
	emphasis_probe.queue_free()
	scene.effects_enabled = false
	scene.ai_enabled = false
	scene.auto_pass = false
	scene.start_screen = false
	scene.render()
	check(is_equal_approx(scene.FIELD_CARD_ASPECT, 1.4), "battle field cards use the same 200 by 280 aspect ratio as their internal layout")
	check(TCGCardView.POWER_GEM_CENTER == Vector2(40, 240) and TCGCardView.MANA_GEM_CENTER == Vector2(100, 240) and TCGCardView.HEALTH_GEM_CENTER == Vector2(160, 240), "battle card stats and mana share one centered bottom row")
	check(is_equal_approx(TCGCardView.STAT_GEM_RADIUS, 27.0), "production stays compact while leaving room for two-digit values")
	var field_shape_card := TCGCardView.new()
	check(TCGCardView.FIELD_POWER_FILL == Color("8c741b") and TCGCardView.FIELD_MANA_FILL == Color("0754a3"), "field production is yellow and mana reuses the former production blue")
	check(field_shape_card.field_mana_badge_points().size() == 4 and field_shape_card.field_mana_badge_points()[0] == Vector2(100, 212), "field mana uses a centered blue diamond")
	check(field_shape_card.field_health_badge_points().size() == 6 and field_shape_card.field_health_badge_points()[0] == Vector2(160, 212), "field health uses the same vertical hexagon language as non-field cards")
	field_shape_card.queue_free()
	check(scene.decks[0].size() == 6, "six pairs in draft")
	scene.begin_game()
	var b: TCGBattle = scene.battle
	check(is_instance_valid(scene.battle_log_badge) and scene.battle_log_badge.visible, "magical battle-log badge stays at the lower right")
	scene.show_battle_log_popup()
	check(is_instance_valid(scene.battle_log_popup) and scene.battle_log_popup.find_children("*", "RichTextLabel", true, false).size() == 1, "battle-log badge reveals the recorded actions on hover")
	scene.hide_battle_log_popup()
	var test_sound: AudioStreamWAV = scene.sound_fx._make_tone(440.0, 0.05, "sine", 0.0, 0.0)
	check(test_sound.data.size() > 0, "procedural game sound is generated")
	check(scene._event_target_view({"kind":"roulette", "target":[]}) == null, "fieldless gambler-spell roulette safely uses the screen center")
	check(FileAccess.file_exists("res://카드-템플릿.md"), "copy-ready card template exists")
	var centered_name_card := TCGCardView.new()
	centered_name_card.configure(TCGCards.by_id("healer"))
	root.add_child(centered_name_card)
	await process_frame
	var centered_name_label := centered_name_card.find_child("CardName", true, false) as Label
	check(centered_name_card.uses_reference_layout() and is_instance_valid(centered_name_label) and centered_name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and centered_name_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER and centered_name_label.position == Vector2(14, 123) and centered_name_label.size == Vector2(172, 32), "non-field card names are centered in the reference-style name bar")
	var turn_suffix := centered_name_card.find_child("TurnSuffix", true, false) as Label
	var printed_effect := centered_name_card.find_child("CardEffectText", true, false) as RichTextLabel
	var printed_effect_font := printed_effect.get_theme_font("normal_font") as FontVariation
	check(centered_name_card.art_rect() == Rect2(46, 15, 108, 108) and is_instance_valid(centered_name_card.find_child("CardType", true, false)), "non-field cards use the portrait medallion and printed unit type")
	check(is_instance_valid(printed_effect_font) and is_equal_approx(printed_effect_font.variation_embolden, 0.45) and printed_effect.get_theme_constant("line_separation") == 2, "printed effect text uses medium weight and two pixels of extra line spacing")
	check(centered_name_card.tier_number_rect().get_center().x == 22.0, "the tier number sits three pixels left of the badge center")
	check(is_instance_valid(turn_suffix) and turn_suffix.position == Vector2(29, 19) and turn_suffix.get_theme_font_size("font_size") == 9, "the small turn suffix sits beside the large tier number instead of below it")
	centered_name_card.queue_free()
	var field_name_card := TCGCardView.new()
	field_name_card.configure(TCGCards.by_id("healer"), -1, -1, 2)
	root.add_child(field_name_card)
	await process_frame
	var field_name_label := field_name_card.find_child("CardName", true, false) as Label
	check(field_name_card.name_bar_rect().position.y == 10.0 and is_instance_valid(field_name_label) and field_name_label.position == Vector2(14, 10) and field_name_label.size == Vector2(172, 34), "field card names use the free upper area and fill the name bar for vertical centering")
	check(field_name_card.art_rect().position.y == 49.0 and field_name_card.art_rect().position.y == field_name_card.name_bar_rect().end.y + 5.0, "field artwork starts exactly five pixels below the name bar")
	var field_power_value := field_name_card.find_child("PowerValue", true, false) as Label
	var field_mana_value := field_name_card.find_child("ManaValue", true, false) as Label
	var field_health_value := field_name_card.find_child("HealthValue", true, false) as Label
	check(field_power_value.get_rect().get_center() == Vector2(40, 240) and field_mana_value.get_rect().get_center() == Vector2(100, 240) and field_health_value.get_rect().get_center() == Vector2(160, 240.5), "field production, mana, and health values are centered on their shapes")
	check(field_power_value.vertical_alignment == VERTICAL_ALIGNMENT_CENTER and field_mana_value.vertical_alignment == VERTICAL_ALIGNMENT_CENTER and field_health_value.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "field stat labels are vertically centered instead of relying on a text baseline")
	field_name_card.queue_free()
	var mana_glow_card := TCGCardView.new()
	mana_glow_card.configure(TCGCards.by_id("healer"), -1, -1, 1)
	check(mana_glow_card.has_mana_glow() and mana_glow_card.inner_border_color() == Color("b6a57a"), "mana adds only the green outer glow without the blue target border")
	mana_glow_card.mana = 0
	check(not mana_glow_card.has_mana_glow(), "the mana glow stops immediately at zero mana")
	mana_glow_card.queue_free()
	var target_pulse_card := TCGCardView.new()
	target_pulse_card.configure(TCGCards.by_id("tank"))
	target_pulse_card.highlighted = true
	root.add_child(target_pulse_card)
	await process_frame
	var pulse_low := target_pulse_card.target_pulse_alpha(3.0 / (4.0 * 1.15))
	var pulse_high := target_pulse_card.target_pulse_alpha(1.0 / (4.0 * 1.15))
	target_pulse_card._process(3.0 / (4.0 * 1.15))
	check(target_pulse_card.is_processing() and pulse_low <= 0.57 and pulse_high >= 0.99 and target_pulse_card.modulate.a < 1.0 and target_pulse_card.self_modulate == Color.WHITE and target_pulse_card.inner_border_color() == Color("b6a57a"), "valid targets and their child stat numbers pulse together without a blue border")
	target_pulse_card.queue_free()
	var turn_slot_card := TCGCardView.new()
	turn_slot_card.configure({})
	turn_slot_card.face_down = true
	turn_slot_card.caption = "3턴"
	root.add_child(turn_slot_card)
	await process_frame
	var turn_slot_label: RichTextLabel = turn_slot_card.find_children("*", "RichTextLabel", true, false)[0]
	check(turn_slot_label.text == "[center]3턴[/center]" and turn_slot_label.position.y == 166.0 and turn_slot_label.get_theme_font_size("normal_font_size") == 30, "empty battle slots show only the turn in the deck-editor label position and size")
	turn_slot_card.queue_free()
	var enter_key: InputEventKey = InputEventKey.new()
	enter_key.keycode = KEY_ENTER
	enter_key.pressed = true
	b.players[0].units = []
	b.players[1].units = []
	for id in ["healer","tank","traveler","bean","traitor","gambler"]:
		b.players[0].units.append(b.make_unit(id))
	for id in ["assassin","viper","rock","thorn","mana_dragon","phoenix"]:
		b.players[1].units.append(b.make_unit(id))
	b.players[0].special = true
	b.players[0].units.append(b.make_unit("token_guard"))
	b.players[0].units.append(b.make_unit("token_six"))
	b.players[0].hand = [TCGCards.by_id("student"),TCGCards.by_id("phoenix")]
	b.players[1].hand = [TCGCards.by_id("thorn")]
	b.phase = "action"
	b.priority = 0
	b.get_unit([0,0]).mana = 2
	scene.render()
	await process_frame
	await process_frame
	check(scene.unit_views.size() == 14, "special summons rendered")
	var active_zone: PanelContainer = scene.root.find_child("PlayerZone%d" % b.active, true, false)
	check(is_instance_valid(active_zone) and active_zone.get_theme_stylebox("panel").shadow_size > 0, "the active player's whole upper or lower zone glows")
	scene.selection = {"action":"attack", "owner":0, "index":0}
	check(not scene.target_eligible([1,0]), "incomplete network drag selection is ignored safely")
	scene.selection.clear()
	var fixed_action_button_position: Vector2 = scene.action_button.global_position
	scene._input(enter_key)
	check(b.ending and b.priority == 1, "Enter declares turn end when the active player has no open chain")
	check(scene.action_button.visible, "the on-screen action button remains available with the Enter shortcut")
	b.ending = false
	b.priority = 0
	b.passes = 0
	scene.render()
	await process_frame
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	check(scene.begin_drag([0,0],Vector2.ZERO), "drag starts")
	scene._input(right_click)
	check(scene.drag_source.is_empty() and b.get_unit([0,0]).mana == 2, "right-click cancels attack drag without cost")
	b.priority = 1
	check(not scene.begin_drag([1,0],Vector2.ZERO), "opponent cannot drag attack")
	b.priority = 0
	scene.select_spell(0)
	check(scene.selection.mode == "copy", "student source selection")
	check(not scene.target_eligible([1,1]), "enemy copy rejected in UI")
	check(scene.target_eligible([0,1]), "allied normal spell copy available")
	scene.cancel_selection()
	var apprentice := b.make_unit("student")
	apprentice.mana = 1
	b.players[0].units.append(apprentice)
	b.players[0].used = [TCGCards.by_id("healer")]
	var apprentice_slot: int = b.players[0].units.size() - 1
	scene.select_ability(0, apprentice_slot)
	check(scene.selection.mode == "replay", "apprentice opens used-spell selection")
	scene._input(right_click)
	check(scene.selection.is_empty(), "right-click cancels apprentice spell selection")
	scene.select_ability(0, apprentice_slot)
	scene.select_replay(TCGCards.by_id("healer"))
	check(scene.selection.mode == "target", "apprentice proceeds to copied-spell target")
	scene._input(right_click)
	check(scene.selection.is_empty(), "right-click cancels apprentice copied-spell target")
	b.defeat([0,0])
	b.open_reactions()
	scene.render()
	await process_frame
	check(not is_instance_valid(scene.root.find_child("DefeatedArchive0", true, false)), "demon board no longer shows a permanent defeated-unit field")
	scene.select_spell(1)
	var defeated_picker: Node = scene.root.find_child("DefeatedTargetPicker0", true, false)
	check(is_instance_valid(defeated_picker) and defeated_picker.is_ancestor_of(scene.unit_views["0:0"]), "defeated units appear only while choosing a valid revival target")
	check(scene.target_eligible([0,0]), "corpse target eligible")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene.unit_views["0:0"].gui_input.emit(press)
	check(b.stack.size() == 1 and b.stack[0].effect == "revive_later", "corpse click casts resurrection")
	check(scene.action_button.has_theme_stylebox_override("normal") and "지금 내 대응 차례" in scene.action_button.text, "response priority brightly highlights the fixed action button")
	check(is_instance_valid(scene.chain_center_badge) and "CHAIN 1" in scene.chain_center_badge.find_children("*", "Label", true, false)[0].text, "chain is presented with a Master Duel-style chain number")
	check(scene.chain_center_badge.get_global_rect().get_center().y < scene.get_viewport_rect().size.y * 0.2, "chain badge stays at the top of the screen")
	var left_chain_title: Vector2 = scene.arrow_layer.title_position(Vector2(60, 400), 180)
	var right_chain_title: Vector2 = scene.arrow_layer.title_position(Vector2(scene.get_viewport_rect().size.x - 60, 400), 180)
	check(left_chain_title.x > 60 and right_chain_title.x + 180 < scene.get_viewport_rect().size.x - 60, "chain arrow captions sit inward beside side cards")
	check(scene.action_button.global_position.is_equal_approx(fixed_action_button_position), "action button stays fixed when a chain appears")
	await create_timer(1.55).timeout
	check(not scene.chain_layer.visible and b.stack.size() == 1, "chain overlay fades without resolving or removing the open chain")
	scene._input(enter_key)
	check(b.passes == 1, "Enter declares no additional chain")
	b.pass_priority()
	check(b.get_unit([0,0]).revive_at == 3, "resurrection scheduled")
	b.phase = "choice"
	b.choice = {"uid": b.get_unit([0,5]).uid,"roll":3}
	b.priority = 0
	scene.render()
	check(scene.overlay_layer.visible, "gambler choice overlay")
	scene.choose_gamble([0,0])
	check(b.get_unit([0,0]).alive, "gambler chooses corpse")
	b.phase = "action"
	b.priority = 0
	scene.render()
	await process_frame
	var packed: Dictionary = scene._pack_online_state()
	var replica = load("res://main.tscn").instantiate()
	root.add_child(replica)
	await process_frame
	replica._restore_online_state(packed)
	check(replica.battle.get_unit([0,5]).uid == b.get_unit([0,5]).uid, "uid serializes")
	check(replica.battle.get_unit([0,6]).card.id == "token_guard", "summon serializes")
	check(replica.battle.players[0].own_turn == b.players[0].own_turn, "own turn serializes")
	check(replica.battle.players[0].special, "special field serializes")
	check(replica.battle.production(replica.battle.get_unit([1,1])) == b.production(b.get_unit([1,1])), "aura production matches remote")
	replica.queue_free()
	await process_frame
	scene.render()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/rulebook-board.png")
		scene.set_process(false)
		scene.show_card_preview(scene.unit_views["0:5"])
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/rulebook-hover.png")
		scene.hide_card_preview()
	scene.show_rules()
	await process_frame
	check(scene.find_children("*","AcceptDialog",false,false).size() > 0, "rules dialog opens")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/rulebook-dialog.png")
	scene.queue_free()
	await process_frame
	var feature_scene = load("res://main.tscn").instantiate()
	root.add_child(feature_scene)
	await process_frame
	check(feature_scene.join_address.begins_with("ws://"), "web edition defaults to a WebSocket server URL")
	feature_scene.open_patch_notes()
	await process_frame
	await process_frame
	var patch_version_menu: MenuButton = feature_scene.root.find_child("PatchVersionMenu", true, false)
	var patch_notes_scroll: ScrollContainer = feature_scene.root.find_child("PatchNotesScroll", true, false)
	check(is_instance_valid(patch_version_menu) and patch_version_menu.get_popup().item_count == feature_scene.PATCH_NOTES.size(), "patch notes provide a fixed version finder with every released version")
	var web_birth_index := -1
	for note_index in range(feature_scene.PATCH_NOTES.size()):
		if str(feature_scene.PATCH_NOTES[note_index].get("version", "")) == "0.0.1":
			web_birth_index = note_index
			break
	patch_version_menu.get_popup().id_pressed.emit(web_birth_index)
	await process_frame
	check("0.0.1 보는 중" in patch_version_menu.text, "version finder labels the selected patch")
	check(patch_notes_scroll.scroll_vertical > 0, "version finder jumps the existing scroll view to the selected patch")
	var scroll_marker: PanelContainer = feature_scene.root.find_child("PatchScrollPositionMarker", true, false)
	var scroll_marker_label: Label = feature_scene.root.find_child("PatchScrollPositionLabel", true, false)
	var scroll_marker_timer: Timer = feature_scene.root.find_child("PatchScrollMarkerHideTimer", true, false)
	check(is_instance_valid(scroll_marker) and scroll_marker.modulate.a > 0.99 and "0.0.1" in scroll_marker_label.text, "scrolling shows the current version beside the scrollbar")
	scroll_marker_timer.stop()
	scroll_marker_timer.timeout.emit()
	await create_timer(0.75).timeout
	check(scroll_marker.modulate.a < 0.05, "current-version scroll marker fades after scrolling stops")
	var latest_version := str(feature_scene.PATCH_NOTES[0].get("version", "")).replace(".", "_")
	check(is_instance_valid(feature_scene.root.find_child("PatchNoteVersion" + latest_version + "Latest", true, false)), "latest patch has a distinct latest marker")
	var change_marker: Control = feature_scene.root.find_child("PatchItemIconChange", true, false)
	check(is_instance_valid(change_marker), "changed patch items use the blue rotating-arrow marker")
	check(is_instance_valid(change_marker) and change_marker.custom_minimum_size.x <= 20.0, "patch item markers occupy only the former bullet-sized column")
	check(is_instance_valid(change_marker) and change_marker.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "patch item markers align vertically with their text")
	check(is_instance_valid(feature_scene.root.find_child("PatchItemIconAdd", true, false)), "added patch items use the green plus marker")
	check(is_instance_valid(feature_scene.root.find_child("PatchItemIconRemove", true, false)), "removed patch items use the red minus marker")
	var latest_patch: Control = feature_scene.root.find_child("PatchNoteVersion" + latest_version + "Latest", true, false)
	var latest_texts: Array[String] = []
	for latest_label in latest_patch.find_children("*", "Label", true, false):
		latest_texts.append((latest_label as Label).text)
	check("신규" in latest_texts and "변경" in latest_texts and "금지" in latest_texts, "latest card changes are separated into new, changed, and banned subsections")
	check("1/6 → 2/5" in latest_texts and "3/12 → 0/12" in latest_texts and "5/15 → 4/15" in latest_texts and "5/9 → 9/5" in latest_texts, "patch-note stat changes consistently use old power/health to new power/health notation")
	var add_subheading: Label = latest_patch.find_child("PatchSubheadingAdd", true, false)
	var change_subheading: Label = latest_patch.find_child("PatchSubheadingChange", true, false)
	var remove_subheading: Label = latest_patch.find_child("PatchSubheadingRemove", true, false)
	check(is_instance_valid(add_subheading) and add_subheading.get_theme_color("font_color") == Color("76db8f"), "new-card subsection uses green")
	check(is_instance_valid(change_subheading) and change_subheading.get_theme_color("font_color") == Color("71b9ff"), "changed-card subsection uses blue")
	check(is_instance_valid(remove_subheading) and remove_subheading.get_theme_color("font_color") == Color("ff6b72"), "banned-card subsection uses red")
	var potato_name_label: Label = null
	for latest_label in latest_patch.find_children("*", "Label", true, false):
		if (latest_label as Label).text == "최강의 감자":
			potato_name_label = latest_label as Label
			break
	check(is_instance_valid(potato_name_label) and potato_name_label.get_theme_color("font_color") == Color("c8b6ff"), "patch-note card names use a distinct lavender color")
	check(is_instance_valid(potato_name_label) and not potato_name_label.get_parent() is HBoxContainer, "patch-note status markers sit beside change details instead of card names")
	feature_scene.open_battle_menu()
	await process_frame
	feature_scene.open_online_menu()
	await process_frame
	check(is_instance_valid(feature_scene.online_server_edit), "native online screen provides a server URL field")
	feature_scene.online_server_address = "https://example.test/"
	check(feature_scene.signaling_url() == "wss://example.test/signal", "native HTTPS server address converts to secure signaling URL")
	check(feature_scene.rooms_url() == "https://example.test/rooms", "native server address provides the public room-list URL")
	feature_scene.online_mode = true
	feature_scene.online_host = true
	feature_scene.online_state = "lobby"
	feature_scene.start_screen = true
	feature_scene.start_page = "online"
	feature_scene.drafting = true
	feature_scene.render()
	await process_frame
	check(is_instance_valid(feature_scene.root.find_child("OnlineLobby", true, false)), "online connection opens a lobby that shows both players")
	feature_scene.online_host = false
	feature_scene.online_state = "playing"
	feature_scene.waiting_for_sync = true
	feature_scene._on_online_sync_timeout()
	check(feature_scene.online_state == "disconnected" and not feature_scene.waiting_for_sync, "sync timeout detects a missing connection instead of waiting forever")
	check("호스트 연결이 끊어졌습니다" in feature_scene.online_notice, "disconnection is reported separately from battle synchronization")
	feature_scene.stop_network()
	feature_scene.open_deck_menu()
	await process_frame
	check(is_instance_valid(feature_scene.root.find_child("SavedDeckLibrary", true, false)), "deck screen provides nine-slot saved-deck controls")
	check(is_instance_valid(feature_scene.root.find_child("BuiltinDefaultDeckSlot", true, false)), "bottom-right slot provides the original default deck")
	feature_scene.saved_decks = [{"name": "편집 확인", "cards": feature_scene._default_deck()}]
	var banned_deck: Array = feature_scene._default_deck()
	banned_deck[5][1] = "gambler"
	check(not feature_scene._valid_online_deck(banned_deck), "decks containing the temporarily banned gambler cannot enter a match")
	feature_scene.open_deck_editor(0)
	await process_frame
	var back_button: Button = feature_scene.root.find_child("BackButton", true, false)
	check(back_button.position.y == 16.0 and back_button.custom_minimum_size == Vector2(150, 48), "back button sits at the account button height without changing size")
	check(is_instance_valid(feature_scene.root.find_child("DeckTierFilter6", true, false)), "deck editor puts turn filter buttons beside search")
	var tier_filter_1: Button = feature_scene.root.find_child("DeckTierFilter1", true, false)
	var tier_filter_2: Button = feature_scene.root.find_child("DeckTierFilter2", true, false)
	tier_filter_1.button_pressed = true
	tier_filter_1.pressed.emit()
	tier_filter_2.button_pressed = true
	tier_filter_2.pressed.emit()
	check(feature_scene.deck_filter_tiers == [1, 2], "deck editor can filter multiple turns at once")
	tier_filter_1.button_pressed = false
	tier_filter_1.pressed.emit()
	tier_filter_2.button_pressed = false
	tier_filter_2.pressed.emit()
	check(feature_scene.deck_filter_tiers.is_empty() and feature_scene.root.find_child("DeckTierFilter0", true, false).button_pressed, "turn filters return to all cards when the last selected turn is pressed again")
	await process_frame
	var deck_column: VBoxContainer = feature_scene.root.find_child("EditorDeckColumn", true, false)
	var left_gaps: Array[Node] = deck_column.find_children("LeftDeckGap*", "Control", false, false)
	var left_gaps_equal := left_gaps.size() == 7
	for gap in left_gaps:
		left_gaps_equal = left_gaps_equal and gap.size_flags_vertical == Control.SIZE_EXPAND_FILL and absf(gap.size.y - left_gaps[0].size.y) <= 1.0
	check(deck_column.get_theme_constant("separation") == 0 and left_gaps_equal, "all seven gaps below the deck name row have equal height")
	var editor_tier: Node = feature_scene.root.find_child("EditorTier1", true, false)
	check(editor_tier.custom_minimum_size.y == 104 and editor_tier.size_flags_vertical != Control.SIZE_EXPAND_FILL, "left turn boxes keep their original fixed height")
	var selected_card: TCGCardView = editor_tier.find_children("*", "TCGCardView", true, false)[0]
	check(selected_card.custom_minimum_size == Vector2(70, 98) and not selected_card.draft_selected, "selected deck card keeps the 5:7 aspect ratio without green included styling")
	var card_browser: Node = feature_scene.root.find_child("DeckCardBrowser", true, false)
	var first_browser_column: Node = card_browser.get_child(0)
	var first_available_card: TCGCardView = first_browser_column.find_children("*", "TCGCardView", true, false)[0]
	var card_gaps: Array[Node] = first_browser_column.find_children("CardGap*", "Control", false, false)
	var card_gaps_equal := card_gaps.size() == 3
	for gap in card_gaps:
		card_gaps_equal = card_gaps_equal and gap.size_flags_vertical == Control.SIZE_EXPAND_FILL and absf(gap.size.y - card_gaps[0].size.y) <= 1.0
	check(first_available_card.custom_minimum_size == Vector2(200, 280) and card_gaps_equal, "available cards use the full 200 by 280 card size with equal top, middle, and bottom gaps")
	feature_scene.show_card_preview(first_available_card)
	await process_frame
	check(first_available_card.tooltip_text.is_empty() and is_instance_valid(feature_scene.hover_card) and feature_scene.hover_card.size == Vector2(330, 462) and is_instance_valid(feature_scene.hover_spell) and not is_instance_valid(feature_scene.hover_backdrop), "deck-editor cards use the same floating card and effect preview as field cards without a duplicate tooltip")
	feature_scene.hide_card_preview()
	feature_scene.queue_free()
	await process_frame
	print("RULEBOOK UI CHECKS: %d | FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
