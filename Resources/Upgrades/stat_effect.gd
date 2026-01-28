class_name StatEffect
extends UpgradeEffect

@export var stat_name: String = "move_speed"
@export var value: float = 10.0

func apply(player: Node2D) -> void:
	# Duck-typing: Check if player has the stats component
	if "stats" in player and player.stats != null:
		player.stats.add_modifier(stat_name, value)
		print("Applied Stat Effect: %s += %f" % [stat_name, value])
