## popup_manager.gd
## Manages all popup windows: velocity, sound picker, help, confirm.
class_name PopupManager
extends RefCounted

signal velocity_chosen(row: int, step: int, velocity: int)
signal sound_selected(row: int, path: String)

const VELOCITY_POPUP_SCENE = preload("res://scenes/ui/velocity_popup.tscn")
const SOUND_PICKER_SCENE   = preload("res://scenes/ui/sound_picker.tscn")
const HELP_POPUP_SCENE     = preload("res://scenes/ui/help_popup.tscn")
const CONFIRM_POPUP_SCENE  = preload("res://scenes/ui/confirm_popup.tscn")

var _velocity_popup: VelocityPopup = null
var _velocity_backdrop: ColorRect = null
var _sound_picker: SoundPicker = null
var _sound_picker_backdrop: ColorRect = null
var _help_popup: HelpPopup = null
var _help_popup_backdrop: ColorRect = null
var _confirm_popup: ConfirmPopup = null
var _confirm_popup_backdrop: ColorRect = null

var _owner: Control


func setup(owner: Control) -> void:
	_owner = owner


# ── Backdrop helper ───────────────────────────────────────────────────────────

func _create_backdrop(z: int, close_callable: Callable = Callable()) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.01)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.z_index = z
	if close_callable.is_valid():
		backdrop.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or \
			   (e is InputEventScreenTouch and e.pressed):
				close_callable.call()
		)
	_owner.add_child(backdrop)
	return backdrop


# ── Velocity popup ────────────────────────────────────────────────────────────

func open_velocity(row: int, step: int, velocity: int, btn: Button) -> void:
	close_velocity()
	_velocity_backdrop = _create_backdrop(10, close_velocity)
	var popup: VelocityPopup = VELOCITY_POPUP_SCENE.instantiate()
	popup.velocity_chosen.connect(func(chosen_row: int, chosen_step: int, chosen_velocity: int) -> void:
		velocity_chosen.emit(chosen_row, chosen_step, chosen_velocity)
	)
	_owner.add_child(popup)
	popup.setup(row, step, velocity)
	popup.position_near(btn.get_global_rect(), _owner.get_viewport_rect().size)
	_velocity_popup = popup


func close_velocity() -> void:
	if is_instance_valid(_velocity_popup):
		_velocity_popup.queue_free()
	if is_instance_valid(_velocity_backdrop):
		_velocity_backdrop.queue_free()
	_velocity_popup = null
	_velocity_backdrop = null


func has_velocity_popup() -> bool:
	return is_instance_valid(_velocity_popup)


# ── Sound picker ──────────────────────────────────────────────────────────────

func open_sound_picker(row: int, sound_path: String, anchor_btn: Button) -> void:
	close_sound_picker()
	_sound_picker_backdrop = _create_backdrop(10, close_sound_picker)
	var picker: SoundPicker = SOUND_PICKER_SCENE.instantiate()
	picker.z_index = 11
	picker.sound_selected.connect(func(selected_row: int, path: String) -> void:
		sound_selected.emit(selected_row, path)
	)
	_owner.add_child(picker)
	picker.setup(row, sound_path)
	picker.position_near(anchor_btn.get_global_rect(), _owner.get_viewport_rect().size)
	_animate_open(picker)
	_sound_picker = picker


func close_sound_picker() -> void:
	if is_instance_valid(_sound_picker):
		_sound_picker.queue_free()
	if is_instance_valid(_sound_picker_backdrop):
		_sound_picker_backdrop.queue_free()
	_sound_picker = null
	_sound_picker_backdrop = null


# ── Confirm popup ─────────────────────────────────────────────────────────────

func open_confirm(title: String, body: String, ok_label: String, on_confirm: Callable) -> void:
	close_confirm()
	_confirm_popup_backdrop = _create_backdrop(20)
	_confirm_popup_backdrop.color = Color(0, 0, 0, 0.55)
	var popup: ConfirmPopup = CONFIRM_POPUP_SCENE.instantiate()
	popup.z_index = 21
	popup.confirmed.connect(on_confirm)
	popup.cancelled.connect(close_confirm)
	_owner.add_child(popup)
	popup.setup(title, body, ok_label)
	popup.position_near(_owner.get_viewport_rect().size)
	_animate_open(popup)
	_confirm_popup = popup


func close_confirm() -> void:
	if is_instance_valid(_confirm_popup):
		_confirm_popup.queue_free()
	if is_instance_valid(_confirm_popup_backdrop):
		_confirm_popup_backdrop.queue_free()
	_confirm_popup = null
	_confirm_popup_backdrop = null


# ── Help popup ────────────────────────────────────────────────────────────────

func open_help() -> void:
	if is_instance_valid(_help_popup):
		close_help()
		return
	_help_popup_backdrop = _create_backdrop(10, close_help)
	var popup: HelpPopup = HELP_POPUP_SCENE.instantiate()
	popup.z_index = 11
	popup.close_requested.connect(close_help)
	_owner.add_child(popup)
	popup.position_near(_owner.get_viewport_rect().size)
	_animate_open(popup)
	_help_popup = popup


func close_help() -> void:
	if is_instance_valid(_help_popup):
		_help_popup.queue_free()
	if is_instance_valid(_help_popup_backdrop):
		_help_popup_backdrop.queue_free()
	_help_popup = null
	_help_popup_backdrop = null


func _animate_open(control: Control) -> void:
	control.scale = Vector2(0.85, 0.85)
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, 0.2)
	tween.tween_property(control, "modulate:a", 1.0, 0.14)
