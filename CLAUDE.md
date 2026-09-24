# Kurawa — Instructions pour Claude Code

Ce fichier donne à Claude Code (dans ce dossier) tout le contexte nécessaire pour travailler sur le projet sans avoir à re-demander les bases à chaque session.

## Le projet en une phrase

**Kurawa** est un jeu gacha mobile-first (Godot 4) où le joueur, Maître de guilde, invoque des guerriers venus d'une brèche dimensionnelle pour construire une équipe et combattre en tour par tour. Univers shonen original (inspiré de l'esprit de One Piece, Hunter x Hunter, Dragon Ball, Demon Slayer, Jujutsu Kaisen, My Hero Academia) — **aucun personnage, nom ou élément sous licence**, tout est inventé.

Le document de design complet (lore, économie, système de combat) est dans `GDD.md`. Le lire avant toute décision de gameplay ou de contenu.

## Direction artistique & narration

- **UI :** menus/écran d'accueil dans une ambiance sombre thématique "guilde/Brèche" ; personnages et VFX de combat restent colorés et vifs — ne pas assombrir les illustrations elles-mêmes
- **Enjeu narratif :** rivalité entre guildes qui se disputent le contrôle de la Brèche (pas de menace cosmique/invasion). Une seule guilde rivale au lancement, **L'Ordre Voracis** (nom modifiable), type "puissance à tout prix"
- **Mode histoire (lancement) :** 3-5 chapitres courts, narration en texte simple entre les combats (pas de dialogues avec portraits pour l'instant), boss nommé de l'Ordre Voracis au dernier chapitre avec récompense spéciale
- **Guilde du joueur :** jeune et modeste (underdog), pas de mentor/PNJ dédié — tutoriel UI seul
- **Difficulté :** courbe qui force le farm des donjons entre les chapitres (pas de progression histoire-only)
- **Starter :** le joueur reçoit un personnage garanti lié à l'histoire dès le début, en plus de ses premiers tirages — voir `characters_db.json`, champ `starter: true`
- **Distinction ennemis :** donjons = mobs génériques sans nom (farm) · boss de fin de chapitre = guerriers **nommés** de la guilde rivale (narratif) — ne pas confondre les deux dans le contenu ou le code
- La Brèche est un phénomène naturel ancien (pas d'origine mystérieuse à coder/écrire pour l'instant)
- Le nom du monde d'origine du joueur n'est pas encore défini — ne pas l'inventer arbitrairement dans le code/contenu sans validation

## Stack technique

- **Moteur :** Godot 4 (GDScript)
- **Cibles d'export :** Mac (.app), Web (HTML5), iOS (Xcode) — l'UI doit fonctionner au clic souris ET au toucher
- **Orientation :** Portrait, mobile-first
- **Style visuel :** illustrations anime full color statiques (pas d'animation de personnage pour le prototype ; placeholders en carrés de couleur jusqu'à la Phase 4)

## Structure du dépôt

```
Kurawa/
├── CLAUDE.md               # ce fichier
├── GDD.md                  # game design document complet
├── project.godot           # config Godot (scène principale : Scenes/Main.tscn)
├── Data/
│   ├── characters_db.json  # catalogue des guerriers + glossaire des compétences
│   ├── economy.json        # équilibrage : coûts, pity, énergie, XP, règles de combat
│   ├── enemies.json        # mobs génériques (donjons) et boss nommés (fins de chapitre)
│   ├── story.json          # 4 chapitres : textes, combats, récompenses de premier passage
│   ├── dungeons.json       # donjons rejouables (Or, XP, élémentaires)
│   └── tutorial.json       # texte du tutoriel de première partie
├── Scripts/
│   ├── DataLoader.gd       # lecture des Data/*.json + couleurs éléments/raretés
│   ├── GachaSystem.gd      # tirage RNG + pity system
│   ├── PlayerManager.gd    # ressources joueur, inventaire, sauvegarde locale
│   ├── StaminaSystem.gd    # jauge d'énergie, recharge automatique, coût par combat
│   ├── ProgressionSystem.gd # niveaux + paliers de doublons par personnage
│   ├── Main.gd             # coquille : barre de ressources + navigation
│   ├── SummonScreen.gd     # écran d'invocation
│   ├── SummonReveal.gd     # révélation des tirages (effets par rareté)
│   ├── InventoryGrid.gd    # galerie + filtres + fiche détaillée
│   ├── CharacterCard.gd    # carte de guerrier réutilisable
│   ├── Style.gd            # palette et fabriques de styles (source unique de l'habillage)
│   ├── SigilBackground.gd  # fond commun : sceau en filigrane + vignette
│   ├── OrnateFrame.gd      # cadre gravé (liseré + équerres d'angle)
│   ├── BreachPortal.gd     # la Brèche dessinée (anneaux runiques + déchirure)
│   ├── RevealBurst.gd      # gerbe de lumière par rareté à la révélation
│   ├── Combatant.gd        # état d'un combattant en piste (PV, ATB, altérations)
│   ├── CombatManager.gd    # combat au tour par tour (ATB Vitesse) + IA tactique
│   ├── ContentLibrary.gd   # accès aux chapitres/donjons + barème de récompenses
│   ├── StoryScreen.gd      # chapitres, textes et combats du mode histoire
│   ├── DungeonScreen.gd    # donjons rejouables
│   ├── TeamSelect.gd       # composition de l'équipe de 3 avant un combat
│   ├── CombatArena.gd      # écran de combat (manuel + auto)
│   ├── CombatUnit.gd       # vignette d'un combattant en combat
│   ├── TitleScreen.gd      # écran d'accueil (état de la guilde, entrée en jeu)
│   └── Tutorial.gd         # tutoriel mécanique de première partie
├── Tests/
│   ├── run_tests.gd        # tests headless (voir « Lancer les tests »)
│   ├── capture_screens.gd  # captures PNG des écrans (voir « Relire l'UI »)
│   └── balance_report.gd   # taux de victoire par combat et par niveau (voir « Équilibrer »)
├── Scenes/
│   ├── Main.tscn           # scène principale (lancée par project.godot)
│   ├── SummonScreen.tscn   # écran d'invocation (Brèche)
│   ├── SummonReveal.tscn   # overlay de révélation (x1 et récap x10)
│   ├── InventoryGrid.tscn  # galerie de guerriers
│   ├── CharacterCard.tscn  # carte réutilisable (révélation, galerie, fiche)
│   ├── StoryScreen.tscn    # mode histoire
│   ├── DungeonScreen.tscn  # donjons rejouables
│   ├── TeamSelect.tscn     # composition d'équipe
│   ├── CombatArena.tscn    # écran de combat
│   ├── CombatUnit.tscn     # vignette de combattant
│   ├── TitleScreen.tscn    # écran d'accueil
│   ├── Tutorial.tscn       # tutoriel de première partie
│   └── GachaTest.tscn      # scène de debug Phase 1 (garde son propre PlayerManager)
└── Assets/
    ├── Characters/         # illustrations des personnages
    ├── UI/
    │   ├── kurawa_theme.tres # thème global (couleurs, polices, variations de type)
    │   └── Fonts/          # Cinzel (titres) + Inter (corps), licences OFL incluses
    └── Audio/              # musiques et SFX

`Design-Style/` (hors dépôt, voir .gitignore) contient les mockups de référence fournis
par l'auteur : ils définissent la direction visuelle décrite ci-dessous.
```

## Roadmap (voir GDD.md pour le détail)

1. **Fondations & algorithmes** — characters_db.json, GachaSystem.gd (taux réels + pity + bonus x10), PlayerManager.gd, StaminaSystem.gd, ProgressionSystem.gd (niveaux + doublons). Validation via une mini-scène Godot (bouton "Tirer" + Label résultat), pas juste des logs console.
2. **Interface visuelle** — SummonScreen, animations/VFX par rareté, InventoryGrid avec filtres.
3. **Combat tactique** — sélection d'équipe (3 persos), CombatManager basé Vitesse **avec IA tactique** (cible intelligemment, exploite les faiblesses élémentaires), StoryMap (chapitres scriptés) + DungeonSelect (farm rejouable), récompenses.
4. **Peaufinage & déploiement** — vraies illustrations, audio, contrôles tactiles + souris, exports Mac/Web/iOS.

**Ne pas sauter à la Phase 2 avant que la Phase 1 soit testée et fonctionnelle** (probabilités de tirage vérifiées, sauvegarde fiable).

**État au 2026-09-24 :** Phases 1, 2 et 3 terminées et couvertes par `Tests/run_tests.gd` (99 vérifications), de l'écran d'accueil au combat gagné avec récompenses, tutoriel de première partie compris. Reste la Phase 4 : illustrations, audio, exports.

## Architecture Phases 1-2

- `GachaSystem`, `StaminaSystem`, `ProgressionSystem` : logique pure (`RefCounted`), sans accès aux monnaies ni au disque
- `PlayerManager` (Node) : possède ces trois systèmes, les monnaies et l'inventaire, et est le **seul** à lire/écrire la sauvegarde (`user://kurawa_save.json`, écriture atomique, sauvegarde illisible mise de côté en `.corrupt`)
- L'énergie se recharge sur l'horloge système (continue quand le jeu est fermé)
- `Main` est le **seul** à instancier `PlayerManager` ; chaque écran le reçoit via `setup(player)` et ne crée jamais le sien (une seule sauvegarde en jeu). Un écran expose `setup()` et, si besoin, `on_shown()`
- Les overlays plein écran (révélation, fiche détaillée) vivent dans un `CanvasLayer` pour passer au-dessus de la barre de ressources et de la navigation. **Attention :** une fois un nœud reparenté dans un `CanvasLayer`, les recherches par nom unique (`%Nom`) ne le trouvent plus — capturer les références en `@onready` avant le reparentage
- Couleurs d'éléments et de raretés : toujours via `DataLoader.element_color()` / `rarity_color()`, jamais en dur dans l'UI

## Langage visuel

Référence : les mockups de `Design-Style/` (écrans de sélection de légende, gabarit de cartes TCG).

- **Palette** — encre noire (`Style.INK`), cramoisi de guilde (`Style.CRIMSON`), liserés et
  titres en or pâle (`Style.GOLD`). Le violet de la première maquette a été abandonné
- **Typographie** — Cinzel (serif à capitales) pour les titres et les noms de guerriers,
  Inter pour le corps. Passer par les variations de type du thème (`Display`, `Heading`,
  `Caption`, `CardName`) plutôt que par des tailles en dur
- **Cadres** — panneaux d'encre à liseré 1px et équerres d'angle (`OrnateFrame`), angles à
  peine arrondis (2-4px). Jamais de gros arrondis ni d'aplats clairs
- **Cartes** — format poster, liseré de la rareté, badges rareté/élément en pastilles
  sombres, bandeau de nom gravé. Illustration = dégradé sombre de l'élément + initiales
  jusqu'à la Phase 4
- **Couleurs** — tout l'habillage passe par `Style.gd` ; les couleurs d'éléments et de
  raretés restent pilotées par `Data/characters_db.json` via `DataLoader`
- Les décors (sceau de fond, Brèche, gerbe de révélation) sont **dessinés en `_draw()`**,
  sans aucune texture à produire — ils s'adaptent à toutes les résolutions

## Lancer les tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://Tests/run_tests.gd
```

Code de sortie 0 si tout passe. Après ajout/renommage d'un `class_name`, lancer d'abord `--headless --path . --import` pour rafraîchir le cache de classes.

Les tests d'UI montent réellement `Main.tscn` dans l'arbre : une erreur runtime dans un écran fait échouer la vérification « les tests d'UI sont allés au bout ».

## Relire l'UI

Captures PNG de tous les écrans (nécessite un vrai rendu, donc **pas** `--headless`) :

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 720x1280 \
  -s res://Tests/capture_screens.gd -- /chemin/de/sortie
```

## Architecture du combat (Phase 3)

- `CombatManager` (RefCounted) est **déterministe à graine fixée** et ne touche ni au rendu ni
  au disque : il expose `begin_turn()` / `act()` / `act_ai()` et un journal d'événements
  (`events`) que l'UI rejoue. `auto_resolve()` déroule le combat entier (tests, équilibrage,
  futur bouton « auto »)
- Une compétence est une **donnée exécutable** : `target`, `power`, `hits`, `cooldown`, `effects`.
  Tout mode de ciblage et tout type d'effet doit figurer au glossaire
  (`characters_db.json > skill_glossary`) — un test échoue sinon
- Les guerriers arrivent au combat avec leurs stats et leur compétence **déjà** ajustées par le
  niveau et les étoiles (`PlayerManager.get_character_stats` / `get_character_skill`)
- Les adversaires montent en niveau sur la même courbe que les guerriers ; c'est le contenu
  (`story.json`, `dungeons.json`) qui fixe leur niveau, jamais `enemies.json`
- **Flux d'un combat :** un écran (Histoire/Donjons) émet `encounter_requested` → `Main` ouvre
  `TeamSelect` → `Main.start_combat()` paie l'énergie → `CombatArena.begin()`. L'arène est le
  seul endroit qui verse les récompenses (`PlayerManager.grant_victory`). Un écran de contenu
  ne lance jamais un combat lui-même
- **Lancement :** `Main` affiche `TitleScreen` par-dessus tout (calque 12) ; « Entrer dans la
  guilde » le referme et déclenche `Tutorial` si `player.tutorial_seen` est faux. Le tutoriel
  bascule lui-même sur l'onglet dont il parle
- `CombatArena.step_delay` cadence l'affichage ; à 0 la boucle se déroule d'un trait
  (c'est ce que font les tests)

## Équilibrer

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://Tests/balance_report.gd
```

Affiche le taux de victoire de chaque combat pour une équipe type à différents niveaux.
Lecture : 0% = mur infranchissable · 40-70% = combat tendu · 100% = trop facile. À relancer
après toute modification de stats, de compétences ou de contenu.

## Conventions de code

- GDScript, typage statique quand possible (`var x: int = 0`)
- Un script = une responsabilité claire (voir les noms de fichiers ci-dessus)
- Les données de contenu (personnages, taux, coûts) vivent dans `Data/*.json`, jamais en dur dans le code
- Commits Git réguliers, un commit par étape logique complétée

## Règles de contenu

- Personnages et noms 100% originaux — ne jamais réutiliser un nom, un pouvoir ou un design identifiable d'un manga existant
- Éléments : Feu > Vent > Foudre > Eau > Feu (cycle de forces/faiblesses)
- Raretés : R (92%) / SR (6.5%) / SSR (1.5%)
- Monnaie premium : Éclats Dimensionnels · Monnaie standard : Or de guilde
- Pas d'équipement séparé en v1 — la puissance vient uniquement du niveau et des doublons
- IA ennemie tactique dès la Phase 3 (pas d'IA purement aléatoire)

## Portée du projet

Projet perso / portfolio, sans intention commerciale immédiate. Conséquence directe sur l'archi : **sauvegarde locale uniquement**, pas de compte/cloud à prévoir pour l'instant. Ne pas complexifier PlayerManager.gd avec de la synchro réseau tant que ce n'est pas demandé.

## Ce qui n'est PAS encore décidé

- Seuil exact du pity system (valeur de départ suggérée dans GDD.md, à ajuster en test)
- Sourcing final des illustrations (IA générative vs commande à un illustrateur) — voir GDD.md
- Plafond et coût exact de la jauge d'énergie (valeur de départ suggérée dans GDD.md, à calibrer en test)
- Détail des paliers de doublons (combien d'étoiles max, bonus exact par palier)
