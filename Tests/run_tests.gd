extends SceneTree

## Tests de validation de la Phase 1 (taux de tirage, pity, sauvegarde, énergie, progression).
## Lancement : godot --headless --path . -s res://Tests/run_tests.gd
## Code de sortie 0 si tout passe, 1 sinon.

const TEST_SAVE_PATH := "user://test_kurawa_save.json"

var _failures: int = 0
var _checks: int = 0
var fake_time: float = 1_000_000.0

# Les tests d'UI ont besoin que l'arbre tourne : on les lance après les tests de logique,
# puis on vérifie l'état des écrans une fois quelques frames passées.
var _ui_frames: int = 0
var _main: Node
var _ui_completed: bool = false

func _initialize() -> void:
	test_costs()
	test_raw_rates()
	test_pity()
	test_multi_pull_guarantee()
	test_progression()
	test_duplicates()
	test_stamina()
	test_save_roundtrip()
	test_corrupt_save()
	test_data_integrity()
	test_skill_data()
	test_combat()
	start_ui_tests()

func _process(_delta: float) -> bool:
	_ui_frames += 1
	if _ui_frames < 3:
		return false
	finish_ui_tests()
	check(_ui_completed, "les tests d'UI sont allés au bout (aucune erreur runtime)")
	print("\n%d vérifications, %d échec(s)." % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
	return true

func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)

func _new_gacha(seed_value: int) -> GachaSystem:
	var gacha := GachaSystem.new()
	gacha.rng.seed = seed_value
	return gacha

func test_costs() -> void:
	print("Coûts d'invocation")
	var gacha := GachaSystem.new()
	check(gacha.get_cost(false) == 30, "tirage simple = 30 Éclats")
	check(gacha.get_cost(true) == 270, "tirage x10 = 270 Éclats (remise 10%)")

## Sans pity, les taux observés doivent coller aux taux annoncés (tolérance ~5 écarts-types).
func test_raw_rates() -> void:
	const N := 1_000_000
	print("Taux bruts sur %d tirages (pity désactivé)" % N)
	var gacha := _new_gacha(42)
	gacha.pity_enabled = false
	var counts := {"R": 0, "SR": 0, "SSR": 0}
	var starter_pulled := false
	for i in range(N):
		var pull := gacha.single_pull()
		counts[pull["rarity"]] += 1
		if pull["character"].get("starter", false):
			starter_pulled = true
	for rarity: String in counts:
		var expected := gacha.get_drop_rate(rarity)
		var observed := float(counts[rarity]) / N
		var tolerance := 5.0 * sqrt(expected * (1.0 - expected) / N)
		check(absf(observed - expected) <= tolerance,
			"%s : %.3f%% observé vs %.1f%% annoncé" % [rarity, observed * 100, expected * 100])
	check(not starter_pulled, "le personnage starter n'est jamais invocable")

## Avec pity : jamais plus de 10 tirages sans SR+, ni plus de 50 sans SSR.
func test_pity() -> void:
	const N := 200_000
	print("Pity sur %d tirages" % N)
	var gacha := _new_gacha(7)
	var since_sr := 0
	var since_ssr := 0
	var max_since_sr := 0
	var max_since_ssr := 0
	var counts := {"R": 0, "SR": 0, "SSR": 0}
	for i in range(N):
		var rarity: String = gacha.single_pull()["rarity"]
		counts[rarity] += 1
		since_sr += 1
		since_ssr += 1
		max_since_sr = maxi(max_since_sr, since_sr)
		max_since_ssr = maxi(max_since_ssr, since_ssr)
		if rarity != "R":
			since_sr = 0
		if rarity == "SSR":
			since_ssr = 0
	check(max_since_sr <= gacha.pity_sr_threshold, "SR+ au plus tard au tirage %d (max observé : %d)" % [gacha.pity_sr_threshold, max_since_sr])
	check(max_since_ssr <= gacha.pity_ssr_threshold, "SSR au plus tard au tirage %d (max observé : %d)" % [gacha.pity_ssr_threshold, max_since_ssr])
	print("       taux effectifs avec pity : R %.2f%% · SR %.2f%% · SSR %.2f%%" % [
		100.0 * counts["R"] / N, 100.0 * counts["SR"] / N, 100.0 * counts["SSR"] / N])

func test_multi_pull_guarantee() -> void:
	print("Garantie du tirage x10")
	var gacha := _new_gacha(3)
	gacha.pity_enabled = false # isole la garantie x10 du pity SR, qui la couvrirait déjà
	var all_guaranteed := true
	var all_sized := true
	for i in range(20_000):
		var results := gacha.multi_pull()
		all_sized = all_sized and results.size() == 10
		all_guaranteed = all_guaranteed and results.any(func(r): return r["rarity"] != "R")
	check(all_sized, "chaque x10 contient 10 guerriers")
	check(all_guaranteed, "chaque x10 contient au moins un SR+")

func test_progression() -> void:
	print("Niveaux")
	var prog := ProgressionSystem.new()
	var entry := prog.new_entry()
	check(prog.xp_to_next_level(1) == 100, "niveau 1 -> 2 : 100 XP")
	check(prog.add_xp(entry, 99) == 0 and entry["level"] == 1, "99 XP : reste niveau 1")
	check(prog.add_xp(entry, 1) == 1 and entry["level"] == 2 and entry["xp"] == 0, "100 XP : niveau 2")
	prog.add_xp(entry, 10_000_000)
	check(entry["level"] == prog.max_level and entry["xp"] == 0, "XP plafonnée au niveau max (%d)" % prog.max_level)
	var base := {"atk": 100, "pv": 1000}
	check(prog.compute_stats(base, prog.new_entry()) == base, "niveau 1 / 1 étoile : stats de base")
	var boosted := prog.compute_stats(base, {"level": 11, "stars": 3, "xp": 0})
	# 100 × (1 + 10×5%) × (1 + 16%) = 174
	check(boosted["atk"] == 174, "niveau 11 / 3 étoiles : ATK 100 -> 174 (obtenu %d)" % boosted["atk"])

func test_duplicates() -> void:
	print("Doublons")
	var player := _new_player()
	player.add_character("kur_001")
	for i in range(5):
		player.add_character("kur_001")
	check(player.inventory["kur_001"]["stars"] == 6, "5 doublons : 6 étoiles")
	var or_before := player.or_de_guilde
	var result := player.add_character("kur_001")
	check(result["stars"] == 6 and player.or_de_guilde == or_before + player.progression.max_star_duplicate_or,
		"doublon au palier max converti en %d Or" % player.progression.max_star_duplicate_or)
	check(player.progression.get_unlocks(6).size() == 2, "2 déblocages de compétence à 6 étoiles")
	player.free()

func test_stamina() -> void:
	print("Énergie")
	var stamina := StaminaSystem.new()
	stamina.clock = func() -> float: return fake_time
	stamina.reset_full()
	check(stamina.get_current() == 120, "jauge pleine au départ")
	check(stamina.spend_for_combat() and stamina.get_current() == 114, "un combat coûte 6")
	fake_time += 299
	check(stamina.get_current() == 114, "pas de point avant 5 min")
	fake_time += 1
	check(stamina.get_current() == 115, "+1 point à 5 min")
	var saved := stamina.to_dict()
	fake_time += 3000 # jeu fermé 50 min
	var reloaded := StaminaSystem.new()
	reloaded.clock = func() -> float: return fake_time
	reloaded.from_dict(saved)
	check(reloaded.get_current() == 120, "recharge hors-jeu plafonnée à 120 (obtenu %d)" % reloaded.get_current())
	fake_time -= 10_000 # horloge système reculée
	check(reloaded.get_current() == 120, "horloge reculée : aucune perte")
	var drained := StaminaSystem.new()
	drained.clock = func() -> float: return fake_time
	drained.reset_full()
	for i in range(20):
		drained.spend_for_combat()
	check(drained.get_current() == 0 and not drained.spend_for_combat(), "combat refusé sans énergie")
	fake_time += 3000
	check(drained.get_current() == 10, "+10 points après 50 min")

func _new_player() -> PlayerManager:
	var player := PlayerManager.new()
	player.save_path = TEST_SAVE_PATH
	player.reset_save()
	return player

func test_save_roundtrip() -> void:
	print("Sauvegarde")
	var player := _new_player()
	check(player.eclats_dimensionnels == 300 and player.or_de_guilde == 1000, "ressources de départ")
	check(player.inventory.has("kur_013"), "starter Talia Wren offert en nouvelle partie")
	check(player.summon(true).size() == 10 and player.eclats_dimensionnels == 30, "x10 payé 270 Éclats")
	check(player.summon(true).is_empty() and player.eclats_dimensionnels == 30, "x10 refusé sans assez d'Éclats")
	player.add_character_xp("kur_013", 250)
	player.start_combat()
	player.save_game()

	var reloaded := PlayerManager.new()
	reloaded.save_path = TEST_SAVE_PATH
	reloaded.load_or_new_game()
	check(reloaded.eclats_dimensionnels == player.eclats_dimensionnels, "Éclats restaurés")
	check(reloaded.or_de_guilde == player.or_de_guilde, "Or restauré")
	check(reloaded.inventory == player.inventory, "inventaire restauré (%d guerriers)" % reloaded.inventory.size())
	check(typeof(reloaded.inventory["kur_013"]["level"]) == TYPE_INT, "niveaux relus en entiers")
	check(reloaded.gacha.to_dict() == player.gacha.to_dict(), "compteurs de pity restaurés")
	check(reloaded.stamina.get_current() == player.stamina.get_current(), "énergie restaurée")
	check(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "aucun fichier temporaire résiduel")
	player.free()
	reloaded.free()

func test_corrupt_save() -> void:
	print("Sauvegarde corrompue")
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ pas du json")
	file.close()
	var player := PlayerManager.new()
	player.save_path = TEST_SAVE_PATH
	player.load_or_new_game()
	check(player.eclats_dimensionnels == 300, "repart sur une nouvelle partie")
	check(FileAccess.file_exists(TEST_SAVE_PATH + ".corrupt"), "fichier corrompu conservé en .corrupt")
	DirAccess.remove_absolute(TEST_SAVE_PATH)
	DirAccess.remove_absolute(TEST_SAVE_PATH + ".corrupt")
	player.free()

# --- Contenu & UI -----------------------------------------------------------------------------

## Le contenu (couleurs, éléments, cycle de forces) doit rester cohérent : l'UI s'en sert
## directement pour colorer cartes et filtres.
func test_data_integrity() -> void:
	print("Intégrité des données")
	var elements := DataLoader.element_names()
	check(elements.size() == 4, "4 éléments déclarés (%s)" % ", ".join(elements))
	var cycle_ok := true
	var visited: Array[String] = []
	var current: String = elements[0]
	for i in range(elements.size()):
		visited.append(current)
		current = DataLoader.element_beats(current)
		cycle_ok = cycle_ok and current != ""
	check(cycle_ok and current == elements[0] and visited.size() == 4,
		"cycle des forces complet et fermé (%s)" % " > ".join(visited))
	var colors_ok := true
	for element: String in elements:
		colors_ok = colors_ok and DataLoader.element_color(element) != DataLoader.FALLBACK_COLOR
	for rarity: String in ["R", "SR", "SSR"]:
		colors_ok = colors_ok and DataLoader.rarity_color(rarity) != DataLoader.FALLBACK_COLOR
	check(colors_ok, "chaque élément et chaque rareté a une couleur")

	var seen_ids := {}
	var names_ok := true
	var stats_ok := true
	for character: Dictionary in DataLoader.characters_db().get("characters", []):
		names_ok = names_ok and not seen_ids.has(character.get("id"))
		seen_ids[character.get("id")] = true
		names_ok = names_ok and elements.has(character.get("element", ""))
		for stat: String in ["atk", "def", "vit", "pv"]:
			stats_ok = stats_ok and int(character.get("stats", {}).get(stat, 0)) > 0
	check(names_ok, "%d personnages : identifiants uniques et éléments valides" % seen_ids.size())
	check(stats_ok, "chaque personnage a ses 4 stats renseignées")

## Smoke test de la Phase 2 : les scènes se chargent, s'instancient et se peuplent sans erreur.
func start_ui_tests() -> void:
	print("Interface (Phase 2)")
	for path: String in ["res://Scenes/Main.tscn", "res://Scenes/SummonScreen.tscn",
			"res://Scenes/InventoryGrid.tscn", "res://Scenes/SummonReveal.tscn",
			"res://Scenes/CharacterCard.tscn", "res://Scenes/GachaTest.tscn"]:
		check(ResourceLoader.exists(path) and load(path) != null, "scène chargée : %s" % path.get_file())
	check(load("res://Assets/UI/kurawa_theme.tres") is Theme, "thème kurawa_theme.tres valide")

	_main = load("res://Scenes/Main.tscn").instantiate()
	_main.player.save_path = TEST_SAVE_PATH
	root.add_child(_main)
	_main.player.reset_save()

func finish_ui_tests() -> void:
	var host: Node = _main.get_node("%ScreenHost")
	check(host.get_child_count() == 4, "Brèche, Guilde, Histoire et Donjons montés dans la coquille")
	var summon: Node = host.get_child(0)
	var inventory: Node = host.get_child(1)
	check(summon.visible and not inventory.visible, "la Brèche est l'écran d'accueil")

	var grid: GridContainer = inventory.get_node("%Grid")
	inventory.on_shown()
	check(grid.get_child_count() == _main.player.inventory.size(),
		"la galerie affiche les %d guerriers possédés" % _main.player.inventory.size())
	var starter_card: CharacterCard = grid.get_child(0)
	check(starter_card.character_id != "", "carte liée à un guerrier (%s)" % starter_card.character_id)
	# Tri de la galerie : chaque critère doit réellement réordonner les cartes.
	inventory._sort = "Niveau"
	inventory._refresh()
	var by_level: Array = inventory._filtered_ids()
	inventory._sort = "Étoiles"
	inventory._refresh()
	var by_stars: Array = inventory._filtered_ids()
	inventory._sort = "Rareté"
	inventory._refresh()
	var by_rarity: Array = inventory._filtered_ids()
	check(by_level.size() == by_stars.size() and by_stars.size() == by_rarity.size(),
		"les trois tris affichent le même nombre de guerriers")
	var levels_sorted := true
	for i in range(by_level.size() - 1):
		levels_sorted = levels_sorted and int(_main.player.inventory[by_level[i]]["level"]) \
			>= int(_main.player.inventory[by_level[i + 1]]["level"])
	check(levels_sorted, "le tri par niveau est décroissant")

	inventory._show_detail(starter_card.character_id)
	check(inventory._detail.visible and inventory._detail_body.text.contains("STATS"),
		"la fiche détaillée s'ouvre au clic sur une carte")

	var results: Array = _main.player.summon(true)
	check(results.size() == 10, "invocation x10 depuis l'UI")
	summon._reveal.start(results)
	check(summon._reveal.visible and summon._reveal.get_node("%CardHost").get_child_count() == 1,
		"la révélation affiche une carte à la fois")
	summon._reveal._show_summary()
	check(summon._reveal.get_node("%Summary").visible and summon._reveal.get_node("%Grid").get_child_count() == 10,
		"le récapitulatif x10 liste les 10 guerriers")
	summon._reveal._close()
	check(not summon._reveal.visible, "la révélation se referme")

	test_onboarding()
	test_combat_screens(host)
	_ui_completed = true
	_main.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

# --- Combat (Phase 3) -------------------------------------------------------------------------

## Les compétences sont désormais des données exécutables : tout ce que CombatManager sait
## lire doit être déclaré au glossaire, et réciproquement.
func test_skill_data() -> void:
	print("Compétences")
	var db := DataLoader.characters_db()
	var glossary: Dictionary = db.get("skill_glossary", {})
	var known_targets: Dictionary = glossary.get("targets", {})
	var known_effects: Dictionary = glossary.get("effects", {})
	var targets_ok := true
	var effects_ok := true
	var cooldowns_ok := true
	var units: Array = db.get("characters", []).duplicate()
	for group: String in ["mobs", "bosses"]:
		units.append_array(DataLoader.enemies_db().get(group, []))
	for unit: Dictionary in units:
		var skill: Dictionary = unit.get("skill", {})
		targets_ok = targets_ok and known_targets.has(skill.get("target", ""))
		cooldowns_ok = cooldowns_ok and int(skill.get("cooldown", 0)) >= 1
		for effect: Dictionary in skill.get("effects", []):
			effects_ok = effects_ok and known_effects.has(effect.get("type", ""))
	check(targets_ok, "les %d compétences ciblent toutes un mode déclaré au glossaire" % units.size())
	check(effects_ok, "tous les effets utilisés sont déclarés au glossaire")
	check(cooldowns_ok, "toute compétence a un cooldown d'au moins 1 tour")

	var prog := ProgressionSystem.new()
	var base: Dictionary = db["characters"][8]["skill"] # Ryoto Vahn, SSR
	var maxed := prog.compute_skill(base, 6)
	check(is_equal_approx(maxed["power"], float(base["power"]) * 1.4),
		"6 étoiles : puissance de compétence +40%%")
	check(int(maxed["cooldown"]) == int(base["cooldown"]) - 1, "6 étoiles : un tour de cooldown en moins")
	check(is_equal_approx(prog.compute_skill(base, 1)["power"], float(base["power"])),
		"1 étoile : compétence inchangée")

func _combatant(name: String, element: String, atk: int, def_value: int, vit: int, pv: int,
		is_ally: bool, skill: Dictionary = {}) -> Combatant:
	var unit := Combatant.new()
	unit.name = name
	unit.element = element
	unit.is_ally = is_ally
	unit.base_atk = atk
	unit.base_def = def_value
	unit.base_vit = vit
	unit.max_hp = pv
	unit.hp = pv
	unit.skill = skill
	return unit

func test_combat() -> void:
	print("Combat")
	var combat := CombatManager.new()
	check(is_equal_approx(combat.element_multiplier("Feu", "Vent"), 1.5), "Feu bat Vent : ×1.5")
	check(is_equal_approx(combat.element_multiplier("Vent", "Feu"), 0.75), "Vent contre Feu : ×0.75")
	check(is_equal_approx(combat.element_multiplier("Feu", "Feu"), 1.0), "même élément : ×1.0")

	# L'ordre de passage suit la Vitesse, pas l'ordre de l'équipe.
	var order := CombatManager.new()
	order.rng.seed = 1
	var slow := _combatant("Lent", "Feu", 50, 50, 40, 500, true)
	var fast := _combatant("Rapide", "Feu", 50, 50, 200, 500, false)
	order.start([slow] as Array[Combatant], [fast] as Array[Combatant])
	check(order.begin_turn() == fast, "le plus rapide agit en premier")

	# Un combat déséquilibré doit se conclure, et du bon côté.
	var rout := CombatManager.new()
	rout.rng.seed = 5
	var champion := _combatant("Champion", "Feu", 300, 200, 150, 5000, true)
	var minion := _combatant("Sbire", "Vent", 40, 20, 60, 300, false)
	rout.start([champion] as Array[Combatant], [minion] as Array[Combatant])
	check(rout.auto_resolve() == CombatManager.Result.VICTORY, "l'équipe largement supérieure gagne")
	check(rout.turn_count < rout._max_turns, "le combat se termine avant la limite de tours")

	# Brûlure : des dégâts au début de chaque tour de la victime, même sans attaque.
	var burn := CombatManager.new()
	burn.rng.seed = 2
	var torch := _combatant("Torche", "Feu", 100, 50, 100, 400, true)
	var victim := _combatant("Brûlé", "Feu", 10, 0, 300, 400, false)
	burn.start([torch] as Array[Combatant], [victim] as Array[Combatant])
	victim.add_status({"type": "burn", "duration": 3, "value": 0.2, "source_atk": 100})
	var before := victim.hp
	burn.begin_turn()
	check(victim.hp < before, "la brûlure ronge la cible en début de tour (%d -> %d)" % [before, victim.hp])

	# Étourdissement : le tour est perdu.
	var stun := CombatManager.new()
	stun.rng.seed = 3
	var sleeper := _combatant("Étourdi", "Feu", 100, 50, 300, 400, false)
	var watcher := _combatant("Témoin", "Feu", 100, 50, 10, 400, true)
	stun.start([watcher] as Array[Combatant], [sleeper] as Array[Combatant])
	sleeper.add_status({"type": "stun", "duration": 1, "value": 0.0})
	check(stun.begin_turn() == null, "un combattant étourdi saute son tour")

	# IA tactique : elle vise l'avantage élémentaire plutôt que la première cible venue.
	var ai := CombatManager.new()
	ai.rng.seed = 4
	var attacker := _combatant("Pyromane", "Feu", 120, 50, 100, 900, false)
	var solid := _combatant("Solide", "Eau", 100, 120, 90, 900, true)
	var vulnerable := _combatant("Vulnérable", "Vent", 100, 120, 90, 900, true)
	ai.start([solid, vulnerable] as Array[Combatant], [attacker] as Array[Combatant])
	check(ai._choose_target(attacker, [solid, vulnerable] as Array[Combatant]) == vulnerable,
		"l'IA vise la faiblesse élémentaire")
	var finishable := _combatant("Agonisant", "Eau", 100, 20, 90, 1, true)
	check(ai._choose_target(attacker, [vulnerable, finishable] as Array[Combatant]) == finishable,
		"l'IA achève une cible à portée de mort avant de chercher l'avantage")

	# Les adversaires du contenu se montent bien au niveau demandé.
	var boss := CombatManager.from_enemy("boss_solvire_kaan", 20)
	var rookie := CombatManager.from_enemy("boss_solvire_kaan", 1)
	check(boss.max_hp > rookie.max_hp * 1.9, "un boss niveau 20 est bien plus solide qu'au niveau 1")
	check(boss.is_boss and not CombatManager.from_enemy("mob_eclat_ardent", 1).is_boss,
		"boss nommé et mob générique sont distingués")

	# Un combat de chapitre complet, avec les vraies données.
	var story := DataLoader.load_json(DataLoader.STORY_PATH)
	var battle: Dictionary = story["chapters"][0]["battles"][0]
	var foes: Array[Combatant] = []
	for entry: Dictionary in battle["enemies"]:
		foes.append(CombatManager.from_enemy(entry["id"], int(entry["level"])))
	var player := _new_player()
	var team: Array[Combatant] = []
	for character_id: String in player.get_owned_character_ids():
		team.append(CombatManager.from_character(player.get_character_data(character_id),
			player.get_character_stats(character_id), player.get_character_skill(character_id)))
	var chapter := CombatManager.new()
	chapter.rng.seed = 9
	chapter.start(team, foes)
	var outcome := chapter.auto_resolve()
	check(outcome != CombatManager.Result.ONGOING, "le premier combat du chapitre 1 se résout")
	check(chapter.events.size() > 3, "le combat produit un journal d'événements (%d)" % chapter.events.size())
	print("       chapitre 1, combat 1 : %s en %d tours" % [
		"victoire" if outcome == CombatManager.Result.VICTORY else "défaite", chapter.turn_count])
	player.free()

## Enchaînement complet d'un combat depuis l'UI : demande d'un écran, composition d'équipe,
## arène en mode auto, puis récompenses versées et avancement du chapitre enregistré.
func test_combat_screens(host: Node) -> void:
	print("Combat depuis l'interface")
	var player: PlayerManager = _main.player
	var story: Node = host.get_child(2)
	var dungeons: Node = host.get_child(3)
	check(story.has_signal("encounter_requested") and dungeons.has_signal("encounter_requested"),
		"Histoire et Donjons demandent leurs combats à la coquille")
	check(player.is_chapter_unlocked("ch_01") and not player.is_chapter_unlocked("ch_02"),
		"seul le premier chapitre est ouvert en début de partie")

	var chapter: Dictionary = ContentLibrary.chapter("ch_01")
	var encounter := {
		"title": chapter["battles"][0]["name"],
		"enemies": chapter["battles"][0]["enemies"],
		"chapter_id": "ch_01",
		"battle_index": 0,
	}
	_main._on_encounter_requested(encounter)
	var team_select: Node = _main._team_select
	check(team_select.visible and team_select.get_node("%Grid").get_child_count() == player.inventory.size(),
		"la composition d'équipe propose les guerriers possédés")

	var team: Array = player.get_owned_character_ids().slice(0, 3)
	var energy_before: int = player.stamina.get_current()
	var or_before: int = player.or_de_guilde
	_main._arena.step_delay = 0.0
	_main._on_team_confirmed(team)
	check(player.stamina.get_current() == energy_before - player.stamina.cost_per_combat,
		"l'engagement coûte l'énergie d'un combat")
	check(_main._arena.visible and not team_select.visible, "l'arène prend le relais")

	# Mode auto : l'IA joue l'équipe du joueur jusqu'au bout du combat.
	_main._arena._on_auto_toggled(true)
	check(_main._arena._combat.is_over(), "le combat se résout en mode auto")
	check(_main._arena.get_node("%Result").visible, "l'écran de fin de combat s'affiche")
	if _main._arena._combat.result() == CombatManager.Result.VICTORY:
		check(player.or_de_guilde > or_before, "la victoire verse de l'Or (%d -> %d)" % [or_before, player.or_de_guilde])
		check(player.battles_cleared("ch_01") == 1, "le combat réussi fait avancer le chapitre")
	else:
		check(player.or_de_guilde == or_before, "une défaite ne verse rien")
	_main._arena._on_continue()
	check(not _main._arena.visible, "l'arène se referme sur Continuer")

## Accueil et tutoriel : le joueur doit passer par l'écran-titre, voir le tutoriel une seule
## fois, et le tutoriel doit rester cohérent avec les onglets réellement présents.
func test_onboarding() -> void:
	print("Accueil et tutoriel")
	var player: PlayerManager = _main.player
	check(_main._title_screen.visible, "l'écran-titre s'affiche au lancement")
	check(not player.tutorial_seen, "une nouvelle guilde n'a pas encore vu le tutoriel")

	_main._on_entered()
	check(not _main._title_screen.visible and _main._tutorial.visible,
		"entrer dans la guilde lance le tutoriel")

	var steps: Array = DataLoader.load_json(DataLoader.TUTORIAL_PATH).get("steps", [])
	var navs_ok := true
	for step: Dictionary in steps:
		var nav_name := str(step.get("nav", ""))
		navs_ok = navs_ok and (nav_name == "" or _main.has_node("%" + nav_name))
	check(navs_ok, "chaque étape du tutoriel désigne un onglet qui existe (%d étapes)" % steps.size())

	for i in range(steps.size()):
		_main._tutorial._advance()
	check(not _main._tutorial.visible, "le tutoriel se referme à la dernière étape")
	check(player.tutorial_seen, "le tutoriel est marqué comme vu")

	var reloaded := PlayerManager.new()
	reloaded.save_path = TEST_SAVE_PATH
	reloaded.load_or_new_game()
	check(reloaded.tutorial_seen, "le tutoriel reste vu après rechargement")
	reloaded.free()
