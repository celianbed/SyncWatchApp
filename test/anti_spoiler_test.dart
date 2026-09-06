// Anti-spoiler : l'API retire le commentaire d'un ami plus avancé que vous
// dans la série. L'app doit le dire, et surtout garder la note — un chiffre
// ne divulgue rien, et c'est justement l'information utile.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/theme.dart';
import 'package:syncwatch_mobile/widgets/avis_abonnements.dart';

http.Client _reseau({required bool masque}) => MockClient((_) async {
      final corps = [
        {
          'id_avis': 1,
          'utilisateur': {'id_utilisateur': 2, 'pseudo': 'Kenan', 'avatar': null},
          'id_serie': 1,
          'id_film': null,
          'id_episode': null,
          'note': 9,
          'commentaire': masque ? null : 'La fin est incroyable.',
          'date_creation': '2026-09-06T12:00:00',
          'date_modification': null,
          'masque': masque,
        }
      ];
      return http.Response(jsonEncode(corps), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> monter(WidgetTester tester, {required bool masque}) async {
  api = ClientApi(client: _reseau(masque: masque));
  await tester.pumpWidget(MaterialApp(
    theme: themeSyncWatch(),
    home: const Scaffold(
        body: SingleChildScrollView(
            child: AvisAbonnements(cle: 'id_serie', id: 1))),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('un avis masqué explique pourquoi, et garde la note',
      (tester) async {
    await monter(tester, masque: true);

    expect(find.textContaining('Kenan est plus avancé que toi'), findsOneWidget);
    expect(find.text('★ 9/10'), findsOneWidget,
        reason: 'la note ne divulgue rien : c\'est tout l\'intérêt');
    expect(find.textContaining('La fin est incroyable'), findsNothing);
  });

  testWidgets('un avis non masqué s\'affiche normalement', (tester) async {
    await monter(tester, masque: false);

    expect(find.text('La fin est incroyable.'), findsOneWidget);
    expect(find.textContaining('plus avancé'), findsNothing);
  });
}
