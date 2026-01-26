class_name MoneyUI
extends CanvasLayer

@onready var label: Label = $Control/Panel/Label

func update_money(amount: int) -> void:
	label.text = "$ %d" % amount
