extends Control

## Donjons rejouables : le farm entre deux chapitres (Or, XP, et un donjon par élément
## pour travailler le triangle des forces). Tout est ouvert dès le départ : c'est le niveau
## des paliers qui fait barrage, pas un verrou de progression.

signal encounter_requested(encounter: Dictionary)

@onready var _list: VBoxContainer = %List

var _player: PlayerManager

func setup(player: PlayerManager) -> void:
	_player = player
	_player.state_changed.connect(_refresh)
	if is_node_ready():
		_refresh()

func _ready() -> void:
	%Header.text = "DONJONS"
	%Subtitle.text = "REJOUABLES À VOLONTÉ · CHAQUE TENTATIVE COÛTE DE L'ÉNERGIE"
	_refresh()

func on_shown() -> void:
	_refresh()

func _refresh() -> void:
	if _player == null or not is_node_ready():
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for dungeon: Dictionary in ContentLibrary.dungeons():
		_list.add_child(_build_dungeon(dungeon))

func _build_dungeon(dungeon: Dictionary) -> Control:
	var element := str(dungeon.get("element", ""))
	var accent := DataLoader.element_color(element) if element != "" else Style.GOLD_DIM

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel(Color(Style.SURFACE, 0.8), Color(accent, 0.7), 3, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = str(dungeon.get("name", "")).to_upper()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if element != "":
		title.add_theme_color_override("font_color", accent)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.theme_type_variation = &"Caption"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.text = "%s  ·  OR ×%.1f · XP ×%.1f" % [str(dungeon.get("description", "")),
		float(dungeon.get("or_multiplier", 1.0)), float(dungeon.get("xp_multiplier", 1.0))]
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)

	var tiers: Array = dungeon.get("tiers", [])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for tier_index in range(tiers.size()):
		row.add_child(_build_tier(dungeon, tier_index, tiers[tier_index]))
	return panel

func _build_tier(dungeon: Dictionary, tier_index: int, tier: Dictionary) -> Button:
	var dungeon_id := str(dungeon.get("id", ""))
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.text = "NIV %d\n%d ennemis" % [int(tier.get("level", 1)), tier.get("enemies", []).size()]
	button.pressed.connect(func() -> void:
		encounter_requested.emit({
			"kicker": "DONJON",
			"title": "%s — niveau %d" % [dungeon.get("name", ""), int(tier.get("level", 1))],
			"enemies": ContentLibrary.dungeon_encounter(dungeon_id, tier_index),
			"or_multiplier": float(dungeon.get("or_multiplier", 1.0)),
			"xp_multiplier": float(dungeon.get("xp_multiplier", 1.0)),
		}))
	return button
