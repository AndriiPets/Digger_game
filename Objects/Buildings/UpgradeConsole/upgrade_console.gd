class_name UpgradeConsole
extends Area2D

@export var categories: Array[ShopCategory] = []

@onready var ui: UpgradeUI = $UpgradeUI
@onready var prompt: Label = $PromptLabel

var _player_ref: Player
var _in_range: bool = false
var _manager: GameLoop

func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	prompt.visible = false
	
	ui.item_purchased.connect(_on_item_purchased)
	# Connect rebuild signal
	ui.rebuild_requested.connect(_on_rebuild_requested)
	
	# Cache Manager
	var managers = get_tree().get_nodes_in_group("game_manager")
	if not managers.is_empty():
		_manager = managers[0]

func _process(_delta: float) -> void:
	if _in_range and not ui.visible:
		if Input.is_key_pressed(KEY_Z):
			_open_console()

func _open_console() -> void:
	if not _manager:
		var managers = get_tree().get_nodes_in_group("game_manager")
		if not managers.is_empty():
			_manager = managers[0]

	var money = _manager.total_money if _manager else 0
	
	var owned: Array[String] = []
	var total_value: int = 0
	var is_built: bool = false
	var has_pending: bool = false
	
	if _player_ref and _player_ref.upgrades:
		owned = _player_ref.upgrades.owned_item_ids
		total_value = _player_ref.upgrades.owned_items_total_cost
	
	if _manager:
		is_built = _manager.is_robot_built
		has_pending = _manager.has_pending_updates
	
	ui.open(categories, money, owned, total_value, is_built, has_pending)
	prompt.visible = false

func _refresh_ui() -> void:
	if not ui.visible: return
	
	var money = _manager.total_money if _manager else 0
	var owned: Array[String] = []
	var total_value: int = 0
	var is_built: bool = false
	var has_pending: bool = false
	
	if _player_ref and _player_ref.upgrades:
		owned = _player_ref.upgrades.owned_item_ids
		total_value = _player_ref.upgrades.owned_items_total_cost
		
	if _manager:
		is_built = _manager.is_robot_built
		has_pending = _manager.has_pending_updates
		
	ui.refresh_state(money, owned, total_value, is_built, has_pending)

func _on_item_purchased(item: ShopItem) -> void:
	if _manager:
		_manager.try_purchase_upgrade(item)
		_refresh_ui()

func _on_rebuild_requested(cost: int) -> void:
	if not _manager:
		var managers = get_tree().get_nodes_in_group("game_manager")
		if not managers.is_empty():
			_manager = managers[0]

	if _manager:
		var success = _manager.try_rebuild_robot(cost)
		if success:
			_refresh_ui()

func _on_entered(body: Node2D) -> void:
	if body is Player:
		_player_ref = body
		_in_range = true
		prompt.visible = true

func _on_exited(body: Node2D) -> void:
	if body is Player:
		_player_ref = null
		_in_range = false
		prompt.visible = false
		ui.close()