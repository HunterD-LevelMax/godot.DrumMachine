## sequencer.gd
## Pure data model for the drum machine.
## Owns the grid, tempo, step counter, and mute flags.
## Contains zero UI code — tested and reused independently of scenes.
class_name Sequencer
extends RefCounted

signal tempo_changed(value: int)
signal structure_changed
signal row_changed(row: int)
signal pattern_changed

const MIN_ROWS := PatternState.MIN_ROWS
const MAX_ROWS := PatternState.MAX_ROWS
const DEFAULT_ROWS := PatternState.DEFAULT_ROWS
const MIN_STEPS := PatternState.MIN_STEPS
const MAX_STEPS := PatternState.MAX_STEPS
const MIN_TEMPO := PatternState.MIN_TEMPO
const MAX_TEMPO := PatternState.MAX_TEMPO
const DEFAULT_STEPS := PatternState.DEFAULT_STEPS
const DEFAULT_TEMPO := PatternState.DEFAULT_TEMPO
const MIN_VELOCITY := PatternState.MIN_VELOCITY
const MAX_VELOCITY := PatternState.MAX_VELOCITY

const RANDOMIZE_PROBS_DEFAULT: float = 0.30

const DEFAULT_SOUNDS: Array[String] = [
	"res://assets/sounds/kick/kick_syth.wav",
	"res://assets/sounds/snare/snare.wav",
	"res://assets/sounds/hat/hat.wav",
	"res://assets/sounds/bass/bass.ogg",
]

# grid[row][step] = int 0–4  (0 = off, 1–4 = velocity)
var grid:        Array        = []
var muted:       Array[bool]  = []
var sound_paths: Array[String] = []
var rows: int    = DEFAULT_ROWS
var tempo: int   = DEFAULT_TEMPO
var steps: int   = DEFAULT_STEPS

var current_step: int  = 0
var is_playing:   bool = true

var _velocities_cache: Array[int] = []


func _init() -> void:
	_init_defaults()
	_rebuild_grid()


func _init_defaults() -> void:
	sound_paths.clear()
	muted.clear()
	for i in range(DEFAULT_ROWS):
		sound_paths.append(DEFAULT_SOUNDS[i] if i < DEFAULT_SOUNDS.size() else DEFAULT_SOUNDS[0])
		muted.append(false)
	rows = DEFAULT_ROWS


# ── Rows ──────────────────────────────────────────────────────────────────────

func add_row(sound_path: String = "") -> bool:
	if rows >= MAX_ROWS:
		return false
	var path := sound_path if not sound_path.is_empty() else _default_sound_for_row(rows)
	sound_paths.append(path)
	muted.append(false)
	var new_row: Array[int] = []
	new_row.resize(steps)
	new_row.fill(0)
	grid.append(new_row)
	rows += 1
	structure_changed.emit()
	return true


func remove_row(index: int) -> bool:
	if rows <= MIN_ROWS or index < 0 or index >= rows:
		return false
	sound_paths.remove_at(index)
	muted.remove_at(index)
	grid.remove_at(index)
	rows -= 1
	structure_changed.emit()
	return true


func _default_sound_for_row(index: int) -> String:
	return DEFAULT_SOUNDS[index % DEFAULT_SOUNDS.size()]


# ── Grid ──────────────────────────────────────────────────────────────────────

func _rebuild_grid() -> void:
	grid.clear()
	for _i in range(rows):
		var row: Array[int] = []
		row.resize(steps)
		row.fill(0)
		grid.append(row)


## Resize the step count, preserving existing note data up to the new length.
func resize_steps(new_steps: int) -> void:
	var snapshot := get_grid_snapshot()
	steps = clampi(new_steps, MIN_STEPS, MAX_STEPS)
	_rebuild_grid()
	for row in range(rows):
		for step in range(mini(steps, snapshot[row].size())):
			grid[row][step] = snapshot[row][step]
	current_step = 0
	structure_changed.emit()


func set_velocity(row: int, step: int, velocity: int) -> void:
	if not _is_valid_cell(row, step):
		return
	grid[row][step] = clampi(velocity, MIN_VELOCITY, MAX_VELOCITY)
	row_changed.emit(row)
	pattern_changed.emit()


## Cycle velocity 0→4→3→2→1→0. Returns the new velocity.
func cycle_velocity(row: int, step: int) -> int:
	if not _is_valid_cell(row, step):
		return MIN_VELOCITY
	var v: int = grid[row][step]
	v = 4 if v == 0 else v - 1
	grid[row][step] = v
	row_changed.emit(row)
	pattern_changed.emit()
	return v


## Returns velocity for each row at the current step, honouring mute flags.
## Reuses a pre-allocated array to avoid per-tick allocation.
func current_step_velocities() -> Array[int]:
	_velocities_cache.resize(rows)
	for row in range(rows):
		_velocities_cache[row] = grid[row][current_step] if not muted[row] else 0
	return _velocities_cache


func advance() -> void:
	current_step = (current_step + 1) % steps


# ── Snapshot helpers (for undo/save) ─────────────────────────────────────────

func get_grid_snapshot() -> Array:
	var copy: Array = []
	for row in range(rows):
		copy.append(grid[row].duplicate())
	return copy


func apply_grid_snapshot(snapshot: Array) -> void:
	for row in range(rows):
		if row >= snapshot.size():
			break
		for step in range(steps):
			grid[row][step] = int(snapshot[row][step]) if step < snapshot[row].size() else 0
	pattern_changed.emit()


# ── Pattern operations ────────────────────────────────────────────────────────

func clear() -> void:
	for row in range(rows):
		grid[row].fill(0)
	pattern_changed.emit()


func randomize() -> void:
	for row in range(rows):
		for step in range(steps):
			grid[row][step] = randi_range(2, 4) if randf() < RANDOMIZE_PROBS_DEFAULT else 0
	pattern_changed.emit()


# ── Tempo ─────────────────────────────────────────────────────────────────────

## Returns the timer interval (seconds per 8th-note step at current BPM).
func timer_interval() -> float:
	return 60.0 / float(tempo) / 2.0


func set_tempo(value: int) -> void:
	var next_tempo := clampi(value, MIN_TEMPO, MAX_TEMPO)
	if next_tempo == tempo:
		return
	tempo = next_tempo
	tempo_changed.emit(tempo)


func change_tempo(delta: int) -> void:
	set_tempo(tempo + delta)


func set_muted(row: int, value: bool) -> void:
	if row < 0 or row >= rows or muted[row] == value:
		return
	muted[row] = value
	row_changed.emit(row)
	pattern_changed.emit()


func set_sound(row: int, path: String) -> void:
	if row < 0 or row >= rows or path.is_empty() or sound_paths[row] == path:
		return
	sound_paths[row] = path
	row_changed.emit(row)
	pattern_changed.emit()


# ── Serialisation ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return create_snapshot().to_dict()


func from_dict(data: Dictionary) -> void:
	restore_snapshot(PatternState.from_dict(data, DEFAULT_SOUNDS))


func create_snapshot() -> PatternState:
	return PatternState.create(rows, steps, tempo, grid, muted, sound_paths, DEFAULT_SOUNDS)


func restore_snapshot(state: PatternState) -> void:
	var safe_state := PatternState.from_dict(state.to_dict(), DEFAULT_SOUNDS)
	rows = safe_state.rows
	steps = safe_state.steps
	tempo = safe_state.tempo
	grid = safe_state.grid
	muted = safe_state.muted
	sound_paths = safe_state.sounds
	current_step = 0
	structure_changed.emit()
	tempo_changed.emit(tempo)
	pattern_changed.emit()


func _is_valid_cell(row: int, step: int) -> bool:
	return row >= 0 and row < rows and step >= 0 and step < steps
