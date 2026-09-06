// Blocage et signalement côté app. Ce que vérifient ces tests, c'est surtout
// ce qu'Apple regarde : que les deux gestes existent, qu'ils soient
// atteignables, et que le blocage annonce ses conséquences avant d'agir.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/ecrans/ecran_blocages.dart';
import 'package:syncwatch_mobile/theme.dart';
import 'package:syncwatch_mobile/widgets/moderation.dart';

final appels = <String>[];

http.Client _reseau({List<Map<String, Object?>> blocages = const []}) =>
    MockClient((requete) async {
      appels.add('${requete.method} ${requete.url.path}');
      if (requete.url.path == '/utilisateurs/moi/blocages') {
        return http.Response(jsonEncode(blocages), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (requete.method == 'DELETE') return http.Response('', 204);
      return http.Response(jsonEncode({'statut': 'bloque'}), 201,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Map<String, Object?> _resume(String pseudo) => {
      'id_utilisateur': 2,
      'pseudo': pseudo,
      'avatar': null,
      'nb_series': 0,
      'nb_films': 0,
      'est_abonne': false,
      'me_suit': false,
    };

/// Écran minimal portant un bouton qui déclenche l'action à tester.
Future<void> monterAction(
    WidgetTester tester, Future<void> Function(BuildContext) action) async {
  await tester.pumpWidget(MaterialApp(
    theme: themeSyncWatch(),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
            onPressed: () => action(context), child: const Text('agir')),
      ),
    ),
  ));
  await tester.tap(find.text('agir'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    appels.clear();
    api = ClientApi(client: _reseau());
  });

  group('signalement', () {
    testWidgets('les motifs sont proposés, et le délai annoncé', (tester) async {
      await monterAction(tester,
          (c) => ouvrirSignalement(c, idAvis: 7, quoi: 'cet avis'));

      expect(find.text('Signaler cet avis'), findsOneWidget);
      expect(find.textContaining('24 heures'), findsOneWidget);
      expect(find.text('Propos haineux'), findsOneWidget);
      expect(find.text('Harcèlement'), findsOneWidget);
    });

    testWidgets('choisir un motif envoie le signalement', (tester) async {
      await monterAction(tester,
          (c) => ouvrirSignalement(c, idAvis: 7, quoi: 'cet avis'));
      await tester.tap(find.text('Spam ou publicité'));
      await tester.pumpAndSettle();

      expect(appels, contains('POST /signalements'));
      expect(find.textContaining('Signalement envoyé'), findsOneWidget);
    });

    testWidgets('refermer sans choisir n\'envoie rien', (tester) async {
      await monterAction(tester,
          (c) => ouvrirSignalement(c, idVise: 2, quoi: 'Kenan'));
      await tester.tapAt(const Offset(200, 50)); // hors de la feuille
      await tester.pumpAndSettle();

      expect(appels, isNot(contains('POST /signalements')));
    });
  });

  group('blocage', () {
    testWidgets('les conséquences sont annoncées avant d\'agir', (tester) async {
      await monterAction(tester,
          (c) => confirmerBlocage(c, idUtilisateur: 2, pseudo: 'Kenan'));

      expect(find.text('Bloquer Kenan ?'), findsOneWidget);
      expect(find.textContaining('abonnements mutuels seront rompus'),
          findsOneWidget);
      expect(find.textContaining('n\'en sera pas informée'), findsOneWidget);
      expect(appels, isEmpty, reason: 'rien avant confirmation');
    });

    testWidgets('annuler ne bloque pas', (tester) async {
      await monterAction(tester,
          (c) => confirmerBlocage(c, idUtilisateur: 2, pseudo: 'Kenan'));
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(appels, isEmpty);
    });

    testWidgets('confirmer bloque', (tester) async {
      await monterAction(tester,
          (c) => confirmerBlocage(c, idUtilisateur: 2, pseudo: 'Kenan'));
      await tester.tap(find.widgetWithText(TextButton, 'Bloquer'));
      await tester.pumpAndSettle();

      expect(appels, contains('POST /utilisateurs/2/bloquer'));
    });
  });

  group('liste des blocages', () {
    Future<void> ouvrir(WidgetTester tester,
        {List<Map<String, Object?>> blocages = const []}) async {
      api = ClientApi(client: _reseau(blocages: blocages));
      await tester.pumpWidget(MaterialApp(
          theme: themeSyncWatch(), home: const EcranBlocages()));
      await tester.pumpAndSettle();
    }

    testWidgets('vide, l\'écran le dit', (tester) async {
      await ouvrir(tester);
      expect(find.textContaining('n\'as bloqué personne'), findsOneWidget);
    });

    testWidgets('débloquer est possible — sinon le blocage serait sans retour',
        (tester) async {
      await ouvrir(tester, blocages: [_resume('Kenan')]);
      expect(find.text('Kenan'), findsOneWidget);

      await tester.tap(find.text('Débloquer'));
      await tester.pumpAndSettle();

      expect(appels, contains('DELETE /utilisateurs/2/bloquer'));
    });
  });
}
