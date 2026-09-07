// Accueil — « À regarder ce soir » : prochain épisode de chaque série suivie,
// carrousel « Reprendre une série », puis bloc découverte : héro « Tendance
// de la semaine », tendances, séries à l'antenne, films à l'affiche (TMDB).
// Maquette HD · Accueil.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../widgets/squelette.dart';
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

  // Saisons par série (référence TMDB) — un seul appel /saisons par série.
  // On garde la liste entière, pas seulement la progression qu'on en tire :
  // elle porte l'état vu de chaque épisode, donc de quoi calculer le prochain
  // localement et se passer d'un aller-retour à chaque épisode coché.
  final _saisons = <int, List<SaisonAvecEpisodes>>{};
  final _enCours = <int>{};

  // Prochain épisode recalculé sur place après un cochage. null = série
  // terminée, sa carte disparaît.
  final _prochainLocal = <int, ProchainEpisode?>{};

  // Épisodes qu'on vient de marquer vus. La carte reste en place, cochée :
  // la retirer la faisait disparaître puis revenir avec l'épisode suivant, un
  // clignotement que rien ne justifie. Vidé quand la liste revient rechargée.
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

  /// Recharge sans blanchir l'écran : on attend la nouvelle liste avant de
  /// la poser. Remplacer le Future d'abord ramenait le FutureBuilder à l'état
  /// « en attente », donc le squelette — d'où la série qui disparaissait, la
  /// page qui se rechargeait, puis la série qui revenait.
  /// [avecDecouverte] : les carrousels de tendances ne bougent qu'une fois par
  /// semaine et n'ont aucun rapport avec un épisode coché. Les relancer les
  /// renvoyait en chargement à chaque tic, ce qui donnait l'impression que
  /// toute la page se rechargeait. Seul le tiré-pour-rafraîchir les redemande.
  Future<void> _rafraichir({bool avecDecouverte = false}) async {
    final futur = _charger();
    List<AccueilEntree>? nouvelles;
    try {
      nouvelles = await futur;
    } on ExceptionApi {
      if (mounted) setState(() => _entrees = futur); // laisse voir l'erreur
      return;
    }
    if (!mounted) return;
    setState(() {
      _entrees = Future.value(nouvelles);
      if (avecDecouverte) _chargerDecouverte();
      // la liste rechargée fait autorité : elle porte déjà l'épisode suivant
      _marques.clear();
    });
    // le rechargement vient d'avoir lieu : sans ça, la révision le relancerait
    marquerAJour();
  }

  /// L'entrée telle qu'elle doit s'afficher : avec le prochain épisode
  /// recalculé localement s'il y en a un, ou null si la série n'a plus rien
  /// à proposer ce soir.
  AccueilEntree? _avecProchainLocal(AccueilEntree entree) {
    final ref = entree.serie.referenceTmdb;
    if (!_prochainLocal.containsKey(ref)) return entree;
    final prochain = _prochainLocal[ref];
    return prochain == null
        ? null
        : AccueilEntree(serie: entree.serie, episode: prochain);
  }

  /// Progression connue, ou null tant que les saisons ne sont pas arrivées.
  ///
  /// Une valeur, pas un Future : un FutureBuilder repart en attente dès qu'on
  /// lui passe une nouvelle instance, et affiche alors zéro — la barre se
  /// vidait sous les yeux à chaque épisode coché.
  ({int vus, int total})? _progression(AccueilEntree entree) {
    final ref = entree.serie.referenceTmdb;
    final saisons = _saisons[ref];
    if (saisons != null) return progressionSerie(saisons);
    if (_enCours.add(ref)) _chargerSaisons(ref);
    return null;
  }

  Future<void> _chargerSaisons(int referenceTmdb) async {
    try {
      final donnees = await api.get('/series/$referenceTmdb/saisons') as List;
      final saisons = [
        for (final s in donnees)
          SaisonAvecEpisodes.depuisJson(s as Map<String, dynamic>)
      ];
      if (mounted) setState(() => _saisons[referenceTmdb] = saisons);
    } on ExceptionApi {
      // la barre reste vide : une progression manquante ne vaut pas une erreur
    } finally {
      _enCours.remove(referenceTmdb);
    }
  }

  /// Applique le cochage sur le cache local : l'épisode passe vu, et le
  /// prochain est recalculé sur place. Renvoie faux si les saisons ne sont pas
  /// encore chargées — il faudra alors s'en remettre au serveur.
  bool _appliquerLocalement(AccueilEntree entree, int idEpisode, bool vu) {
    final saisons = _saisons[entree.serie.referenceTmdb];
    if (saisons == null) return false;
    for (final saison in saisons) {
      for (final episode in saison.episodes) {
        if (episode.idEpisode == idEpisode) {
          episode.vu = vu;
          _prochainLocal[entree.serie.referenceTmdb] = prochainNonVu(saisons);
          return true;
        }
      }
    }
    return false;
  }

  /// Marque l'épisode vu. Barre et carte avancent sur-le-champ, l'appel part
  /// derrière, et l'écran ne se recharge qu'en cas de refus du serveur.
  ///
  /// Les saisons déjà en cache portent l'état vu de chaque épisode : le
  /// prochain se calcule donc localement, sans le moindre aller-retour. C'est
  /// ce qui manquait — je croyais devoir demander au serveur quel épisode
  /// afficher ensuite, d'où un rechargement à chaque tic.
  Future<void> _marquerVu(AccueilEntree entree) async {
    final idEpisode = entree.episode.idEpisode;
    final localement = _appliquerLocalement(entree, idEpisode, true);
    setState(() {
      if (!localement) _marques.add(idEpisode); // repli : on coche la carte
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${entree.serie.titre} ${entree.episode.code} marqué vu ✓'),
      action: SnackBarAction(
          label: 'Annuler', onPressed: () => _annulerVu(entree)),
    ));

    // l'affichage est déjà juste : inutile que la révision le refasse
    if (localement) ignorerProchaineEcriture();
    try {
      await api.post('/episodes/$idEpisode/vu');
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      // le serveur a refusé : on remet l'écran dans l'état d'avant
      setState(() {
        _appliquerLocalement(entree, idEpisode, false);
        _marques.remove(idEpisode);
      });
      _message(e.message, remplace: true);
    }
  }

  /// Défait le marquage sur simple pression de « Annuler ».
  Future<void> _annulerVu(AccueilEntree entree) async {
    final idEpisode = entree.episode.idEpisode;
    final localement = _appliquerLocalement(entree, idEpisode, false);
    if (mounted) setState(() => _marques.remove(idEpisode));
    if (localement) ignorerProchaineEcriture();
    try {
      await api.delete('/episodes/$idEpisode/vu');
      _message('${entree.episode.code} remis en non vu');
    } on ExceptionApi catch (e) {
      if (mounted) setState(() => _appliquerLocalement(entree, idEpisode, true));
      _message(e.message);
    }
  }

  /// [remplace] : vide la file d'attente avant d'afficher. Un refus du serveur
  /// arrivait sinon quatre secondes après la confirmation « marqué vu ✓ », qui
  /// occupait encore l'écran — on lisait une confirmation, puis son démenti.
  void _message(String texte, {bool remplace = false}) {
    if (!mounted) return;
    final messager = ScaffoldMessenger.of(context);
    if (remplace) messager.clearSnackBars();
    messager.showSnackBar(SnackBar(content: Text(texte)));
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
        // geste explicite : c'est le seul cas où les tendances se redemandent
        onRefresh: () => _rafraichir(avecDecouverte: true),
        child: FutureBuilder(
          future: _entrees,
          builder: (context, instantane) {
            if (instantane.connectionState == ConnectionState.waiting) {
              return const AvecMentionReveil(child: SqueletteListe());
            }
            if (instantane.hasError) {
              return _MessageCentre(
                  icone: Icons.cloud_off,
                  texte: 'API injoignable.\n${instantane.error}',
                  surReessayer: _rafraichir);
            }
            // Le prochain épisode recalculé sur place prime sur celui que le
            // serveur avait envoyé ; une série dont tout le diffusé est vu
            // quitte la liste, exactement comme le ferait l'API.
            final entrees = [
              for (final e in instantane.data ?? <AccueilEntree>[])
                ?_avecProchainLocal(e)
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
                        vu: _marques.contains(entree.episode.idEpisode),
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
  /// null tant que la progression n'est pas connue.
  final ({int vus, int total})? progression;
  final VoidCallback surVu;
  final VoidCallback surOuvrir;

  /// Épisode validé, en attente de la liste rechargée : la carte reste en
  /// place, cochée, plutôt que de disparaître puis revenir.
  final bool vu;

  const _CarteEpisode(
      {required this.entree,
      required this.progression,
      required this.vu,
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
              _BoutonVu(surVu: vu ? null : surVu, vu: vu),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarreProgression extends StatelessWidget {
  final ({int vus, int total})? progression;
  const _BarreProgression({required this.progression});

  @override
  Widget build(BuildContext context) {
    final p = progression;
    final valeur = p == null || p.total == 0 ? 0.0 : p.vus / p.total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      // animée : cocher un épisode fait glisser la barre au lieu de sauter
      child: TweenAnimationBuilder<double>(
        // begin ne sert qu'au tout premier rendu ; ensuite l'animation part
        // de la valeur courante vers le nouveau `end`.
        tween: Tween<double>(begin: 0, end: valeur),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6),
      ),
    );
  }
}

class _BoutonVu extends StatelessWidget {
  final VoidCallback? surVu;
  final bool vu;
  const _BoutonVu({required this.surVu, required this.vu});

  @override
  Widget build(BuildContext context) {
    // validé : pastille pleine, coche blanche. Le retour est immédiat, sans
    // faire disparaître la carte — la liste rechargée y posera l'épisode suivant.
    return Material(
      color: vu
          ? CouleursSW.succes
          : CouleursSW.succes.withValues(alpha: .15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: surVu,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(vu ? Icons.check_rounded : Icons.check,
              color: vu ? Colors.white : CouleursSW.succes, size: 20),
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
