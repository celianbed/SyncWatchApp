// Les écrans ne se rechargeaient jamais : la coquille empile les onglets dans
// un IndexedStack, qui conserve leur état, et une douzaine d'écrans chargeaient
// leurs données une seule fois. On marquait un épisode vu, on revenait à
// l'accueil, et il affichait encore l'ancien.
//
// Le remède évident — recharger à chaque apparition — serait le mauvais : sur
// une offre gratuite qui endort le serveur, naviguer sans rien modifier
// paierait des allers-retours pour rien. Ces tests verrouillent la nuance.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/util/rafraichissement.dart';

/// Écran d'essai : compte ses rechargements, et sa visibilité se pilote.
class _Ecran extends StatefulWidget {
  final bool actif;
  const _Ecran({required this.actif});

  @override
  State<_Ecran> createState() => _EcranState();
}

class _EcranState extends State<_Ecran> with RafraichitSiPerime {
  static int rechargements = 0;

  @override
  bool get visible => widget.actif;

  @override
  void rafraichir() => rechargements++;

  @override
  void didUpdateWidget(_Ecran ancien) {
    super.didUpdateWidget(ancien);
    if (widget.actif && !ancien.actif) rafraichirSiNecessaire();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> monter(WidgetTester tester, {required bool actif}) =>
    tester.pumpWidget(MaterialApp(home: _Ecran(actif: actif)));

void main() {
  setUp(() {
    _EcranState.rechargements = 0;
    api = ClientApi(client: MockClient((_) async => http.Response(
        jsonEncode({'ok': true}), 200,
        headers: {'content-type': 'application/json'})));
  });

  testWidgets('une lecture ne périme rien', (tester) async {
    await monter(tester, actif: true);
    await api.get('/accueil');
    await tester.pump();

    expect(_EcranState.rechargements, 0,
        reason: 'naviguer sans rien modifier ne doit rien coûter');
  });

  testWidgets('une écriture recharge l\'écran visible', (tester) async {
    await monter(tester, actif: true);
    await api.post('/episodes/1/vu');
    await tester.pump();

    expect(_EcranState.rechargements, 1);
  });

  testWidgets('un onglet caché attend d\'être revu', (tester) async {
    await monter(tester, actif: false);
    await api.post('/episodes/1/vu');
    await tester.pump();
    expect(_EcranState.rechargements, 0, reason: 'inutile tant qu\'il est caché');

    await monter(tester, actif: true); // l'onglet revient au premier plan
    await tester.pump();
    expect(_EcranState.rechargements, 1);
  });

  testWidgets('revenir sur un onglet sans écriture ne recharge pas',
      (tester) async {
    await monter(tester, actif: false);
    await monter(tester, actif: true);
    await tester.pump();

    expect(_EcranState.rechargements, 0);
  });

  testWidgets('deux écritures ne provoquent qu\'un rechargement au retour',
      (tester) async {
    await monter(tester, actif: false);
    await api.post('/episodes/1/vu');
    await api.delete('/episodes/2/vu');
    await tester.pump();

    await monter(tester, actif: true);
    await tester.pump();

    expect(_EcranState.rechargements, 1);
  });

  testWidgets('une écriture échouée ne périme rien', (tester) async {
    api = ClientApi(client: MockClient((_) async =>
        http.Response('{"detail":"non"}', 400,
            headers: {'content-type': 'application/json'})));
    await monter(tester, actif: true);

    await expectLater(api.post('/episodes/1/vu'), throwsA(isA<ExceptionApi>()));
    await tester.pump();

    expect(_EcranState.rechargements, 0);
  });
}
