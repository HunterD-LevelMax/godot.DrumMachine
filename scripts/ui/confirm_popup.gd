## confirm_popup.gd
## Generic confirmation popup with a message and CANCEL / CONFIRM buttons.
## Structure defined in scenes/ui/confirm_popup.tscn.
## Emits confirmed() when the user accepts.
class_name ConfirmPopup
extends PanelContainer

signal confirmed()


func setup(title: String, body: String, confirm_label: String) -> void:
	(%Title  as Label).text  = title
	(%Body   as Label).text  = body
	(%OkBtn  as Button).text = confirm_label
	(%OkBtn  as Button).pressed.connect(func() -> void: confirmed.emit())
	(%CancelBtn as Button).pressed.connect(func() -> void: queue_free())


func position_near(viewport_size: Vector2) -> void:
	await get_tree().process_frame
	var sz := size
	position = Vector2(
		clampf((viewport_size.x - sz.x) * 0.5, 4.0, viewport_size.x - sz.x - 4.0),
		clampf((viewport_size.y - sz.y) * 0.5, 4.0, viewport_size.y - sz.y - 4.0)
	)
