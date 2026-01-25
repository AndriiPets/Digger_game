class_name FloatingText
extends Node2D

@onready var label: Label = $Label

func setup(text: String, start_pos: Vector2, color: Color = Color.WHITE) -> void:
	global_position = start_pos
	label.text = text
	label.modulate = color
	
	_animate()

func _animate() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. Move Upward (50 pixels over 1 second)
	tween.tween_property(self, "global_position:y", global_position.y - 50.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 2. Fade Out (Start fading after 0.5s)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(0.2)
	
	# 3. Destroy self when done
	tween.chain().tween_callback(queue_free)
