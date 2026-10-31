class_name CloudDecks
extends Node

signal sync_finished(ok: bool, decks: Array, message: String)
signal save_finished(ok: bool, message: String)

const STATE_PATH := "user://deck_sync_state.json"

var state_path := STATE_PATH
var base_url := ""
var request: HTTPRequest
var save_timer: Timer
var current_action := ""
var current_token := ""
var current_user_id := ""
var local_decks_at_sync: Array = []
var pending_decks: Array = []
var pending_token := ""
var pending_user_id := ""
var generation := 0
var request_generation := 0

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.request_completed.connect(_on_request_completed)
	add_child(request)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.8
	save_timer.timeout.connect(_flush_pending_save)
	add_child(save_timer)

func configure(server_url: String) -> void:
	base_url = server_url.strip_edges().trim_suffix("/")

func sync(local_decks: Array, token: String, user_id: String) -> void:
	if base_url.is_empty() or token.is_empty() or user_id.is_empty():
		sync_finished.emit(false, [], "클라우드 덱 연결 정보가 없습니다.")
		return
	if _is_busy():
		sync_finished.emit(false, [], "다른 덱 요청을 처리하고 있습니다.")
		return
	current_token = token
	current_user_id = user_id
	local_decks_at_sync = local_decks.duplicate(true)
	var state := _load_state()
	if bool(state.get("dirty", false)) and str(state.get("user_id", "")) == user_id:
		_start_put(local_decks_at_sync, "sync_put")
	else:
		_start_get()

func queue_save(decks: Array, token: String, user_id: String) -> void:
	if base_url.is_empty() or token.is_empty() or user_id.is_empty():
		return
	pending_decks = decks.duplicate(true)
	pending_token = token
	pending_user_id = user_id
	generation += 1
	_write_state(user_id, true)
	save_timer.start()

func cancel() -> void:
	save_timer.stop()
	pending_decks.clear()
	pending_token = ""
	pending_user_id = ""
	if request != null and _is_busy():
		request.cancel_request()
	current_action = ""

func _start_get() -> void:
	current_action = "sync_get"
	var error := request.request(base_url + "/api/decks", _headers(current_token), HTTPClient.METHOD_GET)
	if error != OK:
		current_action = ""
		sync_finished.emit(false, [], "클라우드 덱을 불러오지 못했습니다. (%s)" % error_string(error))

func _start_put(decks: Array, action: String) -> void:
	current_action = action
	request_generation = generation
	var payload := JSON.stringify({"decks": decks})
	var error := request.request(base_url + "/api/decks", _headers(current_token), HTTPClient.METHOD_PUT, payload)
	if error != OK:
		current_action = ""
		if action == "sync_put":
			sync_finished.emit(false, [], "로컬 덱을 클라우드에 올리지 못했습니다. (%s)" % error_string(error))
		else:
			save_finished.emit(false, "클라우드 덱 저장을 시작하지 못했습니다. (%s)" % error_string(error))

func _flush_pending_save() -> void:
	if pending_token.is_empty() or pending_user_id.is_empty():
		return
	if _is_busy():
		save_timer.start()
		return
	current_token = pending_token
	current_user_id = pending_user_id
	_start_put(pending_decks.duplicate(true), "save_put")

func _on_request_completed(result: int, response_code: int, _headers_value: PackedStringArray, body: PackedByteArray) -> void:
	var action := current_action
	current_action = ""
	var response_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text) if not response_text.is_empty() else {}
	var payload: Dictionary = parsed if parsed is Dictionary else {}
	var ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	if not ok:
		var message := str(payload.get("message", "클라우드 덱 요청에 실패했습니다. (%d)" % response_code))
		if action.begins_with("sync_"):
			sync_finished.emit(false, [], message)
		else:
			save_finished.emit(false, message)
		return
	if action == "sync_get":
		var cloud_decks = payload.get("decks", [])
		if not (cloud_decks is Array):
			sync_finished.emit(false, [], "서버의 덱 데이터 형식이 올바르지 않습니다.")
			return
		if not bool(payload.get("exists", false)) and not local_decks_at_sync.is_empty():
			_start_put(local_decks_at_sync, "sync_put")
			return
		_write_state(current_user_id, false)
		sync_finished.emit(true, cloud_decks, "클라우드 덱을 불러왔습니다.")
		return
	if request_generation == generation:
		_write_state(current_user_id, false)
		pending_decks.clear()
		pending_token = ""
		pending_user_id = ""
	if action == "sync_put":
		sync_finished.emit(true, local_decks_at_sync, "기존 덱을 클라우드에 저장했습니다.")
	else:
		save_finished.emit(true, "덱을 클라우드에 저장했습니다.")
	if request_generation != generation:
		save_timer.start()

func _headers(token: String) -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json",
		"Accept: application/json",
	])

func _is_busy() -> bool:
	return request != null and request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED

func _load_state() -> Dictionary:
	if not FileAccess.file_exists(state_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	return parsed if parsed is Dictionary else {}

func _write_state(user_id: String, dirty: bool) -> void:
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"user_id": user_id, "dirty": dirty}))
