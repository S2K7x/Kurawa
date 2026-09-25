# Illustrations des adversaires

Même convention que `Assets/Characters/` : **un fichier par identifiant** de
`Data/enemies.json`, extensions reconnues dans l'ordre `.png`, `.webp`, `.jpg`.
Sans fichier, la vignette de combat garde son placeholder (dégradé de l'élément +
initiales) — mobs et boss peuvent donc s'illustrer un par un.

Le chargement passe par `DataLoader.enemy_art()`, qui met en cache y compris les absences.
Ne pas charger une texture d'adversaire ailleurs, sinon le repli sur le placeholder est perdu.

## Deux familles, deux traitements

`CLAUDE.md > Distinction ennemis` les sépare, l'illustration doit le faire aussi :

- **`mob_*` — créatures génériques de la Brèche, sans nom.** Silhouettes, masses,
  anatomies non humaines. Elles se farment en boucle : elles doivent se lire d'un coup
  d'œil et ne jamais voler la vedette au guerrier d'en face.
- **`boss_*` — guerriers NOMMÉS de l'Ordre Voracis.** Visage humain, armure sombre à
  liserés cramoisis, posture dominante. Même soin qu'un guerrier jouable : on doit
  reconnaître un personnage, pas un monstre.

## Format

Identique aux guerriers — **ratio 2:3**, 512×768 suffit. En combat, l'image est recadrée
sur son **tiers supérieur** (`CombatUnit.BUST_RATIO`) : le visage ou la tête de la créature
doit y tenir. Fond sombre ou détouré : l'interface est noire.

## Gabarits de prompt

Générés avec `Tools/art_generator.html` (gabarits « Mob de donjon » et « Boss nommé »).
Garder le même gabarit d'un adversaire à l'autre, sinon le bestiaire perd son unité.

| id | prompt de sujet à saisir |
|---|---|
| `mob_eclat_ardent` | éclat de braise flottant, noyau incandescent fissuré, aucun visage |
| `mob_ressac_spectral` | vague spectrale translucide, silhouette noyée sans traits |
| `mob_arc_crepitant` | arc d'énergie en boucle, décharges continues, forme instable |
| `mob_souffle_lacere` | tourbillon lacéré de lames de vent, corps en lambeaux de brume |
| `mob_colosse_faille` | colosse de pierre humide, fissures ruisselantes, massif et lent |
| `mob_veilleur_brise` | sentinelle mécanique brisée, œil unique grésillant |
| `mob_carcasse_ardente` | carcasse calcinée encore en combustion, côtes ouvertes |
| `boss_vashk_orren` | duelliste arrogant de l'Ordre Voracis, cheveux rasés, gantelets conducteurs |
| `boss_solvire_kaan` | stratège au visage brûlé, manteau lourd, braises aux poings |
| `boss_vehl_draska` | lancier agile au regard méprisant, écharpe fouettée par le vent |

L'aura à choisir dans l'atelier est celle de l'élément indiqué dans `enemies.json`.

## Après avoir déposé des fichiers

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Versionner les `.import` avec les images.
