extends Node

const MENU := "res://UI/Menu/main_menu.tscn"
const ARENA := "res://world.tscn"
const SUDOKU := "res://world_sudoku.tscn"
const ARENA_MODE := 0
const SUDOKU_MODE := 1
const ARENA_SIZES := [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
const SUDOKU_SIZES := [4, 6, 8, 9, 10, 12, 16]
const LEVEL_COUNT := 7
const PAINTED_MAP := preload("res://maze/painted_map.gd")
const SAVE_PATH := "user://arena_checkpoint.cfg"
const SAVE_BACKUP := "user://arena_checkpoint.backup"

var editor_draft := PackedInt32Array()
var editor_dimension := 9
var return_to_map_editor := false
var custom_tiles := PackedInt32Array()
var single_arena := false
var editor_playtest := false
var player_count := 1
var opponent_ai := 3
var roster := PackedInt32Array([PlayerRoster.HUMAN, 3])
var wins := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
var level := 1
var mode := ARENA_MODE
var size_choice := 9
var map_size := 9
var rounds_played := 0
var player_one_wins := 0
var player_two_wins := 0
var losses := 0
var draws := 0
var completed := false


func ai_runtime_available() -> bool:
	return ClassDB.class_exists("CSharpScript")


func start(players: int, controller: int = 0) -> Error:
	return start_roster(PlayerRoster.from_legacy(clampi(players, 1, 2), clampi(controller, 0, 5)))


func sizes_for(game_mode: int) -> Array:
	return SUDOKU_SIZES if game_mode == SUDOKU_MODE else ARENA_SIZES


func prepare_map() -> void:
	map_size = size_choice if size_choice > 0 else sizes_for(mode).pick_random()


func start_roster(selection: PackedInt32Array, game_mode := ARENA_MODE, requested_size := 9, paint := PackedInt32Array(), start_level := 0, from_editor := true) -> Error:
	if game_mode not in [ARENA_MODE, SUDOKU_MODE] or (requested_size != 0 and requested_size not in sizes_for(game_mode)):
		return ERR_INVALID_PARAMETER
	if start_level < 0 or start_level > LEVEL_COUNT or (start_level > 0 and (game_mode != ARENA_MODE or not paint.is_empty())):
		return ERR_INVALID_PARAMETER
	for role in selection:
		if role >= PlayerRoster.PRACTICE and (role == PlayerRoster.SUDOKU_AI) != (game_mode == SUDOKU_MODE):
			return ERR_INVALID_PARAMETER
	if not PlayerRoster.is_valid(selection):
		return ERR_INVALID_PARAMETER
	if PlayerRoster.needs_dotnet(selection) and not ai_runtime_available():
		return ERR_UNAVAILABLE
	if not paint.is_empty() and (game_mode != ARENA_MODE or not PAINTED_MAP.valid(requested_size, paint, selection.size() - selection.count(PlayerRoster.OFF))):
		return ERR_INVALID_DATA
	custom_tiles = paint.duplicate()
	single_arena = start_level > 0 or not paint.is_empty()
	editor_playtest = from_editor and not paint.is_empty()
	_set_roster(selection)
	mode = game_mode
	size_choice = requested_size
	prepare_map()
	wins.fill(0)
	level = maxi(1, start_level)
	rounds_played = 0
	player_one_wins = 0
	player_two_wins = 0
	losses = 0
	draws = 0
	completed = false
	return get_tree().change_scene_to_file(SUDOKU if mode == SUDOKU_MODE else ARENA)


func play_random_next(previous_level: int, was_custom: bool) -> Error:
	var next_level := 1
	if mode == ARENA_MODE:
		var choices := range(1, LEVEL_COUNT + 1)
		if not was_custom:
			choices.erase(previous_level)
		next_level = choices.pick_random()
	custom_tiles = PackedInt32Array()
	editor_playtest = false
	return_to_map_editor = false
	single_arena = mode == ARENA_MODE
	level = next_level
	completed = false
	size_choice = 0
	prepare_map()
	return get_tree().change_scene_to_file(SUDOKU if mode == SUDOKU_MODE else ARENA)


func _set_roster(selection: PackedInt32Array) -> void:
	roster = selection.duplicate()
	player_count = roster.count(PlayerRoster.HUMAN)
	opponent_ai = 0
	for role in roster:
		if role > PlayerRoster.PRACTICE:
			opponent_ai = role
			break


func award_win(slot: int) -> void:
	wins[slot] += 1
	player_one_wins = wins[0]
	player_two_wins = wins[1]


func save_checkpoint() -> Error:
	if mode != ARENA_MODE or single_arena:
		return ERR_UNAVAILABLE
	var config := ConfigFile.new()
	var fields := {
		"version": 3, "players": player_count, "level": level, "opponent_ai": opponent_ai,
		"size_choice": size_choice, "map_size": map_size,
		"roster": roster, "wins": wins,
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
		if config.load(path) != OK:
			continue
		var version: Variant = config.get_value("arena", "version", 0)
		if version not in [1, 2, 3]:
			continue
		var bounds := {
			"players": Vector2i(0, 3), "level": Vector2i(1, LEVEL_COUNT),
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
		if fields.size() != bounds.size():
			continue
		if version == 1:
			var controller: Variant = config.get_value("arena", "opponent_ai", 3)
			if typeof(controller) != TYPE_INT or controller < 0 or controller > 5 or fields.players not in [1, 2]:
				continue
			fields["roster"] = PlayerRoster.from_legacy(fields.players, controller)
			fields["wins"] = PackedInt32Array([fields.player_one_wins, fields.player_two_wins, 0, 0, 0, 0, 0, 0])
		else:
			var saved_roster: Variant = config.get_value("arena", "roster")
			var saved_wins: Variant = config.get_value("arena", "wins")
			if typeof(saved_roster) != TYPE_PACKED_INT32_ARRAY or not PlayerRoster.is_valid(saved_roster):
				continue
			if typeof(saved_wins) != TYPE_PACKED_INT32_ARRAY or saved_wins.size() != PlayerRoster.MAX_PLAYERS:
				continue
			var valid_scores := true
			for score in saved_wins:
				valid_scores = valid_scores and score >= 0 and score <= 1000000
			if not valid_scores:
				continue
			fields["roster"] = saved_roster
			fields["wins"] = saved_wins
		var saved_map: Variant = config.get_value("arena", "map_size", 9)
		var saved_choice: Variant = config.get_value("arena", "size_choice", 9)
		if typeof(saved_map) != TYPE_INT or saved_map not in ARENA_SIZES:
			continue
		if typeof(saved_choice) != TYPE_INT or (saved_choice != 0 and saved_choice not in ARENA_SIZES):
			continue
		if fields.roster.has(PlayerRoster.SUDOKU_AI):
			continue
		fields["map_size"] = saved_map
		fields["size_choice"] = saved_choice
		return fields
	return {}


func has_checkpoint() -> bool:
	var checkpoint := _read_checkpoint()
	return not checkpoint.is_empty() and checkpoint.completed == 0


func load_checkpoint() -> Error:
	var fields := _read_checkpoint()
	if fields.is_empty() or fields.completed != 0:
		return ERR_INVALID_DATA
	if PlayerRoster.needs_dotnet(fields.roster) and not ai_runtime_available():
		return ERR_UNAVAILABLE
	custom_tiles = PackedInt32Array()
	single_arena = false
	editor_playtest = false
	_set_roster(fields.roster)
	mode = ARENA_MODE
	map_size = fields.map_size
	size_choice = fields.size_choice
	wins = fields.wins
	level = fields.level
	rounds_played = fields.rounds
	player_one_wins = fields.player_one_wins
	player_two_wins = fields.player_two_wins
	losses = fields.losses
	draws = fields.draws
	completed = false
	return get_tree().change_scene_to_file(SUDOKU if mode == SUDOKU_MODE else ARENA)
