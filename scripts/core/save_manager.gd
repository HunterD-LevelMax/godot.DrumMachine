class_name SaveManager
extends RefCounted

const SLOT_NAMES := ["A", "B", "C", "D"]

static func slot_path(slot: int) -> String:
	return "user://slot_%s.json" % SLOT_NAMES[slot].to_lower()

static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

static func save(slot: int, data: Dictionary) -> void:
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

# Returns empty Dictionary on failure.
static func load_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
