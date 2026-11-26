class_name ArenaRoundManager extends LevelManager

const THEME_CATALOG := preload("res://gameplay/levels/arena_theme.gd")
const PORTAL := preload("res://gameplay/weapons/portal_pair.gd")
const PETS := preload("res://gameplay/npcs/animal_spawner.gd")
const EVENT_SCRIPT := preload("res://gameplay/levels/arena_event.gd")
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
	var slot: int
	var role: int
	var card: FighterCard
	var input_slot: int
	var lives := 3
	var tank: TankBase
	var previous_spawn := Vector2i(-1, -1)


@export_range(0.1, 10.0) var respawn_delay: float = 1.25
@export_range(0.1, 30.0) var intermission: float = 3.0

var round_active := false
var arena_number := 1
var round_result := ""
var targets: Array[TankBase] = []
var contestants: Array[Contestant] = []
var next_round := Timer.new()
var hud := ArenaHud.new()
var _ai_status := ""
@onready var pause_menu: PauseMenu = $"../WorldCommon/MenuUi"
@onready var pickups: PickupSpawner = get_node_or_null("PickupSpawner") as PickupSpawner


func _ready() -> void:
	next_round.one_shot = true
	add_child(next_round)
	next_round.timeout.connect(_advance)
	arena_number = GameSession.level
	_build_hud()
	var world := get_parent()
	maze_builder = world.get_node(world.maze_path) as MazeBuilder
	if pickups != null:
		pickups.arena = self
		pickups.spawn_interval = maxf(1.5, pickups.spawn_interval - 0.5 * (GameSession.level - 1))
	_configure_mode()
	_begin_round.call_deferred()


func _configure_mode() -> void:
	if maze_builder.footprint in [MazeBuilder.Footprint.GROVE, MazeBuilder.Footprint.KEYHOLE, MazeBuilder.Footprint.FORK]:
		var pets := PETS.new()
		pets.name = "AnimalSpawner"
		pets.maze = maze_builder
		add_child(pets)
	var kind: int = THEME_CATALOG.for_level(GameSession.level).event
	if kind != EVENT_SCRIPT.Kind.NONE:
		var event := EVENT_SCRIPT.new()
		event.setup(maze_builder, tanks, kind, camera)
		add_child(event)


func _build_hud() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	get_parent().hud = hud
	hud._pause = pause_menu.open
	hud.layout_changed.connect(get_parent().set_hud_insets)
	overlay.add_child(hud)


func _return_to_menu() -> void:
	GameSession.return_to_map_editor = not GameSession.custom_tiles.is_empty()
	get_tree().change_scene_to_file(GameSession.MENU)


func available_cells(excluded: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var clearance := maze_builder.grid_size * minf(absf(maze_builder.scale.x), absf(maze_builder.scale.y)) * 0.65
	for y in range(maze_builder.maze_size.y):
		for x in range(maze_builder.maze_size.x):
			var cell := Vector2i(x, y)
			if cell in excluded or not maze_builder.valid_index(x, y):
				continue
			var center := maze_builder.get_cell_position(x, y)
			if tanks.any(func(tank): return is_instance_valid(tank) and tank.global_position.distance_to(center) < clearance):
				continue
			cells.append(cell)
	return cells


func _begin_round() -> void:
	if not is_inside_tree():
		return
	arena_number = GameSession.level
	round_active = true
	var human_slot := 0
	for slot in range(GameSession.roster.size()):
		var role: int = GameSession.roster[slot]
		if role == PlayerRoster.OFF:
			continue
		var contestant := Contestant.new()
		contestant.slot = slot
		contestant.team = slot + 1
		contestant.role = role
		if role == PlayerRoster.HUMAN:
			human_slot += 1
			contestant.input_slot = human_slot
		contestant.card = hud.add_fighter(slot, role)
		contestants.append(contestant)
	# Place AI first so human starts can maximize distance from actual rivals.
	for contestant in contestants:
		if contestant.role != PlayerRoster.HUMAN:
			_spawn_contestant(contestant)
	for contestant in contestants:
		if contestant.role == PlayerRoster.HUMAN:
			_spawn_contestant(contestant)
	if pickups != null:
		pickups.start()


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
	_configure_tank(tank)
	tank.get_node("body").modulate = PlayerRoster.COLORS[contestant.slot]
	var path := maze_builder.maze_astar.get_global_enemy_path(
		tank.global_position, maze_builder.get_cell_position(maze_builder.maze_size.x / 2, maze_builder.maze_size.y / 2))
	if path.size() > 1:
		tank.rotation = (path[1] - path[0]).angle()
	if human:
		var player := tank as TankPlayer
		player.set_input_slot(contestant.input_slot)
		player_tanks.append(player)
		_on_player_spawned(player)

	else:
		targets.append(tank)
		if contestant.role == PlayerRoster.PRACTICE:
			tank.set_physics_process(false)
		else:
			_attach_ai(tank, contestant.role)
	tank.destroyed_signal.connect(_on_destroyed.bind(contestant, tank))


func _configure_tank(tank: TankBase) -> void:
	tank.portal_launcher = launch_portal


func launch_portal(shooter: TankBase, origin: Vector2, direction: Vector2) -> bool:
	if not round_active:
		return false
	var limit := origin + direction * maze_builder.grid_size * 2.5
	var shot := PhysicsRayQueryParameters2D.create(shooter.global_position, limit, 1, [shooter.get_rid()])
	var hit := shooter.get_world_2d().direct_space_state.intersect_ray(shot)
	var impact: Vector2 = limit if hit.is_empty() else hit.position
	var entry := maze_builder.cell_at(impact - direction * 9.0)
	if not maze_builder.valid_index(entry.x, entry.y):
		entry = maze_builder.cell_at(shooter.global_position)
	if not maze_builder.valid_index(entry.x, entry.y):
		return false
	var exits := available_cells([entry])
	if exits.is_empty():
		return false
	var destination: Vector2i = exits.pick_random()
	var gates := PORTAL.new()
	gates.arena = self
	gates.entrance = to_local(maze_builder.get_cell_position(entry.x, entry.y))
	gates.exit = to_local(maze_builder.get_cell_position(destination.x, destination.y))
	gates.muzzle = to_local(origin)
	gates.tracer_end = to_local(impact)
	gates.radius = maze_builder.grid_size * 0.25
	add_child(gates)
	return true


func _choose_spawn(contestant: Contestant, cells: Array[Vector2i]) -> Vector2i:
	var rivals := PackedVector2Array()
	for tank in tanks:
		if is_instance_valid(tank) and not tank.pending_destroy and tank.team != contestant.team:
			rivals.append(tank.global_position)
	var graph := maze_builder.maze_astar
	var distances := graph.distances_from(rivals)
	var best_distance := -1
	var farthest: Array[Vector2i] = []
	var safe: Array[Vector2i] = []
	for cell in cells:
		var distance: int = distances.get(graph.get_cell_id(cell.x, cell.y), -1)
		if distance > best_distance:
			best_distance = distance
			farthest.clear()
		if distance == best_distance:
			farthest.append(cell)
		if distance >= 3 and cell != contestant.previous_spawn:
			safe.append(cell)

	if contestant.role == PlayerRoster.HUMAN:
		return farthest.pick_random()
	if not safe.is_empty():
		return safe.pick_random()
	var alternatives := cells.filter(func(cell: Vector2i): return cell != contestant.previous_spawn)
	return alternatives.pick_random() if not alternatives.is_empty() else cells[0]


func _attach_ai(tank: TankBase, role: int) -> void:
	if GameSession.ai_runtime_available():
		var controller := load(AI_COMPONENT_PATHS[role - 1]) as PackedScene
		if controller != null:
			tank.add_child(controller.instantiate())
			if tank.has_meta("_active_tank_brain"):
				return
	_ai_status = tr("AI_DISABLED")
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
	var survivors := contestants.filter(func(slot: Contestant): return slot.lives > 0)
	if survivors.size() > 1:
		return

	var advance := true
	GameSession.rounds_played += 1
	if survivors.size() == 1:
		var winner: Contestant = survivors[0]
		GameSession.award_win(winner.slot)
		round_result = tr("WINNER") % (winner.slot + 1)
		if GameSession.player_count == 1 and winner.role != PlayerRoster.HUMAN:
			GameSession.losses += 1
			advance = false
	else:
		GameSession.draws += 1
		round_result = tr("DRAW")

	_freeze_round()

	if not GameSession.custom_tiles.is_empty():
		GameSession.completed = true
	elif advance and arena_number == GameSession.LEVEL_COUNT:
		GameSession.completed = true
		round_result += "   ·   " + tr("CAMPAIGN_COMPLETE")
	elif advance:
		GameSession.level = arena_number + 1
		round_result += "   ·   " + tr("NEXT_ARENA")
	else:
		round_result += "   ·   " + tr("RETRY_ARENA")
	if not GameSession.completed:
		GameSession.prepare_map()
	var event := get_node_or_null("ArenaEvent")
	var delay: float = event.flame_seconds() if event != null else 0.0
	next_round.start(maxf(intermission, delay))


func _freeze_round() -> void:
	round_active = false
	var pets := get_node_or_null("AnimalSpawner")
	if pets != null:
		pets.process_mode = Node.PROCESS_MODE_DISABLED
	var event := get_node_or_null("ArenaEvent")
	if event != null:
		event.end_round()
	if pickups != null:
		pickups.process_mode = Node.PROCESS_MODE_DISABLED
	for effect in get_tree().get_nodes_in_group("arena_weapon_effect"):
		effect.process_mode = Node.PROCESS_MODE_DISABLED
	for tank in tanks:
		if is_instance_valid(tank):
			if is_instance_valid(tank.laser_beam):
				tank.laser_beam.queue_free()
			tank.process_mode = Node.PROCESS_MODE_DISABLED


func _advance() -> void:
	if GameSession.completed:
		_return_to_menu()
	else:
		get_tree().change_scene_to_file(GameSession.ARENA)


func _process(_delta: float) -> void:
	var heading := tr("ARENA_STATUS") % [tr(THEME_CATALOG.for_level(arena_number).name), arena_number, GameSession.LEVEL_COUNT]
	if not GameSession.custom_tiles.is_empty():
		heading = tr("MAP_EDITOR_CUSTOM")
	if not round_active and not round_result.is_empty():
		heading += "   ·   " + round_result
	if not _ai_status.is_empty():
		heading += "   ·   " + _ai_status
	hud.show_round(heading)
	for contestant in contestants:
		contestant.card.update_fighter(contestant.tank, contestant.lives, GameSession.wins[contestant.slot])
