class_name RobotEntity
extends Area2D

signal player_embarked

enum State {FUNCTIONAL, BROKEN, EMBARKED}

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var static_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

# In a real project, assign these in Inspector
# For now, we modify the sprite properties in code
var _original_modulate: Color

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_original_modulate = sprite.modulate

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_embarked.emit()
		set_state(State.EMBARKED)

func set_state(state: State) -> void:
	match state:
		State.FUNCTIONAL:
			visible = true
			collision_shape.set_deferred("disabled", false) # Can enter
			static_collision.set_deferred("disabled", true) # No collision wall
			sprite.modulate = _original_modulate
			label.text = "MECH"
			
		State.BROKEN:
			visible = true
			collision_shape.set_deferred("disabled", true) # Cannot enter
			static_collision.set_deferred("disabled", false) # Wall active
			sprite.modulate = Color(0.3, 0.3, 0.3) # Dark/Burnt look
			label.text = "WRECK"
			
		State.EMBARKED:
			visible = false
			collision_shape.set_deferred("disabled", true)
			static_collision.set_deferred("disabled", true)

# Legacy support for existing calls (mapping boolean to state)
func set_active(is_active: bool) -> void:
	if is_active:
		set_state(State.FUNCTIONAL)
	else:
		set_state(State.BROKEN)