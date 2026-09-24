extends RefCounted
class_name ProgressionSystem

## Progression d'un personnage possédé : niveaux (XP) et paliers de doublons (étoiles).
## Pas d'équipement en v1 : la puissance vient uniquement du niveau et des étoiles.
## Paliers : Data/characters_db.json > duplicate_system · courbe d'XP : Data/economy.json > progression.

var max_level: int = 40
var xp_base: float = 100.0
var xp_growth: float = 1.1
var stat_growth_per_level_pct: float = 5.0
var max_star_duplicate_or: int = 0
var max_stars: int = 6
var tiers: Array = []

func _init() -> void:
	var config: Dictionary = DataLoader.load_json(DataLoader.ECONOMY_PATH).get("progression", {})
	max_level = int(config.get("max_level", max_level))
	xp_base = float(config.get("xp_base", xp_base))
	xp_growth = float(config.get("xp_growth", xp_growth))
	stat_growth_per_level_pct = float(config.get("stat_growth_per_level_pct", stat_growth_per_level_pct))
	max_star_duplicate_or = int(config.get("max_star_duplicate_or", 0))

	var duplicates: Dictionary = DataLoader.load_json(DataLoader.CHARACTERS_DB_PATH).get("duplicate_system", {})
	max_stars = int(duplicates.get("max_stars", max_stars))
	tiers = duplicates.get("tiers", [])

## Entrée d'inventaire d'un personnage fraîchement obtenu.
func new_entry() -> Dictionary:
	return {"level": 1, "stars": 1, "xp": 0}

## XP nécessaire pour passer du niveau `level` au suivant (0 au niveau max).
func xp_to_next_level(level: int) -> int:
	if level >= max_level:
		return 0
	return roundi(xp_base * pow(xp_growth, level - 1))

## Ajoute de l'XP à une entrée d'inventaire (modifiée en place). Retourne le nombre de niveaux gagnés.
func add_xp(entry: Dictionary, amount: int) -> int:
	var level: int = entry.get("level", 1)
	var xp: int = entry.get("xp", 0) + maxi(amount, 0)
	var start_level := level
	while level < max_level and xp >= xp_to_next_level(level):
		xp -= xp_to_next_level(level)
		level += 1
	entry["level"] = level
	entry["xp"] = 0 if level >= max_level else xp
	return level - start_level

## Applique un doublon (modifie l'entrée en place) : +1 étoile, ou conversion en Or si déjà au max.
## Retourne l'Or de compensation à créditer (0 si une étoile a été gagnée).
func apply_duplicate(entry: Dictionary) -> int:
	var stars: int = entry.get("stars", 1)
	if stars >= max_stars:
		return max_star_duplicate_or
	entry["stars"] = stars + 1
	return 0

func _get_tier(stars: int) -> Dictionary:
	for tier: Dictionary in tiers:
		if int(tier.get("star", 0)) == stars:
			return tier
	return {}

func get_star_bonus_pct(stars: int) -> float:
	return float(_get_tier(stars).get("stat_bonus_pct", 0.0))

## Déblocages de compétence obtenus jusqu'au palier `stars` inclus.
func get_unlocks(stars: int) -> Array[String]:
	var unlocks: Array[String] = []
	for tier: Dictionary in tiers:
		if int(tier.get("star", 0)) <= stars and tier.get("unlock") != null:
			unlocks.append(str(tier["unlock"]))
	return unlocks

## Stats effectives = base × bonus de niveau × bonus d'étoiles.
func compute_stats(base_stats: Dictionary, entry: Dictionary) -> Dictionary:
	var level: int = entry.get("level", 1)
	var level_mult := 1.0 + (level - 1) * stat_growth_per_level_pct / 100.0
	var star_mult := 1.0 + get_star_bonus_pct(entry.get("stars", 1)) / 100.0
	var result := {}
	for stat: String in base_stats:
		result[stat] = roundi(float(base_stats[stat]) * level_mult * star_mult)
	return result
