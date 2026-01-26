class_name TerrainManager
extends Node2D

signal block_broken(grid_pos: Vector2i, type: TileDefinition)

enum DigStatus {NONE, HIT, DESTROYED}

# --- Configuration ---
@export_category("Map Settings")
@export var grid_size: int = 32
@export var map_width: int = 25
@export var map_height: int = 250
@export var tile_texture_atlas: Texture2D

@export_category("Layer Configuration")
@export var terrain_layers: Array[TerrainLayer] = []
@export var bedrock_definition: TileDefinition

@export_category("Global Settings")
@export var global_resource_chance: float = 0.2
@export var resource_hp_bonus: int = 2

# --- Internal State ---
@onready var _tile_map: TileMapLayer = $TileMapLayer
const SOURCE_ID: int = 0

@export var default_drop_scene: PackedScene
@export var block_break_particles_scene: PackedScene

# OPTIMIZATION: Store health as integers mapped to coordinates, not Nodes
var _tile_health: Dictionary = {} # { Vector2i: int }
var _tile_data_map: Dictionary = {} # { Vector2i: TileDefinition }
var _cached_definitions: Array[TileDefinition] = []

func _ready() -> void:
	_tile_map.show_behind_parent = true
	_cache_all_definitions()
	
	if _cached_definitions.is_empty() or not tile_texture_atlas:
		push_error("TerrainManager: Missing Config!")
		return
		
	_setup_tileset()
	regenerate_map()

func _cache_all_definitions() -> void:
	_cached_definitions.clear()
	if bedrock_definition:
		_cached_definitions.append(bedrock_definition)
	
	for layer in terrain_layers:
		var blocks = layer.get_all_blocks()
		for b in blocks:
			if not _cached_definitions.has(b):
				_cached_definitions.append(b)

func _setup_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(grid_size, grid_size)
	
	tile_set.add_physics_layer(0)
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)
	
	var source := TileSetAtlasSource.new()
	source.texture = tile_texture_atlas
	source.texture_region_size = Vector2i(grid_size, grid_size)
	tile_set.add_source(source, SOURCE_ID)
	
	for def in _cached_definitions:
		if not source.has_tile(def.atlas_coords):
			source.create_tile(def.atlas_coords)
		var td = source.get_tile_data(def.atlas_coords, 0)
		td.modulate = def.color_tint
		_add_collision_to_tile(td)
		
	_tile_map.tile_set = tile_set

func _add_collision_to_tile(tile_data: TileData) -> void:
	var s: float = float(grid_size) / 2.0
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, [
		Vector2(-s, -s),
		Vector2(s, -s),
		Vector2(s, s),
		Vector2(-s, s)
	])

# --- Generation Logic ---

func regenerate_map() -> void:
	_tile_map.clear()
	# OPTIMIZATION: We no longer need to queue_free thousands of child nodes
	_tile_health.clear()
	_tile_data_map.clear()
	
	var half_w: int = int(float(map_width) / 2.0)
	
	for y in range(1, map_height + 1):
		var active_layer = _get_layer_for_depth(y)
		
		for x in range(-half_w - 1, half_w + 2):
			var coords = Vector2i(x, y)
			
			if x == -half_w - 1 or x == half_w + 1 or y == map_height:
				_create_tile_at(coords, bedrock_definition)
				continue
			
			if active_layer:
				_generate_tile_from_layer(coords, active_layer)

func _get_layer_for_depth(y: int) -> TerrainLayer:
	for layer in terrain_layers:
		if y <= layer.max_depth:
			return layer
	return terrain_layers.back() if not terrain_layers.is_empty() else null

func _generate_tile_from_layer(coords: Vector2i, layer: TerrainLayer) -> void:
	var final_block: TileDefinition = _pick_weighted(layer.structural_pool)
	if not final_block: return
	
	var final_hp: int = final_block.max_health
	
	if not layer.resource_pool.is_empty() and randf() <= global_resource_chance:
		var resource_def = _pick_weighted(layer.resource_pool)
		if resource_def:
			final_block = resource_def
			final_hp = _calculate_resource_hp(layer, final_block)

	_create_tile_at(coords, final_block, final_hp)

func _pick_weighted(pool: Array[SpawnWeight]) -> TileDefinition:
	if pool.is_empty(): return null
	
	var total_weight: float = 0.0
	for entry in pool:
		total_weight += entry.weight
		
	var roll = randf() * total_weight
	var current_sum = 0.0
	
	for entry in pool:
		current_sum += entry.weight
		if roll <= current_sum:
			return entry.block
	
	return pool[0].block

func _calculate_resource_hp(layer: TerrainLayer, resource: TileDefinition) -> int:
	return resource.max_health + resource_hp_bonus

func _create_tile_at(coords: Vector2i, def: TileDefinition, custom_hp: int = -1) -> void:
	if not def: return
	_tile_map.set_cell(coords, SOURCE_ID, def.atlas_coords)
	_tile_data_map[coords] = def
	
	if def.is_diggable:
		# OPTIMIZATION: Store HP in dictionary, do NOT create a Node
		var hp = custom_hp if custom_hp > 0 else def.max_health
		_tile_health[coords] = hp

func _destroy_tile(coords: Vector2i) -> void:
	if not _tile_data_map.has(coords): return
	var def = _tile_data_map[coords]
	
	# Get position center of the tile
	var world_pos = to_global(_tile_map.map_to_local(coords))
	
	_tile_map.erase_cell(coords)
	
	# --- VISUALS: Block Break Particles ---
	if block_break_particles_scene:
		var particles = block_break_particles_scene.instantiate() as BlockParticles
		get_tree().current_scene.add_child(particles)
		particles.global_position = world_pos
		particles.setup(tile_texture_atlas, def.atlas_coords, grid_size)
	# --------------------------------------

	# --- DROPS: Item Drop Logic ---
	if randf() <= def.drop_chance:
		# Determine which scene to use (custom or default)
		var scene_to_spawn = def.drop_scene if def.drop_scene else default_drop_scene
		
		if scene_to_spawn:
			# Determine amount
			var count = randi_range(def.min_drops, def.max_drops)
			
			for i in range(count):
				var drop = scene_to_spawn.instantiate()
				get_tree().current_scene.add_child(drop)
				drop.global_position = world_pos
				
				# If it's our standard ItemDrop script, configure it
				if drop is ItemDrop:
					drop.setup(def, tile_texture_atlas)
	# ------------------------------
		
	block_broken.emit(coords, def)
	
	_tile_health.erase(coords)
	_tile_data_map.erase(coords)

# --- Interaction API ---

func try_dig(origin_global: Vector2, direction: Vector2) -> DigStatus:
	var local_origin = _tile_map.to_local(origin_global)
	var player_cell = _tile_map.local_to_map(local_origin)
	var best_dot = -1.0
	var best_cell: Vector2i
	var found = false
	
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = player_cell + offset
		if not _tile_data_map.has(neighbor) or not _tile_data_map[neighbor].is_diggable: continue
		var dot = direction.dot((_tile_map.map_to_local(neighbor) - local_origin).normalized())
		if dot > best_dot:
			best_dot = dot
			best_cell = neighbor
			found = true
			
	if found and best_dot > 0.5:
		if _tile_health.has(best_cell):
			_damage_tile(best_cell, 1)
			
			# Check if it was destroyed or just damaged
			if _tile_health.has(best_cell):
				return DigStatus.HIT
			else:
				return DigStatus.DESTROYED
				
	return DigStatus.NONE

func _damage_tile(coords: Vector2i, amount: int) -> void:
	if not _tile_health.has(coords): return
	
	_tile_health[coords] -= amount
	
	# OPTIMIZATION: Request redraw only when health changes if debugging
	if Globals.debug_mode:
		queue_redraw()
		
	if _tile_health[coords] <= 0:
		_destroy_tile(coords)

# --- Debug ---

func _process(_delta: float) -> void:
	# OPTIMIZATION: Only redraw every frame if strictly necessary. 
	# Moving queue_redraw to _damage_tile is usually better, but if you want 
	# to see the text follow the camera smoothly, keep it here.
	if Globals.debug_mode:
		queue_redraw()

func _draw() -> void:
	if not Globals.debug_mode:
		return
		
	var font := ThemeDB.fallback_font
	var font_size := 12
	
	# OPTIMIZATION: Do not draw health for every single block.
	# Only draw for blocks that are damaged, or perhaps close to player (not implemented here)
	for coords: Vector2i in _tile_health:
		var current_hp = _tile_health[coords]
		var max_hp = _tile_data_map[coords].max_health
		
		# Only draw if health is different than max, or if it's a special resource
		if current_hp == max_hp:
			continue
			
		var local_pos := _tile_map.map_to_local(coords)
		var text := str(current_hp)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var draw_pos := local_pos + Vector2(-text_size.x / 2, text_size.y / 3)
		
		draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 2, Color.BLACK)
		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)