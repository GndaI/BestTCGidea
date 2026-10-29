extends SceneTree

const TEST_PORT := 24781

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mode := "client"
	for argument in OS.get_cmdline_user_args():
		if argument == "--host": mode = "host"
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if mode == "host":
		scene.online_port = TEST_PORT
		scene.start_host()
	else:
		scene.join_address = "ws://127.0.0.1:%d" % TEST_PORT
		scene.start_join()
	var draft_started := false
	var deck_submitted := false
	var sync_probe_sent := false
	var host_playing_ticks := 0
	for _step in range(2400):
		if scene.online_state == "lobby" and mode == "host" and not draft_started:
			draft_started = true
			scene.begin_online_draft()
		if scene.online_state == "draft" and not deck_submitted:
			deck_submitted = true
			scene.decks[scene.local_player] = scene._default_deck()
			scene.submit_selected_online_deck()
		if scene.online_state == "playing":
			if mode == "client":
				if not sync_probe_sent:
					sync_probe_sent = true
					scene._send_online_intent({"type":"invalid_sync_probe"})
				elif not scene.waiting_for_sync:
					print("WEBSOCKET PROCESS CLIENT: battle state synchronized and rejected intent recovered | FAILURES: 0")
					await create_timer(1.2).timeout
					scene.stop_network()
					quit(0)
					return
			else:
				host_playing_ticks += 1
				if host_playing_ticks >= 30:
					print("WEBSOCKET PROCESS HOST: battle state broadcast | FAILURES: 0")
					scene.stop_network()
					quit(0)
					return
		if scene.online_state == "idle" and not scene.online_notice.is_empty():
			push_error("WEBSOCKET PROCESS %s: %s" % [mode.to_upper(), scene.online_notice])
			quit(1)
			return
		await create_timer(0.01).timeout
	push_error("WEBSOCKET PROCESS %s: battle synchronization timed out in state %s, waiting=%s" % [mode.to_upper(), scene.online_state, scene.waiting_for_sync])
	scene.stop_network()
	quit(1)
