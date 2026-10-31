class_name TCGCardView
extends Control

const TOOLTIP_FONT = preload("res://assets/fonts/NotoSansKR-Variable.ttf")
const BOTTOM_GEM_Y := 240.0
const STAT_GEM_RADIUS := 27.0
const POWER_GEM_CENTER := Vector2(40.0, BOTTOM_GEM_Y)
const MANA_GEM_CENTER := Vector2(100.0, BOTTOM_GEM_Y)
const HEALTH_GEM_CENTER := Vector2(160.0, BOTTOM_GEM_Y)
const FIELD_POWER_FILL := Color("8c741b")
const FIELD_POWER_EDGE := Color("ffe58a")
const FIELD_MANA_FILL := Color("0754a3")
const FIELD_MANA_EDGE := Color("8be4ff")

# Card views are rebuilt often during play. Keep one resized texture per card and
# layout instead of decoding and resizing the same source image for every view.
static var portrait_texture_cache: Dictionary = {}
static var portrait_mask_shader: Shader

var card: Dictionary = {}
var production := 0
var health := 0
var mana := -1
var shield := 0
var spell_face := false
var face_down := false
var caption := "미공개"
var highlighted := false
var draft_selected := false
var content: Control
var tint := Color("546e85")
var portrait: TextureRect
var visual_scale := 1.0
var target_pulse_time := 0.0

func uses_reference_layout() -> bool:
	return mana < 0 and not spell_face and not face_down

func tier_number_rect() -> Rect2:
	# The badge center is x=25; the large number sits 3px to its left.
	return Rect2(8, 4, 28, 38)

func field_mana_badge_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(100, 212), Vector2(128, 240), Vector2(100, 268), Vector2(72, 240)])

func field_health_badge_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(160, 212), Vector2(184, 226), Vector2(179, 254), Vector2(160, 269), Vector2(141, 254), Vector2(136, 226)])

func name_bar_rect() -> Rect2:
	if uses_reference_layout(): return Rect2(14, 123, 172, 32)
	return Rect2(14, 10, 172, 34) if mana >= 0 else Rect2(14, 36, 172, 34)

func name_text_rect() -> Rect2:
	return name_bar_rect()

func art_rect() -> Rect2:
	if uses_reference_layout(): return Rect2(46, 15, 108, 108)
	var bar := name_bar_rect()
	return Rect2(23, bar.end.y + 5.0, 154, 164)

func configure(data: Dictionary, power: int = -1, hp: int = -1, stored_mana: int = -1, spell: bool = false) -> void:
	card = data
	production = power if power >= 0 else int(data.get("power", 0))
	health = hp if hp >= 0 else int(data.get("health", 0))
	mana = stored_mana
	spell_face = spell
	if not data.is_empty(): tint = Color.from_hsv(float(abs(hash(data.id)) % 360) / 360.0, 0.42, 0.47)
	custom_minimum_size = Vector2(172, 241)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	set_process(highlighted)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_clip_contents(true)
	content.size = Vector2(200, 280)
	add_child(content)
	if face_down:
		if caption.ends_with("턴"):
			# Empty battle slots reuse the deck editor's turn-label treatment.
			text(caption, Rect2(20, 166, 160, 48), 30, Color("ffe0a0"))
		else:
			text(caption, Rect2(24, 116, 152, 48), 20, Color("e4cf99"))
		if not card.is_empty(): text(card.name, Rect2(20, 185, 160, 40), 15, Color("baa885"))
	else:
		_add_portrait()
		centered_text(card.name, name_text_rect(), 15, Color("fff0c9"), "CardName")
		if uses_reference_layout():
			var printed_effect := str(card.get("rules", "")).strip_edges()
			if printed_effect.is_empty(): printed_effect = "효과 없음"
			var effect_label := text(printed_effect, Rect2(25, 162, 150, 66), 12, Color("2b2115"))
			effect_label.name = "CardEffectText"
			var effect_font := FontVariation.new()
			effect_font.base_font = TOOLTIP_FONT
			effect_font.variation_embolden = 0.45
			effect_label.add_theme_font_override("normal_font", effect_font)
			effect_label.add_theme_constant_override("line_separation", 2)
			centered_text("유닛", Rect2(43, 232, 114, 31), 12, Color("f2dfaa"), "CardType")
		if not spell_face:
			var health_color := Color("ff626b") if health < int(card.get("current_max_hp", card.get("health", health))) else Color.WHITE
			if uses_reference_layout():
				centered_text(str(production), Rect2(12, 220, 54, 54), 30, Color("fff3a7"), "PowerValue")
				centered_text(str(health), Rect2(138, 220, 48, 57), 30, health_color, "HealthValue")
			else:
				centered_text(str(production), Rect2(13, 213, 54, 54), 30, Color("fff3a7"), "PowerValue")
				centered_text(str(health), Rect2(136, 212, 48, 57), 30, health_color, "HealthValue")
		if mana >= 0 and not spell_face:
			centered_text(str(mana), Rect2(72, 212, 56, 56), 30, Color.WHITE, "ManaValue")
		elif not spell_face:
			text(str(card.get("tier", 0)), tier_number_rect(), 25, Color.WHITE)
			if uses_reference_layout(): centered_text("턴", Rect2(29, 19, 14, 16), 9, Color("d9efff"), "TurnSuffix")
		if draft_selected:
			var ribbon := Panel.new()
			ribbon.position = Vector2(38, 207)
			ribbon.size = Vector2(124, 27)
			ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ribbon_style := StyleBoxFlat.new()
			ribbon_style.bg_color = Color("183f2a")
			ribbon_style.border_color = Color("78efab")
			ribbon_style.set_border_width_all(2)
			ribbon_style.set_corner_radius_all(6)
			ribbon.add_theme_stylebox_override("panel", ribbon_style)
			content.add_child(ribbon)
			text("✓", Rect2(151, 8, 36, 30), 23, Color("13271f"))
			text("덱에 포함", Rect2(38, 209, 124, 25), 15, Color("d5ffdc"))
	fit_content()

func _add_portrait() -> void:
	var image_path := str(card.get("portrait", ""))
	if image_path.is_empty():
		var base_path := "res://cards/images/%s" % card.get("id", "")
		image_path = base_path + ".png"
		if not FileAccess.file_exists(ProjectSettings.globalize_path(image_path)) and FileAccess.file_exists(ProjectSettings.globalize_path(base_path + ".jpg")):
			image_path = base_path + ".jpg"
	if image_path.is_empty(): return
	var picture_rect := art_rect()
	var cache_key := "%s|%dx%d" % [image_path, int(picture_rect.size.x), int(picture_rect.size.y)]
	var cached: Dictionary = portrait_texture_cache.get(cache_key, {})
	if cached.is_empty():
		var image: Image
		if ResourceLoader.exists(image_path):
			var loaded_texture := load(image_path) as Texture2D
			if loaded_texture != null: image = loaded_texture.get_image()
		if image == null or image.is_empty():
			var source_path := ProjectSettings.globalize_path(image_path)
			if not FileAccess.file_exists(source_path): return
			image = Image.new()
			var load_error := image.load(source_path)
			if load_error != OK:
				var bytes := FileAccess.get_file_as_bytes(source_path)
				if bytes.size() >= 3 and bytes[0] == 0xff and bytes[1] == 0xd8 and bytes[2] == 0xff:
					load_error = image.load_jpg_from_buffer(bytes)
				if load_error != OK: return
		var fit := minf(picture_rect.size.x / float(image.get_width()), picture_rect.size.y / float(image.get_height()))
		var resized_size := Vector2i(maxi(1, roundi(image.get_width() * fit)), maxi(1, roundi(image.get_height() * fit)))
		image.resize(resized_size.x, resized_size.y, Image.INTERPOLATE_LANCZOS)
		cached = {"texture": ImageTexture.create_from_image(image), "size": resized_size}
		portrait_texture_cache[cache_key] = cached
	var draw_size: Vector2i = cached["size"]
	portrait = TextureRect.new()
	portrait.texture = cached["texture"]
	portrait.position = Vector2((200.0 - draw_size.x) / 2.0, picture_rect.position.y + (picture_rect.size.y - draw_size.y) / 2.0)
	portrait.size = Vector2(draw_size)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if uses_reference_layout():
		if portrait_mask_shader == null:
			portrait_mask_shader = Shader.new()
			portrait_mask_shader.code = "shader_type canvas_item;\nvoid fragment() {\n  vec2 p = (UV - vec2(0.5)) * 2.0;\n  vec4 tex = texture(TEXTURE, UV);\n  float mask = 1.0 - smoothstep(0.94, 1.0, dot(p, p));\n  COLOR = vec4(tex.rgb, tex.a * mask);\n}"
		var mask_material := ShaderMaterial.new()
		mask_material.shader = portrait_mask_shader
		portrait.material = mask_material
	content.add_child(portrait)

func text(value: String, rect: Rect2, font_size: int, color: Color) -> RichTextLabel:
	if value.is_empty(): return null
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	var shown := value
	if card.get("id", "") == "gambler":
		shown = shown.replace("6", "[color=#ff5364]6[/color]")
	label.text = "[center]" + shown + "[/center]"
	label.scroll_active = false
	label.fit_content = false
	label.position = rect.position
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = rect.size
	content.add_child(label)
	return label

func centered_text(value: String, rect: Rect2, font_size: int, color: Color, node_name: String = "") -> void:
	if value.is_empty(): return
	var label := Label.new()
	if not node_name.is_empty(): label.name = node_name
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)

func _make_custom_tooltip(for_text: String) -> Object:
	# Battle cards and empty field slots do not carry editor tooltip text.
	# Returning no tooltip here prevents a duplicate "효과 없음" popup.
	if for_text.strip_edges().is_empty():
		return null
	var panel := PanelContainer.new()
	panel.name = "CardEffectTooltip"
	panel.custom_minimum_size.x = 620
	var style := StyleBoxFlat.new()
	style.bg_color = Color("08111f")
	style.border_color = Color("f1ca7b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	style.shadow_color = Color(0, 0, 0, 0.92)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var lines := for_text.split("\n")
	var title_text := lines[0] if not lines.is_empty() else "카드 효과"
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", TOOLTIP_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f1ca7b"))
	title.add_theme_constant_override("outline_size", 0)
	column.add_child(title)
	var effect_lines: Array[String] = []
	for index in range(1, maxi(1, lines.size() - 2)):
		if not lines[index].strip_edges().is_empty(): effect_lines.append(lines[index])
	var effect := Label.new()
	effect.text = "\n".join(effect_lines) if not effect_lines.is_empty() else "효과 없음"
	effect.custom_minimum_size.x = 570
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_override("font", TOOLTIP_FONT)
	effect.add_theme_font_size_override("font_size", 25)
	effect.add_theme_color_override("font_color", Color("f4f7fc"))
	effect.add_theme_constant_override("line_spacing", 8)
	effect.add_theme_constant_override("outline_size", 0)
	column.add_child(effect)
	if lines.size() >= 2:
		var action_text := lines[lines.size() - 1].strip_edges()
		if not action_text.is_empty():
			var action := Label.new()
			action.text = action_text
			action.add_theme_font_override("font", TOOLTIP_FONT)
			action.add_theme_font_size_override("font_size", 21)
			action.add_theme_color_override("font_color", Color("71b9ff"))
			column.add_child(action)
	return panel

func update_health(value: int) -> void:
	health = value
	if is_instance_valid(content):
		var health_label := content.get_node_or_null("HealthValue") as Label
		if health_label != null:
			health_label.text = str(health)
			var max_health := int(card.get("current_max_hp", card.get("health", health)))
			health_label.add_theme_color_override("font_color", Color("ff626b") if health < max_health else Color.WHITE)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		fit_content()
		queue_redraw()

func fit_content() -> void:
	if is_instance_valid(content):
		var factor := minf(size.x / 200.0, size.y / 280.0) * visual_scale
		content.scale = Vector2.ONE * factor
		content.position = (size - Vector2(200, 280) * factor) / 2

func has_mana_glow() -> bool:
	return not face_down and not spell_face and mana >= 1

func inner_border_color() -> Color:
	return Color("b6a57a")

func target_pulse_alpha(seconds: float) -> float:
	return lerpf(0.56, 1.0, (sin(seconds * TAU * 1.15) + 1.0) * 0.5)

func _process(delta: float) -> void:
	if not highlighted:
		modulate.a = 1.0
		set_process(false)
		return
	target_pulse_time += delta
	# `modulate` also affects the child labels, so stats and mana pulse with the card.
	modulate.a = target_pulse_alpha(target_pulse_time)

func plate(rect: Rect2, fill: Color, edge: Color, radius: int = 12, width: int = 2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func mana_glow_plate(rect: Rect2) -> void:
	# The bright core shares the card's exact outer rectangle. The shadow blooms
	# outward from that edge, so there is no dark gap between the card and glow.
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color.TRANSPARENT
	glow.border_color = Color("52df68")
	glow.set_border_width_all(5)
	glow.set_corner_radius_all(18)
	glow.shadow_color = Color(0.18, 0.9, 0.31, 0.38)
	glow.shadow_size = 11
	glow.shadow_offset = Vector2.ZERO
	draw_style_box(glow, rect)
	# A softer second halo makes the edge look diffused instead of like another frame.
	var soft_glow := StyleBoxFlat.new()
	soft_glow.bg_color = Color.TRANSPARENT
	soft_glow.border_color = Color(0.3, 0.88, 0.4, 0.16)
	soft_glow.set_border_width_all(2)
	soft_glow.set_corner_radius_all(20)
	soft_glow.shadow_color = Color(0.16, 0.86, 0.28, 0.13)
	soft_glow.shadow_size = 16
	soft_glow.shadow_offset = Vector2.ZERO
	draw_style_box(soft_glow, rect)

func gem(center: Vector2, radius: float, fill: Color, edge: Color, edge_width: float = 2.0) -> void:
	draw_circle(center + Vector2(0, 2), radius + maxf(2.0, edge_width), Color("080c13"))
	draw_circle(center, radius, fill)
	draw_arc(center, radius - edge_width / 2.0, 0, TAU, 48, edge, edge_width, true)
	draw_arc(center, radius - edge_width - 3.0, PI * 1.08, PI * 1.92, 24, fill.lightened(0.44), maxf(2.0, edge_width - 1.0), true)

func filled_polygon(points: PackedVector2Array, fill: Color, edge: Color, edge_width: float = 2.0) -> void:
	draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, edge, edge_width, true)

func _draw() -> void:
	var factor := minf(size.x / 200.0, size.y / 280.0) * visual_scale
	var origin := (size - Vector2(200, 280) * factor) / 2
	draw_set_transform(origin, 0, Vector2.ONE * factor)
	if draft_selected:
		plate(Rect2(1, 1, 198, 278), Color(0.2, 0.72, 0.4, 0.18), Color("78efab"), 19, 4)
	var card_outer_rect := Rect2(7, 7, 186, 270)
	plate(card_outer_rect, Color("080c13"), Color("080c13"), 18)
	plate(Rect2(10, 7, 180, 267), Color("423d32"), inner_border_color(), 17, 3)
	if has_mana_glow():
		mana_glow_plate(card_outer_rect)
	plate(Rect2(17, 14, 166, 250), Color("172b27") if uses_reference_layout() else (Color("1b302e") if not spell_face else Color("283854")), Color("6c674f"), 12)
	if face_down:
		draw_circle(Vector2(100, 94), 39, Color("314554"))
		draw_arc(Vector2(100, 94), 31, 0, TAU, 48, Color("b6a57a"), 2, true)
		draw_colored_polygon(PackedVector2Array([Vector2(100, 65), Vector2(115, 94), Vector2(100, 122), Vector2(85, 94)]), Color("829f98"))
		return
	var picture_rect := art_rect()
	if uses_reference_layout():
		draw_circle(Vector2(100, 69), 61, Color("1a2428"))
		draw_arc(Vector2(100, 69), 60, 0, TAU, 64, Color("d6c482"), 3, true)
		draw_circle(Vector2(100, 69), 55, tint.darkened(0.35))
		for side_x in [20.0, 180.0]:
			var direction := 1.0 if side_x < 100.0 else -1.0
			for mark_y in [50.0, 76.0, 102.0]:
				draw_polyline(PackedVector2Array([Vector2(side_x, mark_y), Vector2(side_x + direction * 8.0, mark_y + 8.0), Vector2(side_x, mark_y + 16.0)]), Color("a99655"), 2, true)
	else:
		# Empty art wells have a subtle colored fallback; drop a same-id PNG into cards/images to replace it.
		plate(picture_rect, tint.darkened(0.72), Color("8c9c86"), 6)
	if portrait == null:
		var art_center := Vector2(100, picture_rect.position.y + 56.0)
		var fallback_radius := 46.0 if uses_reference_layout() else 48.0
		draw_circle(art_center, fallback_radius, tint.darkened(0.48))
		draw_arc(art_center, fallback_radius - 9.0, 0, TAU, 48, tint.lightened(0.35), 2, true)
		for index in range(8):
			var ray := Vector2.from_angle(float(index) * TAU / 8.0)
			draw_line(art_center + ray * 22, art_center + ray * 35, tint.lightened(0.45), 2, true)
		draw_circle(art_center + Vector2(0, -4), 15, tint.lightened(0.2))
		draw_colored_polygon(PackedVector2Array([art_center + Vector2(-20, 23), art_center + Vector2(-10, 5), art_center, art_center + Vector2(10, 5), art_center + Vector2(20, 23)]), tint.lightened(0.1))
	if uses_reference_layout():
		plate(name_bar_rect(), Color("604b25"), Color("e0c278"), 5, 2)
		var effect_panel := PackedVector2Array([Vector2(21, 160), Vector2(179, 160), Vector2(179, 231), Vector2(166, 239), Vector2(34, 239), Vector2(21, 231)])
		filled_polygon(effect_panel, Color("eee2b8"), Color("c7ae69"), 2)
		plate(Rect2(43, 232, 114, 31), Color("3a3527"), Color("b8a36b"), 3, 2)
		var tier_badge := PackedVector2Array([Vector2(25, 2), Vector2(46, 17), Vector2(40, 45), Vector2(10, 45), Vector2(4, 17)])
		filled_polygon(tier_badge, Color("1d557a"), Color("b9edff"), 2)
	else:
		plate(name_bar_rect(), Color("46313a"), Color("d5bd85"), 5)
		if mana >= 0:
			filled_polygon(field_mana_badge_points(), FIELD_MANA_FILL, FIELD_MANA_EDGE, 4)
		else:
			gem(Vector2(25, 23), 22, Color("299a25"), Color("baff75"))
	if not spell_face:
		if uses_reference_layout():
			gem(Vector2(39, 247), STAT_GEM_RADIUS, Color("8c741b"), Color("ffe58a"), 4)
			var health_badge := PackedVector2Array([Vector2(162, 220), Vector2(186, 234), Vector2(181, 262), Vector2(162, 277), Vector2(143, 262), Vector2(138, 234)])
			filled_polygon(health_badge, Color("8c2730"), Color("ffd0a8"), 4)
		else:
			gem(POWER_GEM_CENTER, STAT_GEM_RADIUS, FIELD_POWER_FILL, FIELD_POWER_EDGE, 4)
			filled_polygon(field_health_badge_points(), Color("8c2730"), Color("ffd0a8"), 4)
	if shield > 0 and not spell_face:
		var shield_points := PackedVector2Array([Vector2(100, 10), Vector2(187, 36), Vector2(184, 190), Vector2(100, 268), Vector2(16, 190), Vector2(13, 36)])
		var shield_fill := Color("56caff")
		shield_fill.a = 0.11
		draw_colored_polygon(shield_points, shield_fill)
		draw_polyline(PackedVector2Array([shield_points[0], shield_points[1], shield_points[2], shield_points[3], shield_points[4], shield_points[5], shield_points[0]]), Color("a2edff"), 3, true)
		var shield_glow := Color("45bfff")
		shield_glow.a = 0.65
		draw_arc(Vector2(100, 143), 94, PI * 1.08, PI * 1.92, 36, shield_glow, 2, true)
	if draft_selected:
		gem(Vector2(169, 22), 18, Color("81f0a7"), Color("e0ffe3"))
		plate(Rect2(38, 207, 124, 27), Color("183f2a"), Color("78efab"), 6, 2)
