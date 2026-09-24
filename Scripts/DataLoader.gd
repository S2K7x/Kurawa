extends RefCounted
class_name DataLoader

## Lecture des fichiers de données Data/*.json (source de vérité du contenu et de l'équilibrage).
## Expose aussi les couleurs d'éléments/raretés utilisées par toute l'UI (Phase 2).

const CHARACTERS_DB_PATH := "res://Data/characters_db.json"
const ECONOMY_PATH := "res://Data/economy.json"
const ENEMIES_PATH := "res://Data/enemies.json"
const STORY_PATH := "res://Data/story.json"
const DUNGEONS_PATH := "res://Data/dungeons.json"

const FALLBACK_COLOR := Color(1, 1, 1)

# Le catalogue est relu par plusieurs systèmes et écrans : on le garde en cache.
static var _characters_db: Dictionary = {}
static var _enemies_db: Dictionary = {}

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

static func enemies_db() -> Dictionary:
	if _enemies_db.is_empty():
		_enemies_db = load_json(ENEMIES_PATH)
	return _enemies_db

## Fiche d'un adversaire par identifiant, qu'il soit mob générique ou boss nommé.
static func enemy(enemy_id: String) -> Dictionary:
	var db := enemies_db()
	for group: String in ["mobs", "bosses"]:
		for entry: Dictionary in db.get(group, []):
			if entry.get("id", "") == enemy_id:
				return entry
	push_error("DataLoader: adversaire inconnu : %s" % enemy_id)
	return {}

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

static func element_color(element: String) -> Color:
	return _color(characters_db().get("elements", {}).get(element, {}).get("color"))

static func rarity_color(rarity: String) -> Color:
	return _color(characters_db().get("rarities", {}).get(rarity, {}).get("color"))

static func _color(value: Variant) -> Color:
	if value == null:
		return FALLBACK_COLOR
	return Color.html(str(value))
