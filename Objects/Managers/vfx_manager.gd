extends Node

# Dictionary to store preloaded scenes for different effect types
var _effect_scenes: Dictionary = {}

# Paths to effect scenes
const HIT_FLASH_PATH = "res://Objects/FX/HitFlash/HitFlash.tscn"
# Add more effects here in the future, e.g. const SMOKE_PATH = "..."

func _ready() -> void:
	# Preload scenes to avoid stutter during gameplay
	_effect_scenes["hit_flash"] = load(HIT_FLASH_PATH)

# --- Generic Spawner ---

func spawn_effect_scene(key: String, position: Vector2, parent: Node = null) -> Node:
	if not _effect_scenes.has(key) or not _effect_scenes[key]:
		push_warning("VFXManager: Effect '%s' not found or invalid." % key)
		return null
		
	var instance = _effect_scenes[key].instantiate()
	
	if parent:
		parent.add_child(instance)
	else:
		# Default to current scene if no parent specified
		get_tree().current_scene.add_child(instance)
		
	if instance is Node2D:
		instance.global_position = position
		
	return instance

# --- Specific Effect Helpers ---

# Helper for the Tile Hit Flash
func play_tile_hit_effect(global_pos: Vector2, atlas: Texture2D, coords: Vector2i, grid_size: int) -> void:
	var effect = spawn_effect_scene("hit_flash", global_pos)
	
	if effect and effect.has_method("setup"):
		effect.setup(atlas, coords, grid_size)