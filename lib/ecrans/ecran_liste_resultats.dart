// « Voir tout » — grille 3 colonnes d'affiches 2:3 pour une liste de
// résultats découverte (tendances, nouveautés…).
import 'package:flutter/material.dart';

import '../modeles/modeles.dart';
import '../widgets/affiche_tmdb.dart';
import 'ecran_fiche_film.dart';
import 'ecran_fiche_serie.dart';

class EcranListeResultats extends StatelessWidget {
  final String titre;
  final Future<List<ResultatRecherche>> resultats;

  const EcranListeResultats(
      {super.key, required this.titre, required this.resultats});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: FutureBuilder(
        future: resultats,
        builder: (context, instantane) {
          if (instantane.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = instantane.data ?? [];
          if (liste.isEmpty) {
            return Center(
                child: Text('Rien à afficher.',
                    style: Theme.of(context).textTheme.bodySmall));
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2 / 3, // affiches 2:3, cf. charte
            ),
            itemCount: liste.length,
            itemBuilder: (context, i) {
              final resultat = liste[i];
              return GestureDetector(
                onTap: () => ouvrirFiche(context, resultat),
                child: LayoutBuilder(
                  builder: (_, contraintes) => AfficheTmdb(
                      chemin: resultat.affiche,
                      largeur: contraintes.maxWidth,
                      hauteur: contraintes.maxHeight),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Ouvre la fiche série ou film selon le type du résultat.
Future<void> ouvrirFiche(BuildContext context, ResultatRecherche resultat) {
  final page = resultat.type == 'serie'
      ? EcranFicheSerie(referenceTmdb: resultat.referenceTmdb)
      : EcranFicheFilm(referenceTmdb: resultat.referenceTmdb);
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}
