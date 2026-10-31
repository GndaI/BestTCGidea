extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + title)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + filename + ".png")

func wait_for_effects(scene: Control, timeout: float = 8.0) -> void:
	var elapsed := 0.0
	while scene.playing_effects and elapsed < timeout:
		await create_timer(0.05).timeout
		elapsed += 0.05
	check(not scene.playing_effects, "animation finishes within time limit")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.ai_enabled = false
	scene.auto_pass = false
	scene.start_screen = false
	scene.set_process(false)
	scene.render()
	await process_frame
	await process_frame
	check(scene.draft_card_views.size() == 21, "all playable draft candidates tracked while gambler is banned")
	check(scene.deck_card_views.size() == 12, "complete deck has twelve cards")
	var selected_count := 0
	for view in scene.draft_card_views:
		if view.draft_selected: selected_count += 1
	check(selected_count == 12, "selected candidates marked")
	var first: TCGCardView = scene.draft_card_views[0]
	var point := first.get_global_rect().get_center()
	scene._update_hover_preview(point)
	check(scene.hover_source == first and is_instance_valid(scene.hover_spell), "draft hover shows description")
	scene._update_hover_preview(point)
	check(scene.hover_source == first, "draft hover remains through update")
	await capture("draft-selected-hover")
	scene.hide_card_preview()
	var id: String = scene.decks[0][0][0]
	scene.toggle_draft(1, id)
	await process_frame
	check(scene.deck_card_views.size() == 11, "deck overview updates after deselection")
	scene.toggle_draft(1, id)
	await process_frame
	await process_frame
	check(scene.deck_card_views.size() == 12, "deck overview updates after selection")
	scene.board_scroll.ensure_control_visible(scene.deck_overview)
	await process_frame
	scene.board_scroll.scroll_vertical += int(scene.deck_overview.get_global_rect().position.y - 30)
	await process_frame
	await capture("deck-overview")
	var deck_view: TCGCardView = scene.deck_card_views[0]
	scene._update_hover_preview(deck_view.get_global_rect().get_center())
	check(scene.hover_source == deck_view, "complete-deck cards also show descriptions")
	scene.hide_card_preview()
	scene.begin_game()
	var b: TCGBattle = scene.battle
	b.players[0].units.clear()
	b.players[1].units.clear()
	for unit_id in ["healer", "tank", "archer", "mage", "traitor"]: b.players[0].units.append(b.make_unit(unit_id))
	for unit_id in ["assassin", "viper", "rock", "thorn", "mana_dragon", "dragon"]: b.players[1].units.append(b.make_unit(unit_id))
	b.players[0].revealed = 5
	b.players[1].revealed = 6
	b.players[0].used = [TCGCards.by_id("tank")]
	b.players[1].used = [TCGCards.by_id("dragon")]
	b.players[0].deck[5] = ["gambler", "dragon"]
	b.phase = "action"
	b.get_unit([1,0]).alive = false
	b.get_unit([1,0]).hp = 0
	scene.render()
	await process_frame
	var unused_area: Node = scene.root.find_child("UnusedSpellArea", true, false)
	check(is_instance_valid(unused_area) and unused_area.get_global_rect().position.x < scene.get_viewport_rect().size.x * 0.5, "unused spells stay in the lower-left area")
	check(is_instance_valid(scene.used_archive_badge) and scene.used_archive_badge.get_global_rect().position.x > scene.get_viewport_rect().size.x * 0.5, "used-spell summary sits at the upper right")
	scene.show_used_spells_popup(scene.used_archive_badge)
	await process_frame
	await process_frame
	var used_archive: Node = scene.hover_layer.find_child("UsedSpellArchive", true, false)
	check(is_instance_valid(used_archive) and scene.used_spell_views.size() == 2 and used_archive.get_child(0).get_child(1).get_child_count() == 2, "hovering the summary reveals used spells separated by player")
	var archive_labels: Array = used_archive.find_children("*", "Label", true, false)
	check(archive_labels.any(func(label): return "보호막" in label.text) and archive_labels.any(func(label): return "피해" in label.text), "used spell archive keeps effect descriptions visible")
	check(scene.board_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scene.board_scroll.scroll_vertical == 0, "battle screen disables whole-screen scrolling")
	check(scene.root.get_global_rect().end.y <= scene.get_viewport_rect().end.y + 1.0, "the complete battle layout fits inside the viewport")
	var normal_field_rect: Rect2 = scene.field_panels[0].get_global_rect()
	var normal_grid: GridContainer = scene.field_scrolls[0].get_child(0).get_child(0)
	check(normal_field_rect.position.x >= 20.0 and normal_grid.get_child_count() == 6, "normal board keeps its original margins and six cells")
	var field_card: TCGCardView = scene.unit_views["0:0"]
	check(field_card.custom_minimum_size.is_equal_approx(Vector2(200, 280)) and is_equal_approx(field_card.visual_scale, 1.0), "normal field cards use the shared 200 by 280 reference size without an extra visual scale")
	check(absf(normal_grid.get_global_rect().get_center().x - scene.get_viewport_rect().size.x * 0.5) < 2.0, "normal six-cell board is centered")
	check(scene.field_panels[0].get_theme_stylebox("panel").shadow_size > 0 and scene.field_panels[1].get_theme_stylebox("panel").shadow_size == 0, "current turn player's board has a soft glow")
	var dead_view: TCGCardView = scene.unit_views["1:0"]
	scene.show_card_preview(dead_view)
	check(is_instance_valid(scene.hover_card) and scene.hover_card.card.id == "assassin", "defeated unit reveals its card on hover")
	scene.hide_card_preview()
	b.get_unit([1,0]).alive = true
	b.get_unit([1,0]).hp = b.get_unit([1,0]).max_hp
	b.phase = "deploy"
	scene.render()
	check(b.deploy(0), "gambler deploys")
	check(b.visual_events.any(func(event): return event.kind == "field_destroy"), "gambler queues whole-field destruction")
	check(b.visual_events.any(func(event): return event.kind == "arrival"), "gambler arrival event")
	check(b.players[0].units.slice(0, 5).all(func(unit): return not unit.alive and unit.board_slot == TCGBattle.BOARD_DOCK), "destroyed field cards leave their board cells")
	scene.render()
	await create_timer(0.15).timeout
	check(scene.playing_effects and scene.effect_blocker.visible, "arrival animation blocks input")
	var destruction_fx: Array = scene.find_children("*", "TCGGambleFX", true, false)
	check(destruction_fx.filter(func(fx): return fx.kind == "slot_break").size() == 6, "the six actual summon cells crack at the same time")
	await capture("gambler-arrival")
	await create_timer(1.65).timeout
	var summon_fx: Array = scene.find_children("*", "TCGGambleFX", true, false)
	check(summon_fx.any(func(fx): return fx.kind == "arrival"), "high-rank arrival animation follows field destruction")
	await capture("gambler-high-rank-summon")
	await wait_for_effects(scene)
	await process_frame
	var demon: TCGCardView = scene.unit_views["0:5"]
	check(scene.gambler_docks.has(0), "gambler has separate dock")
	check(absf(demon.get_global_rect().get_center().x - scene.get_viewport_rect().size.x * 0.5) < 5, "gambler centered")
	check(demon.get_global_rect().position.y >= scene.field_scrolls[0].get_global_rect().end.y, "gambler below own board")
	check(not scene.field_scrolls[0].is_ancestor_of(demon), "gambler does not move with board scroll")
	check(scene.root.get_global_rect().end.y <= scene.get_viewport_rect().end.y + 1.0, "demon board, enlarged dock, hand, and used spells still fit on one screen")
	check(demon.get_global_rect().size.x >= 120 and demon.get_global_rect().size.y >= 170, "gambler card is displayed at an emphasized larger size")
	var demon_card_text: Array = demon.find_children("*", "RichTextLabel", true, false)
	check(demon_card_text.any(func(label): return "1[color=#ff5364]6[/color]" in label.text), "gambler stat 16 paints only the six red")
	scene.show_card_preview(demon)
	var red_six_text: Array = scene.hover_spell.find_children("*", "RichTextLabel", true, false)
	check(red_six_text.any(func(label): return "[color=#ff5364]6[/color]" in label.text), "all sixes in gambler rules are red")
	scene.hide_card_preview()
	b.finishing = true
	b.end_rolls = [{"uid": b.get_unit([0,5]).uid, "roll": 1}]
	b.process_end_rolls()
	check(b.phase == "roulette" and b.players[0].units.size() == 6, "roulette starts before summon applies")
	scene.render()
	await create_timer(0.4).timeout
	check(b.phase == "roulette" and b.players[0].units.size() == 6, "outcome not applied while spinning")
	check(scene.playing_effects and scene.ai_timer.is_stopped() and scene.auto_timer.is_stopped(), "AI and automatic pass wait for roulette")
	var roulettes: Array = scene.effect_blocker.find_children("*", "Control", false, false)
	var wheel: TCGGambleFX
	for node in roulettes:
		if node is TCGGambleFX: wheel = node
	check(is_instance_valid(wheel) and wheel.result == 1, "displayed roulette matches real result")
	await capture("gambler-roulette-spin")
	await create_timer(1.55).timeout
	check(is_instance_valid(wheel) and "수호자 소환" in wheel.result_label.text, "roulette shows effect name at stop")
	await capture("gambler-roulette-result")
	await wait_for_effects(scene)
	await process_frame
	await process_frame
	check(b.players[0].units.size() == 12, "six minions spawned after roulette")
	var lane: ScrollContainer = scene.field_scrolls[0]
	check(lane.size.x > scene.get_viewport_rect().size.x * 0.8, "board lane uses full viewport width")
	var board_row := lane.get_child(0)
	check(board_row.get_child_count() == 9, "demon board shows nine base cells")
	var unit_view: TCGCardView = scene.unit_views["0:6"]
	var last_view: TCGCardView = scene.unit_views["0:11"]
	check(lane.is_ancestor_of(unit_view) and lane.is_ancestor_of(last_view), "minions in main board")
	check(absf(unit_view.get_global_rect().position.y - last_view.get_global_rect().position.y) > 1, "demon board cells use irregular vertical positions")
	check(last_view.get_global_rect().position.x > unit_view.get_global_rect().position.x, "minions extend to right")
	var occupied := {}
	for index in range(6, 12): occupied[b.get_unit([0, index]).board_slot] = true
	check(occupied.size() == 6 and range(6).all(func(slot): return occupied.has(slot)), "first summons fill empty demon-board cells in order")
	var presentation := b.presentation_enabled
	b.presentation_enabled = false
	b.apply_roll({"uid": b.get_unit([0,5]).uid, "roll": 2})
	b.presentation_enabled = presentation
	scene.render()
	await process_frame
	await process_frame
	lane = scene.field_scrolls[0]
	check(b.get_unit([0,12]).board_slot == 6 and b.get_unit([0,13]).board_slot == 7, "summons use remaining empty cells before overflowing")
	check(lane.scroll_horizontal == 0 and lane.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "nine-cell demon board does not scroll horizontally")
	unit_view = scene.unit_views["0:6"]
	last_view = scene.unit_views["0:13"]
	check(absf(unit_view.get_global_rect().position.y - last_view.get_global_rect().position.y) > 1, "nine demon cells retain irregular vertical positions")
	b.presentation_enabled = false
	b.apply_roll({"uid": b.get_unit([0,5]).uid, "roll": 2})
	b.presentation_enabled = presentation
	scene.render()
	await process_frame
	await process_frame
	check(b.get_unit([0,14]).board_slot == 8, "last empty demon-board cell fills")
	check(b.players[0].units.size() == 15 and b.board_card_count(0) == 9, "summoning stops at nine board cards")
	await capture("gambler-expanded-board")
	b.phase = "choice"
	b.priority = 0
	b.active = 0
	b.choice = {"uid": b.get_unit([0,5]).uid, "roll": 5}
	b.presentation_enabled = false
	var effects_before_gamble: bool = scene.effects_enabled
	scene.effects_enabled = false
	scene.render()
	await process_frame
	var gamble_source: TCGCardView = scene.unit_views["0:5"]
	var gamble_target: TCGCardView = scene.unit_views["1:0"]
	var hp_before: int = b.get_unit([1,0]).hp
	check(not scene.overlay_layer.visible and scene.begin_drag([0,5], gamble_source.get_global_rect().get_center()), "gambler damage target starts by dragging from the demon")
	scene.drag_moved = true
	scene.finish_drag(gamble_target.get_global_rect().get_center())
	check(b.get_unit([1,0]).hp == maxi(0, hp_before - 6), "gambler drag applies six damage to the dropped-on field card")
	scene.effects_enabled = effects_before_gamble
	b.presentation_enabled = presentation
	b.finishing = true
	b.end_rolls = [{"uid":b.get_unit([0,5]).uid,"roll":6}]
	b.process_end_rolls()
	var snapshot: Dictionary = scene._pack_online_state()
	check(snapshot.pending_roll.roll == 6 and snapshot.phase == "roulette", "roulette serializes to remote")
	check(b.get_unit([0,5]).dice == 1, "extra die not applied before animation")
	b.visual_events.clear()
	b.complete_roll()
	check(b.get_unit([0,5]).dice == 2, "extra die applied after animation")
	check(b.visual_events.any(func(event): return event.kind == "turn_start" and event.amount == b.turn_index + 1 and event.owner == b.active), "turn change queues centered turn banner")
	scene.render()
	await create_timer(0.25).timeout
	check(not scene.effect_blocker.find_children("TurnBanner", "PanelContainer", true, false).is_empty(), "turn banner appears in the center")
	await wait_for_effects(scene)
	scene.queue_free()
	await process_frame
	print("DECK/GAMBLE UI CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
