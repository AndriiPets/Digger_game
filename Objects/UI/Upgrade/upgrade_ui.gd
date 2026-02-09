class_name UpgradeUI
extends CanvasLayer

signal item_purchased(category_id: String, item: ShopItem)
signal item_equipped(category_id: String, item: ShopItem)
signal closed
signal rebuild_requested(cost: int)

enum State {CATEGORY_SELECT, ITEM_SELECT}

@onready var container_vbox: VBoxContainer = %CategoryContainer
@onready var info_panel: Panel = %InfoPanel
@onready var info_title: Label = %InfoTitle
@onready var info_desc: Label = %InfoDesc
@onready var info_cost: Label = %InfoCost
@onready var wallet_label: Label = %WalletLabel

# Rebuild UI
@onready var rebuild_status_label: Label = %StatusLabel
@onready var rebuild_cost_label: Label = %CostLabel
@onready var rebuild_action_label: Label = %ActionLabel

var _categories: Array[ShopCategory] = []
var _owned_ids: Array[String] = []
var _equipped_ids_map: Dictionary = {} # { "cat_id": "item_id" }
var _current_money: int = 0
var _rebuild_cost: int = 0
var _is_robot_built: bool = false
var _has_pending: bool = false

var _state: State = State.CATEGORY_SELECT
var _selected_cat_index: int = 0
var _selected_item_index: int = 0
var _active_grid: GridContainer = null

# Visual Settings
var color_normal = Color(0.15, 0.15, 0.15, 0.9)
var color_selected = Color(0.3, 0.6, 0.9, 0.9)
var color_expanded = Color(0.25, 0.25, 0.25, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

# UPDATED: Accepts equipped_map
func open(categories: Array[ShopCategory], money: int, owned_ids: Array[String], equipped_map: Dictionary, total_equipped_value: int, is_built: bool, has_pending: bool) -> void:
	_categories = []
	for cat in categories:
		if cat != null:
			_categories.append(cat)

	_current_money = money
	_owned_ids = owned_ids
	_equipped_ids_map = equipped_map
	_is_robot_built = is_built
	_has_pending = has_pending

	# Rebuild cost is based on active/equipped configuration
	_rebuild_cost = floor(total_equipped_value * 0.5)

	_state = State.CATEGORY_SELECT
	_selected_cat_index = 0
	_selected_item_index = 0

	wallet_label.text = "Funds: $%d" % money

	_rebuild_main_list()
	visible = true
	get_tree().paused = true

	_update_visuals()
	_update_rebuild_panel()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible: return

	if event.is_action_pressed("CANCEL") or event.is_action_pressed("ui_menu"):
		if _state == State.ITEM_SELECT:
			_collapse_category()
			SoundManager.play_sfx("close")
		else:
			close()
			SoundManager.play_sfx("close")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("REBUILD"):
		if not _is_robot_built or _has_pending:
			rebuild_requested.emit(_rebuild_cost)

	if _state == State.CATEGORY_SELECT:
		_handle_category_input(event)
	elif _state == State.ITEM_SELECT:
		_handle_item_input(event)

# UPDATED: Accepts equipped_map
func refresh_state(money: int, owned_ids: Array[String], equipped_map: Dictionary, total_value: int, is_built: bool, has_pending: bool) -> void:
	_current_money = money
	_owned_ids = owned_ids
	_equipped_ids_map = equipped_map
	_is_robot_built = is_built
	_has_pending = has_pending
	_rebuild_cost = floor(total_value * 0.5)

	wallet_label.text = "Funds: $%d" % money
	
	if _state == State.CATEGORY_SELECT:
		_rebuild_main_list()
	elif _state == State.ITEM_SELECT:
		# If inside a category, refresh the grid to show new Equipped status
		_refresh_active_grid()
		
	_update_visuals()
	_update_rebuild_panel()

func _update_rebuild_panel() -> void:
	if not _is_robot_built:
		rebuild_status_label.text = "STATUS: BROKEN"
		rebuild_status_label.modulate = Color.RED
		_set_rebuild_ui_active(true)
	elif _has_pending:
		rebuild_status_label.text = "STATUS: UPDATE PENDING"
		rebuild_status_label.modulate = Color.ORANGE
		_set_rebuild_ui_active(true)
	else:
		rebuild_status_label.text = "STATUS: ONLINE"
		rebuild_status_label.modulate = Color.GREEN
		_set_rebuild_ui_active(false)

func _set_rebuild_ui_active(is_active: bool) -> void:
	if is_active:
		if _rebuild_cost > 0:
			rebuild_cost_label.text = "COST: $%d" % _rebuild_cost
		else:
			rebuild_cost_label.text = "COST: FREE"

		rebuild_action_label.text = "[R] REBUILD/UPDATE"

		# Rebuild is MAINTENANCE (false)
		if Globals.can_afford(_rebuild_cost, _current_money, false):
			rebuild_action_label.modulate = Color(1, 0.8, 0.2)
		else:
			rebuild_action_label.modulate = Color.RED
	else:
		rebuild_cost_label.text = ""
		rebuild_action_label.text = "SYSTEMS READY"
		rebuild_action_label.modulate = Color.DARK_GRAY

func _handle_category_input(event: InputEvent) -> void:
	if _categories.is_empty(): return

	if event.is_action_pressed("DOWN"):
		_selected_cat_index = wrapi(_selected_cat_index + 1, 0, _categories.size())
		_update_visuals()
		SoundManager.play_sfx("switch")
	elif event.is_action_pressed("UP"):
		_selected_cat_index = wrapi(_selected_cat_index - 1, 0, _categories.size())
		_update_visuals()
		SoundManager.play_sfx("switch")
	elif event.is_action_pressed("ACTION"):
		_expand_category()
		SoundManager.play_sfx("select")

func _handle_item_input(event: InputEvent) -> void:
	if _categories.is_empty(): return

	var category = _categories[_selected_cat_index]
	var item_count = category.items.size()
	var total_slots = item_count + 1
	var columns = 3

	if event.is_action_pressed("RIGHT"):
		_selected_item_index = wrapi(_selected_item_index + 1, 0, total_slots)
		_update_visuals()
		SoundManager.play_sfx("switch")
	elif event.is_action_pressed("LEFT"):
		_selected_item_index = wrapi(_selected_item_index - 1, 0, total_slots)
		_update_visuals()
		SoundManager.play_sfx("switch")
	elif event.is_action_pressed("DOWN"):
		var next = _selected_item_index + columns
		if next < total_slots:
			_selected_item_index = next
			_update_visuals()
			SoundManager.play_sfx("switch")
	elif event.is_action_pressed("UP"):
		var prev = _selected_item_index - columns
		if prev >= 0:
			_selected_item_index = prev
			_update_visuals()
			SoundManager.play_sfx("switch")
	elif event.is_action_pressed("ACTION"):
		_confirm_item_selection()
		SoundManager.play_sfx("select")

func _rebuild_main_list() -> void:
	for child in container_vbox.get_children():
		child.queue_free()

	if _categories.is_empty():
		return

	for i in range(_categories.size()):
		var cat = _categories[i]
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = color_normal
		style.set_corner_radius_all(4)
		style.content_margin_left = 10
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)

		var label = Label.new()
		label.text = cat.display_name.to_upper()
		vbox.add_child(label)

		# Find name of equipped item
		var equipped_id = _equipped_ids_map.get(cat.id, "")
		var item_name = "None"
		
		if equipped_id != "":
			for item in cat.items:
				if item.id == equipped_id:
					item_name = item.display_name
					break
		
		var sub_label = Label.new()
		sub_label.text = "Equipped: %s" % item_name
		sub_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		sub_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(sub_label)

		panel.add_child(vbox)
		container_vbox.add_child(panel)

func _expand_category() -> void:
	var category = _categories[_selected_cat_index]
	var panel = container_vbox.get_child(_selected_cat_index)

	var content_vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = category.display_name.to_upper()
	label.add_theme_color_override("font_color", Color.YELLOW)
	content_vbox.add_child(label)

	var sep = HSeparator.new()
	content_vbox.add_child(sep)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)

	_active_grid = grid
	_refresh_active_grid()

	content_vbox.add_child(grid)

	for child in panel.get_children(): child.queue_free()
	panel.add_child(content_vbox)

	_state = State.ITEM_SELECT
	_selected_item_index = 0
	_update_visuals()

func _refresh_active_grid() -> void:
	if not _active_grid: return
	
	for child in _active_grid.get_children():
		child.queue_free()
		
	var category = _categories[_selected_cat_index]
	var equipped_id = _equipped_ids_map.get(category.id, "")

	# 1. Back Button
	var exit_btn = _create_panel_base()
	var exit_lbl = Label.new()
	exit_lbl.text = "BACK"
	exit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit_lbl.anchors_preset = Control.PRESET_FULL_RECT
	exit_btn.add_child(exit_lbl)
	_active_grid.add_child(exit_btn)

	# 2. Items
	for item in category.items:
		var is_owned = item.id in _owned_ids
		var is_equipped = (item.id == equipped_id)
		
		var item_panel = _create_panel_base()
		
		if item and item.icon:
			var tex = TextureRect.new()
			tex.texture = item.icon
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(40, 40)
			tex.position = Vector2(12, 12)
			item_panel.add_child(tex)

		# Visual States
		if is_equipped:
			item_panel.modulate = Color(0.2, 1.0, 0.2, 1.0) # Green Tint
			# Add 'E' marker
			var e_lbl = Label.new()
			e_lbl.text = "E"
			e_lbl.position = Vector2(4, 4)
			e_lbl.add_theme_color_override("font_color", Color.BLACK)
			e_lbl.add_theme_stylebox_override("normal", _make_label_bg(Color.WHITE))
			item_panel.add_child(e_lbl)
		elif is_owned:
			item_panel.modulate = Color(0.7, 0.7, 0.7, 1.0) # Normal Gray
		else:
			item_panel.modulate = Color(1, 1, 1, 1) # Full Brightness

		_active_grid.add_child(item_panel)

func _create_panel_base() -> Panel:
	var p = Panel.new()
	p.custom_minimum_size = Vector2(64, 64)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.set_corner_radius_all(4)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.TRANSPARENT
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_label_bg(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.content_margin_left = 4
	s.content_margin_right = 4
	return s

func _collapse_category() -> void:
	_rebuild_main_list()
	_active_grid = null
	_state = State.CATEGORY_SELECT
	_update_visuals()

func _confirm_item_selection() -> void:
	if _selected_item_index == 0:
		_collapse_category()
		return

	var category = _categories[_selected_cat_index]
	var item_idx = _selected_item_index - 1
	if item_idx < category.items.size():
		var item = category.items[item_idx]
		var equipped_id = _equipped_ids_map.get(category.id, "")
		
		# If already equipped, do nothing
		if item.id == equipped_id:
			return

		if item.id in _owned_ids:
			# Just Swap
			item_equipped.emit(category.id, item)
		else:
			# Buy - Upgrade
			if Globals.can_afford(item.cost, _current_money, true):
				item_purchased.emit(category.id, item)

func _update_visuals() -> void:
	if _categories.is_empty(): return

	for i in range(container_vbox.get_child_count()):
		var panel = container_vbox.get_child(i) as PanelContainer
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat

		if i == _selected_cat_index:
			style.bg_color = color_selected
			style.border_width_left = 4
			style.border_color = Color.WHITE
		else:
			style.bg_color = color_normal
			style.border_width_left = 0

		if _state == State.ITEM_SELECT and i == _selected_cat_index:
			style.bg_color = color_expanded

	if _active_grid:
		for i in range(_active_grid.get_child_count()):
			var cell = _active_grid.get_child(i) as Panel
			var style = cell.get_theme_stylebox("panel") as StyleBoxFlat

			if i == _selected_item_index:
				style.border_color = Color.WHITE
			else:
				style.border_color = Color.TRANSPARENT

	_update_info_panel()

func _update_info_panel() -> void:
	if _state == State.CATEGORY_SELECT:
		var cat = _categories[_selected_cat_index]
		info_title.text = cat.display_name
		info_desc.text = "Select to equip or upgrade."
		info_cost.text = ""
	elif _state == State.ITEM_SELECT:
		if _selected_item_index == 0:
			info_title.text = "Back"
			info_desc.text = "Return to category list."
			info_cost.text = ""
		else:
			var cat = _categories[_selected_cat_index]
			var item = cat.items[_selected_item_index - 1]
			var equipped_id = _equipped_ids_map.get(cat.id, "")
			
			info_title.text = item.display_name
			info_desc.text = item.description

			if item.id == equipped_id:
				info_cost.text = "EQUIPPED"
				info_cost.modulate = Color.GREEN
			elif item.id in _owned_ids:
				info_cost.text = "OWNED"
				info_cost.modulate = Color.GRAY
			else:
				info_cost.text = "$ %d" % item.cost
				# Upgrade Cost Check
				if Globals.can_afford(item.cost, _current_money, true):
					info_cost.modulate = Color.GOLD
				else:
					info_cost.modulate = Color.RED