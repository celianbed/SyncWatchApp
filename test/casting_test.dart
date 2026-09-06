// Section « Distribution ». Ce qui compte ici n'est pas la liste — TMDB la
// donne à tout le monde — mais le compteur « déjà vu·e dans N titres », calculé
// sur l'historique. Il ne doit apparaître que lorsqu'il dit quelque chose.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/theme.dart';
import 'package:syncwatch_mobile/widgets/section_casting.dart';

http.Client _reseau(List<Map<String, Object?>> casting) =>
    MockClient((_) async => http.Response(jsonEncode(casting), 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));

http.Client _absent() => MockClient((_) async =>
    http.Response('{"detail":"Série absente du cache."}', 404,
        headers: {'content-type': 'application/json; charset=utf-8'}));

Map<String, Object?> _membre(String nom, {int dejaVu = 0, String? role}) => {
      'id_acteur': nom.hashCode,
      'nom': nom,
      'photo': null,
      'personnage': role,
      'deja_vu_dans': dejaVu,
    };

Future<void> monter(WidgetTester tester, http.Client client) async {
  api = ClientApi(client: client);
  await tester.pumpWidget(MaterialApp(
    theme: themeSyncWatch(),
    home: const Scaffold(
        body: SectionCasting(type: 'series', referenceTmdb: 4901)),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('la distribution s\'affiche avec les personnages', (tester) async {
    await monter(tester, _reseau([_membre('Alba Rivas', role: 'Nora')]));

    expect(find.text('Distribution'), findsOneWidget);
    expect(find.text('Alba Rivas'), findsOneWidget);
    expect(find.text('Nora'), findsOneWidget);
  });

  testWidgets('le compteur n\'apparaît que s\'il dit quelque chose',
      (tester) async {
    await monter(tester, _reseau([
      _membre('Alba Rivas', dejaVu: 3),
      _membre('Jasper Roy'),
    ]));

    expect(find.text('Déjà vu·e dans 3 titres'), findsOneWidget);
    expect(find.textContaining('Déjà vu·e dans 0'), findsNothing);
  });

  testWidgets('le singulier est accordé', (tester) async {
    await monter(tester, _reseau([_membre('Alba Rivas', dejaVu: 1)]));
    expect(find.text('Déjà vu·e dans 1 titre'), findsOneWidget);
  });

  testWidgets('un titre absent du cache ne montre aucune section',
      (tester) async {
    // la fiche reste lisible : mieux vaut se taire qu'afficher une erreur
    await monter(tester, _absent());
    expect(find.text('Distribution'), findsNothing);
  });
}
