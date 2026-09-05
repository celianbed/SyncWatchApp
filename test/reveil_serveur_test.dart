// L'API est hébergée sur une offre qui met le service en veille : le réveil peut
// dépasser la minute, alors que le client abandonnait à vingt secondes. Personne
// ne voyait jamais l'application démarrer. Ces tests verrouillent le rattrapage —
// et le fait qu'il ne s'applique qu'aux lectures.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';

/// Client dont les `premieres` réponses traînent au-delà du délai imparti,
/// les suivantes répondant normalement. Compte les tentatives.
class ReseauLent {
  int appels = 0;
  final int premieres;
  ReseauLent({this.premieres = 1});

  http.Client get client => MockClient((requete) async {
        appels++;
        if (appels <= premieres) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        return http.Response(jsonEncode({'ok': true}), 200,
            headers: {'content-type': 'application/json'});
      });
}

ClientApi _api(http.Client client) => ClientApi(
      client: client,
      delaiNormal: const Duration(milliseconds: 20),
      delaiReveil: const Duration(seconds: 5),
    );

void main() {
  test('une lecture lente est rejouée avec une fenêtre longue', () async {
    final reseau = ReseauLent();
    final api = _api(reseau.client);

    final donnees = await api.get('/utilisateurs/moi');

    expect(donnees, {'ok': true});
    expect(reseau.appels, 2, reason: 'la première tentative doit être rejouée');
  });

  test('le réveil est signalé pendant la seconde tentative, puis retombe',
      () async {
    final api = _api(ReseauLent().client);
    final vus = <bool>[];
    api.reveil.addListener(() => vus.add(api.reveil.value));

    await api.get('/utilisateurs/moi');

    expect(vus, [true, false], reason: 'les écrans doivent pouvoir afficher le réveil');
  });

  test('une écriture lente n\'est jamais rejouée', () async {
    // un délai dépassé ne dit pas que le serveur n'a rien fait : rejouer un POST
    // créerait un doublon (un avis, un compte, un abonnement…)
    final reseau = ReseauLent();
    final api = _api(reseau.client);

    await expectLater(
        api.post('/avis', corps: {'note': 8}), throwsA(isA<ExceptionApi>()));
    expect(reseau.appels, 1);
    expect(api.reveil.value, isFalse);
  });

  test('un serveur durablement muet finit par rendre la main', () async {
    final reseau = ReseauLent(premieres: 99);
    final api = ClientApi(
      client: reseau.client,
      delaiNormal: const Duration(milliseconds: 10),
      delaiReveil: const Duration(milliseconds: 30),
    );

    await expectLater(api.get('/accueil'), throwsA(isA<ExceptionApi>()));
    expect(reseau.appels, 2, reason: 'deux tentatives, pas davantage');
    expect(api.reveil.value, isFalse, reason: 'l\'indicateur ne doit pas rester allumé');
  });

  test('une erreur HTTP n\'est pas prise pour une panne réseau', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'detail': 'Ce pseudo est déjà pris.'}), 409,
        headers: {'content-type': 'application/json'}));

    try {
      await _api(client).get('/utilisateurs/moi');
      fail('une réponse 409 doit lever');
    } on ExceptionApi catch (e) {
      expect(e.code, 409);
      expect(e.message, 'Ce pseudo est déjà pris.');
    }
  });
}
