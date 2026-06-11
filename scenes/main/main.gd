## main.gd
## DrumMachine scene controller.
## Responsibility: wire UI signals to the Sequencer model and update the view.
## Business logic lives in Sequencer / PatternHistory.
## Style creation lives in DrumTheme.
## Static UI structure lives in main.tscn (row labels, mute/sound buttons, step containers).
## Popup structures live in scenes/ui/velocity_popup.tscn and scenes/ui/sound_picker.tscn.
extends Control

# ── Layout constants ──────────────────────────────────────────────────────────
const BTN_SIZE  := 96
const H_GAP     := 6
const V_GAP     := 10
const BEAT_GAP  := 10
const NUM_H     := 28
const PAD_V     := 10
const PAD_H     := 12

# ── Input constants ───────────────────────────────────────────────────────────
const LONG_PRESS_SEC := 0.45
const MAX_TAP_COUNT  := 8

# ── Popup scenes ──────────────────────────────────────────────────────────────
const VELOCITY_POPUP_SCENE = preload("res://scenes/ui/velocity_popup.tscn")
const SOUND_PICKER_SCENE   = preload("res://scenes/ui/sound_picker.tscn")
const HELP_POPUP_SCENE     = preload("res://scenes/ui/help_popup.tscn")
const CONFIRM_POPUP_SCENE  = preload("res://scenes/ui/confirm_popup.tscn")

# ── Scene references ──────────────────────────────────────────────────────────
@onready var _timer:        Timer             = $Timer
@onready var _kick_player:  AudioStreamPlayer = $KickPlayer
@onready var _snare_player: AudioStreamPlayer = $SnarePlayer
@onready var _hat_player:   AudioStreamPlayer = $HatPlayer
@onready var _bass_player:  AudioStreamPlayer = $BassPlayer

@onready var _increase_tempo_btn: Button = %IncreaseTempoButton
@onready var _decrease_tempo_btn: Button = %DecreaseTempoButton
@onready var _tempo_label:        Label  = %TempoLabel

@onready var _increase_steps_btn: Button = %IncreaseStepsButton
@onready var _decrease_steps_btn: Button = %DecreaseStepsButton
@onready var _steps_label:        Label  = %StepsLabel

@onready var _play_stop_btn: Button = %PlayStopButton
@onready var _tap_btn:       Button = %TapButton
@onready var _clear_btn:     Button = %ClearButton
@onready var _random_btn:    Button = %RandomButton

@onready var _slot_btn_a: Button = %SlotButtonA
@onready var _slot_btn_b: Button = %SlotButtonB
@onready var _slot_btn_c: Button = %SlotButtonC
@onready var _slot_btn_d: Button = %SlotButtonD
@onready var _save_btn:   Button = %SaveButton
@onready var _load_btn:   Button = %LoadButton
@onready var _inf_btn:    Button = $MainPanel/VBox/SlotsContainer/InfButton

# ── Model / Logic ─────────────────────────────────────────────────────────────
var _seq:     Sequencer
var _history: PatternHistory
var _music:   MusicManager

# ── View state ────────────────────────────────────────────────────────────────
var _buttons:      Array      = []   # [row][step] → Button
var _row_labels:   Array      = []   # [row]       → Label   (static nodes)
var _row_snd_btns: Array      = []   # [row]       → Button  (static nodes)
var _row_mute_btns: Array     = []   # [row]       → Button  (static nodes)
var _step_row_nodes: Array    = []   # [row]       → HBoxContainer (static nodes)
var _style_cache:  Dictionary = {}   # Vector3i(velocity, row, is_beat) → styles
var _pulse_tweens: Dictionary = {}
var _prev_step:    int        = -1

var _active_slot:  int   = 0
var _slot_buttons: Array = []

# ── Long press state ──────────────────────────────────────────────────────────
var _lp_timer:    Timer
var _lp_row:      int  = -1
var _lp_step:     int  = -1
var _lp_fired:    bool = false
var _lp_consumed: bool = false

# ── Velocity popup ────────────────────────────────────────────────────────────
var _velocity_popup: VelocityPopup = null
var _popup_backdrop: ColorRect     = null

# ── Sound picker ──────────────────────────────────────────────────────────────
var _sound_picker:          SoundPicker = null
var _sound_picker_backdrop: ColorRect   = null

# ── Help popup ────────────────────────────────────────────────────────────────
var _help_popup:          HelpPopup = null
var _help_popup_backdrop: ColorRect = null

# ── Confirm popup ─────────────────────────────────────────────────────────────
var _confirm_popup:          ConfirmPopup = null
var _confirm_popup_backdrop: ColorRect    = null

# ── Tap tempo ─────────────────────────────────────────────────────────────────
var _tap_times: Array[float] = []

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_seq     = Sequencer.new()
	_history = PatternHistory.new()
	_music   = MusicManager.new()
	_music.setup([_kick_player, _snare_player, _hat_player, _bass_player])
	_music.set_master_volume(GameSettings.master_volume_db)

	_lp_timer           = Timer.new()
	_lp_timer.one_shot  = true
	_lp_timer.wait_time = LONG_PRESS_SEC
	_lp_timer.timeout.connect(_on_long_press_timeout)
	add_child(_lp_timer)

	# Collect static row nodes
	_row_labels    = [%Row0Label,    %Row1Label,    %Row2Label,    %Row3Label]
	_row_snd_btns  = [%Row0SoundBtn, %Row1SoundBtn, %Row2SoundBtn, %Row3SoundBtn]
	_row_mute_btns = [%Row0MuteBtn,  %Row1MuteBtn,  %Row2MuteBtn,  %Row3MuteBtn]
	_step_row_nodes = [%Row0Steps,   %Row1Steps,    %Row2Steps,    %Row3Steps]

	%StepArea.get_v_scroll_bar().modulate.a = 0
	DrumTheme.style_h_scrollbar(%StepArea)

	_init_row_labels()
	_build_grid_ui()

	_timer.wait_time = _seq.timer_interval()
	_timer.timeout.connect(_on_timer_timeout)
	_timer.start()

	_connect_transport_buttons()
	_init_slot_ui()
	_refresh_tempo_label()
	_refresh_steps_label()
	_refresh_play_button()


# ── Row label init (static nodes) ─────────────────────────────────────────────

func _init_row_labels() -> void:
	for row in range(Sequencer.ROWS):
		var mute_btn: Button = _row_mute_btns[row]
		mute_btn.button_pressed = _seq.muted[row]
		mute_btn.toggled.connect(_on_mute_toggled.bind(row))
		(_row_labels[row] as Label).modulate = Color(0.4, 0.4, 0.4) if _seq.muted[row] else Color(1, 1, 1)
		var snd_btn: Button = _row_snd_btns[row]
		snd_btn.tooltip_text = _seq.sound_paths[row].get_file().get_basename().replace("_", " ")
		snd_btn.pressed.connect(_open_sound_picker.bind(row, snd_btn))


# ── Connections ───────────────────────────────────────────────────────────────

func _connect_transport_buttons() -> void:
	_increase_tempo_btn.pressed.connect(_on_increase_tempo)
	_decrease_tempo_btn.pressed.connect(_on_decrease_tempo)
	_increase_steps_btn.pressed.connect(_on_increase_steps)
	_decrease_steps_btn.pressed.connect(_on_decrease_steps)
	_play_stop_btn.pressed.connect(_on_play_stop)
	_tap_btn.pressed.connect(_on_tap_tempo)
	_clear_btn.pressed.connect(_on_clear_pattern)
	_random_btn.pressed.connect(_on_randomize_pattern)


# ── Grid UI (step buttons only) ───────────────────────────────────────────────

func _build_grid_ui() -> void:
	_buttons.clear()
	_style_cache.clear()
	_pulse_tweens.clear()
	_prev_step = -1

	# Clear step number header
	for child in %StepNumRow.get_children():
		child.free()
	_build_step_numbers_header(%StepNumRow)

	# Clear and rebuild each step row
	for row in range(Sequencer.ROWS):
		_buttons.append([])
		var hbox: HBoxContainer = _step_row_nodes[row]
		for child in hbox.get_children():
			child.free()
		_build_step_row(hbox, row)


func _build_step_numbers_header(hbox: HBoxContainer) -> void:
	hbox.add_theme_constant_override("separation", H_GAP)
	for s in range(_seq.steps):
		if s > 0 and s % 4 == 0:
			hbox.add_child(_make_spacer(BEAT_GAP, NUM_H))
		var lbl := Label.new()
		lbl.custom_minimum_size  = Vector2(BTN_SIZE, NUM_H)
		lbl.text                 = str(s + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color",
			Color(0.58, 0.60, 0.92) if s % 4 == 0 else Color(0.20, 0.20, 0.30))
		hbox.add_child(lbl)


func _build_step_row(hbox: HBoxContainer, row: int) -> void:
	hbox.add_theme_constant_override("separation", H_GAP)
	for step in range(_seq.steps):
		if step > 0 and step % 4 == 0:
			hbox.add_child(_make_spacer(BEAT_GAP, BTN_SIZE))
		var btn := _create_step_button(row, step)
		hbox.add_child(btn)
		_buttons[row].append(btn)


func _create_step_button(row: int, step: int) -> Button:
	var btn := Button.new()
	btn.focus_mode          = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	btn.button_down.connect(_on_step_button_down.bind(row, step))
	btn.button_up.connect(_on_step_button_up.bind(row, step))
	_refresh_step_visual(btn, _seq.grid[row][step], row, step)
	return btn


func _make_spacer(w: int, h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c


# ── Long press ────────────────────────────────────────────────────────────────

func _on_step_button_down(row: int, step: int) -> void:
	if _velocity_popup != null:
		_close_velocity_popup()
		_lp_consumed = true
		return
	_lp_consumed = false
	_lp_row      = row
	_lp_step     = step
	_lp_fired    = false
	_lp_timer.start()


func _on_step_button_up(row: int, step: int) -> void:
	if _lp_consumed:
		_lp_consumed = false
		return
	if not _lp_fired:
		_lp_timer.stop()
		_do_cycle_velocity(row, step)
	_lp_row  = -1
	_lp_step = -1


func _on_long_press_timeout() -> void:
	_lp_fired = true
	if _lp_row >= 0:
		_open_velocity_popup(_lp_row, _lp_step)


# ── Velocity cycling (short tap) ──────────────────────────────────────────────

func _do_cycle_velocity(row: int, step: int) -> void:
	_history.push(_seq.get_grid_snapshot())
	var v := _seq.cycle_velocity(row, step)
	_refresh_step_visual(_buttons[row][step], v, row, step)
	if v > 0 and not _seq.muted[row]:
		_music.play_row(row, v)


# ── Velocity popup (long press) ───────────────────────────────────────────────

func _open_velocity_popup(row: int, step: int) -> void:
	_close_velocity_popup()

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.01)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.z_index = 10
	backdrop.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or \
		   (e is InputEventScreenTouch and e.pressed):
			_close_velocity_popup()
	)
	add_child(backdrop)
	_popup_backdrop = backdrop

	var popup: VelocityPopup = VELOCITY_POPUP_SCENE.instantiate()
	popup.velocity_chosen.connect(_on_velocity_chosen)
	add_child(popup)
	popup.setup(row, step, _seq.grid[row][step])
	popup.position_near(
		(_buttons[row][step] as Button).get_global_rect(),
		get_viewport_rect().size
	)
	_velocity_popup = popup


func _on_velocity_chosen(row: int, step: int, velocity: int) -> void:
	_history.push(_seq.get_grid_snapshot())
	_seq.set_velocity(row, step, velocity)
	_refresh_step_visual(_buttons[row][step], velocity, row, step)
	if velocity > 0 and not _seq.muted[row]:
		_music.play_row(row, velocity)
	_close_velocity_popup()


func _close_velocity_popup() -> void:
	if is_instance_valid(_velocity_popup):
		_velocity_popup.queue_free()
	if is_instance_valid(_popup_backdrop):
		_popup_backdrop.queue_free()
	_velocity_popup = null
	_popup_backdrop = null


# ── Sound picker ──────────────────────────────────────────────────────────────

func _open_sound_picker(row: int, anchor_btn: Button) -> void:
	_close_sound_picker()

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.01)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.z_index = 10
	backdrop.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or \
		   (e is InputEventScreenTouch and e.pressed):
			_close_sound_picker()
	)
	add_child(backdrop)
	_sound_picker_backdrop = backdrop

	var picker: SoundPicker = SOUND_PICKER_SCENE.instantiate()
	picker.z_index = 11
	picker.sound_selected.connect(_on_sound_selected)
	add_child(picker)
	picker.setup(row, _seq.sound_paths[row])
	picker.position_near(anchor_btn.get_global_rect(), get_viewport_rect().size)
	_sound_picker = picker


func _on_sound_selected(row: int, path: String) -> void:
	_seq.sound_paths[row] = path
	_music.set_stream(row, path)
	if row < _row_snd_btns.size():
		(_row_snd_btns[row] as Button).tooltip_text = path.get_file().get_basename().replace("_", " ")
	_close_sound_picker()


func _close_sound_picker() -> void:
	if is_instance_valid(_sound_picker):
		_sound_picker.queue_free()
	if is_instance_valid(_sound_picker_backdrop):
		_sound_picker_backdrop.queue_free()
	_sound_picker = null
	_sound_picker_backdrop = null


func _apply_sound_paths() -> void:
	for row in range(Sequencer.ROWS):
		_music.set_stream(row, _seq.sound_paths[row])


# ── Mute ──────────────────────────────────────────────────────────────────────

func _on_mute_toggled(pressed: bool, row: int) -> void:
	_seq.muted[row] = pressed
	(_row_labels[row] as Label).modulate = Color(0.4, 0.4, 0.4) if pressed else Color(1, 1, 1)


# ── Sequencer tick ────────────────────────────────────────────────────────────

func _on_timer_timeout() -> void:
	var velocities := _seq.current_step_velocities()
	for row in range(Sequencer.ROWS):
		if velocities[row] > 0:
			_music.play_row(row, velocities[row])
			_flash_row_label(row)
	_highlight_step(_seq.current_step)
	_seq.advance()


# ── Visual feedback ───────────────────────────────────────────────────────────

func _flash_row_label(row: int) -> void:
	if row >= _row_labels.size():
		return
	var lbl: Label = _row_labels[row]
	var tween := create_tween()
	tween.tween_property(lbl, "modulate", Color(2.8, 2.8, 2.8), 0.04)
	tween.tween_property(lbl, "modulate", Color(1.0, 1.0, 1.0), 0.18)


func _pulse_button(btn: Button) -> void:
	if _pulse_tweens.has(btn) and _pulse_tweens[btn] != null:
		_pulse_tweens[btn].kill()
	var tween := create_tween()
	_pulse_tweens[btn] = tween
	tween.set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.07)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.13).set_delay(0.07)


func _highlight_step(step: int) -> void:
	if _prev_step != -1:
		for row in range(Sequencer.ROWS):
			_buttons[row][_prev_step].modulate = Color(1, 1, 1)
	for row in range(Sequencer.ROWS):
		var btn: Button = _buttons[row][step]
		btn.modulate = Color(2.4, 2.4, 2.4)
		if _seq.grid[row][step] > 0:
			_pulse_button(btn)
	_prev_step = step


func _refresh_step_visual(btn: Button, velocity: int, row: int, step: int) -> void:
	var key    := Vector3i(velocity, row, 1 if step % 4 == 0 else 0)
	var styles: Array[StyleBoxFlat]
	if _style_cache.has(key):
		styles = _style_cache[key]
	else:
		styles = DrumTheme.step_styles(velocity, row, step % 4 == 0)
		_style_cache[key] = styles
	btn.add_theme_stylebox_override("normal",  styles[0])
	btn.add_theme_stylebox_override("hover",   styles[1])
	btn.add_theme_stylebox_override("pressed", styles[2])
	if velocity in [1, 2, 3]:
		btn.text = str(velocity)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	else:
		btn.text = ""


func _refresh_all_step_visuals() -> void:
	for row in range(Sequencer.ROWS):
		for step in range(_seq.steps):
			_refresh_step_visual(_buttons[row][step], _seq.grid[row][step], row, step)


# ── Play / Stop ───────────────────────────────────────────────────────────────

func _on_play_stop() -> void:
	_seq.is_playing = not _seq.is_playing
	if _seq.is_playing:
		_seq.current_step = 0
		_prev_step        = -1
		_timer.start()
	else:
		_timer.stop()
		if _prev_step != -1:
			for row in range(Sequencer.ROWS):
				_buttons[row][_prev_step].modulate = Color(1, 1, 1)
	_refresh_play_button()


func _refresh_play_button() -> void:
	if _seq.is_playing:
		_play_stop_btn.text = "■ STOP"
		_play_stop_btn.add_theme_color_override("font_color", Color("#FF3D7F"))
		_set_button_border(_play_stop_btn, Color("#FF3D7F"))
	else:
		_play_stop_btn.text = "▶ PLAY"
		_play_stop_btn.add_theme_color_override("font_color", Color("#00FF8C"))
		_set_button_border(_play_stop_btn, Color("#00FF8C"))


func _set_button_border(btn: Button, color: Color) -> void:
	var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	s.border_color = color
	s.shadow_color = color
	btn.add_theme_stylebox_override("normal", s)


# ── Pattern operations ────────────────────────────────────────────────────────

func _on_clear_pattern() -> void:
	_history.push(_seq.get_grid_snapshot())
	_seq.clear()
	_seq.current_step = 0
	_prev_step        = -1
	_refresh_all_step_visuals()


func _on_randomize_pattern() -> void:
	_history.push(_seq.get_grid_snapshot())
	_seq.randomize()
	_refresh_all_step_visuals()


# ── Undo / Redo ───────────────────────────────────────────────────────────────

func _undo() -> void:
	var restored := _history.undo(_seq.get_grid_snapshot())
	_seq.apply_grid_snapshot(restored)
	_refresh_all_step_visuals()


func _redo() -> void:
	var restored := _history.redo(_seq.get_grid_snapshot())
	_seq.apply_grid_snapshot(restored)
	_refresh_all_step_visuals()


# ── Save / Load ───────────────────────────────────────────────────────────────

func _on_save_pressed() -> void:
	if SaveManager.slot_exists(_active_slot):
		_open_confirm_popup(
			"SAVE TO SLOT %s?" % SaveManager.SLOT_NAMES[_active_slot],
			"This will overwrite your existing pattern.",
			"OVERWRITE",
			_do_save
		)
	else:
		_do_save()


func _do_save() -> void:
	_close_confirm_popup()
	SaveManager.save(_active_slot, _seq.to_dict())
	_refresh_slot_buttons()


func _on_load_pressed() -> void:
	var data := SaveManager.load_slot(_active_slot)
	if data.is_empty():
		return
	_history.push(_seq.get_grid_snapshot())
	_seq.from_dict(data)
	_apply_sound_paths()
	# Refresh static row UI to reflect loaded state
	for row in range(Sequencer.ROWS):
		(_row_mute_btns[row] as Button).button_pressed = _seq.muted[row]
		(_row_labels[row] as Label).modulate = Color(0.4, 0.4, 0.4) if _seq.muted[row] else Color(1, 1, 1)
		(_row_snd_btns[row] as Button).tooltip_text = _seq.sound_paths[row].get_file().get_basename().replace("_", " ")
	_build_grid_ui()
	_timer.wait_time = _seq.timer_interval()
	_refresh_tempo_label()
	_refresh_steps_label()
	_refresh_slot_buttons()


# ── Slot UI ───────────────────────────────────────────────────────────────────

func _init_slot_ui() -> void:
	_slot_buttons = [_slot_btn_a, _slot_btn_b, _slot_btn_c, _slot_btn_d]
	for i in range(4):
		_slot_buttons[i].focus_mode = Control.FOCUS_NONE
		_slot_buttons[i].pressed.connect(_on_slot_selected.bind(i))
	_apply_action_button(_save_btn, Color("#FFD54A"))
	_apply_action_button(_load_btn, Color("#1FB6FF"))
	_save_btn.pressed.connect(_on_save_pressed)
	_load_btn.pressed.connect(_on_load_pressed)
	_inf_btn.pressed.connect(_open_help_popup)
	_refresh_slot_buttons()


func _on_slot_selected(slot: int) -> void:
	_active_slot = slot
	_refresh_slot_buttons()


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


# ── Tempo ─────────────────────────────────────────────────────────────────────

func _on_increase_tempo() -> void:
	_seq.tempo   = mini(_seq.tempo + 5, Sequencer.MAX_TEMPO)
	_timer.wait_time = _seq.timer_interval()
	_refresh_tempo_label()


func _on_decrease_tempo() -> void:
	_seq.tempo   = maxi(_seq.tempo - 5, Sequencer.MIN_TEMPO)
	_timer.wait_time = _seq.timer_interval()
	_refresh_tempo_label()


func _refresh_tempo_label() -> void:
	_tempo_label.text = "%d BPM" % _seq.tempo


# ── Steps ─────────────────────────────────────────────────────────────────────

func _on_increase_steps() -> void:
	_seq.resize_steps(_seq.steps + 4)
	_build_grid_ui()
	_refresh_steps_label()


func _on_decrease_steps() -> void:
	_seq.resize_steps(_seq.steps - 4)
	_build_grid_ui()
	_refresh_steps_label()


func _refresh_steps_label() -> void:
	_steps_label.text = str(_seq.steps)


# ── Tap Tempo ─────────────────────────────────────────────────────────────────

func _on_tap_tempo() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _tap_times.is_empty() and (now - _tap_times[-1]) > 3.0:
		_tap_times.clear()
	_tap_times.append(now)
	if _tap_times.size() > MAX_TAP_COUNT:
		_tap_times.remove_at(0)
	if _tap_times.size() >= 2:
		var total := 0.0
		for i in range(1, _tap_times.size()):
			total += _tap_times[i] - _tap_times[i - 1]
		_seq.tempo = clampi(
			int(round(60.0 / (total / (_tap_times.size() - 1)))),
			Sequencer.MIN_TEMPO, Sequencer.MAX_TEMPO
		)
		_timer.wait_time = _seq.timer_interval()
		_refresh_tempo_label()


# ── Keyboard input ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if _velocity_popup != null:
		_close_velocity_popup()
		return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z: _undo()
			KEY_Y: _redo()
		return
	match event.keycode:
		KEY_1: if not _seq.muted[0]: _music.play_row(0, 4)
		KEY_2: if not _seq.muted[1]: _music.play_row(1, 4)
		KEY_3: if not _seq.muted[2]: _music.play_row(2, 4)
		KEY_4: if not _seq.muted[3]: _music.play_row(3, 4)
		KEY_SPACE:
			_on_play_stop()
			get_viewport().set_input_as_handled()


# ── Confirm popup ─────────────────────────────────────────────────────────────

func _open_confirm_popup(title: String, body: String, ok_label: String, on_confirm: Callable) -> void:
	_close_confirm_popup()

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.z_index = 20
	add_child(backdrop)
	_confirm_popup_backdrop = backdrop

	var popup: ConfirmPopup = CONFIRM_POPUP_SCENE.instantiate()
	popup.z_index = 21
	popup.confirmed.connect(on_confirm)
	popup.tree_exited.connect(_close_confirm_popup)
	add_child(popup)
	popup.setup(title, body, ok_label)
	popup.position_near(get_viewport_rect().size)
	_confirm_popup = popup


func _close_confirm_popup() -> void:
	if is_instance_valid(_confirm_popup):
		_confirm_popup.queue_free()
	if is_instance_valid(_confirm_popup_backdrop):
		_confirm_popup_backdrop.queue_free()
	_confirm_popup          = null
	_confirm_popup_backdrop = null


# ── Help popup ────────────────────────────────────────────────────────────────

func _open_help_popup() -> void:
	if _help_popup != null:
		_close_help_popup()
		return

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.z_index = 10
	backdrop.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or \
		   (e is InputEventScreenTouch and e.pressed):
			_close_help_popup()
	)
	add_child(backdrop)
	_help_popup_backdrop = backdrop

	var popup: HelpPopup = HELP_POPUP_SCENE.instantiate()
	popup.z_index = 11
	popup.get_node("Margin/VBox/TitleRow/CloseBtn").pressed.connect(_close_help_popup)
	add_child(popup)
	popup.position_near(get_viewport_rect().size)
	_help_popup = popup


func _close_help_popup() -> void:
	if is_instance_valid(_help_popup):
		_help_popup.queue_free()
	if is_instance_valid(_help_popup_backdrop):
		_help_popup_backdrop.queue_free()
	_help_popup          = null
	_help_popup_backdrop = null


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
