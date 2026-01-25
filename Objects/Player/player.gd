class_name Player
extends CharacterBody2D

# Signals
signal item_collected(type: TileDefinition)
signal inventory_full_rejected()

# Exports
@export var speed: float = 150.0
@export var grid_size: int = 32
@export var dig_interval: float = 0.5

# Components
@onready var visual: ColorRect = $Visual
@onready var dig_detector: Area2D = $DigDetector
@onready var inventory: InventoryComponent = %Inventory

# State
var _input_direction: Vector2 = Vector2.ZERO
var _facing_direction: Vector2 = Vector2.RIGHT
var _terrain_manager: TerrainManager

# Digging State
var _dig_cooldown: float = 0.0
var _debug_flash_timer: float = 0.0

func _ready() -> void:
	# Size the player to fit inside the grid slightly
	var player_size := float(grid_size) * 0.8
	visual.size = Vector2(player_size, player_size)
	visual.position = - visual.size / 2

	add_to_group("player")

	# Setup detector size
	var collision_shape: CollisionShape2D = dig_detector.get_child(0)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(player_size, player_size) * 0.5
	collision_shape.shape = rect

	# Cache terrain reference
	var terrain_nodes := get_tree().get_nodes_in_group("terrain")
	if not terrain_nodes.is_empty():
		_terrain_manager = terrain_nodes[0] as TerrainManager

func _process(delta: float) -> void:
	# Update visual flash timer independent of physics tick
	if _debug_flash_timer > 0:
		_debug_flash_timer -= delta
		queue_redraw()

	# Request redraw if debug mode state changes
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
	# Removed old single-press logic
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
	velocity = _input_direction * speed
	move_and_slide()

func _handle_actions() -> void:
	# Check for Dig button (Z) - Held down
	if Input.is_key_pressed(KEY_Z):
		if _dig_cooldown <= 0:
			_try_manual_dig()

func _try_manual_dig() -> void:
	# Reset cooldown
	_dig_cooldown = dig_interval

	# Trigger visual flash for debug
	_debug_flash_timer = 0.15

	if not _terrain_manager:
		return

	# Pass origin and facing direction to terrain manager
	_terrain_manager.try_dig(global_position, _facing_direction)

func _draw() -> void:
	if Globals.debug_mode:
		var start := Vector2.ZERO
		var end := _facing_direction * 40.0

		# Default color is Magenta, flash Red when attacking
		var color := Color.MAGENTA
		if _debug_flash_timer > 0:
			color = Color.RED

		var width := 4.0

		# Draw shaft
		draw_line(start, end, color, width)

		# Draw arrow head
		var angle := _facing_direction.angle()
		var arrow_size := 10.0
		var arrow_angle := PI / 4.0 # 45 degrees

		var right_wing := end + Vector2(cos(angle + PI - arrow_angle), sin(angle + PI - arrow_angle)) * arrow_size
		var left_wing := end + Vector2(cos(angle + PI + arrow_angle), sin(angle + PI + arrow_angle)) * arrow_size

		draw_line(end, right_wing, color, width)
		draw_line(end, left_wing, color, width)

func collect_item(item_type: TileDefinition) -> void:
	if not inventory: return

	# Try to add item
	var success = inventory.add_item(item_type, 1)

	if success:
		item_collected.emit(item_type)
	else:
		# Item is effectively discarded (we do nothing with it),
		# but we emit a signal so the Game Manager can show text.
		inventory_full_rejected.emit()
