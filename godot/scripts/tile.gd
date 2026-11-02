class_name Tile
extends Node2D
## Одна фигурка. Рисуется процедурно — без текстур, чтобы .pck был крошечным.

const COLORS := [
	Color("#ff6b6b"), # круг
	Color("#4d96ff"), # квадрат
	Color("#6bcb77"), # треугольник
	Color("#ffd93d"), # ромб
	Color("#c77dff"), # звезда
	Color("#ff9f1c"), # шестиугольник
]
const SHAPE_NAMES := ["circle", "square", "triangle", "diamond", "star", "hexagon"]
const GOLD := Color("#ffe066")

var kind := 0
var is_gold := false
var size := 90.0
var cell := Vector2i.ZERO
var _bg_style: StyleBoxFlat


func setup(p_kind: int, p_gold: bool, p_size: float, p_cell: Vector2i) -> void:
	kind = p_kind
	is_gold = p_gold
	size = p_size
	cell = p_cell
	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = Color(1, 1, 1, 0.07)
	_bg_style.set_corner_radius_all(int(size * 0.18))
	if is_gold:
		_bg_style.bg_color = Color(GOLD, 0.22)
		_bg_style.border_color = GOLD
		_bg_style.set_border_width_all(max(2, int(size * 0.04)))
	queue_redraw()


func color() -> Color:
	return COLORS[kind % COLORS.size()]


func _draw() -> void:
	var half := size * 0.5
	var pad := size * 0.04
	_bg_style.draw(get_canvas_item(), Rect2(-half + pad, -half + pad, size - pad * 2, size - pad * 2))

	var col := color()
	var r := size * 0.34
	match kind % 6:
		0:
			draw_circle(Vector2.ZERO, r, col)
		1:
			draw_rect(Rect2(-r, -r, r * 2, r * 2), col, true)
		2:
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -r * 1.1), Vector2(r * 1.1, r * 0.85), Vector2(-r * 1.1, r * 0.85)
			]), col)
		3:
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -r * 1.15), Vector2(r * 0.85, 0), Vector2(0, r * 1.15), Vector2(-r * 0.85, 0)
			]), col)
		4:
			draw_colored_polygon(_star(r * 1.15, r * 0.5), col)
		5:
			draw_colored_polygon(_polygon(6, r * 1.08, PI / 6.0), col)

	# Блик.
	draw_circle(Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.35))
	if is_gold:
		draw_circle(Vector2(r * 0.55, -r * 0.65), r * 0.14, GOLD)


func _polygon(n: int, radius: float, offset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := offset + TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _star(outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		var rad := outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a), sin(a)) * rad)
	return pts


# ---------- анимации ----------

func appear(delay := 0.0) -> void:
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func slide_to(target: Vector2, duration := 0.22) -> void:
	var t := create_tween()
	t.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func pop() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.06)
	t.chain().tween_property(self, "scale", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(queue_free)


func shake() -> void:
	var origin := position
	var t := create_tween()
	t.tween_property(self, "position", origin + Vector2(6, 0), 0.04)
	t.tween_property(self, "position", origin - Vector2(6, 0), 0.04)
	t.tween_property(self, "position", origin + Vector2(3, 0), 0.04)
	t.tween_property(self, "position", origin, 0.04)
