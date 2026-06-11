extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_test_sequencer_defaults()
	_test_velocity_and_resize()
	_test_rows()
	_test_serialization_validation()
	_test_complete_history()
	if _failures == 0:
		print("PASS: %d checks" % _checks)
	else:
		push_error("FAIL: %d of %d checks failed" % [_failures, _checks])
	quit(_failures)


func _test_sequencer_defaults() -> void:
	var seq := Sequencer.new()
	_expect_equal(seq.rows, Sequencer.DEFAULT_ROWS, "default rows")
	_expect_equal(seq.steps, Sequencer.DEFAULT_STEPS, "default steps")
	_expect_equal(seq.tempo, Sequencer.DEFAULT_TEMPO, "default tempo")
	_expect_equal(seq.grid.size(), seq.rows, "grid row count")


func _test_velocity_and_resize() -> void:
	var seq := Sequencer.new()
	seq.set_velocity(0, 0, 99)
	_expect_equal(seq.grid[0][0], Sequencer.MAX_VELOCITY, "velocity is clamped")
	seq.set_velocity(0, 15, 3)
	seq.resize_steps(20)
	_expect_equal(seq.grid[0][15], 3, "resize preserves notes")
	_expect_equal(seq.grid[0][19], 0, "resize initializes new notes")
	seq.clear()
	_expect_equal(seq.grid[0][15], 0, "clear removes notes")


func _test_rows() -> void:
	var seq := Sequencer.new()
	var initial_rows := seq.rows
	_expect_true(seq.add_row(), "row can be added")
	_expect_equal(seq.rows, initial_rows + 1, "row count increases")
	_expect_true(seq.remove_row(seq.rows - 1), "row can be removed")
	_expect_equal(seq.rows, initial_rows, "row count decreases")


func _test_serialization_validation() -> void:
	var seq := Sequencer.new()
	seq.from_dict({
		"version": 999,
		"rows": 999,
		"steps": -10,
		"tempo": 9999,
		"grid": [[-2, 88], "broken"],
		"muted": [true],
		"sounds": [42],
	})
	_expect_equal(seq.rows, Sequencer.MAX_ROWS, "loaded rows are clamped")
	_expect_equal(seq.steps, Sequencer.MIN_STEPS, "loaded steps are clamped")
	_expect_equal(seq.tempo, Sequencer.MAX_TEMPO, "loaded tempo is clamped")
	_expect_equal(seq.grid[0][0], Sequencer.MIN_VELOCITY, "low velocity is clamped")
	_expect_equal(seq.grid[0][1], Sequencer.MAX_VELOCITY, "high velocity is clamped")
	_expect_equal(seq.grid[1][0], 0, "invalid grid row is replaced")
	_expect_true(not seq.sound_paths[0].is_empty(), "invalid sound gets a default")


func _test_complete_history() -> void:
	var seq := Sequencer.new()
	var history := PatternHistory.new()
	history.push(seq.create_snapshot())
	seq.resize_steps(32)
	seq.add_row()
	seq.set_tempo(200)
	seq.set_muted(0, true)
	seq.set_sound(0, "res://custom.wav")

	var restored := history.undo(seq.create_snapshot())
	seq.restore_snapshot(restored)
	_expect_equal(seq.steps, Sequencer.DEFAULT_STEPS, "undo restores steps")
	_expect_equal(seq.rows, Sequencer.DEFAULT_ROWS, "undo restores rows")
	_expect_equal(seq.tempo, Sequencer.DEFAULT_TEMPO, "undo restores tempo")
	_expect_equal(seq.muted[0], false, "undo restores mute")
	_expect_equal(seq.sound_paths[0], Sequencer.DEFAULT_SOUNDS[0], "undo restores sounds")

	var redone := history.redo(seq.create_snapshot())
	seq.restore_snapshot(redone)
	_expect_equal(seq.steps, 32, "redo restores steps")
	_expect_equal(seq.rows, Sequencer.DEFAULT_ROWS + 1, "redo restores rows")
	_expect_equal(seq.tempo, 200, "redo restores tempo")
	_expect_equal(seq.muted[0], true, "redo restores mute")


func _expect_true(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error("Expected true: %s" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		push_error("%s: expected %s, got %s" % [label, expected, actual])
