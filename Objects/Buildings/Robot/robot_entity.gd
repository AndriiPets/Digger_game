class_name RobotEntity
extends Area2D

signal player_embarked

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_embarked.emit()
		set_active(false)

func set_active(is_active: bool) -> void:
	visible = is_active
	collision_shape.set_deferred("disabled", not is_active)
