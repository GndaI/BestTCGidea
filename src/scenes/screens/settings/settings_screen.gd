extends Control

signal back_requested
signal setting_changed(setting_name: String, enabled: bool)

const ScreenUI = preload("res://src/ui/screens/screen_ui.gd")

var effects_enabled := true
var auto_pass_enabled := true
var privacy_enabled := false

func configure(values: Dictionary) -> void:
	effects_enabled = bool(values.get("effects_enabled", true))
	auto_pass_enabled = bool(values.get("auto_pass", true))
	privacy_enabled = bool(values.get("privacy", false))

func _ready() -> void:
	ScreenUI.add_screen_header(self, "설정", func(): back_requested.emit())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 140
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 430)
	panel.add_theme_stylebox_override("panel", ScreenUI.box(Color("17243a"), Color("3b5472")))
	center.add_child(panel)
	var settings := VBoxContainer.new()
	settings.alignment = BoxContainer.ALIGNMENT_CENTER
	settings.add_theme_constant_override("separation", 24)
	panel.add_child(settings)
	var heading := ScreenUI.label_at(settings, "게임 설정", 32, ScreenUI.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_toggle(settings, "전투 연출 사용", "effects_enabled", effects_enabled)
	_add_toggle(settings, "행동이 없으면 자동으로 넘기기", "auto_pass", auto_pass_enabled)
	_add_toggle(settings, "로컬 대전에서 행동권 변경 시 패 가리기", "privacy", privacy_enabled)

func _add_toggle(parent: Node, text: String, setting_name: String, value: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = value
	toggle.custom_minimum_size = Vector2(560, 58)
	toggle.add_theme_font_size_override("font_size", 21)
	toggle.toggled.connect(func(enabled: bool): setting_changed.emit(setting_name, enabled))
	parent.add_child(toggle)
