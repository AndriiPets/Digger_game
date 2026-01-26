class_name TileDefinition
extends Resource

@export_group("Visuals")
@export var display_name: String = "Dirt"
@export var atlas_coords: Vector2i = Vector2i(0, 0)
@export var color_tint: Color = Color.WHITE

@export_group("Gameplay")
@export var max_health: int = 3
@export var weight: float = 1.0
@export var base_value: int = 1 # <--- NEW VALUE
@export var is_diggable: bool = true

@export_group("Drops")
@export var drop_scene: PackedScene
@export var min_drops: int = 1
@export var max_drops: int = 3
@export var drop_chance: float = 1.0