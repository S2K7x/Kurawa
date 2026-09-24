extends Control

## Coquille de l'application : blason de guilde, ressources, navigation entre écrans,
## et propriétaire unique du PlayerManager, passé aux écrans via setup().
## Les écrans ne créent jamais leur propre PlayerManager (une seule sauvegarde en jeu).
## Habillage : bandeaux d'encre à liseré or, onglets serif soulignés (Design-Style/).

const SUMMON_SCREEN := preload("res://Scenes/SummonScreen.tscn")
const INVENTORY_SCREEN := preload("res://Scenes/InventoryGrid.tscn")

@onready var _screen_host: Control = %ScreenHost
@onready var _summon_nav: Button = %SummonNav
@onready var _guild_nav: Button = %GuildNav

var player := PlayerManager.new()

var _summon_screen: Control
var _inventory_screen: Control

func _ready() -> void:
	add_child(player)
	player.state_changed.connect(_refresh_top_bar)
	_style_chrome()

	_summon_screen = _add_screen(SUMMON_SCREEN)
	_inventory_screen = _add_screen(INVENTORY_SCREEN)

	var nav_group := ButtonGroup.new()
	for nav: Button in [_summon_nav, _guild_nav]:
		nav.button_group = nav_group
		nav.toggle_mode = true
	_summon_nav.pressed.connect(_show.bind(_summon_screen))
	_guild_nav.pressed.connect(_show.bind(_inventory_screen))

	_show(_summon_screen)
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

	for nav: Button in [_summon_nav, _guild_nav]:
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
	screen.hide()
	return screen

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
