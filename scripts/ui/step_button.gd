## A sequencer pad with unified short press, long press, touch, and context input.
class_name StepButton
extends Button

signal short_pressed(row: int, step: int)
signal context_requested(row: int, step: int)

const LONG_PRESS_SECONDS := 0.45

var _row: int
var _step: int
var _long_press_fired: bool = false
var _timer: Timer


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = LONG_PRESS_SECONDS
	_timer.timeout.connect(_on_long_press)
	add_child(_timer)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	gui_input.connect(_on_gui_input)


func setup(row: int, step: int) -> void:
	_row = row
	_step = step


func _on_button_down() -> void:
	_long_press_fired = false
	_timer.start()


func _on_button_up() -> void:
	_timer.stop()
	if not _long_press_fired:
		short_pressed.emit(_row, _step)


func _on_long_press() -> void:
	_long_press_fired = true
	context_requested.emit(_row, _step)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		accept_event()
		_timer.stop()
		_long_press_fired = true
		context_requested.emit(_row, _step)


func cancel_interaction() -> void:
	_timer.stop()
	_long_press_fired = true
