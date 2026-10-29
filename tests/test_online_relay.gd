extends SceneTree

const MainScene = preload("res://main.tscn")
const LOCAL_SERVER := "http://127.0.0.1:24832"

var host
var guest
var join_started := false
var draft_started := false
var host_deck_sent := false
var guest_deck_sent := false
var sync_probe_sent := false

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
	host.create_public_web_room()
	for _step in range(1600):
		if not join_started and host.current_room_code.length() == 6:
			join_started = true
			guest.join_public_room(host.current_room_code)
		if not draft_started and host.online_state == "lobby" and guest.online_state == "lobby":
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
			if not sync_probe_sent:
				sync_probe_sent = true
				guest._send_online_intent({"type": "invalid_sync_probe"})
			elif not guest.waiting_for_sync and host.battle.phase == guest.battle.phase:
				print("ONLINE RELAY MATCH CHECKS: lobby, draft, decks, battle sync | FAILURES: 0")
				host.stop_network()
				guest.stop_network()
				quit(0)
				return
		if host.online_state in ["disconnected", "sync_failed"] or guest.online_state in ["disconnected", "sync_failed"]:
			push_error("relay match disconnected: host=%s guest=%s" % [host.online_state, guest.online_state])
			quit(1)
			return
		await create_timer(0.01).timeout
	push_error("relay match timed out: host=%s guest=%s" % [host.online_state, guest.online_state])
	quit(1)
