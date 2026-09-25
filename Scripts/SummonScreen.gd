extends Control

## Écran d'invocation : la Brèche, les compteurs de pity et les boutons x1 / x10.
## L'écran ne décide de rien : il demande l'invocation à PlayerManager et confie
## l'affichage du résultat à SummonReveal.

const REVEAL_SCENE := preload("res://Scenes/SummonReveal.tscn")

@onready var _portal: BreachPortal = %Portal
@onready var _message: Label = %Message
@onready var _pull_button: Button = %PullButton
@onready var _pull_x10_button: Button = %PullX10Button

var _player: PlayerManager
var _reveal: Control

## Appelé par Main juste après l'instanciation (l'écran ne crée jamais son PlayerManager).
func setup(player: PlayerManager) -> void:
	_player = player
	_player.state_changed.connect(_refresh)
	if is_node_ready():
		_refresh()

func _ready() -> void:
	%PityPanel.add_theme_stylebox_override("panel", Style.panel(Color(Style.SURFACE, 0.72), Style.GOLD_DIM, 3, 22))
	# Le x10 est l'action principale : cramoisi plein. Le x1 reste sobre.
	_pull_x10_button.add_theme_stylebox_override("normal", Style.action_button(Style.CRIMSON, Style.GOLD_DIM))
	_pull_x10_button.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD))
	_pull_x10_button.add_theme_color_override("font_color", Style.TEXT)

	# CanvasLayer : la révélation passe au-dessus de toute l'application (barre de
	# ressources et navigation comprises) sans dépendre de sa place dans l'arbre.
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	_reveal = REVEAL_SCENE.instantiate()
	overlay.add_child(_reveal)
	_reveal.closed.connect(_refresh)

	_pull_button.pressed.connect(_on_summon.bind(false))
	_pull_x10_button.pressed.connect(_on_summon.bind(true))
	%FreeButton.pressed.connect(_on_free_summon)
	%FreeButton.add_theme_stylebox_override("normal", Style.action_button(Color(Style.CRIMSON, 0.45), Style.GOLD, 12))
	%FreeButton.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD, 12))
	_refresh()

## L'invocation offerte du jour : le rendez-vous quotidien, sans contrepartie.
func _on_free_summon() -> void:
	var results := _player.summon(false, true)
	if results.is_empty():
		_message.text = "L'invocation offerte a déjà été utilisée aujourd'hui."
		return
	_message.text = ""
	_portal.flare()
	_reveal.start(results)
	_refresh()

func on_shown() -> void:
	_message.text = ""
	_refresh()

func _on_summon(multi: bool) -> void:
	var results := _player.summon(multi)
	if results.is_empty():
		_message.text = "Pas assez d'Éclats Dimensionnels."
		return
	_message.text = ""
	_portal.flare()
	_reveal.start(results)
	_refresh()

func _refresh() -> void:
	if _player == null:
		return
	var gacha := _player.gacha
	_pull_button.text = "INVOQUER\n◈ %d" % gacha.get_cost(false)
	_pull_x10_button.text = "INVOQUER ×10\n◈ %d" % gacha.get_cost(true)
	_pull_button.disabled = not _player.can_afford_summon(false)
	_pull_x10_button.disabled = not _player.can_afford_summon(true)

	%SrLabel.text = "SR+ GARANTI DANS %d TIRAGE(S)" % maxi(gacha.pity_sr_threshold - gacha.pulls_since_sr, 0)
	%SrBar.max_value = gacha.pity_sr_threshold
	%SrBar.value = gacha.pulls_since_sr
	%SsrLabel.text = "SSR GARANTI DANS %d TIRAGE(S)" % maxi(gacha.pity_ssr_threshold - gacha.pulls_since_ssr, 0)
	%SsrBar.max_value = gacha.pity_ssr_threshold
	%SsrBar.value = gacha.pulls_since_ssr

	%FreeButton.visible = _player.meta.has_free_summon()
	var featured := _player.get_character_data(gacha.featured_id)
	%Featured.text = "" if featured.is_empty() else \
		"VEDETTE DE LA SEMAINE : %s — %d%% DES SSR" % [str(featured.get("name", "")).to_upper(),
			roundi(gacha.featured_share * 100)]
	%Featured.add_theme_color_override("font_color", Style.GOLD)
