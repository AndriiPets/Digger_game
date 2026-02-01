class_name StatsComponent
extends Node

# Signal to notify other systems (like UI or Inventory)
signal stat_changed(stat_name: String, new_value: float)

var _base_stats: Dictionary = {}
var _modifiers: Dictionary = {}

func initialize(stat_name: String, value: float) -> void:
	_base_stats[stat_name] = value
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = 0.0
	# Emit initial value
	stat_changed.emit(stat_name, get_value(stat_name))

func add_modifier(stat_name: String, value: float) -> void:
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = 0.0
	
	_modifiers[stat_name] += value
	stat_changed.emit(stat_name, get_value(stat_name))

func get_value(stat_name: String) -> float:
	var base = _base_stats.get(stat_name, 0.0)
	var mod = _modifiers.get(stat_name, 0.0)
	return base + mod

func reset_modifiers() -> void:
	_modifiers.clear()
	# Notify listeners that values have likely dropped back to base
	for stat in _base_stats:
		stat_changed.emit(stat, _base_stats[stat])