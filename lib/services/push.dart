// Push notifications — Android (FCM) et iOS (FCM relayé vers APNs).
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../ecrans/ecran_fiche_film.dart';
import '../ecrans/ecran_fiche_serie.dart';

/// Navigateur racine : permet d'ouvrir une fiche depuis un tap sur une notification.
final navigatorKey = GlobalKey<NavigatorState>();

/// Réception en arrière-plan / app terminée (doit être top-level).
/// Le système affiche la notif tout seul (payload « notification ») : rien à faire.
@pragma('vm:entry-point')
Future<void> _surMessageArrierePlan(RemoteMessage message) async {}

abstract final class Push {
  static bool _fait = false;
  static int? _idAppareil; // pour désinscrire l'appareil à la déconnexion

  /// À appeler une fois connecté (le POST /appareils exige le jeton). Idempotent.
  static Future<void> initialiser() async {
    if (_fait) return;
    _fait = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      final autorisation = await messaging.requestPermission();
      if (autorisation.authorizationStatus == AuthorizationStatus.denied) {
        // refus : inutile d'enregistrer un appareil qui ne recevra rien.
        // Tracé, sinon l'absence de push est indiscernable d'une panne.
        debugPrint('Push : notifications refusées par l\'utilisateur '
            '(Réglages > SyncWatch > Notifications)');
        return;
      }
      debugPrint('Push : autorisation ${autorisation.authorizationStatus}');
      FirebaseMessaging.onBackgroundMessage(_surMessageArrierePlan);
      // sans ça, iOS n'affiche aucune notification quand l'app est au premier plan
      await messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      final jeton = await _jetonFcm(messaging);
      if (jeton == null) {
        debugPrint('Push : aucun jeton FCM, appareil non enregistré');
      } else {
        await _enregistrer(jeton);
      }
      messaging.onTokenRefresh.listen(_enregistrer);

      // tap sur la notif → ouvre la fiche (app en fond, puis app lancée à froid)
      FirebaseMessaging.onMessageOpenedApp.listen(_ouvrir);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _ouvrir(initial);
    } catch (e) {
      _fait = false; // on pourra réessayer (ex. Firebase pas encore configuré)
      debugPrint('Push : initialisation impossible ($e)');
    }
  }

  /// Sur iOS, FCM ne peut rien donner tant qu'APNs ne lui a pas remis son jeton,
  /// qui arrive un court instant après le lancement — d'où les tentatives.
  /// Le simulateur, lui, n'en fournit jamais : on abandonne proprement.
  static Future<String?> _jetonFcm(FirebaseMessaging messaging) async {
    if (Platform.isIOS) {
      var jetonApns = await messaging.getAPNSToken();
      for (var essai = 0; jetonApns == null && essai < 5; essai++) {
        await Future.delayed(const Duration(seconds: 1));
        jetonApns = await messaging.getAPNSToken();
      }
      if (jetonApns == null) {
        debugPrint('Push : aucun jeton APNs après 5 tentatives '
            '(simulateur, capability absente, ou clé APNs manquante dans Firebase)');
        return null;
      }
    }
    return messaging.getToken();
  }

  static Future<void> _enregistrer(String jeton) async {
    try {
      final reponse = await api.post('/appareils', corps: {
        'jeton_notif': jeton,
        'plateforme': Platform.isIOS ? 'ios' : 'android',
      }) as Map<String, dynamic>;
      _idAppareil = reponse['id_appareil'] as int?;
      debugPrint('Push : appareil enregistré (id $_idAppareil)');
    } catch (e) {
      // l'app reste utilisable sans push, mais l'échec était jusqu'ici muet :
      // une table `appareil` vide ne disait pas si le POST avait échoué,
      // si le jeton manquait, ou si l'autorisation avait été refusée.
      debugPrint('Push : enregistrement de l\'appareil refusé — $e');
    }
  }

  /// À la déconnexion : cet appareil ne doit plus recevoir les notifs du compte
  /// quitté. À appeler tant que le jeton d'accès est encore valide.
  static Future<void> oublier() async {
    final id = _idAppareil;
    _idAppareil = null;
    _fait = false; // la prochaine connexion réenregistrera l'appareil
    if (id == null) return;
    try {
      await api.delete('/appareils/$id');
    } catch (_) {
      // hors ligne : le jeton sera de toute façon réattribué au prochain compte
    }
  }

  static void _ouvrir(RemoteMessage message) {
    final ref = int.tryParse(message.data['reference_tmdb'] ?? '');
    if (ref == null) return;
    navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => message.data['cible'] == 'film'
            ? EcranFicheFilm(referenceTmdb: ref)
            : EcranFicheSerie(referenceTmdb: ref)));
  }
}
