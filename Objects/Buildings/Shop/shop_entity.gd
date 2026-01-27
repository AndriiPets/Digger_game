class_name ShopEntity
extends Area2D

@export var shop_name: String = "General Store"
@export var items_for_sale: Array[ShopItem] = []

@onready var shop_ui: ShopUI = $ShopUI
@onready var prompt_label: Label = $PromptLabel

var _player_in_range: bool = false
var _cooldown: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if shop_ui:
		shop_ui.shop_closed.connect(_on_shop_closed)
		# You can also connect item_purchased here to handle logic
		# shop_ui.item_purchased.connect(_on_item_purchased)
		
	prompt_label.visible = false

func _process(delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta
		return

	if _player_in_range and not shop_ui.visible:
		if Input.is_key_pressed(KEY_Z):
			_open_shop()

func _open_shop() -> void:
	# Pass the specific data for this instance to the generic UI
	shop_ui.populate_and_open(shop_name, items_for_sale)
	prompt_label.visible = false

func _on_shop_closed() -> void:
	_cooldown = 0.5
	if _player_in_range:
		prompt_label.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if not shop_ui.visible:
			prompt_label.visible = true
		_cooldown = 0.2

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		prompt_label.visible = false
		if shop_ui.visible:
			shop_ui.close()