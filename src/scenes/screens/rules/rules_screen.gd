extends Control

signal back_requested

const ScreenUI = preload("res://src/ui/screens/screen_ui.gd")

func _ready() -> void:
	ScreenUI.add_screen_header(self, "게임 규칙", func(): back_requested.emit())
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_top = 140
	page.add_theme_constant_override("margin_left", 120)
	page.add_theme_constant_override("margin_right", 120)
	page.add_theme_constant_override("margin_top", 12)
	page.add_theme_constant_override("margin_bottom", 36)
	add_child(page)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ScreenUI.box(Color("17243a"), Color("344d6b")))
	page.add_child(panel)
	var text_view := RichTextLabel.new()
	text_view.name = "RulebookText"
	text_view.text = FileAccess.get_file_as_string("res://docs/RULEBOOK.md")
	text_view.add_theme_font_size_override("normal_font_size", 18)
	text_view.add_theme_color_override("default_color", Color("e7edf6"))
	text_view.scroll_active = true
	panel.add_child(text_view)
