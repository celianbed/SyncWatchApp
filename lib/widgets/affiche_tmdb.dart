// Affiche / vignette TMDB : les chemins renvoyés par l'API sont des
// `poster_path` relatifs, à préfixer par le CDN d'images TMDB.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

String? urlImageTmdb(String? chemin, {int largeur = 342}) {
  if (chemin == null || chemin.isEmpty) return null;
  if (chemin.startsWith('http')) return chemin;
  return 'https://image.tmdb.org/t/p/w$largeur$chemin';
}

class AfficheTmdb extends StatelessWidget {
  final String? chemin;
  final double largeur;
  final double hauteur;
  final double rayon;
  final int largeurTmdb;

  const AfficheTmdb({
    super.key,
    required this.chemin,
    required this.largeur,
    required this.hauteur,
    this.rayon = 12,
    this.largeurTmdb = 342,
  });

  @override
  Widget build(BuildContext context) {
    final url = urlImageTmdb(chemin, largeur: largeurTmdb);
    final substitut = Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: CouleursSW.surface,
        borderRadius: BorderRadius.circular(rayon),
      ),
      child: Icon(Icons.movie_outlined,
          color: CouleursSW.texteSecondaire.withValues(alpha: .5),
          size: largeur * .3),
    );
    if (url == null) return substitut;
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: CachedNetworkImage(
        imageUrl: url,
        width: largeur,
        height: hauteur,
        fit: BoxFit.cover,
        placeholder: (_, _) => substitut,
        errorWidget: (_, _, _) => substitut,
      ),
    );
  }
}
