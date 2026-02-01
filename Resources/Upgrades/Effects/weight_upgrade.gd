class_name WeightUpgrade
extends UpgradeEffect

@export var amount: float = 5.0

func apply(player: Node2D) -> void:
    if "stats" in player and player.stats:
        player.stats.add_modifier("max_weight", amount)
