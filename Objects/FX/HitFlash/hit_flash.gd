class_name VFXHitFlash
extends Sprite2D

@export var flash_duration: float = 0.15
@export_range(0.0, 1.0) var peak_intensity: float = 1.5

func setup(atlas: Texture2D, coords: Vector2i, grid_size: int) -> void:
	# Create an AtlasTexture on the fly to mimic the specific tile
	var new_tex = AtlasTexture.new()
	new_tex.atlas = atlas
	new_tex.region = Rect2(coords * grid_size, Vector2(grid_size, grid_size))
	
	texture = new_tex
	
	# Start the flash animation
	_animate()

func _animate() -> void:
	var mat = material as ShaderMaterial
	if not mat: return
	
	mat.set_shader_parameter("flash_intensity", peak_intensity)

	var tween = create_tween()
	tween.tween_method(
		func(val): mat.set_shader_parameter("flash_intensity", val),
		peak_intensity,
		0.0,
		flash_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	tween.tween_callback(queue_free)