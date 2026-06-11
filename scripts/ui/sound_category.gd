## sound_category.gd
## Category header label inside SoundPicker's list.
## Style defined in scenes/ui/sound_category.tscn.
class_name SoundCategory
extends Label


func setup(category: String) -> void:
	text = category.capitalize()
