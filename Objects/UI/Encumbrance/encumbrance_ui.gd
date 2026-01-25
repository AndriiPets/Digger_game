class_name EncumbranceUI
extends CanvasLayer

@onready var progress_bar: ProgressBar = $Control/ProgressBar
@onready var label: Label = $Control/ProgressBar/Label

func update_display(current: float, maximum: float) -> void:
	progress_bar.max_value = maximum
	progress_bar.value = current
	
	label.text = "%.1f / %.1f kg" % [current, maximum]
	
	# Visual feedback: Turn red if full
	if current >= maximum:
		progress_bar.modulate = Color(1, 0.3, 0.3)
	else:
		progress_bar.modulate = Color.WHITE
