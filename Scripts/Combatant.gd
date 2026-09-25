extends RefCounted
class_name Combatant

## Un combattant en piste : ses stats du moment, sa jauge ATB, ses altérations d'état.
## Logique pure, sans accès aux données ni au rendu — CombatManager l'orchestre et
## PlayerManager/les données le fabriquent (voir CombatManager.from_character / from_enemy).

var id: String = ""
var name: String = ""
var element: String = ""
var is_ally: bool = false
## Vrai pour un guerrier nommé de la guilde rivale (fin de chapitre), faux pour un mob.
var is_boss: bool = false

var max_hp: int = 1
var hp: int = 1
var base_atk: int = 0
var base_def: int = 0
var base_vit: int = 0

var skill: Dictionary = {}
var skill_cooldown: int = 0

## Jauge ATB : le premier à atteindre le seuil agit (voir GDD.md > Système de combat).
var atb: float = 0.0

# Altérations en cours : [{"type", "duration", "value", ...}]
var statuses: Array[Dictionary] = []
## Compétence en cours de charge ({} si aucune) : elle se déclenchera au prochain tour.
var pending_skill: Dictionary = {}
## En garde : encaisse moitié moins jusqu'à son prochain tour (voir CombatManager.act).
var guarding: bool = false

func is_alive() -> bool:
	return hp > 0

## Somme des `value` des altérations d'un type donné (0.0 si aucune).
func status_value(type: String) -> float:
	var total := 0.0
	for status: Dictionary in statuses:
		if status.get("type", "") == type:
			total += float(status.get("value", 0.0))
	return total

func has_status(type: String) -> bool:
	for status: Dictionary in statuses:
		if status.get("type", "") == type:
			return true
	return false

## Altérations bénéfiques d'un côté, néfastes de l'autre : le nettoyage et le dissipement
## ont besoin de savoir laquelle est laquelle.
const HARMFUL := ["burn", "stun", "def_down", "atk_down"]
const BENEFICIAL := ["atk_up", "speed_up", "damage_reduction", "dodge", "empower", "heal_per_turn", "counter"]

func atk() -> int:
	return roundi(base_atk * (1.0 + status_value("atk_up") - minf(status_value("atk_down"), 0.7)))

func def() -> int:
	return roundi(base_def * (1.0 - minf(status_value("def_down"), 0.7)))

func vit() -> float:
	return base_vit * (1.0 + status_value("speed_up"))

## Part des dégâts absorbée par les protections en cours, plafonnée pour qu'un combattant
## reste toujours blessable.
func damage_reduction() -> float:
	return minf(status_value("damage_reduction"), 0.8)

func is_stunned() -> bool:
	return has_status("stun")

## Consomme une charge d'esquive si le combattant en a une. Retourne true s'il esquive.
func consume_dodge() -> bool:
	for index in range(statuses.size()):
		var status: Dictionary = statuses[index]
		if status.get("type", "") != "dodge":
			continue
		status["charges"] = int(status.get("charges", 1)) - 1
		if int(status["charges"]) <= 0:
			statuses.remove_at(index)
		return true
	return false

## Retire les altérations d'une famille. Retourne le nombre d'altérations retirées.
func remove_statuses(types: Array) -> int:
	var kept: Array[Dictionary] = []
	var removed := 0
	for status: Dictionary in statuses:
		if types.has(status.get("type", "")):
			removed += 1
		else:
			kept.append(status)
	statuses = kept
	return removed

func add_status(status: Dictionary) -> void:
	# Une altération déjà présente est rafraîchie plutôt qu'empilée : pas de cumul infini.
	for existing: Dictionary in statuses:
		if existing.get("type", "") == status.get("type", ""):
			existing["duration"] = maxi(int(existing.get("duration", 0)), int(status.get("duration", 0)))
			existing["value"] = maxf(float(existing.get("value", 0.0)), float(status.get("value", 0.0)))
			existing["charges"] = maxi(int(existing.get("charges", 0)), int(status.get("charges", 0)))
			return
	statuses.append(status.duplicate())

## Fait vieillir les altérations d'un tour et retire celles qui expirent.
## Les esquives (comptées en charges, pas en tours) ne vieillissent pas ici.
func tick_statuses() -> void:
	var remaining: Array[Dictionary] = []
	for status: Dictionary in statuses:
		if status.get("type", "") == "dodge":
			remaining.append(status)
			continue
		status["duration"] = int(status.get("duration", 0)) - 1
		if int(status["duration"]) > 0:
			remaining.append(status)
	statuses = remaining

func take_damage(amount: int) -> int:
	var dealt: int = clampi(amount, 0, hp)
	hp -= dealt
	return dealt

func heal(amount: int) -> int:
	var healed: int = clampi(amount, 0, max_hp - hp)
	hp += healed
	return healed
