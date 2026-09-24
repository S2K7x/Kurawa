extends SceneTree

## Rapport d'équilibrage : taux de victoire de chaque combat du mode histoire et de chaque
## donjon, pour une équipe type à différents niveaux. Sert à calibrer la courbe de difficulté
## (GDD.md > Courbe de difficulté : chaque chapitre doit exiger du farm, pas être infranchissable).
##
##   godot --headless --path . -s res://Tests/balance_report.gd
##
## Lecture : ~0% = mur infranchissable · 40-70% = combat tendu · 100% = trop facile.

const RUNS := 200
const TEAM_LEVELS := [1, 10, 20, 25, 30, 35, 40]
## Deux équipes de référence : celle d'un joueur modeste (le starter + deux R, 1★) et celle
## d'un joueur investi (trois SSR à 3★). Un contenu doit rester franchissable par la première
## avec du farm, sans être trivial pour la seconde.
const PROFILES := [
	{"label": "modeste", "ids": ["kur_013", "kur_001", "kur_002"], "stars": 1},
	{"label": "investie", "ids": ["kur_009", "kur_011", "kur_012"], "stars": 3},
]

func _initialize() -> void:
	var progression := ProgressionSystem.new()
	print("Taux de victoire sur %d combats simulés par palier." % RUNS)
	for profile: Dictionary in PROFILES:
		print("  équipe %-9s : %s (%d★)" % [profile["label"], ", ".join(profile["ids"]), int(profile["stars"])])
	print("")

	print("MODE HISTOIRE")
	for chapter: Dictionary in DataLoader.load_json(DataLoader.STORY_PATH).get("chapters", []):
		print("  %s — %s" % [chapter["id"], chapter["title"]])
		for battle: Dictionary in chapter["battles"]:
			_report(battle["name"], battle["enemies"], progression, battle.get("boss", false))

	print("\nDONJONS")
	for dungeon: Dictionary in DataLoader.load_json(DataLoader.DUNGEONS_PATH).get("dungeons", []):
		print("  %s — %s" % [dungeon["id"], dungeon["name"]])
		for tier: Dictionary in dungeon["tiers"]:
			var enemies: Array = []
			for enemy_id: String in tier["enemies"]:
				enemies.append({"id": enemy_id, "level": tier["level"]})
			_report("niveau %d" % int(tier["level"]), enemies, progression, false)
	quit(0)

func _report(label: String, enemies: Array, progression: ProgressionSystem, is_boss: bool) -> void:
	print("    %s%s" % [label, "   [BOSS]" if is_boss else ""])
	for profile: Dictionary in PROFILES:
		var rates: PackedStringArray = []
		for level: int in TEAM_LEVELS:
			rates.append("Niv%d %3d%%" % [level, _win_rate(level, enemies, progression, profile)])
		print("      %-9s %s" % [profile["label"], " · ".join(rates)])

func _win_rate(team_level: int, enemies: Array, progression: ProgressionSystem, profile: Dictionary) -> int:
	var wins := 0
	for run in range(RUNS):
		var combat := CombatManager.new()
		combat.rng.seed = run # reproductible d'une exécution à l'autre
		var team: Array[Combatant] = []
		var stars: int = int(profile["stars"])
		for character_id: String in profile["ids"]:
			var data: Dictionary = DataLoader.characters_db()["characters"].filter(
				func(c: Dictionary) -> bool: return c["id"] == character_id)[0]
			var entry := {"level": team_level, "stars": stars, "xp": 0}
			team.append(CombatManager.from_character(data,
				progression.compute_stats(data["stats"], entry),
				progression.compute_skill(data["skill"], stars)))
		var foes: Array[Combatant] = []
		for entry: Dictionary in enemies:
			foes.append(CombatManager.from_enemy(entry["id"], int(entry["level"])))
		combat.start(team, foes)
		if combat.auto_resolve() == CombatManager.Result.VICTORY:
			wins += 1
	return roundi(100.0 * wins / RUNS)
