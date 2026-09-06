// Accueil — « À regarder ce soir » : prochain épisode de chaque série suivie,
// carrousel « Reprendre une série », puis bloc découverte : héro « Tendance
// de la semaine », tendances, séries à l'antenne, films à l'affiche (TMDB).
// Maquette HD · Accueil.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../util/rafraichissement.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/affiche_tmdb.dart';
import '../widgets/rangee_resultats.dart';
import 'ecran_activite.dart';
import 'ecran_fiche_serie.dart';
import 'ecran_liste_resultats.dart';
import 'ecran_notifications.dart';

class EcranAccueil extends StatefulWidget {
    /// Onglet à l'écran ? La coquille les construit tous, n'en montre qu'un.
  final bool actif;
  const EcranAccueil({super.key, this.actif = false});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil>
    with RafraichitSiPerime {
  @override
  bool get visible => widget.actif;

  @override
  void rafraichir() => _rafraichir();

  @override
  void didUpdateWidget(EcranAccueil ancien) {
    super.didUpdateWidget(ancien);
    // l'onglet vient de revenir au premier plan
    if (widget.actif && !ancien.actif) rafraichirSiNecessaire();
  }

  late Future<List<AccueilEntree>> _entrees;
  late Future<List<ResultatRecherche>> _tendances;
  late Future<List<ResultatRecherche>> _seriesALAntenne;
  late Future<List<ResultatRecherche>> _filmsALAffiche;

  // Progressions par série (référence TMDB) — un seul appel saisons par série.
  final _progressions = <int, Future<({int vus, int total})>>{};

  // Épisodes qu'on vient de marquer vus : retirés de la liste tout de suite,
  // sans attendre le serveur. Vidé dès que la liste revient rechargée.
  final _marques = <int>{};

  @override
  void initState() {
    super.initState();
    _entrees = _charger();
    _chargerDecouverte();
  }

  Future<List<AccueilEntree>> _charger() async {
    final donnees = await api.get('/accueil') as List;
    return [
      for (final e in donnees) AccueilEntree.depuisJson(e as Map<String, dynamic>)
    ];
  }

  Future<List<ResultatRecherche>> _chargerResultats(String chemin,
      [Map<String, String>? params]) async {
    final donnees = await api.get(chemin, params: params) as List;
    return [
      for (final r in donnees)
        ResultatRecherche.depuisJson(r as Map<String, dynamic>)
    ];
  }

  void _chargerDecouverte() {
    _tendances = _chargerResultats('/search/tendances');
    _seriesALAntenne =
        _chargerResultats('/search/nouveautes', {'type': 'serie'});
    _filmsALAffiche = _chargerResultats('/search/nouveautes', {'type': 'film'});
  }

  Future<void> _rafraichir() async {
    _progressions.clear();
    setState(() {
      _entrees = _charger();
      _chargerDecouverte();
    });
    await _entrees;
    // la liste rechargée fait autorité : elle porte déjà l'épisode suivant
    if (mounted) setState(_marques.clear);
  }

  Future<({int vus, int total})> _progression(AccueilEntree entree) =>
      _progressions.putIfAbsent(entree.serie.referenceTmdb, () async {
        final donnees =
            await api.get('/series/${entree.serie.referenceTmdb}/saisons') as List;
        final saisons = [
          for (final s in donnees)
            SaisonAvecEpisodes.depuisJson(s as Map<String, dynamic>)
        ];
        return progressionSerie(saisons);
      });

  /// Marque l'épisode vu : la carte disparaît immédiatement, l'appel part
  /// derrière, et la carte revient si le serveur refuse.
  Future<void> _marquerVu(AccueilEntree entree) async {
    final idEpisode = entree.episode.idEpisode;
    setState(() => _marques.add(idEpisode));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${entree.serie.titre} ${entree.episode.code} marqué vu ✓'),
      action: SnackBarAction(
          label: 'Annuler', onPressed: () => _annulerVu(entree)),
    ));
    try {
      await api.post('/episodes/$idEpisode/vu');
      await _rafraichir();
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() => _marques.remove(idEpisode));
      _message(e.message);
    }
  }

  /// Défait le marquage sur simple pression de « Annuler ».
  Future<void> _annulerVu(AccueilEntree entree) async {
    try {
      await api.delete('/episodes/${entree.episode.idEpisode}/vu');
      await _rafraichir();
      _message('${entree.episode.code} remis en non vu');
    } on ExceptionApi catch (e) {
      _message(e.message);
    }
  }

  void _message(String texte) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texte)));
    }
  }

  String _salutation() {
    final heure = DateTime.now().hour;
    return heure >= 18 || heure < 5 ? 'Bonsoir 👋' : 'Bonjour 👋';
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _rafraichir,
        child: FutureBuilder(
          future: _entrees,
          builder: (context, instantane) {
            if (instantane.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (instantane.hasError) {
              return _MessageCentre(
                  icone: Icons.cloud_off,
                  texte: 'API injoignable.\n${instantane.error}',
                  surReessayer: _rafraichir);
            }
            final entrees = [
              for (final e in instantane.data ?? <AccueilEntree>[])
                if (!_marques.contains(e.episode.idEpisode)) e
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Row(
                  children: [
                    Text(_salutation(), style: typo.bodySmall),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.dynamic_feed_outlined,
                          color: CouleursSW.texteSecondaire),
                      tooltip: 'Activité de tes abonnements',
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const EcranActivite())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: CouleursSW.texteSecondaire),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const EcranNotifications())),
                    ),
                  ],
                ),
                Text('À regarder ce soir', style: typo.headlineMedium),
                const SizedBox(height: 16),
                if (entrees.isEmpty)
                  const _CarteVide(
                      texte:
                          'Rien à suivre pour l’instant.\nPioche une idée dans les tendances ci-dessous 👇')
                else
                  for (final entree in entrees) ...[
                    _CarteEpisode(
                        entree: entree,
                        progression: _progression(entree),
                        surVu: () => _marquerVu(entree),
                        surOuvrir: () => _ouvrirSerie(entree)),
                    const SizedBox(height: 12),
                  ],
                if (entrees.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Reprendre une série', style: typo.titleLarge),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entrees.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _ouvrirSerie(entrees[i]),
                        child: AfficheTmdb(
                            chemin: entrees[i].serie.affiche,
                            largeur: 100,
                            hauteur: 150),
                      ),
                    ),
                  ),
                ],
                // ---- Bloc découverte ----
                const SizedBox(height: 28),
                FutureBuilder(
                  future: _tendances,
                  builder: (context, tendancesInstantane) {
                    final tendances = tendancesInstantane.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _EnteteSection(
                            titre: 'Tendances cette semaine',
                            sousTitre: 'Ce que tout le monde regarde',
                            surVoirTout: tendances.isEmpty
                                ? null
                                : () => _voirTout(
                                    'Tendances cette semaine', _tendances)),
                        const SizedBox(height: 14),
                        if (tendancesInstantane.connectionState ==
                            ConnectionState.waiting)
                          const SizedBox(
                              height: 120,
                              child:
                                  Center(child: CircularProgressIndicator()))
                        else if (tendances.isEmpty)
                          Text('Tendances indisponibles.',
                              style: typo.bodySmall,
                              textAlign: TextAlign.center)
                        else ...[
                          // la tendance n°1 en pleine largeur, le reste en rangée
                          _CarteHero(
                              resultat: tendances.first,
                              surOuvrir: () =>
                                  _ouvrirResultat(tendances.first)),
                          const SizedBox(height: 14),
                          RangeeResultats(
                              resultats: tendances.skip(1).toList(),
                              surOuvrir: _ouvrirResultat),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _EnteteSection(
                    titre: 'Séries à l’antenne',
                    sousTitre: 'De nouveaux épisodes cette semaine',
                    surVoirTout: () =>
                        _voirTout('Séries à l’antenne', _seriesALAntenne)),
                const SizedBox(height: 14),
                CarrouselResultats(
                    resultats: _seriesALAntenne, surOuvrir: _ouvrirResultat),
                const SizedBox(height: 24),
                _EnteteSection(
                    titre: 'Films à l’affiche',
                    sousTitre: 'En salles en ce moment',
                    surVoirTout: () =>
                        _voirTout('Films à l’affiche', _filmsALAffiche)),
                const SizedBox(height: 14),
                CarrouselResultats(
                    resultats: _filmsALAffiche, surOuvrir: _ouvrirResultat),
              ],
            );
          },
        ),
      ),
    );
  }

  void _ouvrirSerie(AccueilEntree entree) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                EcranFicheSerie(referenceTmdb: entree.serie.referenceTmdb)))
        .then((_) => _rafraichir());
  }

  void _ouvrirResultat(ResultatRecherche resultat) {
    ouvrirFiche(context, resultat).then((_) => _rafraichir());
  }

  void _voirTout(String titre, Future<List<ResultatRecherche>> resultats) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranListeResultats(titre: titre, resultats: resultats)));
  }
}

/// En-tête de section : barre accent, titre, sous-titre, « Voir tout ».
class _EnteteSection extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final VoidCallback? surVoirTout;

  const _EnteteSection(
      {required this.titre, required this.sousTitre, this.surVoirTout});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: CouleursSW.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: typo.titleLarge),
              const SizedBox(height: 2),
              Text(sousTitre, style: typo.bodySmall),
            ],
          ),
        ),
        if (surVoirTout != null)
          TextButton(onPressed: surVoirTout, child: const Text('Voir tout')),
      ],
    );
  }
}

/// Grande carte 16:9 sur l'image de fond TMDB — la tendance n°1.
class _CarteHero extends StatelessWidget {
  final ResultatRecherche resultat;
  final VoidCallback surOuvrir;

  const _CarteHero({required this.resultat, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: surOuvrir,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (_, contraintes) => AfficheTmdb(
                  chemin: resultat.imageDeFond ?? resultat.affiche,
                  largeur: contraintes.maxWidth,
                  hauteur: contraintes.maxHeight,
                  rayon: 16,
                  largeurTmdb: 780),
            ),
            // dégradé de lisibilité vers le bas de la carte
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [.4, 1],
                  colors: [
                    Colors.transparent,
                    CouleursSW.fond.withValues(alpha: .92),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Pastille(
                          texte: resultat.type == 'serie' ? 'SÉRIE' : 'FILM',
                          couleur: CouleursSW.accent),
                      if (resultat.noteMoyenne != null) ...[
                        const SizedBox(width: 8),
                        _Pastille(
                            texte:
                                '★ ${resultat.noteMoyenne!.toStringAsFixed(1)}',
                            couleur: CouleursSW.accentSecondaire),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(resultat.titre,
                      style: typo.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit badge arrondi (type, note…) — même style que « NOUVEAU ».
class _Pastille extends StatelessWidget {
  final String texte;
  final Color couleur;
  const _Pastille({required this.texte, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texte,
          style: TextStyle(
              color: couleur,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .8)),
    );
  }
}

class _CarteEpisode extends StatelessWidget {
  final AccueilEntree entree;
  final Future<({int vus, int total})> progression;
  final VoidCallback surVu;
  final VoidCallback surOuvrir;

  const _CarteEpisode(
      {required this.entree,
      required this.progression,
      required this.surVu,
      required this.surOuvrir});

  bool get _nouveau {
    final diffusion = entree.episode.dateDiffusion;
    return diffusion != null &&
        entree.episode.dejaDiffuse &&
        DateTime.now().difference(diffusion).inDays <= 7;
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final episode = entree.episode;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: surOuvrir,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AfficheTmdb(
                  chemin: episode.vignette ?? entree.serie.affiche,
                  largeur: 88,
                  hauteur: 56,
                  largeurTmdb: 300),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(entree.serie.titre,
                                style: typo.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        if (_nouveau) ...[
                          const SizedBox(width: 8),
                          const _Pastille(
                              texte: 'NOUVEAU',
                              couleur: CouleursSW.accentSecondaire),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        episode.titre == null
                            ? episode.code
                            : '${episode.code} · ${episode.titre}',
                        style: typo.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    _BarreProgression(progression: progression),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _BoutonVu(surVu: surVu),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarreProgression extends StatelessWidget {
  final Future<({int vus, int total})> progression;
  const _BarreProgression({required this.progression});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: progression,
      builder: (context, instantane) {
        final donnees = instantane.data;
        final valeur = donnees == null || donnees.total == 0
            ? 0.0
            : donnees.vus / donnees.total;
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: valeur, minHeight: 6),
        );
      },
    );
  }
}

class _BoutonVu extends StatelessWidget {
  final VoidCallback surVu;
  const _BoutonVu({required this.surVu});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CouleursSW.succes.withValues(alpha: .15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: surVu,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.check, color: CouleursSW.succes, size: 20),
        ),
      ),
    );
  }
}

class _CarteVide extends StatelessWidget {
  final String texte;
  const _CarteVide({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(texte,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _MessageCentre extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Future<void> Function()? surReessayer;

  const _MessageCentre(
      {required this.icone, required this.texte, this.surReessayer});

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView pour rester compatible avec RefreshIndicator
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(icone, size: 48, color: CouleursSW.texteSecondaire),
        const SizedBox(height: 16),
        Text(texte,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
        if (surReessayer != null) ...[
          const SizedBox(height: 16),
          Center(
              child: TextButton(
                  onPressed: () => surReessayer!(),
                  child: const Text('Réessayer'))),
        ],
      ],
    );
  }
}
