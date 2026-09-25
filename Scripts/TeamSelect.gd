extends Control

## Sélection des 3 guerriers envoyés au combat (voir GDD.md > Système de combat).
## Affiche aussi qui attend en face et ce que coûte l'engagement en énergie, pour que le
## choix se fasse en connaissance de cause.

signal confirmed(team_ids: Array)
signal cancelled

const CARD_SCENE := preload("res://Scenes/CharacterCard.tscn")

@onready var _grid: GridContainer = %Grid
@onready var _launch: Button = %LaunchButton

var _player: PlayerManager
var _encounter: Dictionary = {}
var _team: Array = []
var _team_size: int = 3

func setup(player: PlayerManager) -> void:
	_player = player
	_team_size = int(DataLoader.economy().get("combat", {}).get("team_size", 3))

func _ready() -> void:
	%EnemyPanel.add_theme_stylebox_override("panel", Style.crimson_panel(14))
	_launch.add_theme_stylebox_override("normal", Style.action_button(Style.CRIMSON, Style.GOLD_DIM))
	_launch.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD))
	%BackButton.pressed.connect(func() -> void: cancelled.emit())
	_launch.pressed.connect(_on_launch)

## `encounter` : {"title", "enemies": [{"id", "level"}], ...} — voir Main._on_encounter_requested.
func open(encounter: Dictionary) -> void:
	_encounter = encounter
	%Title.text = str(encounter.get("title", "COMBAT")).to_upper()
	%Kicker.text = str(encounter.get("kicker", "PRÉPARATION")).to_upper()

	var lines: PackedStringArray = []
	for entry: Dictionary in encounter.get("enemies", []):
		var data := DataLoader.enemy(str(entry.get("id", "")))
		lines.append("%s · %s · Niv %d" % [data.get("name", "?"), data.get("element", "?"), int(entry.get("level", 1))])
	%EnemyList.text = "\n".join(lines)

	# On repropose la dernière équipe envoyée, filtrée de ce qui n'est plus possédé.
	_team = []
	for character_id: String in _player.last_team:
		if _player.inventory.has(character_id) and _team.size() < _team_size:
			_team.append(character_id)
	_build_grid()
	_refresh()
	show()

func _build_grid() -> void:
	UiUtils.clear_children(_grid)
	var ids: Array = _player.get_owned_character_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(_player.inventory[a]["level"]) > int(_player.inventory[b]["level"]))
	for character_id: String in ids:
		var card: CharacterCard = CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(0, 248)
		_grid.add_child(card)
		card.display(_player.get_character_data(character_id), _player.inventory[character_id],
			_player.progression.max_stars)
		card.pressed.connect(_toggle)

func _toggle(character_id: String) -> void:
	if _team.has(character_id):
		_team.erase(character_id)
	elif _team.size() < _team_size:
		_team.append(character_id)
	_refresh()

func _refresh() -> void:
	var cost := _player.stamina.cost_per_combat
	var enough_energy := _player.stamina.get_current() >= cost
	%SelectionLabel.text = "%d / %d GUERRIERS — %s" % [_team.size(), _team_size,
		", ".join(_team.map(func(id: String) -> String: return str(_player.get_character_data(id).get("name", "?"))))
			if not _team.is_empty() else "touche une carte pour l'engager"]
	%CostLabel.text = "COÛT : %d ÉNERGIE (%d disponible)" % [cost, _player.stamina.get_current()]
	%CostLabel.add_theme_color_override("font_color", Style.TEXT_MUTED if enough_energy else Style.CRIMSON_BRIGHT)
	_launch.disabled = _team.is_empty() or not enough_energy

	# Les cartes engagées se démarquent ; les autres reculent d'un cran.
	for card: CharacterCard in _grid.get_children():
		card.modulate = Color.WHITE if _team.has(card.character_id) else Color(1, 1, 1, 0.45)

func _on_launch() -> void:
	confirmed.emit(_team.duplicate())
