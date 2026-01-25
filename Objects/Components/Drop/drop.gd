class_name ItemDrop
extends Area2D

# Config
@export var acceleration: float = 800.0
@export var max_speed: float = 400.0
@export var scatter_force: float = 150.0

# State
var _target: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _collect_phase: bool = false
var _resource_type: TileDefinition

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Find player automatically
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_target = players[0]
	
	# Connect collision
	body_entered.connect(_on_body_entered)
	
	# Initial "Pop" direction (Scatter)
	var random_angle = randf() * TAU
	_velocity = Vector2(cos(random_angle), sin(random_angle)) * scatter_force
	
	# Wait a fraction of a second before flying to player
	await get_tree().create_timer(0.35).timeout
	_collect_phase = true

func setup(type: TileDefinition, texture_atlas: Texture2D) -> void:
	_resource_type = type
	
	# Setup visual based on the block definition
	if sprite and texture_atlas:
		sprite.texture = texture_atlas
		# Create an AtlasTexture on the fly to crop just the specific tile
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = texture_atlas
		# Assuming 32x32 grid size, grab the rect
		var region = Rect2(type.atlas_coords * 32, Vector2(32, 32))
		atlas_tex.region = region
		sprite.texture = atlas_tex
		
		# Scale down slightly so it looks like a "chunk"
		sprite.scale = Vector2(0.5, 0.5)

func _physics_process(delta: float) -> void:
	if _collect_phase and is_instance_valid(_target):
		# Magnet behavior
		var direction = global_position.direction_to(_target.global_position)
		_velocity += direction * acceleration * delta
		_velocity = _velocity.limit_length(max_speed)
	else:
		# Friction during scatter phase
		_velocity = _velocity.move_toward(Vector2.ZERO, 5.0)
	
	global_position += _velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.collect_item(_resource_type)
		queue_free()