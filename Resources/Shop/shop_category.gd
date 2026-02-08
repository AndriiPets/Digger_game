class_name ShopCategory
extends Resource

@export var id: String = "category_id"
@export var display_name: String = "Category Name"
@export var icon: Texture2D
@export var items: Array[ShopItem] = []