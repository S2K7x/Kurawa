extends Control

## Écran d'accueil : le blason (GuildCrest, dessiné), le nom du jeu en Cinzel, l'état de
## la guilde, et l'entrée en jeu.
## S'affiche au lancement par-dessus la coquille, et sert aussi de point de reprise
## (« recommencer une nouvelle guilde »).

signal entered

@onready var _enter: Button = %EnterButton

var _player: PlayerManager

func setup(player: PlayerManager) -> void:
	_player = player
	_player.state_changed.connect(_refresh)
	if is_node_ready():
		_refresh()

func _ready() -> void:
	%StatusPanel.add_theme_stylebox_override("panel", Style.panel(Color(Style.SURFACE, 0.75), Style.GOLD_DIM, 3, 16))
	_enter.add_theme_stylebox_override("normal", Style.action_button(Style.CRIMSON, Style.GOLD_DIM))
	_enter.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD))
	_enter.pressed.connect(func() -> void: entered.emit())
	%ResetButton.add_theme_stylebox_override("normal", Style.nav_tab(Color(0, 0, 0, 0)))
	%ResetButton.add_theme_color_override("font_color", Style.TEXT_MUTED)
	%ResetButton.pressed.connect(_on_reset)
	_refresh()

func _refresh() -> void:
	if _player == null or not is_node_ready():
		return
	var chapters := ContentLibrary.chapters()
	var cleared := 0
	for chapter: Dictionary in chapters:
		if _player.is_chapter_cleared(str(chapter.get("id", ""))):
			cleared += 1
	var best_level := 0
	for character_id: String in _player.get_owned_character_ids():
		best_level = maxi(best_level, int(_player.inventory[character_id].get("level", 1)))
	%Status.text = "%d guerrier(s) dans la guilde · chapitre %d / %d\nmeilleur niveau : %d" % [
		_player.inventory.size(), cleared, chapters.size(), best_level]

## Repartir de zéro efface la sauvegarde : on demande confirmation par un second appui.
func _on_reset() -> void:
	if %ResetButton.get_meta("armed", false):
		_player.reset_save()
		%ResetButton.set_meta("armed", false)
		%ResetButton.text = "recommencer une nouvelle guilde"
		return
	%ResetButton.set_meta("armed", true)
	%ResetButton.text = "tout effacer ? touche encore pour confirmer"
