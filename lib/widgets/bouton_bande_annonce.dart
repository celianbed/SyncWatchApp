// Bouton « Bande-annonce » des fiches série et film.
//
// La clé YouTube vient de l'API, qui applique le même classement que le feed
// « Extraits » (Trailer avant Teaser, officiel avant amateur, VF avant VO) :
// les deux montrent ainsi la même vidéo pour un titre donné.
//
// Le bouton ne s'affiche pas tant que la clé n'est pas connue : proposer une
// bande-annonce puis annoncer qu'il n'y en a pas serait pire que se taire.
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../api/client_api.dart';
import '../theme.dart';

class BoutonBandeAnnonce extends StatefulWidget {
  /// « series » ou « films » — le segment de l'API.
  final String type;
  final int referenceTmdb;
  final String titre;

  const BoutonBandeAnnonce({
    super.key,
    required this.type,
    required this.referenceTmdb,
    required this.titre,
  });

  @override
  State<BoutonBandeAnnonce> createState() => _BoutonBandeAnnonceState();
}

class _BoutonBandeAnnonceState extends State<BoutonBandeAnnonce> {
  String? _cle;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final donnees = await api
          .get('/${widget.type}/${widget.referenceTmdb}/bande-annonce');
      if (mounted) {
        setState(() => _cle = (donnees as Map<String, dynamic>)['cle_youtube']
            as String?);
      }
    } on ExceptionApi {
      // 404 = ce titre n'a pas de bande-annonce ; le bouton reste absent
    }
  }

  void _ouvrir() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeuilleLecteur(cle: _cle!, titre: widget.titre),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cle == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: _ouvrir,
        icon: const Icon(Icons.play_circle_outline, size: 20),
        label: const Text('Bande-annonce'),
      ),
    );
  }
}

/// Le lecteur, dans une feuille qu'on referme d'un geste. Le contrôleur est
/// créé et détruit ici : sortir de la feuille arrête la lecture, sans quoi le
/// son continuerait derrière la fiche.
class _FeuilleLecteur extends StatefulWidget {
  final String cle;
  final String titre;

  const _FeuilleLecteur({required this.cle, required this.titre});

  @override
  State<_FeuilleLecteur> createState() => _FeuilleLecteurState();
}

class _FeuilleLecteurState extends State<_FeuilleLecteur> {
  late final YoutubePlayerController _controleur;
  bool _indisponible = false;

  @override
  void initState() {
    super.initState();
    _controleur = YoutubePlayerController.fromVideoId(
      videoId: widget.cle,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        enableCaption: false,
        // origin: null → aucun param origin. La vraie origine est le serveur
        // local de la lib (cf. vendor/youtube_player_iframe).
        origin: null,
      ),
    );
    _controleur.stream.listen((valeur) {
      final casse = valeur.error != YoutubeError.none;
      if (casse != _indisponible && mounted) {
        setState(() => _indisponible = casse);
      }
    });
  }

  @override
  void dispose() {
    _controleur.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.titre,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: CouleursSW.texte),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _indisponible
                  // certaines vidéos interdisent l'intégration : le lecteur
                  // reste noir, autant l'expliquer et proposer YouTube.
                  ? Container(
                      color: CouleursSW.surface,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                            'Cette bande-annonce ne peut pas être lue ici.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center),
                      ),
                    )
                  : YoutubePlayer(
                      controller: _controleur, aspectRatio: 16 / 9),
            ),
          ],
        ),
      ),
    );
  }
}
