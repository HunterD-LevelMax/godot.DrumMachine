## slot_manager.gd
## Manages save/load slots, slot button UI, and save/load flow.
class_name SlotManager
extends RefCounted

var _seq:      Sequencer
var _popups:   PopupManager
var _music:    MusicManager
var _history:  PatternHistory
var _timer:    Timer
var _grid:     StepGridBuilder
var _owner:    Control

var _active_slot: int   = 0
var _slot_buttons: Array = []

var on_rebuild:       Callable
var on_apply_sounds:  Callable
var on_refresh_tempo: Callable
var on_refresh_steps: Callable


func setup(owner: Control, seq: Sequencer, popups: PopupManager, music: MusicManager,
           history: PatternHistory, timer: Timer, grid: StepGridBuilder,
           p_on_rebuild: Callable, p_on_apply_sounds: Callable,
           p_on_refresh_tempo: Callable, p_on_refresh_steps: Callable) -> void:
	_owner  = owner
	_seq    = seq
	_popups = popups
	_music  = music
	_history = history
	_timer  = timer
	_grid   = grid
	on_rebuild       = p_on_rebuild
	on_apply_sounds  = p_on_apply_sounds
	on_refresh_tempo = p_on_refresh_tempo
	on_refresh_steps = p_on_refresh_steps


func init(slot_a: Button, slot_b: Button, slot_c: Button, slot_d: Button,
          save_btn: Button, load_btn: Button, inf_btn: Button) -> void:
	_slot_buttons = [slot_a, slot_b, slot_c, slot_d]
	for i in range(4):
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
			else (DrumTheme.ROW_COLORS[i].darkened(0.1) if has_data else Color(0.28, 0.28, 0.28)))
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
	SaveManager.save(_active_slot, _seq.to_dict())
	_refresh_slot_buttons()


func _on_load_pressed() -> void:
	var data := SaveManager.load_slot(_active_slot)
	if data.is_empty():
		return
	var was_playing := _seq.is_playing
	if was_playing:
		_seq.is_playing = false
		_timer.stop()
	_history.push(_seq.get_grid_snapshot())
	_seq.from_dict(data)
	on_rebuild.call()
	on_apply_sounds.call()
	_timer.wait_time = _seq.timer_interval()
	on_refresh_tempo.call()
	on_refresh_steps.call()
	_refresh_slot_buttons()
	if was_playing:
		_seq.is_playing = true
		_seq.current_step = 0
		_grid.set_prev_step(-1)
		_timer.start()
