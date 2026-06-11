## help_popup.gd
## Floating popup with gameplay tips.
## Structure defined in scenes/ui/help_popup.tscn.
## Tip cards are scenes/ui/tip_card.tscn instances.
class_name HelpPopup
extends PanelContainer

signal close_requested

const TIP_CARD_SCENE := preload("res://scenes/ui/tip_card.tscn")

const TIPS: Array[Dictionary] = [
	{ "title": "TAP A PAD",          "body": "Cycles velocity:  OFF → LOW → MED → HIGH → MAX" },
	{ "title": "HOLD A PAD",         "body": "Long-press to open the velocity picker and set it precisely" },
	{ "title": "♪  BUTTON",          "body": "Tap to change the sound sample for that track" },
	{ "title": "MUTE BUTTON",        "body": "Tap KICK / SNARE / HAT / BASS to mute or unmute a track" },
	{ "title": "TAP BUTTON",         "body": "Tap to the beat — tempo is calculated from your tapping rhythm" },
	{ "title": "+/- STEPS",          "body": "Adjust the number of steps per loop (4 to 64)" },
	{ "title": "SLOTS  A B C D",     "body": "Select a slot, then tap SAVE to store or LOAD to restore a pattern" },
	{ "title": "KEYBOARD SHORTCUTS", "body": "Space = Play/Stop     1-4 = Preview sounds     Ctrl+Z / Y = Undo/Redo" },
]


func _ready() -> void:
	%CloseBtn.pressed.connect(func() -> void: close_requested.emit())
	var list: VBoxContainer = %TipsList
	for tip: Dictionary in TIPS:
		var card: TipCard = TIP_CARD_SCENE.instantiate()
		list.add_child(card)
		card.setup(tip["title"], tip["body"])
	DrumTheme.style_scrollbar(list.get_parent() as ScrollContainer)


func position_near(viewport_size: Vector2) -> void:
	var w := 460.0
	var h := 540.0
	custom_minimum_size = Vector2(w, h)
	position = Vector2(
		clampf((viewport_size.x - w) * 0.5, 4.0, viewport_size.x - w - 4.0),
		clampf((viewport_size.y - h) * 0.5, 4.0, viewport_size.y - h - 4.0)
	)
