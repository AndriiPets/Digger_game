extends Node

enum DebtStrategy {NO_DEBT, NO_UPGRADES, ALL_DEBT}

var debug_mode: bool = false
# Default to ALL_DEBT to match previous behavior
var current_debt_strategy: DebtStrategy = DebtStrategy.NO_UPGRADES

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_mode = not debug_mode

# Helper to centralize debt logic
func can_afford(cost: int, current_money: int, is_upgrade: bool) -> bool:
	# Always allow if we actually have the money
	if current_money >= cost:
		return true
		
	match current_debt_strategy:
		DebtStrategy.NO_DEBT:
			return false
		DebtStrategy.NO_UPGRADES:
			# If it is an upgrade, we cannot go into debt.
			# If it is NOT an upgrade (repair/fuel), we CAN go into debt.
			return not is_upgrade
		DebtStrategy.ALL_DEBT:
			return true
			
	return false