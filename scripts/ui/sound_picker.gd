## sound_picker.gd
## Floating popup for selecting a track's audio sample.
## Structure defined in scenes/ui/sound_picker.tscn.
## List rows are scenes/ui/sound_entry.tscn and scenes/ui/sound_category.tscn instances.
## Emits sound_selected(row, path) when the user picks an entry.
class_name SoundPicker
extends PanelContainer

signal sound_selected(row: int, path: String)

const SOUND_ENTRY_SCENE    := preload("res://scenes/ui/sound_entry.tscn")
const SOUND_CATEGORY_SCENE := preload("res://scenes/ui/sound_category.tscn")

const SOUNDS_DIR := "res://assets/sounds"
const MANIFEST_PATH := "res://assets/sounds/manifest.json"
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3"]


func setup(row: int, current_path: String) -> void:
	var sounds := _discover_sounds()
	var list: VBoxContainer = %SoundList
	for category: String in sounds.keys():
		var cat: SoundCategory = SOUND_CATEGORY_SCENE.instantiate()
		list.add_child(cat)
		cat.setup(category)
		for path: String in sounds[category]:
			var entry: SoundEntry = SOUND_ENTRY_SCENE.instantiate()
			list.add_child(entry)
			entry.setup(path, path == current_path)
			entry.entry_pressed.connect(func(p: String) -> void: sound_selected.emit(row, p))
	DrumTheme.style_scrollbar(list.get_parent() as ScrollContainer)


func position_near(anchor_rect: Rect2, viewport_size: Vector2) -> void:
	var w := 448.0
	var h := 544.0
	custom_minimum_size = Vector2(w, h)
	var px := anchor_rect.position.x
	var py := anchor_rect.end.y + 6.0
	if py + h > viewport_size.y:
		py = anchor_rect.position.y - h - 6.0
	px = clampf(px, 4.0, viewport_size.x - w - 4.0)
	py = clampf(py, 4.0, viewport_size.y - h - 4.0)
	position = Vector2(px, py)


static func _discover_sounds() -> Dictionary:
	var result := _scan_sounds_dir()
	if not result.is_empty():
		_save_manifest(result)
	else:
		result = _load_manifest()
	return result


static func _scan_sounds_dir() -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(SOUNDS_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("."):
			var files: PackedStringArray = []
			var sub := DirAccess.open(SOUNDS_DIR.path_join(folder))
			if sub:
				sub.list_dir_begin()
				var file := sub.get_next()
				while file != "":
					if not sub.current_is_dir():
						var ext := file.get_extension().to_lower()
						if ext in AUDIO_EXTENSIONS:
							files.append(SOUNDS_DIR.path_join(folder).path_join(file))
					file = sub.get_next()
				sub.list_dir_end()
			if files.size() > 0:
				result[folder] = files
		folder = dir.get_next()
	dir.list_dir_end()
	return result


static func _load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func _save_manifest(sounds: Dictionary) -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(sounds, "\t"))
	file.close()
