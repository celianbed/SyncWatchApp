// Un épisode marqué vu ne se décochait pas, et « Tout marquer vu » n'avait
// aucune marche arrière. Ces tests verrouillent les deux bascules — et le fait
// que l'affichage change avant la réponse du serveur.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/ecrans/ecran_fiche_serie.dart';
import 'package:syncwatch_mobile/theme.dart';

const _ref = 1399;

/// Réseau doublé qui tient l'état vu des épisodes comme le ferait l'API.
class ApiSerie {
  /// id d'épisode -> vu. S01E01 et S01E02, tous deux diffusés.
  final vus = <int, bool>{101: false, 102: false};
  final appels = <String>[];

  /// Bloque les écritures jusqu'à libération : permet de vérifier que
  /// l'affichage a déjà changé alors que le serveur n'a pas répondu.
  Completer<void>? barriere;

  /// Fait échouer toute écriture, pour vérifier le retour en arrière.
  bool ecrituresRefusees = false;

  Map<String, Object?> get _saisons => {
        'id_saison': 1,
        'num_saison': 1,
        'titre': null,
        'episodes': [
          for (final id in vus.keys)
            {
              'id_episode': id,
              'num_episode': id - 100,
              'titre': 'Épisode ${id - 100}',
              'duree': 55,
              'date_diffusion': '2011-04-17',
              'vu': vus[id],
            }
        ],
      };

  http.Client get client => MockClient((requete) async {
        final chemin = requete.url.path;
        appels.add('${requete.method} $chemin');
        Object? corps;

        // le PATCH du suivi sert à lire l'état : seules les bascules sont
        // concernées par la barrière et par le refus.
        final bascule = chemin.startsWith('/episodes/') ||
            chemin.startsWith('/saisons/');
        if (bascule && requete.method != 'GET') {
          await barriere?.future;
          if (ecrituresRefusees) {
            return http.Response('{"detail":"Épisode introuvable."}', 404,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
        }

        if (chemin == '/series/$_ref') {
          corps = {
            'id_serie': 1,
            'reference_tmdb': _ref,
            'titre': 'Game of Thrones',
            'synopsis': null,
            'affiche': null,
            'image_de_fond': null,
            'statut_diffusion': 'Ended',
            'date_premiere_diffusion': '2011-04-17',
            'note_moyenne_tmdb': 8.4,
            'genres': <Object>[],
          };
        } else if (chemin == '/series/$_ref/saisons') {
          corps = [_saisons];
        } else if (chemin == '/series/$_ref/suivre') {
          corps = {'statut_suivi': 'en_cours', 'favori': false};
        } else if (chemin.startsWith('/episodes/')) {
          final id = int.parse(chemin.split('/')[2]);
          vus[id] = requete.method == 'POST';
          if (requete.method == 'DELETE') return http.Response('', 204);
          corps = {
            'id_episode': id,
            'date_visionnage': '2026-09-06T20:00:00',
            'nombre_revisionnage': 0,
          };
        } else if (chemin == '/saisons/1/vu') {
          final marquer = requete.method == 'POST';
          for (final id in vus.keys) {
            vus[id] = marquer;
          }
          corps = marquer
              ? {'episodes_marques': 2}
              : {'episodes_retires': 2};
        } else if (chemin == '/series/$_ref/plateformes') {
          corps = {'lien': null, 'abonnement': <Object>[], 'gratuit': <Object>[],
                   'location': <Object>[], 'achat': <Object>[]};
        } else if (chemin.endsWith('/similaires') ||
            chemin.endsWith('/progression-abonnements') ||
            chemin == '/avis/abonnements' ||
            chemin == '/avis/moi') {
          corps = <Object>[];
        } else {
          return http.Response('{"detail":"inattendu"}', 404);
        }
        return http.Response(jsonEncode(corps), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

/// Écran haut : la feuille de saison sort du cadre 800x600 par défaut.
void main() => _tests();

Future<void> ouvrirSaison(WidgetTester tester) async {
  // la feuille de saison déborde du cadre de test par défaut (800x600)
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      theme: themeSyncWatch(),
      home: const EcranFicheSerie(referenceTmdb: _ref)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Saison 1'));
  await tester.pump(); // la route de la feuille est poussée
  await tester.pump(const Duration(milliseconds: 500)); // fin de l'animation
}

/// L'icône de la ligne de `titre` : pleine = vu, contour = non vu.
bool ligneVue(WidgetTester tester, String titre) {
  final icone = tester.widget<Icon>(find.descendant(
      of: find.widgetWithText(ListTile, titre), matching: find.byType(Icon)));
  return icone.icon == Icons.check_circle;
}

void _tests() {
  testWidgets('la feuille montre l\'état réel de chaque épisode',
      (tester) async {
    final faux = ApiSerie()..vus[101] = true;
    api = ClientApi(client: faux.client);
    await ouvrirSaison(tester);

    expect(ligneVue(tester, 'Épisode 1'), isTrue);
    expect(ligneVue(tester, 'Épisode 2'), isFalse);
  });

  testWidgets('un épisode vu se décoche — le rattrapage qui manquait',
      (tester) async {
    final faux = ApiSerie()..vus[101] = true;
    api = ClientApi(client: faux.client);
    await ouvrirSaison(tester);

    await tester.tap(find.text('Épisode 1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ligneVue(tester, 'Épisode 1'), isFalse);
    expect(faux.appels, contains('DELETE /episodes/101/vu'));
    expect(faux.vus[101], isFalse);
  });

  testWidgets('la coche change avant la réponse du serveur', (tester) async {
    final faux = ApiSerie()..barriere = Completer<void>();
    api = ClientApi(client: faux.client);
    await ouvrirSaison(tester);

    await tester.tap(find.text('Épisode 2'));
    await tester.pump(); // le serveur n'a pas encore répondu

    expect(ligneVue(tester, 'Épisode 2'), isTrue);
    expect(faux.vus[102], isFalse, reason: 'l\'écriture est encore en vol');

    faux.barriere!.complete();
    await tester.pump(const Duration(milliseconds: 400));
    expect(faux.vus[102], isTrue);
  });

  testWidgets('un échec remet la coche comme elle était', (tester) async {
    final faux = ApiSerie()..vus[101] = true;
    api = ClientApi(client: faux.client);
    await ouvrirSaison(tester);
    faux.ecrituresRefusees = true;

    await tester.tap(find.text('Épisode 1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ligneVue(tester, 'Épisode 1'), isTrue, reason: 'retour en arrière');
    expect(find.text('Épisode introuvable.'), findsOneWidget);
  });

  testWidgets('la saison entière se marque puis se dé-marque', (tester) async {
    final faux = ApiSerie();
    api = ClientApi(client: faux.client);
    await ouvrirSaison(tester);

    await tester.tap(find.text('Tout marquer vu'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ligneVue(tester, 'Épisode 1'), isTrue);
    expect(ligneVue(tester, 'Épisode 2'), isTrue);

    // le bouton devient sa propre marche arrière
    await tester.tap(find.text('Tout dé-marquer'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ligneVue(tester, 'Épisode 1'), isFalse);
    expect(faux.appels, contains('DELETE /saisons/1/vu'));
    expect(faux.vus.values, everyElement(isFalse));
  });

  testWidgets('la feuille reste ouverte après une bascule', (tester) async {
    // elle se refermait à chaque clic : impossible de cocher deux épisodes.
    api = ClientApi(client: ApiSerie().client);
    await ouvrirSaison(tester);

    await tester.tap(find.text('Épisode 1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Épisode 2'), findsOneWidget);
  });
}
