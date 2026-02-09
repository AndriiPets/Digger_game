class_name GameLoop
extends Node

enum GameState {SAFE, RUN}

@export var player_start_pos: Vector2 = Vector2(-270, -32)

@export_group("References")
@export var terrain_manager: TerrainManager
@export var player: Player
@export var safe_zone: SafeZone
@export var robot_entity: RobotEntity

@export_group("UI References")
@export var energy_ui: EnergyUI
@export var encumbrance_ui: EncumbranceUI
@export var depth_ui: DepthUI
@export var money_ui: MoneyUI
@export var floating_text_scene: PackedScene
@export var death_ui_scene: PackedScene

var total_money: int = 10
var _current_state: GameState = GameState.SAFE

# --- Rebuild System State ---
var is_robot_built: bool = false

# Computed property: Automatically true if active configuration differs from saved configuration
var has_pending_updates: bool:
	get:
		if player and player.upgrades:
			return player.upgrades.has_pending_changes()
		return false

const REBUILD_COST_PERCENTAGE: float = 0.5

func _enter_tree() -> void:
	add_to_group("game_manager")

func _ready() -> void:
	if safe_zone:
		safe_zone.player_exited_zone.connect(start_run)
		safe_zone.player_entered_zone.connect(_on_player_entered_safezone)
		
	if robot_entity:
		robot_entity.player_embarked.connect(_on_player_embarked)

	_connect_gameplay_signals()
	_reset_game()
	
	if money_ui:
		money_ui.update_money(total_money)

	# Start Music (Volume -10db to be background)
	SoundManager.play_loop("music", 1.0, -10.0)

func _connect_gameplay_signals() -> void:
	if player:
		if not player.item_collected.is_connected(_on_player_item_collected):
			player.item_collected.connect(_on_player_item_collected)
		if not player.inventory_full_rejected.is_connected(_on_inventory_full):
			player.inventory_full_rejected.connect(_on_inventory_full)
		if player.inventory and encumbrance_ui:
			if not player.inventory.inventory_changed_value.is_connected(encumbrance_ui.update_display):
				player.inventory.inventory_changed_value.connect(encumbrance_ui.update_display)
				encumbrance_ui.update_display(player.inventory.current_weight, player.inventory.max_weight)
		
		if energy_ui and not player.energy_changed.is_connected(energy_ui.update_energy):
			player.energy_changed.connect(energy_ui.update_energy)
		
		if not player.energy_depleted.is_connected(_on_energy_depleted):
			player.energy_depleted.connect(_on_energy_depleted)
	
	var shops = get_tree().get_nodes_in_group("shops")
	for shop in shops:
		if shop is ShopEntity:
			if not shop.shop_ui.item_purchased.is_connected(try_purchase_upgrade):
				shop.shop_ui.item_purchased.connect(try_purchase_upgrade)

# --- Upgrade & Rebuild Logic ---

func try_purchase_upgrade(category_id: String, item: ShopItem) -> void:
	# Buying an item is an UPGRADE (true)
	if Globals.can_afford(item.cost, total_money, true):
		total_money -= item.cost
		if money_ui: money_ui.update_money(total_money)
		
		if player and player.upgrades:
			# Store purchase but DO NOT apply stats yet
			player.upgrades.purchase_item(category_id, item)
			_spawn_floating_text("Purchased!", Color.GREEN)
	else:
		_spawn_floating_text("Too Expensive!", Color.RED)

func try_rebuild_robot(cost: int) -> bool:
	# Rebuilding is MAINTENANCE (false)
	if Globals.can_afford(cost, total_money, false):
		total_money -= cost
		SoundManager.play_sfx("rebuild")
		if money_ui: money_ui.update_money(total_money)
		
		# 1. Mark as built
		is_robot_built = true
		
		# 2. Apply all stats (this refreshes stats with new items)
		if player and player.upgrades:
			player.upgrades.apply_all_upgrades(player)
		
		# 3. Update Visuals
		if robot_entity:
			robot_entity.set_state(RobotEntity.State.FUNCTIONAL)

		# 4. If player is inside the robot (updating while active), force eject
		if player and player.current_mode != Player.MovementMode.NORMAL:
			player.exit_mech()
			_spawn_floating_text("Updated! Please Re-embark.", Color.CYAN)
		else:
			_spawn_floating_text("Systems Online", Color.CYAN)

		return true
	else:
		_spawn_floating_text("Funds Low", Color.RED)
		return false

func try_purchase_refuel(cost: int) -> bool:
	# Refueling is MAINTENANCE (false)
	if Globals.can_afford(cost, total_money, false):
		total_money -= cost
		if money_ui: money_ui.update_money(total_money)
		
		if player and player.stats:
			var max_energy = player.stats.get_value("max_energy")
			player.current_energy = max_energy
			player.call("_emit_energy_update")
			_spawn_floating_text("Tank Refueled!", Color.GREEN)
			SoundManager.play_sfx("refuel")
		return true
	else:
		_spawn_floating_text("Funds Low", Color.RED)
		return false

# --- Gameplay Loops ---

func _on_player_item_collected(item: TileDefinition) -> void:
	if not floating_text_scene or not item: return
	_spawn_floating_text("+1 %s" % item.display_name, item.color_tint)

func _on_inventory_full() -> void:
	_spawn_floating_text("Max Weight!", Color(1, 0.2, 0.2))

func _spawn_floating_text(text: String, color: Color) -> void:
	if not floating_text_scene or not player: return
	var popup = floating_text_scene.instantiate() as FloatingText
	add_child(popup)
	var random_offset = Vector2(randf_range(-10, 10), randf_range(-20, -10))
	popup.setup(text, player.global_position + random_offset, color)

func _process(delta: float) -> void:
	if depth_ui and player:
		var grid_size = player.grid_size if "grid_size" in player else 32
		var depth_meters = floor(player.global_position.y / float(grid_size))
		depth_ui.update_depth(int(depth_meters))

func _on_player_entered_safezone() -> void:
	if player and player.inventory and player.inventory.current_weight > 0:
		var value = player.inventory.get_total_value()
		total_money += value
		if money_ui: money_ui.update_money(total_money)
		_spawn_floating_text("Sold: $%d" % value, Color.GOLD)
		player.inventory.clear()
		SoundManager.play_sfx("sold")

func _on_player_embarked() -> void:
	if player:
		player.enter_mech()
		_spawn_floating_text("System Online", Color.CYAN)
		SoundManager.play_sfx("embark")

func _reset_game() -> void:
	_current_state = GameState.SAFE
	
	if player:
		player.velocity = Vector2.ZERO
		player.global_position = player_start_pos
		if player.inventory: player.inventory.clear()
		player.reset_all_stats()
		player.exit_mech()
		SoundManager.stop_loop("thrust")
		SoundManager.play_sfx("respawn")

	if terrain_manager: terrain_manager.regenerate_map()
	
	# Death/Reset breaks the robot completely
	is_robot_built = false
	if robot_entity:
		robot_entity.set_state(RobotEntity.State.BROKEN)

func start_run() -> void:
	if _current_state == GameState.SAFE:
		_current_state = GameState.RUN

func _on_energy_depleted() -> void:
	_spawn_floating_text("Exhausted!", Color.RED)
	SoundManager.play_sfx("death")
	_end_round()

func _end_round() -> void:
	if death_ui_scene:
		var ui = death_ui_scene.instantiate() as DeathUI
		add_child(ui)
		ui.open()
		SoundManager.stop_loop("thrust")
		ui.confirm_pressed.connect(_on_death_confirmed.bind(ui))
	else:
		_reset_game()

func _on_death_confirmed(ui_instance: Node) -> void:
	ui_instance.queue_free()
	_reset_game()