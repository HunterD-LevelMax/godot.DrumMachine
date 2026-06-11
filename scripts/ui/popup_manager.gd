## popup_manager.gd
## Manages all popup windows: velocity, sound picker, help, confirm.
class_name PopupManager
extends RefCounted

const VELOCITY_POPUP_SCENE = preload("res://scenes/ui/velocity_popup.tscn")
const SOUND_PICKER_SCENE   = preload("res://scenes/ui/sound_picker.tscn")
const HELP_POPUP_SCENE     = preload("res://scenes/ui/help_popup.tscn")
const CONFIRM_POPUP_SCENE  = preload("res://scenes/ui/confirm_popup.tscn")

var velocity_popup:          VelocityPopup   = null
var popup_backdrop:          ColorRect       = null
var sound_picker:            SoundPicker     = null
var sound_picker_backdrop:   ColorRect       = null
var help_popup:              HelpPopup       = null
var help_popup_backdrop:     ColorRect       = null
var confirm_popup:           ConfirmPopup    = null
var confirm_popup_backdrop:  ColorRect       = null

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

func open_velocity(row: int, step: int, velocity: int, btn: Button, on_chosen: Callable) -> void:
	close_velocity()
	popup_backdrop = _create_backdrop(10, close_velocity)
	var popup: VelocityPopup = VELOCITY_POPUP_SCENE.instantiate()
	popup.velocity_chosen.connect(on_chosen)
	_owner.add_child(popup)
	popup.setup(row, step, velocity)
	popup.position_near(btn.get_global_rect(), _owner.get_viewport_rect().size)
	velocity_popup = popup


func close_velocity() -> void:
	if is_instance_valid(velocity_popup):
		velocity_popup.queue_free()
	if is_instance_valid(popup_backdrop):
		popup_backdrop.queue_free()
	velocity_popup = null
	popup_backdrop = null


# ── Sound picker ──────────────────────────────────────────────────────────────

func open_sound_picker(row: int, sound_path: String, anchor_btn: Button, on_selected: Callable) -> void:
	close_sound_picker()
	sound_picker_backdrop = _create_backdrop(10, close_sound_picker)
	var picker: SoundPicker = SOUND_PICKER_SCENE.instantiate()
	picker.z_index = 11
	picker.sound_selected.connect(on_selected)
	_owner.add_child(picker)
	picker.setup(row, sound_path)
	picker.position_near(anchor_btn.get_global_rect(), _owner.get_viewport_rect().size)
	picker.scale = Vector2(0.85, 0.85)
	picker.modulate.a = 0.0
	var tween := picker.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(picker, "scale", Vector2.ONE, 0.2)
	tween.tween_property(picker, "modulate:a", 1.0, 0.14)
	sound_picker = picker


func close_sound_picker() -> void:
	if is_instance_valid(sound_picker):
		sound_picker.queue_free()
	if is_instance_valid(sound_picker_backdrop):
		sound_picker_backdrop.queue_free()
	sound_picker = null
	sound_picker_backdrop = null


# ── Confirm popup ─────────────────────────────────────────────────────────────

func open_confirm(title: String, body: String, ok_label: String, on_confirm: Callable) -> void:
	close_confirm()
	confirm_popup_backdrop = _create_backdrop(20)
	confirm_popup_backdrop.color = Color(0, 0, 0, 0.55)
	var popup: ConfirmPopup = CONFIRM_POPUP_SCENE.instantiate()
	popup.z_index = 21
	popup.confirmed.connect(on_confirm)
	popup.tree_exited.connect(close_confirm)
	_owner.add_child(popup)
	popup.setup(title, body, ok_label)
	popup.position_near(_owner.get_viewport_rect().size)
	popup.scale = Vector2(0.85, 0.85)
	popup.modulate.a = 0.0
	var tween := popup.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.2)
	tween.tween_property(popup, "modulate:a", 1.0, 0.14)
	confirm_popup = popup


func close_confirm() -> void:
	if is_instance_valid(confirm_popup):
		confirm_popup.queue_free()
	if is_instance_valid(confirm_popup_backdrop):
		confirm_popup_backdrop.queue_free()
	confirm_popup = null
	confirm_popup_backdrop = null


# ── Help popup ────────────────────────────────────────────────────────────────

func open_help() -> void:
	if help_popup != null:
		close_help()
		return
	help_popup_backdrop = _create_backdrop(10, close_help)
	var popup: HelpPopup = HELP_POPUP_SCENE.instantiate()
	popup.z_index = 11
	popup.get_node("Margin/VBox/TitleRow/CloseBtn").pressed.connect(close_help)
	_owner.add_child(popup)
	popup.position_near(_owner.get_viewport_rect().size)
	popup.scale = Vector2(0.85, 0.85)
	popup.modulate.a = 0.0
	var tween := popup.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.2)
	tween.tween_property(popup, "modulate:a", 1.0, 0.14)
	help_popup = popup


func close_help() -> void:
	if is_instance_valid(help_popup):
		help_popup.queue_free()
	if is_instance_valid(help_popup_backdrop):
		help_popup_backdrop.queue_free()
	help_popup = null
	help_popup_backdrop = null
