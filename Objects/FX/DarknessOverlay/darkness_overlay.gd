class_name DarknessOverlay
extends CanvasLayer

@export var base_radius: float = 128.0
@export var flicker_intensity: float = 2.0
@export var max_darkness_depth: float = 100.0 # Depth (in meters) where darkness is 100%

@onready var color_rect: ColorRect = $ColorRect

var _player: Node2D
var _upgrade_multiplier: float = 1.0
const GRID_SIZE: float = 32.0

func _ready() -> void:
	# Find player automatically
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	
	# Start invisible
	color_rect.modulate.a = 0.0

func _process(_delta: float) -> void:
	if not is_instance_valid(_player): return
	
	var mat = color_rect.material as ShaderMaterial
	if not mat: return
	
	# 1. Calculate Player Screen Position
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

	# 5. Calculate Depth Opacity
	# Convert World Y pixels to Meters (32 pixels per meter)
	var current_depth_m = max(0.0, _player.global_position.y / GRID_SIZE)
	
	# Calculate ratio (0.0 at surface, 1.0 at 100m)
	var alpha_ratio = clampf(current_depth_m / max_darkness_depth, 0.0, 1.0)
	
	# Apply opacity to the rect. 
	# Because we updated the shader to use * COLOR.a, this now fades the blackness.
	color_rect.modulate.a = alpha_ratio

func increase_radius(multiplier: float) -> void:
	_upgrade_multiplier += multiplier