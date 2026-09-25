extends Control

## Quartier général : tout ce qui donne une raison de revenir, rassemblé au même endroit —
## connexion du jour, invocation offerte, missions, niveau de guilde, collection et exploits.
## Aucune de ces récompenses ne s'achète : elles se gagnent en jouant ou en revenant.
## Données : Data/meta.json · logique : MetaProgression.

signal summon_requested

@onready var _list: VBoxContainer = %List

var _player: PlayerManager
## Vrai si l'écran a raté un rafraîchissement pendant qu'il était caché.
var _stale: bool = true

func setup(player: PlayerManager) -> void:
	_player = player
	_player.state_changed.connect(_refresh)
	if is_node_ready():
		_refresh()

func _ready() -> void:
	_refresh()

func on_shown() -> void:
	show()
	# Une session qui commence un nouveau jour doit le voir tout de suite.
	if _player != null:
		_player.refresh_day()
	_refresh()

func _refresh() -> void:
	if _player == null or not is_node_ready():
		return
	# Un écran caché n'a rien à reconstruire : on_shown() le rafraîchira quand il
	# reviendra au premier plan.
	if not visible:
		_stale = true
		return
	_stale = false
	UiUtils.clear_children(_list)

	var meta := _player.meta
	%Subtitle.text = "GUILDE NIVEAU %d · %d GUERRIER(S) SUR %d · SÉRIE DE CONNEXION : %d JOUR(S)" % [
		meta.guild_level, _player.inventory.size(),
		DataLoader.characters_db().get("characters", []).size(), meta.login_streak]

	_list.add_child(_daily_section())
	_list.add_child(_missions_section())
	_list.add_child(_guild_section())
	_list.add_child(_collection_section())
	_list.add_child(_achievements_section())

# --- Briques d'affichage -------------------------------------------------------------------------

func _section(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel(Color(Style.SURFACE, 0.8), Style.GOLD_DIM, 3, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := Label.new()
	heading.theme_type_variation = &"Heading"
	heading.text = title
	box.add_child(heading)
	box.set_meta("panel", panel)
	return box

func _line(text: String, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	if muted:
		label.add_theme_color_override("font_color", Style.TEXT_MUTED)
	return label

func _claim_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", Style.action_button(Style.CRIMSON, Style.GOLD_DIM, 12))
	button.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD, 12))
	button.pressed.connect(callback)
	return button

func _reward_text(reward: Dictionary) -> String:
	return "◈ %d · ⬢ %d" % [int(reward.get("eclats_dimensionnels", 0)), int(reward.get("or_de_guilde", 0))]

func _progress(value: int, target: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.max_value = maxi(target, 1)
	bar.value = value
	return bar

# --- Sections ---------------------------------------------------------------------------------

func _daily_section() -> Control:
	var box := _section("AUJOURD'HUI")
	var meta := _player.meta
	var reward := meta.login_reward()
	if meta.can_claim_login():
		box.add_child(_line("Récompense de connexion, jour %d : %s" % [
			(meta.login_streak % 7) + 1, _reward_text(reward)]))
		box.add_child(_claim_button("RÉCLAMER LA CONNEXION DU JOUR",
			func() -> void: _player.claim_login()))
	else:
		box.add_child(_line("Connexion du jour déjà réclamée. Demain : %s" % _reward_text(reward), true))

	if meta.has_free_summon():
		box.add_child(_line("Une invocation t'est offerte."))
		box.add_child(_claim_button("UTILISER L'INVOCATION OFFERTE",
			func() -> void: summon_requested.emit()))
	else:
		box.add_child(_line("Invocation offerte déjà utilisée aujourd'hui.", true))
	return box.get_meta("panel")

func _missions_section() -> Control:
	var box := _section("MISSIONS DU JOUR")
	for state: Dictionary in _player.meta.mission_states():
		box.add_child(_line("%s — %d / %d%s" % [state["label"], state["progress"], state["target"],
			"  ✓" if state["claimed"] else ""], state["claimed"]))
		box.add_child(_progress(int(state["progress"]), int(state["target"])))
		if state["done"] and not state["claimed"]:
			var mission_id: String = state["id"]
			box.add_child(_claim_button("RÉCLAMER  %s" % _reward_text(state["reward"]),
				func() -> void: _player.claim_mission(mission_id)))
	if _player.meta.can_claim_daily_chest():
		box.add_child(_claim_button("OUVRIR LE COFFRE DU JOUR",
			func() -> void: _player.claim_daily_chest()))
	elif _player.meta.daily_chest_claimed:
		box.add_child(_line("Coffre du jour déjà ouvert.", true))
	return box.get_meta("panel")

func _guild_section() -> Control:
	var box := _section("NIVEAU DE GUILDE")
	var meta := _player.meta
	var needed := meta.guild_xp_to_next()
	box.add_child(_line("Niveau %d%s" % [meta.guild_level,
		"" if needed == 0 else " — %d / %d XP" % [meta.guild_xp, needed]]))
	box.add_child(_progress(meta.guild_xp, maxi(needed, 1)))
	box.add_child(_line("Chaque combat fait monter la guilde, gagné ou perdu. Chaque niveau relève le plafond d'énergie de %d." % [
		int(meta.config.get("guild_levels", {}).get("stamina_per_level", 3))], true))
	return box.get_meta("panel")

func _collection_section() -> Control:
	var box := _section("COLLECTION")
	var owned := _player.inventory.size()
	var total: int = DataLoader.characters_db().get("characters", []).size()
	box.add_child(_line("%d guerriers sur %d (%d%%)" % [owned, total, roundi(100.0 * owned / maxi(total, 1))]))
	box.add_child(_progress(owned, total))
	for state: Dictionary in _player.meta.collection_states(owned):
		if state["claimed"]:
			continue
		if state["claimable"]:
			var milestone: int = state["owned"]
			box.add_child(_claim_button("JALON %d GUERRIERS  ·  %s" % [milestone, _reward_text(state["reward"])],
				func() -> void: _player.claim_collection(milestone)))
		else:
			box.add_child(_line("Jalon %d guerriers : %s" % [state["owned"], _reward_text(state["reward"])], true))
			break # un seul jalon à venir affiché : c'est le prochain objectif, pas une liste de courses
	return box.get_meta("panel")

func _achievements_section() -> Control:
	var box := _section("EXPLOITS")
	for state: Dictionary in _player.meta.achievement_states():
		if state["complete"]:
			box.add_child(_line("%s — tous les paliers  ✓" % state["label"], true))
			continue
		box.add_child(_line("%s (palier %d/%d) — %d / %d" % [state["label"], state["tier"],
			state["tier_count"], state["progress"], state["target"]]))
		box.add_child(_progress(int(state["progress"]), int(state["target"])))
		if state["claimable"]:
			var achievement_id: String = state["id"]
			box.add_child(_claim_button("RÉCLAMER  %s" % _reward_text(state["reward"]),
				func() -> void: _player.claim_achievement(achievement_id)))
	return box.get_meta("panel")
