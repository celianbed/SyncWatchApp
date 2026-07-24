// Fiche série — backdrop, chips genres, notes, suivi, progression, saisons,
// synopsis, où regarder, titres similaires. Maquette HD · Fiche série.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/affiche_tmdb.dart';
import '../widgets/fiche_extras.dart';
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
  ProchainEpisode? _prochain;
  bool _touteVue = false; // prochain == null ET série au cache
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
      ProchainEpisode? prochain;
      var touteVue = false;
      SuiviPublic? suivi;
      try {
        final donnees =
            await api.get('/series/${widget.referenceTmdb}/saisons') as List;
        saisons = [
          for (final s in donnees)
            SaisonAvecEpisodes.depuisJson(s as Map<String, dynamic>)
        ];
        final brut =
            await api.get('/series/${widget.referenceTmdb}/prochain-episode');
        if (brut == null) {
          touteVue = true;
        } else {
          prochain = ProchainEpisode.depuisJson(brut as Map<String, dynamic>);
        }
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
        _prochain = prochain;
        _touteVue = touteVue;
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
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => _suivi = avant); // rollback
      _snack(e.message);
    }
  }

  Future<void> _marquerEpisodeVu(int idEpisode) async {
    try {
      await api.post('/episodes/$idEpisode/vu');
      await _charger(silencieux: true); // maj de la progression sans spinner global
    } on ExceptionApi catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _marquerSaisonVue(SaisonAvecEpisodes saison) async {
    try {
      await api.post('/saisons/${saison.idSaison}/vu');
      _snack('Saison ${saison.numSaison} marquée vue ✓');
      await _charger(silencieux: true);
    } on ExceptionApi catch (e) {
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
        appBar: AppBar(),
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
    final progression =
        progressionSerie(_saisons, _touteVue ? null : _prochain);

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
                Text(serie.titre, style: typo.headlineMedium),
                const SizedBox(height: 10),
                ChipsGenres(genres: serie.genres),
                const SizedBox(height: 10),
                Text(_meta(serie), style: typo.bodySmall),
                const SizedBox(height: 20),
                BlocNoterFiche(
                    idSerie: serie.idSerie, noteTmdb: serie.noteMoyenneTmdb),
                const SizedBox(height: 12),
                _boutonSuivi(),
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
                        prochain: _touteVue ? null : _prochain,
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

  void _ouvrirSaison(SaisonAvecEpisodes saison) {
    final prochain = _touteVue ? null : _prochain;
    bool episodeVu(EpisodeDansSaison episode) =>
        prochain == null ||
        saison.numSaison < prochain.numSaison ||
        (saison.numSaison == prochain.numSaison &&
            episode.numEpisode < prochain.numEpisode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (contexteFeuille) => DraggableScrollableSheet(
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
                    onPressed: () {
                      Navigator.of(contexteFeuille).pop();
                      _marquerSaisonVue(saison);
                    },
                    child: const Text('Tout marquer vu'),
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
                  final vu = episodeVu(episode);
                  return ListTile(
                    leading: Text(
                        episode.numEpisode.toString().padLeft(2, '0'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: CouleursSW.texteSecondaire)),
                    title: Text(episode.titre ?? 'Épisode ${episode.numEpisode}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Icon(
                        vu ? Icons.check_circle : Icons.check_circle_outline,
                        color: vu
                            ? CouleursSW.succes
                            : CouleursSW.texteSecondaire),
                    onTap: vu
                        ? null
                        : () {
                            Navigator.of(contexteFeuille).pop();
                            _marquerEpisodeVu(episode.idEpisode);
                          },
                  );
                },
              ),
            ),
          ],
        ),
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
  final ProchainEpisode? prochain;
  final VoidCallback surOuvrir;

  const _CarteSaison(
      {required this.saison, required this.prochain, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    var vus = 0;
    for (final episode in saison.episodes) {
      if (prochain == null ||
          saison.numSaison < prochain!.numSaison ||
          (saison.numSaison == prochain!.numSaison &&
              episode.numEpisode < prochain!.numEpisode)) {
        vus++;
      }
    }
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
