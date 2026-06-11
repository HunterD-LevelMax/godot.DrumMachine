## tip_card.gd
## Single tip card instantiated inside help_popup's TipsList.
class_name TipCard
extends PanelContainer


func setup(title: String, body: String) -> void:
	(%TitleLabel as Label).text = title
	(%BodyLabel as Label).text  = body
