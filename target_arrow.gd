class_name TCGTargetArrow
extends Control

var arrows: Array = []
var pulse_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	pulse_time = fmod(pulse_time + delta, 1.0)
	if not arrows.is_empty():
		queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	for arrow in arrows:
		var start: Vector2 = arrow.start
		var end: Vector2 = arrow.end
		var color: Color = arrow.color
		var delta := end - start
		var bend := (start + end) * 0.5 + delta.orthogonal().normalized() * 35
		if delta.length() < 40:
			start += Vector2(-30, -30)
			end += Vector2(30, -30)
			bend = start + Vector2(30, -100)
		var points := PackedVector2Array()
		for i in range(25):
			var t := float(i) / 24
			points.append((1 - t) * (1 - t) * start + 2 * (1 - t) * t * bend + t * t * end)
		draw_polyline(points, Color(0.02, 0.03, 0.05, 0.8), 9, true)
		draw_polyline(points, color, 4, true)
		var direction := (end - points[22]).normalized()
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([end, end - direction * 22 + side * 10, end - direction * 22 - side * 10]), color)
		draw_circle(start, 6, color)
		draw_arc(end, 15, 0, TAU, 32, color, 2, true)
		var title: String = arrow.get("title", "")
		if not title.is_empty():
			var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var position := title_position(start, width)
			draw_rect(Rect2(position - Vector2(6, 18), Vector2(width + 12, 26)), Color(0.04, 0.07, 0.12, 0.94))
			draw_string(font, position, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
		var impact_text: String = arrow.get("impact_text", "")
		if not impact_text.is_empty():
			var impact_color: Color = arrow.get("impact_color", Color("ff626b"))
			var pulse := 0.62 + 0.38 * sin(pulse_time * TAU)
			var font_size := 38
			var text_size := font.get_string_size(impact_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var badge_size := Vector2(maxf(74.0, text_size.x + 30.0), 58.0)
			var badge_center := end + Vector2(0, -8)
			var badge_rect := Rect2(badge_center - badge_size * 0.5, badge_size)
			draw_rect(badge_rect, Color(0.02, 0.025, 0.04, 0.82 * pulse))
			draw_rect(badge_rect, Color(impact_color, 0.95 * pulse), false, 4.0)
			var text_pos := Vector2(badge_center.x - text_size.x * 0.5, badge_center.y + text_size.y * 0.34)
			for shadow_offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
				draw_string(font, text_pos + shadow_offset, impact_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.01, 0.01, 0.015, pulse))
			draw_string(font, text_pos, impact_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(impact_color, pulse))

func title_position(start: Vector2, width: float) -> Vector2:
	var title_x := start.x - width * 0.5
	# Side chain cards occupy the arrow origin. Put their captions inward, beside the card.
	if start.x < size.x * 0.2:
		title_x = start.x + 74
	elif start.x > size.x * 0.8:
		title_x = start.x - width - 74
	return Vector2(clampf(title_x, 12, size.x - width - 12), clampf(start.y - 18, 28, size.y - 28))
