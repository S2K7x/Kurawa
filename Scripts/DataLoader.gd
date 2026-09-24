extends RefCounted
class_name DataLoader

## Lecture des fichiers de données Data/*.json (source de vérité du contenu et de l'équilibrage).

const CHARACTERS_DB_PATH := "res://Data/characters_db.json"
const ECONOMY_PATH := "res://Data/economy.json"

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
