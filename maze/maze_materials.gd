extends RefCounted

enum Kind { STUDIO, FOUNDRY, MOON, FOREST }
const TRIM := [Color("#ffd89e"), Color("#f8cb76"), Color("#c9dcf4"), Color("#ddcf97")]
const FLOOR := "res://UI/Art/MazeMaterials/floor.png"
const WALL := "res://UI/Art/MazeMaterials/wall.png"


static func texture(path: String, kind: int) -> AtlasTexture:
	if not ResourceLoader.exists(path):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	var half := atlas.atlas.get_size() * 0.5
	var origin := Vector2(kind % 2, kind / 2) * half
	var margin := Vector2.ONE * 12.0
	atlas.region = Rect2(origin + margin, half - margin * 2.0)
	if path == WALL:
		var swatch := atlas.region
		atlas.region = Rect2(swatch.position + Vector2(0.0, swatch.size.y * 0.38), Vector2(swatch.size.x, swatch.size.y * 0.24))
	atlas.filter_clip = true
	return atlas
