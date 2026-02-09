class_name DeathUI
extends CanvasLayer

signal confirm_pressed

#@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open() -> void:
	visible = true
	get_tree().paused = true
	# Optional: play simple tween or animation if added later

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ACTION"): # Z Key
		get_tree().paused = false
		visible = false
		confirm_pressed.emit()
		get_viewport().set_input_as_handled()
