extends SceneTree

## Outil de relecture visuelle : monte Main.tscn, capture chaque écran en PNG puis quitte.
## Doit tourner avec un vrai rendu (pas --headless) :
##   godot --path . --resolution 720x1280 -s res://Tests/capture_screens.gd -- <dossier_sortie>

const SAVE_PATH := "user://capture_kurawa_save.json"

var _main: Node
var _frames: int = 0
var _shots: Array[String] = []
var _out_dir: String = "user://captures"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_main = load("res://Scenes/Main.tscn").instantiate()
	_main.player.save_path = SAVE_PATH
	root.add_child(_main)
	_main.player.reset_save()
	_main.player.add_eclats(3000)

func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		20:
			_shot("00_accueil")
			_main._on_entered()
		30:
			_shot("01_tutoriel")
			for i in range(8):
				_main._tutorial._advance()
			_main.get_node("%SummonNav").button_pressed = true
			_main._show(_main.get_node("%ScreenHost").get_child(0))
		40:
			_shot("02_breche")
		50:
			var results: Array = _main.player.summon(true)
			_main.get_node("%ScreenHost").get_child(0)._reveal.start(results)
		200:
			_shot("03_revelation")
		206:
			_main.get_node("%ScreenHost").get_child(0)._reveal._show_summary()
		260:
			_shot("04_recap_x10")
			_main.get_node("%ScreenHost").get_child(0)._reveal._close()
			_main.get_node("%GuildNav").button_pressed = true
			_main._show(_main.get_node("%ScreenHost").get_child(1))
		266:
			_shot("05_guilde")
			var inventory: Node = _main.get_node("%ScreenHost").get_child(1)
			var grid: GridContainer = inventory.get_node("%Grid")
			if grid.get_child_count() > 0:
				inventory._show_detail(grid.get_child(0).character_id)
		272:
			_shot("06_fiche")
		278:
			# Une révélation SSR forcée : c'est l'effet le plus spectaculaire, il doit être relu.
			var ssr: Dictionary = {}
			for character: Dictionary in DataLoader.characters_db().get("characters", []):
				if character.get("rarity") == "SSR":
					ssr = character
					break
			var inventory_screen: Node = _main.get_node("%ScreenHost").get_child(1)
			inventory_screen._detail.hide()
			_main.get_node("%SummonNav").button_pressed = true
			_main._show(_main.get_node("%ScreenHost").get_child(0))
			_main.get_node("%ScreenHost").get_child(0)._reveal.start([
				{"character": ssr, "rarity": "SSR", "is_new": true, "stars": 1, "or_bonus": 0}])
		420:
			_shot("07_ssr")
		430:
			_main._arena._on_continue() if _main._arena.visible else null
			_main._show(_main.get_node("%ScreenHost").get_child(0))
			_main.get_node("%ScreenHost").get_child(0)._reveal._close()
			_main.get_node("%StoryNav").button_pressed = true
			_main._show(_main.get_node("%ScreenHost").get_child(2))
		440:
			_shot("08_histoire")
			_main.get_node("%DungeonNav").button_pressed = true
			_main._show(_main.get_node("%ScreenHost").get_child(3))
		450:
			_shot("09_donjons")
			var chapter: Dictionary = ContentLibrary.chapter("ch_01")
			_main._on_encounter_requested({
				"kicker": "CHAPITRE 1",
				"title": chapter["battles"][0]["name"],
				"enemies": chapter["battles"][0]["enemies"],
				"chapter_id": "ch_01",
				"battle_index": 0,
			})
		460:
			_shot("10_equipe")
			_main._arena.step_delay = 0.25
			_main._on_team_confirmed(_main.player.get_owned_character_ids().slice(0, 3))
		520:
			_shot("11_combat")
			_main._arena.step_delay = 0.02
			_main._arena._on_auto_toggled(true)
		760:
			_shot("12_resultat")
		766:
			print("\n".join(_shots))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			quit(0)
			return true
	return false

func _shot(name: String) -> void:
	var path := "%s/%s.png" % [_out_dir, name]
	var image := root.get_texture().get_image()
	image.save_png(path)
	_shots.append(path)
