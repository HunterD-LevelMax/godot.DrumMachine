## tap_tempo.gd
## Calculates BPM from tap rhythm.
class_name TapTempo
extends RefCounted

const MAX_TAP_COUNT := 8
const RESET_DELAY   := 3.0

var _seq:   Sequencer
var _timer: Timer
var _tap_times: Array[float] = []


func setup(seq: Sequencer, timer: Timer) -> void:
	_seq   = seq
	_timer = timer


func on_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _tap_times.is_empty() and (now - _tap_times[-1]) > RESET_DELAY:
		_tap_times.clear()
	_tap_times.append(now)
	if _tap_times.size() > MAX_TAP_COUNT:
		_tap_times.remove_at(0)
	if _tap_times.size() >= 2:
		var total := 0.0
		for i in range(1, _tap_times.size()):
			total += _tap_times[i] - _tap_times[i - 1]
		_seq.tempo = clampi(
			int(round(60.0 / (total / (_tap_times.size() - 1)))),
			Sequencer.MIN_TEMPO, Sequencer.MAX_TEMPO
		)
		_timer.wait_time = _seq.timer_interval()
