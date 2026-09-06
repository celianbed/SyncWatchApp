// Deux oublis relevés en faisant le tour de l'app :
//  - une note posée par erreur ne pouvait plus être retirée (POST et PATCH
//    existaient, DELETE n'était jamais appelé) ;
//  - l'avatar se saisissait en collant une URL à la main.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/api/session.dart';
import 'package:syncwatch_mobile/ecrans/ecran_profil.dart';
import 'package:syncwatch_mobile/modeles/modeles.dart';
import 'package:syncwatch_mobile/theme.dart';
import 'package:syncwatch_mobile/util/avatars.dart';
import 'package:syncwatch_mobile/widgets/fiche_extras.dart';

/// Réseau doublé pour la note d'une série : tient l'avis comme le ferait l'API.
class ApiAvis {
  Map<String, Object?>? avis;
  final appels = <String>[];

  ApiAvis({int? note}) {
    if (note != null) {
      avis = {'id_avis': 7, 'id_serie': 1, 'id_film': null, 'note': note,
              'commentaire': null, 'date_publication': '2026-09-01T12:00:00'};
    }
  }

  http.Client get client => MockClient((requete) async {
        final chemin = requete.url.path;
        appels.add('${requete.method} $chemin');
        Object? corps;

        if (chemin == '/avis/moi') {
          corps = avis == null ? <Object>[] : [avis];
        } else if (chemin == '/avis' && requete.method == 'POST') {
          final note = jsonDecode(requete.body)['note'];
          avis = {'id_avis': 7, 'id_serie': 1, 'id_film': null, 'note': note,
                  'commentaire': null, 'date_publication': '2026-09-01T12:00:00'};
          corps = avis;
        } else if (chemin == '/avis/7') {
          if (requete.method == 'DELETE') {
            avis = null;
            return http.Response('', 204);
          }
          avis!['note'] = jsonDecode(requete.body)['note'];
          corps = avis;
        } else {
          return http.Response('{"detail":"inattendu"}', 404);
        }
        return http.Response(jsonEncode(corps), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

Future<void> ouvrirNote(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: themeSyncWatch(),
    home: const Scaffold(
        body: Center(child: BlocNoterFiche(idSerie: 1, noteTmdb: 8.4))),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('TA NOTE'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Profil doublé, sans réseau : seul le formulaire d'édition nous intéresse.
final _reponsesProfil = <String, Object>{
  '/stats': {'episodes_vus': 0, 'films_vus': 0, 'series_suivies': 0,
             'series_terminees': 0, 'minutes_totales': 0},
  '/utilisateurs/moi/favoris': [],
  '/utilisateurs/moi/films-vus': [],
  '/utilisateurs/moi/a-voir': [],
  '/notifications/nombre-non-lues': {'nombre': 0},
  '/utilisateurs/1': {
    'id_utilisateur': 1, 'pseudo': 'celian', 'avatar': null,
    'date_inscription': '2026-01-15T10:00:00', 'nb_abonnes': 0,
    'nb_abonnements': 0, 'nb_series': 0, 'est_abonne': false, 'me_suit': false,
  },
};

class SessionLocale extends Session {
  String? avatarEnvoye;
  bool profilMisAJour = false;

  SessionLocale({String? avatar}) {
    utilisateur = Utilisateur.depuisJson({
      'id_utilisateur': 1,
      'adresse_mail': 'celian@example.com',
      'pseudo': 'celian',
      'avatar': avatar,
      'date_inscription': '2026-01-15T10:00:00',
    });
  }

  @override
  Future<void> mettreAJourProfil({String? pseudo, String? avatar}) async {
    profilMisAJour = true;
    avatarEnvoye = avatar;
  }
}

Future<SessionLocale> ouvrirEditionProfil(WidgetTester tester,
    {String? avatar}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  api = ClientApi(client: MockClient((requete) async {
    final corps = _reponsesProfil[requete.url.path];
    if (corps == null) return http.Response('{"detail":"inattendu"}', 404);
    return http.Response(jsonEncode(corps), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }));

  final session = SessionLocale(avatar: avatar);
  await tester.pumpWidget(ChangeNotifierProvider<Session>.value(
    value: session,
    // EcranProfil est un corps d'onglet : en vrai le Scaffold vient du shell
    child: MaterialApp(
        theme: themeSyncWatch(),
        home: const Scaffold(body: EcranProfil())),
  ));
  await tester.pumpAndSettle();

  final entree = find.text('Modifier le profil');
  await tester.scrollUntilVisible(entree, 200);
  await tester.ensureVisible(entree);
  await tester.pumpAndSettle();
  await tester.tap(entree);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return session;
}

/// Les cases de la grille d'avatars — l'écran de profil, derrière la feuille,
/// contient d'autres GestureDetector qu'il ne faut pas attraper.
Finder casesAvatar() => find.descendant(
    of: find.byType(GridView), matching: find.byType(GestureDetector));

void main() {
  group('note personnelle', () {
    testWidgets('sans note, aucun retrait n\'est proposé', (tester) async {
      api = ClientApi(client: ApiAvis().client);
      await ouvrirNote(tester);
      expect(find.text('Retirer ma note'), findsNothing);
    });

    testWidgets('une note posée par erreur se retire', (tester) async {
      final faux = ApiAvis(note: 9);
      api = ClientApi(client: faux.client);
      await ouvrirNote(tester);

      await tester.tap(find.text('Retirer ma note'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(faux.appels, contains('DELETE /avis/7'));
      expect(faux.avis, isNull);
      expect(find.text('?/10'), findsOneWidget);
    });

    testWidgets('la note s\'affiche avant la réponse du serveur',
        (tester) async {
      api = ClientApi(client: ApiAvis().client);
      await ouvrirNote(tester);

      await tester.tap(find.text('8'));
      await tester.pump(); // rien n'est encore revenu du serveur

      expect(find.text('8/10'), findsOneWidget);
    });
  });

  group('avatar', () {
    testWidgets('le profil propose une grille, plus un champ URL',
        (tester) async {
      await ouvrirEditionProfil(tester);
      expect(find.text('Avatar'), findsOneWidget);
      expect(find.text('URL de l’avatar (vide = aucun)'), findsNothing);
    });

    testWidgets('choisir un avatar l\'envoie au profil', (tester) async {
      final session = await ouvrirEditionProfil(tester);

      await tester.tap(casesAvatar().at(1)); // 1re case = « aucun avatar »
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(session.profilMisAJour, isTrue);
      expect(session.avatarEnvoye, avatarsProposes.first);
      expect(session.avatarEnvoye, startsWith('https://api.dicebear.com/'));
    });

    testWidgets('la première case retire l\'avatar', (tester) async {
      final session =
          await ouvrirEditionProfil(tester, avatar: avatarsProposes.first);

      await tester.tap(casesAvatar().first);
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(session.avatarEnvoye, '');
    });
  });
}
