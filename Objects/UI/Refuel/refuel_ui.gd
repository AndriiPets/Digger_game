class_name RefuelUI
extends CanvasLayer

signal refuel_requested(cost: int)
signal closed

@onready var status_label: Label = %StatusLabel
@onready var cost_label: Label = %CostLabel
@onready var action_label: Label = %ActionLabel
@onready var wallet_label: Label = %WalletLabel

var _cost: int = 0
var _can_afford: bool = false
var _fuel_missing: float = 0.0

const PRICE_PER_BATCH: int = 1
const BATCH_SIZE: float = 10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(current_fuel: float, max_fuel: float, money: int) -> void:
	_fuel_missing = max_fuel - current_fuel
	
	# Logic: 12 missing / 10.0 = 1.2 -> ceil(1.2) = 2 batches -> $2
	var batches = ceil(_fuel_missing / BATCH_SIZE)
	_cost = int(batches * PRICE_PER_BATCH)
	
	# Safety for almost full tank
	if _cost == 0 and _fuel_missing > 0:
		_cost = 1
	elif _fuel_missing <= 0:
		_cost = 0

	# Refuel is NOT an upgrade
	_can_afford = Globals.can_afford(_cost, money, false)
	
	# Update UI Text
	wallet_label.text = "Funds: $%d" % money
	status_label.text = "Fuel Level: %d / %d" % [int(current_fuel), int(max_fuel)]
	
	if _fuel_missing <= 0:
		cost_label.text = "TANK FULL"
		cost_label.modulate = Color.GREEN
		action_label.text = "SYSTEMS READY"
		action_label.modulate = Color.GRAY
	else:
		cost_label.text = "Refuel Cost: $%d" % _cost
		
		if _can_afford:
			cost_label.modulate = Color.WHITE
			action_label.text = "[Z] CONFIRM REFUEL"
			action_label.modulate = Color(1, 0.8, 0.2) # Gold
		else:
			cost_label.modulate = Color.RED
			action_label.text = "INSUFFICIENT FUNDS"
			action_label.modulate = Color.RED
	
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("CANCEL") or event.is_action_pressed("ui_menu"):
		close()
		SoundManager.play_sfx("close")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ACTION"): # Z Key
		if _cost > 0 and _can_afford:
			refuel_requested.emit(_cost)
			get_viewport().set_input_as_handled()