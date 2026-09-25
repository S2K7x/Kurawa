# Blason de la guilde

Le blason de l'écran d'accueil est **dessiné par le moteur** (`Scripts/GuildCrest.gd`),
comme la Brèche et le sceau de fond : aucune texture à produire, net à toutes les
résolutions, et il tient encore à 48 px (testé).

La marque : un **double chevron d'or** qui tombe vers une **fente cramoisie** — la Brèche —
au centre d'un sceau gradué à quatre losanges cardinaux (les quatre éléments, sans couleur
pour n'en privilégier aucun). Elle est volontairement **différente** de `BreachPortal` :
le portail est un disque runique qui tourne, le blason est une marque héraldique fixe.

Le mot **KURAWA** n'est pas dans le blason : il est composé en Cinzel par l'écran-titre.
C'est délibéré — les générateurs d'images déforment systématiquement le texte, et un
wordmark en vraie typo reste net, traduisible et modifiable.

## Prévisualiser

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  -s res://Tools/preview_crest.gd -- /chemin/crest.png 512
```

Rend le blason seul, hors interface. Exige un vrai rendu, donc **pas** `--headless`.
Passer une petite taille (48) pour vérifier qu'il tient en icône.

## Le remplacer par une illustration générée

Déposer `Assets/UI/crest.png` (ou `.webp` / `.jpg`), carré, fond noir ou détouré, puis
relancer `--headless --path . --import`. `GuildCrest` l'utilise aussitôt à la place du
dessin — les deux cohabitent, exactement comme les illustrations de guerriers et leurs
placeholders.

Prompts à essayer dans `Tools/art_generator.html`, gabarit « Emblème / sceau de guilde »
(résolution 768×768, fond détouré, **aucune lettre**) :

- `double chevron descendant au-dessus d'une fissure verticale, sceau circulaire gradue`
- `blason de guilde de chasseurs, anneau grave, fente de lumiere au centre, quatre losanges cardinaux`
- `sceau dimensionnel, cercle runique fin, dechirure verticale cramoisie, symetrie parfaite`

Pour le blason de la guilde rivale (**L'Ordre Voracis**), garder le sceau circulaire mais
inverser les valeurs : trait cramoisi dominant, or réduit à un filet, motif agressif
(pointes vers l'extérieur plutôt que chevrons vers le centre).
