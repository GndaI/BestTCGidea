extends SceneTree

const CloudDecksScript = preload("res://scripts/online/cloud_decks.gd")
const URL := "http://127.0.0.1:24833"
const TEST_STATE := "user://test_cloud_deck_state.json"

var cloud
var sync_done := false
var save_done := false
var failure := ""
var received: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
	cloud = CloudDecksScript.new()
	cloud.state_path = TEST_STATE
	cloud.configure(URL)
	cloud.sync_finished.connect(_on_sync)
	cloud.save_finished.connect(_on_save)
	root.add_child(cloud)
	var local := [{"name": "로컬 덱", "cards": [[], [], [], [], [], []]}]
	cloud.sync(local, "test-token", "test-user")
	if not await _wait_for(func(): return sync_done):
		_finish("initial sync timed out")
		return
	if received.size() != 1 or str(received[0].name) != "로컬 덱":
		_finish("initial local upload was not returned")
		return
	save_done = false
	cloud.queue_save([{"name": "수정 덱", "cards": [[], [], [], [], [], []]}], "test-token", "test-user")
	if not await _wait_for(func(): return save_done, 500):
		_finish("debounced save timed out")
		return
	sync_done = false
	received.clear()
	cloud.sync([], "test-token", "test-user")
	if not await _wait_for(func(): return sync_done):
		_finish("reload sync timed out")
		return
	if received.size() != 1 or str(received[0].name) != "수정 덱":
		_finish("saved cloud deck was not loaded")
		return
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
	print("CLOUD DECK CHECKS: initial upload, debounced save, reload | FAILURES: 0")
	quit(0)

func _wait_for(predicate: Callable, steps: int = 300) -> bool:
	for _step in range(steps):
		if not failure.is_empty():
			return false
		if predicate.call():
			return true
		await create_timer(0.01).timeout
	return false

func _on_sync(ok: bool, decks: Array, message: String) -> void:
	if not ok:
		failure = message
		return
	received = decks.duplicate(true)
	sync_done = true

func _on_save(ok: bool, message: String) -> void:
	if not ok:
		failure = message
		return
	save_done = true

func _finish(message: String) -> void:
	if not failure.is_empty():
		message = failure
	push_error(message)
	quit(1)
