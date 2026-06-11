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

func setup(row: int, current_path: String) -> void:
	var sounds := SoundCatalog.load_catalog()
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
