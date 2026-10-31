class_name TCGGambleFX
extends Control

const RESULTS := [
	"수호자 소환 · 0/1 하수인 6",
	"하수인 소환 · 6/6 하수인 둘",
	"부활 · 처치된 유닛 하나 선택",
	"상대의 사용된 주문 1개를 골라 효과 적용",
	"피해 6 · 악마 현재/최대 생명력 +6",
	"주사위 증가 · 다음 자신의 턴부터 +1",
]
var kind := "roulette"
var result := 1
var player_index := 0
var amount := 0
var elapsed := 0.0
var duration := 2.6
var spin_duration := 1.55
var title: Label
var result_label: RichTextLabel
var rotation_angle := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind != "roulette":
		duration = 1.3 if kind == "slot_break" else (1.55 if kind == "field_destroy" else (1.15 if kind == "arrival" else 0.25))
		return
	title = Label.new()
	title.text = "P%d · 갬블의 악마" % [player_index + 1]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(12, 12)
	title.size = Vector2(size.x - 24, 32)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f4d189"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	result_label = RichTextLabel.new()
	result_label.bbcode_enabled = true
	result_label.text = "[center]운명을 굴리는 중…[/center]"
	result_label.fit_content = false
	result_label.scroll_active = false
	result_label.position = Vector2(12, size.y - 60)
	result_label.size = Vector2(size.x - 24, 48)
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", Color("e6d7ff"))
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result_label)

func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / spin_duration, 0.0, 1.0)
	rotation_angle = (TAU * 5 - float(result - 1) * TAU / 6.0) * (1.0 - pow(1.0 - t, 3.0))
	if kind == "roulette" and elapsed >= spin_duration:
		result_label.text = "[center]" + ("%d  ·  %s" % [result, RESULTS[result - 1]]).replace("6", "[color=#ff5364]6[/color]") + "[/center]"
	queue_redraw()

func _draw() -> void:
	if kind == "slot_break":
		_draw_slot_break()
		return
	if kind == "field_destroy":
		_draw_field_destroy()
		return
	if kind != "roulette":
		if kind == "arrival": _draw_legendary_arrival()
		else: _draw_portal()
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055, 0.035, 0.11, 0.96)
	panel.border_color = Color("b592f3")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(22)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var center := Vector2(size.x * 0.66, size.y * 0.48)
	var radius := minf(size.y * 0.31, 116.0)
	var font := get_theme_default_font()
	for index in range(6):
		var angle := rotation_angle + float(index) * TAU / 6.0 - PI / 2.0
		var polygon := PackedVector2Array([center])
		for step in range(15):
			polygon.append(center + Vector2.from_angle(angle - PI / 6 + float(step) * PI / 42.0) * radius)
		var color := Color("453160") if index % 2 == 0 else Color("272740")
		if elapsed >= spin_duration and index == result - 1: color = Color("987637")
		draw_colored_polygon(polygon, color)
		draw_line(center, polygon[1], Color("ab8ed5"), 1.5, true)
		var point := center + Vector2.from_angle(angle) * radius * 0.66
		var number := str(index + 1)
		var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(font, point + Vector2(-width * 0.5, 10), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ff5364") if index == 5 else Color("fff3d6"))
	draw_arc(center, radius + 3, 0, TAU, 96, Color("d8b9fc"), 3, true)
	draw_circle(center, 16, Color("171322"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-12, -radius - 13), center + Vector2(12, -radius - 13), center + Vector2(0, -radius + 7)]), Color("ffdc82"))
	if elapsed >= spin_duration:
		draw_arc(center, radius + 9, 0, TAU, 96, Color("ffe9a5"), 2, true)
	_draw_friendly_demon(center, radius)

func _draw_slot_break() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var center := size * 0.5
	var crack_t := clampf(t / 0.58, 0.0, 1.0)
	var crack_color := Color("ead8ff")
	crack_color.a = minf(1.0, crack_t * 2.5) * (1.0 - maxf(0.0, t - 0.72) / 0.28)
	var branches := [
		[Vector2(0.48, 0.03), Vector2(0.55, 0.22), Vector2(0.43, 0.38), Vector2(0.57, 0.55), Vector2(0.45, 0.76), Vector2(0.51, 0.98)],
		[Vector2(0.44, 0.38), Vector2(0.25, 0.47), Vector2(0.08, 0.42)],
		[Vector2(0.57, 0.55), Vector2(0.76, 0.45), Vector2(0.95, 0.5)],
		[Vector2(0.45, 0.76), Vector2(0.28, 0.84), Vector2(0.17, 0.96)],
	]
	for branch in branches:
		var points := PackedVector2Array()
		for point in branch:
			points.append(Vector2(point.x * size.x, point.y * size.y))
		var visible_points := maxi(2, ceili(float(points.size()) * crack_t))
		draw_polyline(points.slice(0, visible_points), crack_color, 3.5, true)
	if t > 0.48:
		var burst_t := (t - 0.48) / 0.52
		for index in range(12):
			var angle := float(index) * TAU / 12.0 + float(index % 3) * 0.17
			var distance := minf(size.x, size.y) * (0.08 + burst_t * (0.45 + float(index % 4) * 0.08))
			var shard_center := center + Vector2.from_angle(angle) * distance
			var shard_size := 4.0 + float(index % 3) * 2.0
			var shard_color := Color("c9a7ef")
			shard_color.a = 1.0 - burst_t
			draw_colored_polygon(PackedVector2Array([
				shard_center + Vector2(-shard_size, -shard_size * 0.4),
				shard_center + Vector2(shard_size, 0),
				shard_center + Vector2(-shard_size * 0.3, shard_size),
			]), shard_color)
		var flash := Color("f1ddff")
		flash.a = sin(clampf(burst_t, 0.0, 1.0) * PI) * 0.34
		draw_circle(center, minf(size.x, size.y) * (0.08 + burst_t * 0.6), flash)

func _draw_friendly_demon(wheel_center: Vector2, wheel_radius: float) -> void:
	var bob := sin(elapsed * 5.0) * 3.0
	var body_center := Vector2(size.x * 0.22, size.y * 0.57 + bob)
	var purple := Color("7453ad")
	var light := Color("b99be5")
	# 둥근 몸, 작은 뿔과 웃는 얼굴로 장난스러운 악마를 만든다.
	draw_circle(body_center, 48, Color(0.07, 0.04, 0.12, 0.7))
	draw_circle(body_center, 43, purple)
	draw_colored_polygon(PackedVector2Array([body_center + Vector2(-30, -31), body_center + Vector2(-42, -61), body_center + Vector2(-12, -42)]), light)
	draw_colored_polygon(PackedVector2Array([body_center + Vector2(30, -31), body_center + Vector2(42, -61), body_center + Vector2(12, -42)]), light)
	draw_circle(body_center + Vector2(-15, -7), 5, Color("fff1bd"))
	draw_circle(body_center + Vector2(15, -7), 5, Color("fff1bd"))
	draw_circle(body_center + Vector2(-14, -6), 2, Color("312444"))
	draw_circle(body_center + Vector2(14, -6), 2, Color("312444"))
	draw_arc(body_center + Vector2(0, 7), 15, 0.2, PI - 0.2, 18, Color("fff1bd"), 3, true)
	# 손이 룰렛 테두리를 따라 움직여 직접 돌리는 모습.
	var hand_angle := rotation_angle - PI * 0.72
	var hand := wheel_center + Vector2.from_angle(hand_angle) * (wheel_radius + 2)
	var shoulder := body_center + Vector2(31, -2)
	var elbow := shoulder.lerp(hand, 0.48) + Vector2(0, 12 + sin(elapsed * 7.0) * 5.0)
	draw_polyline(PackedVector2Array([shoulder, elbow, hand]), light, 11, true)
	draw_circle(hand, 9, Color("d6b9f5"))
	draw_arc(body_center + Vector2(-37, 26), 30, -0.15, 1.7, 20, light, 6, true)
	if elapsed < spin_duration:
		for index in range(3):
			var sparkle := wheel_center + Vector2.from_angle(elapsed * 3.0 + index * TAU / 3.0) * (wheel_radius + 19)
			draw_circle(sparkle, 3.5, Color("ffe18b"))

func _draw_field_destroy() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var flash := sin(t * PI)
	var old_color := Color(0.06, 0.11, 0.2, 0.96)
	var new_color := Color(0.14, 0.075, 0.26, 0.96)
	draw_rect(Rect2(Vector2.ZERO, size), old_color.lerp(new_color, smoothstep(0.22, 0.92, t)), true)
	var slot_count := 6
	var gap := 12.0
	var card_width := minf(118.0, (size.x - gap * float(slot_count + 1)) / float(slot_count))
	var card_height := minf(size.y * 0.7, card_width * 1.34)
	var total_width := card_width * slot_count + gap * (slot_count - 1)
	var start_x := (size.x - total_width) * 0.5
	var y := (size.y - card_height) * 0.52
	for index in range(slot_count):
		var delay := float(index) * 0.065
		var local := clampf((t - delay) / 0.62, 0.0, 1.0)
		var center := Vector2(start_x + index * (card_width + gap) + card_width * 0.5, y + card_height * 0.5)
		var shrink := 1.0 - local * 0.72
		var rect := Rect2(center - Vector2(card_width, card_height) * 0.5 * shrink, Vector2(card_width, card_height) * shrink)
		var card_color := Color(0.25, 0.38, 0.58, (1.0 - local) * 0.85)
		draw_rect(rect, card_color, true)
		draw_rect(rect, Color(0.72, 0.84, 1.0, (1.0 - local) * 0.9), false, 2.0)
		if local > 0.04:
			var crack_alpha := clampf((local - 0.04) * 4.0, 0.0, 1.0) * (1.0 - local)
			var crack_color := Color(0.92, 0.84, 1.0, crack_alpha)
			var crack := PackedVector2Array([
				center + Vector2(-card_width * 0.05, -card_height * 0.48),
				center + Vector2(card_width * 0.08, -card_height * 0.18),
				center + Vector2(-card_width * 0.12, card_height * 0.02),
				center + Vector2(card_width * 0.13, card_height * 0.23),
				center + Vector2(card_width * 0.02, card_height * 0.48),
			])
			draw_polyline(crack, crack_color, 3.0, true)
			draw_line(crack[2], crack[2] + Vector2(-card_width * 0.24, card_height * 0.13), crack_color, 2.0, true)
			draw_line(crack[3], crack[3] + Vector2(card_width * 0.22, -card_height * 0.08), crack_color, 2.0, true)
		if local > 0.28:
			for shard in range(5):
				var angle := float(shard) * TAU / 5.0 + float(index) * 0.31
				var from := center + Vector2.from_angle(angle) * card_width * 0.16
				var to := center + Vector2.from_angle(angle) * card_width * (0.3 + local * 1.15)
				var shard_color := Color("cfb3ff")
				shard_color.a = (1.0 - local) * 0.9
				draw_line(from, to, shard_color, 3.0, true)
	var veil := Color("9a69db")
	veil.a = flash * 0.2
	draw_rect(Rect2(Vector2.ZERO, size), veil, true)
	var font := get_theme_default_font()
	var text := "악마의 놀이판으로 재구성!"
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
	draw_string(font, Vector2((size.x - text_width) * 0.5, 34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("f6d98c"))
	if t > 0.6:
		var sub := "9칸의 놀이판 · 빈자리가 없으면 더 소환할 수 없음"
		var sub_width := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var sub_color := Color("eadfff")
		sub_color.a = smoothstep(0.6, 0.9, t)
		draw_string(font, Vector2((size.x - sub_width) * 0.5, size.y - 18), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, sub_color)

func _draw_legendary_arrival() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var center := size * 0.5
	var burst := sin(clampf(t * 1.35, 0.0, 1.0) * PI)
	# 여러 겹의 빛기둥과 회전 문양으로 강한 상급 소환의 분위기를 만든다.
	for layer in range(5):
		var width := size.x * (0.08 + float(layer) * 0.055) * (0.7 + burst * 0.5)
		var beam_color := Color("f6d98c") if layer % 2 == 0 else Color("b985ff")
		beam_color.a = (0.18 - float(layer) * 0.022) * burst
		draw_rect(Rect2(Vector2(center.x - width * 0.5, 0), Vector2(width, size.y)), beam_color, true)
	var seal_radius := minf(size.x, size.y) * (0.16 + t * 0.27)
	for ring in range(4):
		var ring_color := Color("ffe7a3") if ring % 2 == 0 else Color("c89cff")
		ring_color.a = (1.0 - t) * 0.9
		draw_arc(center, seal_radius * (1.0 - float(ring) * 0.14), elapsed * (2.2 + ring), elapsed * (2.2 + ring) + TAU * (0.62 + ring * 0.07), 72, ring_color, 4.0 - ring * 0.55, true)
	var points := PackedVector2Array()
	for index in range(8):
		points.append(center + Vector2.from_angle(elapsed * 1.8 + float(index) * TAU / 8.0) * seal_radius * (0.52 if index % 2 == 0 else 0.86))
	points.append(points[0])
	var rune_color := Color("d9b5ff")
	rune_color.a = (1.0 - t) * 0.72
	draw_polyline(points, rune_color, 3.0, true)
	for index in range(18):
		var angle := float(index) * TAU / 18.0 + elapsed * (0.7 if index % 2 == 0 else -0.5)
		var distance := seal_radius * (0.55 + 0.55 * t) + float(index % 3) * 7.0
		var spark := center + Vector2.from_angle(angle) * distance
		var spark_color := Color("fff0ae")
		spark_color.a = 1.0 - t
		draw_circle(spark, 2.5 + float(index % 3), spark_color)
	var shock_color := Color("f7d786")
	shock_color.a = (1.0 - t) * 0.85
	draw_arc(center, minf(size.x, size.y) * (0.12 + t * 0.62), 0, TAU, 96, shock_color, 5.0, true)
	if t > 0.72:
		var flash := Color.WHITE
		flash.a = sin((t - 0.72) / 0.28 * PI) * 0.42
		draw_rect(Rect2(Vector2.ZERO, size), flash, true)

func _draw_portal() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var center := size * 0.5
	var glow := Color("b486ff")
	glow.a = (1.0 - t) * 0.9
	var radius := size.x * (0.18 + t * 0.5)
	draw_circle(center, radius * 0.8, Color(0.35, 0.13, 0.6, (1.0 - t) * 0.32))
	draw_arc(center, radius, elapsed * 3, elapsed * 3 + TAU * 0.82, 64, glow, 4, true)
	draw_arc(center, radius * 0.66, -elapsed * 4, -elapsed * 4 + TAU * 0.8, 48, glow, 3, true)
	for index in range(10):
		var direction := Vector2.from_angle(float(index) * TAU / 10.0 + elapsed)
		draw_line(center + direction * radius * 0.7, center + direction * radius, glow, 2, true)
