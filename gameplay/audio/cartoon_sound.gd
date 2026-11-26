extends Node

@onready var confirm: AudioStream = load("res://UI/Art/Sound/menu-bing.mp3")
@onready var pause: AudioStream = load("res://UI/Art/Sound/pause-bing.mp3")
@onready var pickup: AudioStream = load("res://UI/Art/Sound/pickup-boing.mp3")
@onready var pop: AudioStream = load("res://UI/Art/Sound/balloon-pop.ogg")

var _menu_player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_player.volume_db = -16.0
	add_child(_menu_player)


func play_confirm() -> void:
	_play_menu(confirm)


func play_pause() -> void:
	_play_menu(pause)


func _play_menu(cue: AudioStream) -> void:
	_menu_player.stream = cue
	_menu_player.play()


func play_at(cue: AudioStream, location: Vector2, volume: float, pitch := 1.0) -> void:
	var world := get_tree().current_scene as Node2D
	if world == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = cue
	player.volume_db = volume
	player.pitch_scale = pitch
	player.position = world.to_local(location)
	player.finished.connect(player.queue_free)
	world.add_child(player)
	player.play()
