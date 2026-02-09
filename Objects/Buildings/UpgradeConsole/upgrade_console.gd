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
	ui.item_equipped.connect(_on_item_equipped)
	ui.rebuild_requested.connect(_on_rebuild_requested)

	_find_manager()

func _process(_delta: float) -> void:
	if _in_range and not ui.visible:
		if Input.is_action_pressed("ACTION"):
			SoundManager.play_sfx("select")
			_open_console()

func _open_console() -> void:
	_find_manager()

	# 1. Ensure Defaults (First item in category)
	if _player_ref and _player_ref.upgrades:
		for cat in categories:
			if cat.items.is_empty(): continue

			# If nothing is equipped for this category, force the first item
			if _player_ref.upgrades.get_equipped_item_id(cat.id) == "":
				var default_item = cat.items[0]
				# 'Purchasing' it grants ownership (if needed) and equips it
				# Default items should ideally have cost 0, but logic works regardless
				_player_ref.upgrades.purchase_item(cat.id, default_item)

	var money = _manager.total_money if _manager else 0

	var owned_ids: Array[String] = []
	var equipped_map: Dictionary = {}
	var rebuild_value: int = 0

	if _player_ref and _player_ref.upgrades:
		owned_ids = _player_ref.upgrades.owned_item_ids
		# Get the formatted map for the UI { "cat_id": "item_id" }
		for cat in categories:
			equipped_map[cat.id] = _player_ref.upgrades.get_equipped_item_id(cat.id)

		rebuild_value = _player_ref.upgrades.get_total_equipped_cost()

	var is_built = _manager.is_robot_built if _manager else false
	var has_pending = _manager.has_pending_updates if _manager else false

	ui.open(categories, money, owned_ids, equipped_map, rebuild_value, is_built, has_pending)
	prompt.visible = false

func _refresh_ui() -> void:
	if not ui.visible: return
	_find_manager()

	var money = _manager.total_money if _manager else 0
	var owned_ids: Array[String] = []
	var equipped_map: Dictionary = {}
	var rebuild_value: int = 0

	if _player_ref and _player_ref.upgrades:
		owned_ids = _player_ref.upgrades.owned_item_ids
		for cat in categories:
			equipped_map[cat.id] = _player_ref.upgrades.get_equipped_item_id(cat.id)
		rebuild_value = _player_ref.upgrades.get_total_equipped_cost()

	var is_built = _manager.is_robot_built if _manager else false
	var has_pending = _manager.has_pending_updates if _manager else false

	ui.refresh_state(money, owned_ids, equipped_map, rebuild_value, is_built, has_pending)

func _on_item_purchased(category_id: String, item: ShopItem) -> void:
	_find_manager()
	if _manager:
		_manager.try_purchase_upgrade(category_id, item)
		_refresh_ui()

func _on_item_equipped(category_id: String, item: ShopItem) -> void:
	if _player_ref and _player_ref.upgrades:
		_player_ref.upgrades.equip_item(category_id, item)
		_refresh_ui()

		# Flag that configuration changed, requiring an update/rebuild
		if _manager:
			_manager.has_pending_updates = true

		_refresh_ui()

func _on_rebuild_requested(cost: int) -> void:
	_find_manager()
	if _manager:
		var success = _manager.try_rebuild_robot(cost)
		if success:
			_refresh_ui()

func _find_manager() -> void:
	if not _manager:
		var managers = get_tree().get_nodes_in_group("game_manager")
		if not managers.is_empty():
			_manager = managers[0]

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
