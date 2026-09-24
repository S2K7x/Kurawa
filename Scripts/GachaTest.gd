extends Control

## Scène de validation manuelle du GachaSystem (Phase 1), avant tout visuel poli.
## Un bouton "Tirer" x1 et un bouton x10, un label de résultat, un label de stats cumulées
## pour vérifier à l'oeil que les taux R/SR/SSR annoncés sont respectés dans la durée.

@onready var result_label: Label = $ResultLabel
@onready var stats_label: Label = $StatsLabel
@onready var pull_button: Button = $PullButton
@onready var pull_x10_button: Button = $PullX10Button

var gacha := GachaSystem.new()
var player := PlayerManager.new()

var pull_counts := {"R": 0, "SR": 0, "SSR": 0}

func _ready() -> void:
	add_child(gacha)
	add_child(player)
	pull_button.pressed.connect(_on_pull_pressed)
	pull_x10_button.pressed.connect(_on_pull_x10_pressed)
	_update_stats_label()

func _on_pull_pressed() -> void:
	var result := gacha.single_pull()
	_display_results([result])

func _on_pull_x10_pressed() -> void:
	var results := gacha.multi_pull()
	_display_results(results)

func _display_results(results: Array) -> void:
	var lines: Array = []
	for r in results:
		var character: Dictionary = r.get("character", {})
		var rarity: String = r.get("rarity", "?")
		pull_counts[rarity] = pull_counts.get(rarity, 0) + 1
		player.add_character(character.get("id", ""))
		lines.append("[%s] %s (%s)" % [rarity, character.get("name", "???"), character.get("element", "?")])
	result_label.text = "\n".join(lines)
	_update_stats_label()

func _update_stats_label() -> void:
	var total: int = pull_counts["R"] + pull_counts["SR"] + pull_counts["SSR"]
	if total == 0:
		stats_label.text = "Aucun tirage encore. Éclats : %d" % player.eclats_dimensionnels
		return
	var pct_r := 100.0 * pull_counts["R"] / total
	var pct_sr := 100.0 * pull_counts["SR"] / total
	var pct_ssr := 100.0 * pull_counts["SSR"] / total
	stats_label.text = "Total: %d | R: %d (%.1f%%) | SR: %d (%.1f%%) | SSR: %d (%.1f%%)" % [
		total, pull_counts["R"], pct_r, pull_counts["SR"], pct_sr, pull_counts["SSR"], pct_ssr
	]
