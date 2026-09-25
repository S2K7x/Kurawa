extends RefCounted
class_name DataLoader

## Lecture des fichiers de données Data/*.json (source de vérité du contenu et de l'équilibrage).
## Expose aussi les couleurs d'éléments/raretés utilisées par toute l'UI (Phase 2).

const CHARACTERS_DB_PATH := "res://Data/characters_db.json"
const ECONOMY_PATH := "res://Data/economy.json"
const ENEMIES_PATH := "res://Data/enemies.json"
const STORY_PATH := "res://Data/story.json"
const DUNGEONS_PATH := "res://Data/dungeons.json"
const TUTORIAL_PATH := "res://Data/tutorial.json"
const META_PATH := "res://Data/meta.json"

const FALLBACK_COLOR := Color(1, 1, 1)

## Illustrations : un fichier par identifiant (kur_001.png, mob_ombre.webp…), rangé dans le
## dossier de sa famille. Un identifiant sans fichier retombe sur son placeholder.
const ART_DIR := "res://Assets/Characters"
const ENEMY_ART_DIR := "res://Assets/Enemies"
const ART_EXTENSIONS: Array[String] = ["png", "webp", "jpg"]

# Le catalogue est relu par plusieurs systèmes et écrans : on le garde en cache.
static var _characters_db: Dictionary = {}
static var _enemies_db: Dictionary = {}
static var _economy: Dictionary = {}
# Illustrations déjà résolues (identifiant -> Texture2D ou null si le fichier n'existe pas).
# Sans ce cache, chaque carte payait un ResourceLoader.exists() par extension candidate —
# mesuré à ~17 ms par appel, soit un demi-seconde pour peupler la galerie.
static var _art_cache: Dictionary = {}
# Catalogue indexé par identifiant, pour éviter un balayage à chaque consultation.
static var _character_index: Dictionary = {}
static var _enemy_index: Dictionary = {}

## Renvoie le contenu JSON (objet racine) du fichier, ou un Dictionary vide en cas d'erreur.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: fichier introuvable : %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("DataLoader: JSON invalide ou racine non-objet : %s" % path)
		return {}
	return parsed

static func characters_db() -> Dictionary:
	if _characters_db.is_empty():
		_characters_db = load_json(CHARACTERS_DB_PATH)
	return _characters_db

## Valeurs d'équilibrage. Mise en cache : elles sont relues par chaque combattant créé.
static func economy() -> Dictionary:
	if _economy.is_empty():
		_economy = load_json(ECONOMY_PATH)
	return _economy

static func enemies_db() -> Dictionary:
	if _enemies_db.is_empty():
		_enemies_db = load_json(ENEMIES_PATH)
	return _enemies_db

## Fiche d'un adversaire par identifiant, qu'il soit mob générique ou boss nommé.
static func enemy(enemy_id: String) -> Dictionary:
	var entry := enemy_or_empty(enemy_id)
	if entry.is_empty():
		push_error("DataLoader: adversaire inconnu : %s" % enemy_id)
	return entry

## Même recherche, mais muette : l'appelant sait qu'un identifiant peut n'être pas un
## adversaire (l'arène interroge les deux catalogues pour trouver une illustration).
static func enemy_or_empty(enemy_id: String) -> Dictionary:
	if _enemy_index.is_empty():
		for group: String in ["mobs", "bosses"]:
			for entry: Dictionary in enemies_db().get(group, []):
				_enemy_index[entry.get("id", "")] = entry
	return _enemy_index.get(enemy_id, {})

## Éléments jouables, dans l'ordre du cycle de forces (les clés de service commencent par "_").
static func element_names() -> Array[String]:
	var names: Array[String] = []
	for key: String in characters_db().get("elements", {}):
		if not key.begins_with("_"):
			names.append(key)
	return names

## Élément battu par `element` ("" si inconnu) -- cycle Feu > Vent > Foudre > Eau > Feu.
static func element_beats(element: String) -> String:
	return str(characters_db().get("elements", {}).get(element, {}).get("beats", ""))

## Fiche d'un guerrier du catalogue ({} si l'identifiant est inconnu — un mob, par exemple).
static func character(character_id: String) -> Dictionary:
	if _character_index.is_empty():
		for entry: Dictionary in characters_db().get("characters", []):
			_character_index[entry.get("id", "")] = entry
	return _character_index.get(character_id, {})

## Illustration d'un guerrier, par convention `Assets/Characters/<id>.<ext>`, ou le chemin
## déclaré dans son champ `art` si le fichier vit ailleurs. Retourne null tant qu'aucune
## illustration n'existe : l'appelant retombe alors sur son placeholder (Phase 4 en cours).
static func character_art(character: Dictionary) -> Texture2D:
	return _art(character, ART_DIR)

## Illustration d'un adversaire (mob de donjon ou boss nommé), même convention dans
## `Assets/Enemies/`. Null tant que le fichier n'existe pas : l'arène garde son placeholder.
static func enemy_art(enemy_entry: Dictionary) -> Texture2D:
	return _art(enemy_entry, ENEMY_ART_DIR)

## Résolution commune, avec cache des absences : sans lui, chaque vignette repayait un
## ResourceLoader.exists() par extension candidate (~17 ms mesurés, voir CLAUDE.md > Profiler).
static func _art(entry: Dictionary, directory: String) -> Texture2D:
	var entry_id := str(entry.get("id", ""))
	var declared := str(entry.get("art", ""))
	# La clé inclut le dossier : un guerrier et un adversaire peuvent porter le même
	# identifiant sans se voler leur illustration.
	var key := declared if declared != "" else "%s/%s" % [directory, entry_id]
	if declared == "" and entry_id == "":
		return null
	if _art_cache.has(key):
		return _art_cache[key]

	var found: Texture2D = null
	if declared != "" and ResourceLoader.exists(declared):
		found = load(declared)
	elif entry_id != "":
		for extension: String in ART_EXTENSIONS:
			var path := "%s/%s.%s" % [directory, entry_id, extension]
			if ResourceLoader.exists(path):
				found = load(path)
				break
	_art_cache[key] = found
	return found

## Vide les caches. Réservé aux tests et aux outils : en jeu, les données ne changent pas
## en cours de session.
static func clear_cache() -> void:
	_characters_db = {}
	_enemies_db = {}
	_economy = {}
	_art_cache = {}
	_character_index = {}
	_enemy_index = {}

static func element_color(element: String) -> Color:
	return _color(characters_db().get("elements", {}).get(element, {}).get("color"))

static func rarity_color(rarity: String) -> Color:
	return _color(characters_db().get("rarities", {}).get(rarity, {}).get("color"))

static func _color(value: Variant) -> Color:
	if value == null:
		return FALLBACK_COLOR
	return Color.html(str(value))
