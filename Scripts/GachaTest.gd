extends Control

## Scène de validation manuelle de la Phase 1, avant tout visuel poli.
## Invocations payées (x1 / x10), pity, inventaire avec niveaux/étoiles, énergie, sauvegarde,
## et une simulation de masse pour vérifier à l'oeil les taux R/SR/SSR annoncés.

const SIMULATION_PULLS := 100_000
const DEBUG_ECLATS := 300
const DEBUG_COMBAT_XP := 50

@onready var resources_label: Label = %ResourcesLabel
@onready var pity_label: Label = %PityLabel
@onready var result_label: RichTextLabel = %ResultLabel
@onready var inventory_label: RichTextLabel = %InventoryLabel
@onready var stats_label: Label = %StatsLabel
@onready var pull_button: Button = %PullButton
@onready var pull_x10_button: Button = %PullX10Button

var player := PlayerManager.new()
var session_counts := {"R": 0, "SR": 0, "SSR": 0}

func _ready() -> void:
	add_child(player)
	player.state_changed.connect(_refresh)
	pull_button.text = "Tirer x1 (%d)" % player.gacha.get_cost(false)
	pull_x10_button.text = "Tirer x10 (%d)" % player.gacha.get_cost(true)
	pull_button.pressed.connect(_on_summon.bind(false))
	pull_x10_button.pressed.connect(_on_summon.bind(true))
	%CombatButton.pressed.connect(_on_combat_pressed)
	%EclatsButton.pressed.connect(_on_eclats_pressed)
	%SimulateButton.pressed.connect(_on_simulate_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	%RefreshTimer.timeout.connect(_refresh_resources)
	_refresh()

func _rarity_color(rarity: String) -> String:
	return str(player.gacha.rarities.get(rarity, {}).get("color", "#ffffff"))

func _on_summon(multi: bool) -> void:
	var results := player.summon(multi)
	if results.is_empty():
		result_label.text = "Pas assez d'Éclats Dimensionnels."
		return
	var lines: PackedStringArray = []
	for r: Dictionary in results:
		var rarity: String = r["rarity"]
		session_counts[rarity] += 1
		var note := "NOUVEAU" if r["is_new"] else "doublon → %d★" % r["stars"]
		if r["or_bonus"] > 0:
			note = "doublon max → +%d Or" % r["or_bonus"]
		lines.append("[color=%s][b][%s][/b] %s[/color] (%s) — %s" % [
			_rarity_color(rarity), rarity, r["character"].get("name", "???"), r["character"].get("element", "?"), note])
	result_label.text = "\n".join(lines)
	_refresh()

func _on_combat_pressed() -> void:
	if not player.start_combat():
		result_label.text = "Pas assez d'énergie pour combattre."
		return
	var level_ups := 0
	for character_id: String in player.get_owned_character_ids():
		level_ups += player.add_character_xp(character_id, DEBUG_COMBAT_XP)
	player.save_game()
	result_label.text = "Combat test : -%d énergie, +%d XP à chaque guerrier (%d niveau(x) gagné(s))." % [
		player.stamina.cost_per_combat, DEBUG_COMBAT_XP, level_ups]
	_refresh()

func _on_eclats_pressed() -> void:
	player.add_eclats(DEBUG_ECLATS)
	player.save_game()
	_refresh()

func _on_reset_pressed() -> void:
	player.reset_save()
	session_counts = {"R": 0, "SR": 0, "SSR": 0}
	result_label.text = "Nouvelle partie : Talia Wren rejoint la guilde."
	_refresh()

## Simulation sur un GachaSystem jetable : n'affecte ni la sauvegarde ni le pity du joueur.
func _on_simulate_pressed() -> void:
	var lines: PackedStringArray = ["Simulation de %d tirages :" % SIMULATION_PULLS]
	for pity_enabled: bool in [false, true]:
		var gacha := GachaSystem.new()
		gacha.pity_enabled = pity_enabled
		var counts := {"R": 0, "SR": 0, "SSR": 0}
		for i in range(SIMULATION_PULLS):
			counts[gacha.single_pull()["rarity"]] += 1
		lines.append("%s : %s" % ["avec pity" if pity_enabled else "sans pity", _format_rates(counts)])
	lines.append("Annoncé : R 92% · SR 6.5% · SSR 1.5%")
	result_label.text = "\n".join(lines)

func _format_rates(counts: Dictionary) -> String:
	var total := 0
	for rarity: String in counts:
		total += counts[rarity]
	if total == 0:
		return "aucun tirage"
	var parts: PackedStringArray = []
	for rarity: String in ["R", "SR", "SSR"]:
		parts.append("%s %.2f%%" % [rarity, 100.0 * counts[rarity] / total])
	return " · ".join(parts)

func _refresh() -> void:
	_refresh_resources()
	pity_label.text = "Pity : %d/%d vers SR · %d/%d vers SSR" % [
		player.gacha.pulls_since_sr, player.gacha.pity_sr_threshold,
		player.gacha.pulls_since_ssr, player.gacha.pity_ssr_threshold]
	stats_label.text = "Session : %d tirage(s) — %s" % [
		session_counts["R"] + session_counts["SR"] + session_counts["SSR"], _format_rates(session_counts)]
	_refresh_inventory()

func _refresh_resources() -> void:
	var stamina := player.stamina
	var current := stamina.get_current()
	var recharge := ""
	if current < stamina.max_stamina:
		var seconds := ceili(stamina.seconds_to_next_point())
		recharge = " (+1 dans %d:%02d)" % [seconds / 60, seconds % 60]
	resources_label.text = "Éclats : %d   ·   Or : %d\nÉnergie : %d/%d%s" % [
		player.eclats_dimensionnels, player.or_de_guilde, current, stamina.max_stamina, recharge]
	pull_button.disabled = not player.can_afford_summon(false)
	pull_x10_button.disabled = not player.can_afford_summon(true)
	%CombatButton.disabled = not stamina.can_afford_combat()

func _refresh_inventory() -> void:
	var ids := player.get_owned_character_ids()
	ids.sort()
	var lines: PackedStringArray = ["[b]Guilde (%d guerriers)[/b]" % ids.size()]
	for character_id: String in ids:
		var data := player.get_character_data(character_id)
		var entry: Dictionary = player.inventory[character_id]
		var stats := player.get_character_stats(character_id)
		lines.append("[color=%s]%s[/color] %s · Niv %d · %d★ · ATK %d · PV %d" % [
			_rarity_color(data["rarity"]), data["name"], data["element"],
			entry["level"], entry["stars"], stats.get("atk", 0), stats.get("pv", 0)])
	inventory_label.text = "\n".join(lines)
