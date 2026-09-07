// Cocher un épisode ne doit rien recharger : les saisons déjà en cache portent
// l'état vu de chacun, donc le prochain épisode se calcule sur place. Le
// serveur n'est prévenu qu'ensuite, et l'écran ne se recharge qu'en cas de
// refus. C'est ce qui manquait aux corrections précédentes — je demandais au
// serveur quel épisode afficher ensuite alors que je le savais déjà.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/ecrans/ecran_accueil.dart';
import 'package:syncwatch_mobile/theme.dart';

const _ref = 1399;

class ApiAccueil {
  final appels = <String>[];
  bool refuseEcriture = false;

  Map<String, Object?> _episode(int id, int num, bool vu) => {
        'id_episode': id,
        'num_episode': num,
        'titre': 'Épisode $num',
        'duree': 50,
        'date_diffusion': '2011-04-17',
        'vu': vu,
      };

  http.Client get client => MockClient((requete) async {
        final chemin = requete.url.path;
        appels.add('${requete.method} $chemin');
        Object? corps;

        if (requete.method != 'GET') {
          if (refuseEcriture) {
            return http.Response('{"detail":"Épisode introuvable."}', 404,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response('', 204);
        }

        if (chemin == '/accueil') {
          corps = [
            {
              'serie': {
                'id_serie': 1,
                'reference_tmdb': _ref,
                'titre': 'Game of Thrones',
                'affiche': null,
              },
              'episode': {
                'id_episode': 101,
                'num_saison': 1,
                'num_episode': 1,
                'titre': 'Épisode 1',
                'duree': 50,
                'date_diffusion': '2011-04-17',
                'vignette': null,
                'deja_diffuse': true,
              },
            }
          ];
        } else if (chemin == '/series/$_ref/saisons') {
          corps = [
            {
              'id_saison': 1,
              'num_saison': 1,
              'titre': null,
              'episodes': [
                _episode(101, 1, false),
                _episode(102, 2, false),
              ],
            }
          ];
        } else {
          corps = <Object>[]; // tendances, nouveautés
        }
        return http.Response(jsonEncode(corps), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

Future<void> ouvrir(WidgetTester tester, ApiAccueil faux) async {
  api = ClientApi(client: faux.client);
  await tester.pumpWidget(MaterialApp(
      theme: themeSyncWatch(),
      home: const Scaffold(body: EcranAccueil(actif: true))));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Restreint aux cartes : la SnackBar de confirmation reprend le code de
/// l'épisode, et fausserait les recherches de texte.
Finder dansUneCarte(String texte) => find.descendant(
    of: find.byType(Card), matching: find.textContaining(texte));

void main() {
  testWidgets('cocher avance l\'épisode sans rien recharger', (tester) async {
    final faux = ApiAccueil();
    await ouvrir(tester, faux);
    expect(dansUneCarte('S01E01'), findsOneWidget);

    faux.appels.clear();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump(const Duration(milliseconds: 400));

    expect(dansUneCarte('S01E02'), findsOneWidget,
        reason: 'le prochain épisode vient du cache local');
    expect(faux.appels, ['POST /episodes/101/vu'],
        reason: 'une seule écriture, aucun rechargement');
  });

  testWidgets('la dernière série cochée quitte la liste', (tester) async {
    final faux = ApiAccueil();
    await ouvrir(tester, faux);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump(const Duration(milliseconds: 300));

    // plus rien de diffusé à voir : la carte disparaît, comme le ferait l'API
    expect(dansUneCarte('S01E'), findsNothing);
    expect(find.textContaining('Rien à suivre'), findsOneWidget);
  });

  testWidgets('un refus du serveur remet l\'écran comme il était',
      (tester) async {
    final faux = ApiAccueil();
    await ouvrir(tester, faux);
    faux.refuseEcriture = true;

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump(const Duration(milliseconds: 400));

    expect(dansUneCarte('S01E01'), findsOneWidget,
        reason: 'retour à l\'épisode d\'avant');
    expect(find.text('Épisode introuvable.'), findsOneWidget);
  });
}
