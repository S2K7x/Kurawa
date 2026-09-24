extends Control

## Coquille de l'application : blason de guilde, ressources, navigation entre écrans,
## et propriétaire unique du PlayerManager, passé aux écrans via setup().
## Les écrans ne créent jamais leur propre PlayerManager (une seule sauvegarde en jeu).
## Habillage : bandeaux d'encre à liseré or, onglets serif soulignés (Design-Style/).

const SUMMON_SCREEN := preload("res://Scenes/SummonScreen.tscn")
const INVENTORY_SCREEN := preload("res://Scenes/InventoryGrid.tscn")
const STORY_SCREEN := preload("res://Scenes/StoryScreen.tscn")
const DUNGEON_SCREEN := preload("res://Scenes/DungeonScreen.tscn")
const TEAM_SELECT := preload("res://Scenes/TeamSelect.tscn")
const COMBAT_ARENA := preload("res://Scenes/CombatArena.tscn")
const TITLE_SCREEN := preload("res://Scenes/TitleScreen.tscn")
const TUTORIAL := preload("res://Scenes/Tutorial.tscn")

@onready var _screen_host: Control = %ScreenHost
@onready var _summon_nav: Button = %SummonNav
@onready var _guild_nav: Button = %GuildNav
@onready var _story_nav: Button = %StoryNav
@onready var _dungeon_nav: Button = %DungeonNav

var player := PlayerManager.new()

var _screens: Array[Control] = []
var _team_select: Control
var _arena: Control
## Combat demandé par un écran, en attente de la composition d'équipe.
var _pending_encounter: Dictionary = {}
var _title_screen: Control
var _tutorial: Control

func _ready() -> void:
	add_child(player)
	player.state_changed.connect(_refresh_top_bar)
	_style_chrome()

	for scene: PackedScene in [SUMMON_SCREEN, INVENTORY_SCREEN, STORY_SCREEN, DUNGEON_SCREEN]:
		_screens.append(_add_screen(scene))
	_build_combat_overlay()

	var nav_group := ButtonGroup.new()
	var navs: Array[Button] = [_summon_nav, _guild_nav, _story_nav, _dungeon_nav]
	for index in range(navs.size()):
		navs[index].button_group = nav_group
		navs[index].toggle_mode = true
		navs[index].pressed.connect(_show.bind(_screens[index]))

	_show(_screens[0])
	_build_front_overlay()
	%RefreshTimer.timeout.connect(_refresh_top_bar)
	_refresh_top_bar()

## Barres haute et basse : encre presque opaque, filet or côté écran.
func _style_chrome() -> void:
	var top := Style.panel(Color(Style.INK_DEEP, 0.92), Style.GOLD_DIM, 0, 12)
	top.border_width_top = 0
	top.border_width_left = 0
	top.border_width_right = 0
	%TopBar.add_theme_stylebox_override("panel", top)

	var bottom := Style.panel(Color(Style.INK_DEEP, 0.92), Style.GOLD_DIM, 0, 0)
	bottom.content_margin_bottom = 10
	bottom.content_margin_top = 2
	bottom.border_width_bottom = 0
	bottom.border_width_left = 0
	bottom.border_width_right = 0
	%BottomNav.add_theme_stylebox_override("panel", bottom)

	# Blason : fanion cramoisi, écho au blason de guilde des écrans de référence.
	var crest := Style.panel(Style.CRIMSON.darkened(0.35), Style.GOLD, 2, 0)
	%Crest.add_theme_stylebox_override("normal", crest)
	%Crest.add_theme_color_override("font_color", Style.GOLD)

	%EclatsLabel.add_theme_stylebox_override("normal", _pill_style())
	%EclatsLabel.add_theme_color_override("font_color", Color("#c9a6ff"))
	%OrLabel.add_theme_stylebox_override("normal", _pill_style())
	%OrLabel.add_theme_color_override("font_color", Style.GOLD)
	%StaminaLabel.add_theme_stylebox_override("normal", _pill_style())
	%StaminaLabel.add_theme_color_override("font_color", Color("#6fb98f"))

	for nav: Button in [_summon_nav, _guild_nav, _story_nav, _dungeon_nav]:
		nav.add_theme_stylebox_override("normal", Style.nav_tab(Color(0, 0, 0, 0)))
		nav.add_theme_stylebox_override("hover", Style.nav_tab(Color(Style.GOLD, 0.35), 2))
		nav.add_theme_stylebox_override("pressed", Style.nav_tab(Style.CRIMSON_BRIGHT, 3))
		nav.add_theme_color_override("font_color", Style.TEXT_MUTED)
		nav.add_theme_color_override("font_pressed_color", Style.GOLD)
		nav.add_theme_color_override("font_hover_color", Style.TEXT)

func _pill_style() -> StyleBoxFlat:
	var style := Style.panel(Color(Style.SURFACE, 0.8), Color(Style.GOLD_DIM, 0.6), 2, 0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _add_screen(scene: PackedScene) -> Control:
	var screen: Control = scene.instantiate()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_host.add_child(screen)
	screen.setup(player)
	if screen.has_signal("encounter_requested"):
		screen.encounter_requested.connect(_on_encounter_requested)
	screen.hide()
	return screen

## Sélection d'équipe et arène vivent dans un CanvasLayer : un combat prend tout l'écran,
## barre de ressources et navigation comprises.
func _build_combat_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 8
	add_child(overlay)

	_team_select = TEAM_SELECT.instantiate()
	overlay.add_child(_team_select)
	_team_select.setup(player)
	_team_select.hide()
	_team_select.cancelled.connect(func() -> void: _team_select.hide())
	_team_select.confirmed.connect(_on_team_confirmed)

	_arena = COMBAT_ARENA.instantiate()
	overlay.add_child(_arena)
	_arena.setup(player)
	_arena.finished.connect(_on_combat_finished)
	_arena.replay_requested.connect(_on_replay_requested)

## Accueil et tutoriel : au-dessus de tout, y compris d'un combat en cours (il n'y en a
## jamais au lancement, mais l'ordre des calques doit rester sans ambiguïté).
func _build_front_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 12
	add_child(overlay)

	_tutorial = TUTORIAL.instantiate()
	overlay.add_child(_tutorial)
	_tutorial.step_changed.connect(_on_tutorial_step)
	_tutorial.closed.connect(func() -> void: player.mark_tutorial_seen())

	_title_screen = TITLE_SCREEN.instantiate()
	overlay.add_child(_title_screen)
	_title_screen.setup(player)
	_title_screen.entered.connect(_on_entered)

func _on_entered() -> void:
	_title_screen.hide()
	if not player.tutorial_seen:
		_tutorial.start()

## Le tutoriel amène l'onglet dont il parle au premier plan : le texte et l'écran décrit
## restent ainsi sous les yeux en même temps.
func _on_tutorial_step(nav_name: String) -> void:
	if nav_name == "":
		return
	var navs := {"SummonNav": 0, "GuildNav": 1, "StoryNav": 2, "DungeonNav": 3}
	if not navs.has(nav_name):
		return
	var index: int = navs[nav_name]
	var nav: Button = get_node("%" + nav_name)
	nav.button_pressed = true
	_show(_screens[index])

## Un écran a demandé un combat : on passe d'abord par la composition d'équipe.
func _on_encounter_requested(encounter: Dictionary) -> void:
	_pending_encounter = encounter
	_team_select.open(encounter)

func _on_team_confirmed(team_ids: Array) -> void:
	# L'énergie se paie à l'engagement, pas à la victoire (GDD.md > Système d'énergie).
	if not player.start_combat():
		return
	_team_select.hide()
	_arena.begin(_pending_encounter, team_ids)

## Relance du même combat depuis l'écran de fin : l'énergie est repayée comme pour un
## engagement normal, et l'équipe reste celle qui vient de se battre.
func _on_replay_requested(encounter: Dictionary, team_ids: Array) -> void:
	if not player.start_combat():
		_arena._show_result(false, {})
		return
	_arena.begin(encounter, team_ids)

func _on_combat_finished(_victory: bool) -> void:
	_pending_encounter = {}
	for screen: Control in _screen_host.get_children():
		if screen.visible and screen.has_method("on_shown"):
			screen.on_shown()
	_refresh_top_bar()

func _show(screen: Control) -> void:
	for child: Control in _screen_host.get_children():
		child.visible = child == screen
	if screen.has_method("on_shown"):
		screen.on_shown()

func _refresh_top_bar() -> void:
	var stamina := player.stamina
	var current := stamina.get_current()
	%EclatsLabel.text = "◈ %d" % player.eclats_dimensionnels
	%OrLabel.text = "⬢ %d" % player.or_de_guilde
	if current >= stamina.max_stamina:
		%StaminaLabel.text = "⚡ %d/%d" % [current, stamina.max_stamina]
	else:
		var seconds := ceili(stamina.seconds_to_next_point())
		%StaminaLabel.text = "⚡ %d/%d · %d:%02d" % [current, stamina.max_stamina, seconds / 60, seconds % 60]
	# Jauge trop basse pour un combat : la barre le dit avant qu'on ouvre un écran pour rien.
	%StaminaLabel.add_theme_color_override("font_color",
		Color("#6fb98f") if current >= stamina.cost_per_combat else Style.CRIMSON_BRIGHT)
