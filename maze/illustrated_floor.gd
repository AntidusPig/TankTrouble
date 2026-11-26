extends Node2D

var maze: MazeBuilder
var material_texture: AtlasTexture


func _ready() -> void:
	z_index = -8


func _draw() -> void:
	if material_texture == null:
		return
	var span := maze.grid_size
	var source := material_texture.region
	# Four adjacent cells share one painted swatch to avoid a stamp on every tile.
	var quarter := source.size * 0.5
	for y in range(maze.maze_size.y):
		for x in range(maze.maze_size.x):
			if not maze.valid_index(x, y):
				continue
			var center := maze.to_local(maze.get_cell_position(x, y))
			var target := Rect2(center - Vector2.ONE * span * 0.5, Vector2.ONE * span).grow(0.25)
			var sample := Rect2(source.position + Vector2(x % 2, y % 2) * quarter, quarter)
			draw_texture_rect_region(material_texture.atlas, target, sample, Color.WHITE, false, true)
