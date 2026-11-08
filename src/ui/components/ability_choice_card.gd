extends Button

const EFFECT_TITLES := {
	"double_production": "폭발적 성장",
	"heal2": "치유",
	"grant_life2": "생명력 부여",
	"replay": "주문 재현",
	"execute_low_tier": "독사의 처형",
	"shield2": "보호막 전개",
	"guard_allies": "철벽 방어",
	"hit3": "정밀 사격",
	"hit2_two": "분산 사격",
	"heal1": "자가 수복",
	"cloak_to_hand": "보호의 주문",
	"increase_reflect": "가시 강화",
	"increase_armor": "철벽 강화",
	"hit6": "멸망의 숨결",
	"arm_apocalypse": "종말 예고",
	"steal_life2": "생명력 흡수",
	"swap": "소유권 교환",
	"hit4": "번개 강타",
	"mana2": "마나 충전",
	"shield3": "수호의 방벽",
	"shield4": "거인의 방벽",
	"heal3": "회복술",
}

func configure(unit_name: String, option: Dictionary, current_mana: int, unavailable_reason: String = "") -> void:
	var effect := str(option.get("effect", ""))
	var cost := int(option.get("cost", 0))
	name = "AbilityChoiceCard_" + effect
	custom_minimum_size = Vector2(230, 310)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "소모 %d · %s" % [cost, str(option.get("text", ""))]
	disabled = not unavailable_reason.is_empty()
	_add_card_styles(effect)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var cost_badge := PanelContainer.new()
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_theme_stylebox_override("panel", _style(Color("183f79"), Color("8bc8ff"), 16))
	top.add_child(cost_badge)
	var cost_label := _label(cost_badge, "소모 %d" % cost, 20, Color("f4f9ff"))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var source := _label(top, unit_name, 14, Color("bdc9d8"))
	source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var art := PanelContainer.new()
	art.custom_minimum_size.y = 108
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent := _effect_color(effect)
	var art_style := _style(Color(accent, 0.20), accent, 18)
	art_style.set_border_width_all(2)
	art.add_theme_stylebox_override("panel", art_style)
	column.add_child(art)
	var rune := _label(art, _effect_rune(effect), 54, accent.lightened(0.28))
	rune.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rune.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var title := _label(column, str(EFFECT_TITLES.get(effect, "소모 효과")), 22, Color("f4dda0"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var divider := HSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)
	var description := _label(column, str(option.get("text", "")), 16, Color("e4eaf2"))
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var status_text := "사용 가능 · 보유 마나 %d" % current_mana
	var status_color := Color("83e0bb")
	if not unavailable_reason.is_empty():
		status_text = unavailable_reason
		status_color = Color("ef9d9d")
	var status := _label(column, status_text, 14, status_color)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _add_card_styles(effect: String) -> void:
	var accent := _effect_color(effect)
	var normal := _style(Color("17243a"), Color(accent, 0.82), 18)
	normal.set_border_width_all(2)
	normal.shadow_color = Color(accent, 0.28)
	normal.shadow_size = 8
	var hover := _style(Color("223653"), accent.lightened(0.18), 18)
	hover.set_border_width_all(3)
	hover.shadow_color = Color(accent, 0.52)
	hover.shadow_size = 14
	var pressed := _style(Color("2c4260"), Color("fff0b5"), 18)
	pressed.set_border_width_all(3)
	var disabled_style := _style(Color("151b27"), Color("596577"), 18)
	disabled_style.set_border_width_all(2)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_style)
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_disabled_color", Color.TRANSPARENT)

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
	return style

func _effect_color(effect: String) -> Color:
	var colors := [Color("64b5f6"), Color("9b8cff"), Color("66d0a3"), Color("f0b45f"), Color("ed7c91")]
	return colors[absi(effect.hash()) % colors.size()]

func _effect_rune(effect: String) -> String:
	if "heal" in effect or "life" in effect: return "✚"
	if "shield" in effect or "guard" in effect or "armor" in effect: return "⬡"
	if "hit" in effect or "execute" in effect: return "✦"
	if "production" in effect or "mana" in effect: return "◆"
	if "replay" in effect or "cloak" in effect: return "◈"
	return "✧"
