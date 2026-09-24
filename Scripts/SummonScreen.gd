extends Control

## Écran d'invocation : état de la Brèche, compteurs de pity et boutons x1 / x10.
## L'écran ne décide de rien : il demande l'invocation à PlayerManager et confie
## l'affichage du résultat à SummonReveal.

const REVEAL_SCENE := preload("res://Scenes/SummonReveal.tscn")

@onready var _portal: Panel = %Portal
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
	_portal.add_theme_stylebox_override("panel", _portal_style())
	_animate_portal()

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
	_refresh()

func on_shown() -> void:
	_message.text = ""
	_refresh()

func _portal_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.29, 0.216, 0.6, 0.55)
	style.set_corner_radius_all(120) # cercle : la Brèche vue de face
	style.set_border_width_all(4)
	style.border_color = Color(0.58, 0.463, 1)
	style.shadow_color = Color(0.482, 0.361, 1, 0.45)
	style.shadow_size = 28
	return style

## Pulsation lente du portail : donne vie à l'écran sans illustration (placeholder Phase 2).
func _animate_portal() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_portal, "scale", Vector2(1.06, 1.06), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_portal, "scale", Vector2.ONE, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_summon(multi: bool) -> void:
	var results := _player.summon(multi)
	if results.is_empty():
		_message.text = "Pas assez d'Éclats Dimensionnels."
		return
	_message.text = ""
	_reveal.start(results)
	_refresh()

func _refresh() -> void:
	if _player == null:
		return
	var gacha := _player.gacha
	_pull_button.text = "Invoquer\n◈ %d" % gacha.get_cost(false)
	_pull_x10_button.text = "Invoquer x10\n◈ %d" % gacha.get_cost(true)
	_pull_button.disabled = not _player.can_afford_summon(false)
	_pull_x10_button.disabled = not _player.can_afford_summon(true)

	%SrLabel.text = "SR+ garanti dans %d tirage(s)" % maxi(gacha.pity_sr_threshold - gacha.pulls_since_sr, 0)
	%SrBar.max_value = gacha.pity_sr_threshold
	%SrBar.value = gacha.pulls_since_sr
	%SsrLabel.text = "SSR garanti dans %d tirage(s)" % maxi(gacha.pity_ssr_threshold - gacha.pulls_since_ssr, 0)
	%SsrBar.max_value = gacha.pity_ssr_threshold
	%SsrBar.value = gacha.pulls_since_ssr
