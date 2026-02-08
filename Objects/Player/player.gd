class_name Player
extends CharacterBody2D

# Define Movement Modes
enum MovementMode {NORMAL, DIG, FLYING}

# Signals
signal item_collected(type: TileDefinition)
signal inventory_full_rejected()
signal energy_changed(current: float, max_val: float)
signal energy_depleted

# Components
@onready var visual: ColorRect = $Visual
@onready var dig_detector: Area2D = $DigDetector
@onready var inventory: InventoryComponent = %Inventory
@onready var stats: StatsComponent = $StatsComponent
@onready var upgrades: UpgradeManager = $UpgradeManager

# Exports
@export_group("Modes")
# CHANGED: Default mode is now NORMAL
@export var current_mode: MovementMode = MovementMode.NORMAL

@export_group("Base Stats")
@export var base_speed: float = 150.0
@export var base_dig_interval: float = 0.5
@export var grid_size: int = 32
@export var recoil_distance: float = 5.0
@export var recoil_recovery_speed: float = 5.0
@export var gravity: float = 1200.0
@export var base_max_energy: float = 20.0
@export var fly_energy_cost: float = 4.0

# NEW: Screen Shake Settings
@export_group("Effects")
@export var shake_threshold_small: float = 300.0
@export var shake_strength_small: float = 0.3
@export var shake_threshold_large: float = 600.0
@export var shake_strength_large: float = 1.0

# State
var _input_direction: Vector2 = Vector2.ZERO
var _facing_direction: Vector2 = Vector2.RIGHT
var _terrain_manager: TerrainManager
var _speed_multiplier: float = 1.0
var _base_visual_pos: Vector2
var _recoil_offset: Vector2 = Vector2.ZERO
var _dig_cooldown: float = 0.0
var _debug_flash_timer: float = 0.0

# NEW: Logic to track landing
var _previous_velocity_y: float = 0.0

# Energy State
var current_energy: float = 100.0

func _ready() -> void:
	add_to_group("player")
	
	stats.stat_changed.connect(_on_stat_changed)
	
	# Initialize Stats
	stats.initialize("move_speed", base_speed)
	stats.initialize("dig_speed", base_dig_interval)
	stats.initialize("dig_damage", 1.0)
	stats.initialize("time_bonus", 0.0)
	
	# Initialize Energy
	stats.initialize("max_energy", base_max_energy)
	current_energy = stats.get_value("max_energy")
	
	if inventory:
		stats.initialize("max_weight", inventory.max_weight)
	
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
	
	call_deferred("_emit_energy_update")

func _emit_energy_update() -> void:
	energy_changed.emit(current_energy, stats.get_value("max_energy"))

func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_name == "max_weight" and inventory:
		inventory.max_weight = new_value
		inventory.inventory_changed_value.emit(inventory.current_weight, inventory.max_weight)
		_on_inventory_weight_changed(inventory.current_weight, inventory.max_weight)
	elif stat_name == "max_energy":
		_emit_energy_update()

func reset_all_stats() -> void:
	if stats:
		stats.reset_modifiers()
	if upgrades:
		upgrades.clear_upgrades()
	_speed_multiplier = 1.0
	current_energy = stats.get_value("max_energy")
	_emit_energy_update()

# --- NEW STATE MANAGEMENT FUNCTIONS ---
func enter_mech() -> void:
	current_mode = MovementMode.DIG
	# Visual cue: Change color to indicate mech mode
	visual.color = Color(0.3, 0.6, 0.9) # Light Blue
	velocity = Vector2.ZERO

func exit_mech() -> void:
	current_mode = MovementMode.NORMAL
	# Visual cue: Reset to human color
	visual.color = Color(0.2, 0.8, 0.2) # Green
	velocity = Vector2.ZERO
# --------------------------------------

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
	
	# NEW: Capture velocity before slide modifies it (to detect impact)
	_previous_velocity_y = velocity.y
	
	_handle_movement(delta)
	
	# NEW: Check for landing
	if is_on_floor() and _previous_velocity_y > 0.0:
		_check_landing_impact()
		
	_handle_actions()
	
	if current_mode == MovementMode.FLYING:
		consume_energy(fly_energy_cost * delta)

# NEW: Calculate impact intensity and trigger shake
func _check_landing_impact() -> void:
	# Only shake screen if in Mech mode (Dig or Fly)
	if current_mode == MovementMode.NORMAL: return

	if _previous_velocity_y > shake_threshold_large:
		VFXManager.screen_shake(shake_strength_large)
	elif _previous_velocity_y > shake_threshold_small:
		VFXManager.screen_shake(shake_strength_small)

func consume_energy(amount: float) -> void:
	if current_energy <= 0: return
	
	current_energy -= amount
	if current_energy <= 0:
		current_energy = 0
		energy_depleted.emit()
	
	energy_changed.emit(current_energy, stats.get_value("max_energy"))

func _handle_timers(delta: float) -> void:
	if _dig_cooldown > 0:
		_dig_cooldown -= delta

func _handle_input() -> void:
	var raw_input := Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")

	if raw_input.x != 0:
		_input_direction = Vector2(raw_input.x, 0)
		_facing_direction = _input_direction.normalized()
	elif raw_input.y != 0:
		_input_direction = Vector2(0, raw_input.y)
		_facing_direction = _input_direction.normalized()
	else:
		_input_direction = Vector2.ZERO
	
	# Hold Space to fly logic
	if Input.is_key_pressed(KEY_SPACE) and current_energy > 0:
		# Can only fly if already in mech (DIG mode)
		if current_mode == MovementMode.DIG:
			current_mode = MovementMode.FLYING
			velocity.y = 0
	else:
		if current_mode == MovementMode.FLYING:
			current_mode = MovementMode.DIG

func _handle_movement(delta: float) -> void:
	var current_speed = stats.get_value("move_speed")
	
	match current_mode:
		MovementMode.FLYING:
			velocity.x = _input_direction.x * current_speed * _speed_multiplier
			# Constant upward movement
			velocity.y = - current_speed * _speed_multiplier
			
		MovementMode.NORMAL, MovementMode.DIG:
			velocity.x = _input_direction.x * current_speed * _speed_multiplier
			velocity.y += gravity * delta

	move_and_slide()

func _handle_actions() -> void:
	if current_mode == MovementMode.NORMAL:
		return
		
	if Input.is_action_pressed("ACTION"):
		if _dig_cooldown <= 0:
			_try_manual_dig()

func _try_manual_dig() -> void:
	if current_energy <= 0:
		return

	var interval = stats.get_value("dig_speed")
	interval = max(0.05, interval)
	
	_dig_cooldown = interval
	_debug_flash_timer = 0.15
	
	if not _terrain_manager: return

	var damage_amount = int(stats.get_value("dig_damage"))
	var status = _terrain_manager.try_dig(global_position, _facing_direction, damage_amount)

	if status == TerrainManager.DigStatus.HIT or status == TerrainManager.DigStatus.DESTROYED:
		_recoil_offset = - _facing_direction * recoil_distance
		consume_energy(1.0)

func _draw() -> void:
	if Globals.debug_mode:
		var start := Vector2.ZERO
		var end := _facing_direction * 40.0
		var color := Color.MAGENTA
		if _debug_flash_timer > 0: color = Color.RED
		draw_line(start, end, color, 4.0)

func collect_item(item_type: TileDefinition, value: int = -1) -> void:
	if not inventory: return
	var success = inventory.add_item(item_type, 1, value)
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