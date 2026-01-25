class_name SafeZone
extends Area2D

signal player_exited_zone
signal player_entered_zone # <--- NEW SIGNAL

func _ready() -> void:
	body_exited.connect(_on_body_exited)
	body_entered.connect(_on_body_entered) # <--- NEW CONNECTION

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_exited_zone.emit()

func _on_body_entered(body: Node2D) -> void: # <--- NEW FUNCTION
	if body is Player:
		player_entered_zone.emit()