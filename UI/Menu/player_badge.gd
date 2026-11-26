class_name PlayerBadge extends Control

var player_slot := 0:
	set(value):
		player_slot = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.44
	if radius <= 0:
		return
	draw_circle(center + Vector2(1, 2), radius, RetroUi.INK, true, -1, true)
	draw_circle(center, radius, RetroUi.INK, true, -1, true)
	draw_circle(center, radius * 0.87, PlayerRoster.COLORS[player_slot], true, -1, true)
	var points := PackedVector2Array()
	var sides: int = [5, 4, 3, 6, 8, 4, 6, 8][player_slot]
	var star := player_slot in [0, 4, 6, 7]
	var count := sides * 2 if star else sides
	var angle := -PI / 2.0 + (PI / 4.0 if player_slot == 5 else 0.0)
	for point in range(count):
		var reach := radius * (0.27 if star and point % 2 == 1 else 0.58)
		points.append(center + Vector2.from_angle(angle + TAU * point / count) * reach)
	draw_colored_polygon(points, RetroUi.CREAM)
	if player_slot in [3, 7]:
		draw_circle(center, radius * 0.15, RetroUi.INK, true, -1, true)
