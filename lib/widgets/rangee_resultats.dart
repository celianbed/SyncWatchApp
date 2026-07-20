// Rangée horizontale d'affiches 2:3 (titre + note) — partagée entre
// l'accueil (tendances, nouveautés) et les fiches (titres similaires).
import 'package:flutter/material.dart';

import '../modeles/modeles.dart';
import '../theme.dart';
import 'affiche_tmdb.dart';

class RangeeResultats extends StatelessWidget {
  final List<ResultatRecherche> resultats;
  final void Function(ResultatRecherche) surOuvrir;

  const RangeeResultats(
      {super.key, required this.resultats, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: resultats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final resultat = resultats[i];
          return GestureDetector(
            onTap: () => surOuvrir(resultat),
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AfficheTmdb(
                      chemin: resultat.affiche, largeur: 110, hauteur: 165),
                  const SizedBox(height: 6),
                  Text(resultat.titre,
                      style: typo.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (resultat.noteMoyenne != null) ...[
                    const SizedBox(height: 2),
                    Text('★ ${resultat.noteMoyenne!.toStringAsFixed(1)}',
                        style: typo.labelSmall
                            ?.copyWith(color: CouleursSW.accentSecondaire)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rangée branchée sur un futur (chargement + erreur discrets).
class CarrouselResultats extends StatelessWidget {
  final Future<List<ResultatRecherche>> resultats;
  final void Function(ResultatRecherche) surOuvrir;

  const CarrouselResultats(
      {super.key, required this.resultats, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return SizedBox(
      height: 208,
      child: FutureBuilder(
        future: resultats,
        builder: (context, instantane) {
          if (instantane.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = instantane.data ?? [];
          if (liste.isEmpty) {
            return Center(
                child: Text('Rien à afficher pour l’instant.',
                    style: typo.bodySmall));
          }
          return RangeeResultats(resultats: liste, surOuvrir: surOuvrir);
        },
      ),
    );
  }
}
