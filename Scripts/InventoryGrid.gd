extends Control

## Galerie des guerriers de la guilde, avec filtres par rareté et par élément,
## et fiche détaillée au clic/toucher d'une carte (voir GDD.md > Phase 2).

const CARD_SCENE := preload("res://Scenes/CharacterCard.tscn")
const ALL := "Tous"
const RARITIES: Array[String] = ["SSR", "SR", "R"]
const RARITY_SORT := {"SSR": 0, "SR": 1, "R": 2}
## 3 colonnes sur 720 px de large : hauteur choisie pour rester proche du ratio 2:3 des posters.
const CARD_HEIGHT := 312

@onready var _grid: GridContainer = %Grid
@onready var _header: Label = %Header
@onready var _empty_label: Label = %EmptyLabel
@onready var _detail: Control = %Detail
# Références résolues avant le passage de la fiche dans un CanvasLayer : une fois reparentée,
# elle sort du sous-arbre de la scène et les recherches par nom unique (%) n'y répondent plus.
@onready var _detail_card: CenterContainer = %DetailCard
@onready var _detail_name: Label = %DetailName
@onready var _detail_sub: Label = %DetailSub
@onready var _detail_stars: Label = %DetailStars
@onready var _detail_body: RichTextLabel = %DetailBody

var _player: PlayerManager
var _rarity_filter: String = ALL
var _element_filter: String = ALL

## Appelé par Main juste après l'instanciation (l'écran ne crée jamais son PlayerManager).
func setup(player: PlayerManager) -> void:
	_player = player
	_player.state_changed.connect(_refresh)
	if is_node_ready():
		_refresh()

func _ready() -> void:
	_build_filters(%RarityFilters, [ALL] + RARITIES, _on_rarity_filter)
	_build_filters(%ElementFilters, [ALL] + DataLoader.element_names(), _on_element_filter)
	var close_button: Button = %DetailClose
	close_button.pressed.connect(_detail.hide)
	# Même principe que la révélation : la fiche passe au-dessus de toute l'application.
	remove_child(_detail)
	var overlay := CanvasLayer.new()
	overlay.layer = 9
	add_child(overlay)
	overlay.add_child(_detail)
	_detail.hide()
	_refresh()

func on_shown() -> void:
	_refresh()

func _build_filters(host: HBoxContainer, values: Array, callback: Callable) -> void:
	var group := ButtonGroup.new()
	for value: String in values:
		var button := Button.new()
		button.text = value
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = value == ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 19)
		if value != ALL:
			var color: Color = DataLoader.rarity_color(value) if RARITY_SORT.has(value) else DataLoader.element_color(value)
			button.add_theme_color_override("font_color", color)
			button.add_theme_color_override("font_hover_color", color)
			button.add_theme_color_override("font_pressed_color", color)
		button.pressed.connect(callback.bind(value))
		host.add_child(button)

func _on_rarity_filter(value: String) -> void:
	_rarity_filter = value
	_refresh()

func _on_element_filter(value: String) -> void:
	_element_filter = value
	_refresh()

## Guerriers possédés passant les filtres, triés par rareté puis par nom.
func _filtered_ids() -> Array:
	var ids: Array = []
	for character_id: String in _player.get_owned_character_ids():
		var data := _player.get_character_data(character_id)
		if _rarity_filter != ALL and data.get("rarity", "") != _rarity_filter:
			continue
		if _element_filter != ALL and data.get("element", "") != _element_filter:
			continue
		ids.append(character_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da := _player.get_character_data(a)
		var db := _player.get_character_data(b)
		var ra: int = RARITY_SORT.get(da.get("rarity", "R"), 9)
		var rb: int = RARITY_SORT.get(db.get("rarity", "R"), 9)
		if ra != rb:
			return ra < rb
		return str(da.get("name", "")) < str(db.get("name", "")))
	return ids

func _refresh() -> void:
	if _player == null or not is_node_ready():
		return
	_clear(_grid)
	var ids := _filtered_ids()
	_header.text = "Guilde — %d / %d guerriers" % [ids.size(), _player.inventory.size()]
	_empty_label.visible = ids.is_empty()
	for character_id: String in ids:
		var card: CharacterCard = CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
		_grid.add_child(card)
		card.display(_player.get_character_data(character_id), _player.inventory[character_id], _player.progression.max_stars)
		card.pressed.connect(_show_detail)

func _show_detail(character_id: String) -> void:
	var data := _player.get_character_data(character_id)
	var entry: Dictionary = _player.inventory.get(character_id, {})
	var progression := _player.progression
	var stars: int = int(entry.get("stars", 1))
	var level: int = int(entry.get("level", 1))
	var stats := _player.get_character_stats(character_id)
	var base: Dictionary = data.get("stats", {})
	var element := str(data.get("element", ""))

	_clear(_detail_card)
	var preview: CharacterCard = CARD_SCENE.instantiate()
	preview.custom_minimum_size = Vector2(168, 252)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_card.add_child(preview)
	preview.display(data, entry, progression.max_stars)

	_detail_name.text = str(data.get("name", "???"))
	_detail_name.add_theme_color_override("font_color", DataLoader.rarity_color(str(data.get("rarity", "R"))))
	_detail_sub.text = "%s · %s · %s" % [data.get("rarity", ""), element, data.get("origin", "")]
	_detail_stars.text = CharacterCard.FULL_STAR.repeat(stars) \
		+ CharacterCard.EMPTY_STAR.repeat(maxi(progression.max_stars - stars, 0))
	_detail_stars.add_theme_color_override("font_color", DataLoader.rarity_color("SSR"))

	var xp_needed := progression.xp_to_next_level(level)
	var xp_line := "Niveau max" if xp_needed == 0 else "Niveau %d — %d / %d XP" % [level, int(entry.get("xp", 0)), xp_needed]
	var lines: PackedStringArray = [
		"[b]%s[/b]" % xp_line,
		"",
		"[b]Stats[/b] (base → actuel)",
	]
	for stat: String in ["atk", "def", "vit", "pv"]:
		lines.append("%s : %d → [b]%d[/b]" % [stat.to_upper(), int(base.get(stat, 0)), int(stats.get(stat, 0))])
	var beaten := DataLoader.element_beats(element)
	if beaten != "":
		lines.append("")
		lines.append("[color=#9a95b8]Fort contre %s[/color]" % beaten)
	var skill: Dictionary = data.get("skill", {})
	lines.append("")
	lines.append("[b]%s[/b]" % skill.get("name", "—"))
	lines.append(str(skill.get("description", "")))
	var unlocks := progression.get_unlocks(stars)
	lines.append("")
	lines.append("[b]Paliers de doublons[/b]")
	if unlocks.is_empty():
		lines.append("[color=#9a95b8]Aucun palier de compétence débloqué.[/color]")
	for unlock: String in unlocks:
		lines.append("• %s" % unlock)
	if stars < progression.max_stars:
		lines.append("[color=#9a95b8]Prochain palier : %d★ (+%d%% de stats)[/color]" % [
			stars + 1, roundi(progression.get_star_bonus_pct(stars + 1))])

	_detail_body.text = "\n".join(lines)
	_detail.show()

## Vide un conteneur immédiatement : queue_free() seul laisse les enfants dans l'arbre
## jusqu'à la fin de la frame, ce qui fausserait le comptage juste après.
func _clear(host: Node) -> void:
	for child: Node in host.get_children():
		host.remove_child(child)
		child.queue_free()
