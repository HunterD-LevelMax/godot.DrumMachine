## sound_entry.gd
## A single selectable sound button inside SoundPicker's list.
## Styles defined in scenes/ui/sound_entry.tscn.
class_name SoundEntry
extends Button

signal entry_pressed(path: String)

## Applied when this entry matches the currently active sound.
## Set via tscn inspector (sub_resource se_a).
@export var active_style: StyleBoxFlat


func setup(path: String, is_active: bool) -> void:
	text       = path.get_file().get_basename().replace("_", " ")
	focus_mode = Control.FOCUS_NONE
	if is_active and active_style:
		add_theme_stylebox_override("normal",  active_style)
		add_theme_stylebox_override("pressed", active_style)
		add_theme_color_override("font_color", Color(0, 0.83, 1, 1))
	pressed.connect(func() -> void: entry_pressed.emit(path))
