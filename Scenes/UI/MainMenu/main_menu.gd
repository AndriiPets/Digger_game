class_name MainMenu
extends Node2D

@onready var start_button: Button = %StartButton
@onready var options_button: Button = %OptionsButton
@onready var buttons: Array[Button] = [start_button, options_button]

var _current_index: int = 0
# Track mouse usage to prevent conflict between keyboard and mouse focus
var _using_mouse: bool = false

func _ready() -> void:
	# Stop music in main menu
	SoundManager.stop_loop("music")
	# Initialize focus
	_update_selection(0, false)

	# Connect Button Signals
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)

	# Mouse Hover Support
	start_button.mouse_entered.connect(func(): _on_mouse_hover(0))
	options_button.mouse_entered.connect(func(): _on_mouse_hover(1))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_using_mouse = true
		return

	if event.is_action_pressed("UP"):
		get_viewport().set_input_as_handled()
		_using_mouse = false
		_change_selection(-1)

	elif event.is_action_pressed("DOWN"):
		get_viewport().set_input_as_handled()
		_using_mouse = false
		_change_selection(1)

	elif event.is_action_pressed("ACTION"):
		# Trigger the currently selected button
		get_viewport().set_input_as_handled()
		buttons[_current_index].pressed.emit()

func _change_selection(direction: int) -> void:
	var new_index = wrapi(_current_index + direction, 0, buttons.size())
	if new_index != _current_index:
		_update_selection(new_index)

func _update_selection(index: int, play_sound: bool = true) -> void:
	_current_index = index
	buttons[_current_index].grab_focus()
	if play_sound:
		SoundManager.play_sfx("switch")

func _on_mouse_hover(index: int) -> void:
	if _using_mouse and _current_index != index:
		_update_selection(index)

func _on_start_pressed() -> void:
	SoundManager.play_sfx("select")
	# Transition to the main game scene
	get_tree().change_scene_to_file("res://Scenes/TestScenes/TestScene.tscn")

func _on_options_pressed() -> void:
	SoundManager.play_sfx("select")
	print("Options Menu (Not Implemented)")
