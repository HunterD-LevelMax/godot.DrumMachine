## settings.gd
## Settings screen controller.
extends Control

@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_label:  Label   = %VolumeLabel
@onready var _back_button:   Button  = %BackButton

func _ready() -> void:
	_volume_slider.min_value = GameSettings.MIN_VOLUME_DB
	_volume_slider.max_value = GameSettings.MAX_VOLUME_DB
	_volume_slider.value     = GameSettings.master_volume_db
	_volume_slider.value_changed.connect(_on_volume_changed)
	_back_button.pressed.connect(_on_back_pressed)
	_refresh_volume_label()

func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume_db = value
	_refresh_volume_label()

func _refresh_volume_label() -> void:
	var db  := GameSettings.master_volume_db
	var icon := "🔇" if db <= -35.0 else ("🔉" if db <= -15.0 else "🔊")
	_volume_label.text = "%s Volume: %d dB" % [icon, int(db)]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
