## sequencer.gd
## Pure data model for the drum machine.
## Owns the grid, tempo, step counter, and mute flags.
## Contains zero UI code — tested and reused independently of scenes.
class_name Sequencer
extends RefCounted

const ROWS         := 4
const MIN_STEPS    := 4
const MAX_STEPS    := 64
const MIN_TEMPO    := 30
const MAX_TEMPO    := 300
const DEFAULT_STEPS := 16
const DEFAULT_TEMPO := 120

# Probability that each row fires on a random step (kick, snare, hat, bass)
const RANDOMIZE_PROBS: Array[float] = [0.35, 0.22, 0.50, 0.18]

const DEFAULT_SOUNDS: Array[String] = [
	"res://assets/sounds/kick/kick_syth.wav",
	"res://assets/sounds/snare/snare.wav",
	"res://assets/sounds/hat/hat.wav",
	"res://assets/sounds/bass/bass.ogg",
]

# grid[row][step] = int 0–4  (0 = off, 1–4 = velocity)
var grid:        Array        = []
var muted:       Array[bool]  = [false, false, false, false]
var sound_paths: Array[String] = []
var tempo: int  = DEFAULT_TEMPO
var steps: int  = DEFAULT_STEPS

var current_step: int  = 0
var is_playing:   bool = true


func _init() -> void:
	sound_paths = DEFAULT_SOUNDS.duplicate()
	_rebuild_grid()


# ── Grid ──────────────────────────────────────────────────────────────────────

func _rebuild_grid() -> void:
	grid.clear()
	for _i in range(ROWS):
		var row: Array[int] = []
		row.resize(steps)
		row.fill(0)
		grid.append(row)


## Resize the step count, preserving existing note data up to the new length.
func resize_steps(new_steps: int) -> void:
	var snapshot := get_grid_snapshot()
	steps = clampi(new_steps, MIN_STEPS, MAX_STEPS)
	_rebuild_grid()
	for row in range(ROWS):
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
func current_step_velocities() -> Array[int]:
	var result: Array[int] = []
	for row in range(ROWS):
		result.append(grid[row][current_step] if not muted[row] else 0)
	return result


func advance() -> void:
	current_step = (current_step + 1) % steps


# ── Snapshot helpers (for undo/save) ─────────────────────────────────────────

func get_grid_snapshot() -> Array:
	var copy: Array = []
	for row in range(ROWS):
		copy.append(grid[row].duplicate())
	return copy


func apply_grid_snapshot(snapshot: Array) -> void:
	for row in range(ROWS):
		if row >= snapshot.size():
			break
		for step in range(steps):
			grid[row][step] = int(snapshot[row][step]) if step < snapshot[row].size() else 0


# ── Pattern operations ────────────────────────────────────────────────────────

func clear() -> void:
	for row in range(ROWS):
		grid[row].fill(0)


func randomize() -> void:
	for row in range(ROWS):
		for step in range(steps):
			grid[row][step] = randi_range(2, 4) if randf() < RANDOMIZE_PROBS[row] else 0


# ── Tempo ─────────────────────────────────────────────────────────────────────

## Returns the timer interval (seconds per 8th-note step at current BPM).
func timer_interval() -> float:
	return 60.0 / float(tempo) / 2.0


# ── Serialisation ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"tempo":  tempo,
		"steps":  steps,
		"muted":  Array(muted),
		"grid":   get_grid_snapshot(),
		"sounds": sound_paths.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	tempo = int(data.get("tempo", DEFAULT_TEMPO))
	steps = clampi(int(data.get("steps", DEFAULT_STEPS)), MIN_STEPS, MAX_STEPS)
	var saved_muted: Array = data.get("muted", [])
	for i in range(ROWS):
		muted[i] = bool(saved_muted[i]) if i < saved_muted.size() else false
	var saved_sounds: Array = data.get("sounds", [])
	for i in range(ROWS):
		sound_paths[i] = saved_sounds[i] if i < saved_sounds.size() else DEFAULT_SOUNDS[i]
	_rebuild_grid()
	apply_grid_snapshot(data.get("grid", []))
	current_step = 0
