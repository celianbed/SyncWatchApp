// Suppression de compte depuis le profil — exigence App Store 5.1.1 (v) : le
// chemin doit exister dans l'app, être confirmé, et n'agir qu'après confirmation.
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

/// Réponses minimales mais valides : l'écran doit se construire en entier,
/// sinon la carte qui porte l'entrée de suppression n'existe pas.
final _reponses = <String, Object>{
  '/stats': {
    'episodes_vus': 0,
    'films_vus': 0,
    'series_suivies': 0,
    'series_terminees': 0,
    'minutes_totales': 0,
  },
  '/utilisateurs/moi/favoris': [],
  '/utilisateurs/moi/films-vus': [],
  '/notifications/nombre-non-lues': {'nombre': 0},
  '/utilisateurs/1': {
    'id_utilisateur': 1,
    'pseudo': 'celian',
    'avatar': null,
    'date_inscription': '2026-01-15T10:00:00',
    'nb_abonnes': 0,
    'nb_abonnements': 0,
    'nb_series': 0,
    'est_abonne': false,
    'me_suit': false,
  },
};

http.Client _reseauDouble() => MockClient((requete) async {
      final corps = _reponses[requete.url.path];
      if (corps == null) return http.Response('{"detail":"inattendu"}', 404);
      return http.Response(jsonEncode(corps), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

/// Session doublée : on n'observe que l'appel à la suppression.
class SessionEspion extends Session {
  int suppressions = 0;

  SessionEspion() {
    utilisateur = Utilisateur.depuisJson({
      'id_utilisateur': 1,
      'adresse_mail': 'celian@example.com',
      'pseudo': 'celian',
      'avatar': null,
      'date_inscription': '2026-01-15T10:00:00',
    });
  }

  @override
  Future<void> supprimerMonCompte() async => suppressions++;
}

/// Affiche le profil et fait défiler jusqu'à l'entrée de suppression.
Future<SessionEspion> ouvrirProfil(WidgetTester tester) async {
  final session = SessionEspion();
  await tester.pumpWidget(ChangeNotifierProvider<Session>.value(
    value: session,
    child: MaterialApp(theme: themeSyncWatch(), home: const EcranProfil()),
  ));
  await tester.pumpAndSettle();
  // la liste est paresseuse : le premier défilement construit la carte, le
  // second l'amène vraiment dans le viewport de test (800×600) pour le tap.
  final entree = find.text('Supprimer mon compte');
  await tester.scrollUntilVisible(entree, 200);
  await tester.ensureVisible(entree);
  await tester.pumpAndSettle();
  return session;
}

void main() {
  setUp(() => api = ClientApi(client: _reseauDouble()));

  testWidgets('le profil offre un chemin de suppression de compte',
      (tester) async {
    await ouvrirProfil(tester);
    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('la suppression demande confirmation et annonce que c\'est définitif',
      (tester) async {
    final session = await ouvrirProfil(tester);
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer ton compte ?'), findsOneWidget);
    expect(find.textContaining('irréversible'), findsOneWidget);
    expect(session.suppressions, 0); // le simple tap n'efface rien
  });

  testWidgets('annuler referme sans rien supprimer', (tester) async {
    final session = await ouvrirProfil(tester);
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer ton compte ?'), findsNothing);
    expect(session.suppressions, 0);
  });

  testWidgets('confirmer supprime le compte', (tester) async {
    final session = await ouvrirProfil(tester);
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(session.suppressions, 1);
    expect(find.text('Supprimer ton compte ?'), findsNothing);
  });
}
