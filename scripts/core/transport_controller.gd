## Owns playback timing and transport state without depending on the UI.
class_name TransportController
extends RefCounted

signal step_triggered(step: int, velocities: Array[int])
signal playing_changed(is_playing: bool)
signal tempo_changed(tempo: int)

var _seq: Sequencer
var _timer: Timer
var _tap_tempo: TapTempo


func setup(seq: Sequencer, timer: Timer) -> void:
	_seq = seq
	_timer = timer
	_tap_tempo = TapTempo.new()
	_tap_tempo.setup(_seq, _timer)
	_timer.wait_time = _seq.timer_interval()
	_timer.timeout.connect(_on_timer_timeout)


func start() -> void:
	set_playing(true)


func toggle_playing() -> void:
	set_playing(not _seq.is_playing)


func set_playing(value: bool) -> void:
	var timer_matches := not _timer.is_stopped() if value else _timer.is_stopped()
	if _seq.is_playing == value and timer_matches:
		return
	_seq.is_playing = value
	if value:
		reset_position()
		_timer.start()
	else:
		_timer.stop()
	playing_changed.emit(value)


func pause_for_change() -> bool:
	var was_playing := _seq.is_playing
	if was_playing:
		_seq.is_playing = false
		_timer.stop()
	return was_playing


func resume_after_change(was_playing: bool) -> void:
	_timer.wait_time = _seq.timer_interval()
	if was_playing:
		_seq.is_playing = true
		reset_position()
		_timer.start()
	playing_changed.emit(_seq.is_playing)


func change_tempo(delta: int) -> void:
	_seq.change_tempo(delta)
	_timer.wait_time = _seq.timer_interval()
	tempo_changed.emit(_seq.tempo)


func tap_tempo() -> void:
	_tap_tempo.on_tap()
	tempo_changed.emit(_seq.tempo)


func reset_position() -> void:
	_seq.current_step = 0


func _on_timer_timeout() -> void:
	if not _seq.is_playing:
		return
	var step := _seq.current_step
	step_triggered.emit(step, _seq.current_step_velocities())
	_seq.advance()
