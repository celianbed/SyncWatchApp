// Squelettes de chargement. Ce qu'ils apportent n'est pas cosmétique : une
// page qui prend déjà sa forme paraît plus rapide qu'un disque qui tourne, et
// le contenu s'installe sans sursaut de mise en page.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/theme.dart';
import 'package:syncwatch_mobile/widgets/chargeur_async.dart';
import 'package:syncwatch_mobile/widgets/squelette.dart';

Future<void> monter(WidgetTester tester, Widget enfant,
    {bool animations = true}) async {
  await tester.pumpWidget(MaterialApp(
    theme: themeSyncWatch(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: !animations),
      child: Scaffold(body: enfant),
    ),
  ));
}

void main() {
  testWidgets('le squelette de fiche reprend la forme de la page',
      (tester) async {
    await monter(tester, const SqueletteFiche());
    // bandeau, titre, chips, notes, boutons, cartes de saison, synopsis
    expect(find.byType(Squelette), findsAtLeast(10));
  });

  testWidgets('« Réduire les animations » arrête la pulsation', (tester) async {
    // une pulsation permanente est pénible, voire nauséeuse, pour qui a activé
    // ce réglage système — le squelette doit alors rester immobile
    // porté sur le squelette lui-même : MaterialApp pose ses propres
    // FadeTransition pour les transitions de route
    Finder pulsation() => find.descendant(
        of: find.byType(Squelette), matching: find.byType(FadeTransition));

    await monter(tester, const Squelette(hauteur: 20), animations: false);
    expect(pulsation(), findsNothing);

    await monter(tester, const Squelette(hauteur: 20));
    expect(pulsation(), findsOneWidget);
  });

  group('ChargeurAsync', () {
    testWidgets('affiche le squelette fourni plutôt qu\'un spinner',
        (tester) async {
      await monter(
        tester,
        ChargeurAsync<int>(
          future: Completer<int>().future, // jamais résolu
          squelette: const SqueletteListe(nombre: 3),
          enfant: (_) => const Text('contenu'),
        ),
      );
      await tester.pump();

      expect(find.byType(Squelette), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('sans squelette, le spinner reste — attente courte et centrée',
        (tester) async {
      await monter(
        tester,
        ChargeurAsync<int>(
          future: Completer<int>().future,
          enfant: (_) => const Text('contenu'),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets('le réveil du serveur reste annoncé par-dessus le squelette',
      (tester) async {
    // sans ce mot, une ossature muette pendant la minute de réveil se lit
    // comme une application figée
    api = ClientApi(client: MockClient((_) async => http.Response(
        jsonEncode({'ok': true}), 200,
        headers: {'content-type': 'application/json'})));
    await monter(tester, const AvecMentionReveil(child: SqueletteListe()));
    expect(find.text('Réveil du serveur…'), findsNothing);

    api.reveil.value = true;
    await tester.pump();
    expect(find.text('Réveil du serveur…'), findsOneWidget);
  });
}
