class_name ShopUI
extends CanvasLayer

signal shop_closed
signal item_purchased(item: ShopItem)

@onready var grid_container: GridContainer = $Control/Panel/MarginContainer/GridContainer
@onready var title_label: Label = $Control/Panel/Label
@onready var description_label: Label = $Control/Panel/DescriptionLabel
@onready var cost_label: Label = $Control/Panel/CostLabel

var _items: Array[ShopItem] = []
var _owned_ids: Array[String] = [] # NEW: Tracks owned items
var _current_index: int = 0
var _is_active: bool = false
var _columns: int = 3
var _input_delay: float = 0.0
var _current_wallet: int = 0

# Styles
var style_normal: StyleBoxFlat
var style_selected: StyleBoxFlat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_setup_styles()
	if grid_container.columns > 0:
		_columns = grid_container.columns

func _setup_styles() -> void:
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	style_normal.set_corner_radius_all(8)
	
	style_selected = style_normal.duplicate()
	style_selected.border_width_left = 4
	style_selected.border_width_top = 4
	style_selected.border_width_right = 4
	style_selected.border_width_bottom = 4
	style_selected.border_color = Color.WHITE

# --- Public API ---

# UPDATED: Now accepts owned_ids
func populate_and_open(shop_name: String, items_for_sale: Array[ShopItem], current_money: int, owned_ids: Array[String]) -> void:
	title_label.text = shop_name.to_upper()
	_items = items_for_sale
	_current_index = 0
	_current_wallet = current_money
	_owned_ids = owned_ids # Store ownership data
	
	_rebuild_grid()
	
	_is_active = true
	_input_delay = 0.2
	visible = true
	get_tree().paused = true
	
	_update_visuals()

func close() -> void:
	_is_active = false
	visible = false
	get_tree().paused = false
	shop_closed.emit()

# --- Internal Logic ---

func _rebuild_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	
	# 1. EXIT Option
	var exit_panel = Panel.new()
	exit_panel.custom_minimum_size = Vector2(70, 70)
	exit_panel.add_theme_stylebox_override("panel", style_normal)
	
	var exit_label = Label.new()
	exit_label.text = "EXIT"
	exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit_label.anchors_preset = Control.PRESET_FULL_RECT
	exit_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	exit_panel.add_child(exit_label)
	
	grid_container.add_child(exit_panel)
	
	# 2. Shop Items
	for item in _items:
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(70, 70)
		panel.add_theme_stylebox_override("panel", style_normal)
		
		# NEW: Check ownership and apply gray effect
		var is_owned = item.id in _owned_ids
		if is_owned:
			panel.modulate = Color(0.5, 0.5, 0.5, 0.5) # Dim to 50% opacity
		
		if item.icon:
			var tex_rect = TextureRect.new()
			tex_rect.texture = item.icon
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(48, 48)
			tex_rect.position = Vector2(11, 11)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			if is_owned:
				tex_rect.modulate = Color(0.3, 0.3, 0.3) # Darken icon specifically
				
			panel.add_child(tex_rect)
			
		grid_container.add_child(panel)

func _process(delta: float) -> void:
	if not _is_active: return
	
	if _input_delay > 0:
		_input_delay -= delta
		return
	
	if Input.is_action_just_pressed("ui_right"): _move_selection(1)
	elif Input.is_action_just_pressed("ui_left"): _move_selection(-1)
	elif Input.is_action_just_pressed("ui_down"): _move_selection(_columns)
	elif Input.is_action_just_pressed("ui_up"): _move_selection(-_columns)
	elif Input.is_key_pressed(KEY_Z): _confirm_selection()
	elif Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_X): close()

func _move_selection(direction: int) -> void:
	var total_slots = grid_container.get_child_count()
	if total_slots == 0: return
	
	var new_index = _current_index + direction
	if new_index >= 0 and new_index < total_slots:
		_current_index = new_index
		_update_visuals()

func _confirm_selection() -> void:
	if _current_index == 0:
		close()
		return
		
	var item_index = _current_index - 1
	
	if item_index >= 0 and item_index < _items.size():
		var selected_item = _items[item_index]
		
		# NEW: Check ownership
		if selected_item.id in _owned_ids:
			_show_warning("Item already purchased!")
			return

		if _current_wallet < selected_item.cost:
			_show_warning("Not enough money!")
			return
			
		print("Purchased: ", selected_item.display_name)
		item_purchased.emit(selected_item)
		close()

func _show_warning(text: String) -> void:
	description_label.text = text
	description_label.modulate = Color(1, 0.3, 0.3)
	cost_label.text = ""

func _update_visuals() -> void:
	description_label.modulate = Color.WHITE
	
	# Update Grid
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		var panel = slots[i] as Panel
		if i == _current_index:
			panel.add_theme_stylebox_override("panel", style_selected)
		else:
			panel.add_theme_stylebox_override("panel", style_normal)

	# Update Info
	if _current_index == 0:
		description_label.text = "Leave the shop without buying anything."
		cost_label.text = ""
	else:
		var item_index = _current_index - 1
		if item_index < _items.size():
			var item = _items[item_index]
			
			description_label.text = item.description
			
			# NEW: Handle Owned State
			if item.id in _owned_ids:
				cost_label.text = "OWNED"
				cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5)) # Gray
			else:
				cost_label.text = "$ %d" % item.cost
				if _current_wallet >= item.cost:
					cost_label.add_theme_color_override("font_color", Color(1, 0.84, 0)) # Gold
				else:
					cost_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2)) # Red
