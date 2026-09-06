// Avatars proposés dans « Modifier le profil ».
//
// L'avatar était une URL à coller à la main : personne n'en met, et rien ne
// garantit que le lien pointe sur une image. DiceBear génère l'image à la
// volée depuis une graine, donc une URL stable suffit — aucun fichier à
// héberger, aucun envoi d'image depuis le téléphone.
library;

/// Base de l'API DiceBear. `png` plutôt que `svg` : le reste de l'app affiche
/// les avatars avec CachedNetworkImage, qui ne sait pas rendre du SVG.
const _base = 'https://api.dicebear.com/9.x';

/// URL d'un avatar DiceBear. La taille couvre le plus grand affichage (84 px)
/// en écran haute densité.
String urlAvatarDiceBear(String style, String graine) =>
    '$_base/$style/png?seed=${Uri.encodeComponent(graine)}&size=256';

/// Le choix offert : quatre familles de dessins, quatre variantes chacune.
const _familles = {
  'fun-emoji': ['Aneka', 'Bandit', 'Cuddles', 'Milo'],
  'bottts-neutral': ['Chester', 'Gizmo', 'Nova', 'Pixel'],
  'adventurer': ['Alba', 'Jasper', 'Robin', 'Sasha'],
  'thumbs': ['Coco', 'Loki', 'Mango', 'Ziggy'],
};

/// Les URLs proposées, dans l'ordre d'affichage de la grille.
final avatarsProposes = <String>[
  for (final famille in _familles.entries)
    for (final graine in famille.value)
      urlAvatarDiceBear(famille.key, graine)
];
