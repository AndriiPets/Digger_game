class_name EnergyUI
extends CanvasLayer

@onready var progress_bar: ProgressBar = $Control/ProgressBar
@onready var value_label: Label = $Control/Label

func update_energy(current: float, maximum: float) -> void:
	progress_bar.max_value = maximum
	progress_bar.value = current
	
	# UPDATED: Use ceil() so 0.5 shows as 1, ensuring "0" truly means empty.
	var display_val = ceil(current)
	if display_val == 0 and current > 0: display_val = 1 # Safety clamp
	if current <= 0: display_val = 0
	
	value_label.text = "%d / %d" % [int(display_val), int(maximum)]