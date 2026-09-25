extends RefCounted
class_name MetaProgression

## Boucles d'engagement : connexion quotidienne, invocation offerte, missions du jour,
## exploits, jalons de collection et niveau de guilde (voir Data/meta.json).
## Logique pure : compte, décide de ce qui est réclamable, et dit quoi verser.
## C'est PlayerManager qui verse et qui sauvegarde — comme pour le gacha et l'énergie.

## Compteurs de vie du joueur, tous cumulatifs.
const COUNTERS := ["summons", "victories", "dungeon_clears", "story_clears", "level_ups",
	"stars_gained", "ultimates"]

var config: Dictionary = {}

# --- État sauvegardé ----------------------------------------------------------------------------
var counters: Dictionary = {}
## Jour de la dernière remise à zéro quotidienne, au format AAAA-MM-JJ.
var today: String = ""
var login_streak: int = 0
var login_claimed_today: bool = false
var free_summon_used: bool = false
## Missions du jour : [{"id", "claimed", "start"}] — `start` fige le compteur au tirage
## de la mission, pour que la progression du jour parte de zéro.
var daily_missions: Array = []
var daily_chest_claimed: bool = false
var achievement_tiers_claimed: Dictionary = {}
var collection_claimed: Array = []
var guild_level: int = 1
var guild_xp: int = 0

## Horloge injectable pour les tests (Callable -> String, date locale AAAA-MM-JJ).
var clock: Callable = func() -> String: return Time.get_date_string_from_system()
## Graine du tirage des missions et de la vedette : dérivée de la date, donc stable
## sur la journée et identique d'un lancement à l'autre.
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	config = DataLoader.load_json(DataLoader.META_PATH)
	for counter: String in COUNTERS:
		counters[counter] = 0

# --- Compteurs ----------------------------------------------------------------------------------

func bump(counter: String, amount: int = 1) -> void:
	if not counters.has(counter):
		return
	counters[counter] = int(counters[counter]) + maxi(amount, 0)

func count(counter: String) -> int:
	return int(counters.get(counter, 0))

# --- Jour courant -------------------------------------------------------------------------------

## Bascule sur un nouveau jour si besoin : nouvelles missions, invocation offerte rendue,
## connexion à réclamer. La série ne se casse pas quand un jour est sauté (pardon de série).
func refresh_day() -> bool:
	var current: String = clock.call()
	if current == today:
		return false
	today = current
	login_claimed_today = false
	free_summon_used = false
	daily_chest_claimed = false
	daily_missions = _roll_missions()
	return true

func _day_seed() -> int:
	return hash(today)

func _roll_missions() -> Array:
	var pool: Array = config.get("daily_missions", {}).get("pool", []).duplicate()
	var wanted: int = int(config.get("daily_missions", {}).get("count", 3))
	_rng.seed = _day_seed()
	var picked: Array = []
	while not pool.is_empty() and picked.size() < wanted:
		var mission: Dictionary = pool.pop_at(_rng.randi_range(0, pool.size() - 1))
		picked.append({"id": mission["id"], "claimed": false,
			"start": count(str(mission.get("counter", "")))})
	return picked

# --- Connexion quotidienne ----------------------------------------------------------------------

func login_reward() -> Dictionary:
	var cycle: Array = config.get("daily_login", {}).get("cycle", [])
	if cycle.is_empty():
		return {}
	return cycle[login_streak % cycle.size()]

func can_claim_login() -> bool:
	return not login_claimed_today

## Réclame la connexion du jour et avance la série. Retourne la récompense ({} si déjà prise).
func claim_login() -> Dictionary:
	if not can_claim_login():
		return {}
	var reward := login_reward()
	login_claimed_today = true
	login_streak += 1
	return reward

# --- Invocation offerte -------------------------------------------------------------------------

func has_free_summon() -> bool:
	return not free_summon_used and int(config.get("free_summon", {}).get("per_day", 1)) > 0

func consume_free_summon() -> void:
	free_summon_used = true

# --- Missions du jour ---------------------------------------------------------------------------

func _mission_config(mission_id: String) -> Dictionary:
	for mission: Dictionary in config.get("daily_missions", {}).get("pool", []):
		if mission.get("id", "") == mission_id:
			return mission
	return {}

## État lisible des missions du jour, pour l'écran du quartier général.
func mission_states() -> Array:
	var states: Array = []
	for entry: Dictionary in daily_missions:
		var mission := _mission_config(str(entry.get("id", "")))
		if mission.is_empty():
			continue
		var target: int = int(mission.get("target", 1))
		var progress: int = clampi(count(str(mission.get("counter", ""))) - int(entry.get("start", 0)), 0, target)
		states.append({
			"id": mission["id"], "label": mission.get("label", ""),
			"progress": progress, "target": target,
			"done": progress >= target, "claimed": bool(entry.get("claimed", false)),
			"reward": {"eclats_dimensionnels": int(mission.get("eclats_dimensionnels", 0)),
				"or_de_guilde": int(mission.get("or_de_guilde", 0))},
		})
	return states

## Réclame une mission accomplie. Retourne la récompense ({} si impossible).
func claim_mission(mission_id: String) -> Dictionary:
	for state: Dictionary in mission_states():
		if state["id"] != mission_id or not state["done"] or state["claimed"]:
			continue
		for entry: Dictionary in daily_missions:
			if entry.get("id", "") == mission_id:
				entry["claimed"] = true
		return state["reward"]
	return {}

func can_claim_daily_chest() -> bool:
	if daily_chest_claimed or daily_missions.is_empty():
		return false
	for state: Dictionary in mission_states():
		if not state["claimed"]:
			return false
	return true

func claim_daily_chest() -> Dictionary:
	if not can_claim_daily_chest():
		return {}
	daily_chest_claimed = true
	return config.get("daily_missions", {}).get("chest", {})

# --- Exploits -----------------------------------------------------------------------------------

## Exploits avec leur palier courant : label, progression, et récompense réclamable.
func achievement_states() -> Array:
	var states: Array = []
	for achievement: Dictionary in config.get("achievements", []):
		var achievement_id := str(achievement.get("id", ""))
		var claimed: int = int(achievement_tiers_claimed.get(achievement_id, 0))
		var tiers: Array = achievement.get("tiers", [])
		var done := claimed >= tiers.size()
		var tier: Dictionary = {} if done else tiers[claimed]
		var value := count(str(achievement.get("counter", "")))
		states.append({
			"id": achievement_id, "label": achievement.get("label", ""),
			"tier": claimed + 1, "tier_count": tiers.size(), "complete": done,
			"progress": value, "target": int(tier.get("target", 0)),
			"claimable": not done and value >= int(tier.get("target", 0)),
			"reward": {"eclats_dimensionnels": int(tier.get("eclats_dimensionnels", 0)),
				"or_de_guilde": int(tier.get("or_de_guilde", 0))},
		})
	return states

func claim_achievement(achievement_id: String) -> Dictionary:
	for state: Dictionary in achievement_states():
		if state["id"] == achievement_id and state["claimable"]:
			achievement_tiers_claimed[achievement_id] = int(achievement_tiers_claimed.get(achievement_id, 0)) + 1
			return state["reward"]
	return {}

# --- Collection ---------------------------------------------------------------------------------

## Jalons de collection atteints et non encore réclamés, pour un nombre de guerriers possédés.
func collection_states(owned: int) -> Array:
	var states: Array = []
	for milestone: Dictionary in config.get("collection", {}).get("milestones", []):
		var target: int = int(milestone.get("owned", 0))
		states.append({
			"owned": target, "progress": mini(owned, target),
			"claimed": collection_claimed.has(target),
			"claimable": owned >= target and not collection_claimed.has(target),
			"reward": {"eclats_dimensionnels": int(milestone.get("eclats_dimensionnels", 0)),
				"or_de_guilde": int(milestone.get("or_de_guilde", 0))},
		})
	return states

func claim_collection(owned: int, milestone: int) -> Dictionary:
	for state: Dictionary in collection_states(owned):
		if state["owned"] == milestone and state["claimable"]:
			collection_claimed.append(milestone)
			return state["reward"]
	return {}

# --- Niveau de guilde ---------------------------------------------------------------------------

func guild_xp_to_next() -> int:
	var levels: Dictionary = config.get("guild_levels", {})
	if guild_level >= int(levels.get("max_level", 30)):
		return 0
	return roundi(float(levels.get("xp_base", 200)) * pow(float(levels.get("xp_growth", 1.18)), guild_level - 1))

## Ajoute l'XP de guilde d'un combat. Retourne le nombre de niveaux gagnés.
func add_guild_xp(victory: bool) -> int:
	var levels: Dictionary = config.get("guild_levels", {})
	var gained: int = int(levels.get("xp_per_victory", 40)) if victory else int(levels.get("xp_per_defeat", 12))
	guild_xp += gained
	var gained_levels := 0
	while guild_xp_to_next() > 0 and guild_xp >= guild_xp_to_next():
		guild_xp -= guild_xp_to_next()
		guild_level += 1
		gained_levels += 1
	if guild_xp_to_next() == 0:
		guild_xp = 0
	return gained_levels

## Énergie maximale supplémentaire accordée par le niveau de guilde.
func bonus_stamina() -> int:
	return (guild_level - 1) * int(config.get("guild_levels", {}).get("stamina_per_level", 3))

func level_reward() -> Dictionary:
	return config.get("guild_levels", {}).get("level_reward", {})

# --- Bannière vedette ---------------------------------------------------------------------------

## Guerrier mis en avant cette semaine : choisi parmi les SSR, stable sur toute la rotation.
func featured_character_id(candidates: Array) -> String:
	if candidates.is_empty():
		return ""
	var banner: Dictionary = config.get("featured_banner", {})
	var days: int = int(Time.get_unix_time_from_datetime_string(today + "T00:00:00") / 86400.0) \
		if today != "" else 0
	var period: int = maxi(int(banner.get("rotation_days", 7)), 1)
	return str(candidates[(days / period) % candidates.size()])

func featured_share() -> float:
	return float(config.get("featured_banner", {}).get("featured_share", 0.5))

# --- Sauvegarde ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"counters": counters, "today": today, "login_streak": login_streak,
		"login_claimed_today": login_claimed_today, "free_summon_used": free_summon_used,
		"daily_missions": daily_missions, "daily_chest_claimed": daily_chest_claimed,
		"achievement_tiers_claimed": achievement_tiers_claimed,
		"collection_claimed": collection_claimed,
		"guild_level": guild_level, "guild_xp": guild_xp,
	}

func from_dict(data: Dictionary) -> void:
	for counter: String in COUNTERS:
		counters[counter] = int(data.get("counters", {}).get(counter, 0))
	today = str(data.get("today", ""))
	login_streak = int(data.get("login_streak", 0))
	login_claimed_today = bool(data.get("login_claimed_today", false))
	free_summon_used = bool(data.get("free_summon_used", false))
	daily_missions = data.get("daily_missions", [])
	daily_chest_claimed = bool(data.get("daily_chest_claimed", false))
	achievement_tiers_claimed = {}
	for key: String in data.get("achievement_tiers_claimed", {}):
		achievement_tiers_claimed[key] = int(data["achievement_tiers_claimed"][key])
	collection_claimed = []
	for value: Variant in data.get("collection_claimed", []):
		collection_claimed.append(int(value))
	guild_level = maxi(int(data.get("guild_level", 1)), 1)
	guild_xp = int(data.get("guild_xp", 0))
	refresh_day()
