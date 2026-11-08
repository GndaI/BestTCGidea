extends Control

signal action_requested(action: String)
signal back_requested

const ScreenUI = preload("res://src/ui/screens/screen_ui.gd")

@export var screen_title := "메뉴"
@export var options: Array[String] = []
@export var actions: Array[String] = []

func _ready() -> void:
	ScreenUI.add_screen_header(self, screen_title, func(): back_requested.emit())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 140
	add_child(center)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 18)
	center.add_child(menu)
	for index in range(mini(options.size(), actions.size())):
		ScreenUI.main_menu_button(menu, options[index], _request.bind(actions[index]))

func _request(action: String) -> void:
	action_requested.emit(action)
