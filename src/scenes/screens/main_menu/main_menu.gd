extends Control

signal action_requested(action: String)

const ScreenUI = preload("res://src/ui/screens/screen_ui.gd")

func _ready() -> void:
	_build()

func _build() -> void:
	var logo_panel := PanelContainer.new()
	logo_panel.anchor_left = 0.5
	logo_panel.anchor_right = 0.5
	logo_panel.anchor_top = 0.08
	logo_panel.anchor_bottom = 0.08
	logo_panel.offset_left = -430
	logo_panel.offset_right = 430
	logo_panel.offset_bottom = 170
	logo_panel.add_theme_stylebox_override("panel", ScreenUI.box(Color("111d31"), Color("2d405b")))
	add_child(logo_panel)
	var logo_column := VBoxContainer.new()
	logo_column.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_column.add_theme_constant_override("separation", 2)
	logo_panel.add_child(logo_column)
	var logo := ScreenUI.label_at(logo_column, "최고의TCGidea", ScreenUI.TITLE_FONT_SIZE, ScreenUI.GOLD)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ScreenUI.emphasize_label(logo, 0.42)
	var subtitle := ScreenUI.label_at(logo_column, "TWELVE", 25, ScreenUI.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ScreenUI.emphasize_label(subtitle, 0.24)

	var account := Button.new()
	account.text = "계정"
	account.custom_minimum_size = Vector2(126, 52)
	account.add_theme_font_size_override("font_size", 19)
	account.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	account.offset_left = -142
	account.offset_right = -16
	account.offset_top = 16
	account.offset_bottom = 68
	account.pressed.connect(_request.bind("account"))
	add_child(account)

	var photo_specs := [
		{"path": "res://src/assets/ui/main_left.jpg", "left": 0.035, "right": 0.255},
		{"path": "res://src/assets/ui/main_right.jpg", "left": 0.745, "right": 0.965},
	]
	for photo_spec in photo_specs:
		var photo_frame := PanelContainer.new()
		photo_frame.anchor_left = photo_spec.left
		photo_frame.anchor_right = photo_spec.right
		photo_frame.anchor_top = 0.31
		photo_frame.anchor_bottom = 0.90
		photo_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var photo_style := ScreenUI.box(Color("101a2b"), Color("435a76"))
		photo_style.set_border_width_all(3)
		photo_style.set_corner_radius_all(16)
		photo_frame.add_theme_stylebox_override("panel", photo_style)
		add_child(photo_frame)
		var photo := TextureRect.new()
		photo.texture = load(photo_spec.path)
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.set_clip_contents(true)
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo_frame.add_child(photo)

	var menu_center := CenterContainer.new()
	menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_center.offset_top = 280
	menu_center.offset_bottom = -36
	add_child(menu_center)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 18)
	menu_center.add_child(menu)
	ScreenUI.main_menu_button(menu, "대전", _request.bind("battle"))
	ScreenUI.main_menu_button(menu, "덱", _request.bind("decks"))
	ScreenUI.main_menu_button(menu, "정보", _request.bind("rules"))
	ScreenUI.main_menu_button(menu, "설정", _request.bind("settings"))

	var patch_notes_button := ScreenUI.button_at(self, "패치노트", _request.bind("patch_notes"))
	patch_notes_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	patch_notes_button.offset_left = 18
	patch_notes_button.offset_right = 168
	patch_notes_button.offset_top = -66
	patch_notes_button.offset_bottom = -18
	patch_notes_button.add_theme_font_size_override("font_size", 18)

func _request(action: String) -> void:
	action_requested.emit(action)
