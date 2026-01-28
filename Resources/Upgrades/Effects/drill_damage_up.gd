class_name DrillDamageUpgrade
extends UpgradeEffect

@export var extra_damage: int = 1

func apply(player: Node2D) -> void:
	# Check for stats component
	if "stats" in player and player.stats:
		# We hardcode the string here so you don't have to type it in the inspector
		player.stats.add_modifier("dig_damage", float(extra_damage))
		print("Drill Upgrade Applied: Damage +%d" % extra_damage)
