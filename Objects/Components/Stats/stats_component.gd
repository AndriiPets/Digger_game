class_name StatsComponent
extends Node

# Stores the starting values (e.g., {"move_speed": 150.0})
var _base_stats: Dictionary = {}

# Stores the sum of all upgrades (e.g., {"move_speed": 20.0})
var _modifiers: Dictionary = {}

func initialize(stat_name: String, value: float) -> void:
	_base_stats[stat_name] = value
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = 0.0

func add_modifier(stat_name: String, value: float) -> void:
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = 0.0
	
	_modifiers[stat_name] += value

func get_value(stat_name: String) -> float:
	var base = _base_stats.get(stat_name, 0.0)
	var mod = _modifiers.get(stat_name, 0.0)
	return base + mod

# --- NEW FUNCTION ---
func reset_modifiers() -> void:
	_modifiers.clear()