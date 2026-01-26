class_name InventoryComponent
extends Node

# Signals
signal inventory_updated(item: TileDefinition, total_amount: int)
signal inventory_changed_value(current_weight: float, max_weight: float)
signal inventory_cleared

# Config
@export var max_weight: float = 15.0
@export var is_infinite: bool = false

# Storage
var _storage: Dictionary = {}
var current_weight: float = 0.0

func _ready() -> void:
	# Emit initial state
	inventory_changed_value.emit(current_weight, max_weight)

# Changed return type to bool
func add_item(item: TileDefinition, amount: int = 1) -> bool:
	if not item: return false
	
	var weight_to_add = item.weight * amount
	
	# Check constraints (skip if infinite)
	if not is_infinite and (current_weight + weight_to_add > max_weight):
		return false # Rejected
		
	# Logic to add item
	if _storage.has(item):
		_storage[item] += amount
	else:
		_storage[item] = amount
	
	current_weight += weight_to_add
	
	inventory_updated.emit(item, _storage[item])
	inventory_changed_value.emit(current_weight, max_weight) # Update UI
	
	return true # Accepted

func clear() -> void:
	_storage.clear()
	current_weight = 0.0
	inventory_cleared.emit()
	inventory_changed_value.emit(current_weight, max_weight)

func transfer_to(target_inventory: InventoryComponent) -> void:
	if _storage.is_empty(): return
	
	for item in _storage:
		# Note: We assume Stash has infinite or very large space
		target_inventory.add_item(item, _storage[item])
	
	clear()

# --- NEW: Calculate total value of items ---
func get_total_value() -> int:
	var total: int = 0
	for item in _storage:
		if item:
			total += item.base_value * _storage[item]
	return total

# --- Helper for debugging ---
func get_debug_string() -> String:
	if _storage.is_empty():
		return " (Empty)"
		
	var text = ""
	for item in _storage:
		var n = item.display_name if item.display_name else "Block"
		var q = _storage[item]
		text += "\n   - %s: %d" % [n, q]
	return text