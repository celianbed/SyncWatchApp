// Rafraîchissement paresseux des écrans.
//
// La coquille empile les onglets dans un IndexedStack : leur état est conservé
// — c'est voulu, ça préserve la position de défilement — mais rien ne se
// recharge jamais. Et une douzaine d'écrans chargent leurs données une seule
// fois, à la construction. D'où l'accueil qui affiche encore l'épisode qu'on
// vient de marquer vu.
//
// Recharger à chaque apparition serait le remède évident et le mauvais : sur
// une offre gratuite qui met le serveur en veille, et avec les quotas TMDB, on
// paierait des allers-retours alors que naviguer sans rien modifier est le cas
// courant. On ne recharge donc que si une écriture a eu lieu entre-temps.
import 'package:flutter/widgets.dart';

import '../api/client_api.dart';

mixin RafraichitSiPerime<T extends StatefulWidget> on State<T> {
  int _revisionVue = 0;
  bool _perime = false;

  /// Recharge les données de l'écran. Appelée seulement quand c'est utile.
  void rafraichir();

  /// L'écran est-il à l'écran ? Les onglets d'un IndexedStack sont tous
  /// construits, mais un seul est visible : redéfinir pour ne pas recharger
  /// un onglet caché, qui le fera de toute façon en revenant au premier plan.
  bool get visible => true;

  @override
  void initState() {
    super.initState();
    _revisionVue = api.revision.value;
    api.revision.addListener(_surEcriture);
  }

  @override
  void dispose() {
    api.revision.removeListener(_surEcriture);
    super.dispose();
  }

  void _surEcriture() {
    if (api.revision.value == _revisionVue) return;
    _perime = true;
    if (visible) rafraichirSiNecessaire();
  }

  /// À appeler quand l'écran (re)devient visible : au changement d'onglet, ou
  /// au retour d'une fiche empilée par-dessus.
  void rafraichirSiNecessaire() {
    if (!_perime || !mounted) return;
    _perime = false;
    _revisionVue = api.revision.value;
    rafraichir();
  }

  /// À appeler juste avant une écriture dont l'écran applique déjà l'effet
  /// lui-même. Sans ça, sa révision déclencherait un rechargement complet
  /// alors que l'affichage est déjà juste.
  void ignorerProchaineEcriture() => _revisionVue = api.revision.value + 1;

  /// À appeler après un rechargement déclenché autrement (tiré pour
  /// rafraîchir), pour ne pas recharger une seconde fois juste après.
  void marquerAJour() {
    _perime = false;
    _revisionVue = api.revision.value;
  }
}
