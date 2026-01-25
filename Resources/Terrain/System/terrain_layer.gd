class_name TerrainLayer
extends Resource

@export_group("Depth Settings")
@export var layer_name: String
@export var max_depth: int = 40

@export_group("Blocks")
# In the Inspector, you will see a list. Click "Add Element", 
# select "New SpawnWeight", and fill in the Block and Weight immediately.
@export var structural_pool: Array[SpawnWeight] = []
@export var resource_pool: Array[SpawnWeight] = []

# Helper to get valid blocks for caching
func get_all_blocks() -> Array[TileDefinition]:
	var list: Array[TileDefinition] = []
	for entry in structural_pool:
		if entry.block: list.append(entry.block)
	for entry in resource_pool:
		if entry.block: list.append(entry.block)
	return list