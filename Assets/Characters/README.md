# Illustrations des guerriers

Les 20 illustrations actuelles ont été générées par IA (Canva, compte de l'auteur) le
2026-09-25, à partir d'un même gabarit de prompt : « illustration anime full color, style
shonen moderne, cadrage buste-et-taille, visage dans le tiers supérieur, fond sombre,
aura de la couleur de l'élément, éclairage de contre-jour, sans texte ni cadre ». Réutiliser
ce gabarit pour tout nouveau guerrier, sinon la galerie perd son unité.

Un fichier par guerrier, **nommé d'après son identifiant** dans `Data/characters_db.json` :

```
Assets/Characters/kur_001.png   → Renji Kotsu
Assets/Characters/kur_013.png   → Talia Wren
```

Extensions reconnues, dans cet ordre : `.png`, `.webp`, `.jpg`. Un guerrier sans fichier
garde son placeholder (dégradé de son élément + initiales) — les deux cohabitent, le roster
peut donc s'illustrer un personnage à la fois.

Pour ranger une illustration ailleurs, ajouter un champ `art` à la fiche du guerrier :
`"art": "res://Assets/Characters/speciaux/talia_alt.webp"`.

## Format

- **Ratio 2:3** (poster anime), voir GDD.md > Format des cartes. 512×768 suffit ; 1024×1536
  si tu veux tenir sur un écran Retina en plein écran de révélation.
- **Cadrage** : le personnage centré et un peu haut. La carte recadre en « couvrir »
  (`STRETCH_KEEP_ASPECT_COVERED`), et le bas de l'image est masqué par le bandeau de nom
  sur environ 15% de la hauteur — ne rien y mettre d'important.
- En combat, la même image est recadrée en bandeau large : le **visage doit tenir dans le
  tiers supérieur** de l'illustration.
- Fond : sombre ou détouré. Les cartes vivent sur une interface noire ; un fond blanc jure.

## Guerriers en attente d'illustration

- `kur_029` **Naeve Corlis** (Eau, SSR) — prompt de sujet à saisir dans
  `Tools/art_generator.html`, gabarit « Guerrier jouable », aura Eau :
  *« femme calme aux longs cheveux d'argent mouillés, robe de cérémonie bleu nuit,
  mains ouvertes d'où ruisselle un courant, regard apaisé »*

## Après avoir déposé des fichiers

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Godot génère les `.import` qui accompagnent chaque image : **les versionner avec les images**.
