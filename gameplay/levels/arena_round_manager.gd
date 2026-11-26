class_name ArenaRoundManager extends LevelManager

const TARGET_SCENE := preload("res://tank/tank_base.tscn")
const AI_COMPONENT_PATHS := [
	"res://gameplay/ai/components/StateMachineAI.tscn",
	"res://gameplay/ai/components/BehaviorTreeAI.tscn",
	"res://gameplay/ai/components/GoapAI.tscn",
	"res://gameplay/ai/components/UtilityAI.tscn",
	"res://gameplay/ai/components/NeuralSelfPlayAI.tscn"
]

class Contestant:
	var team: int
	var input_slot: int
	var lives := 3
	var tank: TankBase
	var previous_spawn := Vector2i(-1, -1)


@export_range(0.1, 10.0) var respawn_delay: float = 1.25
@export_range(0.1, 30.0) var intermission: float = 3.0

var round_active := false
var arena_number := 1
var round_result := "Preparing arena"
var targets: Array[TankBase] = []
var contestants: Array[Contestant] = []
var next_round := Timer.new()
var hud := Label.new()
var _ai_status := ""
@onready var pause_menu: PauseMenu = $"../WorldCommon/MenuUi"
@onready var pickups: PickupSpawner = $PickupSpawner


func _ready() -> void:
	next_round.one_shot = true
	add_child(next_round)
	next_round.timeout.connect(_advance)
	_build_hud()
	pickups.arena = self
	pickups.spawn_interval = maxf(1.5, pickups.spawn_interval - 0.5 * (GameSession.level - 1))
	maze_builder = $"../MazeBuilder"
	_begin_round.call_deferred()


func _build_hud() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var score_card := PanelContainer.new()
	score_card.position = Vector2(20, 16)
	score_card.add_theme_stylebox_override("panel", RetroUi.ink_box(RetroUi.PAPER, 12, 2, 3))
	score_card.theme = RetroUi.theme_resource()
	score_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(score_card)
	hud.add_theme_font_size_override("font_size", 19)
	score_card.add_child(hud)
	var button := MenuPanel.create_button("Pause", pause_menu.open, true)
	button.focus_mode = Control.FOCUS_NONE
	overlay.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -120
	button.offset_right = -24
	button.offset_top = 18


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(GameSession.MENU)


func available_cells(excluded: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var clearance := maze_builder.grid_size * minf(absf(maze_builder.scale.x), absf(maze_builder.scale.y)) * 0.65
	for y in range(maze_builder.maze_size.y):
		for x in range(maze_builder.maze_size.x):
			var cell := Vector2i(x, y)
			if cell in excluded:
				continue
			var center := maze_builder.get_cell_position(x, y)
			if tanks.any(func(tank): return is_instance_valid(tank) and tank.global_position.distance_to(center) < clearance):
				continue
			cells.append(cell)
	return cells


func _begin_round() -> void:
	arena_number = GameSession.level
	round_active = true
	_add_contestant(1, 1)
	if GameSession.player_count == 2:
		_add_contestant(2, 2)
	else:
		for i in range(maxi(1, number_of_enemies + arena_number - 1)):
			_add_contestant(2, 0)
	pickups.start()


func _add_contestant(team: int, input_slot: int) -> void:
	var contestant := Contestant.new()
	contestant.team = team
	contestant.input_slot = input_slot
	contestants.append(contestant)
	_spawn_contestant(contestant)


func _spawn_contestant(contestant: Contestant) -> void:
	if not round_active or contestant.lives == 0:
		return
	var occupied_props: Array[Vector2i] = []
	for pickup in get_tree().get_nodes_in_group("arena_pickup"):
		if pickup is ArenaPickup and not pickup.is_queued_for_deletion():
			occupied_props.append(pickup.cell)
	var cells := available_cells(occupied_props)
	if cells.is_empty():
		_wait_to_respawn(contestant, 0.25)
		return
	var cell := _choose_spawn(contestant, cells)
	contestant.previous_spawn = cell
	var human := contestant.input_slot > 0
	var tank := add_tank(PLAYER_TANK_SCENE if human else TARGET_SCENE, cell.x, cell.y)
	contestant.tank = tank
	tank.team = contestant.team
	var path := maze_builder.maze_astar.get_global_enemy_path(
		tank.global_position, maze_builder.get_cell_position(maze_builder.maze_size.x / 2, maze_builder.maze_size.y / 2))
	if path.size() > 1:
		tank.rotation = (path[1] - path[0]).angle()
	if human:
		var player := tank as TankPlayer
		player.set_input_slot(contestant.input_slot)
		player_tanks.append(player)
		_on_player_spawned(player)
		if contestant.input_slot == 2:
			player.get_node("body").modulate = Color("#7cc5ff")
	else:
		targets.append(tank)
		tank.get_node("body").modulate = Color("#f57376")
		if GameSession.opponent_ai == 0:
			tank.set_physics_process(false)
		else:
			_attach_ai(tank)
	tank.destroyed_signal.connect(_on_destroyed.bind(contestant, tank))


func _choose_spawn(contestant: Contestant, cells: Array[Vector2i]) -> Vector2i:
	if contestant.input_slot > 0:
		var home := Vector2i.ONE if contestant.team == 1 else maze_builder.maze_size - Vector2i(2, 2)
		cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.distance_squared_to(home) < b.distance_squared_to(home))
		return cells[0]

	if cells.size() > 1:
		cells.erase(contestant.previous_spawn)
	var separation := maze_builder.grid_size * absf(maze_builder.global_scale.x) * 2.5
	var rivals := tanks.filter(func(tank: TankBase): return is_instance_valid(tank) and tank.team != contestant.team)
	var safe := cells.filter(func(cell: Vector2i):
		var center := maze_builder.get_cell_position(cell.x, cell.y)
		return not rivals.any(func(tank: TankBase): return tank.global_position.distance_to(center) < separation)
	)
	return safe.pick_random() if not safe.is_empty() else cells.pick_random()


func _attach_ai(tank: TankBase) -> void:
	if GameSession.ai_runtime_available():
		var controller := load(AI_COMPONENT_PATHS[GameSession.opponent_ai - 1]) as PackedScene
		if controller != null:
			tank.add_child(controller.instantiate())
			if tank.has_meta("_active_tank_brain"):
				return
	_ai_status = "AI unavailable. Open and build the project in Godot .NET."
	push_warning(_ai_status)


func _on_destroyed(contestant: Contestant, tank: TankBase) -> void:
	if not round_active or contestant.tank != tank:
		return
	contestant.lives -= 1
	contestant.tank = null
	tanks.erase(tank)
	if tank is TankPlayer:
		player_tanks.erase(tank)
	else:
		targets.erase(tank)
	if contestant.lives > 0:
		_wait_to_respawn(contestant, respawn_delay)
	_resolve_round.call_deferred()


func _wait_to_respawn(contestant: Contestant, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	_spawn_contestant(contestant)


func _resolve_round() -> void:
	if not round_active:
		return
	var first_alive := contestants[0].lives > 0
	var rival_alive := contestants.any(func(slot: Contestant): return slot.team == 2 and slot.lives > 0)
	if first_alive and rival_alive:
		return

	var versus := GameSession.player_count == 2
	var advance := versus or first_alive
	GameSession.rounds_played += 1
	if first_alive:
		GameSession.player_one_wins += 1
		round_result = "Player 1 wins" if versus or GameSession.opponent_ai > 0 else "Targets cleared"
	elif rival_alive:
		if versus:
			GameSession.player_two_wins += 1
			round_result = "Player 2 wins"
		else:
			GameSession.losses += 1
			round_result = "Out of lives"
	else:
		GameSession.draws += 1
		round_result = "Round drawn"

	round_active = false
	pickups.process_mode = Node.PROCESS_MODE_DISABLED
	for effect in get_tree().get_nodes_in_group("arena_weapon_effect"):
		effect.process_mode = Node.PROCESS_MODE_DISABLED
	for tank in tanks:
		if is_instance_valid(tank):
			if is_instance_valid(tank.laser_beam):
				tank.laser_beam.queue_free()
			tank.process_mode = Node.PROCESS_MODE_DISABLED

	if advance and arena_number == GameSession.LEVEL_COUNT:
		GameSession.completed = true
		round_result += "   ·   Series complete"
	elif advance:
		GameSession.level = arena_number + 1
		round_result += "   ·   Next arena"
	else:
		round_result += "   ·   Retrying this arena"
	next_round.start(intermission)


func _advance() -> void:
	if GameSession.completed:
		_return_to_menu()
	else:
		get_tree().change_scene_to_file(GameSession.ARENA)


func _process(_delta: float) -> void:
	var versus := GameSession.player_count == 2
	var second_score := GameSession.player_two_wins if versus else GameSession.losses
	var score_label := "P2" if versus else "Losses"
	var score := "Arena %d/%d   P1 %d   %s %d   Draws %d" % [
		arena_number, GameSession.LEVEL_COUNT, GameSession.player_one_wins,
		score_label, second_score, GameSession.draws
	]
	if not round_active:
		hud.text = "%s\n%s" % [score, round_result]
		return
	hud.text = score
	if not _ai_status.is_empty():
		hud.text += "\n" + _ai_status
	for index in range(contestants.size()):
		var contestant := contestants[index]
		var label := "P%d" % contestant.input_slot if contestant.input_slot > 0 else "Enemy %d" % index
		hud.text += "\n" + _tank_status(contestant, label)


func _tank_status(contestant: Contestant, label: String) -> String:
	var status := "%s   Lives %d" % [label, contestant.lives]
	var tank := contestant.tank
	if not is_instance_valid(tank):
		return status + ("   Respawning" if contestant.lives > 0 else "   Eliminated")
	var weapon := "Standard"
	if tank.loadout.weapon != null:
		weapon = "%s (%d)" % [tank.loadout.weapon.display_name, tank.loadout.shots_left]
	return "%s   Hull %d/%d   Shield %d   %s" % [status, tank.health, tank.max_health, tank.shield_points, weapon]
