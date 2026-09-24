extends Control

## Révélation des guerriers invoqués, une carte à la fois, avec un effet par rareté
## (flash coloré + arrivée de la carte) -- voir GDD.md > Phase 2.
## Ne touche ni aux monnaies ni à la sauvegarde : reçoit le résultat déjà appliqué
## par PlayerManager.summon() et se contente de le mettre en scène.

signal closed

const CARD_SCENE := preload("res://Scenes/CharacterCard.tscn")
const REVEAL_CARD_SIZE := Vector2(352, 528)
const SUMMARY_CARD_SIZE := Vector2(148, 222)

## Durée de l'effet d'arrivée, par rareté : plus c'est rare, plus ça dure.
const REVEAL_TIME := {"R": 0.28, "SR": 0.5, "SSR": 0.85}
const FLASH_ALPHA := {"R": 0.14, "SR": 0.3, "SSR": 0.5}

@onready var _flash: ColorRect = %Flash
@onready var _reveal: VBoxContainer = %Reveal
@onready var _counter: Label = %Counter
@onready var _card_host: CenterContainer = %CardHost
@onready var _note: Label = %Note
@onready var _summary: MarginContainer = %Summary
@onready var _grid: GridContainer = %Grid
@onready var _burst: RevealBurst = %Burst

var _results: Array = []
var _index: int = 0
var _busy: bool = false
var _tween: Tween

func _ready() -> void:
	%SkipButton.pressed.connect(_show_summary)
	%CloseButton.pressed.connect(_close)
	hide()

## `results` : sortie de PlayerManager.summon() (character, rarity, is_new, stars, or_bonus).
func start(results: Array) -> void:
	if results.is_empty():
		return
	_results = results
	_index = 0
	_summary.hide()
	_reveal.show()
	%SkipButton.visible = results.size() > 1
	show()
	_reveal_current()

func _reveal_current() -> void:
	var result: Dictionary = _results[_index]
	var rarity := str(result.get("rarity", "R"))
	var color := DataLoader.rarity_color(rarity)

	_counter.text = "%d / %d" % [_index + 1, _results.size()]
	_note.text = _note_for(result)
	_note.add_theme_color_override("font_color", Style.GOLD if not result.get("is_new", false) else color)
	_pop_note(duration_for(str(result.get("rarity", "R"))))

	_clear(_card_host)
	var card: CharacterCard = CARD_SCENE.instantiate()
	card.custom_minimum_size = REVEAL_CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.pivot_offset = REVEAL_CARD_SIZE / 2.0
	_card_host.add_child(card)
	card.display(result.get("character", {}))

	_play_reveal(card, rarity, color)

func _note_for(result: Dictionary) -> String:
	if result.get("is_new", false):
		return "NOUVEAU"
	if int(result.get("or_bonus", 0)) > 0:
		return "Palier max → +%d Or" % int(result["or_bonus"])
	return "Doublon → %d★" % int(result.get("stars", 1))

func duration_for(rarity: String) -> float:
	return float(REVEAL_TIME.get(rarity, 0.3))

## La mention (NOUVEAU / doublon → N★) arrive après la carte, d'un coup, pour qu'on la lise.
func _pop_note(delay: float) -> void:
	_note.modulate.a = 0.0
	_note.pivot_offset = _note.size / 2.0
	_note.scale = Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.tween_interval(delay * 0.7)
	tween.set_parallel(true)
	tween.tween_property(_note, "modulate:a", 1.0, 0.18)
	tween.tween_property(_note, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_reveal(card: Control, rarity: String, color: Color) -> void:
	_busy = true
	var duration: float = REVEAL_TIME.get(rarity, 0.3)

	_flash.color = Color(color, float(FLASH_ALPHA.get(rarity, 0.2)))
	_burst.configure(rarity, color, _index)
	_burst.progress = 0.0
	card.scale = Vector2(0.55, 0.55)
	card.modulate.a = 0.0

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_flash, "color:a", 0.0, duration)
	_tween.tween_property(card, "modulate:a", 1.0, duration * 0.5)
	_tween.tween_property(card, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_burst, "progress", 1.0, duration * 1.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func() -> void: _busy = false)

func _advance() -> void:
	if _busy:
		# Deuxième appui pendant l'animation : on la termine immédiatement.
		if _tween != null and _tween.is_valid():
			_tween.custom_step(10.0)
		_busy = false
		return
	_index += 1
	if _index >= _results.size():
		_show_summary()
		return
	_reveal_current()

func _show_summary() -> void:
	# Un tirage simple n'a rien à récapituler : on ferme directement.
	if _results.size() <= 1:
		_close()
		return
	_busy = false
	_reveal.hide()
	_burst.progress = 0.0
	%SkipButton.hide()
	_flash.color.a = 0.0
	_clear(_grid)
	for result: Dictionary in _results:
		var card: CharacterCard = CARD_SCENE.instantiate()
		card.custom_minimum_size = SUMMARY_CARD_SIZE
		_grid.add_child(card)
		card.display(result.get("character", {}))
	_summary.show()

func _close() -> void:
	hide()
	_burst.progress = 0.0
	_results = []
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if not _reveal.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()

## Vide un conteneur immédiatement : queue_free() seul laisse les enfants dans l'arbre
## jusqu'à la fin de la frame, ce qui fausserait le comptage juste après.
func _clear(host: Node) -> void:
	for child: Node in host.get_children():
		host.remove_child(child)
		child.queue_free()
