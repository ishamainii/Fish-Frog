class_name StarRow
extends Control
## A row of five-pointed stars, `got` of them filled and the rest outlined.
## Drawn rather than typed, as not every font has a star in it.

@export_range(0, 10) var got := 0:
	set(value):
		got = value
		queue_redraw()
@export_range(1, 10) var out_of := 3:
	set(value):
		out_of = value
		_resize()
## Of each star, point to point (px).
@export_range(8.0, 128.0, 1.0) var star_size := 28.0:
	set(value):
		star_size = value
		_resize()
@export var fill_color := UiStyle.SAND
@export var empty_color := Color(1, 1, 1, 0.3)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_resize()


func _draw() -> void:
	var gap := star_size * 0.25
	for i in out_of:
		var center := Vector2(star_size * 0.5 + i * (star_size + gap), star_size * 0.5)
		var points := _star(center, star_size * 0.5)
		if i < got:
			draw_colored_polygon(points, fill_color)
		else:
			points.append(points[0])
			draw_polyline(points, empty_color, 2.0, true)


func _star(center: Vector2, outer: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else outer * 0.45
		var angle := -PI * 0.5 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


func _resize() -> void:
	custom_minimum_size = Vector2(out_of * star_size + (out_of - 1) * star_size * 0.25, star_size)
	queue_redraw()
