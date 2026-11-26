extends RefCounted

const STAGES := [
	{"name": "ARENA_BACKLOT", "footprint": MazeBuilder.Footprint.RECTANGLE, "event": 0, "backdrop": null},
	{"name": "ARENA_FOUNDRY", "footprint": MazeBuilder.Footprint.FOUNDRY, "event": 1, "backdrop": preload("res://UI/Art/Arenas/foundry.png")},
	{"name": "ARENA_MOON", "footprint": MazeBuilder.Footprint.MOON, "event": 2, "backdrop": preload("res://UI/Art/Arenas/moon.png")},
	{"name": "ARENA_GROVE", "footprint": MazeBuilder.Footprint.GROVE, "event": 3, "backdrop": preload("res://UI/Art/Arenas/grove.png")},
	{"name": "ARENA_KEYHOLE", "footprint": MazeBuilder.Footprint.KEYHOLE, "event": 0, "backdrop": preload("res://UI/Art/Arenas/foundry.png")},
	{"name": "ARENA_SWITCHBACK", "footprint": MazeBuilder.Footprint.SWITCHBACK, "event": 0, "backdrop": preload("res://UI/Art/Arenas/moon.png")},
	{"name": "ARENA_FORK", "footprint": MazeBuilder.Footprint.FORK, "event": 0, "backdrop": preload("res://UI/Art/Arenas/grove.png")},
]

static func for_level(level: int) -> Dictionary:
	return STAGES[clampi(level - 1, 0, STAGES.size() - 1)]
