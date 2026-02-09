class_name FlySpeedUpgrade
extends UpgradeEffect

@export var amount: float = 20.0

func apply(player: Node2D) -> void:
	if "stats" in player and player.stats:
		player.stats.add_modifier("fly_speed", amount)
