class_name ShopUnlockUI
extends CanvasLayer

signal unlock_confirmed
signal unlock_cancelled

@onready var panel: Panel = $Control/Panel
@onready var title_label: Label = $Control/Panel/TitleLabel
@onready var cost_label: Label = $Control/Panel/CostLabel
@onready var warning_label: Label = $Control/Panel/WarningLabel

var _cost: int = 0
var _can_afford: bool = false
var _is_active: bool = false
var _input_delay: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(shop_name: String, cost: int, current_money: int) -> void:
	_cost = cost
	_can_afford = (current_money >= cost) or Globals.debt
	
	title_label.text = "Unlock %s?" % shop_name
	cost_label.text = "Cost: %d G" % cost
	
	if _can_afford:
		cost_label.modulate = Color.GREEN
		warning_label.text = "Press [Z] to Unlock"
		warning_label.modulate = Color.WHITE
	else:
		cost_label.modulate = Color.RED
		warning_label.text = "Not enough money"
		warning_label.modulate = Color(1, 0.3, 0.3)
	
	visible = true
	_is_active = true
	_input_delay = 0.3 # NEW: Wait 0.3s before accepting input to prevent accidental double-press
	get_tree().paused = true

func close() -> void:
	visible = false
	_is_active = false
	get_tree().paused = false

func _process(delta: float) -> void:
	if not _is_active: return
	
	# NEW: Delay check
	if _input_delay > 0:
		_input_delay -= delta
		return
	
	if Input.is_key_pressed(KEY_Z):
		if _can_afford:
			unlock_confirmed.emit()
			close()
		else:
			# Optional feedback
			pass
			
	elif Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_ESCAPE):
		unlock_cancelled.emit()
		close()