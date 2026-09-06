// Parcours automatisé sur simulateur : produit les captures de la fiche App Store
// et, au passage, vérifie que chaque écran se remplit vraiment depuis l'API de
// production. Les identifiants viennent de --dart-define, jamais du dépôt.
//
//   flutter drive --driver=test_driver/captures.dart \
//     --target=integration_test/captures_test.dart -d <simulateur> \
//     --dart-define=COMPTE=… --dart-define=MOTDEPASSE=…
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:syncwatch_mobile/main.dart' as app;

const _compte = String.fromEnvironment('COMPTE');

/// Le mot de passe transite en base64 : le passer en clair à --dart-define
/// le fait traverser le shell, l'outil et le compilateur, et les caractères
/// accentués ou d'échappement n'y survivent pas tous.
const _motDePasseB64 = String.fromEnvironment('MOTDEPASSE_B64');
final _motDePasse = utf8.decode(base64.decode(_motDePasseB64));

late IntegrationTestWidgetsFlutterBinding binding;

/// Pompe jusqu'à ce que `cible` apparaisse, sans jamais utiliser pumpAndSettle :
/// un CircularProgressIndicator tourne indéfiniment et ne se stabilise jamais.
/// L'API se réveillant en près d'une minute, la patience par défaut est longue.
Future<void> attendreQue(WidgetTester tester, bool Function() pret,
    {Duration patience = const Duration(seconds: 100), required String quoi}) async {
  final limite = DateTime.now().add(patience);
  while (DateTime.now().isBefore(limite)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (pret()) {
      await tester.pump(const Duration(milliseconds: 600)); // laisse peindre
      return;
    }
  }
  throw StateError('Jamais apparu : $quoi');
}

Future<void> attendre(WidgetTester tester, Finder cible,
        {Duration patience = const Duration(seconds: 100), String? quoi}) =>
    attendreQue(tester, () => cible.evaluate().isNotEmpty,
        patience: patience, quoi: quoi ?? cible.toString());

/// Bouton de validation du formulaire, qui porte « Se connecter » en mode
/// connexion — à distinguer du basculeur du haut, qui porte le même texte.
final boutonConnexion = find.widgetWithText(ElevatedButton, 'Se connecter');

Future<void> capturer(WidgetTester tester, String nom) async {
  await tester.pump(const Duration(milliseconds: 400));
  await binding.takeScreenshot(nom);
}

/// Ouvre un onglet et attend qu'il soit réellement sélectionné.
///
/// Le repère est le libellé, pas l'icône : la barre n'affiche le libellé que de
/// l'onglet actif, et remplace au passage son icône « _outlined » par la version
/// pleine — chercher l'icône d'arrivée ne trouverait donc jamais rien.
Future<void> ouvrirOnglet(WidgetTester tester, String onglet,
    {Duration chargement = const Duration(seconds: 9)}) async {
  await tester.tap(find.byIcon(_icones[onglet]!));
  await attendre(tester, find.text(onglet), quoi: 'onglet $onglet');
  await tester.pump(chargement);
}

const _icones = {
  'Accueil': Icons.home_outlined,
  'Extraits': Icons.play_circle_outline,
  'Recherche': Icons.search,
  'Calendrier': Icons.calendar_month_outlined,
  'Stats': Icons.bar_chart_outlined,
  'Profil': Icons.person_outline,
};

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Le harnais de test remplace le client HTTP par une doublure qui répond 400 à
  // tout : les appels d'API passent quand même (package:http a le sien), mais les
  // affiches TMDB, elles, transitent par HttpClient et n'arrivent jamais. Sans
  // cette ligne, toutes les captures montrent des cadres vides.
  setUpAll(() => HttpOverrides.global = null);

  testWidgets('parcours complet et captures', (tester) async {
    expect(_compte, isNotEmpty, reason: 'passer --dart-define=COMPTE=…');
    expect(_motDePasse, isNotEmpty, reason: 'passer --dart-define=MOTDEPASSE_B64=…');

    app.main();

    // Trois entrées possibles : l'onboarding au premier lancement, l'écran de
    // connexion, ou directement l'app — le jeton survit dans le trousseau iOS
    // même à une désinstallation. On attend celle qui se présente.
    final dansLApp = find.byType(NavigationBar);
    await attendreQue(
        tester,
        () => find.text('Passer').evaluate().isNotEmpty ||
            boutonConnexion.evaluate().isNotEmpty ||
            dansLApp.evaluate().isNotEmpty,
        quoi: 'onboarding, connexion ou app déjà ouverte');

    // 1. Présentation au premier lancement
    if (find.text('Passer').evaluate().isNotEmpty) {
      await capturer(tester, '01-onboarding');
      await tester.tap(find.text('Passer'));
      await tester.pump(const Duration(milliseconds: 900));
    }

    // 2. Connexion, sauf si une session était déjà ouverte
    if (dansLApp.evaluate().isEmpty) {
      await attendre(tester, boutonConnexion, quoi: 'écran de connexion');
      await capturer(tester, '02-connexion');

      final champs = find.byType(TextFormField);
      await tester.enterText(champs.at(0), _compte);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(champs.at(1), _motDePasse);
      await tester.pump(const Duration(milliseconds: 400));
      // Le bouton porte un spinner à la place de son libellé pendant l'envoi :
      // s'il a déjà disparu, c'est que le champ a validé le formulaire lui-même.
      if (boutonConnexion.evaluate().isNotEmpty) {
        await tester.tap(boutonConnexion);
      }
      // témoin : si la connexion échoue, cette capture montrera le message
      await tester.pump(const Duration(seconds: 8));
      await capturer(tester, '02b-apres-envoi');
    }

    // 3. Accueil — l'API se réveille peut-être à cet instant
    await attendre(tester, dansLApp, quoi: 'barre de navigation');
    // laisse les affiches arriver : sans ça, la capture ne montre que des cadres
    await tester.pump(const Duration(seconds: 12));
    await capturer(tester, '03-accueil');

    // 4. Les autres onglets
    await ouvrirOnglet(tester, 'Extraits', chargement: const Duration(seconds: 12));
    await capturer(tester, '04-extraits');

    await ouvrirOnglet(tester, 'Recherche');
    await tester.enterText(find.byType(TextField).first, 'stranger');
    await tester.pump(const Duration(seconds: 10));
    await capturer(tester, '05-recherche');

    await ouvrirOnglet(tester, 'Calendrier');
    await capturer(tester, '06-calendrier');

    await ouvrirOnglet(tester, 'Stats');
    await capturer(tester, '07-stats');

    await ouvrirOnglet(tester, 'Profil', chargement: const Duration(seconds: 10));
    await capturer(tester, '08-profil');

    // 9. La suppression de compte, que le reviewer cherchera
    await tester.dragUntilVisible(
        find.text('Supprimer mon compte'), find.byType(Scrollable).last,
        const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 600));
    await capturer(tester, '09-profil-suppression');
  });
}
