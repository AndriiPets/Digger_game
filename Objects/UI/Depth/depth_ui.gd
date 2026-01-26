class_name DepthUI
extends CanvasLayer

@onready var label: Label = $Control/Panel/Label

func update_depth(depth: int) -> void:
	# Ensure we don't show negative depth if player jumps high
	var display_val = max(0, depth)
	label.text = "Depth: %d m" % display_val
