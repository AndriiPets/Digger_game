class_name ShopEntity
extends Area2D

@export var shop_name: String = "General Store"
@export var items_for_sale: Array[ShopItem] = []

@onready var shop_ui: ShopUI = $ShopUI
@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false
var _cooldown: float = 0.0
var _player_ref: Player # NEW: Cache the player reference

func _ready() -> void:
	add_to_group("shops")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if shop_ui:
		shop_ui.shop_closed.connect(_on_shop_closed)
		
	prompt_label.visible = false

func _process(delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta
		return

	if _player_in_range and not shop_ui.visible:
		if Input.is_key_pressed(KEY_Z):
			_open_shop()

func _open_shop() -> void:
	# Fetch money
	var money = 0
	var managers = get_tree().get_nodes_in_group("game_manager")
	if not managers.is_empty():
		money = managers[0].total_money
	
	# NEW: Fetch owned items
	var owned_ids: Array[String] = []
	if _player_ref and _player_ref.upgrades:
		owned_ids = _player_ref.upgrades.owned_item_ids
	
	# Pass data to UI
	shop_ui.populate_and_open(shop_name, items_for_sale, money, owned_ids)
	prompt_label.visible = false

func _on_shop_closed() -> void:
	_cooldown = 0.5
	if _player_in_range:
		prompt_label.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_player_ref = body as Player # Store reference
		
		if not shop_ui.visible:
			prompt_label.visible = true
		_cooldown = 0.2

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_player_ref = null # Clear reference
		
		prompt_label.visible = false
		if shop_ui.visible:
			shop_ui.close()