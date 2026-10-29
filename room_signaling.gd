extends Node

signal identity_ready(peer_id: int, room_code: String)
signal status_changed(message: String)
signal failed(message: String)

enum Message {
	JOIN,
	ID,
	PEER_CONNECT,
	PEER_DISCONNECT,
	OFFER,
	ANSWER,
	CANDIDATE,
	SEAL,
}

const ICE_SERVERS := {
	"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]
}

var socket := WebSocketPeer.new()
var rtc_multiplayer: WebRTCMultiplayerPeer
var rtc_peers: Dictionary = {}
var requested_room: Variant = ""
var own_id := 0
var active := false
var join_sent := false

func create_room(url: String) -> void:
	_start(url, "")

func create_public_room(url: String, room_name: String) -> void:
	_start(url, {"code": "", "public": true, "name": room_name.strip_edges()})

func join_room(url: String, room_code: String) -> void:
	_start(url, room_code.strip_edges().to_upper())

func seal_room() -> void:
	_send(Message.SEAL)

func _start(url: String, room_request: Variant) -> void:
	stop()
	requested_room = room_request
	socket = WebSocketPeer.new()
	var error := socket.connect_to_url(url)
	if error != OK:
		failed.emit("방 서버에 연결을 시작하지 못했습니다. (%s)" % error_string(error))
		return
	active = true
	join_sent = false
	status_changed.emit("방 서버에 연결하는 중…")
	set_process(true)

func stop() -> void:
	active = false
	join_sent = false
	requested_room = ""
	own_id = 0
	for peer in rtc_peers.values():
		peer.close()
	rtc_peers.clear()
	if socket.get_ready_state() in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
		socket.close()
	socket = WebSocketPeer.new()
	rtc_multiplayer = null
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
		active = false
		set_process(false)
		if own_id == 0:
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
			_setup_multiplayer(peer_id)
		Message.JOIN:
			var code := str(data).to_upper()
			requested_room = code
			identity_ready.emit(own_id, code)
		Message.PEER_CONNECT:
			_create_peer(peer_id)
		Message.PEER_DISCONNECT:
			_remove_peer(peer_id)
		Message.OFFER, Message.ANSWER:
			_receive_description(peer_id, data)
		Message.CANDIDATE:
			_receive_candidate(peer_id, data)

func _setup_multiplayer(peer_id: int) -> void:
	own_id = peer_id
	rtc_multiplayer = WebRTCMultiplayerPeer.new()
	var error := rtc_multiplayer.create_server() if own_id == 1 else rtc_multiplayer.create_client(own_id)
	if error != OK:
		failed.emit("브라우저 대전 연결을 만들지 못했습니다. (%s)" % error_string(error))
		stop()
		return
	multiplayer.multiplayer_peer = rtc_multiplayer

func _create_peer(peer_id: int) -> void:
	if rtc_multiplayer == null or rtc_peers.has(peer_id):
		return
	var peer := WebRTCPeerConnection.new()
	var error := peer.initialize(ICE_SERVERS)
	if error != OK:
		failed.emit("상대 연결을 준비하지 못했습니다. (%s)" % error_string(error))
		return
	peer.session_description_created.connect(_description_created.bind(peer_id))
	peer.ice_candidate_created.connect(_candidate_created.bind(peer_id))
	rtc_peers[peer_id] = peer
	rtc_multiplayer.add_peer(peer, peer_id)
	if peer_id < own_id:
		peer.create_offer()

func _remove_peer(peer_id: int) -> void:
	if rtc_multiplayer != null:
		rtc_multiplayer.remove_peer(peer_id)
	if rtc_peers.has(peer_id):
		rtc_peers[peer_id].close()
		rtc_peers.erase(peer_id)

func _description_created(type: String, sdp: String, peer_id: int) -> void:
	if not rtc_peers.has(peer_id):
		return
	rtc_peers[peer_id].set_local_description(type, sdp)
	_send(Message.OFFER if type == "offer" else Message.ANSWER, peer_id, {"type": type, "sdp": sdp})

func _candidate_created(media: String, index: int, candidate: String, peer_id: int) -> void:
	_send(Message.CANDIDATE, peer_id, {"media": media, "index": index, "candidate": candidate})

func _receive_description(peer_id: int, data: Variant) -> void:
	if not rtc_peers.has(peer_id) or not data is Dictionary:
		return
	rtc_peers[peer_id].set_remote_description(str(data.get("type", "")), str(data.get("sdp", "")))

func _receive_candidate(peer_id: int, data: Variant) -> void:
	if not rtc_peers.has(peer_id) or not data is Dictionary:
		return
	rtc_peers[peer_id].add_ice_candidate(str(data.get("media", "")), int(data.get("index", 0)), str(data.get("candidate", "")))
