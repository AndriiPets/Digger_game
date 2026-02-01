class_name MoneyUI
extends CanvasLayer

@onready var panel: Panel = $Control/Panel
@onready var label: Label = $Control/Panel/Label

# Define colors
# Green (Original from Tscn)
var _color_positive: Color = Color(0.1, 0.4, 0.1, 0.8)
# Red (For debt)
var _color_negative: Color = Color(0.6, 0.1, 0.1, 0.8)

func update_money(amount: int) -> void:
	label.text = "$ %d" % amount
	# Ensure font stays white (reverting previous change if necessary)
	label.modulate = Color.WHITE
	
	# Get the StyleBoxFlat to modify the background color
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if amount < 0:
			style.bg_color = _color_negative
		else:
			style.bg_color = _color_positive