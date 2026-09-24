extends Control

## Mode histoire : les chapitres dans l'ordre, leur texte, et les combats jouables.
## Un chapitre s'ouvre quand le précédent est bouclé ; à l'intérieur, chaque combat
## s'ouvre quand le précédent est réussi (et reste rejouable ensuite).
## L'écran ne lance rien lui-même : il demande un combat à Main via `encounter_requested`.

signal encounter_requested(encounter: Dictionary)

@onready var _list: VBoxContainer = %List

var _player: PlayerManager

func setup(player: PlayerManager) -> void:
	_player = player
	_player.state_changed.connect(_refresh)
	if is_node_ready():
		_refresh()

func _ready() -> void:
	%Header.text = "MODE HISTOIRE"
	_refresh()

func on_shown() -> void:
	_refresh()

func _refresh() -> void:
	if _player == null or not is_node_ready():
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var chapters := ContentLibrary.chapters()
	var cleared := 0
	for chapter: Dictionary in chapters:
		if _player.is_chapter_cleared(str(chapter.get("id", ""))):
			cleared += 1
	%Subtitle.text = "%d / %d CHAPITRES BOUCLÉS · GUILDE RIVALE : %s" % [cleared, chapters.size(),
		str(DataLoader.load_json(DataLoader.STORY_PATH).get("rival_guild", "")).to_upper()]

	for index in range(chapters.size()):
		_list.add_child(_build_chapter(index, chapters[index]))

func _build_chapter(index: int, chapter: Dictionary) -> Control:
	var chapter_id := str(chapter.get("id", ""))
	var unlocked := _player.is_chapter_unlocked(chapter_id)
	var chapter_cleared := _player.is_chapter_cleared(chapter_id)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel(
		Color(Style.SURFACE, 0.8 if unlocked else 0.45),
		Style.GOLD_DIM if unlocked else Color(Style.GOLD_DIM, 0.35), 3, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "CHAPITRE %d · %s" % [index + 1, str(chapter.get("title", "")).to_upper()]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not unlocked:
		title.add_theme_color_override("font_color", Style.TEXT_MUTED)
	box.add_child(title)

	var status := Label.new()
	status.theme_type_variation = &"Caption"
	status.add_theme_font_size_override("font_size", 15)
	if not unlocked:
		status.text = "VERROUILLÉ — BOUCLE LE CHAPITRE PRÉCÉDENT"
	elif chapter_cleared:
		status.text = "BOUCLÉ — REJOUABLE"
	else:
		status.text = "%d / %d COMBATS" % [_player.battles_cleared(chapter_id), chapter.get("battles", []).size()]
	box.add_child(status)

	if unlocked:
		box.add_child(_narration(str(chapter.get("intro", ""))))
		var battles: Array = chapter.get("battles", [])
		for battle_index in range(battles.size()):
			box.add_child(_build_battle(chapter_id, battle_index, battles[battle_index]))
		if chapter_cleared:
			box.add_child(_narration(str(chapter.get("outro", ""))))
	return panel

## Le texte narratif reste sobre : c'est de la narration en texte simple, pas une mise en scène.
func _narration(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Style.TEXT_MUTED)
	return label

func _build_battle(chapter_id: String, battle_index: int, battle: Dictionary) -> Button:
	var unlocked := _player.is_battle_unlocked(chapter_id, battle_index)
	var done := _player.battles_cleared(chapter_id) > battle_index
	var is_boss: bool = battle.get("boss", false)

	var button := Button.new()
	button.text = "%d. %s%s%s" % [battle_index + 1, str(battle.get("name", "")),
		"   ✦ BOSS" if is_boss else "", "   ✓" if done else ""]
	button.disabled = not unlocked
	button.add_theme_font_size_override("font_size", 17)
	if is_boss and unlocked:
		button.add_theme_stylebox_override("normal", Style.action_button(Color(Style.CRIMSON, 0.55), Style.CRIMSON, 12))
		button.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD, 12))
	button.pressed.connect(func() -> void:
		encounter_requested.emit({
			"kicker": "CHAPITRE %s" % chapter_id.substr(3),
			"title": str(battle.get("name", "")),
			"enemies": battle.get("enemies", []),
			"chapter_id": chapter_id,
			"battle_index": battle_index,
		}))
	return button
