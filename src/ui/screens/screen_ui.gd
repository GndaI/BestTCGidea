extends RefCounted

const GOLD := Color("f6d98d")
const MUTED := Color("c4d0df")
const MENU_BUTTON := Color("20344d")
const MENU_BUTTON_HOVER := Color("2c4968")
const MENU_BUTTON_PRESSED := Color("365473")
const TITLE_FONT_SIZE := 85
const MENU_FONT_SIZE := 35

static func box(color: Color, edge: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.set_border_width_all(1)
	style.border_color = edge
	return style

static func label_at(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

static func button_at(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

static func emphasize_label(label: Label, strength: float = 0.35) -> void:
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, strength))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)

static func main_menu_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := button_at(parent, text, callback)
	button.custom_minimum_size = Vector2(480, 86)
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	button.add_theme_color_override("font_color", Color("f7f9fd"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_stylebox_override("normal", box(MENU_BUTTON, Color("496684")))
	button.add_theme_stylebox_override("hover", box(MENU_BUTTON_HOVER, Color("5d789a")))
	button.add_theme_stylebox_override("pressed", box(MENU_BUTTON_PRESSED, GOLD.darkened(0.25)))
	return button

static func add_screen_header(parent: Control, title_text: String, back_callback: Callable) -> Control:
	var header := Control.new()
	header.custom_minimum_size.y = 140
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 140
	parent.add_child(header)
	var back := button_at(header, "← 뒤로", back_callback)
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(150, 48)
	back.add_theme_font_size_override("font_size", 18)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 0
	back.offset_right = 150
	back.offset_top = 16
	back.offset_bottom = 64
	var title := label_at(header, title_text, TITLE_FONT_SIZE, GOLD)
	emphasize_label(title, 0.42)
	title.anchor_left = 0.2
	title.anchor_right = 0.8
	title.offset_top = 12
	title.offset_bottom = 136
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return header
