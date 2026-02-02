class_name UpgradeManager
extends Node

# Keeps track of what we bought
var owned_item_ids: Array[String] = []
# NEW: Keeps track of unlocked shops
var unlocked_shop_ids: Array[String] = []

func apply_upgrade(item: ShopItem) -> void:
	owned_item_ids.append(item.id)
	
	var player = get_parent()
	for effect in item.effects:
		if effect:
			effect.apply(player)
			
	print("Upgrade Manager: Acquired %s" % item.display_name)

func clear_upgrades() -> void:
	owned_item_ids.clear()
	# Note: We usually don't clear unlocked shops on death if they are permanent, 
	# but for this game loop reset, we might want to keep them. 
	# If you want resets to wipe shop unlocks, uncomment the next line:
	# unlocked_shop_ids.clear()

# --- NEW FUNCTIONS ---
func unlock_shop(shop_id: String) -> void:
	if not shop_id in unlocked_shop_ids:
		unlocked_shop_ids.append(shop_id)

func is_shop_unlocked(shop_id: String) -> bool:
	return shop_id in unlocked_shop_ids