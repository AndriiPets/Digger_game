class_name ShopEntity
extends Area2D

@export var shop_id: String = "general_store"
@export var shop_name: String = "General Store"
@export var items_for_sale: Array[ShopItem] = []
@export var start_locked: bool = false
@export var unlock_cost: int = 10

@onready var shop_ui: ShopUI = $ShopUI
@onready var unlock_ui: ShopUnlockUI = $ShopUnlockUI
@onready var prompt_label: Label = $PromptLabel
@onready var sprite: Sprite2D = $Sprite2D

var _player_in_range: bool = false
var _cooldown: float = 0.0
var _player_ref: Player

func _ready() -> void:
	add_to_group("shops")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if shop_ui:
		shop_ui.shop_closed.connect(_on_shop_closed)
	if unlock_ui:
		unlock_ui.unlock_confirmed.connect(_on_unlock_confirmed)
		unlock_ui.unlock_cancelled.connect(_on_shop_closed)
		
	prompt_label.visible = false
	_update_visual_state()

func _update_visual_state() -> void:
	# Optional: Change sprite color if locked
	var is_unlocked = _check_is_unlocked()
	if is_unlocked:
		sprite.modulate = Color(0.9, 0.6, 0.3, 1) # Normal
	else:
		sprite.modulate = Color(0.4, 0.4, 0.4, 1) # Dark/Locked

func _check_is_unlocked() -> bool:
	if not start_locked: return true
	if _player_ref and _player_ref.upgrades:
		return _player_ref.upgrades.is_shop_unlocked(shop_id)
	return false

func _process(delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta
		return

	if _player_in_range and not shop_ui.visible and not unlock_ui.visible:
		if Input.is_key_pressed(KEY_Z):
			_interact()

func _interact() -> void:
	var is_unlocked = _check_is_unlocked()
	
	var money = _get_player_money()
	
	if is_unlocked:
		_open_shop(money)
	else:
		_open_unlock_prompt(money)

func _get_player_money() -> int:
	var managers = get_tree().get_nodes_in_group("game_manager")
	if not managers.is_empty():
		return managers[0].total_money
	return 0

func _open_unlock_prompt(money: int) -> void:
	unlock_ui.open(shop_name, unlock_cost, money)
	prompt_label.visible = false

func _open_shop(money: int) -> void:
	var owned_ids: Array[String] = []
	if _player_ref and _player_ref.upgrades:
		owned_ids = _player_ref.upgrades.owned_item_ids
	
	shop_ui.populate_and_open(shop_name, items_for_sale, money, owned_ids)
	prompt_label.visible = false

func _on_unlock_confirmed() -> void:
	# Deduct money
	var managers = get_tree().get_nodes_in_group("game_manager")
	if not managers.is_empty():
		managers[0].total_money -= unlock_cost
		if managers[0].money_ui:
			managers[0].money_ui.update_money(managers[0].total_money)
	
	# Unlock permanently
	if _player_ref and _player_ref.upgrades:
		_player_ref.upgrades.unlock_shop(shop_id)
		
	_update_visual_state()
	
	# Immediately open the real shop
	_open_shop(_get_player_money())

func _on_shop_closed() -> void:
	_cooldown = 0.5
	if _player_in_range:
		prompt_label.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_player_ref = body as Player
		_update_visual_state() # Update checks just in case
		
		if not shop_ui.visible and not unlock_ui.visible:
			prompt_label.visible = true
		_cooldown = 0.2

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		# Do not clear player_ref immediately if we want to check unlock status during callbacks
		# but usually safe to clear.
		
		prompt_label.visible = false
		if shop_ui.visible: shop_ui.close()
		if unlock_ui.visible: unlock_ui.close()