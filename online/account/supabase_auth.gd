class_name SupabaseAuth
extends Node

signal auth_finished(action: String, ok: bool, payload: Dictionary, message: String)

const Config = preload("res://online/account/supabase_config.gd")
const SESSION_PATH := "user://supabase_session.json"

var request: HTTPRequest
var current_action := ""
var keep_session := true
var session: Dictionary = {}

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.request_completed.connect(_on_request_completed)
	add_child(request)

func is_configured() -> bool:
	return Config.is_configured()

func is_signed_in() -> bool:
	return not str(session.get("access_token", "")).is_empty() and session.get("user", {}) is Dictionary

func access_token() -> String:
	return str(session.get("access_token", ""))

func user_id() -> String:
	var user = session.get("user", {})
	return str(user.get("id", "")) if user is Dictionary else ""

func user_email() -> String:
	var user = session.get("user", {})
	return str(user.get("email", "")) if user is Dictionary else ""

func user_nickname() -> String:
	var user = session.get("user", {})
	if not user is Dictionary:
		return ""
	var metadata = user.get("user_metadata", {})
	return str(metadata.get("nickname", "")) if metadata is Dictionary else ""

func sign_up(email: String, password: String, nickname: String) -> void:
	_start_request("signup", "/auth/v1/signup", {
		"email": email,
		"password": password,
		"data": {"nickname": nickname},
	})

func sign_in(email: String, password: String, remember: bool) -> void:
	keep_session = remember
	_start_request("signin", "/auth/v1/token?grant_type=password", {
		"email": email,
		"password": password,
	})

func send_password_reset(email: String) -> void:
	_start_request("recover", "/auth/v1/recover", {"email": email})

func restore_session() -> void:
	if not is_configured() or not FileAccess.file_exists(SESSION_PATH):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if not saved is Dictionary or str(saved.get("refresh_token", "")).is_empty():
		_clear_saved_session()
		return
	keep_session = true
	_start_request("refresh", "/auth/v1/token?grant_type=refresh_token", {
		"refresh_token": str(saved.get("refresh_token", "")),
	})

func sign_out() -> void:
	var access_token := str(session.get("access_token", ""))
	session.clear()
	_clear_saved_session()
	if access_token.is_empty() or not is_configured():
		auth_finished.emit("signout", true, {}, "로그아웃했습니다.")
		return
	_start_request("signout", "/auth/v1/logout", {}, access_token)

func _start_request(action: String, path: String, body: Dictionary, bearer: String = "") -> void:
	if not is_configured():
		auth_finished.emit(action, false, {}, "Supabase 연결 설정이 필요합니다.")
		return
	if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		auth_finished.emit(action, false, {}, "이전 계정 요청을 처리하고 있습니다.")
		return
	current_action = action
	var headers := PackedStringArray([
		"apikey: %s" % Config.PUBLISHABLE_KEY,
		"Content-Type: application/json",
	])
	if not bearer.is_empty():
		headers.append("Authorization: Bearer %s" % bearer)
	var error := request.request(Config.PROJECT_URL.trim_suffix("/") + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		current_action = ""
		auth_finished.emit(action, false, {}, "계정 서버 요청을 시작하지 못했습니다. (%s)" % error_string(error))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := current_action
	current_action = ""
	var response_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text) if not response_text.is_empty() else {}
	var payload: Dictionary = parsed if parsed is Dictionary else {}
	var ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	if not ok:
		var message := str(payload.get("msg", payload.get("error_description", payload.get("message", "계정 요청에 실패했습니다."))))
		auth_finished.emit(action, false, payload, message)
		return
	if action in ["signin", "refresh"] or (action == "signup" and payload.has("access_token")):
		session = payload.duplicate(true)
		if keep_session:
			_save_session()
	if action == "signout":
		session.clear()
		_clear_saved_session()
	auth_finished.emit(action, true, payload, "")

func _save_session() -> void:
	var refresh_token := str(session.get("refresh_token", ""))
	if refresh_token.is_empty():
		return
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"refresh_token": refresh_token}))

func _clear_saved_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
