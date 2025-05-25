extends Control

const ROWS := 4
const STEPS := 8
const DEFAULT_TEMPO := 120  # beats per minute

var tempo := DEFAULT_TEMPO
var current_step := 0
var grid := []
var buttons := []

@onready var timer := $Timer
@onready var step_grid := $StepGrid
@onready var kick_player := $KickPlayer
@onready var snare_player := $SnarePlayer
@onready var hat_player := $HatPlayer
@onready var bass_player := $BassPlayer

@onready var increase_tempo_button := $IncreaseTempoButton
@onready var decrease_tempo_button := $DecreaseTempoButton
@onready var tempo_label := $TempoLabel

func _ready():
	for row in range(ROWS):
		grid.append([])
		buttons.append([])
		for step in range(STEPS):
			grid[row].append(false)
			var btn = Button.new()
			btn.text = ""
			btn.focus_mode = Control.FOCUS_NONE
			btn.connect("pressed", _on_step_pressed.bind(row, step))
			step_grid.add_child(btn)
			buttons[row].append(btn)
			_update_button_visual(btn, false, row, step)

	_update_timer()
	timer.connect("timeout", _on_timer_timeout)
	timer.start()

	increase_tempo_button.connect("pressed", _on_increase_tempo)
	decrease_tempo_button.connect("pressed", _on_decrease_tempo)
	_update_tempo_label()

func _on_step_pressed(row: int, step: int):
	grid[row][step] = !grid[row][step]
	_update_button_visual(buttons[row][step], grid[row][step], row, step)

func _on_timer_timeout():
	for row in range(ROWS):
		if grid[row][current_step]:
			match row:
				0: kick_player.play()
				1: snare_player.play()
				2: hat_player.play()
				3: bass_player.play()

	_highlight_step(current_step)
	current_step = (current_step + 1) % STEPS

func _highlight_step(step_index):
	for row in range(ROWS):
		for col in range(STEPS):
			var btn = buttons[row][col]
			var is_active = grid[row][col]

			if col == step_index:
				btn.modulate = Color(1.0, 1.0, 0.4) if is_active else Color(0.5, 0.5, 0.5)
			else:
				btn.modulate = Color(1, 1, 1)
				_update_button_visual(btn, is_active, row, col)

func _update_button_visual(btn: Button, active: bool, row := 0, col := 0):
	var style := StyleBoxFlat.new()
	var top_color := Color(0.2 + row * 0.2, 0.3 + col * 0.08, 0.6)
	var base_color := top_color if active else top_color.darkened(0.4)

	style.bg_color = base_color
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.2)

	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", style)
	theme.set_stylebox("hover", "Button", style)
	theme.set_stylebox("pressed", "Button", style)

	btn.theme = theme
	btn.custom_minimum_size = Vector2(100, 100)

# === Tempo Management ===

func _on_increase_tempo():
	tempo += 10
	_update_timer()
	_update_tempo_label()

func _on_decrease_tempo():
	tempo = max(30, tempo - 10)
	_update_timer()
	_update_tempo_label()

func _update_timer():
	timer.wait_time = 60.0 / tempo / 2

func _update_tempo_label():
	tempo_label.text = "Tempo: %d BPM" % tempo
