class_name UpgradeManager
extends Node

# Stores actual resources
var owned_items: Array[ShopItem] = []
# Keep IDs for quick ownership checks
var owned_item_ids: Array[String] = []

# { "category_id": ShopItem }
var equipped_items: Dictionary = {}

# NEW: Snapshot of what is actually applied to the player (the robot's current state)
var applied_items: Dictionary = {}

# Tracks unlocked shops
var unlocked_shop_ids: Array[String] = []

func purchase_item(category_id: String, item: ShopItem) -> void:
	if not item.id in owned_item_ids:
		owned_items.append(item)
		owned_item_ids.append(item.id)
		print("Upgrade Manager: Acquired %s" % item.display_name)
	
	equip_item(category_id, item)

func equip_item(category_id: String, item: ShopItem) -> void:
	if item.id in owned_item_ids:
		equipped_items[category_id] = item
		print("Upgrade Manager: Equipped %s in slot %s" % [item.display_name, category_id])

func get_equipped_item_id(category_id: String) -> String:
	if equipped_items.has(category_id):
		return equipped_items[category_id].id
	return ""

func get_total_equipped_cost() -> int:
	var total = 0
	for cat_id in equipped_items:
		var item = equipped_items[cat_id]
		if item:
			total += item.cost
	return total

func apply_all_upgrades(player: Node2D) -> void:
	if "stats" in player and player.stats:
		player.stats.reset_modifiers()
		
	for cat_id in equipped_items:
		var item = equipped_items[cat_id]
		if item:
			for effect in item.effects:
				if effect:
					effect.apply(player)
	
	# NEW: Update the snapshot to match the newly applied configuration
	applied_items = equipped_items.duplicate()
	print("Upgrade Manager: All active systems applied. Configuration saved.")

# NEW: Compare current equipment vs applied equipment
func has_pending_changes() -> bool:
	if equipped_items.size() != applied_items.size():
		return true
		
	for cat_id in equipped_items:
		if not applied_items.has(cat_id):
			return true
		# Compare the items
		if equipped_items[cat_id] != applied_items[cat_id]:
			return true
			
	return false

func is_shop_unlocked(shop_id: String) -> bool:
	return shop_id in unlocked_shop_ids

func unlock_shop(shop_id: String) -> void:
	if not shop_id in unlocked_shop_ids:
		unlocked_shop_ids.append(shop_id)

func clear_upgrades() -> void:
	owned_items.clear()
	owned_item_ids.clear()
	equipped_items.clear()
	applied_items.clear()