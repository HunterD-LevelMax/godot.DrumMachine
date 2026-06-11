## main.gd
## DrumMachine scene controller.
extends Control

const PLAYHEAD_HEIGHT := 4
const DRUM_ROW_SCENE := preload("res://scenes/ui/drum_row.tscn")

const _KEY_ROW_MAP: Array[Key] = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
	KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
]

@onready var _timer: Timer = $Timer

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
@onready var _add_row_btn:   Button = %AddRowButton
@onready var _slot_btn_a: Button = %SlotButtonA
@onready var _slot_btn_b: Button = %SlotButtonB
@onready var _slot_btn_c: Button = %SlotButtonC
@onready var _slot_btn_d: Button = %SlotButtonD
@onready var _save_btn:   Button = %SaveButton
@onready var _load_btn:   Button = %LoadButton
@onready var _inf_btn:    Button = $MainPanel/VBox/SlotsContainer/InfButton
@onready var _row_panel:      VBoxContainer    = %RowVBox
@onready var _row_scroll:     ScrollContainer  = %RowPanel
@onready var _rows_container: VBoxContainer    = %RowsContainer
@onready var _step_num_row:   HBoxContainer    = %StepNumRow
@onready var _step_area:      ScrollContainer  = %StepArea
@onready var _step_vbox:      VBoxContainer     = %StepVBox

var _seq:     Sequencer
var _history: PatternHistory = null
var _music:   MusicManager
var _grid:    StepGridBuilder
var _popups:  PopupManager
var _slots:   SlotManager
var _transport: TransportController

var _row_views: Array[DrumRow] = []

var _syncing_scroll: bool = false

var _playhead: ColorRect
var _playhead_glow: ColorRect

var _flash_tweens: Dictionary = {}

var _pinch_active: bool = false
var _pinch_start_dist: float = 0.0
var _pinch_start_btn_size: float = 0.0


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_seq     = Sequencer.new()
	_history = PatternHistory.new()
	_music   = MusicManager.new()
	_grid    = StepGridBuilder.new()
	_popups  = PopupManager.new()
	_slots   = SlotManager.new()
	_transport = TransportController.new()
	_popups.setup(self)
	_popups.velocity_chosen.connect(_on_velocity_chosen)
	_popups.sound_selected.connect(_on_sound_selected)
	_music.setup(self)
	_music.set_master_volume(GameSettings.master_volume_db)
	_slots.setup(_seq, _popups)
	_slots.pattern_loaded.connect(_on_pattern_loaded)
	_transport.setup(_seq, _timer)
	_transport.step_triggered.connect(_on_transport_step)
	_transport.playing_changed.connect(_on_playing_changed)
	_transport.tempo_changed.connect(func(_tempo: int) -> void:
		_refresh_tempo_label()
	)

	_row_scroll.get_v_scroll_bar().modulate.a = 0
	DrumTheme.style_h_scrollbar(_step_area)
	DrumTheme.style_scrollbar(_step_area)
	_row_scroll.get_v_scroll_bar().value_changed.connect(_sync_step_scroll)
	_step_area.get_v_scroll_bar().value_changed.connect(_sync_row_scroll)

	_init_playhead()
	_rebuild_all_rows()
	_apply_sound_paths()

	_transport.start()

	_connect_transport_buttons()
	_slots.init(
		_slot_btn_a, _slot_btn_b, _slot_btn_c, _slot_btn_d,
		_save_btn, _load_btn, _inf_btn
	)
	_refresh_tempo_label()
	_refresh_steps_label()
	_refresh_play_button()
	_add_row_btn.pressed.connect(_on_add_row)


# ── Playhead ──────────────────────────────────────────────────────────────────

func _init_playhead() -> void:
	_playhead = ColorRect.new()
	_playhead.color = Color(0, 0.83, 1, 0.85)
	_playhead.custom_minimum_size = Vector2(0, PLAYHEAD_HEIGHT)
	_playhead.size = Vector2(0, PLAYHEAD_HEIGHT)
	_playhead.visible = false
	_step_vbox.add_child(_playhead)
	_step_vbox.move_child(_playhead, 0)

	_playhead_glow = ColorRect.new()
	_playhead_glow.color = Color(0, 0.83, 1, 0.25)
	_playhead_glow.custom_minimum_size = Vector2(0, PLAYHEAD_HEIGHT + 8)
	_playhead_glow.size = Vector2(0, PLAYHEAD_HEIGHT + 8)
	_playhead_glow.visible = false
	_step_vbox.add_child(_playhead_glow)
	_step_vbox.move_child(_playhead_glow, 0)


func _update_playhead() -> void:
	if not _seq.is_playing or _seq.current_step >= _seq.steps:
		_playhead.visible = false
		_playhead_glow.visible = false
		return
	_playhead.visible = true
	_playhead_glow.visible = true
	var btn_size := StepGridBuilder.BTN_SIZE
	var h_gap    := StepGridBuilder.H_GAP
	var beat_gap := StepGridBuilder.BEAT_GAP
	var step := _seq.current_step
	var separators_before := step / 4
	var x := step * (btn_size + h_gap) + separators_before * (beat_gap - h_gap)
	_playhead.position = Vector2(x, 0)
	_playhead.size = Vector2(btn_size, PLAYHEAD_HEIGHT)
	_playhead_glow.position = Vector2(x - 2, -4)
	_playhead_glow.size = Vector2(btn_size + 4, PLAYHEAD_HEIGHT + 8)


# ── Scroll sync ──────────────────────────────────────────────────────────────

func _sync_step_scroll(value: float) -> void:
	if _syncing_scroll:
		return
	_syncing_scroll = true
	_step_area.scroll_vertical = int(value)
	_syncing_scroll = false


func _sync_row_scroll(value: float) -> void:
	if _syncing_scroll:
		return
	_syncing_scroll = true
	_row_scroll.scroll_vertical = int(value)
	_syncing_scroll = false


# ── Row management ────────────────────────────────────────────────────────────

func _rebuild_all_rows() -> void:
	_row_scroll.get_v_scroll_bar().value_changed.disconnect(_sync_step_scroll)
	_step_area.get_v_scroll_bar().value_changed.disconnect(_sync_row_scroll)

	for child in _row_panel.get_children():
		child.set_process(false)
		child.set_process_input(false)
		child.queue_free()
	for child in _rows_container.get_children():
		child.set_process(false)
		child.set_process_input(false)
		child.queue_free()
	_grid.clear()
	_row_views.clear()
	for tween: Tween in _flash_tweens.values():
		if tween != null:
			tween.kill()
	_flash_tweens.clear()

	_step_num_row.add_theme_constant_override("separation", StepGridBuilder.H_GAP)
	for child in _step_num_row.get_children():
		child.queue_free()
	_grid.build_step_numbers_header(_step_num_row, _seq.steps)

	_music.set_player_count(_seq.rows)

	for row in range(_seq.rows):
		_create_row_ui(row)

	_add_row_btn.disabled = _seq.rows >= Sequencer.MAX_ROWS
	_add_row_btn.text = "ADD ROW" if _seq.rows < Sequencer.MAX_ROWS else "MAX 10"

	_row_scroll.get_v_scroll_bar().value_changed.connect(_sync_step_scroll)
	_step_area.get_v_scroll_bar().value_changed.connect(_sync_row_scroll)
	_row_scroll.scroll_vertical = 0
	_step_area.scroll_vertical = 0
	_playhead.visible = false
	_playhead_glow.visible = false


func _create_row_ui(row: int) -> void:
	var row_view: DrumRow = DRUM_ROW_SCENE.instantiate()
	_row_panel.add_child(row_view)
	row_view.setup(
		row,
		_seq.muted[row],
		_seq.sound_paths[row],
		row >= Sequencer.DEFAULT_ROWS
	)
	row_view.mute_requested.connect(_on_row_mute_requested)
	row_view.sound_requested.connect(_on_sound_btn_pressed)
	row_view.delete_requested.connect(_on_delete_row)
	_row_views.append(row_view)

	var step_hbox := HBoxContainer.new()
	step_hbox.add_theme_constant_override("separation", StepGridBuilder.H_GAP)
	_rows_container.add_child(step_hbox)
	_grid.build_step_row(step_hbox, row, _seq.steps, _seq.grid,
		_on_step_short_pressed, _open_velocity_popup)


func _on_delete_row(row: int) -> void:
	if row < Sequencer.DEFAULT_ROWS:
		return
	if _seq.rows <= Sequencer.MIN_ROWS:
		return
	var was_playing := _transport.pause_for_change()
	_history.push(_seq.create_snapshot())
	_seq.remove_row(row)
	_music.set_player_count(_seq.rows)
	_rebuild_all_rows()
	_transport.resume_after_change(was_playing)


func _on_add_row() -> void:
	var previous_state := _seq.create_snapshot()
	if _seq.add_row():
		_history.push(previous_state)
		var was_playing := _transport.pause_for_change()
		_music.set_player_count(_seq.rows)
		_rebuild_all_rows()
		_transport.resume_after_change(was_playing)


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
	_animate_button_press(_increase_tempo_btn)
	_animate_button_press(_decrease_tempo_btn)
	_animate_button_press(_increase_steps_btn)
	_animate_button_press(_decrease_steps_btn)
	_animate_button_press(_tap_btn)
	_animate_button_press(_clear_btn)
	_animate_button_press(_random_btn)
	_animate_button_press(_add_row_btn)
	_animate_button_press(_save_btn)
	_animate_button_press(_load_btn)


func _animate_button_press(btn: Button) -> void:
	btn.button_down.connect(func() -> void:
		var tween := btn.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.04)
	)
	btn.button_up.connect(func() -> void:
		var tween := btn.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)


func _on_step_short_pressed(row: int, step: int) -> void:
	if _popups.has_velocity_popup():
		_popups.close_velocity()
		return
	_do_cycle_velocity(row, step)


func _do_cycle_velocity(row: int, step: int) -> void:
	_history.push(_seq.create_snapshot())
	var v := _seq.cycle_velocity(row, step)
	var btn: Button = _grid.get_buttons()[row][step]
	_grid.refresh_step_visual(btn, v, row, step)
	_grid.bounce_button(btn)
	if v > 0 and not _seq.muted[row]:
		_music.play_row(row, v)


# ── Velocity popup ────────────────────────────────────────────────────────────

func _open_velocity_popup(row: int, step: int) -> void:
	_popups.open_velocity(
		row, step, _seq.grid[row][step],
		_grid.get_buttons()[row][step] as Button
	)


func _on_velocity_chosen(row: int, step: int, velocity: int) -> void:
	_history.push(_seq.create_snapshot())
	_seq.set_velocity(row, step, velocity)
	_grid.refresh_step_visual(_grid.get_buttons()[row][step], velocity, row, step)
	if velocity > 0 and not _seq.muted[row]:
		_music.play_row(row, velocity)
	_popups.close_velocity()


# ── Sound picker ──────────────────────────────────────────────────────────────

func _on_sound_btn_pressed(row: int, anchor_btn: Button) -> void:
	_popups.open_sound_picker(row, _seq.sound_paths[row], anchor_btn)


func _on_sound_selected(row: int, path: String) -> void:
	_history.push(_seq.create_snapshot())
	_seq.set_sound(row, path)
	_music.set_stream(row, path)
	if row < _row_views.size():
		_row_views[row].set_sound_path(path)
	_popups.close_sound_picker()


func _apply_sound_paths() -> void:
	for row in range(_seq.rows):
		_music.set_stream(row, _seq.sound_paths[row])


func _on_pattern_loaded(state: PatternState) -> void:
	var was_playing := _transport.pause_for_change()
	_history.push(_seq.create_snapshot())
	_seq.restore_snapshot(state)
	_rebuild_all_rows()
	_apply_sound_paths()
	_refresh_tempo_label()
	_refresh_steps_label()
	_transport.resume_after_change(was_playing)


func _on_row_mute_requested(row: int, muted: bool) -> void:
	if row < 0 or row >= _seq.rows:
		return
	_history.push(_seq.create_snapshot())
	_seq.set_muted(row, muted)


# ── Sequencer tick ────────────────────────────────────────────────────────────

func _on_transport_step(step: int, velocities: Array[int]) -> void:
	var buttons := _grid.get_buttons()
	var row_count := _seq.rows
	for row in range(row_count):
		if row >= buttons.size():
			continue
		if velocities[row] > 0:
			_music.play_row(row, velocities[row])
			_flash_row_label(row)
	_grid.highlight_step(step, row_count, _seq.steps, _seq.grid)
	_update_playhead()


# ── Visual feedback ───────────────────────────────────────────────────────────

func _flash_row_label(row: int) -> void:
	if row >= _row_views.size():
		return
	var lbl := _row_views[row].get_name_button()
	if _flash_tweens.has(lbl) and _flash_tweens[lbl] != null:
		_flash_tweens[lbl].kill()
	var tween := create_tween()
	_flash_tweens[lbl] = tween
	tween.tween_property(lbl, "modulate", Color(2.8, 2.8, 2.8), 0.04)
	tween.tween_property(lbl, "modulate", Color(1.0, 1.0, 1.0), 0.18)


# ── Play / Stop ───────────────────────────────────────────────────────────────

func _on_play_stop() -> void:
	_grid.bounce_button(_play_stop_btn)
	_transport.toggle_playing()


func _on_playing_changed(is_playing: bool) -> void:
	if is_playing:
		_grid.set_prev_step(-1)
	else:
		_grid.clear_highlight(_seq.rows, _seq.steps)
		_playhead.visible = false
		_playhead_glow.visible = false
		for tween: Tween in _flash_tweens.values():
			if tween != null:
				tween.kill()
		_flash_tweens.clear()
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
	if btn == null:
		return
	var style := btn.get_theme_stylebox("normal")
	if style == null:
		return
	var s := style.duplicate() as StyleBoxFlat
	if s == null:
		return
	s.border_color = color
	s.shadow_color = color
	btn.add_theme_stylebox_override("normal", s)


# ── Pattern operations ────────────────────────────────────────────────────────

func _on_clear_pattern() -> void:
	_history.push(_seq.create_snapshot())
	_seq.clear()
	_seq.current_step = 0
	_grid.set_prev_step(-1)
	_grid.refresh_all_step_visuals(_seq.rows, _seq.steps, _seq.grid)
	_grid.ripple_grid(_seq.rows, _seq.steps)


func _on_randomize_pattern() -> void:
	_history.push(_seq.create_snapshot())
	_seq.randomize()
	_grid.refresh_all_step_visuals(_seq.rows, _seq.steps, _seq.grid)
	_grid.ripple_grid(_seq.rows, _seq.steps)


# ── Undo / Redo ───────────────────────────────────────────────────────────────

func _undo() -> void:
	var was_playing := _transport.pause_for_change()
	var restored := _history.undo(_seq.create_snapshot())
	_seq.restore_snapshot(restored)
	_rebuild_all_rows()
	_apply_sound_paths()
	_refresh_tempo_label()
	_refresh_steps_label()
	_transport.resume_after_change(was_playing)


func _redo() -> void:
	var was_playing := _transport.pause_for_change()
	var restored := _history.redo(_seq.create_snapshot())
	_seq.restore_snapshot(restored)
	_rebuild_all_rows()
	_apply_sound_paths()
	_refresh_tempo_label()
	_refresh_steps_label()
	_transport.resume_after_change(was_playing)


# ── Tempo ─────────────────────────────────────────────────────────────────────

func _on_increase_tempo() -> void:
	_transport.change_tempo(5)


func _on_decrease_tempo() -> void:
	_transport.change_tempo(-5)


func _refresh_tempo_label() -> void:
	_tempo_label.text = "%d BPM" % _seq.tempo
	var tw := _tempo_label.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_tempo_label, "scale", Vector2(1.15, 1.15), 0.05)
	tw.tween_property(_tempo_label, "scale", Vector2.ONE, 0.12)


# ── Steps ─────────────────────────────────────────────────────────────────────

func _on_increase_steps() -> void:
	_history.push(_seq.create_snapshot())
	var was_playing := _transport.pause_for_change()
	_seq.resize_steps(_seq.steps + 4)
	_rebuild_all_rows()
	_apply_sound_paths()
	_refresh_steps_label()
	_transport.resume_after_change(was_playing)


func _on_decrease_steps() -> void:
	_history.push(_seq.create_snapshot())
	var was_playing := _transport.pause_for_change()
	_seq.resize_steps(_seq.steps - 4)
	_rebuild_all_rows()
	_apply_sound_paths()
	_refresh_steps_label()
	_transport.resume_after_change(was_playing)


func _refresh_steps_label() -> void:
	_steps_label.text = str(_seq.steps)
	var tw := _steps_label.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_steps_label, "scale", Vector2(1.15, 1.15), 0.05)
	tw.tween_property(_steps_label, "scale", Vector2.ONE, 0.12)


# ── Tap Tempo ─────────────────────────────────────────────────────────────────

func _on_tap_tempo() -> void:
	_transport.tap_tempo()


# ── Keyboard input ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if _popups.has_velocity_popup():
		_popups.close_velocity()
		return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z: _undo()
			KEY_Y: _redo()
		return
	match event.keycode:
		KEY_SPACE:
			_on_play_stop()
			get_viewport().set_input_as_handled()

	for i in range(mini(_seq.rows, 10)):
		if event.keycode == _KEY_ROW_MAP[i] and not _seq.muted[i]:
			_music.play_row(i, 4)


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
