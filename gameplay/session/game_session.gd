extends Node

const MENU := "res://UI/Menu/main_menu.tscn"
const ARENA := "res://world.tscn"
const LEVEL_COUNT := 3
const SAVE_PATH := "user://arena_checkpoint.cfg"
const SAVE_BACKUP := "user://arena_checkpoint.backup"

var player_count := 1
var opponent_ai := 3
var level := 1
var rounds_played := 0
var player_one_wins := 0
var player_two_wins := 0
var losses := 0
var draws := 0
var completed := false


func ai_runtime_available() -> bool:
	return ClassDB.class_exists("CSharpScript")


func start(players: int, controller: int = 0) -> Error:
	if players == 1 and controller > 0 and not ai_runtime_available():
		return ERR_UNAVAILABLE
	player_count = clampi(players, 1, 2)
	opponent_ai = clampi(controller, 0, 5) if player_count == 1 else 0
	level = 1
	rounds_played = 0
	player_one_wins = 0
	player_two_wins = 0
	losses = 0
	draws = 0
	completed = false
	return get_tree().change_scene_to_file(ARENA)


func save_checkpoint() -> Error:
	var config := ConfigFile.new()
	var fields := {
		"version": 1, "players": player_count, "level": level, "opponent_ai": opponent_ai,
		"rounds": rounds_played, "player_one_wins": player_one_wins,
		"player_two_wins": player_two_wins, "losses": losses, "draws": draws,
		"completed": int(completed)
	}
	for key in fields:
		config.set_value("arena", key, fields[key])
	var temp := SAVE_PATH + ".tmp"
	var error := config.save(temp)
	if error != OK:
		return error
	var path := ProjectSettings.globalize_path(SAVE_PATH)
	var backup := ProjectSettings.globalize_path(SAVE_BACKUP)
	if FileAccess.file_exists(SAVE_PATH):
		error = DirAccess.rename_absolute(path, backup)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), path)
	if error == OK:
		if FileAccess.file_exists(SAVE_BACKUP):
			DirAccess.remove_absolute(backup)
	elif FileAccess.file_exists(SAVE_BACKUP):
		DirAccess.rename_absolute(backup, path)
	return error


func _read_checkpoint() -> Dictionary:
	for path in [SAVE_PATH, SAVE_BACKUP]:
		var config := ConfigFile.new()
		if config.load(path) != OK or config.get_value("arena", "version", 0) != 1:
			continue
		var bounds := {
			"players": Vector2i(1, 2), "level": Vector2i(1, LEVEL_COUNT),
			"rounds": Vector2i(0, 1000000), "player_one_wins": Vector2i(0, 1000000),
			"player_two_wins": Vector2i(0, 1000000), "losses": Vector2i(0, 1000000),
			"draws": Vector2i(0, 1000000), "completed": Vector2i(0, 1)
		}
		var fields := {}
		for key in bounds:
			var value: Variant = config.get_value("arena", key, -1)
			if typeof(value) != TYPE_INT or value < bounds[key].x or value > bounds[key].y:
				break
			fields[key] = value
		if fields.size() == bounds.size():
			var controller: Variant = config.get_value("arena", "opponent_ai", 3)
			if typeof(controller) == TYPE_INT and controller >= 0 and controller <= 5:
				fields["opponent_ai"] = controller if fields.players == 1 else 0
				return fields
	return {}


func has_checkpoint() -> bool:
	var checkpoint := _read_checkpoint()
	return not checkpoint.is_empty() and checkpoint.completed == 0


func load_checkpoint() -> Error:
	var fields := _read_checkpoint()
	if fields.is_empty() or fields.completed != 0:
		return ERR_INVALID_DATA
	if fields.opponent_ai > 0 and not ai_runtime_available():
		return ERR_UNAVAILABLE
	player_count = fields.players
	opponent_ai = fields.opponent_ai
	level = fields.level
	rounds_played = fields.rounds
	player_one_wins = fields.player_one_wins
	player_two_wins = fields.player_two_wins
	losses = fields.losses
	draws = fields.draws
	completed = false
	return get_tree().change_scene_to_file(ARENA)
