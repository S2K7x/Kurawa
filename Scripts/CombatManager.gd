extends RefCounted
class_name CombatManager

## Combat au tour par tour : l'ordre de passage sort d'une jauge ATB remplie par la Vitesse
## (voir GDD.md > Système de combat), et l'IA adverse est tactique dès le départ.
## Logique pure et déterministe à graine fixée : aucun accès au rendu, aucune écriture disque.
## Règles chiffrées : Data/economy.json > combat · compétences : characters_db.json > skill_glossary.
##
## Boucle d'utilisation :
##   var combat := CombatManager.new(); combat.start(allies, enemies)
##   while not combat.is_over():
##       var actor := combat.begin_turn()          # fait avancer l'ATB, applique brûlures/soins
##       if actor == null: continue                # tour sauté (étourdissement, mort en début de tour)
##       if actor.is_ally: combat.act(actor, "skill", cible)   # choix du joueur
##       else: combat.act_ai(actor)                            # l'IA choisit seule

enum Result { ONGOING, VICTORY, DEFEAT, DRAW }

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
## Journal d'événements, consommé par l'UI de combat (Phase 3) et par les tests.
var events: Array[Dictionary] = []
var turn_count: int = 0
var rng := RandomNumberGenerator.new()

var _atb_threshold: float = 1000.0
var _atb_speed_factor: float = 1.0
var _defense_constant: float = 300.0
var _variance: float = 0.05
var _advantage: float = 1.5
var _disadvantage: float = 0.75
var _max_turns: int = 60
var _crit_chance: float = 0.15
var _crit_multiplier: float = 1.5

func _init() -> void:
	rng.randomize()
	var config: Dictionary = DataLoader.load_json(DataLoader.ECONOMY_PATH).get("combat", {})
	_atb_threshold = float(config.get("atb_threshold", _atb_threshold))
	_atb_speed_factor = float(config.get("atb_speed_factor", _atb_speed_factor))
	_defense_constant = float(config.get("defense_constant", _defense_constant))
	_variance = float(config.get("variance_pct", 5)) / 100.0
	_advantage = float(config.get("element_advantage_multiplier", _advantage))
	_disadvantage = float(config.get("element_disadvantage_multiplier", _disadvantage))
	_max_turns = int(config.get("max_turns", _max_turns))
	_crit_chance = float(config.get("crit_chance", _crit_chance))
	_crit_multiplier = float(config.get("crit_multiplier", _crit_multiplier))

# --- Fabrication des combattants ---------------------------------------------------------------

## Combattant issu d'un guerrier possédé : stats et compétence déjà ajustées par
## le niveau et les étoiles (PlayerManager fait le calcul, pas le combat).
static func from_character(character: Dictionary, stats: Dictionary, skill: Dictionary) -> Combatant:
	var unit := Combatant.new()
	unit.id = str(character.get("id", ""))
	unit.name = str(character.get("name", "???"))
	unit.element = str(character.get("element", ""))
	unit.is_ally = true
	unit.max_hp = maxi(int(stats.get("pv", 1)), 1)
	unit.hp = unit.max_hp
	unit.base_atk = int(stats.get("atk", 0))
	unit.base_def = int(stats.get("def", 0))
	unit.base_vit = int(stats.get("vit", 1))
	unit.skill = skill
	return unit

## Combattant issu de Data/enemies.json, monté au niveau demandé par le contenu.
## La courbe de stats est la même que celle des guerriers (economy.json > progression).
static func from_enemy(enemy_id: String, level: int) -> Combatant:
	var data := DataLoader.enemy(enemy_id)
	var growth := float(DataLoader.load_json(DataLoader.ECONOMY_PATH)
		.get("progression", {}).get("stat_growth_per_level_pct", 5.0))
	var multiplier := 1.0 + (maxi(level, 1) - 1) * growth / 100.0
	var stats: Dictionary = data.get("stats", {})
	var unit := Combatant.new()
	unit.id = enemy_id
	unit.name = str(data.get("name", "???"))
	unit.element = str(data.get("element", ""))
	unit.is_ally = false
	unit.is_boss = data.has("guild")
	unit.max_hp = maxi(roundi(int(stats.get("pv", 1)) * multiplier), 1)
	unit.hp = unit.max_hp
	unit.base_atk = roundi(int(stats.get("atk", 0)) * multiplier)
	unit.base_def = roundi(int(stats.get("def", 0)) * multiplier)
	unit.base_vit = roundi(int(stats.get("vit", 1)) * multiplier)
	unit.skill = data.get("skill", {})
	return unit

# --- Déroulement -------------------------------------------------------------------------------

func start(ally_team: Array[Combatant], enemy_team: Array[Combatant]) -> void:
	allies = ally_team
	enemies = enemy_team
	events.clear()
	turn_count = 0
	for unit: Combatant in allies + enemies:
		unit.atb = 0.0
	_log({"kind": "combat_start", "allies": _names(allies), "enemies": _names(enemies)})

func is_over() -> bool:
	return result() != Result.ONGOING

func result() -> int:
	var allies_alive := _living(allies).size() > 0
	var enemies_alive := _living(enemies).size() > 0
	if allies_alive and enemies_alive:
		return Result.DRAW if turn_count >= _max_turns else Result.ONGOING
	if allies_alive:
		return Result.VICTORY
	if enemies_alive:
		return Result.DEFEAT
	return Result.DRAW

## Fait tourner l'ATB jusqu'au prochain combattant prêt, applique ses effets de début de tour,
## puis le retourne. Retourne null si son tour est consommé (étourdi, ou tué par une brûlure)
## ou si le combat est terminé — l'appelant boucle simplement.
func begin_turn() -> Combatant:
	if is_over():
		return null
	var actor := _advance_atb()
	if actor == null:
		return null
	turn_count += 1
	actor.atb -= _atb_threshold
	if actor.skill_cooldown > 0:
		actor.skill_cooldown -= 1

	_apply_turn_start_effects(actor)
	if not actor.is_alive():
		_log({"kind": "defeated", "actor": actor.name, "cause": "burn"})
		return null
	if actor.is_stunned():
		_log({"kind": "stunned", "actor": actor.name})
		actor.tick_statuses()
		return null
	# Une compétence chargée au tour précédent part d'elle-même, sans nouvel ordre.
	if not actor.pending_skill.is_empty():
		var charged: Dictionary = actor.pending_skill
		actor.pending_skill = {}
		_resolve_skill(actor, charged, null, true)
		actor.tick_statuses()
		return null
	return actor

## Action d'un combattant : "attack", "skill" ou "pass". `target` est ignoré pour les
## compétences qui désignent elles-mêmes leurs cibles (équipe entière, soi-même…).
func act(actor: Combatant, action: String, target: Combatant = null) -> void:
	match action:
		"skill":
			if actor.skill_cooldown > 0 or actor.skill.is_empty():
				_basic_attack(actor, target)
			else:
				_resolve_skill(actor, actor.skill, target, false)
		"pass":
			_log({"kind": "pass", "actor": actor.name})
		_:
			_basic_attack(actor, target)
	actor.tick_statuses()
	_cleanup_dead()

## Tour joué par l'IA : elle lance sa compétence dès qu'elle en tire plus qu'une attaque,
## et vise la cible la plus rentable (voir _choose_target).
func act_ai(actor: Combatant) -> void:
	var opponents := _living(enemies if actor.is_ally else allies)
	if opponents.is_empty():
		_log({"kind": "pass", "actor": actor.name})
		return
	var use_skill := _should_use_skill(actor, opponents)
	var target := _choose_target(actor, opponents)
	act(actor, "skill" if use_skill else "attack", target)

## Résout le combat entier en laissant l'IA jouer les deux camps. Sert aux tests et à
## l'équilibrage (et, plus tard, au bouton « auto » de l'écran de combat).
func auto_resolve() -> int:
	while not is_over():
		var actor := begin_turn()
		if actor == null:
			continue
		act_ai(actor)
	return result()

# --- ATB & début de tour -----------------------------------------------------------------------

## Remplit les jauges jusqu'à ce qu'un combattant atteigne le seuil. En cas d'égalité,
## le plus rapide passe devant.
func _advance_atb() -> Combatant:
	var ready: Array[Combatant] = []
	var guard := 0
	while ready.is_empty():
		guard += 1
		if guard > 10000:
			return null # sécurité : aucune vitesse positive en piste
		for unit: Combatant in _living(allies) + _living(enemies):
			unit.atb += unit.vit() * _atb_speed_factor
			if unit.atb >= _atb_threshold:
				ready.append(unit)
	ready.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if is_equal_approx(a.atb, b.atb):
			return a.vit() > b.vit()
		return a.atb > b.atb)
	return ready[0]

## Brûlures et soins périodiques, résolus avant que le combattant n'agisse.
func _apply_turn_start_effects(actor: Combatant) -> void:
	for status: Dictionary in actor.statuses.duplicate():
		match status.get("type", ""):
			"burn":
				var damage := maxi(roundi(float(status.get("source_atk", actor.base_atk)) * float(status.get("value", 0.0))), 1)
				var dealt := actor.take_damage(damage)
				_log({"kind": "burn", "actor": actor.name, "damage": dealt, "hp": actor.hp})
			"heal_per_turn":
				var healed := actor.heal(roundi(float(status.get("source_atk", actor.base_atk)) * float(status.get("value", 0.0))))
				if healed > 0:
					_log({"kind": "heal", "actor": actor.name, "amount": healed, "hp": actor.hp})

# --- Attaques et compétences -------------------------------------------------------------------

func _basic_attack(actor: Combatant, target: Combatant) -> void:
	var victim := target if target != null and target.is_alive() else _first_living_opponent(actor)
	if victim == null:
		return
	var bonus := actor.status_value("empower")
	var dealt := _strike(actor, victim, 1.0 + bonus, 0.0, {})
	_log({"kind": "attack", "actor": actor.name, "target": victim.name, "damage": dealt, "hp": victim.hp})
	# « Empower » : les prochaines attaques de base propagent aussi leur altération.
	if bonus > 0.0:
		for status: Dictionary in actor.statuses:
			if status.get("type", "") == "empower" and status.get("rider", "") == "burn" and victim.is_alive():
				victim.add_status({"type": "burn", "duration": 2, "value": 0.1, "source_atk": actor.atk()})
	_cleanup_dead()

## Résout une compétence complète : dégâts sur toutes les cibles désignées, puis effets.
## `already_charged` évite qu'une compétence à charge ne se recharge indéfiniment.
func _resolve_skill(actor: Combatant, skill: Dictionary, target: Combatant, already_charged: bool) -> void:
	var effects: Array = skill.get("effects", [])
	if not already_charged and _find_effect(effects, "charge") != null:
		actor.pending_skill = skill
		actor.skill_cooldown = int(skill.get("cooldown", 0))
		_log({"kind": "charge", "actor": actor.name, "skill": skill.get("name", "")})
		return

	var targets := _skill_targets(actor, skill, target)
	var defense_ignore := _effect_value(effects, "defense_ignore")
	var total_damage := 0
	var hits: int = maxi(int(skill.get("hits", 1)), 1)
	var power := float(skill.get("power", 0.0))

	for victim: Combatant in targets:
		if not victim.is_alive():
			continue
		var multiplier := 1.0
		if _find_effect(effects, "bonus_vs_burning") != null and victim.has_status("burn"):
			multiplier += _effect_value(effects, "bonus_vs_burning")
		var wounded: Variant = _find_effect(effects, "bonus_vs_wounded")
		if wounded != null and float(victim.hp) / victim.max_hp <= float(wounded["threshold"]):
			multiplier += float(wounded["value"])
		if power > 0.0:
			for i in range(hits):
				if not victim.is_alive():
					break
				total_damage += _strike(actor, victim, power * multiplier, defense_ignore, skill)

	_log({"kind": "skill", "actor": actor.name, "skill": skill.get("name", ""),
		"targets": _names(targets), "damage": total_damage})
	_apply_skill_effects(actor, skill, targets, total_damage)
	actor.skill_cooldown = int(skill.get("cooldown", 0))
	_cleanup_dead()

## Une frappe : dégâts = power × ATK × atténuation de DEF × multiplicateur élémentaire ± variance.
func _strike(actor: Combatant, victim: Combatant, power: float, defense_ignore: float, _skill: Dictionary) -> int:
	if victim.consume_dodge():
		_log({"kind": "dodge", "actor": victim.name})
		return 0
	var defense := victim.def() * (1.0 - clampf(defense_ignore, 0.0, 0.9))
	var mitigation := _defense_constant / (_defense_constant + defense)
	var raw := actor.atk() * power * mitigation * element_multiplier(actor.element, victim.element)
	raw *= 1.0 - victim.damage_reduction()
	var critical := rng.randf() < _crit_chance
	if critical:
		raw *= _crit_multiplier
	raw *= rng.randf_range(1.0 - _variance, 1.0 + _variance)
	var dealt := victim.take_damage(maxi(roundi(raw), 1))
	if critical:
		_log({"kind": "critical", "actor": actor.name, "target": victim.name, "damage": dealt})
	return dealt

## Cycle Feu > Vent > Foudre > Eau > Feu (characters_db.json > elements.beats).
func element_multiplier(attacker: String, defender: String) -> float:
	if DataLoader.element_beats(attacker) == defender:
		return _advantage
	if DataLoader.element_beats(defender) == attacker:
		return _disadvantage
	return 1.0

func _apply_skill_effects(actor: Combatant, skill: Dictionary, targets: Array[Combatant], damage_dealt: int) -> void:
	var allies_of_actor := _living(allies if actor.is_ally else enemies)
	# Dernier survivant : la compétence tape plus fort (kur_013 > Serment de la Guilde).
	var last_stand := 1.0
	if _find_effect(skill.get("effects", []), "last_stand_bonus") != null and allies_of_actor.size() == 1:
		last_stand += _effect_value(skill.get("effects", []), "last_stand_bonus")

	for effect: Dictionary in skill.get("effects", []):
		var type := str(effect.get("type", ""))
		if type in ["charge", "defense_ignore", "bonus_vs_burning", "bonus_vs_wounded", "last_stand_bonus"]:
			continue # déjà pris en compte au moment des dégâts
		if rng.randf() > float(effect.get("chance", 1.0)):
			continue
		match type:
			"extra_turn":
				actor.atb += _atb_threshold
				_log({"kind": "extra_turn", "actor": actor.name})
			"lifesteal":
				var healed := 0
				for ally: Combatant in allies_of_actor:
					healed += ally.heal(roundi(damage_dealt * float(effect.get("value", 0.0))))
				if healed > 0:
					_log({"kind": "heal", "actor": actor.name, "amount": healed})
			_:
				for unit: Combatant in _effect_targets(actor, effect, targets, allies_of_actor):
					if not unit.is_alive():
						continue
					var status := {
						"type": type,
						"duration": int(effect.get("duration", 1)),
						"value": float(effect.get("value", 0.0)) * last_stand,
						"charges": int(effect.get("charges", 1)),
						"source_atk": actor.atk(),
					}
					if effect.has("rider"):
						status["rider"] = effect["rider"]
					unit.add_status(status)
					_log({"kind": "status", "actor": unit.name, "status": type,
						"duration": status["duration"]})

# --- Ciblage -----------------------------------------------------------------------------------

func _skill_targets(actor: Combatant, skill: Dictionary, chosen: Combatant) -> Array[Combatant]:
	var opponents := _living(enemies if actor.is_ally else allies)
	var team := _living(allies if actor.is_ally else enemies)
	match str(skill.get("target", "enemy_single")):
		"enemy_all":
			return opponents
		"enemy_lowest_hp":
			return [_lowest_hp(opponents)] as Array[Combatant] if not opponents.is_empty() else [] as Array[Combatant]
		"enemy_random_2":
			var pool := opponents.duplicate()
			var picked: Array[Combatant] = []
			while not pool.is_empty() and picked.size() < 2:
				picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
			return picked
		"ally_all":
			return team
		"self":
			return [actor] as Array[Combatant]
		_:
			if chosen != null and chosen.is_alive():
				return [chosen] as Array[Combatant]
			return [opponents[0]] as Array[Combatant] if not opponents.is_empty() else [] as Array[Combatant]

## Sur qui retombe un effet : la cible de la compétence, le lanceur, ou son équipe entière.
func _effect_targets(actor: Combatant, effect: Dictionary, skill_targets: Array[Combatant],
		team: Array[Combatant]) -> Array[Combatant]:
	match str(effect.get("target", "target")):
		"self":
			return [actor] as Array[Combatant]
		"ally_all":
			return team
		"enemy_all":
			return _living(enemies if actor.is_ally else allies)
		_:
			return skill_targets

# --- IA tactique -------------------------------------------------------------------------------

## L'IA garde sa compétence pour les moments où elle rapporte : une zone sur plusieurs cibles,
## ou un coup simple nettement plus fort qu'une attaque de base.
func _should_use_skill(actor: Combatant, opponents: Array[Combatant]) -> bool:
	if actor.skill.is_empty() or actor.skill_cooldown > 0:
		return false
	var target_kind := str(actor.skill.get("target", "enemy_single"))
	if target_kind in ["enemy_all", "enemy_random_2"]:
		return opponents.size() >= 2
	if target_kind in ["ally_all", "self"]:
		return true
	return float(actor.skill.get("power", 0.0)) * int(actor.skill.get("hits", 1)) > 1.2

## Choix de cible : d'abord une victime que ce tour peut achever, sinon l'adversaire où
## l'avantage élémentaire paye le plus, et à égalité le plus dangereux (ATK la plus haute).
func _choose_target(actor: Combatant, opponents: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	var best_score := -INF
	for victim: Combatant in opponents:
		var multiplier := element_multiplier(actor.element, victim.element)
		var estimate := actor.atk() * multiplier * (_defense_constant / (_defense_constant + victim.def()))
		var score := multiplier * 100.0 + victim.atk() * 0.2 - victim.hp * 0.02
		if estimate >= victim.hp:
			score += 1000.0 # une élimination vaut mieux que n'importe quel bonus
		if score > best_score:
			best_score = score
			best = victim
	return best

# --- Utilitaires -------------------------------------------------------------------------------

func _living(team: Array[Combatant]) -> Array[Combatant]:
	var alive: Array[Combatant] = []
	for unit: Combatant in team:
		if unit.is_alive():
			alive.append(unit)
	return alive

func _first_living_opponent(actor: Combatant) -> Combatant:
	var opponents := _living(enemies if actor.is_ally else allies)
	return null if opponents.is_empty() else opponents[0]

func _lowest_hp(team: Array[Combatant]) -> Combatant:
	var weakest: Combatant = team[0]
	for unit: Combatant in team:
		if unit.hp < weakest.hp:
			weakest = unit
	return weakest

func _find_effect(effects: Array, type: String) -> Variant:
	for effect: Dictionary in effects:
		if effect.get("type", "") == type:
			return effect
	return null

func _effect_value(effects: Array, type: String) -> float:
	var effect: Variant = _find_effect(effects, type)
	return 0.0 if effect == null else float(effect.get("value", 0.0))

func _cleanup_dead() -> void:
	for unit: Combatant in allies + enemies:
		if not unit.is_alive() and not unit.get_meta("logged_death", false):
			unit.set_meta("logged_death", true)
			_log({"kind": "defeated", "actor": unit.name})

func _names(units: Array[Combatant]) -> PackedStringArray:
	var list: PackedStringArray = []
	for unit: Combatant in units:
		list.append(unit.name)
	return list

func _log(event: Dictionary) -> void:
	events.append(event)
