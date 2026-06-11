class_name SaveManager
extends RefCounted

const SLOT_NAMES: Array[String] = ["A", "B", "C", "D"]

static func slot_path(slot: int) -> String:
	if not is_valid_slot(slot):
		return ""
	return "user://slot_%s.json" % SLOT_NAMES[slot].to_lower()

static func slot_exists(slot: int) -> bool:
	var path := slot_path(slot)
	return not path.is_empty() and FileAccess.file_exists(path)

static func save(slot: int, data: Dictionary) -> Error:
	var path := slot_path(slot)
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	return OK

static func load_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_NAMES.size()
