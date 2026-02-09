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
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var drill_sprite: Sprite2D = $DrillSprite
@onready var drill_anim: AnimationPlayer = $DrillAnimationPlayer
@onready var dig_detector: Area2D = $DigDetector
@onready var inventory: InventoryComponent = %Inventory
@onready var stats: StatsComponent = $StatsComponent
@onready var upgrades: UpgradeManager = $UpgradeManager

# Exports
@export_group("Modes")
@export var current_mode: MovementMode = MovementMode.NORMAL

@export_group("Base Stats")
@export var base_speed: float = 150.0
@export var base_fly_speed: float = 100.0
@export var base_dig_interval: float = 0.5
@export var grid_size: int = 32
@export var recoil_distance: float = 5.0
@export var recoil_recovery_speed: float = 5.0
@export var gravity: float = 1200.0
@export var base_max_energy: float = 30.0
@export var fly_energy_cost: float = 4.0

@export_group("Effects")
@export var shake_threshold_small: float = 300.0
@export var shake_strength_small: float = 0.3
@export var shake_threshold_large: float = 600.0
@export var shake_strength_large: float = 1.0

# State
var _input_direction: Vector2 = Vector2.ZERO
var _facing_direction: Vector2 = Vector2.RIGHT
var _last_dig_direction: Vector2 = Vector2.ZERO
var _terrain_manager: TerrainManager
var _speed_multiplier: float = 1.0
var _recoil_offset: Vector2 = Vector2.ZERO
var _dig_cooldown: float = 0.0
var _debug_flash_timer: float = 0.0

var _previous_velocity_y: float = 0.0

# Energy State
var current_energy: float = 100.0

func _ready() -> void:
	add_to_group("player")

	stats.stat_changed.connect(_on_stat_changed)

	# Initialize Stats
	stats.initialize("move_speed", base_speed)
	stats.initialize("fly_speed", base_fly_speed)
	stats.initialize("dig_speed", base_dig_interval)
	stats.initialize("dig_damage", 1.0)
	stats.initialize("time_bonus", 0.0)

	stats.initialize("max_energy", base_max_energy)
	current_energy = stats.get_value("max_energy")

	if inventory:
		stats.initialize("max_weight", inventory.max_weight)

	# Initial Visual Setup
	if sprite:
		sprite.position = Vector2.ZERO
	if drill_sprite:
		drill_sprite.visible = false

	var collision_shape: CollisionShape2D = dig_detector.get_child(0)
	var rect := RectangleShape2D.new()
	var player_size := float(grid_size) * 0.8
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

	_speed_multiplier = 1.0
	current_energy = stats.get_value("max_energy")
	_emit_energy_update()

func enter_mech() -> void:
	current_mode = MovementMode.DIG
	velocity = Vector2.ZERO

func exit_mech() -> void:
	current_mode = MovementMode.NORMAL
	velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if _debug_flash_timer > 0:
		_debug_flash_timer -= delta
		queue_redraw()

	if _recoil_offset.length_squared() > 0.1:
		_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, recoil_recovery_speed * delta)
	else:
		_recoil_offset = Vector2.ZERO

	if sprite:
		sprite.position = _recoil_offset

	# Apply recoil to drill as well, maintaining its directional offset
	if drill_sprite and drill_sprite.visible:
		var base_pos = _last_dig_direction * float(grid_size)
		drill_sprite.position = base_pos + _recoil_offset

	if Globals.debug_mode:
		queue_redraw()

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_handle_input()

	_previous_velocity_y = velocity.y

	_handle_movement(delta)

	if is_on_floor() and _previous_velocity_y > 0.0:
		_check_landing_impact()

	_handle_actions()
	_update_animation()

	if current_mode == MovementMode.FLYING:
		consume_energy(fly_energy_cost * delta)

func _check_landing_impact() -> void:
	if current_mode == MovementMode.NORMAL: return

	if _previous_velocity_y > shake_threshold_large:
		VFXManager.screen_shake(shake_strength_large)
		SoundManager.play_sfx("fall_big")
	elif _previous_velocity_y > shake_threshold_small:
		VFXManager.screen_shake(shake_strength_small)
		SoundManager.play_sfx("fall_small")

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
		# If finished
		if _dig_cooldown <= 0:
			if drill_sprite: drill_sprite.visible = false
			if drill_anim: drill_anim.stop()

func _handle_input() -> void:
	var raw_input := Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")

	if raw_input.x != 0:
		_input_direction = Vector2(raw_input.x, 0)
		_facing_direction = _input_direction.normalized()
	elif raw_input.y != 0:
		_input_direction = Vector2(0, raw_input.y)
	else:
		_input_direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_SPACE) and current_energy > 0:
		if current_mode == MovementMode.DIG:
			current_mode = MovementMode.FLYING
			velocity.y = 0
			SoundManager.play_loop("thrust")
	else:
		if current_mode == MovementMode.FLYING:
			current_mode = MovementMode.DIG
			SoundManager.stop_loop("thrust")

func _handle_movement(delta: float) -> void:
	var move_speed = stats.get_value("move_speed")

	match current_mode:
		MovementMode.FLYING:
			velocity.x = _input_direction.x * move_speed * _speed_multiplier
			var thrust_speed = stats.get_value("fly_speed")
			velocity.y = - thrust_speed * _speed_multiplier

		MovementMode.NORMAL, MovementMode.DIG:
			velocity.x = _input_direction.x * move_speed * _speed_multiplier
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

	# Determine dig direction
	var dig_dir = Vector2.ZERO
	if Input.is_action_pressed("UP"):
		dig_dir = Vector2.UP
	elif Input.is_action_pressed("DOWN"):
		dig_dir = Vector2.DOWN
	else:
		# Use Facing direction
		dig_dir = _facing_direction

	_last_dig_direction = dig_dir
	_dig_cooldown = interval
	_debug_flash_timer = 0.15

	# Update Drill Visuals
	if drill_sprite and drill_anim:
		drill_sprite.visible = true
		# Position is handled in _process for recoil
		drill_sprite.position = dig_dir * float(grid_size)
		drill_sprite.rotation = dig_dir.angle()
		drill_anim.play("drill")

	if not _terrain_manager: return

	var damage_amount = int(stats.get_value("dig_damage"))
	var status = _terrain_manager.try_dig(global_position, dig_dir, damage_amount)

	if status == TerrainManager.DigStatus.HIT or status == TerrainManager.DigStatus.DESTROYED:
		_recoil_offset = - dig_dir * recoil_distance
		consume_energy(1.0)
		SoundManager.play_sfx("dig", 0.9, 1.1)

func _update_animation() -> void:
	if not sprite or not anim: return

	# 1. Orientation (Body)
	if _facing_direction.x > 0:
		sprite.flip_h = false
	elif _facing_direction.x < 0:
		sprite.flip_h = true

	# 2. State Logic
	if current_mode == MovementMode.NORMAL:
		if abs(velocity.x) > 10.0:
			anim.play("human_run")
		else:
			anim.play("human_idle")

	elif current_mode == MovementMode.FLYING:
		anim.play("robot_fly")

	elif current_mode == MovementMode.DIG:
		# Priority: Digging Action > Moving > Idle
		if _dig_cooldown > 0:
			anim.stop()
			# Manually set body frame based on direction
			if _last_dig_direction == Vector2.UP:
				sprite.frame = 6
			elif _last_dig_direction == Vector2.DOWN:
				sprite.frame = 5
			else:
				sprite.frame = 4
		else:
			if abs(velocity.x) > 10.0:
				anim.play("robot_run")
			else:
				anim.play("robot_idle")

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
		SoundManager.play_sfx("drop", 0.95, 1.05)
	else:
		inventory_full_rejected.emit()

func _on_inventory_weight_changed(current_weight: float, max_weight: float) -> void:
	var ratio: float = 0.0
	if max_weight > 0:
		ratio = current_weight / max_weight

	if ratio > 0.85: _speed_multiplier = 0.5
	elif ratio > 0.70: _speed_multiplier = 0.75
	else: _speed_multiplier = 1.0
