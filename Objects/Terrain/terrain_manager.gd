class_name TerrainManager
extends Node2D

signal block_broken(grid_pos: Vector2i, type: TileDefinition)

enum DigStatus {NONE, HIT, DESTROYED}
# NEW: Enum for generation modes
enum GenerationMode {REGENERATE, PERSISTENT, PIT}

# --- Configuration ---
@export_category("Map Settings")
# NEW: Replaced is_persistent boolean with the enum
@export var generation_mode: GenerationMode = GenerationMode.PERSISTENT
@export var grid_size: int = 32
@export var map_width: int = 25
@export var map_height: int = 250
@export var tile_texture_atlas: Texture2D
@export var damage_texture_atlas: Texture2D

@export_category("Layer Configuration")
@export var terrain_layers: Array[TerrainLayer] = []
@export var bedrock_definition: TileDefinition

@export_category("Global Settings")
@export var global_resource_chance: float = 0.2

# --- Internal State ---
@onready var _base_layer: TileMapLayer = $BaseLayer
@onready var _ore_layer: TileMapLayer = $OreLayer
@onready var _damage_layer: TileMapLayer = $DamageLayer

const SOURCE_ID_TERRAIN: int = 0
const SOURCE_ID_DAMAGE: int = 1

const BASE_DEPTH_MULTIPLIER: float = 50.0
const BASE_HP_MULTIPLIER: float = 1.08
const BASE_VALUE_MULTIPLIER: float = 1.3

@export var default_drop_scene: PackedScene
@export var block_break_particles_scene: PackedScene

# Stores total health of the cell (Base + Ore)
var _tile_health: Dictionary = {}

# Stores Definitions
var _base_data_map: Dictionary = {}
var _ore_data_map: Dictionary = {}

var _cached_definitions: Array[TileDefinition] = []
var _has_generated: bool = false

func _ready() -> void:
	_base_layer.show_behind_parent = true
	_ore_layer.show_behind_parent = true
	_damage_layer.show_behind_parent = true
	
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
	
	# 1. Terrain Source
	var source := TileSetAtlasSource.new()
	source.texture = tile_texture_atlas
	source.texture_region_size = Vector2i(grid_size, grid_size)
	tile_set.add_source(source, SOURCE_ID_TERRAIN)
	
	for def in _cached_definitions:
		if not source.has_tile(def.atlas_coords):
			source.create_tile(def.atlas_coords)
		var td = source.get_tile_data(def.atlas_coords, 0)
		td.modulate = def.color_tint
		_add_collision_to_tile(td)
	
	# 2. Damage Source
	if damage_texture_atlas:
		var dmg_source := TileSetAtlasSource.new()
		dmg_source.texture = damage_texture_atlas
		dmg_source.texture_region_size = Vector2i(grid_size, grid_size)
		
		# Create tiles for (0,0), (1,0), (2,0)
		for x in range(3):
			dmg_source.create_tile(Vector2i(x, 0))
			
		tile_set.add_source(dmg_source, SOURCE_ID_DAMAGE)
		
	_base_layer.tile_set = tile_set
	_ore_layer.tile_set = tile_set
	_damage_layer.tile_set = tile_set

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
	# UPDATED: Check Enum instead of boolean
	if generation_mode == GenerationMode.PERSISTENT and _has_generated:
		print("TerrainManager: Persisting existing map.")
		return

	# Clear previous map (Happens for REGENERATE and PIT)
	_base_layer.clear()
	_ore_layer.clear()
	_damage_layer.clear()
	_tile_health.clear()
	_base_data_map.clear()
	_ore_data_map.clear()
	
	var half_w: int = int(float(map_width) / 2.0)
	
	for y in range(1, map_height + 1):
		var active_layer = _get_layer_for_depth(y)
		
		for x in range(-half_w - 1, half_w + 2):
			var coords = Vector2i(x, y)
			
			# Bedrock Borders and Floor logic
			if x == -half_w - 1 or x == half_w + 1 or y == map_height:
				_create_tile_at(coords, bedrock_definition, null)
				continue
			
			# NEW: Pit Mode Logic
			# If in Pit Mode, check if X is within the -3 to 3 gap (6 blocks wide: -3, -2, -1, 0, 1, 2)
			if generation_mode == GenerationMode.PIT:
				if x >= -3 and x < 3:
					continue # Skip generating a block here
			
			if active_layer:
				_generate_composite_tile(coords, active_layer)
	
	_has_generated = true

func _get_layer_for_depth(y: int) -> TerrainLayer:
	for layer in terrain_layers:
		if y <= layer.max_depth:
			return layer
	return terrain_layers.back() if not terrain_layers.is_empty() else null

func _generate_composite_tile(coords: Vector2i, layer: TerrainLayer) -> void:
	var base_block: TileDefinition = _pick_weighted(layer.structural_pool)
	if not base_block: return
	
	# Calculate Depth Scale (DS)
	# Formula: DS = 1 + (depth / 50)
	var depth_scale: float = 1.0 + (float(coords.y) / BASE_DEPTH_MULTIPLIER)
	
	# Scale Ore Spawn Chance
	# Formula: Chance = BaseChance * DS^0.25
	var scaled_chance = global_resource_chance * pow(depth_scale, 0.25)
	
	var ore_block: TileDefinition = null
	if not layer.resource_pool.is_empty() and randf() <= scaled_chance:
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
	
	_base_layer.set_cell(coords, SOURCE_ID_TERRAIN, base.atlas_coords)
	_base_data_map[coords] = base
	
	if ore:
		_ore_layer.set_cell(coords, SOURCE_ID_TERRAIN, ore.atlas_coords)
		_ore_data_map[coords] = ore
	
	if base.is_diggable:
		var total_hp = base.max_health
		if ore:
			total_hp += ore.health_bonus
		
		# Scale Block Health
		# Formula: HP = BaseHP * DS^1.15
		var depth_scale: float = 1.0 + (float(coords.y) / BASE_DEPTH_MULTIPLIER)
		var scaled_hp = float(total_hp) * pow(depth_scale, BASE_HP_MULTIPLIER)
		
		_tile_health[coords] = int(scaled_hp)

func _destroy_tile(coords: Vector2i) -> void:
	if not _base_data_map.has(coords): return
	
	var base_def = _base_data_map[coords]
	var ore_def = _ore_data_map.get(coords, null)
	var world_pos = to_global(_base_layer.map_to_local(coords))
	
	_base_layer.erase_cell(coords)
	_ore_layer.erase_cell(coords)
	_damage_layer.erase_cell(coords)
	
	if block_break_particles_scene:
		var particles = block_break_particles_scene.instantiate() as BlockParticles
		get_tree().current_scene.add_child(particles)
		particles.global_position = world_pos
		particles.setup(tile_texture_atlas, base_def.atlas_coords, grid_size)

	# Scale Value for Drops
	# Formula: Value = BaseValue * DS^1.3
	var depth_scale: float = 1.0 + (float(coords.y) / BASE_DEPTH_MULTIPLIER)
	var value_multiplier: float = pow(depth_scale, BASE_VALUE_MULTIPLIER)

	_spawn_drops_for(base_def, world_pos, value_multiplier)
	
	if ore_def:
		_spawn_drops_for(ore_def, world_pos, value_multiplier)
		block_broken.emit(coords, ore_def)
	else:
		block_broken.emit(coords, base_def)
	
	_tile_health.erase(coords)
	_base_data_map.erase(coords)
	if _ore_data_map.has(coords):
		_ore_data_map.erase(coords)

func _spawn_drops_for(def: TileDefinition, pos: Vector2, value_mult: float = 1.0) -> void:
	if randf() > def.drop_chance: return
	
	var scene_to_spawn = def.drop_scene if def.drop_scene else default_drop_scene
	if not scene_to_spawn: return
	
	var count = randi_range(def.min_drops, def.max_drops)
	var scaled_value = int(float(def.base_value) * value_mult)
	
	for i in range(count):
		var drop = scene_to_spawn.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = pos
		if drop is ItemDrop:
			# Pass the calculated value to the drop
			drop.setup(def, tile_texture_atlas, scaled_value)

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
	
	# TRIGGER VFX
	var block_def = _base_data_map[coords]
	var target_atlas_coords = block_def.atlas_coords
	
	var world_pos = to_global(_base_layer.map_to_local(coords))
	VFXManager.play_tile_hit_effect(world_pos, tile_texture_atlas, target_atlas_coords, grid_size)

	_tile_health[coords] -= amount
	var current_hp = _tile_health[coords]
	
	if current_hp <= 0:
		_destroy_tile(coords)
	else:
		if damage_texture_atlas:
			var base = _base_data_map[coords]
			var ore = _ore_data_map.get(coords, null)
			
			# Recalculate max_hp for visual ratio, including scaling
			var depth_scale: float = 1.0 + (float(coords.y) / BASE_DEPTH_MULTIPLIER)
			var raw_max_hp = base.max_health + (ore.health_bonus if ore else 0)
			var max_hp = int(float(raw_max_hp) * pow(depth_scale, BASE_HP_MULTIPLIER))
			
			var hp_ratio = float(current_hp) / float(max_hp)
			var damage_ratio = 1.0 - hp_ratio
			
			var tile_coords = Vector2i(-1, -1)
			
			if damage_ratio >= 0.8:
				tile_coords = Vector2i(2, 0) # Stage 3
			elif damage_ratio >= 0.6:
				tile_coords = Vector2i(1, 0) # Stage 2
			elif damage_ratio >= 0.2:
				tile_coords = Vector2i(0, 0) # Stage 1
			
			if tile_coords.x != -1:
				_damage_layer.set_cell(coords, SOURCE_ID_DAMAGE, tile_coords)
			else:
				_damage_layer.erase_cell(coords)

	if Globals.debug_mode:
		queue_redraw()

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
		if not _base_data_map.has(coords): continue
		
		var current_hp = _tile_health[coords]
			
		var local_pos := _base_layer.map_to_local(coords)
		var text := str(current_hp)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var draw_pos := local_pos + Vector2(-text_size.x / 2, text_size.y / 3)
		
		draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 2, Color.BLACK)
		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)