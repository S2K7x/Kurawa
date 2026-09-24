extends RefCounted
class_name ContentLibrary

## Accès au contenu PvE : chapitres du mode histoire, donjons rejouables, et calcul des
## récompenses d'un combat. Lecture seule — l'avancement du joueur vit dans PlayerManager.
## Données : Data/story.json · Data/dungeons.json · barème : Data/economy.json > rewards.

static func chapters() -> Array:
	return DataLoader.load_json(DataLoader.STORY_PATH).get("chapters", [])

static func chapter(chapter_id: String) -> Dictionary:
	for entry: Dictionary in chapters():
		if entry.get("id", "") == chapter_id:
			return entry
	return {}

static func dungeons() -> Array:
	return DataLoader.load_json(DataLoader.DUNGEONS_PATH).get("dungeons", [])

static func dungeon(dungeon_id: String) -> Dictionary:
	for entry: Dictionary in dungeons():
		if entry.get("id", "") == dungeon_id:
			return entry
	return {}

## Ennemis d'un palier de donjon, au format des combats de chapitre ({"id", "level"}).
static func dungeon_encounter(dungeon_id: String, tier_index: int) -> Array:
	var tiers: Array = dungeon(dungeon_id).get("tiers", [])
	if tier_index < 0 or tier_index >= tiers.size():
		return []
	var tier: Dictionary = tiers[tier_index]
	var encounter: Array = []
	for enemy_id: String in tier.get("enemies", []):
		encounter.append({"id": enemy_id, "level": int(tier.get("level", 1))})
	return encounter

## Récompenses d'une victoire : le barème de base monte avec le niveau des adversaires,
## puis se multiplie par le type de contenu (un donjon d'Or paye mieux en Or, etc.).
static func battle_rewards(enemies: Array, or_multiplier: float = 1.0, xp_multiplier: float = 1.0) -> Dictionary:
	var config: Dictionary = DataLoader.load_json(DataLoader.ECONOMY_PATH).get("rewards", {})
	var base_or := float(config.get("base_or", 120))
	var base_xp := float(config.get("base_xp", 80))
	var per_level := float(config.get("per_enemy_level_pct", 12)) / 100.0

	var total_level := 0
	for entry: Dictionary in enemies:
		total_level += int(entry.get("level", 1))
	var average_level: float = float(total_level) / maxi(enemies.size(), 1)
	var scale := 1.0 + (average_level - 1.0) * per_level
	return {
		"or": roundi(base_or * scale * or_multiplier),
		"xp": roundi(base_xp * scale * xp_multiplier),
	}
