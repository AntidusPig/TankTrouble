extends RefCounted

enum Tile { VOID, FLOOR }
const LEGACY_MAX_TILE := 3
const COLORS := [Color("#533e37"), Color("#f6d39a")]
const PATH := "user://painted_arenas.cfg"
const MIN_SIZE := 4
const MAX_SIZE := 16


static func valid(dimension: int, tiles: PackedInt32Array, players: int) -> bool:
	if dimension < MIN_SIZE or dimension > MAX_SIZE or tiles.size() != dimension * dimension:
		return false
	var start := -1
	var count := 0
	for i in range(tiles.size()):
		if tiles[i] < Tile.VOID or tiles[i] > Tile.FLOOR:
			return false
		if tiles[i] != Tile.VOID:
			start = i
			count += 1
	if count < players:
		return false
	var visited := {start: true}
	var queue: Array[int] = [start]
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var cell := Vector2i(index % dimension, index / dimension)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_cell := cell + direction
			if not Rect2i(0, 0, dimension, dimension).has_point(next_cell):
				continue
			var next := next_cell.y * dimension + next_cell.x
			if tiles[next] != Tile.VOID and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return visited.size() == count


static func save_slot(slot: int, dimension: int, tiles: PackedInt32Array) -> Error:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(str(slot), "dimension", dimension)
	config.set_value(str(slot), "tiles", tiles)
	return config.save(PATH)


static func load_slot(slot: int) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return {}
	var dimension: Variant = config.get_value(str(slot), "dimension", 0)
	var tiles: Variant = config.get_value(str(slot), "tiles", null)
	if dimension is int and dimension >= MIN_SIZE and dimension <= MAX_SIZE and tiles is PackedInt32Array and tiles.size() == dimension * dimension:
		for i in range(tiles.size()):
			if tiles[i] < Tile.VOID or tiles[i] > LEGACY_MAX_TILE:
				return {}
			if tiles[i] > Tile.FLOOR:
				tiles[i] = Tile.FLOOR
		return {"dimension": dimension, "tiles": tiles}
	return {}
