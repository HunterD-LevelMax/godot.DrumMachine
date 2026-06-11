## Complete, validated snapshot of an editable drum pattern.
class_name PatternState
extends RefCounted

const FORMAT_VERSION := 1
const MIN_ROWS := 1
const MAX_ROWS := 10
const DEFAULT_ROWS := 4
const MIN_STEPS := 4
const MAX_STEPS := 64
const DEFAULT_STEPS := 16
const MIN_TEMPO := 30
const MAX_TEMPO := 300
const DEFAULT_TEMPO := 120
const MIN_VELOCITY := 0
const MAX_VELOCITY := 4

var rows: int = DEFAULT_ROWS
var steps: int = DEFAULT_STEPS
var tempo: int = DEFAULT_TEMPO
var grid: Array = []
var muted: Array[bool] = []
var sounds: Array[String] = []


static func create(
		p_rows: int,
		p_steps: int,
		p_tempo: int,
		p_grid: Array,
		p_muted: Array,
		p_sounds: Array,
		default_sounds: Array[String]
	) -> PatternState:
	return from_dict({
		"version": FORMAT_VERSION,
		"rows": p_rows,
		"steps": p_steps,
		"tempo": p_tempo,
		"grid": p_grid,
		"muted": p_muted,
		"sounds": p_sounds,
	}, default_sounds)


static func from_dict(data: Dictionary, default_sounds: Array[String]) -> PatternState:
	var state := PatternState.new()
	state.rows = clampi(_safe_int(data.get("rows"), DEFAULT_ROWS), MIN_ROWS, MAX_ROWS)
	state.steps = clampi(_safe_int(data.get("steps"), DEFAULT_STEPS), MIN_STEPS, MAX_STEPS)
	state.tempo = clampi(_safe_int(data.get("tempo"), DEFAULT_TEMPO), MIN_TEMPO, MAX_TEMPO)

	var grid_value: Variant = data.get("grid", [])
	var muted_value: Variant = data.get("muted", [])
	var sounds_value: Variant = data.get("sounds", [])
	var source_grid: Array = grid_value if grid_value is Array else []
	var source_muted: Array = muted_value if muted_value is Array else []
	var source_sounds: Array = sounds_value if sounds_value is Array else []

	for row in range(state.rows):
		var row_data: Array[int] = []
		row_data.resize(state.steps)
		row_data.fill(0)
		if row < source_grid.size() and source_grid[row] is Array:
			var source_row: Array = source_grid[row]
			for step in range(mini(state.steps, source_row.size())):
				row_data[step] = clampi(
					_safe_int(source_row[step], MIN_VELOCITY),
					MIN_VELOCITY,
					MAX_VELOCITY
				)
		state.grid.append(row_data)
		state.muted.append(bool(source_muted[row]) if row < source_muted.size() else false)
		state.sounds.append(_sound_for_row(row, source_sounds, default_sounds))
	return state


func duplicate_state() -> PatternState:
	return PatternState.create(rows, steps, tempo, grid, muted, sounds, sounds)


func to_dict() -> Dictionary:
	var grid_copy: Array = []
	for row: Array in grid:
		grid_copy.append(row.duplicate())
	return {
		"version": FORMAT_VERSION,
		"rows": rows,
		"steps": steps,
		"tempo": tempo,
		"grid": grid_copy,
		"muted": Array(muted),
		"sounds": sounds.duplicate(),
	}


static func _safe_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	return fallback


static func _sound_for_row(
		row: int,
		source_sounds: Array,
		default_sounds: Array[String]
	) -> String:
	if row < source_sounds.size() and source_sounds[row] is String:
		var saved_path: String = source_sounds[row]
		if not saved_path.is_empty():
			return saved_path
	if default_sounds.is_empty():
		return ""
	return default_sounds[row % default_sounds.size()]
