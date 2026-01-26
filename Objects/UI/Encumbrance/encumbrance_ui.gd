class_name EncumbranceUI
extends CanvasLayer

@onready var progress_bar: ProgressBar = $Control/ProgressBar
@onready var label: Label = $Control/ProgressBar/Label

func update_display(current: float, maximum: float) -> void:
	progress_bar.max_value = maximum
	progress_bar.value = current
	
	label.text = "%.1f / %.1f kg" % [current, maximum]
	
	# Calculate ratio safely
	var ratio: float = 0.0
	if maximum > 0:
		ratio = current / maximum
	
	# Color Logic based on encumbrance state
	if ratio > 0.85:
		# Heavy Encumbrance (> 85%)
		progress_bar.modulate = Color(1, 0.2, 0.2) # Red
	elif ratio > 0.70:
		# Medium Encumbrance (70% - 85%)
		progress_bar.modulate = Color(1, 1, 0.2) # Yellow
	else:
		# Light Encumbrance (0% - 70%)
		progress_bar.modulate = Color.WHITE