class_name UpgradeManager
extends Node

# Keeps track of what we bought (useful for saving/loading later)
var owned_item_ids: Array[String] = []

func apply_upgrade(item: ShopItem) -> void:
	# 1. Record ownership
	owned_item_ids.append(item.id)
	
	# 2. Apply all effects
	# We assume the parent is the Player
	var player = get_parent()
	
	for effect in item.effects:
		if effect:
			effect.apply(player)
			
	print("Upgrade Manager: Acquired %s" % item.display_name)

# --- NEW FUNCTION ---
func clear_upgrades() -> void:
	owned_item_ids.clear()