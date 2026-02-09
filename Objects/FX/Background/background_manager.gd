class_name BackgroundManager
extends Node2D

@export var sky_texture_path: String = "res://Assets/Images/sky_bg.png"
@export var ground_texture_path: String = "res://Assets/Images/ground_bg.png"
@export var cloud_texture_path: String = "res://Assets/Images/clouds_bg.png"
@export var chunk_size: int = 960
# 0.0 = Attached to Camera (Static on Screen)
# 1.0 = Locked to World (Standard Foreground)
# 0.8 = Distant Background (Moves 20% with Camera, 80% relative to Camera)
@export var parallax_speed: float = 0.8
@export var cloud_auto_scroll_speed: float = 20.0 # Pixels per second

var _sky_tex: Texture2D
var _ground_tex: Texture2D
var _cloud_tex: Texture2D

var _active_sprites: Dictionary = {} # { Vector2i(x,y) : Sprite2D }
var _pool: Array[Sprite2D] = []

# Cloud specific storage
var _active_cloud_sprites: Dictionary = {} # { Vector2i(x,y) : Sprite2D }
var _cloud_pool: Array[Sprite2D] = []

var _cloud_scroll_x: float = 0.0

func _ready() -> void:
	# Render behind everything else
	z_index = -100
	
	if ResourceLoader.exists(sky_texture_path):
		_sky_tex = load(sky_texture_path)
	
	if ResourceLoader.exists(ground_texture_path):
		_ground_tex = load(ground_texture_path)
		
	if ResourceLoader.exists(cloud_texture_path):
		_cloud_tex = load(cloud_texture_path)

func _process(delta: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	
	var viewport_rect = get_viewport_rect()
	var zoom = cam.zoom
	var size = viewport_rect.size / zoom
	var center = cam.get_screen_center_position()
	
	# Update Cloud Scroll
	_cloud_scroll_x += cloud_auto_scroll_speed * delta
	# Wrap around to prevent infinite float growth
	if abs(_cloud_scroll_x) > chunk_size:
		_cloud_scroll_x -= sign(_cloud_scroll_x) * chunk_size
	
	# --- STANDARD LAYERS (Sky/Ground) ---
	if _sky_tex and _ground_tex:
		var buffer = chunk_size * 0.5
		var top_left = center - size / 2.0 - Vector2(buffer, buffer)
		var bottom_right = center + size / 2.0 + Vector2(buffer, buffer)
		
		# Offset inputs by 32 so Y=0 in logic aligns with Y=32 in world
		var start_x = floori(top_left.x / chunk_size)
		var end_x = floori(bottom_right.x / chunk_size)
		var start_y = floori((top_left.y - 32.0) / chunk_size)
		var end_y = floori((bottom_right.y - 32.0) / chunk_size)
		
		var needed_chunks = {}
		
		for x in range(start_x, end_x + 1):
			for y in range(start_y, end_y + 1):
				var idx = Vector2i(x, y)
				needed_chunks[idx] = true
				if not _active_sprites.has(idx):
					_create_chunk(idx)
		
		var current_indices = _active_sprites.keys()
		for idx in current_indices:
			if not needed_chunks.has(idx):
				_recycle_chunk(idx)

	# --- CLOUD LAYER (Parallax + Auto Scroll) ---
	if _cloud_tex:
		_process_clouds(center, size)

func _create_chunk(idx: Vector2i) -> void:
	var sprite: Sprite2D
	
	if not _pool.is_empty():
		sprite = _pool.pop_back()
		sprite.visible = true
	else:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
	
	sprite.position = Vector2(idx.x * chunk_size, idx.y * chunk_size + 32)
	
	# Logic: 
	# Index Y >= 0 is Ground (Starts at world Y=32)
	# Index Y < 0 is Sky
	
	if idx.y >= 0:
		sprite.texture = _ground_tex
		# Ground covers clouds
		sprite.z_index = -100
	else:
		sprite.texture = _sky_tex
		# Sky is behind clouds
		sprite.z_index = -102
		
	_active_sprites[idx] = sprite

func _recycle_chunk(idx: Vector2i) -> void:
	if _active_sprites.has(idx):
		var sprite = _active_sprites[idx]
		_active_sprites.erase(idx)
		sprite.visible = false
		_pool.append(sprite)

func _process_clouds(center: Vector2, size: Vector2) -> void:
	# Combined Offset: Camera Parallax + Continuous Scroll
	# With parallax_speed = 0.8:
	# Offset includes 20% of Camera X (Moves slowly with camera) + Scroll.
	# The rest (80%) is relative motion, making it feel detached from the player.
	var total_offset_x = (center.x * (1.0 - parallax_speed)) + _cloud_scroll_x
	
	# Transform view bounds into "Grid Space" by subtracting the total offset
	var buffer = chunk_size * 0.5
	var view_min_x = (center.x - size.x / 2.0) - total_offset_x
	var view_max_x = (center.x + size.x / 2.0) - total_offset_x
	
	var start_x = floori((view_min_x - buffer) / chunk_size)
	var end_x = floori((view_max_x + buffer) / chunk_size)
	
	# Vertical is world-locked (no vertical parallax requested)
	var top_y = center.y - size.y / 2.0
	var bottom_y = center.y + size.y / 2.0
	var start_y = floori((top_y - 32.0) / chunk_size)
	var end_y = floori((bottom_y - 32.0) / chunk_size)
	
	# Clamp Y: Clouds only appear in sky (Indices < 0)
	if end_y >= 0: end_y = -1
	
	var needed = {}
	
	if start_y <= end_y:
		for x in range(start_x, end_x + 1):
			for y in range(start_y, end_y + 1):
				var idx = Vector2i(x, y)
				needed[idx] = true
				
				var sprite: Sprite2D
				if _active_cloud_sprites.has(idx):
					sprite = _active_cloud_sprites[idx]
				else:
					sprite = _create_cloud_chunk(idx)
				
				# Update position based on combined offset
				sprite.position.x = idx.x * chunk_size + total_offset_x
				# Y position is fixed relative to world grid
				sprite.position.y = idx.y * chunk_size + 32

	# Recycle Clouds
	var keys = _active_cloud_sprites.keys()
	for k in keys:
		if not needed.has(k):
			_recycle_cloud(k)

func _create_cloud_chunk(idx: Vector2i) -> Sprite2D:
	var sprite: Sprite2D
	
	if not _cloud_pool.is_empty():
		sprite = _cloud_pool.pop_back()
		sprite.visible = true
	else:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
	
	sprite.texture = _cloud_tex
	# Clouds are between Sky (-102) and Ground (-100)
	sprite.z_index = -101
	
	_active_cloud_sprites[idx] = sprite
	return sprite

func _recycle_cloud(idx: Vector2i) -> void:
	if _active_cloud_sprites.has(idx):
		var sprite = _active_cloud_sprites[idx]
		_active_cloud_sprites.erase(idx)
		sprite.visible = false
		_cloud_pool.append(sprite)