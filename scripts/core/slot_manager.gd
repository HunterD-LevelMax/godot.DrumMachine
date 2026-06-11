## slot_manager.gd
## Manages save/load slots, slot button UI, and save/load flow.
class_name SlotManager
extends RefCounted

signal pattern_loaded(state: PatternState)
signal operation_failed(message: String)

var _seq: Sequencer
var _popups: PopupManager

var _active_slot: int = 0
var _slot_buttons: Array[Button] = []


func setup(seq: Sequencer, popups: PopupManager) -> void:
	_seq = seq
	_popups = popups


func init(slot_a: Button, slot_b: Button, slot_c: Button, slot_d: Button,
		  save_btn: Button, load_btn: Button, inf_btn: Button) -> void:
	_slot_buttons = [slot_a, slot_b, slot_c, slot_d]
	for i in range(_slot_buttons.size()):
		_slot_buttons[i].focus_mode = Control.FOCUS_NONE
		_slot_buttons[i].pressed.connect(_on_slot_selected.bind(i))
	_apply_action_button(save_btn, Color("#FFD54A"))
	_apply_action_button(load_btn, Color("#1FB6FF"))
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	inf_btn.pressed.connect(_popups.open_help)
	_refresh_slot_buttons()


func _on_slot_selected(slot: int) -> void:
	_active_slot = slot
	_refresh_slot_buttons()
	var btn: Button = _slot_buttons[slot]
	var tw := btn.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.04)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.14)


func _refresh_slot_buttons() -> void:
	for i in range(_slot_buttons.size()):
		var is_active := i == _active_slot
		var has_data  := SaveManager.slot_exists(i)
		var btn: Button = _slot_buttons[i]
		btn.button_pressed = is_active
		var s := DrumTheme.slot_style(i, is_active, has_data)
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_color_override("font_color",
			Color(1, 1, 1) if is_active
				else (DrumTheme.row_color(i).darkened(0.1) if has_data else Color(0.28, 0.28, 0.28)))
		btn.text = SaveManager.SLOT_NAMES[i] + ("•" if has_data else "")


func _apply_action_button(btn: Button, color: Color) -> void:
	var styles := DrumTheme.action_button_styles(color)
	btn.add_theme_stylebox_override("normal",  styles[0])
	btn.add_theme_stylebox_override("hover",   styles[1])
	btn.add_theme_stylebox_override("pressed", styles[2])
	btn.add_theme_color_override("font_color", color)


func _on_save_pressed() -> void:
	if SaveManager.slot_exists(_active_slot):
		_popups.open_confirm(
			"SAVE TO SLOT %s?" % SaveManager.SLOT_NAMES[_active_slot],
			"This will overwrite your existing pattern.",
			"OVERWRITE",
			_do_save
		)
	else:
		_do_save()


func _do_save() -> void:
	_popups.close_confirm()
	var error := SaveManager.save(_active_slot, _seq.to_dict())
	if error != OK:
		var message := "Could not save slot %s: error %d" % [_active_slot, error]
		push_error(message)
		operation_failed.emit(message)
		return
	_refresh_slot_buttons()


func _on_load_pressed() -> void:
	var data := SaveManager.load_slot(_active_slot)
	if data.is_empty():
		operation_failed.emit("Slot %s is empty or invalid." % SaveManager.SLOT_NAMES[_active_slot])
		return
	pattern_loaded.emit(PatternState.from_dict(data, Sequencer.DEFAULT_SOUNDS))
	_refresh_slot_buttons()
