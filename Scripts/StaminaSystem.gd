extends Node
class_name StaminaSystem

## Jauge d'énergie qui limite le nombre de combats. Recharge automatique dans le temps.
## Valeurs de départ à calibrer en test -- voir GDD.md > Système d'énergie.

const MAX_STAMINA := 120
const RECHARGE_SECONDS := 300.0 # +1 point toutes les 5 minutes
const COST_PER_COMBAT := 6

var current_stamina: int = MAX_STAMINA
var _recharge_timer: float = 0.0

func _process(delta: float) -> void:
	if current_stamina >= MAX_STAMINA:
		return
	_recharge_timer += delta
	if _recharge_timer >= RECHARGE_SECONDS:
		_recharge_timer = 0.0
		current_stamina = min(current_stamina + 1, MAX_STAMINA)

func can_afford_combat() -> bool:
	return current_stamina >= COST_PER_COMBAT

## Retire le coût d'un combat si possible. Retourne false si pas assez d'énergie.
func spend_for_combat() -> bool:
	if not can_afford_combat():
		return false
	current_stamina -= COST_PER_COMBAT
	return true
