## Read-only source of available audio samples.
class_name SoundCatalog
extends RefCounted

const SOUNDS_DIR := "res://assets/sounds"
const MANIFEST_PATH := "res://assets/sounds/manifest.json"
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3"]


static func load_catalog() -> Dictionary:
	var manifest := _load_manifest()
	if not manifest.is_empty():
		return _normalized_catalog(manifest)
	return _scan_sounds_dir()


static func _load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func _scan_sounds_dir() -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(SOUNDS_DIR)
	if not dir:
		return result
	var folders: PackedStringArray = []
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("."):
			folders.append(folder)
		folder = dir.get_next()
	dir.list_dir_end()
	folders.sort()

	for category: String in folders:
		var files: PackedStringArray = []
		var sub := DirAccess.open(SOUNDS_DIR.path_join(category))
		if not sub:
			continue
		sub.list_dir_begin()
		var file := sub.get_next()
		while file != "":
			if not sub.current_is_dir() and file.get_extension().to_lower() in AUDIO_EXTENSIONS:
				files.append(SOUNDS_DIR.path_join(category).path_join(file))
			file = sub.get_next()
		sub.list_dir_end()
		files.sort()
		if not files.is_empty():
			result[category] = files
	return result


static func _normalized_catalog(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var categories: Array = source.keys()
	categories.sort()
	for category_value: Variant in categories:
		if not category_value is String or not source[category_value] is Array:
			continue
		var paths: PackedStringArray = []
		for path_value: Variant in source[category_value]:
			if path_value is String and not path_value.is_empty():
				paths.append(path_value)
		paths.sort()
		if not paths.is_empty():
			result[category_value] = paths
	return result
