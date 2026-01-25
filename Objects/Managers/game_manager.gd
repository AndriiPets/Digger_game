class_name GameLoop
extends Node

enum GameState {SAFE, RUN}

@export var round_time: float = 90.0
@export var player_start_pos: Vector2 = Vector2(0, -32)

@export_group("References")
@export var terrain_manager: TerrainManager
@export var player: Player
@export var safe_zone: SafeZone

@export_group("UI References")
@export var game_ui: TimerUI
@export var encumbrance_ui: EncumbranceUI
# We will attach the node in the scene, or spawn it dynamically
@export var stash_inventory: InventoryComponent
@export var floating_text_scene: PackedScene

var _current_time: float
var _current_state: GameState = GameState.SAFE

func _ready() -> void:
	if safe_zone:
		safe_zone.player_exited_zone.connect(start_run)
		safe_zone.player_entered_zone.connect(_on_player_entered_safezone)

	_connect_debug_signals()
	_connect_gameplay_signals()
	_reset_game()

func _connect_debug_signals() -> void:
	# Connect Player Inventory
	if player and player.inventory:
		# We use unbind(2) to ignore the signal arguments (item, amount)
		# because we just want to reprint the whole state
		player.inventory.inventory_updated.connect(_print_global_inventory_state.unbind(2))
		player.inventory.inventory_cleared.connect(_print_global_inventory_state)

	# Connect Stash Inventory
	if stash_inventory:
		stash_inventory.inventory_updated.connect(_print_global_inventory_state.unbind(2))
		stash_inventory.inventory_cleared.connect(_print_global_inventory_state)

func _connect_gameplay_signals() -> void:
	if player:
		# Success Case
		if not player.item_collected.is_connected(_on_player_item_collected):
			player.item_collected.connect(_on_player_item_collected)

		# Fail Case (Full)
		if not player.inventory_full_rejected.is_connected(_on_inventory_full):
			player.inventory_full_rejected.connect(_on_inventory_full)

		# Update UI Bar
		if player.inventory and encumbrance_ui:
			if not player.inventory.inventory_changed_value.is_connected(encumbrance_ui.update_display):
				player.inventory.inventory_changed_value.connect(encumbrance_ui.update_display)
				# Force initial update
				encumbrance_ui.update_display(player.inventory.current_weight, player.inventory.max_weight)

# Success Text
func _on_player_item_collected(item: TileDefinition) -> void:
	if not floating_text_scene or not item: return
	_spawn_floating_text("+1 %s" % item.display_name, item.color_tint)

# Failure Text
func _on_inventory_full() -> void:
	_spawn_floating_text("Max Weight!", Color(1, 0.2, 0.2))

# Helper to avoid code duplication
func _spawn_floating_text(text: String, color: Color) -> void:
	if not floating_text_scene or not player: return

	var popup = floating_text_scene.instantiate() as FloatingText
	add_child(popup)

	var random_offset = Vector2(randf_range(-10, 10), randf_range(-20, -10))
	var spawn_pos = player.global_position + random_offset

	popup.setup(text, spawn_pos, color)

func _process(delta: float) -> void:
	if _current_state == GameState.RUN:
		if _current_time > 0:
			_current_time -= delta
			if game_ui: game_ui.update_timer(_current_time)
			if _current_time <= 0:
				_end_round()

# --- LOGIC ---

func _on_player_entered_safezone() -> void:
	# If we are in the safe state or just returning, bank the items
	if player and player.inventory and stash_inventory:
		# Check if player actually has something to avoid empty spam
		if player.inventory.current_weight > 0:
			print("$$$ BANKING LOOT $$$")
			player.inventory.transfer_to(stash_inventory)

func _reset_game() -> void:
	_current_state = GameState.SAFE
	_current_time = round_time

	if player:
		player.velocity = Vector2.ZERO
		player.global_position = player_start_pos
		# Requirement: Player inventory resets on map reset
		# (If they died or failed to bank, this wipes it)
		if player.inventory:
			player.inventory.clear()

	if terrain_manager:
		terrain_manager.regenerate_map()

	if game_ui:
		game_ui.update_timer(_current_time)
		game_ui.set_timer_visible(false)

func start_run() -> void:
	if _current_state == GameState.SAFE:
		_current_state = GameState.RUN
		if game_ui:
			game_ui.set_timer_visible(true)

func _end_round() -> void:
	# Requirement: Reset map, which triggers _reset_game -> player inventory clear
	_reset_game()

# --- NEW DEBUG PRINTER ---
func _print_global_inventory_state() -> void:
	print("\n📊 === GLOBAL INVENTORY STATE === 📊")

	# Print Player
	if player and player.inventory:
		var p_weight = player.inventory.current_weight
		var p_items = player.inventory.get_debug_string()
		print("[PLAYER] Weight: %.1f kg%s" % [p_weight, p_items])
	else:
		print("[PLAYER] Not Found")

	print("----------------------------------")

	# Print Stash
	if stash_inventory:
		var s_weight = stash_inventory.current_weight
		var s_items = stash_inventory.get_debug_string()
		print("[STASH]  Weight: %.1f kg%s" % [s_weight, s_items])
	else:
		print("[STASH]  Not Found")

	print("==================================\n")
