extends SceneTree

## Rapport d'équilibrage : taux de victoire de chaque combat du mode histoire et de chaque
## donjon, pour une équipe type à différents niveaux. Sert à calibrer la courbe de difficulté
## (GDD.md > Courbe de difficulté : chaque chapitre doit exiger du farm, pas être infranchissable).
##
##   godot --headless --path . -s res://Tests/balance_report.gd
##
## Lecture : ~0% = mur infranchissable · 40-70% = combat tendu · 100% = trop facile.

const RUNS := 200
const TEAM_LEVELS := [1, 5, 10, 15, 20, 25, 30]
## Équipe type : le starter offert + deux guerriers R, ce qu'un joueur a réellement tôt.
const TEAM_IDS := ["kur_013", "kur_001", "kur_002"]
const TEAM_STARS := 1

func _initialize() -> void:
	var progression := ProgressionSystem.new()
	print("Taux de victoire sur %d combats simulés, équipe %s (1★)\n" % [RUNS, ", ".join(TEAM_IDS)])

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
	var rates: PackedStringArray = []
	for level: int in TEAM_LEVELS:
		rates.append("Niv%d %3d%%" % [level, _win_rate(level, enemies, progression)])
	print("    %-42s %s%s" % [label, " · ".join(rates), "   [BOSS]" if is_boss else ""])

func _win_rate(team_level: int, enemies: Array, progression: ProgressionSystem) -> int:
	var wins := 0
	for run in range(RUNS):
		var combat := CombatManager.new()
		combat.rng.seed = run # reproductible d'une exécution à l'autre
		var team: Array[Combatant] = []
		for character_id: String in TEAM_IDS:
			var data: Dictionary = DataLoader.characters_db()["characters"].filter(
				func(c: Dictionary) -> bool: return c["id"] == character_id)[0]
			var entry := {"level": team_level, "stars": TEAM_STARS, "xp": 0}
			team.append(CombatManager.from_character(data,
				progression.compute_stats(data["stats"], entry),
				progression.compute_skill(data["skill"], TEAM_STARS)))
		var foes: Array[Combatant] = []
		for entry: Dictionary in enemies:
			foes.append(CombatManager.from_enemy(entry["id"], int(entry["level"])))
		combat.start(team, foes)
		if combat.auto_resolve() == CombatManager.Result.VICTORY:
			wins += 1
	return roundi(100.0 * wins / RUNS)
