## sequencer.gd
## Pure data model for the drum machine.
## Owns the grid, tempo, step counter, and mute flags.
## Contains zero UI code — tested and reused independently of scenes.
class_name Sequencer
extends RefCounted

const MIN_ROWS     := 1
const MAX_ROWS     := 10
const DEFAULT_ROWS := 4
const MIN_STEPS    := 4
const MAX_STEPS    := 64
const MIN_TEMPO    := 30
const MAX_TEMPO    := 300
const DEFAULT_STEPS := 16
const DEFAULT_TEMPO := 120

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
	return true


func remove_row(index: int) -> bool:
	if rows <= MIN_ROWS or index < 0 or index >= rows:
		return false
	sound_paths.remove_at(index)
	muted.remove_at(index)
	grid.remove_at(index)
	rows -= 1
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


func set_velocity(row: int, step: int, velocity: int) -> void:
	grid[row][step] = velocity


## Cycle velocity 0→4→3→2→1→0. Returns the new velocity.
func cycle_velocity(row: int, step: int) -> int:
	var v: int = grid[row][step]
	v = 4 if v == 0 else v - 1
	grid[row][step] = v
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


# ── Pattern operations ────────────────────────────────────────────────────────

func clear() -> void:
	for row in range(rows):
		grid[row].fill(0)


func randomize() -> void:
	for row in range(rows):
		for step in range(steps):
			grid[row][step] = randi_range(2, 4) if randf() < RANDOMIZE_PROBS_DEFAULT else 0


# ── Tempo ─────────────────────────────────────────────────────────────────────

## Returns the timer interval (seconds per 8th-note step at current BPM).
func timer_interval() -> float:
	return 60.0 / float(tempo) / 2.0


# ── Serialisation ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"rows":   rows,
		"tempo":  tempo,
		"steps":  steps,
		"muted":  Array(muted),
		"grid":   get_grid_snapshot(),
		"sounds": sound_paths.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	var saved_rows: int = int(data.get("rows", DEFAULT_ROWS))
	saved_rows = clampi(saved_rows, MIN_ROWS, MAX_ROWS)
	tempo = int(data.get("tempo", DEFAULT_TEMPO))
	steps = clampi(int(data.get("steps", DEFAULT_STEPS)), MIN_STEPS, MAX_STEPS)
	# Build rows from saved data
	sound_paths.clear()
	muted.clear()
	grid.clear()
	var saved_sounds: Array = data.get("sounds", [])
	var saved_muted: Array = data.get("muted", [])
	var saved_grid: Array = data.get("grid", [])
	for i in range(saved_rows):
		sound_paths.append(saved_sounds[i] if i < saved_sounds.size() else _default_sound_for_row(i))
		muted.append(bool(saved_muted[i]) if i < saved_muted.size() else false)
		var row_data: Array[int] = []
		row_data.resize(steps)
		row_data.fill(0)
		if i < saved_grid.size():
			for step in range(mini(steps, saved_grid[i].size())):
				row_data[step] = int(saved_grid[i][step])
		grid.append(row_data)
	rows = saved_rows
	current_step = 0
