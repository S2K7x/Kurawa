extends Node
class_name PlayerManager

## Ressources du joueur, inventaire de guerriers et sauvegarde locale.
## Sauvegarde locale uniquement (pas de compte/cloud) -- voir GDD.md > Ambition et portée du projet.
## Possède les systèmes dont l'état est sauvegardé (pity du gacha, jauge d'énergie).

signal state_changed

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://kurawa_save.json"

var save_path: String = DEFAULT_SAVE_PATH

var eclats_dimensionnels: int = 0
var or_de_guilde: int = 0

# inventory[character_id] = {"level": int, "stars": int, "xp": int}
var inventory: Dictionary = {}

var gacha := GachaSystem.new()
var stamina := StaminaSystem.new()
var progression := ProgressionSystem.new()

# character_id -> fiche du catalogue
var _catalog: Dictionary = {}

func _init() -> void:
	for character: Dictionary in DataLoader.characters_db().get("characters", []):
		_catalog[character["id"]] = character

func _ready() -> void:
	load_or_new_game()

func get_character_data(character_id: String) -> Dictionary:
	return _catalog.get(character_id, {})

func get_owned_character_ids() -> Array:
	return inventory.keys()

## Stats effectives (niveau + étoiles) d'un personnage possédé.
func get_character_stats(character_id: String) -> Dictionary:
	if not inventory.has(character_id):
		return {}
	return progression.compute_stats(get_character_data(character_id).get("stats", {}), inventory[character_id])

## Compétence effective (puissance et cooldown ajustés par les étoiles) d'un personnage possédé.
func get_character_skill(character_id: String) -> Dictionary:
	if not inventory.has(character_id):
		return {}
	return progression.compute_skill(get_character_data(character_id).get("skill", {}), inventory[character_id].get("stars", 1))

# --- Nouvelle partie / sauvegarde ------------------------------------------------------------

func load_or_new_game() -> void:
	if not FileAccess.file_exists(save_path) or not load_game():
		new_game()

func new_game() -> void:
	var start: Dictionary = DataLoader.load_json(DataLoader.ECONOMY_PATH).get("starting_resources", {})
	eclats_dimensionnels = int(start.get("eclats_dimensionnels", 0))
	or_de_guilde = int(start.get("or_de_guilde", 0))
	inventory = {}
	gacha.from_dict({})
	stamina.reset_full()
	# Personnage de départ garanti, lié à l'histoire (voir GDD.md > Personnage de départ).
	for character_id: String in _catalog:
		if _catalog[character_id].get("starter", false):
			inventory[character_id] = progression.new_entry()
	save_game()
	state_changed.emit()

## Efface la sauvegarde et repart d'une nouvelle partie.
func reset_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	new_game()

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"eclats_dimensionnels": eclats_dimensionnels,
		"or_de_guilde": or_de_guilde,
		"inventory": inventory,
		"gacha": gacha.to_dict(),
		"stamina": stamina.to_dict(),
	}
	# Écriture atomique : fichier temporaire puis renommage, pour ne jamais laisser
	# une sauvegarde à moitié écrite si le jeu est coupé pendant l'écriture.
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("PlayerManager: impossible d'écrire %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_error("PlayerManager: renommage de la sauvegarde impossible (%s)" % error_string(err))
		return false
	return true

## Charge la sauvegarde. Retourne false si elle est illisible (elle est alors mise de côté
## en .corrupt pour ne pas être écrasée sans trace).
func load_game() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_error("PlayerManager: sauvegarde illisible, copie dans %s.corrupt" % save_path)
		DirAccess.copy_absolute(save_path, save_path + ".corrupt")
		return false
	var data: Dictionary = parsed
	eclats_dimensionnels = int(data.get("eclats_dimensionnels", 0))
	or_de_guilde = int(data.get("or_de_guilde", 0))
	inventory = {}
	# JSON ne distingue pas int/float : on renormalise les entrées d'inventaire.
	var saved_inventory: Dictionary = data.get("inventory", {})
	for character_id: String in saved_inventory:
		if not _catalog.has(character_id):
			push_warning("PlayerManager: personnage inconnu ignoré à la sauvegarde : %s" % character_id)
			continue
		var entry: Dictionary = saved_inventory[character_id]
		inventory[character_id] = {
			"level": int(entry.get("level", 1)),
			"stars": int(entry.get("stars", 1)),
			"xp": int(entry.get("xp", 0)),
		}
	gacha.from_dict(data.get("gacha", {}))
	stamina.from_dict(data.get("stamina", {}))
	state_changed.emit()
	return true

# --- Ressources ------------------------------------------------------------------------------

func spend_eclats(amount: int) -> bool:
	if eclats_dimensionnels < amount:
		return false
	eclats_dimensionnels -= amount
	return true

func add_eclats(amount: int) -> void:
	eclats_dimensionnels += amount

func spend_or(amount: int) -> bool:
	if or_de_guilde < amount:
		return false
	or_de_guilde -= amount
	return true

func add_or(amount: int) -> void:
	or_de_guilde += amount

# --- Invocation & inventaire -----------------------------------------------------------------

func can_afford_summon(multi: bool) -> bool:
	return eclats_dimensionnels >= gacha.get_cost(multi)

## Paie et effectue une invocation, ajoute les guerriers à l'inventaire puis sauvegarde.
## Retourne les résultats enrichis (voir add_character), ou [] si les Éclats manquent.
func summon(multi: bool) -> Array:
	if not spend_eclats(gacha.get_cost(multi)):
		return []
	var pulls: Array = gacha.multi_pull() if multi else [gacha.single_pull()]
	var results: Array = []
	for pull: Dictionary in pulls:
		var result := add_character(pull["character"].get("id", ""))
		result["character"] = pull["character"]
		result["rarity"] = pull["rarity"]
		results.append(result)
	save_game()
	state_changed.emit()
	return results

## Ajoute un personnage obtenu à l'inventaire. Un doublon fait monter d'une étoile
## (ou est converti en Or au palier max). Ne sauvegarde pas : l'appelant s'en charge.
## Retourne {"is_new": bool, "stars": int, "or_bonus": int}.
func add_character(character_id: String) -> Dictionary:
	if not _catalog.has(character_id):
		push_error("PlayerManager: personnage inconnu : '%s'" % character_id)
		return {"is_new": false, "stars": 0, "or_bonus": 0}
	if not inventory.has(character_id):
		inventory[character_id] = progression.new_entry()
		return {"is_new": true, "stars": 1, "or_bonus": 0}
	var entry: Dictionary = inventory[character_id]
	var or_bonus := progression.apply_duplicate(entry)
	add_or(or_bonus)
	return {"is_new": false, "stars": entry["stars"], "or_bonus": or_bonus}

## Donne de l'XP à un personnage possédé. Retourne le nombre de niveaux gagnés.
func add_character_xp(character_id: String, amount: int) -> int:
	if not inventory.has(character_id):
		return 0
	return progression.add_xp(inventory[character_id], amount)

# --- Énergie ---------------------------------------------------------------------------------

## Consomme l'énergie d'un combat. Retourne false si la jauge est insuffisante.
func start_combat() -> bool:
	if not stamina.spend_for_combat():
		return false
	save_game()
	state_changed.emit()
	return true
