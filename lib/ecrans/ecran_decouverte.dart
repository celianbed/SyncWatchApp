// Extraits — feed vertical (façon Reels) des bandes-annonces des titres en
// tendance. Un seul lecteur YouTube partagé : on change de vidéo au swipe
// (loadVideoById) plutôt que d'instancier une WebView par page.
import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/affiche_tmdb.dart';
import 'ecran_fiche_film.dart';
import 'ecran_fiche_serie.dart';

class EcranDecouverte extends StatefulWidget {
  /// Vrai quand l'onglet est affiché : le lecteur ne joue que dans ce cas.
  final bool actif;
  const EcranDecouverte({super.key, required this.actif});

  @override
  State<EcranDecouverte> createState() => _EcranDecouverteState();
}

class _EcranDecouverteState extends State<EcranDecouverte>
    with WidgetsBindingObserver {
  List<ExtraitFeed> _items = [];
  YoutubePlayerController? _controleur;
  StreamSubscription<YoutubePlayerValue>? _sousEtat;
  int _index = 0;
  bool _muet = true;
  bool _enLecture = true;
  bool _demarrageForce = false; // évite de relancer play en boucle sur une même vidéo
  bool _videoIndisponible = false; // trailer avec intégration bloquée (erreur YouTube)
  bool _chargement = false;
  String? _erreur;
  int _pageChargee = 0; // dernière page de tendances chargée (feed infini)

  /// Les « tendances de la semaine » de TMDB ne bougent qu'une fois par
  /// semaine : démarrer toujours à la page 1 montrait les mêmes vingt titres
  /// pendant sept jours. On entre dans la liste au hasard.
  static const _pagesTendances = 20;
  final _premierePage = Random().nextInt(_pagesTendances) + 1;
  bool _chargeSuivant = false; // garde-fou : un seul préchargement à la fois
  final Set<String> _ajoutes = {}; // "type:reference" déjà suivis pendant la session

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.actif) _charger();
  }

  @override
  void didUpdateWidget(EcranDecouverte ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.actif == widget.actif) return;
    if (widget.actif) {
      if (_items.isEmpty && !_chargement) {
        _charger(); // chargement paresseux : à la première ouverture de l'onglet
      } else if (_enLecture) {
        _controleur?.playVideo();
      }
    } else {
      _controleur?.pauseVideo(); // onglet quitté : on met en pause
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat != AppLifecycleState.resumed) {
      _controleur?.pauseVideo();
    } else if (widget.actif && _enLecture) {
      _controleur?.playVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sousEtat?.cancel();
    _controleur?.close();
    super.dispose();
  }

  /// Suit l'état réel du lecteur : détecte les vidéos non intégrables, synchronise
  /// l'état lecture/pause, et force le démarrage si le lecteur reste « cued ».
  void _surEtatLecteur(YoutubePlayerValue valeur) {
    final indisponible = valeur.error != YoutubeError.none;
    final etat = valeur.playerState;
    final joue = etat == PlayerState.playing;

    // Coup de pouce : certains WKWebView chargent la vidéo en pause (cued) malgré
    // autoPlay. Dès qu'elle est prête et que l'onglet est actif, on lance.
    if (!_demarrageForce &&
        widget.actif &&
        (etat == PlayerState.cued || etat == PlayerState.unStarted)) {
      _demarrageForce = true;
      _controleur?.playVideo();
      if (_muet) _controleur?.mute();
    }

    if (mounted &&
        (indisponible != _videoIndisponible || joue != _enLecture)) {
      setState(() {
        _videoIndisponible = indisponible;
        _enLecture = joue;
      });
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final items = await _chargerPage(_premierePage);
      if (!mounted) return;
      _sousEtat?.cancel();
      _controleur?.close();
      final ctrl = items.isEmpty
          ? null
          : YoutubePlayerController.fromVideoId(
              videoId: items.first.cleYoutube,
              autoPlay: widget.actif,
              params: const YoutubePlayerParams(
                showControls: false,
                showFullscreenButton: false,
                mute: true, // démarrage muet = autoplay fiable ; l'utilisateur active le son
                enableCaption: false,
                loop: false,
                // origin: null → aucun param origin. La vraie origine est le
                // serveur local 127.0.0.1 (cf. patch de la lib) : on reproduit
                // exactement le test navigateur qui fonctionne.
                origin: null,
              ),
            );
      _sousEtat = ctrl?.stream.listen(_surEtatLecteur);
      setState(() {
        _items = items;
        _controleur = ctrl;
        _index = 0;
        _pageChargee = _premierePage;
        _demarrageForce = false;
        _videoIndisponible = false;
        _enLecture = true;
        _chargement = false;
      });
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  /// Récupère une page du feed (bandes-annonces des tendances).
  Future<List<ExtraitFeed>> _chargerPage(int page) async {
    final donnees =
        await api.get('/decouverte/extraits', params: {'page': '$page'}) as List;
    return [
      for (final e in donnees) ExtraitFeed.depuisJson(e as Map<String, dynamic>)
    ];
  }

  /// Précharge la page suivante et l'ajoute au feed (scroll infini). Quand les
  /// tendances sont épuisées, reboucle à la page 1 → jamais de fin.
  Future<void> _chargerSuivant() async {
    if (_chargeSuivant) return;
    _chargeSuivant = true;
    try {
      var page = _pageChargee + 1;
      var nouveaux = await _chargerPage(page);
      if (nouveaux.isEmpty) {
        page = 1; // fin des tendances → on reboucle
        nouveaux = await _chargerPage(page);
      }
      if (mounted && nouveaux.isNotEmpty) {
        setState(() {
          _items = [..._items, ...nouveaux];
          _pageChargee = page;
        });
      }
    } on ExceptionApi {
      // silencieux : on retentera au prochain swipe
    } finally {
      _chargeSuivant = false;
    }
  }

  void _changerPage(int i) {
    setState(() {
      _index = i;
      _videoIndisponible = false;
    });
    _demarrageForce = false; // nouvelle vidéo → un nouveau coup de pouce autorisé
    _controleur?.loadVideoById(videoId: _items[i].cleYoutube);
    if (_muet) _controleur?.mute(); // loadVideoById peut réactiver le son
    // feed infini : précharge la suite quand on approche de la fin
    if (i >= _items.length - 3) _chargerSuivant();
  }

  Future<void> _ouvrirYoutube(String cle) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$cle');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _message("Impossible d'ouvrir YouTube.");
    }
  }

  void _basculerSon() {
    setState(() => _muet = !_muet);
    _muet ? _controleur?.mute() : _controleur?.unMute();
  }

  Future<void> _suivre(ExtraitFeed e) async {
    final cle = '${e.type}:${e.referenceTmdb}';
    final chemin = e.estSerie
        ? '/series/${e.referenceTmdb}/suivre'
        : '/films/${e.referenceTmdb}/suivre';
    setState(() => _ajoutes.add(cle)); // optimiste : le bouton bascule tout de suite
    try {
      await api.post(chemin);
      _message(e.estSerie ? 'Ajoutée à tes séries' : 'Ajouté à ta liste à voir');
    } on ExceptionApi catch (ex) {
      if (!mounted) return;
      if (ex.code == 409) {
        _message('Déjà dans ta liste'); // déjà suivi = objectif atteint
      } else {
        setState(() => _ajoutes.remove(cle)); // rollback
        _message(ex.message);
      }
    }
  }

  void _ouvrirFiche(ExtraitFeed e) {
    _controleur?.pauseVideo();
    setState(() => _enLecture = false);
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => e.estSerie
              ? EcranFicheSerie(referenceTmdb: e.referenceTmdb)
              : EcranFicheFilm(referenceTmdb: e.referenceTmdb),
        ))
        .then((_) {
      if (widget.actif && mounted) {
        setState(() => _enLecture = true);
        _controleur?.playVideo();
      }
    });
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return _Erreur(message: _erreur!, surReessayer: _charger);
    }
    if (_items.isEmpty) {
      return const _MessageVide();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: CouleursSW.fond),
        // Lecteur unique, centré, non interactif : tous les gestes vont au PageView.
        Center(
          child: IgnorePointer(
            child: YoutubePlayer(controller: _controleur!, aspectRatio: 16 / 9),
          ),
        ),
        // Vidéo non intégrable : on masque le lecteur cassé par l'affiche du titre.
        if (_videoIndisponible)
          Positioned.fill(
            child:
                IgnorePointer(child: _FondIndisponible(extrait: _items[_index])),
          ),
        PageView.builder(
          scrollDirection: Axis.vertical,
          onPageChanged: _changerPage,
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final e = _items[i];
            return _PageInfos(
              extrait: e,
              deja: _ajoutes.contains('${e.type}:${e.referenceTmdb}'),
              surTap: _basculerSon, // tap = couper/remettre le son (la vidéo reste en lecture)
              surSuivre: () => _suivre(e),
              surDetail: () => _ouvrirFiche(e),
            );
          },
        ),
        // Repli quand la bande-annonce refuse l'intégration : ouvrir sur YouTube.
        if (_videoIndisponible)
          Align(
            alignment: const Alignment(0, -0.2),
            child: _RepliYoutube(
              surOuvrir: () => _ouvrirYoutube(_items[_index].cleYoutube),
            ),
          ),
        // Bouton son en haut à droite (au-dessus du PageView → cliquable).
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _BoutonRond(
                icone: _muet ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                surTap: _basculerSon,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageInfos extends StatelessWidget {
  final ExtraitFeed extrait;
  final bool deja;
  final VoidCallback surTap;
  final VoidCallback surSuivre;
  final VoidCallback surDetail;

  const _PageInfos({
    required this.extrait,
    required this.deja,
    required this.surTap,
    required this.surSuivre,
    required this.surDetail,
  });

  String get _meta {
    final parts = <String>[
      if (extrait.annee != null) '${extrait.annee}',
      extrait.estSerie ? 'Série' : 'Film',
      if (extrait.noteMoyenne != null)
        '★ ${extrait.noteMoyenne!.toStringAsFixed(1)}',
    ];
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: surTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE60F172A), CouleursSW.fond],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(extrait.titre,
                    style: typo.headlineMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(_meta,
                    style: typo.bodySmall
                        ?.copyWith(color: CouleursSW.accentSecondaire)),
                if (extrait.apercu != null) ...[
                  const SizedBox(height: 10),
                  Text(extrait.apercu!,
                      style: typo.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: deja ? null : surSuivre,
                        icon: Icon(deja
                            ? Icons.check_rounded
                            : Icons.add_rounded),
                        label: Text(deja
                            ? 'Ajouté'
                            : (extrait.estSerie ? 'Suivre' : 'À voir')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: surDetail,
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('Détail'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  final IconData icone;
  final VoidCallback surTap;
  const _BoutonRond({required this.icone, required this.surTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: surTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icone, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Fond affiché à la place d'une bande-annonce non intégrable : l'affiche du
/// titre, assombrie, pour que l'écran reste soigné plutôt que « cassé ».
class _FondIndisponible extends StatelessWidget {
  final ExtraitFeed extrait;
  const _FondIndisponible({required this.extrait});

  @override
  Widget build(BuildContext context) {
    final url =
        urlImageTmdb(extrait.imageDeFond ?? extrait.affiche, largeur: 780);
    if (url == null) return const ColoredBox(color: CouleursSW.fond);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.45),
      colorBlendMode: BlendMode.darken,
      errorWidget: (_, _, _) => const ColoredBox(color: CouleursSW.fond),
    );
  }
}

/// Bouton de repli : ouvre la bande-annonce dans l'app YouTube.
class _RepliYoutube extends StatelessWidget {
  final VoidCallback surOuvrir;
  const _RepliYoutube({required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_off_outlined,
            color: Colors.white70, size: 40),
        const SizedBox(height: 10),
        Text('Bande-annonce non lisible ici',
            style: typo.bodySmall?.copyWith(color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: surOuvrir,
          icon: const Icon(Icons.smart_display_outlined),
          label: const Text('Regarder sur YouTube'),
        ),
      ],
    );
  }
}

class _MessageVide extends StatelessWidget {
  const _MessageVide();

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_outlined,
                size: 48, color: CouleursSW.texteSecondaire),
            const SizedBox(height: 16),
            Text('Aucun extrait disponible pour le moment.',
                style: typo.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  final String message;
  final VoidCallback surReessayer;
  const _Erreur({required this.message, required this.surReessayer});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: CouleursSW.texteSecondaire),
            const SizedBox(height: 12),
            Text(message, style: typo.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: surReessayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
