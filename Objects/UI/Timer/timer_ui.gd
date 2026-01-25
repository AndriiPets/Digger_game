class_name TimerUI
extends CanvasLayer

@onready var timer_label: Label = $Control/TimerContainer/TimerLabel

func update_timer(time_left: float) -> void:
	time_left = max(0.0, time_left)
	var minutes := int(time_left / 60)
	var seconds := int(time_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	if time_left <= 10.0:
		timer_label.modulate = Color(1, 0.3, 0.3)
	else:
		timer_label.modulate = Color.WHITE

# New helper function
func set_timer_visible(is_visible: bool) -> void:
	visible = is_visible