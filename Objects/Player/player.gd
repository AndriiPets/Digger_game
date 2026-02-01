class_name Player
extends CharacterBody2D

# Signals
signal item_collected(type: TileDefinition)
signal inventory_full_rejected()

# Components
@onready var visual: ColorRect = $Visual
@onready var dig_detector: Area2D = $DigDetector
@onready var inventory: InventoryComponent = %Inventory
@onready var stats: StatsComponent = $StatsComponent
@onready var upgrades: UpgradeManager = $UpgradeManager

# Exports
@export_group("Base Stats")
@export var base_speed: float = 150.0
@export var base_dig_interval: float = 0.5
@export var grid_size: int = 32
@export var recoil_distance: float = 10.0
@export var recoil_recovery_speed: float = 5.0

# State
var _input_direction: Vector2 = Vector2.ZERO
var _facing_direction: Vector2 = Vector2.RIGHT
var _terrain_manager: TerrainManager
var _speed_multiplier: float = 1.0
var _base_visual_pos: Vector2
var _recoil_offset: Vector2 = Vector2.ZERO
var _dig_cooldown: float = 0.0
var _debug_flash_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	
	# Connect signal to listen for upgrades
	stats.stat_changed.connect(_on_stat_changed)
	
	# Initialize Stats
	stats.initialize("move_speed", base_speed)
	stats.initialize("dig_speed", base_dig_interval)
	stats.initialize("dig_damage", 1.0)
	
	# NEW: Initialize Time Bonus (starts at 0)
	stats.initialize("time_bonus", 0.0)
	
	# NEW: Initialize Weight from Inventory Component's default
	if inventory:
		stats.initialize("max_weight", inventory.max_weight)
	
	# ... (Visual Setup) ...
	var player_size := float(grid_size) * 0.8
	visual.size = Vector2(player_size, player_size)
	visual.position = - visual.size / 2
	_base_visual_pos = visual.position

	var collision_shape: CollisionShape2D = dig_detector.get_child(0)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(player_size, player_size) * 0.5
	collision_shape.shape = rect

	var terrain_nodes := get_tree().get_nodes_in_group("terrain")
	if not terrain_nodes.is_empty():
		_terrain_manager = terrain_nodes[0] as TerrainManager
	
	if inventory:
		inventory.inventory_changed_value.connect(_on_inventory_weight_changed)
		_on_inventory_weight_changed(inventory.current_weight, inventory.max_weight)

# NEW: Sync stats to actual components
func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_name == "max_weight" and inventory:
		inventory.max_weight = new_value
		# Force UI update
		inventory.inventory_changed_value.emit(inventory.current_weight, inventory.max_weight)
		# Re-check speed penalty logic
		_on_inventory_weight_changed(inventory.current_weight, inventory.max_weight)

# ... (Rest of Reset Logic) ...
func reset_all_stats() -> void:
	if stats:
		stats.reset_modifiers()
	if upgrades:
		upgrades.clear_upgrades()
	_speed_multiplier = 1.0

# ... (Standard Process/Physics functions omitted for brevity, they remain unchanged) ...

func _process(delta: float) -> void:
	if _debug_flash_timer > 0:
		_debug_flash_timer -= delta
		queue_redraw()

	if _recoil_offset.length_squared() > 0.1:
		_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, recoil_recovery_speed * delta)
	else:
		_recoil_offset = Vector2.ZERO
	
	visual.position = _base_visual_pos + _recoil_offset

	if Globals.debug_mode:
		queue_redraw()

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_handle_input()
	_handle_movement()
	_handle_actions()

func _handle_timers(delta: float) -> void:
	if _dig_cooldown > 0:
		_dig_cooldown -= delta

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _handle_input() -> void:
	var raw_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if raw_input.x != 0:
		_input_direction = Vector2(raw_input.x, 0)
		_facing_direction = _input_direction.normalized()
	elif raw_input.y != 0:
		_input_direction = Vector2(0, raw_input.y)
		_facing_direction = _input_direction.normalized()
	else:
		_input_direction = Vector2.ZERO

func _handle_movement() -> void:
	var current_speed = stats.get_value("move_speed")
	velocity = _input_direction * current_speed * _speed_multiplier
	move_and_slide()

func _handle_actions() -> void:
	if Input.is_key_pressed(KEY_Z):
		if _dig_cooldown <= 0:
			_try_manual_dig()

func _try_manual_dig() -> void:
	var interval = stats.get_value("dig_speed")
	interval = max(0.05, interval)
	
	_dig_cooldown = interval
	_debug_flash_timer = 0.15
	
	if not _terrain_manager: return

	var damage_amount = int(stats.get_value("dig_damage"))
	var status = _terrain_manager.try_dig(global_position, _facing_direction, damage_amount)

	if status == TerrainManager.DigStatus.HIT:
		_recoil_offset = - _facing_direction * recoil_distance

func _draw() -> void:
	if Globals.debug_mode:
		var start := Vector2.ZERO
		var end := _facing_direction * 40.0
		var color := Color.MAGENTA
		if _debug_flash_timer > 0: color = Color.RED
		draw_line(start, end, color, 4.0)

func collect_item(item_type: TileDefinition) -> void:
	if not inventory: return
	var success = inventory.add_item(item_type, 1)
	if success:
		item_collected.emit(item_type)
	else:
		inventory_full_rejected.emit()

func _on_inventory_weight_changed(current_weight: float, max_weight: float) -> void:
	var ratio: float = 0.0
	if max_weight > 0:
		ratio = current_weight / max_weight
	
	if ratio > 0.85: _speed_multiplier = 0.5
	elif ratio > 0.70: _speed_multiplier = 0.75
	else: _speed_multiplier = 1.0