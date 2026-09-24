extends Control

## Coquille de l'application (Phase 2) : barre de ressources, navigation entre écrans,
## et propriétaire unique du PlayerManager, passé aux écrans via setup().
## Les écrans ne créent jamais leur propre PlayerManager (une seule sauvegarde en jeu).

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
		%StaminaLabel.text = "⚡ %d/%d (%d:%02d)" % [current, stamina.max_stamina, seconds / 60, seconds % 60]
