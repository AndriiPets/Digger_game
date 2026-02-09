class_name TimeUpgrade
extends UpgradeEffect

@export var amount: float = 10.0

func apply(player: Node2D) -> void:
	if "stats" in player and player.stats:
		# Changed from "time_bonus" to "max_energy"
		player.stats.add_modifier("max_energy", amount)