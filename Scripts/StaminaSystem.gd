extends RefCounted
class_name StaminaSystem

## Jauge d'énergie qui limite le nombre de combats. Recharge automatique basée sur l'horloge
## système : l'énergie continue de remonter quand le jeu est fermé.
## Valeurs dans Data/economy.json > stamina -- voir GDD.md > Système d'énergie.

var max_stamina: int = 120
var recharge_seconds: float = 300.0
var cost_per_combat: int = 6

var _current: int = 0
# Horodatage (unix) du début de la recharge du prochain point.
var _last_tick: float = 0.0

## Horloge injectable pour les tests (Callable -> float, temps unix en secondes).
var clock: Callable = Time.get_unix_time_from_system

func _init() -> void:
	var config: Dictionary = DataLoader.economy().get("stamina", {})
	max_stamina = int(config.get("max", max_stamina))
	recharge_seconds = float(config.get("recharge_seconds", recharge_seconds))
	cost_per_combat = int(config.get("cost_per_combat", cost_per_combat))
	reset_full()

func reset_full() -> void:
	_current = max_stamina
	_last_tick = clock.call()

## Applique la recharge écoulée depuis le dernier calcul.
func _refresh() -> void:
	var now: float = clock.call()
	if _current >= max_stamina or now < _last_tick:
		# Jauge pleine (pas d'accumulation) ou horloge reculée : on repart de maintenant.
		_last_tick = now
		return
	var gained := floori((now - _last_tick) / recharge_seconds)
	if gained <= 0:
		return
	_current = mini(_current + gained, max_stamina)
	_last_tick = now if _current >= max_stamina else _last_tick + gained * recharge_seconds

func get_current() -> int:
	_refresh()
	return _current

## Secondes avant le prochain point (0 si la jauge est pleine).
func seconds_to_next_point() -> float:
	_refresh()
	if _current >= max_stamina:
		return 0.0
	return maxf(0.0, recharge_seconds - (clock.call() - _last_tick))

func can_afford_combat() -> bool:
	return get_current() >= cost_per_combat

## Retire le coût d'un combat si possible. Retourne false si pas assez d'énergie.
func spend_for_combat() -> bool:
	# can_afford_combat() rafraîchit la jauge ; si elle était pleine, _last_tick vaut maintenant
	# et la recharge démarre donc à la sortie du plafond.
	if not can_afford_combat():
		return false
	_current -= cost_per_combat
	return true

func to_dict() -> Dictionary:
	_refresh()
	return {"current": _current, "last_tick": _last_tick}

func from_dict(data: Dictionary) -> void:
	_current = clampi(int(data.get("current", max_stamina)), 0, max_stamina)
	_last_tick = float(data.get("last_tick", clock.call()))
	_refresh()
