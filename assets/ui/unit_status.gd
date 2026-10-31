class_name TCGUnitStatus
extends Control

var mana := 0
var shield := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(172, 54)
	tooltip_text = "마나: %d%s" % [mana, " · 다음 피해를 %d 감소" % shield if shield > 0 else ""]

func _draw() -> void:
	# Floating blue crystal, styled to match the card's jewel-like stat frame.
	var center := Vector2(86, 23)
	var halo := Color("36bfff")
	halo.a = 0.16
	draw_circle(center + Vector2(0, 2), 23, halo)
	var points := PackedVector2Array([
		center + Vector2(-11, -19), center + Vector2(8, -19),
		center + Vector2(19, -7), center + Vector2(14, 13),
		center + Vector2(0, 21), center + Vector2(-14, 13),
		center + Vector2(-19, -7),
	])
	draw_colored_polygon(points, Color("1980a9"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[6], points[0]]), Color("9eeaff"), 2, true)
	draw_colored_polygon(PackedVector2Array([points[0], points[1], center + Vector2(1, 5)]), Color("c8f7ff"))
	draw_colored_polygon(PackedVector2Array([points[0], points[6], center + Vector2(-4, 10), center + Vector2(1, 5)]), Color("53c9ee"))
	draw_colored_polygon(PackedVector2Array([points[1], points[2], points[3], center + Vector2(1, 5)]), Color("147195"))
	var font := ThemeDB.fallback_font
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, center + Vector2(-7, 6) + offset, str(mana), HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color("082235"))
	draw_string(font, center + Vector2(-7, 6), str(mana), HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color.WHITE)
	draw_string(font, Vector2(70, 52), "MANA", HORIZONTAL_ALIGNMENT_CENTER, 32, 9, Color("9edcf0"))
	if shield > 0:
		var shield_center := Vector2(145, 22)
		var shield_points := PackedVector2Array([
			shield_center + Vector2(0, -17), shield_center + Vector2(15, -11),
			shield_center + Vector2(13, 5), shield_center + Vector2(0, 18),
			shield_center + Vector2(-13, 5), shield_center + Vector2(-15, -11),
		])
		draw_colored_polygon(shield_points, Color("194569"))
		draw_polyline(PackedVector2Array([shield_points[0], shield_points[1], shield_points[2], shield_points[3], shield_points[4], shield_points[5], shield_points[0]]), Color("9ce8ff"), 2, true)
		var amount := "−%d" % shield
		var amount_size := font.get_string_size(amount, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
		draw_string(font, shield_center + Vector2(-amount_size * 0.5, 5), amount, HORIZONTAL_ALIGNMENT_CENTER, amount_size + 2, 13, Color.WHITE)
