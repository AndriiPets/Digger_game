class_name BlockParticles
extends CPUParticles2D

func _ready() -> void:
	# Ensure the node cleans itself up after emission is done
	finished.connect(queue_free)

func setup(texture_atlas: Texture2D, atlas_coords: Vector2i, grid_size: int) -> void:
	# Create a unique AtlasTexture for this particle system
	# This allows us to use the specific tile graphic from the main tileset
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = texture_atlas
	atlas_tex.region = Rect2(atlas_coords * grid_size, Vector2(grid_size, grid_size))
	
	texture = atlas_tex
	emitting = true
