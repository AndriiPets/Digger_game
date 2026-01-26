class_name DarknessOverlay
extends CanvasLayer

@export var base_radius: float = 128.0
@export var flicker_intensity: float = 2.0

@onready var color_rect: ColorRect = $ColorRect

var _player: Node2D
var _upgrade_multiplier: float = 1.0

func _ready() -> void:
	# Find player automatically
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]

func _process(_delta: float) -> void:
	if not is_instance_valid(_player): return
	
	var mat = color_rect.material as ShaderMaterial
	if not mat: return
	
	# 1. Calculate Player Screen Position
	# We use the canvas transform to convert World Pos -> Screen Pos
	var canvas_transform = _player.get_canvas_transform()
	var player_screen = canvas_transform * _player.global_position
	
	# 2. Calculate Surface Y Screen Position (World Y = 0)
	var surface_screen_pos = canvas_transform * Vector2(0, 0)
	
	# 3. Calculate Flicker
	var jitter = randf_range(-flicker_intensity, flicker_intensity)
	var final_radius = (base_radius * _upgrade_multiplier) + jitter
	
	# 4. Update Shader
	mat.set_shader_parameter("player_screen_pos", player_screen)
	mat.set_shader_parameter("radius", final_radius)
	mat.set_shader_parameter("surface_y_screen", surface_screen_pos.y)

# API for Upgrades
func increase_radius(multiplier: float) -> void:
	_upgrade_multiplier += multiplier
