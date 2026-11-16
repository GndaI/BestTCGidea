class_name TCGBattle
extends "res://src/battle/local_battle.gd"

signal remote_command_requested(player: int, command: Dictionary)
signal server_snapshot_received(snapshot: Dictionary)

var remote_authority := false
var remote_player := -1
var server_snapshot: Dictionary = {}

func use_local_authority() -> void:
	remote_authority = false
	remote_player = -1
	server_snapshot.clear()

func use_remote_authority(player: int) -> void:
	remote_authority = true
	remote_player = player
	server_snapshot.clear()

func submit_command(player: int, command: Dictionary) -> bool:
	if not remote_authority:
		return apply_local_command(player, command)
	if player != remote_player or command.is_empty():
		return false
	remote_command_requested.emit(player, command.duplicate(true))
	return true

func apply_server_snapshot(snapshot: Dictionary) -> void:
	server_snapshot = snapshot.duplicate(true)
	server_snapshot_received.emit(server_snapshot)
