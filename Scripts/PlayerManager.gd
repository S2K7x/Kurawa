extends Node
class_name PlayerManager

## Gère les ressources du joueur, son inventaire de personnages et la sauvegarde locale.
## Sauvegarde locale uniquement (pas de compte/cloud) -- voir GDD.md > Ambition et portée du projet.

const SAVE_PATH := "user://kurawa_save.json"
const DB_PATH := "res://Data/characters_db.json"

var eclats_dimensionnels: int = 0
var or_de_guilde: int = 0

# inventory[character_id] = {"level": int, "stars": int, "xp": int}
var inventory: Dictionary = {}

var duplicate_tiers: Array = []
var max_stars: int = 6

func _ready() -> void:
	_load_duplicate_config()
	_load_or_init_save()

func _load_duplicate_config() -> void:
	if not FileAccess.file_exists(DB_PATH):
		return
	var file := FileAccess.open(DB_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		return
	var dup_system: Dictionary = parsed.get("duplicate_system", {})
	duplicate_tiers = dup_system.get("tiers", [])
	max_stars = dup_system.get("max_stars", 6)

func _load_or_init_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
	else:
		# Nouvelle partie : ressources de départ (valeurs à ajuster en test).
		eclats_dimensionnels = 300
		or_de_guilde = 1000
		save_game()

## Ajoute un personnage obtenu (tirage ou starter) à l'inventaire.
## Si déjà possédé, monte d'un palier d'étoile (jusqu'au max défini par duplicate_system).
func add_character(character_id: String) -> void:
	if character_id.is_empty():
		return
	if inventory.has(character_id):
		var entry: Dictionary = inventory[character_id]
		entry["stars"] = min(int(entry.get("stars", 1)) + 1, max_stars)
	else:
		inventory[character_id] = {"level": 1, "stars": 1, "xp": 0}

func get_owned_character_ids() -> Array:
	return inventory.keys()

func spend_eclats(amount: int) -> bool:
	if eclats_dimensionnels < amount:
		return false
	eclats_dimensionnels -= amount
	return true

func spend_or(amount: int) -> bool:
	if or_de_guilde < amount:
		return false
	or_de_guilde -= amount
	return true

func add_or(amount: int) -> void:
	or_de_guilde += amount

func save_game() -> void:
	var data := {
		"eclats_dimensionnels": eclats_dimensionnels,
		"or_de_guilde": or_de_guilde,
		"inventory": inventory,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		return
	eclats_dimensionnels = parsed.get("eclats_dimensionnels", 0)
	or_de_guilde = parsed.get("or_de_guilde", 0)
	inventory = parsed.get("inventory", {})
