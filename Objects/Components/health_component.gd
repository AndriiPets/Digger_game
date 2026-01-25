class_name HealthComponent
extends Node

# Signals
signal died
signal health_changed(new_amount: int, delta: int)
signal damaged(amount: int)
signal healed(amount: int)

# Exports
@export var max_health: int = 1
@export var current_health: int = 1

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
		
	current_health -= amount
	current_health = max(0, current_health)
	
	health_changed.emit(current_health, -amount)
	damaged.emit(amount)
	
	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	if amount <= 0:
		return
		
	current_health += amount
	current_health = min(current_health, max_health)
	
	health_changed.emit(current_health, amount)
	healed.emit(amount)
