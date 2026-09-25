extends Node
class_name PlayerManager

## Ressources du joueur, inventaire de guerriers et sauvegarde locale.
## Sauvegarde locale uniquement (pas de compte/cloud) -- voir GDD.md > Ambition et portée du projet.
## Possède les systèmes dont l'état est sauvegardé (pity du gacha, jauge d'énergie).

signal state_changed

const SAVE_VERSION := 3
const DEFAULT_SAVE_PATH := "user://kurawa_save.json"

var save_path: String = DEFAULT_SAVE_PATH

var eclats_dimensionnels: int = 0
var or_de_guilde: int = 0

# inventory[character_id] = {"level": int, "stars": int, "xp": int}
var inventory: Dictionary = {}

# Avancement du mode histoire : story_progress[chapter_id] = nombre de combats réussis.
var story_progress: Dictionary = {}
# Chapitres dont la récompense de premier passage a déjà été versée.
var claimed_first_clear: Dictionary = {}
# Dernière équipe envoyée au combat, proposée par défaut à la sélection suivante.
var last_team: Array = []
# Le tutoriel de première partie n'est montré qu'une fois.
var tutorial_seen: bool = false

var gacha := GachaSystem.new()
var stamina := StaminaSystem.new()
var progression := ProgressionSystem.new()
var meta := MetaProgression.new()

# character_id -> fiche du catalogue
var _catalog: Dictionary = {}

func _init() -> void:
	for character: Dictionary in DataLoader.characters_db().get("characters", []):
		_catalog[character["id"]] = character

func _ready() -> void:
	load_or_new_game()

## Répercute sur les systèmes ce que la méta-progression décide : plafond d'énergie relevé
## par le niveau de guilde, et guerrier mis en avant par la bannière du moment.
func _sync_meta_bonuses() -> void:
	var base_max := int(DataLoader.economy().get("stamina", {}).get("max", 120))
	stamina.max_stamina = base_max + meta.bonus_stamina()
	var ssr_ids: Array = []
	for character: Dictionary in DataLoader.characters_db().get("characters", []):
		if character.get("rarity", "") == "SSR" and not character.get("starter", false):
			ssr_ids.append(character["id"])
	ssr_ids.sort()
	gacha.featured_id = meta.featured_character_id(ssr_ids)
	gacha.featured_share = meta.featured_share()

## Bascule quotidienne : missions renouvelées, invocation offerte rendue, vedette recalculée.
func refresh_day() -> bool:
	if not meta.refresh_day():
		return false
	_sync_meta_bonuses()
	save_game()
	state_changed.emit()
	return true

func get_character_data(character_id: String) -> Dictionary:
	return _catalog.get(character_id, {})

func get_owned_character_ids() -> Array:
	return inventory.keys()

## Stats effectives (niveau + étoiles) d'un personnage possédé.
func get_character_stats(character_id: String) -> Dictionary:
	if not inventory.has(character_id):
		return {}
	return progression.compute_stats(get_character_data(character_id).get("stats", {}), inventory[character_id])

## Compétence effective (puissance et cooldown ajustés par les étoiles) d'un personnage possédé.
func get_character_skill(character_id: String) -> Dictionary:
	if not inventory.has(character_id):
		return {}
	return progression.compute_skill(get_character_data(character_id).get("skill", {}), inventory[character_id].get("stars", 1))

# --- Nouvelle partie / sauvegarde ------------------------------------------------------------

func load_or_new_game() -> void:
	if not FileAccess.file_exists(save_path) or not load_game():
		new_game()

func new_game() -> void:
	var start: Dictionary = DataLoader.economy().get("starting_resources", {})
	eclats_dimensionnels = int(start.get("eclats_dimensionnels", 0))
	or_de_guilde = int(start.get("or_de_guilde", 0))
	inventory = {}
	story_progress = {}
	claimed_first_clear = {}
	last_team = []
	tutorial_seen = false
	meta = MetaProgression.new()
	meta.refresh_day()
	_sync_meta_bonuses()
	gacha.from_dict({})
	stamina.reset_full()
	# Personnage de départ garanti, lié à l'histoire (voir GDD.md > Personnage de départ).
	for character_id: String in _catalog:
		if _catalog[character_id].get("starter", false):
			inventory[character_id] = progression.new_entry()
	save_game()
	state_changed.emit()

## Efface la sauvegarde et repart d'une nouvelle partie.
func reset_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	new_game()

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"eclats_dimensionnels": eclats_dimensionnels,
		"or_de_guilde": or_de_guilde,
		"inventory": inventory,
		"story_progress": story_progress,
		"claimed_first_clear": claimed_first_clear,
		"last_team": last_team,
		"tutorial_seen": tutorial_seen,
		"gacha": gacha.to_dict(),
		"meta": meta.to_dict(),
		"stamina": stamina.to_dict(),
	}
	# Écriture atomique : fichier temporaire puis renommage, pour ne jamais laisser
	# une sauvegarde à moitié écrite si le jeu est coupé pendant l'écriture.
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("PlayerManager: impossible d'écrire %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_error("PlayerManager: renommage de la sauvegarde impossible (%s)" % error_string(err))
		return false
	return true

## Charge la sauvegarde. Retourne false si elle est illisible (elle est alors mise de côté
## en .corrupt pour ne pas être écrasée sans trace).
func load_game() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_error("PlayerManager: sauvegarde illisible, copie dans %s.corrupt" % save_path)
		DirAccess.copy_absolute(save_path, save_path + ".corrupt")
		return false
	var data: Dictionary = parsed
	# Une sauvegarde plus récente que le jeu ne peut pas être lue sans risquer de perdre ce
	# qu'elle contient : on la met de côté intacte plutôt que de l'écraser au prochain save.
	var version := int(data.get("version", 1))
	if version > SAVE_VERSION:
		push_error("PlayerManager: sauvegarde en version %d, le jeu en gère %d. Mise de côté en .future."
			% [version, SAVE_VERSION])
		DirAccess.copy_absolute(save_path, save_path + ".future")
		return false
	if version < SAVE_VERSION:
		# Les champs absents prennent leur valeur par défaut : la migration est implicite.
		print("PlayerManager: sauvegarde version %d migrée vers %d." % [version, SAVE_VERSION])

	eclats_dimensionnels = int(data.get("eclats_dimensionnels", 0))
	or_de_guilde = int(data.get("or_de_guilde", 0))
	inventory = {}
	# JSON ne distingue pas int/float : on renormalise les entrées d'inventaire.
	var saved_inventory: Dictionary = data.get("inventory", {})
	for character_id: String in saved_inventory:
		if not _catalog.has(character_id):
			push_warning("PlayerManager: personnage inconnu ignoré à la sauvegarde : %s" % character_id)
			continue
		# Une entrée corrompue (mauvais type) est remplacée par un guerrier neuf plutôt que
		# de faire planter tout le chargement.
		var raw: Variant = saved_inventory[character_id]
		var entry: Dictionary = raw if raw is Dictionary else {}
		inventory[character_id] = {
			"level": clampi(int(entry.get("level", 1)), 1, progression.max_level),
			"stars": clampi(int(entry.get("stars", 1)), 1, progression.max_stars),
			"xp": maxi(int(entry.get("xp", 0)), 0),
		}
	story_progress = {}
	for chapter_id: String in data.get("story_progress", {}):
		story_progress[chapter_id] = int(data["story_progress"][chapter_id])
	claimed_first_clear = data.get("claimed_first_clear", {})
	last_team = []
	for character_id: String in data.get("last_team", []):
		if inventory.has(character_id):
			last_team.append(character_id)
	tutorial_seen = bool(data.get("tutorial_seen", false))
	meta.from_dict(data.get("meta", {}))
	_sync_meta_bonuses()
	gacha.from_dict(data.get("gacha", {}))
	stamina.from_dict(data.get("stamina", {}))
	state_changed.emit()
	return true

# --- Ressources ------------------------------------------------------------------------------

func spend_eclats(amount: int) -> bool:
	if eclats_dimensionnels < amount:
		return false
	eclats_dimensionnels -= amount
	return true

func add_eclats(amount: int) -> void:
	eclats_dimensionnels += amount

func spend_or(amount: int) -> bool:
	if or_de_guilde < amount:
		return false
	or_de_guilde -= amount
	return true

func add_or(amount: int) -> void:
	or_de_guilde += amount

# --- Invocation & inventaire -----------------------------------------------------------------

func can_afford_summon(multi: bool) -> bool:
	return eclats_dimensionnels >= gacha.get_cost(multi)

## Paie et effectue une invocation, ajoute les guerriers à l'inventaire puis sauvegarde.
## Retourne les résultats enrichis (voir add_character), ou [] si les Éclats manquent.
## `free` : l'invocation offerte du jour, qui ne coûte rien et ne peut être prise qu'une fois.
func summon(multi: bool, free: bool = false) -> Array:
	if free:
		if multi or not meta.has_free_summon():
			return []
		meta.consume_free_summon()
	elif not spend_eclats(gacha.get_cost(multi)):
		return []
	var pulls: Array = gacha.multi_pull() if multi else [gacha.single_pull()]
	var results: Array = []
	for pull: Dictionary in pulls:
		var result := add_character(pull["character"].get("id", ""))
		result["character"] = pull["character"]
		result["rarity"] = pull["rarity"]
		results.append(result)
		meta.bump("summons")
		if not result["is_new"] and int(result.get("or_bonus", 0)) == 0:
			meta.bump("stars_gained")
	save_game()
	state_changed.emit()
	return results

## Ajoute un personnage obtenu à l'inventaire. Un doublon fait monter d'une étoile
## (ou est converti en Or au palier max). Ne sauvegarde pas : l'appelant s'en charge.
## Retourne {"is_new": bool, "stars": int, "or_bonus": int}.
func add_character(character_id: String) -> Dictionary:
	if not _catalog.has(character_id):
		push_error("PlayerManager: personnage inconnu : '%s'" % character_id)
		return {"is_new": false, "stars": 0, "or_bonus": 0}
	if not inventory.has(character_id):
		inventory[character_id] = progression.new_entry()
		return {"is_new": true, "stars": 1, "or_bonus": 0}
	var entry: Dictionary = inventory[character_id]
	var or_bonus := progression.apply_duplicate(entry)
	add_or(or_bonus)
	return {"is_new": false, "stars": entry["stars"], "or_bonus": or_bonus}

## Donne de l'XP à un personnage possédé. Retourne le nombre de niveaux gagnés.
func add_character_xp(character_id: String, amount: int) -> int:
	if not inventory.has(character_id):
		return 0
	return progression.add_xp(inventory[character_id], amount)

# --- Mode histoire & récompenses ---------------------------------------------------------------

## Nombre de combats déjà réussis dans un chapitre.
func battles_cleared(chapter_id: String) -> int:
	return int(story_progress.get(chapter_id, 0))

func is_chapter_cleared(chapter_id: String) -> bool:
	var chapter := ContentLibrary.chapter(chapter_id)
	return battles_cleared(chapter_id) >= chapter.get("battles", []).size()

## Un chapitre s'ouvre quand le précédent est bouclé ; le premier est toujours jouable.
func is_chapter_unlocked(chapter_id: String) -> bool:
	var all_chapters := ContentLibrary.chapters()
	for index in range(all_chapters.size()):
		if all_chapters[index].get("id", "") == chapter_id:
			return index == 0 or is_chapter_cleared(str(all_chapters[index - 1].get("id", "")))
	return false

## Un combat de chapitre est jouable dès que le précédent est réussi (rejouable ensuite).
func is_battle_unlocked(chapter_id: String, battle_index: int) -> bool:
	return is_chapter_unlocked(chapter_id) and battle_index <= battles_cleared(chapter_id)

## Enregistre une victoire : XP à l'équipe engagée, Or, avancement du chapitre et
## récompense de premier passage s'il vient d'être bouclé. Retourne le détail pour l'écran
## de fin de combat. Ne consomme pas d'énergie : c'est start_combat() qui l'a déjà fait.
func grant_victory(team_ids: Array, rewards: Dictionary, chapter_id: String = "", battle_index: int = -1,
		battle_stats: Dictionary = {}) -> Dictionary:
	var gained_or := int(rewards.get("or", 0))
	var gained_xp := int(rewards.get("xp", 0))
	add_or(gained_or)
	var level_ups := {}
	for character_id: String in team_ids:
		var levels := add_character_xp(character_id, gained_xp)
		if levels > 0:
			level_ups[character_id] = levels
			meta.bump("level_ups", levels)
	meta.bump("victories")
	meta.bump("ultimates", int(battle_stats.get("ultimates", 0)))
	meta.bump("dungeon_clears" if chapter_id == "" else "story_clears")
	var guild_levels := meta.add_guild_xp(true)
	for i in range(guild_levels):
		_apply_reward(meta.level_reward())
	if guild_levels > 0:
		_sync_meta_bonuses()

	var first_clear := {}
	if chapter_id != "" and battle_index >= 0:
		story_progress[chapter_id] = maxi(battles_cleared(chapter_id), battle_index + 1)
		if is_chapter_cleared(chapter_id) and not claimed_first_clear.has(chapter_id):
			claimed_first_clear[chapter_id] = true
			first_clear = ContentLibrary.chapter(chapter_id).get("first_clear", {})
			add_eclats(int(first_clear.get("eclats_dimensionnels", 0)))
			add_or(int(first_clear.get("or_de_guilde", 0)))

	last_team = team_ids.duplicate()
	save_game()
	state_changed.emit()
	return {"or": gained_or, "xp": gained_xp, "level_ups": level_ups, "first_clear": first_clear,
		"guild_levels": guild_levels}

## Défaite : rien n'est gagné, mais l'équipe engagée est mémorisée pour la prochaine tentative.
func record_defeat(team_ids: Array, battle_stats: Dictionary = {}) -> void:
	meta.bump("ultimates", int(battle_stats.get("ultimates", 0)))
	meta.add_guild_xp(false)
	last_team = team_ids.duplicate()
	save_game()
	state_changed.emit()

## Le tutoriel a été vu : on ne le repropose plus (sauf nouvelle partie).
func mark_tutorial_seen() -> void:
	tutorial_seen = true
	save_game()

# --- Récompenses de la méta-progression -----------------------------------------------------------

## Verse une récompense {eclats_dimensionnels, or_de_guilde}. Retourne false si elle est vide.
func _apply_reward(reward: Dictionary) -> bool:
	if reward.is_empty():
		return false
	add_eclats(int(reward.get("eclats_dimensionnels", 0)))
	add_or(int(reward.get("or_de_guilde", 0)))
	return true

func claim_login() -> Dictionary:
	return _claim(meta.claim_login())

func claim_mission(mission_id: String) -> Dictionary:
	return _claim(meta.claim_mission(mission_id))

func claim_daily_chest() -> Dictionary:
	return _claim(meta.claim_daily_chest())

func claim_achievement(achievement_id: String) -> Dictionary:
	return _claim(meta.claim_achievement(achievement_id))

func claim_collection(milestone: int) -> Dictionary:
	return _claim(meta.claim_collection(inventory.size(), milestone))

func _claim(reward: Dictionary) -> Dictionary:
	if not _apply_reward(reward):
		return {}
	save_game()
	state_changed.emit()
	return reward

# --- Énergie ---------------------------------------------------------------------------------

## Consomme l'énergie d'un combat. Retourne false si la jauge est insuffisante.
func start_combat() -> bool:
	if not stamina.spend_for_combat():
		return false
	save_game()
	state_changed.emit()
	return true
