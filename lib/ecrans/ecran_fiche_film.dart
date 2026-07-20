// Fiche film — affiche, chips genres, notes, marquer vu / à voir, synopsis,
// où regarder, titres similaires.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/affiche_tmdb.dart';
import '../widgets/fiche_extras.dart';
import 'ecran_liste_resultats.dart';

class EcranFicheFilm extends StatefulWidget {
  final int referenceTmdb;
  const EcranFicheFilm({super.key, required this.referenceTmdb});

  @override
  State<EcranFicheFilm> createState() => _EcranFicheFilmState();
}

class _EcranFicheFilmState extends State<EcranFicheFilm> {
  late Future<FilmPublic> _film;
  late Future<PlateformesVisionnage> _plateformes;
  late Future<List<ResultatRecherche>> _similaires;

  @override
  void initState() {
    super.initState();
    _film = _charger();
    _plateformes = _chargerPlateformes();
    _similaires = _chargerSimilaires();
  }

  Future<FilmPublic> _charger() async => FilmPublic.depuisJson(
      await api.get('/films/${widget.referenceTmdb}') as Map<String, dynamic>);

  Future<PlateformesVisionnage> _chargerPlateformes() async =>
      PlateformesVisionnage.depuisJson(
          await api.get('/films/${widget.referenceTmdb}/plateformes')
              as Map<String, dynamic>);

  Future<List<ResultatRecherche>> _chargerSimilaires() async {
    final donnees =
        await api.get('/films/${widget.referenceTmdb}/similaires') as List;
    return [
      for (final r in donnees)
        ResultatRecherche.depuisJson(r as Map<String, dynamic>)
    ];
  }

  Future<void> _marquerVu() async {
    try {
      await api.post('/films/${widget.referenceTmdb}/vu');
      _snack('Film marqué vu ✓');
    } on ExceptionApi catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _aVoir() async {
    try {
      await api.post('/films/${widget.referenceTmdb}/suivre',
          corps: const {'statut': 'a_voir'});
      _snack('Ajouté à ta liste « À voir »');
    } on ExceptionApi catch (e) {
      _snack(e.code == 409 ? 'Déjà dans ta liste.' : e.message);
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder(
        future: _film,
        builder: (context, instantane) {
          if (instantane.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (instantane.hasError) {
            return Center(
                child: Text('${instantane.error}', style: typo.bodySmall));
          }
          final film = instantane.data!;
          final morceaux = <String>[
            if (film.dateSortie != null) '${film.dateSortie!.year}',
            if (film.duree != null) formatDuree(film.duree!),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AfficheTmdb(chemin: film.affiche, largeur: 120, hauteur: 180),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(film.titre, style: typo.titleLarge),
                        const SizedBox(height: 8),
                        Text(morceaux.join(' · '), style: typo.bodySmall),
                        const SizedBox(height: 10),
                        ChipsGenres(genres: film.genres),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              BlocNoterFiche(
                  idFilm: film.idFilm, noteTmdb: film.noteMoyenneTmdb),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                  onPressed: _marquerVu,
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('Marquer vu')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _aVoir,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CouleursSW.accent,
                  side: const BorderSide(color: CouleursSW.accent),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                label: const Text('À voir plus tard'),
              ),
              if (film.synopsis != null && film.synopsis!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(film.synopsis!,
                    style: typo.bodySmall?.copyWith(height: 1.5)),
              ],
              SectionOuRegarder(plateformes: _plateformes),
              SectionSimilaires(
                  resultats: _similaires,
                  surOuvrir: (r) => ouvrirFiche(context, r)),
            ],
          );
        },
      ),
    );
  }
}
