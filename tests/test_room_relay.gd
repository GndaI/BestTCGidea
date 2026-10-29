extends SceneTree

const RoomRelay = preload("res://room_signaling.gd")
const URL := "ws://127.0.0.1:24832/signal"

var host
var guest
var room_code := ""
var host_ready := false
var guest_ready := false
var relay_ok := false
var reply_ok := false
var failure := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	host = RoomRelay.new()
	guest = RoomRelay.new()
	root.add_child(host)
	root.add_child(guest)
	host.identity_ready.connect(_host_identity)
	host.peer_connected.connect(func(id): host_ready = id == 2)
	host.game_message.connect(_host_message)
	host.failed.connect(func(message): failure = message)
	guest.identity_ready.connect(func(id, _code): guest_ready = id == 2)
	guest.game_message.connect(_guest_message)
	guest.failed.connect(func(message): failure = message)
	host.create_public_room(URL, "Godot 중계 시험방")
	for _step in range(600):
		if relay_ok and reply_ok:
			print("GODOT ROOM RELAY CHECKS: native socket and two-way payload | FAILURES: 0")
			host.stop()
			guest.stop()
			quit(0)
			return
		if not failure.is_empty():
			push_error(failure)
			quit(1)
			return
		if host_ready and guest_ready and not relay_ok:
			host.send_game("state", {"turn": 7, "phase": "action"})
		await create_timer(0.01).timeout
	push_error("Godot room relay timed out")
	quit(1)

func _host_identity(id: int, code: String) -> void:
	if id != 1:
		failure = "host identity was not 1"
		return
	room_code = code
	guest.join_room(URL, room_code)

func _guest_message(kind: String, payload: Variant) -> void:
	if kind == "state" and payload is Dictionary and int(payload.get("turn", 0)) == 7:
		relay_ok = true
		guest.send_game("intent", {"type": "pass"})

func _host_message(kind: String, payload: Variant) -> void:
	if kind == "intent" and payload is Dictionary and str(payload.get("type", "")) == "pass":
		reply_ok = true
