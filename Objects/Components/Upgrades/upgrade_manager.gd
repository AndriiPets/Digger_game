class_name UpgradeManager
extends Node

# Store actual resources to re-apply effects later
var owned_items: Array[ShopItem] = []
# Keep IDs for quick ownership checks in UI
var owned_item_ids: Array[String] = []
# Tracks the total value of all upgrades for rebuild cost calculation
var owned_items_total_cost: int = 0
# Keeps track of unlocked shops
var unlocked_shop_ids: Array[String] = []

# Called when buying from shop - DOES NOT apply stats yet
func purchase_item(item: ShopItem) -> void:
	owned_items.append(item)
	owned_item_ids.append(item.id)
	owned_items_total_cost += item.cost
	print("Upgrade Manager: Purchased %s (Total Value: %d)" % [item.display_name, owned_items_total_cost])

# Called when Rebuilding - Applies all effects to player
func apply_all_upgrades(player: Node2D) -> void:
	# 1. Reset modifiers to prevent infinite stacking (e.g. +10 speed becoming +20, +30)
	if "stats" in player and player.stats:
		player.stats.reset_modifiers()
		
	# 2. Re-apply all owned items
	for item in owned_items:
		for effect in item.effects:
			if effect:
				effect.apply(player)
				
	print("Upgrade Manager: All systems applied.")

func clear_upgrades() -> void:
	owned_items.clear()
	owned_item_ids.clear()
	owned_items_total_cost = 0

func unlock_shop(shop_id: String) -> void:
	if not shop_id in unlocked_shop_ids:
		unlocked_shop_ids.append(shop_id)

func is_shop_unlocked(shop_id: String) -> bool:
	return shop_id in unlocked_shop_ids