extends Node
class_name GachaSystem

## Gère les tirages (simple / x10) depuis la Brèche, avec pity system.
## Charge les taux et le catalogue depuis Data/characters_db.json.
## Voir GDD.md > Économie pour les règles de conception.

const DB_PATH := "res://Data/characters_db.json"

var characters: Array = []
var rarities: Dictionary = {}
var multi_pull_config: Dictionary = {}

# Pity counters -- nombre de tirages depuis le dernier SR / SSR obtenu
var pulls_since_sr: int = 0
var pulls_since_ssr: int = 0

# Seuils de pity (valeurs de départ suggérées dans le GDD, à ajuster en test)
const PITY_SR_THRESHOLD := 10
const PITY_SSR_THRESHOLD := 50

func _ready() -> void:
	_load_database()

func _load_database() -> void:
	if not FileAccess.file_exists(DB_PATH):
		push_error("GachaSystem: characters_db.json introuvable à %s" % DB_PATH)
		return

	var file := FileAccess.open(DB_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("GachaSystem: JSON invalide dans characters_db.json")
		return

	characters = parsed.get("characters", [])
	rarities = parsed.get("rarities", {})
	multi_pull_config = parsed.get("multi_pull", {
		"size": 10, "discount_pct": 10, "guaranteed_min_rarity": "SR"
	})

	print("GachaSystem: %d personnages chargés." % characters.size())

## Tire une rareté selon les taux définis dans characters_db.json,
## en appliquant le pity system (SSR prioritaire sur SR).
func _roll_rarity() -> String:
	pulls_since_sr += 1
	pulls_since_ssr += 1

	if pulls_since_ssr >= PITY_SSR_THRESHOLD:
		return "SSR"
	if pulls_since_sr >= PITY_SR_THRESHOLD:
		return "SR"

	var roll := randf()
	var cumulative := 0.0
	# Cumul du plus rare au plus commun pour rester cohérent avec les taux annoncés.
	for rarity_id in ["SSR", "SR", "R"]:
		if not rarities.has(rarity_id):
			continue
		cumulative += float(rarities[rarity_id].get("drop_rate", 0.0))
		if roll <= cumulative:
			return rarity_id

	return "R" # fallback de sécurité, ne devrait pas arriver si les taux totalisent 1.0

func _reset_pity_for(rarity: String) -> void:
	if rarity == "SR":
		pulls_since_sr = 0
	elif rarity == "SSR":
		pulls_since_sr = 0
		pulls_since_ssr = 0

## Renvoie un personnage aléatoire de la rareté donnée (exclut les personnages "starter").
func _pick_character(rarity: String) -> Dictionary:
	var pool: Array = characters.filter(func(c): return c.get("rarity") == rarity and not c.get("starter", false))
	if pool.is_empty():
		push_warning("GachaSystem: aucun personnage disponible pour la rareté %s" % rarity)
		return {}
	return pool[randi() % pool.size()]

## Un tirage simple. Retourne {"character": Dictionary, "rarity": String}.
func single_pull() -> Dictionary:
	var rarity := _roll_rarity()
	_reset_pity_for(rarity)
	var character := _pick_character(rarity)
	return {"character": character, "rarity": rarity}

## Tirage x10 avec la garantie définie dans characters_db.json (multi_pull.guaranteed_min_rarity).
func multi_pull() -> Array:
	var size: int = multi_pull_config.get("size", 10)
	var guaranteed_min: String = multi_pull_config.get("guaranteed_min_rarity", "SR")
	var results: Array = []

	for i in range(size):
		results.append(single_pull())

	var rarity_rank := {"R": 0, "SR": 1, "SSR": 2}
	var has_guaranteed := false
	for r in results:
		if rarity_rank.get(r["rarity"], 0) >= rarity_rank.get(guaranteed_min, 1):
			has_guaranteed = true
			break

	if not has_guaranteed and not results.is_empty():
		# Remplace le dernier tirage du lot par une garantie du rang minimum.
		var character := _pick_character(guaranteed_min)
		results[results.size() - 1] = {"character": character, "rarity": guaranteed_min}
		_reset_pity_for(guaranteed_min)

	return results
