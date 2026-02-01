class_name TimeUpgrade
extends UpgradeEffect

@export var amount: float = 30.0

func apply(player: Node2D) -> void:
    if "stats" in player and player.stats:
        player.stats.add_modifier("time_bonus", amount)
