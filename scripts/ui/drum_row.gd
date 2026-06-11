## Self-contained view for one track's controls.
class_name DrumRow
extends HBoxContainer

signal mute_requested(row: int, muted: bool)
signal sound_requested(row: int, anchor: Button)
signal delete_requested(row: int)

const LONG_PRESS_SECONDS := 0.5

@onready var _mute_button: Button = %MuteButton
@onready var _name_button: Button = %NameButton
@onready var _sound_button: Button = %SoundButton
@onready var _delete_button: Button = %DeleteButton
@onready var _long_press_timer: Timer = %LongPressTimer

var _row: int
var _muted: bool
var _updating: bool = false


func _ready() -> void:
	_mute_button.toggled.connect(_on_mute_toggled)
	_name_button.gui_input.connect(_on_name_input)
	_sound_button.pressed.connect(func() -> void:
		sound_requested.emit(_row, _sound_button)
	)
	_delete_button.pressed.connect(func() -> void:
		delete_requested.emit(_row)
	)
	_long_press_timer.wait_time = LONG_PRESS_SECONDS
	_long_press_timer.timeout.connect(_toggle_mute)


func setup(row: int, muted: bool, sound_path: String, can_delete: bool) -> void:
	_row = row
	_name_button.text = DrumTheme.row_name(row)
	_name_button.add_theme_color_override("font_color", DrumTheme.row_color(row))
	_delete_button.visible = can_delete
	set_sound_path(sound_path)
	set_muted(muted, false)


func set_muted(value: bool, animate: bool = true) -> void:
	_muted = value
	_updating = true
	_mute_button.button_pressed = value
	_updating = false
	var target_color := Color(0.4, 0.4, 0.4) if value else Color.WHITE
	if animate:
		var tween := _name_button.create_tween()
		tween.tween_property(_name_button, "modulate", target_color, 0.15) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_name_button.modulate = target_color
	var style := DrumTheme.mute_style(value, _row)
	_mute_button.add_theme_stylebox_override("normal", style)
	_mute_button.add_theme_stylebox_override("pressed", style)
	_mute_button.add_theme_stylebox_override("hover", style)


func set_sound_path(path: String) -> void:
	_sound_button.tooltip_text = path.get_file().get_basename().replace("_", " ")


func get_name_button() -> Button:
	return _name_button


func _on_mute_toggled(value: bool) -> void:
	if _updating:
		return
	_muted = value
	set_muted(value)
	mute_requested.emit(_row, value)


func _on_name_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_name_button.accept_event()
			_toggle_mute()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_long_press_timer.start()
			else:
				_long_press_timer.stop()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_long_press_timer.start()
		else:
			_long_press_timer.stop()


func _toggle_mute() -> void:
	_long_press_timer.stop()
	_mute_button.button_pressed = not _muted
