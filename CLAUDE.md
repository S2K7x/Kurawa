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
├── project.godot            # à créer en Phase 1
├── Data/
│   ├── characters_db.json  # catalogue des guerriers (source de vérité pour le contenu)
│   └── economy.json        # équilibrage : coûts, pity, énergie, courbe d'XP, ressources de départ
├── Scripts/
│   ├── DataLoader.gd       # lecture des Data/*.json
│   ├── GachaSystem.gd      # tirage RNG + pity system
│   ├── PlayerManager.gd    # ressources joueur, inventaire, sauvegarde locale
│   ├── StaminaSystem.gd    # jauge d'énergie, recharge automatique, coût par combat
│   ├── CombatManager.gd    # combat au tour par tour (Vitesse) + IA tactique
│   └── ProgressionSystem.gd # niveaux + paliers de doublons par personnage
├── Tests/
│   └── run_tests.gd        # tests headless Phase 1 (voir « Lancer les tests »)
├── Scenes/
│   ├── GachaTest.tscn      # scène de validation manuelle de la Phase 1
│   ├── SummonScreen.tscn   # écran d'invocation (Brèche)
│   ├── InventoryGrid.tscn  # galerie de guerriers
│   ├── StoryMap.tscn       # carte des chapitres (mode histoire)
│   ├── DungeonSelect.tscn  # sélection de donjons rejouables
│   └── CombatArena.tscn    # écran de combat
└── Assets/
    ├── Characters/         # illustrations des personnages
    ├── UI/                 # éléments d'interface
    └── Audio/              # musiques et SFX
```

## Roadmap (voir GDD.md pour le détail)

1. **Fondations & algorithmes** — characters_db.json, GachaSystem.gd (taux réels + pity + bonus x10), PlayerManager.gd, StaminaSystem.gd, ProgressionSystem.gd (niveaux + doublons). Validation via une mini-scène Godot (bouton "Tirer" + Label résultat), pas juste des logs console.
2. **Interface visuelle** — SummonScreen, animations/VFX par rareté, InventoryGrid avec filtres.
3. **Combat tactique** — sélection d'équipe (3 persos), CombatManager basé Vitesse **avec IA tactique** (cible intelligemment, exploite les faiblesses élémentaires), StoryMap (chapitres scriptés) + DungeonSelect (farm rejouable), récompenses.
4. **Peaufinage & déploiement** — vraies illustrations, audio, contrôles tactiles + souris, exports Mac/Web/iOS.

**Ne pas sauter à la Phase 2 avant que la Phase 1 soit testée et fonctionnelle** (probabilités de tirage vérifiées, sauvegarde fiable).

## Architecture Phase 1

- `GachaSystem`, `StaminaSystem`, `ProgressionSystem` : logique pure (`RefCounted`), sans accès aux monnaies ni au disque
- `PlayerManager` (Node) : possède ces trois systèmes, les monnaies et l'inventaire, et est le **seul** à lire/écrire la sauvegarde (`user://kurawa_save.json`, écriture atomique, sauvegarde illisible mise de côté en `.corrupt`)
- L'énergie se recharge sur l'horloge système (continue quand le jeu est fermé)

## Lancer les tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://Tests/run_tests.gd
```

Code de sortie 0 si tout passe. Après ajout/renommage d'un `class_name`, lancer d'abord `--headless --path . --import` pour rafraîchir le cache de classes.

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
