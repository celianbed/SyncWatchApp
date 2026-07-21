// Push notifications FCM — Android uniquement (iOS = APNs, compte Apple requis).
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
/// Android affiche la notif système tout seul (payload « notification ») : rien à faire.
@pragma('vm:entry-point')
Future<void> _surMessageArrierePlan(RemoteMessage message) async {}

abstract final class Push {
  static bool _fait = false;

  /// À appeler une fois connecté (le POST /appareils exige le jeton). Idempotent.
  static Future<void> initialiser() async {
    if (_fait || !Platform.isAndroid) return;
    _fait = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      FirebaseMessaging.onBackgroundMessage(_surMessageArrierePlan);

      final jeton = await messaging.getToken();
      if (jeton != null) await _enregistrer(jeton);
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

  static Future<void> _enregistrer(String jeton) async {
    try {
      await api.post('/appareils',
          corps: {'jeton_notif': jeton, 'plateforme': 'android'});
    } catch (_) {
      // déjà enregistré ou API indisponible : sans gravité
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
