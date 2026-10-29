class_name TCGCombatFX
extends Control

var kind := "damage"
var amount := 0
var lethal := false
var elapsed := 0.0
var duration := 0.85
var number: Label
var tint := Color("ff635d")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint = Color("71ffc1") if kind == "heal" else Color("ff635d")
	if kind in ["shield", "mana"]: tint = Color("8acfff")
	if amount == 0: tint = Color("b5d7ed")
	number = Label.new()
	number.text = ("+%d" if kind == "heal" else "−%d") % amount
	if amount == 0: number.text = "회복 0" if kind == "heal" else "방어!"
	if kind == "shield": number.text = "방어 +%d" % amount
	if kind == "mana": number.text = "마나 +%d" % amount
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 40 if amount > 0 else 25)
	number.add_theme_color_override("font_color", tint)
	number.add_theme_color_override("font_outline_color", Color("121b29"))
	number.add_theme_constant_override("outline_size", 9)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.size = Vector2(size.x + 100, 65)
	add_child(number)
	if lethal:
		var defeat_label := Label.new()
		defeat_label.text = "재기불능"
		defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		defeat_label.add_theme_color_override("font_color", Color("ffb6a5"))
		defeat_label.add_theme_constant_override("outline_size", 6)
		defeat_label.position = Vector2(-25, size.y * 0.66)
		defeat_label.size.x = size.x + 50
		defeat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(defeat_label)

func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	number.position = Vector2(-50, size.y * 0.42 - 62 * progress)
	number.modulate.a = minf(1.0, (1.0 - progress) * 3)
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var center := size * 0.5
	var fade := 1.0 - progress
	var flash := tint
	flash.a = maxf(0, 0.35 * (1 - progress * 3))
	draw_rect(Rect2(Vector2.ZERO, size), flash)
	var glow := tint
	glow.a = fade * 0.8
	draw_arc(center, 20 + progress * size.x * 0.65, 0, TAU, 48, glow, 3, true)
	if amount == 0: return
	for i in range(10):
		var angle := float(i) / 10 * TAU
		var offset := Vector2.from_angle(angle) * (15 + progress * 76)
		if kind == "heal":
			var point := center + Vector2(offset.x, offset.y - progress * 42)
			draw_line(point - Vector2(4, 0), point + Vector2(4, 0), glow, 2, true)
			draw_line(point - Vector2(0, 4), point + Vector2(0, 4), glow, 2, true)
		else:
			draw_line(center + offset * 0.7, center + offset, glow, 3, true)
	if kind == "damage" and progress < 0.45:
		draw_line(center + Vector2(-37, 35), center + Vector2(37, -35), glow, 5, true)
