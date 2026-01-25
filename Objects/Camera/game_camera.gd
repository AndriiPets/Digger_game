class_name GameCamera
extends Camera2D

# Exports
@export var target: Node2D
@export var smooth_speed: float = 10.0
@export var offset_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	make_current()
	
	# If no target assigned manually, try to find the player
	if not target:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target = players[0] as Node2D
			# Snap immediately to target on start to avoid swooping
			global_position = target.global_position

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
		
	# Simple interpolation towards target
	# We use code-based smoothing or enable "Position Smoothing" in the Inspector
	# Here we simply set the position and let the built-in properties handle smoothing
	# if enabled, or exact tracking if not.
	global_position = target.global_position + offset_position
