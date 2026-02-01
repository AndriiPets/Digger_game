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

# --- Internal State ---
@onready var _base_layer: TileMapLayer = $BaseLayer
@onready var _ore_layer: TileMapLayer = $OreLayer
const SOURCE_ID: int = 0

@export var default_drop_scene: PackedScene
@export var block_break_particles_scene: PackedScene

# Stores total health of the cell (Base + Ore)
var _tile_health: Dictionary = {} # { Vector2i: int }

# Stores Definitions
var _base_data_map: Dictionary = {} # { Vector2i: TileDefinition }
var _ore_data_map: Dictionary = {} # { Vector2i: TileDefinition }

var _cached_definitions: Array[TileDefinition] = []

func _ready() -> void:
	_base_layer.show_behind_parent = true
	_ore_layer.show_behind_parent = true
	
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
	
	# Physics only needed on Base Layer
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
		
		# Only add collision if it's NOT an ore (Visual overlay doesn't need physics)
		# Or if you want the ore to share the definition but use it differently:
		_add_collision_to_tile(td)
		
	_base_layer.tile_set = tile_set
	_ore_layer.tile_set = tile_set

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
	_base_layer.clear()
	_ore_layer.clear()
	_tile_health.clear()
	_base_data_map.clear()
	_ore_data_map.clear()
	
	var half_w: int = int(float(map_width) / 2.0)
	
	for y in range(1, map_height + 1):
		var active_layer = _get_layer_for_depth(y)
		
		for x in range(-half_w - 1, half_w + 2):
			var coords = Vector2i(x, y)
			
			# Borders / Bedrock
			if x == -half_w - 1 or x == half_w + 1 or y == map_height:
				_create_tile_at(coords, bedrock_definition, null)
				continue
			
			if active_layer:
				_generate_composite_tile(coords, active_layer)

func _get_layer_for_depth(y: int) -> TerrainLayer:
	for layer in terrain_layers:
		if y <= layer.max_depth:
			return layer
	return terrain_layers.back() if not terrain_layers.is_empty() else null

func _generate_composite_tile(coords: Vector2i, layer: TerrainLayer) -> void:
	# 1. Pick Structural Block (Base)
	var base_block: TileDefinition = _pick_weighted(layer.structural_pool)
	if not base_block: return
	
	# 2. Pick Resource Overlay (Ore)
	var ore_block: TileDefinition = null
	if not layer.resource_pool.is_empty() and randf() <= global_resource_chance:
		ore_block = _pick_weighted(layer.resource_pool)
	
	_create_tile_at(coords, base_block, ore_block)

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

func _create_tile_at(coords: Vector2i, base: TileDefinition, ore: TileDefinition) -> void:
	if not base: return
	
	# 1. Place Base
	_base_layer.set_cell(coords, SOURCE_ID, base.atlas_coords)
	_base_data_map[coords] = base
	
	# 2. Place Ore (if any)
	if ore:
		_ore_layer.set_cell(coords, SOURCE_ID, ore.atlas_coords)
		_ore_data_map[coords] = ore
	
	# 3. Calculate Combined Health
	if base.is_diggable:
		var total_hp = base.max_health
		if ore:
			total_hp += ore.health_bonus
		
		_tile_health[coords] = total_hp

func _destroy_tile(coords: Vector2i) -> void:
	if not _base_data_map.has(coords): return
	
	var base_def = _base_data_map[coords]
	var ore_def = _ore_data_map.get(coords, null)
	
	var world_pos = to_global(_base_layer.map_to_local(coords))
	
	# --- VISUALS ---
	_base_layer.erase_cell(coords)
	_ore_layer.erase_cell(coords)
	
	# Particles (Use base block texture for particles usually, or could mix)
	if block_break_particles_scene:
		var particles = block_break_particles_scene.instantiate() as BlockParticles
		get_tree().current_scene.add_child(particles)
		particles.global_position = world_pos
		particles.setup(tile_texture_atlas, base_def.atlas_coords, grid_size)

	# --- DROPS ---
	# 1. Drop Base Item
	_spawn_drops_for(base_def, world_pos)
	
	# 2. Drop Ore Item (if it existed)
	if ore_def:
		_spawn_drops_for(ore_def, world_pos)
		# Emit signal for the Ore primarily as it's the "event" usually, 
		# or emit for base. Let's emit for base first.
		block_broken.emit(coords, ore_def)
	else:
		block_broken.emit(coords, base_def)
	
	# Cleanup Data
	_tile_health.erase(coords)
	_base_data_map.erase(coords)
	if _ore_data_map.has(coords):
		_ore_data_map.erase(coords)

func _spawn_drops_for(def: TileDefinition, pos: Vector2) -> void:
	if randf() > def.drop_chance: return
	
	var scene_to_spawn = def.drop_scene if def.drop_scene else default_drop_scene
	if not scene_to_spawn: return
	
	var count = randi_range(def.min_drops, def.max_drops)
	for i in range(count):
		var drop = scene_to_spawn.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = pos
		if drop is ItemDrop:
			drop.setup(def, tile_texture_atlas)

# --- Interaction API ---

func try_dig(origin_global: Vector2, direction: Vector2, damage_amount: int = 1) -> DigStatus:
	var local_origin = _base_layer.to_local(origin_global)
	var player_cell = _base_layer.local_to_map(local_origin)
	var best_dot = -1.0
	var best_cell: Vector2i
	var found = false
	
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = player_cell + offset
		if not _base_data_map.has(neighbor): continue
		if not _base_data_map[neighbor].is_diggable: continue
		
		var dot = direction.dot((_base_layer.map_to_local(neighbor) - local_origin).normalized())
		if dot > best_dot:
			best_dot = dot
			best_cell = neighbor
			found = true
			
	if found and best_dot > 0.5:
		if _tile_health.has(best_cell):
			_damage_tile(best_cell, damage_amount)
			
			if _tile_health.has(best_cell):
				return DigStatus.HIT
			else:
				return DigStatus.DESTROYED
				
	return DigStatus.NONE
	
func _damage_tile(coords: Vector2i, amount: int) -> void:
	if not _tile_health.has(coords): return
	
	_tile_health[coords] -= amount
	
	if Globals.debug_mode:
		queue_redraw()
		
	if _tile_health[coords] <= 0:
		_destroy_tile(coords)

# --- Debug ---

func _process(_delta: float) -> void:
	if Globals.debug_mode:
		queue_redraw()

func _draw() -> void:
	if not Globals.debug_mode:
		return
		
	var font := ThemeDB.fallback_font
	var font_size := 12
	
	for coords: Vector2i in _tile_health:
		# Check max HP vs Current HP
		if not _base_data_map.has(coords): continue
		
		var base = _base_data_map[coords]
		var ore = _ore_data_map.get(coords, null)
		var max_hp = base.max_health + (ore.health_bonus if ore else 0)
		
		var current_hp = _tile_health[coords]
		if current_hp == max_hp: continue
			
		var local_pos := _base_layer.map_to_local(coords)
		var text := str(current_hp)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var draw_pos := local_pos + Vector2(-text_size.x / 2, text_size.y / 3)
		
		draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 2, Color.BLACK)
		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)