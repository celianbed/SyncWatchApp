// Bouton « Bande-annonce » des fiches. Le point délicat : tous les titres n'en
// ont pas, et un bouton qui annonce une vidéo pour ensuite dire qu'il n'y en a
// pas serait pire que pas de bouton du tout.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/theme.dart';
import 'package:syncwatch_mobile/widgets/bouton_bande_annonce.dart';

/// [cle] nulle = l'API répond 404, comme pour un titre sans bande-annonce.
http.Client _reseau({String? cle, List<String>? appels}) =>
    MockClient((requete) async {
      appels?.add(requete.url.path);
      if (cle == null) {
        return http.Response('{"detail":"Aucune bande-annonce disponible."}', 404,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode({'cle_youtube': cle}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> monter(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: themeSyncWatch(),
    home: const Scaffold(
      body: BoutonBandeAnnonce(
          type: 'films', referenceTmdb: 550, titre: 'Fight Club'),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('le bouton apparaît quand une bande-annonce existe',
      (tester) async {
    api = ClientApi(client: _reseau(cle: 'abc123'));
    await monter(tester);
    expect(find.widgetWithText(OutlinedButton, 'Bande-annonce'), findsOneWidget);
  });

  testWidgets('aucun bouton si le titre n\'a pas de bande-annonce',
      (tester) async {
    api = ClientApi(client: _reseau());
    await monter(tester);
    expect(find.text('Bande-annonce'), findsNothing);
  });

  testWidgets('la clé est demandée à la bonne route', (tester) async {
    final appels = <String>[];
    api = ClientApi(client: _reseau(cle: 'abc123', appels: appels));
    await monter(tester);
    expect(appels, contains('/films/550/bande-annonce'));
  });

  // L'ouverture de la feuille n'est pas couverte : YoutubePlayer s'appuie sur
  // webview_flutter, qui n'a pas d'implémentation de plateforme en test
  // unitaire. La simuler reviendrait à tester la bibliothèque tierce plutôt que
  // notre code — les trois cas ci-dessus couvrent ce qui nous appartient.
}
