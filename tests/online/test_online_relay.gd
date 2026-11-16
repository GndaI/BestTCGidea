extends SceneTree

const MainScene = preload("res://src/scenes/main.tscn")
const LOCAL_SERVER := "http://127.0.0.1:24832"

var host
var guest
var join_started := false
var draft_started := false
var host_deck_sent := false
var guest_deck_sent := false
var sync_probe_sent := false
var battle_step := 0
var tested_fate_id := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var server_address := OS.get_environment("ONLINE_TEST_SERVER").strip_edges()
	if server_address.is_empty():
		server_address = LOCAL_SERVER
	host = MainScene.instantiate()
	guest = MainScene.instantiate()
	root.add_child(host)
	root.add_child(guest)
	await process_frame
	host.online_server_address = server_address
	guest.online_server_address = server_address
	host.public_room_name = "윈도우 통합 시험방"
	host.selected_game_mode = host.GameModesScript.FATE_ID
	host.create_public_web_room()
	for _step in range(1600):
		if not join_started and host.current_room_code.length() == 6:
			join_started = true
			guest.join_public_room(host.current_room_code)
		if not draft_started and host.online_state == "lobby" and guest.online_state == "lobby":
			if host.current_game_mode != host.GameModesScript.FATE_ID or guest.current_game_mode != host.GameModesScript.FATE_ID:
				push_error("room game mode did not synchronize")
				quit(1)
				return
			if not guest.local_lobby_ready:
				guest.toggle_online_ready()
			elif host.remote_lobby_ready:
				draft_started = true
				host.begin_online_draft()
		if host.online_state == "draft" and not host_deck_sent:
			host_deck_sent = true
			host.decks[host.local_player] = host._default_deck()
			host.submit_selected_online_deck()
		if guest.online_state == "draft" and not guest_deck_sent:
			guest_deck_sent = true
			guest.decks[guest.local_player] = guest._default_deck()
			guest.submit_selected_online_deck()
		if host.online_state == "playing" and guest.online_state == "playing":
			if battle_step == 0 and host.battle.phase == "deploy" and guest.battle.phase == "deploy":
				if not host.battle.players[1].deck.is_empty() or not guest.battle.players[0].deck.is_empty():
					push_error("opponent deck was exposed")
					quit(1)
					return
				if host.battle.players[0].fate_hand.size() != 3 or guest.battle.players[1].fate_hand.size() != 2 or not guest.battle.players[0].fate_hand.is_empty() or int(guest.battle.players[0].fate_hand_count) != 3 or int(host.battle.players[1].fate_hand_count) != 2:
					push_error("fate opening hand privacy or first-turn draw was incorrect")
					quit(1)
					return
				battle_step = 1
				host.choose_deploy(0)
			elif battle_step == 1 and not host.waiting_for_sync and host.battle.phase == "action" and guest.battle.phase == "action":
				battle_step = 2
				host.end_action()
			elif battle_step == 2 and not host.waiting_for_sync and host.battle.ending and guest.battle.ending and guest.battle.priority == 1:
				battle_step = 3
				guest.pass_action()
			elif battle_step == 3 and not guest.waiting_for_sync and host.battle.turn_index == 1 and guest.battle.phase == "deploy":
				battle_step = 4
				guest.choose_deploy(0)
			elif battle_step == 4 and not guest.waiting_for_sync and guest.battle.phase == "action":
				battle_step = 5
				guest.end_action()
			elif battle_step == 5 and not guest.waiting_for_sync and guest.battle.ending and host.battle.priority == 0:
				battle_step = 6
				host.pass_action()
			elif battle_step == 6 and not host.waiting_for_sync and guest.battle.turn_index == 2 and guest.battle.phase == "deploy":
				battle_step = 7
				guest.choose_deploy(0)
			elif battle_step == 7 and not guest.waiting_for_sync and guest.battle.phase == "action" and int(guest.battle.players[1].units[0].mana) > 0:
				battle_step = 8
				var fate_index: int = guest.battle.players[1].fate_hand.find("recharge")
				tested_fate_id = "recharge"
				if fate_index < 0:
					fate_index = guest.battle.players[1].fate_hand.find("guard")
					tested_fate_id = "guard"
				if fate_index < 0:
					push_error("expected a zero-cost fate in the deterministic opening draws")
					quit(1)
					return
				guest._send_online_intent({"type":"activate_fate","index":fate_index,"payer":[1,0],"target":[1,0]})
			elif battle_step == 8 and not guest.waiting_for_sync and guest.battle.stack.size() == 1 and host.battle.priority == 0:
				battle_step = 9
				host.pass_action()
			elif battle_step == 9 and not host.waiting_for_sync and guest.battle.priority == 1:
				battle_step = 10
				guest.pass_action()
			elif battle_step == 10 and not guest.waiting_for_sync and guest.battle.phase == "action" and tested_fate_id in guest.battle.players[1].fate_used and ((tested_fate_id == "recharge" and int(guest.battle.players[1].units[0].mana) == 2) or (tested_fate_id == "guard" and int(guest.battle.players[1].units[0].shield) == 2)):
				battle_step = 14
			elif battle_step == 14 and not sync_probe_sent:
				sync_probe_sent = true
				guest._send_online_intent({"type": "invalid_sync_probe"})
			elif battle_step == 14 and not guest.waiting_for_sync and host.battle.phase == guest.battle.phase:
				print("ONLINE SERVER MATCH CHECKS: mode sync, private decks, fate draw/use, deploy, turn end, rejection sync | FAILURES: 0")
				host.stop_network()
				guest.stop_network()
				quit(0)
				return
		if host.online_state in ["disconnected", "sync_failed"] or guest.online_state in ["disconnected", "sync_failed"]:
			push_error("relay match disconnected: host=%s guest=%s" % [host.online_state, guest.online_state])
			quit(1)
			return
		await create_timer(0.01).timeout
	var debug_unit: Dictionary = guest.battle.players[1].units[0] if guest.battle.players.size() > 1 and not guest.battle.players[1].units.is_empty() else {}
	var host_hp = host.battle.players[0].units[0].hp if host.battle.players.size() > 0 and not host.battle.players[0].units.is_empty() else "-"
	var guest_hp = guest.battle.players[0].units[0].hp if guest.battle.players.size() > 0 and not guest.battle.players[0].units.is_empty() else "-"
	push_error("relay match timed out: host=%s guest=%s step=%d fate=%s phase=%s mana=%s shield=%s used=%s hp=%s/%s" % [host.online_state, guest.online_state, battle_step, tested_fate_id, guest.battle.phase, debug_unit.get("mana", "-"), debug_unit.get("shield", "-"), guest.battle.players[1].get("fate_used", []) if guest.battle.players.size() > 1 else [], host_hp, guest_hp])
	quit(1)
