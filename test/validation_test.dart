// Les règles de saisie de l'app doivent coller à celles de l'API : trop
// strictes, elles bloquent des comptes que l'API accepte ; trop laxistes, la
// personne se prend un 422 qu'on aurait pu lui éviter.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncwatch_mobile/api/client_api.dart';
import 'package:syncwatch_mobile/util/validation.dart';

void main() {
  group('pseudo', () {
    test('accepte les accents — \\w est Unicode côté API', () {
      // le piège : en Dart, \w est ASCII, un motif naïf refuserait « Zoé »
      for (final valide in ['Zoé', 'Kenan Turhan', 'jean-luc', 'l.é.o', 'kenan_00']) {
        expect(erreurPseudo(valide), isNull, reason: valide);
      }
    });

    test('refuse ce que l\'API refuse', () {
      expect(erreurPseudo('<img src=x>'), isNotNull);
      expect(erreurPseudo('Kenan!'), isNotNull);
      expect(erreurPseudo('kenan+turhan'), isNotNull);
      expect(erreurPseudo('ab'), '3 caractères minimum');
      expect(erreurPseudo('k' * 31), '30 caractères maximum');
    });
  });

  group('adresse mail', () {
    test('un simple @ ne suffit pas : l\'API exige un domaine', () {
      expect(erreurAdresseMail('kenan@gmail'), isNotNull);
      expect(erreurAdresseMail('pas-un-mail'), isNotNull);
      expect(erreurAdresseMail('turhankenan00@gmail.com'), isNull);
    });
  });

  group('mot de passe', () {
    test('huit caractères minimum', () {
      expect(erreurMotDePasse('court'), '8 caractères minimum');
      expect(erreurMotDePasse('motdepasse1'), isNull);
    });

    test('la limite bcrypt se compte en octets, pas en caractères', () {
      expect(erreurMotDePasse('a' * 72), isNull);
      expect(erreurMotDePasse('é' * 40), isNotNull, reason: '80 octets');
    });
  });

  test('un 422 renvoyé en liste reste lisible', () async {
    // filet de sécurité : l'API rédige désormais une phrase, mais un client à
    // jour face à une API plus ancienne ne doit pas afficher « erreur (422) ».
    final api = ClientApi(client: MockClient((_) async => http.Response(
        jsonEncode({
          'detail': [
            {'loc': ['body', 'pseudo'], 'msg': 'Le pseudo est invalide.'}
          ]
        }),
        422,
        headers: {'content-type': 'application/json; charset=utf-8'})));

    try {
      await api.post('/utilisateurs', corps: {'pseudo': 'a!'});
      fail('un 422 doit lever');
    } on ExceptionApi catch (e) {
      expect(e.code, 422);
      expect(e.message, 'Le pseudo est invalide.');
    }
  });
}
