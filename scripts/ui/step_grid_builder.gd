## step_grid_builder.gd
## Builds and manages the step button grid, number header, and visual feedback.
class_name StepGridBuilder
extends RefCounted

const BTN_SIZE  := 96
const H_GAP     := 6
const BEAT_GAP  := 10
const NUM_H     := 28

var _buttons:        Array = []
var _step_row_nodes: Array = []
var _style_cache:    Dictionary = {}
var _pulse_tweens:   Dictionary = {}
var _prev_step:      int = -1
var _step_number_labels: Array = []


func clear() -> void:
	_buttons.clear()
	_step_row_nodes.clear()
	_style_cache.clear()
	_pulse_tweens.clear()
	_step_number_labels.clear()
	_prev_step = -1


func build_step_numbers_header(hbox: HBoxContainer, steps: int) -> void:
	hbox.add_theme_constant_override("separation", H_GAP)
	_step_number_labels.clear()
	for s in range(steps):
		if s > 0 and s % 4 == 0:
			hbox.add_child(_make_spacer(BEAT_GAP, NUM_H))
			_step_number_labels.append(null)
		var lbl := Label.new()
		lbl.custom_minimum_size  = Vector2(BTN_SIZE, NUM_H)
		lbl.text                 = str(s + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color",
			Color(0.58, 0.60, 0.92) if s % 4 == 0 else Color(0.20, 0.20, 0.30))
		hbox.add_child(lbl)
		_step_number_labels.append(lbl)


func build_step_row(
		hbox: HBoxContainer,
		row: int,
		steps: int,
		grid: Array,
		on_short_press: Callable,
		on_context: Callable
	) -> void:
	hbox.add_theme_constant_override("separation", H_GAP)
	_buttons.append([])
	for step in range(steps):
		if step > 0 and step % 4 == 0:
			hbox.add_child(_make_spacer(BEAT_GAP, BTN_SIZE))
		var btn := _create_step_button(row, step, grid)
		btn.short_pressed.connect(on_short_press)
		btn.context_requested.connect(on_context)
		hbox.add_child(btn)
		_buttons[row].append(btn)
	_step_row_nodes.append(hbox)


func get_buttons() -> Array:
	return _buttons


func get_prev_step() -> int:
	return _prev_step


func set_prev_step(v: int) -> void:
	_prev_step = v


func _create_step_button(row: int, step: int, grid: Array) -> StepButton:
	var btn := StepButton.new()
	btn.setup(row, step)
	btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	refresh_step_visual(btn, grid[row][step], row, step)
	return btn


func _make_spacer(w: int, h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c


func refresh_step_visual(btn: Button, velocity: int, row: int, step: int) -> void:
	var key := Vector3i(velocity, row, 1 if step % 4 == 0 else 0)
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


func refresh_all_step_visuals(rows: int, steps: int, grid: Array) -> void:
	for row in range(rows):
		for step in range(steps):
			if row < _buttons.size() and step < _buttons[row].size():
				refresh_step_visual(_buttons[row][step], grid[row][step], row, step)


func highlight_step(step: int, rows: int, steps: int, grid: Array) -> void:
	if _prev_step != -1 and _prev_step < steps:
		for row in range(rows):
			if row < _buttons.size() and _prev_step < _buttons[row].size():
				_buttons[row][_prev_step].modulate = Color(1, 1, 1)
		_unhighlight_step_number(_prev_step)
	for row in range(rows):
		if row < _buttons.size() and step < _buttons[row].size():
			var btn: Button = _buttons[row][step]
			btn.modulate = Color(2.4, 2.4, 2.4)
			if grid[row][step] > 0:
				pulse_button(btn)
	_highlight_step_number(step)
	_prev_step = step


func pulse_button(btn: Button) -> void:
	if _pulse_tweens.has(btn) and _pulse_tweens[btn] != null:
		_pulse_tweens[btn].kill()
	var tween := btn.create_tween()
	_pulse_tweens[btn] = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.06)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func bounce_button(btn: Button) -> void:
	if _pulse_tweens.has(btn) and _pulse_tweens[btn] != null:
		_pulse_tweens[btn].kill()
	var tween := btn.create_tween()
	_pulse_tweens[btn] = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", Vector2(0.85, 0.85), 0.05)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _highlight_step_number(step: int) -> void:
	if step < _step_number_labels.size():
		var lbl: Label = _step_number_labels[step]
		if lbl != null:
			lbl.add_theme_color_override("font_color", Color(0, 0.83, 1, 1.0))
			lbl.add_theme_font_size_override("font_size", 14)


func _unhighlight_step_number(step: int) -> void:
	if step < _step_number_labels.size():
		var lbl: Label = _step_number_labels[step]
		if lbl != null:
			var is_beat := step % 4 == 0
			lbl.add_theme_color_override("font_color",
				Color(0.58, 0.60, 0.92) if is_beat else Color(0.20, 0.20, 0.30))
			lbl.add_theme_font_size_override("font_size", 12)


func clear_highlight(rows: int, steps: int) -> void:
	if _prev_step != -1:
		for row in range(rows):
			if row < _buttons.size() and _prev_step < _buttons[row].size():
				_buttons[row][_prev_step].modulate = Color(1, 1, 1)
		_unhighlight_step_number(_prev_step)
	_prev_step = -1


func ripple_grid(rows: int, steps: int) -> void:
	for row in range(rows):
		if row >= _buttons.size():
			continue
		for step in range(steps):
			if step >= _buttons[row].size():
				continue
			var btn: Button = _buttons[row][step]
			var delay := (row * 0.03) + (step * 0.015)
			var tween := btn.create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
			tween.tween_property(btn, "scale", Vector2(0.7, 0.7), 0.04).set_delay(delay)
			tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
