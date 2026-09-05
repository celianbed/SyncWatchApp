// Boutons de connexion externe : ce qui s'affiche dépend de la plateforme, et
// pour Google, de la présence d'un identifiant de client iOS.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:syncwatch_mobile/api/session.dart';
import 'package:syncwatch_mobile/ecrans/ecran_connexion.dart';

/// Affiche l'écran de connexion en se faisant passer pour `plateforme`, puis
/// joue `verifications`. L'override est remis à zéro quoi qu'il arrive : le
/// framework de test refuse qu'une variable de debug survive au test.
Future<void> surPlateforme(WidgetTester tester, TargetPlatform plateforme,
    Future<void> Function() verifications) async {
  debugDefaultTargetPlatformOverride = plateforme;
  try {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => Session(),
      child: const MaterialApp(home: EcranConnexion()),
    ));
    await tester.pump();
    await verifications();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('sur iOS, le bouton Apple est proposé', (tester) async {
    await surPlateforme(tester, TargetPlatform.iOS, () async {
      expect(find.byType(SignInWithAppleButton), findsOneWidget);
    });
  });

  testWidgets('sur iOS, Google reste masqué tant que le client iOS manque',
      (tester) async {
    // googleClientIdIos est vide : afficher le bouton ferait échouer le plugin
    // nativement au premier tap. Il doit donc rester invisible.
    expect(googleClientIdIos, isEmpty);
    await surPlateforme(tester, TargetPlatform.iOS, () async {
      expect(find.text('Continuer avec Google'), findsNothing);
    });
  });

  testWidgets('sur Android, Google est proposé et Apple non', (tester) async {
    await surPlateforme(tester, TargetPlatform.android, () async {
      expect(find.text('Continuer avec Google'), findsOneWidget);
      expect(find.byType(SignInWithAppleButton), findsNothing);
    });
  });

  testWidgets('le bouton Apple précède celui de Google quand les deux sont là',
      (tester) async {
    // Exigence Apple : son bouton ne doit pas être moins visible que les autres.
    // Ce test ne dit quelque chose que le jour où Google est activé sur iOS.
    if (googleClientIdIos.isEmpty) {
      markTestSkipped('googleClientIdIos vide : Google est masqué sur iOS');
      return;
    }
    await surPlateforme(tester, TargetPlatform.iOS, () async {
      final apple = tester.getTopLeft(find.byType(SignInWithAppleButton)).dy;
      final google = tester.getTopLeft(find.text('Continuer avec Google')).dy;
      expect(apple, lessThan(google));
    });
  });
}
