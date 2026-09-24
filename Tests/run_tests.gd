extends SceneTree

## Tests de validation de la Phase 1 (taux de tirage, pity, sauvegarde, énergie, progression).
## Lancement : godot --headless --path . -s res://Tests/run_tests.gd
## Code de sortie 0 si tout passe, 1 sinon.

const TEST_SAVE_PATH := "user://test_kurawa_save.json"

var _failures: int = 0
var _checks: int = 0
var fake_time: float = 1_000_000.0

func _init() -> void:
	test_costs()
	test_raw_rates()
	test_pity()
	test_multi_pull_guarantee()
	test_progression()
	test_duplicates()
	test_stamina()
	test_save_roundtrip()
	test_corrupt_save()
	print("\n%d vérifications, %d échec(s)." % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

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
