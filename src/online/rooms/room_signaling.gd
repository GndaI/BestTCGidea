extends Node

signal identity_ready(peer_id: int, room_code: String)
signal status_changed(message: String)
signal failed(message: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal game_message(kind: String, payload: Variant)
signal connection_lost(message: String)

enum Message {
	JOIN,
	ID,
	PEER_CONNECT,
	PEER_DISCONNECT,
	OFFER,
	ANSWER,
	CANDIDATE,
	SEAL,
	RELAY,
}

var socket := WebSocketPeer.new()
var requested_room: Variant = ""
var own_id := 0
var active := false
var join_sent := false
var stopping := false

func create_room(url: String) -> void:
	_start(url, "")

func create_public_room(url: String, room_name: String) -> void:
	_start(url, {"code": "", "public": true, "name": room_name.strip_edges()})

func join_room(url: String, room_code: String) -> void:
	_start(url, room_code.strip_edges().to_upper())

func seal_room() -> void:
	_send(Message.SEAL)

func send_game(kind: String, payload: Variant = {}) -> void:
	if own_id not in [1, 2]:
		return
	var target_id := 2 if own_id == 1 else 1
	_send(Message.RELAY, target_id, {"kind": kind, "payload": payload})

func is_room_connected() -> bool:
	return active and own_id in [1, 2] and socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func _start(url: String, room_request: Variant) -> void:
	stop()
	requested_room = room_request
	socket = WebSocketPeer.new()
	var error := socket.connect_to_url(url)
	if error != OK:
		failed.emit("방 서버에 연결을 시작하지 못했습니다. (%s)" % error_string(error))
		return
	active = true
	stopping = false
	join_sent = false
	status_changed.emit("방 서버에 연결하는 중…")
	set_process(true)

func stop() -> void:
	stopping = true
	active = false
	join_sent = false
	requested_room = ""
	own_id = 0
	if socket.get_ready_state() in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
		socket.close()
	socket = WebSocketPeer.new()
	set_process(false)

func _process(_delta: float) -> void:
	if not active:
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not join_sent:
			join_sent = true
			_send(Message.JOIN, 0, requested_room)
		while socket.get_available_packet_count() > 0:
			_handle_message(socket.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		var reason := socket.get_close_reason()
		var had_identity := own_id != 0
		active = false
		set_process(false)
		if stopping:
			return
		if had_identity:
			connection_lost.emit(reason if not reason.is_empty() else "방 서버와 연결이 끊어졌습니다.")
		else:
			failed.emit(reason if not reason.is_empty() else "방 서버에 연결하지 못했습니다.")

func _send(type: int, peer_id: int = 0, data: Variant = "") -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(JSON.stringify({"type": type, "id": peer_id, "data": data}))

func _handle_message(raw: String) -> void:
	var message = JSON.parse_string(raw)
	if not message is Dictionary:
		return
	var type := int(message.get("type", -1))
	var peer_id := int(message.get("id", 0))
	var data = message.get("data", "")
	match type:
		Message.ID:
			own_id = peer_id
		Message.JOIN:
			var code := str(data).to_upper()
			requested_room = code
			identity_ready.emit(own_id, code)
		Message.PEER_CONNECT:
			peer_connected.emit(peer_id)
		Message.PEER_DISCONNECT:
			peer_disconnected.emit(peer_id)
		Message.RELAY:
			if data is Dictionary:
				game_message.emit(str(data.get("kind", "")), data.get("payload", {}))
