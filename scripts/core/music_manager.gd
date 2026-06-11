class_name MusicManager
extends RefCounted

# Velocity level 0 is unused (off). Levels 1-4 are dB offsets from master.
const VELOCITY_DB: Array[float] = [0.0, -9.0, -6.0, -3.0, 0.0]
const MAX_PLAYERS := 10

var _players: Array[AudioStreamPlayer] = []
var _master_volume_db: float = 0.0
var _parent: Node = null
var _stream_cache: Dictionary = {}


func setup(parent: Node) -> void:
	_parent = parent
	_ensure_player_count(Sequencer.DEFAULT_ROWS)


func _ensure_player_count(count: int) -> void:
	while _players.size() < count:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		_parent.add_child(player)
		_players.append(player)


func set_player_count(count: int) -> void:
	_ensure_player_count(count)


func set_master_volume(volume_db: float) -> void:
	_master_volume_db = volume_db


func set_stream(row: int, path: String) -> void:
	if row < 0 or row >= _players.size() or path.is_empty():
		return
	if not _stream_cache.has(path):
		_stream_cache[path] = load(path)
	var stream: AudioStream = _stream_cache[path]
	if stream == null:
		push_warning("Could not load audio stream: %s" % path)
		return
	_players[row].stream = stream


func play_row(row: int, velocity: int) -> void:
	if row < 0 or row >= _players.size():
		return
	if velocity < PatternState.MIN_VELOCITY or velocity > PatternState.MAX_VELOCITY:
		return
	if _players[row].stream == null:
		return
	_players[row].volume_db = _master_volume_db + VELOCITY_DB[velocity]
	_players[row].play()
