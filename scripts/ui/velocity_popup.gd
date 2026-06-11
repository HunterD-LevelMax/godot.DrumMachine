## velocity_popup.gd
## Self-contained velocity chooser popup shown on long-press of a step button.
## Static structure (buttons, layout) defined in scenes/ui/velocity_popup.tscn.
## Row-specific colours are applied at runtime since they depend on which row was pressed.
## Emits velocity_chosen(row, step, velocity) when the user picks an option.
class_name VelocityPopup
extends PanelContainer

signal velocity_chosen(row: int, step: int, velocity: int)

var _row:  int
var _step: int


func setup(row: int, step: int, current_velocity: int) -> void:
	_row  = row
	_step = step

	# Row-specific panel background (colour depends on which row was pressed).
	add_theme_stylebox_override("panel", DrumTheme.velocity_popup_bg(row))

	var color := DrumTheme.row_color(row)
	%Title.add_theme_color_override("font_color", color.darkened(0.25))
	%Sep.modulate = Color(color.r, color.g, color.b, 0.35)

	var btns: Array[Button] = [%Btn0, %Btn1, %Btn2, %Btn3, %Btn4]
	for v in range(5):
		var btn: Button = btns[v]
		var styles := DrumTheme.velocity_button_styles(v, current_velocity, row)
		btn.add_theme_stylebox_override("normal",  styles[0])
		btn.add_theme_stylebox_override("hover",   styles[1])
		btn.add_theme_stylebox_override("pressed", styles[0])
		if v == current_velocity:
			btn.add_theme_color_override("font_color", color)
		elif v == 0:
			btn.add_theme_color_override("font_color", Color(0.75, 0.28, 0.28))
		else:
			btn.add_theme_color_override("font_color", color.darkened(0.35 - (v / 4.0) * 0.15))
		btn.pressed.connect(_on_velocity_chosen.bind(v))


func position_near(btn_rect: Rect2, viewport_size: Vector2) -> void:
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var pop_sz := size
	var px := btn_rect.position.x + btn_rect.size.x * 0.5 - pop_sz.x * 0.5
	var py := btn_rect.position.y - pop_sz.y - 12.0
	if py < 8.0:
		py = btn_rect.position.y + btn_rect.size.y + 12.0
	global_position = Vector2(
		clampf(px, 8.0, viewport_size.x - pop_sz.x - 8.0),
		clampf(py, 8.0, viewport_size.y - pop_sz.y - 8.0)
	)
	scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)


func _on_velocity_chosen(v: int) -> void:
	velocity_chosen.emit(_row, _step, v)
