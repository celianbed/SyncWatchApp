// Le bouton « À voir plus tard » ne montrait aucun état et n'offrait aucun
// retour en arrière : on l'ajoutait, rien ne changeait à l'écran, et un clic
// malencontreux était définitif. Ces tests verrouillent les deux corrections.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/ecrans/ecran_fiche_film.dart';
import 'package:syncwatch_mobile/theme.dart';

const _ref = 693134;

/// Réseau doublé qui tient l'état du film comme le ferait l'API.
class ApiFilm {
  bool dansAVoir;
  bool dejaVu;
  final appels = <String>[];

  ApiFilm({this.dansAVoir = false, this.dejaVu = false});

  http.Client get client => MockClient((requete) async {
        final chemin = requete.url.path;
        appels.add('${requete.method} $chemin');
        Object? corps;

        if (chemin == '/films/$_ref') {
          corps = {
            'id_film': 1,
            'reference_tmdb': _ref,
            'titre': 'Dune',
            'titre_original': 'Dune',
            'synopsis': 'Sur la planète Arrakis…',
            'affiche': null,
            'duree': 155,
            'date_sortie': '2021-09-15',
            'note_moyenne_tmdb': 7.8,
            'genres': <String>[],
          };
        } else if (chemin == '/films/$_ref/vu') {
          if (requete.method == 'POST') {
            dejaVu = true;
            dansAVoir = false; // l'API bascule le statut du suivi
            corps = {'id_film': 1, 'nombre_visionnages': 1};
          } else {
            corps = {
              'deja_vu': dejaVu,
              'nombre_visionnages': dejaVu ? 1 : 0,
              'dans_a_voir': dansAVoir,
            };
          }
        } else if (chemin == '/films/$_ref/suivre') {
          dansAVoir = requete.method == 'POST';
          if (requete.method == 'DELETE') return http.Response('', 204);
          corps = {'id_film': 1, 'statut': 'a_voir', 'favori': false};
        } else if (chemin.endsWith('/similaires')) {
          corps = <Object>[];
        } else if (chemin.endsWith('/plateformes')) {
          corps = {'lien': null, 'abonnement': <Object>[], 'gratuit': <Object>[],
                   'location': <Object>[], 'achat': <Object>[]};
        } else {
          return http.Response('{"detail":"inattendu"}', 404);
        }
        return http.Response(jsonEncode(corps), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

Future<void> ouvrirFiche(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
      theme: themeSyncWatch(),
      home: const EcranFicheFilm(referenceTmdb: _ref)));
  await tester.pump(const Duration(milliseconds: 500));
}

final ajouter = find.widgetWithText(OutlinedButton, 'À voir plus tard');
final retirer = find.widgetWithText(ElevatedButton, 'Dans ma liste · retirer');

void main() {
  testWidgets('un film hors de la liste propose de l\'y ajouter', (tester) async {
    api = ClientApi(client: ApiFilm().client);
    await ouvrirFiche(tester);
    expect(ajouter, findsOneWidget);
    expect(retirer, findsNothing);
  });

  testWidgets('un film déjà dans la liste le montre dès l\'ouverture',
      (tester) async {
    // c'est ce qui manquait : l'état n'était pas lu, le bouton restait identique
    api = ClientApi(client: ApiFilm(dansAVoir: true).client);
    await ouvrirFiche(tester);
    expect(retirer, findsOneWidget);
    expect(ajouter, findsNothing);
  });

  testWidgets('ajouter fait basculer le bouton', (tester) async {
    api = ClientApi(client: ApiFilm().client);
    await ouvrirFiche(tester);
    await tester.tap(ajouter);
    await tester.pump(const Duration(milliseconds: 400));
    expect(retirer, findsOneWidget);
  });

  testWidgets('un ajout par mégarde se défait', (tester) async {
    final faux = ApiFilm(dansAVoir: true);
    api = ClientApi(client: faux.client);
    await ouvrirFiche(tester);

    await tester.tap(retirer);
    await tester.pump(const Duration(milliseconds: 400));

    expect(ajouter, findsOneWidget);
    expect(faux.appels, contains('DELETE /films/$_ref/suivre'));
    expect(faux.dansAVoir, isFalse);
  });

  testWidgets('marquer vu sort le film de la liste', (tester) async {
    api = ClientApi(client: ApiFilm(dansAVoir: true).client);
    await ouvrirFiche(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Marquer vu'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(retirer, findsNothing, reason: 'un film vu n\'est plus « à voir »');
    expect(ajouter, findsOneWidget);
  });
}
