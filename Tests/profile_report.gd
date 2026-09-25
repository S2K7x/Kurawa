extends SceneTree

## Mesure des chemins chauds du projet, avant et après optimisation.
## La documentation Godot est explicite : on profile, puis on optimise ce que la mesure
## désigne — pas ce qu'on imagine lent.
##
##   godot --headless --path . -s res://Tests/profile_report.gd
##
## Les durées sont en millisecondes, mesurées sur un build de debug : ce sont des ordres
## de grandeur et un point de comparaison avant/après, pas des chiffres absolus.

const SAVE_PATH := "user://profile_kurawa_save.json"

func _initialize() -> void:
	print("Profil des chemins chauds (ms)\n")
	_bench("DataLoader.characters_db() ×2000", func() -> void:
		for i in range(2000):
			DataLoader.characters_db())
	_bench("DataLoader.load_json(economy) ×2000", func() -> void:
		for i in range(2000):
			DataLoader.load_json(DataLoader.ECONOMY_PATH))
	_bench("DataLoader.character_art() ×2000", func() -> void:
		var data := DataLoader.character("kur_001")
		for i in range(2000):
			DataLoader.character_art(data))
	_bench("CombatManager.from_enemy() ×2000", func() -> void:
		for i in range(2000):
			CombatManager.from_enemy("mob_eclat_ardent", 10))

	var combat := CombatManager.new()
	var duel := _duel(combat)
	_bench("turn_order_preview(7) ×2000", func() -> void:
		for i in range(2000):
			combat.turn_order_preview(7))
	_bench("combat complet en auto ×300", func() -> void:
		for i in range(300):
			var fight := CombatManager.new()
			fight.rng.seed = i
			fight.start(_team(), _foes())
			fight.auto_resolve())

	var player := PlayerManager.new()
	player.save_path = SAVE_PATH
	player.reset_save()
	_bench("PlayerManager.save_game() ×300", func() -> void:
		for i in range(300):
			player.save_game())
	_bench("summon(x10) ×200", func() -> void:
		for i in range(200):
			player.add_eclats(300)
			player.summon(true))
	_bench("get_character_stats() ×5000", func() -> void:
		var ids := player.get_owned_character_ids()
		for i in range(5000):
			player.get_character_stats(ids[i % ids.size()]))
	# Coût côté interface : c'est lui que le joueur ressent comme de la fluidité.
	var card_scene: PackedScene = load("res://Scenes/CharacterCard.tscn")
	var host := Control.new()
	root.add_child(host)
	_bench("construire 28 cartes (galerie) ×10", func() -> void:
		for pass_index in range(10):
			UiUtils.clear_children(host)
			for character: Dictionary in DataLoader.characters_db().get("characters", []):
				var card: CharacterCard = card_scene.instantiate()
				host.add_child(card)
				card.display(character, {"level": 1, "stars": 1, "xp": 0}, 6))
	UiUtils.clear_children(host)
	host.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	player.free()
	duel.clear()
	quit(0)

func _bench(label: String, body: Callable) -> void:
	var start := Time.get_ticks_usec()
	body.call()
	print("  %-38s %8.1f" % [label, (Time.get_ticks_usec() - start) / 1000.0])

func _team() -> Array[Combatant]:
	var progression := ProgressionSystem.new()
	var team: Array[Combatant] = []
	for character_id: String in ["kur_013", "kur_001", "kur_002"]:
		var data := DataLoader.character(character_id)
		var entry := {"level": 20, "stars": 1, "xp": 0}
		team.append(CombatManager.from_character(data,
			progression.compute_stats(data["stats"], entry),
			progression.compute_skill(data["skill"], 1)))
	return team

func _foes() -> Array[Combatant]:
	var foes: Array[Combatant] = []
	for enemy_id: String in ["mob_eclat_ardent", "mob_veilleur_brise", "mob_colosse_faille"]:
		foes.append(CombatManager.from_enemy(enemy_id, 15))
	return foes

func _duel(combat: CombatManager) -> Array[Combatant]:
	var team := _team()
	var foes := _foes()
	combat.start(team, foes)
	return team + foes
