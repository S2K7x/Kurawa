# Kurawa — Game Design Document

*Dernière mise à jour : 2026-09-24*

**Nom du jeu :** Kurawa (définitif).

## Concept

**Pitch :** Un shonen d'action épique où tu es à la tête d'une guilde qui recrute des guerriers venus d'une brèche dimensionnelle pour affronter une menace grandissante.

**Ton :** Shonen classique — amitié, dépassement de soi, rivalités, montée en puissance progressive, tournois. Univers coloré et haute énergie, inspiré de l'esprit de One Piece, Hunter x Hunter, Dragon Ball, Demon Slayer, Jujutsu Kaisen et My Hero Academia — aucun personnage ni élément sous licence, tout est original.

**Piliers de gameplay :**
- Invocation de guerriers via la Brèche (le "gacha")
- Collection et progression de personnages à systèmes de pouvoir uniques
- Combat au tour par tour stratégique inspiré de Summoners War
- Gestion de guilde (le joueur comme Maître de guilde)

## Rôle du joueur & lore

Le joueur est **Maître de guilde** : il dirige une guilde qui forme et envoie des combattants invoqués en mission.

**Invocation :** Les guerriers proviennent de la **Brèche** — une déchirure dimensionnelle reliant d'innombrables mondes/époques de combattants. Le Maître de guilde active la Brèche pour en faire émerger des alliés (remplace le tirage "gemmes → carte" classique par un tirage "Brèche → guerrier").

**Enjeu narratif principal :** rivalité entre guildes. Plusieurs guildes se disputent le contrôle de la Brèche pour leurs propres fins (pouvoir, ressources, territoire) — conflit de factions plutôt qu'une menace cosmique ou une invasion. Ça ouvre la porte à des rivaux récurrents, des guildes adverses nommées, et éventuellement un futur mode PvP/comparatif entre guildes.

**Monde d'origine du joueur :** pas encore nommé — à définir une fois le gameplay de base fonctionnel.

**Origine de la Brèche :** un phénomène naturel ancien, pas récent — les guildes ont appris à l'exploiter au fil du temps. Pas de mystère d'origine à résoudre dans l'histoire principale (peut rester un thème d'arrière-plan à explorer plus tard si besoin).

**Guilde rivale de lancement :** **L'Ordre Voracis** (nom proposé, modifiable) — une seule guilde antagoniste pour le premier arc, de type **"puissance à tout prix"**. Elle exploite la Brèche sans précaution pour maximiser sa force, quitte à prendre des risques que la guilde du joueur refuse. Rivalité idéologique claire : ambition/pouvoir sans limite vs approche plus prudente/responsable du joueur.

**Contenu de lancement (mode histoire) :** 3-5 chapitres courts, narrés en texte simple entre les combats (écran "Chapitre X : ..." + quelques lignes de contexte, pas de dialogues mis en scène avec portraits pour l'instant). Le dernier chapitre culmine sur un premier boss nommé de l'Ordre Voracis.

**Récompenses de boss :** chaque boss de fin de chapitre donne une récompense spéciale et notable (Or important, matériau rare, éventuellement garantie de tirage) plutôt qu'une simple variante plus généreuse des récompenses standards.

**Statut de la guilde du joueur :** jeune et modeste — histoire classique d'underdog qui se construit face à l'Ordre Voracis, déjà établi et puissant. Rien à restaurer, tout est à bâtir depuis le début.

**Onboarding :** pas de personnage mentor/conseiller dédié — tutoriel purement mécanique (UI/tooltips), sans PNJ narratif attaché.

**Personnage de départ :** le joueur reçoit un personnage garanti lié à l'histoire, en plus de ses premiers tirages (pas de tirage à l'aveugle pour l'équipe de départ).

**Courbe de difficulté :** chaque chapitre est nettement plus dur que le précédent, ce qui force le farm des donjons entre les chapitres pour progresser — renforce l'utilité du système d'énergie et des donjons rejouables.

## Économie

**Monnaie premium :** Éclats Dimensionnels (fragments extraits de la Brèche).

**Monnaie standard :** Or de guilde (gagné en combat, sert à monter de niveau/équiper les guerriers).

**Taux d'invocation :**
- SSR : 1.5%
- SR : 6.5%
- R : 92%

**Pity system :** garantie d'obtenir au moins un SR/SSR après un certain nombre de tirages consécutifs sans succès. **Calibré :** SR garanti tous les 10 tirages, SSR tous les 85 — mesuré à R 85.5% / SR 12.4% / SSR 2.1% en taux effectifs (le pity gonfle nécessairement les taux au-dessus des taux annoncés).

**Tirage x10 :** avantage par rapport à 10 tirages simples — remise sur le coût total et/ou garantie d'au moins un SR dans le lot, à combiner avec le pity général.

## Personnages

**Style visuel :** illustrations anime full color statiques (carte façon artwork), le plus rapide à produire pour le prototype.

**Format des cartes :** portraits élongués (ratio ~2:3, type poster anime) plutôt que des cartes proches du carré — plus immersif pour l'illustration, structurant pour le layout de l'InventoryGrid et du SummonScreen.

**Raretés :** R / SR / SSR (voir taux dans Économie).

**Éléments :** système classique de forces/faiblesses (Feu > Vent > Foudre > Eau > Feu) pour donner du poids stratégique à la composition d'équipe.

**Fiche personnage type :** Nom, Origine/monde d'où il vient, Élément, Rareté, Stats (ATK/DEF/VIT/PV), Compétence spéciale unique.

Voir `Data/characters_db.json` pour le catalogue de départ (9-12 guerriers).

## Système de combat

Inspiré de Summoners War : tour par tour où l'**ordre de passage** est déterminé par la stat Vitesse de chaque personnage (jauge/ATB), pas un tour figé équipe-par-équipe.

**Équipe :** 3 combattants actifs uniquement (pas de réserve échangeable en combat), sélectionnés dans l'inventaire.

**Actions par tour :** Attaque de base, Compétence spéciale (cooldown), Passer.

**Dégâts :** multiplicateur selon les forces/faiblesses élémentaires.

**Récompense :** Or de guilde à la victoire, réinvesti dans les invocations et l'équipement.

**IA ennemie :** tactique dès le départ (Phase 3 incluse) — vise intelligemment (ex. cible le plus faible ou le plus dangereux) et exploite les faiblesses élémentaires, plutôt qu'une IA purement aléatoire.

## Progression des personnages

**Niveaux + doublons = puissance** (façon Summoners War / Dokkan Battle) :
- XP gagnée en combat fait monter le niveau, augmente les stats brutes
- Un doublon obtenu au tirage renforce le personnage existant (ex. +1 étoile, bonus de stats ou déblocage d'un palier de compétence) au lieu d'être un doublon inutile
- **Pas d'équipement séparé en v1** — toute la puissance vient du niveau + des doublons, ce qui simplifie l'équilibrage du prototype
- **5-6 paliers de doublons** par personnage (façon Dokkan Battle) : bonus de stats à chaque palier, avec déblocage/amélioration de compétence à certains paliers clés (ex. palier 3 : nouvelle variante de la compétence spéciale ; palier 6 : version ultime)

## Structure du contenu PvE

**Les deux :** une histoire courte pour poser l'univers de la Brèche et de la guilde, plus des donjons rejouables pour farmer.

- **Mode histoire :** quelques chapitres scriptés qui introduisent le lore et les premiers rivaux/menaces
- **Donjons :** combats rejouables à l'infini, typés par récompense (donjon XP, donjon Or, donjon par élément plus tard)
- **Ennemis des donjons :** monstres/sbires génériques sans nom, distincts du roster de guerriers invocables — plus rapide à produire en contenu qu'un roster d'ennemis nommés
- **Boss de fin de chapitre (mode histoire) :** guerriers **nommés** de la guilde rivale, distincts des mobs génériques des donjons — c'est là que le lore de rivalité entre guildes se joue en combat
- **Premier donjon/chapitre :** les 4 éléments (Feu/Vent/Foudre/Eau) représentés dès le début pour tester immédiatement le triangle des faiblesses élémentaires

## Système d'énergie

Une jauge d'**énergie/stamina** limite le nombre de combats joués par session, comme dans la plupart des gacha mobiles.

- Recharge **automatique dans le temps** (ex. +1 point toutes les 5-10 minutes, valeur à ajuster en test), plafonnée à un maximum
- Chaque combat (histoire ou donjon) coûte de l'énergie ; les tirages gacha n'en consomment pas (ils utilisent les Éclats Dimensionnels/Or)
- Le plafond et le coût exact par combat restent à calibrer une fois la boucle de jeu testée

## Ambition et portée du projet

**Projet perso / portfolio :** pas d'intention commerciale immédiate. L'objectif est d'avoir un jeu complet et fun à jouer, sans la pression d'une monétisation ou d'un lancement public.

**Conséquences sur les choix techniques :**
- **Sauvegarde locale uniquement** — pas d'architecture compte/cloud prévue pour l'instant, ce qui simplifie PlayerManager.gd
- Pas de pression sur le rythme de sortie de contenu ni sur l'équilibrage économique à des fins de monétisation
- Si le projet évolue plus tard vers quelque chose de publié, ces choix (sauvegarde, énergie, doublons) seront à reconsidérer à ce moment-là

## Direction artistique

**UI (menus, écran d'accueil) :** ambiance sombre thématique "guilde/Brèche" — mais les personnages et effets de combat restent colorés et vifs. Contraste volontaire entre un cadre sombre et des héros éclatants, plutôt qu'une palette uniformément sombre ou uniformément vive.

## Format & plateformes

**Orientation :** Portrait, mobile-first — invocations et gestion de guilde à une main.

**Exports cibles :** Mac (.app), Web (HTML5), iPhone (via Xcode) — l'UI doit réagir au clic souris comme au toucher.

## Sourcing des illustrations

Le développement (Phases 1-3) utilise des placeholders (carrés de couleur par élément/rareté). Les vraies illustrations arrivent en Phase 4. Options envisagées, non tranchées :

1. **Génération IA** (Midjourney / Stable Diffusion) — rapide, itérable, cohérence de style à maintenir via prompts/seeds partagés
2. **Assets libres de droits** (itch.io, packs Unity/Godot) — rapide mais moins original
3. **Illustrateur freelance** (Fiverr/ArtStation) — qualité et originalité maximales, plus lent et coûteux

## Structure de fichiers & roadmap

Voir `CLAUDE.md` pour la structure des dossiers.

**Phase 1 — Fondations & algorithmes :** characters_db.json (9-12 guerriers), GachaSystem.gd (tirage simple/x10, taux réels, pity), PlayerManager.gd (ressources + sauvegarde locale).

**Phase 2 — Interface visuelle :** SummonScreen (invocation depuis la Brèche), animations/VFX par rareté (bleu R, violet SR, doré SSR), InventoryGrid avec filtres par rareté/élément.

**Phase 3 — Combat tactique :** sélection d'équipe (3 persos), CombatManager basé Vitesse, actions (Attaque/Compétence/Passer), multiplicateurs élémentaires, récompenses en Or.

**Phase 4 — Peaufinage & déploiement :** illustrations finales + musique, contrôles tactiles + souris, exports Mac/Web/iOS.

## Prochaines étapes

1. Créer le dossier de projet et initialiser Godot 4 + Git. ✅ (fait — `/Users/shai/Github/Kurawa`)
2. Rédiger le CLAUDE.md du projet à partir de ce document. ✅
3. Générer characters_db.json avec 9-12 guerriers originaux (Phase 1). ✅ (voir `Data/characters_db.json`)
4. Implémenter GachaSystem.gd (taux + pity) et valider les probabilités avant tout visuel. ✅ (vérifié sur 1M tirages, voir `Tests/run_tests.gd`)
5. Concevoir le modèle de doublons (paliers d'étoiles/bonus par personnage) et le brancher sur PlayerManager.gd. ✅ (ProgressionSystem.gd — doublon au-delà de 6★ converti en Or)
6. Ébaucher StaminaSystem.gd (recharge automatique, plafond, coût par combat) en parallèle du GachaSystem. ✅ (recharge aussi hors-jeu)
7. Construire l'interface de la Phase 2 : coquille de navigation, écran d'invocation avec révélation par rareté, galerie filtrable et fiche de guerrier. ✅ (`Scenes/Main.tscn`, placeholders : dégradé de l'élément + initiales jusqu'à la Phase 4)
8. Esquisser les 2-3 premiers chapitres du mode histoire pour poser le ton avant de coder l'IA tactique des donjons.
9. Phase 3 : `CombatManager.gd` (ordre de passage par Vitesse, multiplicateurs élémentaires déjà décrits dans `characters_db.json > elements.beats`, IA tactique).
