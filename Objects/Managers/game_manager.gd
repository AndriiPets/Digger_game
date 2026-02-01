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
@export var depth_ui: DepthUI
@export var money_ui: MoneyUI
@export var floating_text_scene: PackedScene

var total_money: int = 10
var _current_time: float
var _current_state: GameState = GameState.SAFE

func _ready() -> void:
	add_to_group("game_manager")
	
	if safe_zone:
		safe_zone.player_exited_zone.connect(start_run)
		safe_zone.player_entered_zone.connect(_on_player_entered_safezone)

	_connect_gameplay_signals()
	_reset_game()
	
	if money_ui:
		money_ui.update_money(total_money)

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
	
	var shops = get_tree().get_nodes_in_group("shops")
	for shop in shops:
		if shop is ShopEntity:
			if not shop.shop_ui.item_purchased.is_connected(try_purchase_upgrade):
				shop.shop_ui.item_purchased.connect(try_purchase_upgrade)

func try_purchase_upgrade(item: ShopItem) -> void:
	if total_money >= item.cost or Globals.debt:
		total_money -= item.cost
		if money_ui: money_ui.update_money(total_money)
		
		if player and player.upgrades:
			player.upgrades.apply_upgrade(item)
			_spawn_floating_text("Purchased!", Color.GREEN)
		else:
			push_error("Player or UpgradeManager missing!")
	else:
		_spawn_floating_text("Too Expensive!", Color.RED)

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
	if _current_state == GameState.RUN and _current_time > 0:
		_current_time -= delta
		if game_ui: game_ui.update_timer(_current_time)
		if _current_time <= 0: _end_round()

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

func _reset_game() -> void:
	_current_state = GameState.SAFE
	
	# NEW: Calculate Time based on stats
	var bonus_time = 0.0
	if player and player.stats:
		bonus_time = player.stats.get_value("time_bonus")
	
	_current_time = round_time + bonus_time
	
	if player:
		player.velocity = Vector2.ZERO
		player.global_position = player_start_pos
		if player.inventory: player.inventory.clear()
		player.reset_all_stats()

	if terrain_manager: terrain_manager.regenerate_map()
	if game_ui:
		game_ui.update_timer(_current_time)
		game_ui.set_timer_visible(false)

func start_run() -> void:
	if _current_state == GameState.SAFE:
		_current_state = GameState.RUN
		if game_ui: game_ui.set_timer_visible(true)

func _end_round() -> void:
	_reset_game()