extends Node

const PATH := "user://ai_difficulty.cfg"
const ROLES := [1, 2, 3, 4, 5, 6]
const LABELS := ["AI_BEGINNER", "AI_INTERMEDIATE", "AI_ADVANCED", "RANDOM"]
const CARD_COLORS := [Color("#daf0cd"), Color("#ffdda0"), Color("#f2bcbc")]
const RANDOM := 3
const DEFAULT := 0
var _settings := ConfigFile.new()


func _ready() -> void:
	_settings.load(PATH)


func preference(role: int) -> int:
	var value: Variant = _settings.get_value("difficulty", str(role), DEFAULT)
	return value if value is int and value >= 0 and value <= RANDOM else DEFAULT


func set_preference(role: int, value: int) -> Error:
	if role not in ROLES or value < 0 or value > RANDOM:
		return ERR_INVALID_PARAMETER
	var previous := preference(role)
	_settings.set_value("difficulty", str(role), value)
	var result := _settings.save(PATH)
	if result != OK:
		_settings.set_value("difficulty", str(role), previous)
	return result


func roll(role: int) -> int:
	if role not in ROLES:
		return -1
	var chosen := preference(role)
	return randi_range(0, RANDOM - 1) if chosen == RANDOM else chosen
