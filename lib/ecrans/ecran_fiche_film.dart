// Fiche film — affiche, chips genres, notes, marquer vu / à voir, synopsis,
// où regarder, titres similaires.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/affiche_tmdb.dart';
import '../widgets/avis_abonnements.dart';
import '../widgets/feuille_recommander.dart';
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
  bool _dejaVu = false; // état calculé côté API (présence dans visionner_film)
  int _nbVus = 0;
  bool _aVoirActif = false; // le film est-il en attente dans « À voir » ?
  bool _bascule = false; // évite un double envoi si on tape deux fois vite

  @override
  void initState() {
    super.initState();
    _film = _charger();
    _plateformes = _chargerPlateformes();
    _similaires = _chargerSimilaires();
    _chargerEtatVu();
  }

  Future<void> _chargerEtatVu() async {
    try {
      final etat = await api.get('/films/${widget.referenceTmdb}/vu')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _dejaVu = etat['deja_vu'] as bool;
        _nbVus = etat['nombre_visionnages'] as int;
        _aVoirActif = etat['dans_a_voir'] as bool? ?? false;
      });
    } catch (_) {
      // silencieux : on garde l'état par défaut (non vu)
    }
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
    final avantVu = _dejaVu, avantNb = _nbVus;
    // optimiste : le bouton passe à « Vu » immédiatement
    setState(() {
      _dejaVu = true;
      _nbVus = _nbVus + 1;
    });
    try {
      final res = await api.post('/films/${widget.referenceTmdb}/vu')
          as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _nbVus = res['nombre_visionnages'] as int;
          _aVoirActif = false; // l'API bascule le statut : ce n'est plus « à voir »
        });
      }
      _snack(_nbVus > 1 ? 'Revu ✓ ($_nbVus fois)' : 'Film marqué vu ✓');
    } on ExceptionApi catch (e) {
      if (mounted) {
        setState(() {
          _dejaVu = avantVu;
          _nbVus = avantNb;
        });
      }
      _snack(e.message);
    }
  }

  /// Ajoute ou retire le film de la liste « À voir ». Un ajout par mégarde doit
  /// pouvoir se défaire : le même bouton fait les deux, selon son état.
  Future<void> _basculerAVoir() async {
    if (_bascule) return;
    final avant = _aVoirActif;
    setState(() {
      _bascule = true;
      _aVoirActif = !avant; // optimiste : le bouton change tout de suite
    });
    try {
      if (avant) {
        await api.delete('/films/${widget.referenceTmdb}/suivre');
        _snack('Retiré de ta liste');
      } else {
        await api.post('/films/${widget.referenceTmdb}/suivre',
            corps: const {'statut': 'a_voir'});
        _snack('Ajouté à ta liste « À voir »');
      }
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => _aVoirActif = avant);
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _bascule = false);
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
      appBar: AppBar(actions: [
        IconButton(
          icon: const Icon(Icons.send_outlined),
          tooltip: 'Recommander à un ami',
          onPressed: () => ouvrirRecommander(context,
              referenceTmdb: widget.referenceTmdb, type: 'film'),
        ),
      ]),
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
              _dejaVu
                  ? ElevatedButton.icon(
                      onPressed: _marquerVu, // re-tap = revu (revoir un film)
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CouleursSW.succes,
                        foregroundColor: CouleursSW.fond,
                      ),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: Text(_nbVus > 1 ? 'Vu · $_nbVus fois' : 'Vu'))
                  : ElevatedButton.icon(
                      onPressed: _marquerVu,
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('Marquer vu')),
              const SizedBox(height: 12),
              // Un seul bouton pour les deux sens : plein quand le film est dans
              // la liste, à liseré sinon — même grammaire que le bouton « Vu ».
              _aVoirActif
                  ? ElevatedButton.icon(
                      onPressed: _basculerAVoir,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CouleursSW.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.bookmark, size: 20),
                      label: const Text('Dans ma liste · retirer'))
                  : OutlinedButton.icon(
                      onPressed: _basculerAVoir,
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
              AvisAbonnements(cle: 'id_film', id: film.idFilm),
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
