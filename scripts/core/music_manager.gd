class_name MusicManager
extends RefCounted

# Velocity level 0 is unused (off). Levels 1-4 are dB offsets from master.
const VELOCITY_DB: Array[float] = [0.0, -9.0, -6.0, -3.0, 0.0]

var _players: Array
var _master_volume_db: float = 0.0

func setup(players: Array) -> void:
	_players = players

func set_master_volume(volume_db: float) -> void:
	_master_volume_db = volume_db

func set_stream(row: int, path: String) -> void:
	var stream = load(path)
	if stream and _players[row]:
		_players[row].stream = stream


func play_row(row: int, velocity: int) -> void:
	_players[row].volume_db = _master_volume_db + VELOCITY_DB[velocity]
	_players[row].play()
