## localization.gd
## Static string constants for the UI.
## Replace with Godot's built-in TranslationServer when multi-language is needed.
class_name Localization

# Shared
const APP_TITLE := "DRUM MACHINE"

# Menu screen
const MENU_PLAY     := "PLAY"
const MENU_SETTINGS := "SETTINGS"
const MENU_EXIT     := "EXIT"

# Main screen
const TEMPO := "BPM"


static func get_steps_label(steps: int) -> String:
	return "Steps: %d" % steps


static func get_tempo_label(tempo: int) -> String:
	return "%d BPM" % tempo


static func get_row_name(index: int) -> String:
	return DrumTheme.ROW_NAMES[index] if index < DrumTheme.ROW_NAMES.size() else ""
