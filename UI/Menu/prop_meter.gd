extends Control

var _marker := ""
var _tint := Color.WHITE
var _portion := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(queue_redraw)


func show_prop(marker: String, tint: Color, portion: float, caption: String) -> void:
	show()
	if tooltip_text != caption:
		tooltip_text = caption
		accessibility_name = caption
	portion = clampf(portion, 0.0, 1.0)
	if _marker == marker and _tint == tint and is_equal_approx(_portion, portion):
		return
	_marker = marker
	_tint = tint
	_portion = portion
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 2.5
	if radius <= 4.0:
		return
	draw_circle(center, radius + 2.0, RetroUi.INK, true, -1.0, true)
	draw_circle(center, radius + 0.5, Color("#826b57"), true, -1.0, true)
	draw_circle(center, radius - 2.0, RetroUi.CREAM, true, -1.0, true)
	if _portion > 0.0:
		draw_arc(center, radius - 0.8, -PI * 0.5, TAU * _portion - PI * 0.5, 48, _tint, 3.5, true)
	var font := RetroUi.DISPLAY_FONT
	var point_size := maxi(12, roundi(radius * 1.2))
	var width := font.get_string_size(_marker, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	var baseline := (font.get_ascent(point_size) - font.get_descent(point_size)) * 0.5
	draw_string(font, center + Vector2(-width * 0.5, baseline), _marker, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, RetroUi.INK)
