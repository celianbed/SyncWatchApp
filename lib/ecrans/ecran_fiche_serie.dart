// Fiche série — backdrop, chips genres, notes, suivi, progression, saisons,
// synopsis, où regarder, titres similaires. Maquette HD · Fiche série.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/affiche_tmdb.dart';
import '../widgets/avis_abonnements.dart';
import '../widgets/section_casting.dart';
import '../widgets/bouton_bande_annonce.dart';
import '../widgets/feuille_recommander.dart';
import '../widgets/fiche_extras.dart';
import '../widgets/progression_abonnements.dart';
import 'ecran_liste_resultats.dart';

/// Statuts de diffusion TMDB → libellés français.
const _statutsDiffusion = {
  'Returning Series': 'En cours',
  'Ended': 'Terminée',
  'Canceled': 'Annulée',
  'In Production': 'En production',
  'Planned': 'Prévue',
  'Pilot': 'Pilote',
};

class EcranFicheSerie extends StatefulWidget {
  final int referenceTmdb;
  const EcranFicheSerie({super.key, required this.referenceTmdb});

  @override
  State<EcranFicheSerie> createState() => _EcranFicheSerieState();
}

class _EcranFicheSerieState extends State<EcranFicheSerie> {
  SeriePublique? _serie;
  List<SaisonAvecEpisodes> _saisons = [];
  SuiviPublic? _suivi;
  bool _chargement = true;
  String? _erreur;
  late Future<PlateformesVisionnage> _plateformes;
  late Future<List<ResultatRecherche>> _similaires;

  @override
  void initState() {
    super.initState();
    _plateformes = _chargerPlateformes();
    _similaires = _chargerSimilaires();
    _charger();
  }

  Future<PlateformesVisionnage> _chargerPlateformes() async =>
      PlateformesVisionnage.depuisJson(
          await api.get('/series/${widget.referenceTmdb}/plateformes')
              as Map<String, dynamic>);

  Future<List<ResultatRecherche>> _chargerSimilaires() async {
    final donnees =
        await api.get('/series/${widget.referenceTmdb}/similaires') as List;
    return [
      for (final r in donnees)
        ResultatRecherche.depuisJson(r as Map<String, dynamic>)
    ];
  }

  /// [silencieux] : rafraîchit les données SANS afficher le spinner plein écran
  /// (utilisé après une action optimiste — le contenu se met à jour en place).
  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux) {
      setState(() {
        _chargement = true;
        _erreur = null;
      });
    }
    try {
      final serie = SeriePublique.depuisJson(
          await api.get('/series/${widget.referenceTmdb}')
              as Map<String, dynamic>);

      // Saisons, prochain épisode et suivi : absents tant que personne ne suit
      // la série (cache non rempli) — un 404 ici est un état normal.
      var saisons = <SaisonAvecEpisodes>[];
      SuiviPublic? suivi;
      try {
        final donnees =
            await api.get('/series/${widget.referenceTmdb}/saisons') as List;
        saisons = [
          for (final s in donnees)
            SaisonAvecEpisodes.depuisJson(s as Map<String, dynamic>)
        ];
      } on ExceptionApi catch (e) {
        if (e.code != 404) rethrow;
      }
      try {
        // PATCH vide : renvoie le suivi actuel sans le modifier, 404 sinon.
        suivi = SuiviPublic.depuisJson(
            await api.patch('/series/${widget.referenceTmdb}/suivre',
                corps: const {}) as Map<String, dynamic>);
      } on ExceptionApi catch (e) {
        if (e.code != 404) rethrow;
      }

      if (!mounted) return;
      setState(() {
        _serie = serie;
        _saisons = saisons;
        _suivi = suivi;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      // en silencieux, on ne blanchit pas la page : on garde le contenu affiché
      if (silencieux) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  Future<void> _suivre() async {
    final avant = _suivi;
    // optimiste : le bouton passe à « suivi » immédiatement
    setState(() => _suivi = SuiviPublic.depuisJson(
        const {'statut_suivi': 'en_cours', 'favori': false}));
    try {
      await api.post('/series/${widget.referenceTmdb}/suivre',
          corps: const {'statut_suivi': 'en_cours'});
      _snack('Série suivie ✓');
      // suivre remplit le cache (saisons, épisodes) : on les charge en fond, sans spinner
      await _charger(silencieux: true);
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => _suivi = avant); // rollback
      _snack(e.message);
    }
  }

  Future<void> _changerStatut(String statut) async {
    final avant = _suivi;
    setState(() => _suivi = SuiviPublic.depuisJson(
        {'statut_suivi': statut, 'favori': avant?.favori ?? false}));
    try {
      await api.patch('/series/${widget.referenceTmdb}/suivre',
          corps: {'statut_suivi': statut});
      _snack('Série marquée « ${libellesStatutSuivi[statut]} » ✓');
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => _suivi = avant); // rollback
      _snack(e.message);
    }
  }

  Future<void> _nePlusSuivre() async {
    final avant = _suivi;
    setState(() => _suivi = null); // optimiste
    try {
      await api.delete('/series/${widget.referenceTmdb}/suivre');
      _snack('Tu ne suis plus cette série');
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => _suivi = avant); // rollback
      _snack(e.message);
    }
  }

  /// Bascule un épisode vu / non vu. La coche change immédiatement, l'appel
  /// part derrière, et l'état revient en place s'il échoue. [aussi] rebâtit la
  /// feuille de saison, qui a son propre State et n'écoute pas celui-ci.
  Future<void> _basculerEpisode(EpisodeDansSaison episode,
      {required String libelle, VoidCallback? aussi}) async {
    final avant = episode.vu;
    setState(() => episode.vu = !avant);
    aussi?.call();
    try {
      if (avant) {
        await api.delete('/episodes/${episode.idEpisode}/vu');
        _snack('$libelle retiré des épisodes vus');
      } else {
        await api.post('/episodes/${episode.idEpisode}/vu');
        _snack('$libelle marqué vu ✓');
      }
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => episode.vu = avant);
      aussi?.call();
      _snack(e.message);
    }
  }

  /// Marque ou dé-marque toute la saison — un « Tout marquer vu » par mégarde
  /// doit pouvoir se défaire d'un geste.
  Future<void> _basculerSaison(SaisonAvecEpisodes saison,
      {VoidCallback? aussi}) async {
    final diffuses = saison.episodes.where((e) => e.diffuse).toList();
    if (diffuses.isEmpty) return;
    final toutVu = diffuses.every((e) => e.vu);
    final avant = {for (final e in saison.episodes) e.idEpisode: e.vu};

    setState(() {
      // dé-marquer efface toute la saison, y compris un épisode non diffusé
      // qui aurait été marqué à la main ; marquer ne touche que le diffusé.
      for (final e in toutVu ? saison.episodes : diffuses) {
        e.vu = !toutVu;
      }
    });
    aussi?.call();
    try {
      if (toutVu) {
        await api.delete('/saisons/${saison.idSaison}/vu');
        _snack('Saison ${saison.numSaison} retirée des vus');
      } else {
        await api.post('/saisons/${saison.idSaison}/vu');
        _snack('Saison ${saison.numSaison} marquée vue ✓');
      }
    } on ExceptionApi catch (e) {
      if (mounted) {
        setState(() {
          for (final e in saison.episodes) {
            e.vu = avant[e.idEpisode]!;
          }
        });
      }
      aussi?.call();
      _snack(e.message);
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
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_erreur != null || _serie == null) {
      return Scaffold(
        appBar: AppBar(actions: [
          IconButton(
            icon: const Icon(Icons.send_outlined),
            tooltip: 'Recommander à un ami',
            onPressed: () => ouvrirRecommander(context,
                referenceTmdb: widget.referenceTmdb, type: 'serie'),
          ),
        ]),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_erreur ?? 'Série introuvable',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center))),
      );
    }

    final serie = _serie!;
    final typo = Theme.of(context).textTheme;
    final progression = progressionSerie(_saisons);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Bandeau(serie: serie),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Text(serie.titre, style: typo.headlineMedium)),
                    IconButton(
                      icon: const Icon(Icons.send_outlined,
                          color: CouleursSW.texteSecondaire),
                      tooltip: 'Recommander à un ami',
                      onPressed: () => ouvrirRecommander(context,
                          referenceTmdb: widget.referenceTmdb, type: 'serie'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ChipsGenres(genres: serie.genres),
                const SizedBox(height: 10),
                Text(_meta(serie), style: typo.bodySmall),
                const SizedBox(height: 20),
                BlocNoterFiche(
                    idSerie: serie.idSerie, noteTmdb: serie.noteMoyenneTmdb),
                const SizedBox(height: 12),
                _boutonSuivi(),
                BoutonBandeAnnonce(
                    type: 'series',
                    referenceTmdb: widget.referenceTmdb,
                    titre: serie.titre),
                if (_saisons.isNotEmpty && progression.total > 0) ...[
                  const SizedBox(height: 20),
                  Text('${progression.vus} / ${progression.total} épisodes vus',
                      style: typo.bodySmall
                          ?.copyWith(color: CouleursSW.texte)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: progression.vus / progression.total,
                        minHeight: 6),
                  ),
                ],
                if (_saisons.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  for (final saison
                      in _saisons.where((s) => s.numSaison > 0)) ...[
                    _CarteSaison(
                        saison: saison,
                        surOuvrir: () => _ouvrirSaison(saison)),
                    const SizedBox(height: 12),
                  ],
                ] else if (_suivi == null) ...[
                  const SizedBox(height: 20),
                  Text(
                      'Suis cette série pour récupérer ses saisons et suivre ta progression.',
                      style: typo.bodySmall),
                ],
                if (serie.synopsis != null && serie.synopsis!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(serie.synopsis!,
                      style: typo.bodySmall?.copyWith(height: 1.5)),
                ],
                SectionCasting(
                    type: 'series', referenceTmdb: widget.referenceTmdb),
                ProgressionAbonnements(referenceTmdb: widget.referenceTmdb),
                AvisAbonnements(cle: 'id_serie', id: serie.idSerie),
                SectionOuRegarder(plateformes: _plateformes),
                SectionSimilaires(
                    resultats: _similaires, surOuvrir: _ouvrirResultat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _meta(SeriePublique serie) {
    final morceaux = <String>[
      if (serie.datePremiereDiffusion != null)
        '${serie.datePremiereDiffusion!.year}',
      if (serie.statutDiffusion != null)
        _statutsDiffusion[serie.statutDiffusion] ?? serie.statutDiffusion!,
    ];
    return morceaux.join(' · ');
  }

  void _ouvrirResultat(ResultatRecherche resultat) {
    ouvrirFiche(context, resultat).then((_) => _charger());
  }

  Widget _boutonSuivi() {
    final suivi = _suivi;
    if (suivi == null) {
      return ElevatedButton.icon(
          onPressed: _suivre,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Suivre'));
    }
    return ElevatedButton.icon(
      onPressed: _menuSuivi,
      icon: const Icon(Icons.check, size: 20),
      label: Text('Suivie · ${libellesStatutSuivi[suivi.statutSuivi]}'),
    );
  }

  void _menuSuivi() {
    showModalBottomSheet(
      context: context,
      builder: (contexteFeuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final entree in libellesStatutSuivi.entries)
              ListTile(
                title: Text(entree.value),
                trailing: _suivi?.statutSuivi == entree.key
                    ? const Icon(Icons.check, color: CouleursSW.accent)
                    : null,
                onTap: () {
                  Navigator.of(contexteFeuille).pop();
                  _changerStatut(entree.key);
                },
              ),
            const Divider(),
            ListTile(
              title: const Text('Ne plus suivre',
                  style: TextStyle(color: CouleursSW.danger)),
              leading:
                  const Icon(Icons.close, color: CouleursSW.danger, size: 20),
              onTap: () {
                Navigator.of(contexteFeuille).pop();
                _nePlusSuivre();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Feuille de la saison : chaque ligne se coche et se décoche sur place, la
  /// feuille reste ouverte. `majFeuille` la rebâtit — elle a son propre State.
  void _ouvrirSaison(SaisonAvecEpisodes saison) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (contexteFeuille) => StatefulBuilder(
        builder: (_, majFeuille) {
          void rafraichir() {
            if (contexteFeuille.mounted) majFeuille(() {});
          }

          final diffuses = saison.episodes.where((e) => e.diffuse).toList();
          final toutVu = diffuses.isNotEmpty && diffuses.every((e) => e.vu);

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .6,
            builder: (_, defilement) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                  child: Row(
                    children: [
                      Text('Saison ${saison.numSaison}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: diffuses.isEmpty
                            ? null
                            : () => _basculerSaison(saison, aussi: rafraichir),
                        child: Text(
                            toutVu ? 'Tout dé-marquer' : 'Tout marquer vu'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: defilement,
                    itemCount: saison.episodes.length,
                    itemBuilder: (_, i) {
                      final episode = saison.episodes[i];
                      final numero =
                          'S${saison.numSaison.toString().padLeft(2, '0')}'
                          'E${episode.numEpisode.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: Text(
                            episode.numEpisode.toString().padLeft(2, '0'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: CouleursSW.texteSecondaire)),
                        title: Text(
                            episode.titre ?? 'Épisode ${episode.numEpisode}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: episode.diffuse
                            ? null
                            : const Text('Pas encore diffusé'),
                        trailing: Icon(
                            episode.vu
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: episode.vu
                                ? CouleursSW.succes
                                : CouleursSW.texteSecondaire),
                        // un épisode vu se décoche : c'est le rattrapage d'un
                        // clic malencontreux, il n'y en avait aucun avant.
                        onTap: episode.diffuse || episode.vu
                            ? () => _basculerEpisode(episode,
                                libelle: numero, aussi: rafraichir)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  final SeriePublique serie;
  const _Bandeau({required this.serie});

  @override
  Widget build(BuildContext context) {
    final url = urlImageTmdb(serie.imageDeFond ?? serie.affiche, largeur: 780);
    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          else
            Container(color: CouleursSW.surface),
          // fondu vers le fond de l'écran, comme sur la maquette
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, CouleursSW.fond],
                stops: [.4, 1],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: CouleursSW.fond.withValues(alpha: .6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.arrow_back,
                            color: CouleursSW.texte, size: 20)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteSaison extends StatelessWidget {
  final SaisonAvecEpisodes saison;
  final VoidCallback surOuvrir;

  const _CarteSaison({required this.saison, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final vus = saison.episodes.where((e) => e.vu).length;
    final total = saison.episodes.length;
    final complete = total > 0 && vus == total;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: surOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saison ${saison.numSaison}', style: typo.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                            value: total == 0 ? 0 : vus / total,
                            minHeight: 6,
                            color: CouleursSW.succes),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                complete ? '$vus / $total ✓' : '$vus / $total',
                style: typo.bodySmall?.copyWith(
                    color: complete
                        ? CouleursSW.succes
                        : CouleursSW.texteSecondaire,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
