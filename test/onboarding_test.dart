// La présentation ne se revoyait jamais : son drapeau était rangé dans le
// trousseau, qui survit à la désinstallation de l'app. Ces tests verrouillent
// la distinction — le jeton reste au trousseau (volontairement), le drapeau
// d'interface part avec l'app.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncwatch_mobile/api/session.dart';
import 'package:syncwatch_mobile/ecrans/ecran_onboarding.dart';
import 'package:syncwatch_mobile/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('persistance du drapeau', () {
    test('une réinstallation revoit la présentation', () async {
      // ce qu'on simule : le trousseau a survécu (ancien drapeau compris),
      // les préférences non — c'est exactement une réinstallation.
      FlutterSecureStorage.setMockInitialValues({'onboarding_vu': '1'});
      final session = Session();

      await session.restaurer();

      expect(session.onboardingVu, isFalse,
          reason: 'le drapeau ne doit plus vivre dans le trousseau');
    });

    test('une fois vue, elle ne revient pas au lancement suivant', () async {
      await Session().terminerOnboarding();

      final session = Session();
      await session.restaurer();

      expect(session.onboardingVu, isTrue);
    });
  });

  group('carrousel', () {
    Future<void> ouvrir(WidgetTester tester) async {
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => Session(),
        child: MaterialApp(
            theme: themeSyncWatch(), home: const EcranOnboarding()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('trois diapos, la dernière invitant à commencer',
        (tester) async {
      await ouvrir(tester);
      expect(find.textContaining('au même endroit'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('où tu t’étais arrêté'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('aucune sortie'), findsOneWidget);
      expect(find.text('C’est parti !'), findsOneWidget);
    });

    testWidgets('les maquettes ne chargent aucune image distante',
        (tester) async {
      // c'est la raison d'être du choix de les redessiner : au premier
      // lancement, le réseau peut être lent ou absent, et un cadre vide
      // ferait une piètre première impression.
      await ouvrir(tester);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(FadeInImage), findsNothing);
    });

    testWidgets('« Passer » termine la présentation', (tester) async {
      await ouvrir(tester);
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      expect((await SharedPreferences.getInstance()).getBool('onboarding_vu'),
          isTrue);
    });
  });
}
