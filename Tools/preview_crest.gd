extends SceneTree

## Rend le blason seul, en grand, dans un PNG — pour juger la marque sans la lire à 88 px
## sur l'écran d'accueil. Exige un vrai rendu, donc **pas** --headless :
##
##   Godot --path . -s res://Tools/preview_crest.gd -- /chemin/crest.png [taille]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "crest_preview.png"
	var side: int = int(args[1]) if args.size() > 1 else 512

	var viewport := SubViewport.new()
	viewport.size = Vector2i(side, side)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Style.INK
	background.size = Vector2(side, side)
	viewport.add_child(background)

	var crest := GuildCrest.new()
	crest.size = Vector2(side, side) * 0.82
	crest.position = Vector2(side, side) * 0.09
	viewport.add_child(crest)

	await process_frame
	await process_frame
	var error := viewport.get_texture().get_image().save_png(out)
	print("blason écrit : %s (%d px, erreur %d)" % [out, side, error])
	quit()
