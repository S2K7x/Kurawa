extends SceneTree

## Tests de validation de la Phase 1 (taux de tirage, pity, sauvegarde, énergie, progression).
## Lancement : godot --headless --path . -s res://Tests/run_tests.gd
## Code de sortie 0 si tout passe, 1 sinon.

const TEST_SAVE_PATH := "user://test_kurawa_save.json"

var _failures: int = 0
var _checks: int = 0
var fake_time: float = 1_000_000.0
var fake_day: String = "2026-09-25"

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

	# Illustrations : la convention de nommage et le repli sur le placeholder doivent tenir,
	# que le roster soit illustré ou non (Phase 4 en cours).
	check(DataLoader.character_art({}) == null, "sans identifiant, aucune illustration")
	check(DataLoader.character_art({"id": "guerrier_inexistant"}) == null,
		"guerrier sans fichier : repli sur le placeholder")
	check(DataLoader.character_art({"id": "x", "art": "res://icon.svg"}) != null,
		"le champ `art` permet de pointer une illustration hors convention")

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
	check(host.get_child_count() == 5, "QG, Brèche, Guilde, Histoire et Donjons montés dans la coquille")
	var summon: Node = host.get_child(1)
	var inventory: Node = host.get_child(2)
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

	test_meta_progression(host)
	test_art_viewer(host)
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

	# --- Profondeur tactique (Phase 5) ---------------------------------------------------------
	# La garde : encaisser à moitié, charger la Brèche, et regagner un peu d'ATB.
	var guard_combat := CombatManager.new()
	guard_combat.rng.seed = 11
	var hitter := _combatant("Cogneur", "Feu", 200, 50, 100, 900, false)
	var guardian := _combatant("Gardien", "Feu", 100, 100, 100, 900, true)
	guard_combat.start([guardian] as Array[Combatant], [hitter] as Array[Combatant])
	guard_combat._basic_attack(hitter, guardian)
	var open_damage: int = guardian.max_hp - guardian.hp
	guardian.hp = guardian.max_hp
	guard_combat.act(guardian, "guard")
	guard_combat._basic_attack(hitter, guardian)
	var guarded_damage: int = guardian.max_hp - guardian.hp
	check(guarded_damage < open_damage, "la garde réduit les dégâts subis (%d -> %d)" % [open_damage, guarded_damage])
	check(guard_combat.breach_gauge > 0, "la garde charge la jauge de Brèche")

	# La Percée : disponible à jauge pleine, elle frappe tout le camp adverse et relance l'équipe.
	var ult := CombatManager.new()
	ult.rng.seed = 12
	var leader := _combatant("Meneur", "Feu", 180, 80, 100, 900, true)
	var foe_a := _combatant("Sbire A", "Vent", 60, 40, 90, 800, false)
	var foe_b := _combatant("Sbire B", "Vent", 60, 40, 90, 800, false)
	ult.start([leader] as Array[Combatant], [foe_a, foe_b] as Array[Combatant])
	check(not ult.can_use_ultimate(leader), "la Percée est indisponible jauge vide")
	ult.breach_gauge = 100
	check(ult.can_use_ultimate(leader), "la Percée s'ouvre à jauge pleine")
	ult.act(leader, "ultimate")
	check(foe_a.hp < foe_a.max_hp and foe_b.hp < foe_b.max_hp, "la Percée touche toute l'équipe adverse")
	check(ult.breach_gauge < 100, "la Percée consomme la jauge")

	# Manipulation de l'ATB : pousser un allié, retenir un ennemi.
	var atb := CombatManager.new()
	atb.rng.seed = 13
	var pusher := _combatant("Meneuse", "Vent", 100, 50, 100, 900, true)
	var slowed := _combatant("Ralenti", "Vent", 100, 50, 100, 900, false)
	atb.start([pusher] as Array[Combatant], [slowed] as Array[Combatant])
	slowed.atb = 500.0
	atb._apply_skill_effects(pusher, {"effects": [
		{"type": "atb_cut", "target": "target", "chance": 1.0, "value": 0.3}]},
		[slowed] as Array[Combatant], 0)
	check(slowed.atb < 500.0, "atb_cut retient la jauge de la cible (%.0f)" % slowed.atb)
	atb._apply_skill_effects(pusher, {"effects": [
		{"type": "atb_boost", "target": "ally_all", "chance": 1.0, "value": 0.5}]},
		[] as Array[Combatant], 0)
	check(pusher.atb > 0.0, "atb_boost pousse la jauge de l'équipe (%.0f)" % pusher.atb)

	# Nettoyage et dissipement.
	var purge := CombatManager.new()
	var sick := _combatant("Empoisonné", "Feu", 100, 50, 100, 900, true)
	var buffed := _combatant("Renforcé", "Feu", 100, 50, 100, 900, false)
	purge.start([sick] as Array[Combatant], [buffed] as Array[Combatant])
	sick.add_status({"type": "burn", "duration": 3, "value": 0.1})
	sick.add_status({"type": "atk_up", "duration": 3, "value": 0.2})
	buffed.add_status({"type": "atk_up", "duration": 3, "value": 0.5})
	purge._apply_skill_effects(sick, {"effects": [
		{"type": "cleanse", "target": "self", "chance": 1.0}]}, [] as Array[Combatant], 0)
	check(not sick.has_status("burn") and sick.has_status("atk_up"),
		"le nettoyage retire les altérations néfastes et garde les bonnes")
	purge._apply_skill_effects(sick, {"effects": [
		{"type": "strip", "target": "target", "chance": 1.0}]}, [buffed] as Array[Combatant], 0)
	check(not buffed.has_status("atk_up"), "le dissipement retire les altérations bénéfiques")

	# Riposte : la cible rend le coup, sans boucle infinie.
	var riposte := CombatManager.new()
	riposte.rng.seed = 14
	var striker := _combatant("Assaillant", "Feu", 150, 50, 100, 900, false)
	var counterer := _combatant("Riposteur", "Feu", 150, 50, 100, 900, true)
	riposte.start([counterer] as Array[Combatant], [striker] as Array[Combatant])
	counterer.add_status({"type": "counter", "duration": 3, "value": 0.8})
	riposte._basic_attack(striker, counterer)
	check(striker.hp < striker.max_hp, "la riposte rend le coup à l'assaillant")

	# Aperçu de l'ordre des tours : le rapide revient plus souvent que le lent.
	var preview := CombatManager.new()
	var quick := _combatant("Rapide", "Feu", 100, 50, 200, 900, true)
	var laggard := _combatant("Lent", "Feu", 100, 50, 50, 900, false)
	preview.start([quick] as Array[Combatant], [laggard] as Array[Combatant])
	var upcoming := preview.turn_order_preview(6)
	var quick_turns := upcoming.filter(func(u: Combatant) -> bool: return u == quick).size()
	check(upcoming.size() == 6 and quick_turns >= 4,
		"l'aperçu annonce 6 tours, dominés par le plus rapide (%d/6)" % quick_turns)
	check(quick.atb == 0.0, "l'aperçu ne touche pas à l'état réel du combat")

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
	var story: Node = host.get_child(3)
	var dungeons: Node = host.get_child(4)
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
	# Rejouer relance le même combat en repayant l'énergie, sans repasser par les écrans.
	var energy_before_replay: int = player.stamina.get_current()
	_main._arena._on_replay()
	check(player.stamina.get_current() == energy_before_replay - player.stamina.cost_per_combat,
		"rejouer repaie l'énergie d'un combat")
	check(_main._arena._combat.turn_count > 0 and _main._arena.visible, "rejouer relance le même combat")
	_main._arena._on_auto_toggled(true)

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

## Visionneuse plein écran : elle doit s'ouvrir sur le bon guerrier, se parcourir, et
## refuser de s'ouvrir sur un guerrier sans illustration.
func test_art_viewer(host: Node) -> void:
	print("Visionneuse d'illustrations")
	var inventory: Node = host.get_child(2)
	var viewer: Node = _main._art_viewer
	var ids: Array = inventory._filtered_ids()
	check(ids.size() >= 2, "assez de guerriers possédés pour parcourir la galerie (%d)" % ids.size())

	_main._on_artwork_requested(ids[0], ids)
	check(viewer.visible and viewer._index == 0, "la visionneuse s'ouvre sur le guerrier demandé")
	check(viewer.get_node("%Art").texture != null, "l'illustration est chargée en plein écran")
	viewer._step(1)
	check(viewer._index == 1, "le glissement passe au guerrier suivant")
	viewer._step(-1)
	check(viewer._index == 0, "le glissement revient en arrière")
	viewer._set_caption_visible(false)
	check(not viewer.get_node("%Caption").visible, "le bandeau se masque pour laisser l'illustration seule")
	viewer._close()
	check(not viewer.visible, "la visionneuse se referme")

## Boucles d'engagement : connexion, invocation offerte, missions, exploits, collection,
## niveau de guilde et bannière vedette. Le tout doit survivre à un rechargement et à un
## changement de jour.
func test_meta_progression(host: Node) -> void:
	print("Quartier général")
	var player: PlayerManager = _main.player
	var meta := player.meta
	fake_day = "2026-09-25"
	meta.clock = func() -> String: return fake_day
	meta.refresh_day()

	# Connexion du jour : réclamable une fois, valeur croissante, série qui avance.
	check(meta.can_claim_login(), "la connexion du jour est réclamable")
	var eclats_before: int = player.eclats_dimensionnels
	var login := player.claim_login()
	check(not login.is_empty() and player.eclats_dimensionnels > eclats_before,
		"la connexion verse ses Éclats (+%d)" % int(login.get("eclats_dimensionnels", 0)))
	check(not meta.can_claim_login() and meta.login_streak == 1, "elle ne se réclame pas deux fois")
	check(player.claim_login().is_empty(), "une seconde tentative ne donne rien")

	# Jour 7 plus généreux que le jour 1 : la série doit valoir la peine d'être tenue.
	var cycle: Array = meta.config["daily_login"]["cycle"]
	check(int(cycle[6]["eclats_dimensionnels"]) > int(cycle[0]["eclats_dimensionnels"]) * 3,
		"le jour 7 vaut nettement plus que le jour 1")

	# Invocation offerte : une par jour, gratuite.
	check(meta.has_free_summon(), "l'invocation offerte est disponible")
	var before_free: int = player.eclats_dimensionnels
	var free_pull: Array = player.summon(false, true)
	check(free_pull.size() == 1 and player.eclats_dimensionnels == before_free,
		"l'invocation offerte ne coûte aucun Éclat")
	check(player.summon(false, true).is_empty(), "elle ne se prend qu'une fois par jour")

	# Missions du jour : progression, réclamation, puis coffre.
	check(meta.mission_states().size() == 3, "trois missions tirées pour la journée")
	for state: Dictionary in meta.mission_states():
		meta.bump(_mission_counter(meta, str(state["id"])), int(state["target"]))
	var all_done := true
	for state: Dictionary in meta.mission_states():
		all_done = all_done and state["done"]
	check(all_done, "les missions se marquent accomplies quand le compteur suit")
	for state: Dictionary in meta.mission_states():
		player.claim_mission(str(state["id"]))
	check(meta.can_claim_daily_chest(), "le coffre du jour s'ouvre une fois les trois missions prises")
	check(not player.claim_daily_chest().is_empty() and not meta.can_claim_daily_chest(),
		"le coffre ne se prend qu'une fois")

	# Exploits : paliers successifs.
	meta.counters["summons"] = 10
	var claimable := meta.achievement_states().filter(func(a: Dictionary) -> bool: return a["claimable"])
	check(claimable.size() > 0, "un palier d'exploit devient réclamable")
	var achievement_id: String = claimable[0]["id"]
	check(not player.claim_achievement(achievement_id).is_empty(), "le palier se réclame")
	check(player.claim_achievement(achievement_id).is_empty(), "et pas deux fois")

	# Collection : jalon atteint selon le nombre de guerriers différents.
	var owned: int = player.inventory.size()
	var milestones := meta.collection_states(owned).filter(func(c: Dictionary) -> bool: return c["claimable"])
	if milestones.size() > 0:
		var milestone: int = milestones[0]["owned"]
		check(not player.claim_collection(milestone).is_empty(), "un jalon de collection se réclame")
		check(player.claim_collection(milestone).is_empty(), "et pas deux fois")

	# Niveau de guilde : monte à chaque combat, relève le plafond d'énergie.
	var level_before: int = meta.guild_level
	var base_max: int = player.stamina.max_stamina
	for i in range(40):
		meta.add_guild_xp(true)
	check(meta.guild_level > level_before, "la guilde monte de niveau en combattant (%d -> %d)" % [
		level_before, meta.guild_level])
	player._sync_meta_bonuses()
	check(player.stamina.max_stamina > base_max, "le niveau de guilde relève le plafond d'énergie")

	# Bannière vedette : un SSR mis en avant, stable sur la journée.
	check(player.gacha.featured_id != "", "une vedette est désignée")
	check(player.get_character_data(player.gacha.featured_id).get("rarity", "") == "SSR",
		"la vedette est un SSR")

	# Nouveau jour : missions renouvelées, invocation offerte rendue, série conservée.
	fake_day = "2026-09-26"
	check(player.refresh_day(), "le changement de jour est détecté")
	check(meta.can_claim_login() and meta.has_free_summon(), "connexion et invocation offerte reviennent")
	check(meta.login_streak == 1, "la série de connexion n'est pas perdue en changeant de jour")

	# Tout cela survit à un rechargement.
	player.save_game()
	var reloaded := PlayerManager.new()
	reloaded.save_path = TEST_SAVE_PATH
	reloaded.meta.clock = func() -> String: return fake_day
	reloaded.load_or_new_game()
	check(reloaded.meta.guild_level == meta.guild_level and reloaded.meta.login_streak == meta.login_streak,
		"niveau de guilde et série rechargés")
	check(reloaded.meta.count("summons") == meta.count("summons"), "les compteurs de vie sont rechargés")
	reloaded.free()

func _mission_counter(meta: MetaProgression, mission_id: String) -> String:
	for mission: Dictionary in meta.config["daily_missions"]["pool"]:
		if mission["id"] == mission_id:
			return str(mission["counter"])
	return ""
