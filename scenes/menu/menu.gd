extends Control

func _ready() -> void:
	%PlayButton.pressed.connect(_on_play_pressed)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%ExitButton.pressed.connect(_on_exit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
