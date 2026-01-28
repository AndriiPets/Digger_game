class_name ShopItem
extends Resource

@export var id: String = "item_id"
@export var display_name: String = "Item Name"
@export_multiline var description: String = "Description"
@export var cost: int = 100
@export var icon: Texture2D

# NEW: The list of effects this item applies when bought
@export var effects: Array[UpgradeEffect] = []