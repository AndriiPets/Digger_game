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
# NEW: Track accumulated monetary value of stored items separate from count
# This allows Depth 1 Iron (worth less) and Depth 100 Iron (worth more) to stack in count, but preserve total value.
var _value_storage: Dictionary = {}

var current_weight: float = 0.0

func _ready() -> void:
	# Emit initial state
	inventory_changed_value.emit(current_weight, max_weight)

# UPDATED: Added unit_value parameter
func add_item(item: TileDefinition, amount: int = 1, unit_value: int = -1) -> bool:
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
	
	# Logic to add value
	# If no specific value provided, fallback to base_value
	var val_per_item = unit_value if unit_value >= 0 else item.base_value
	var total_added_value = val_per_item * amount
	
	if _value_storage.has(item):
		_value_storage[item] += total_added_value
	else:
		_value_storage[item] = total_added_value
	
	current_weight += weight_to_add
	
	inventory_updated.emit(item, _storage[item])
	inventory_changed_value.emit(current_weight, max_weight) # Update UI
	
	return true # Accepted

func clear() -> void:
	_storage.clear()
	_value_storage.clear()
	current_weight = 0.0
	inventory_cleared.emit()
	inventory_changed_value.emit(current_weight, max_weight)

func transfer_to(target_inventory: InventoryComponent) -> void:
	if _storage.is_empty(): return
	
	for item in _storage:
		# Note: We assume Stash has infinite or very large space.
		# Ideally we pass the value too, but if the stash uses the same system,
		# we would need to pass the average value or just the sum.
		# For now, we estimate unit value based on stored total.
		var stored_val = _value_storage.get(item, 0)
		var count = _storage[item]
		var avg_val = item.base_value
		
		if count > 0:
			avg_val = int(stored_val / count)
		
		target_inventory.add_item(item, count, avg_val)
	
	clear()

# UPDATED: Calculate total value from stored value dictionary
func get_total_value() -> int:
	var total: int = 0
	for val in _value_storage.values():
		total += val
	return total

# --- Helper for debugging ---
func get_debug_string() -> String:
	if _storage.is_empty():
		return " (Empty)"
		
	var text = ""
	for item in _storage:
		var n = item.display_name if item.display_name else "Block"
		var q = _storage[item]
		var v = _value_storage.get(item, 0)
		text += "\n   - %s: %d (Val: %d)" % [n, q, v]
	return text