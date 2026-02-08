class_name GameCamera
extends Camera2D

# Exports
@export var target: Node2D
@export var smooth_speed: float = 10.0
@export var offset_position: Vector2 = Vector2.ZERO

# NEW: Shake Settings
@export var shake_decay: float = 5.0
@export var max_offset: Vector2 = Vector2(10, 10)

var _shake_strength: float = 0.0

func _ready() -> void:
	make_current()
	add_to_group("game_camera") # Ensure VFXManager can find this
	
	# If no target assigned manually, try to find the player
	if not target:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target = players[0] as Node2D
			global_position = target.global_position

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
		
	# 1. Follow Target
	global_position = target.global_position + offset_position
	
	# 2. Handle Shake Decay
	if _shake_strength > 0:
		_shake_strength = move_toward(_shake_strength, 0, shake_decay * delta)
		
		# Apply random offset based on strength
		offset = Vector2(
			randf_range(-_shake_strength, _shake_strength) * max_offset.x,
			randf_range(-_shake_strength, _shake_strength) * max_offset.y
		)
	else:
		offset = Vector2.ZERO

# NEW: API called by VFXManager
func apply_shake(strength: float) -> void:
	# specific strength overrides current only if it's higher
	_shake_strength = max(_shake_strength, strength)