class_name RefuelingStation
extends Area2D

@onready var prompt_label: Label = $PromptLabel
@onready var ui: RefuelUI = $RefuelUI

var _player_ref: Player
var _in_range: bool = false
var _manager: GameLoop

func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	prompt_label.visible = false
	
	ui.refuel_requested.connect(_on_refuel_requested)
	ui.closed.connect(_on_ui_closed)

func _process(_delta: float) -> void:
	if _in_range and not ui.visible:
		if Input.is_action_just_pressed("ACTION"):
			SoundManager.play_sfx("select")
			_open_interface()

func _open_interface() -> void:
	if not _manager:
		var managers = get_tree().get_nodes_in_group("game_manager")
		if not managers.is_empty():
			_manager = managers[0]
	
	if not _player_ref: return
	
	var current_fuel = _player_ref.current_energy
	var max_fuel = _player_ref.stats.get_value("max_energy") if _player_ref.stats else 100.0
	var money = _manager.total_money if _manager else 0
	
	ui.open(current_fuel, max_fuel, money)
	prompt_label.visible = false

func _on_refuel_requested(cost: int) -> void:
	if not _manager:
		var managers = get_tree().get_nodes_in_group("game_manager")
		if not managers.is_empty():
			_manager = managers[0]
			
	if _manager:
		var success = _manager.try_purchase_refuel(cost)
		if success:
			# Refresh UI
			_open_interface()

func _on_ui_closed() -> void:
	if _in_range:
		prompt_label.visible = true

func _on_entered(body: Node2D) -> void:
	if body is Player:
		_player_ref = body
		_in_range = true
		prompt_label.visible = true

func _on_exited(body: Node2D) -> void:
	if body is Player:
		_player_ref = null
		_in_range = false
		prompt_label.visible = false
		ui.close()