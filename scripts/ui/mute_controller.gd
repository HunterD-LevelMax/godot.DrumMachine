## mute_controller.gd
## Handles mute toggle and label long-press to mute.
class_name MuteController
extends RefCounted

var _seq: Sequencer
var _row_labels:    Array = []
var _row_mute_btns: Array = []
var _row_snd_btns:  Array = []
var _label_mute_timer: Timer = null
var _label_mute_row: int = -1
var _owner: Node
var on_sound_pick: Callable


func setup(owner: Node, seq: Sequencer) -> void:
	_owner = owner
	_seq   = seq


func set_row_refs(labels: Array, mute_btns: Array, snd_btns: Array, p_on_sound_pick: Callable) -> void:
	_row_labels    = labels
	_row_mute_btns = mute_btns
	_row_snd_btns  = snd_btns
	on_sound_pick  = p_on_sound_pick


func on_label_input(event: InputEvent, row: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_start_label_mute_timer(row)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_mute(row)
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_cancel_label_mute_timer()
	elif event is InputEventScreenTouch and event.pressed:
		_start_label_mute_timer(row)
	elif event is InputEventScreenTouch and not event.pressed:
		_cancel_label_mute_timer()


func _toggle_mute(row: int) -> void:
	if row < 0 or row >= _seq.rows:
		return
	var btn: Button = _row_mute_btns[row] as Button
	btn.button_pressed = not btn.button_pressed


func _start_label_mute_timer(row: int) -> void:
	_cancel_label_mute_timer()
	_label_mute_row = row
	_label_mute_timer = Timer.new()
	_label_mute_timer.one_shot = true
	_label_mute_timer.wait_time = 0.5
	_label_mute_timer.timeout.connect(_on_label_mute_timeout)
	_owner.add_child(_label_mute_timer)
	_label_mute_timer.start()


func _cancel_label_mute_timer() -> void:
	if _label_mute_timer != null and _label_mute_timer.is_inside_tree():
		_label_mute_timer.stop()
		_label_mute_timer.queue_free()
		_label_mute_timer = null
	_label_mute_row = -1


func _on_label_mute_timeout() -> void:
	if _label_mute_row >= 0 and _label_mute_row < _seq.rows:
		(_row_mute_btns[_label_mute_row] as Button).button_pressed = not _seq.muted[_label_mute_row]
	_label_mute_row = -1
	_cancel_label_mute_timer()


func on_mute_toggled(pressed: bool, row: int) -> void:
	_seq.muted[row] = pressed
	var lbl: Button = _row_labels[row]
	var target_color := Color(0.4, 0.4, 0.4) if pressed else Color(1, 1, 1)
	var tween := lbl.create_tween()
	tween.tween_property(lbl, "modulate", target_color, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var mute_style := DrumTheme.mute_style(pressed, row)
	(_row_mute_btns[row] as Button).add_theme_stylebox_override("normal", mute_style)
	(_row_mute_btns[row] as Button).add_theme_stylebox_override("pressed", mute_style)
	(_row_mute_btns[row] as Button).add_theme_stylebox_override("hover", mute_style)
