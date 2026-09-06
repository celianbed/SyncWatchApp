// Client HTTP vers l'API SyncWatch.
// L'URL se change au lancement : flutter run --dart-define=SYNCWATCH_API=http://127.0.0.1:8000
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExceptionApi implements Exception {
  final int code; // 0 = problème réseau / hors-ligne (pas de réponse HTTP)
  final String message;
  ExceptionApi(this.code, this.message);

  @override
  String toString() => message;
}

/// Message **affichable à l'utilisateur** pour une réponse en erreur.
/// Pour les 4xx on privilégie le `detail` de l'API (en français) ; pour les 5xx
/// et le 429 on rédige un message clair (le corps y est technique/anglais).
String _messageErreur(http.Response reponse) {
  final code = reponse.statusCode;
  var message = switch (code) {
    429 => 'Trop de tentatives. Réessaie dans quelques minutes.',
    >= 500 => 'Le service est momentanément indisponible. Réessaie plus tard.',
    _ => 'Une erreur est survenue ($code).',
  };
  // le message précis de l'API n'est fiable/rédigé que pour les 4xx (< 500)
  if (code < 500) {
    try {
      final corps = jsonDecode(utf8.decode(reponse.bodyBytes));
      if (corps is Map) {
        final detail = corps['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          // filet : forme brute de FastAPI sur un 422 (liste d'objets {msg}).
          // L'API la remplace par une phrase, mais sans ça un client à jour
          // face à une API plus ancienne n'affichait que « erreur (422) ».
          final phrases = [
            for (final e in detail)
              if (e is Map && e['msg'] is String) e['msg'] as String
          ];
          if (phrases.isNotEmpty) message = phrases.join(' ');
        }
      }
    } catch (_) {}
  }
  return message;
}

class ClientApi {
  static const urlBase = String.fromEnvironment('SYNCWATCH_API',
      defaultValue: 'https://syncwatch-b3tv.onrender.com');

  String? jeton;

  /// Appelé sur une réponse 401 alors qu'un jeton était présent (session expirée).
  void Function()? surNonAutorise;

  final http.Client _http;

  /// `client` et les délais ne sont fournis que par les tests, pour doubler le
  /// réseau et ne pas attendre vraiment vingt secondes.
  ClientApi({http.Client? client, Duration? delaiNormal, Duration? delaiReveil})
      : _http = client ?? http.Client(),
        _delaiNormal = delaiNormal ?? const Duration(seconds: 20),
        _delaiReveil = delaiReveil ?? const Duration(seconds: 75);

  /// Vrai pendant la seconde tentative d'une lecture : l'hébergement met le
  /// service en veille et son réveil dure jusqu'à une minute. Les écrans
  /// s'en servent pour dire « réveil du serveur » au lieu d'un spinner muet.
  final reveil = ValueNotifier<bool>(false);

  final Duration _delaiNormal;
  final Duration _delaiReveil;

  Uri _uri(String chemin, [Map<String, String>? params]) {
    final uri = Uri.parse('$urlBase$chemin');
    return params == null ? uri : uri.replace(queryParameters: params);
  }

  Map<String, String> get _entetes => {
        'Content-Type': 'application/json',
        if (jeton != null) 'Authorization': 'Bearer $jeton',
      };

  dynamic _decoder(http.Response reponse) {
    if (reponse.statusCode == 401 && jeton != null) surNonAutorise?.call();
    if (reponse.statusCode >= 400) {
      throw ExceptionApi(reponse.statusCode, _messageErreur(reponse));
    }
    if (reponse.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(reponse.bodyBytes));
  }

  /// Exécute la requête avec un timeout, transforme une panne réseau en
  /// ExceptionApi(0) lisible, puis décode la réponse.
  ///
  /// `rejouable` n'est vrai que pour les lectures : un délai dépassé ne dit pas
  /// que le serveur n'a rien fait, et rejouer une écriture créerait un doublon.
  /// Pour une lecture, la seconde tentative laisse au service le temps de sortir
  /// de veille — sans quoi rien ne répond avant que l'utilisateur n'abandonne.
  /// Exécute la requête avec un délai, transforme une panne réseau en
  /// ExceptionApi(0) lisible, puis décode la réponse.
  ///
  /// `rejouable` n'est vrai que pour les lectures : un délai dépassé ne dit pas
  /// que le serveur n'a rien fait, et rejouer une écriture créerait un doublon.
  /// Pour une lecture, la seconde tentative laisse au service le temps de sortir
  /// de veille — sans quoi rien ne répond avant que l'utilisateur n'abandonne.
  Future<dynamic> _envoyer(Future<http.Response> Function() requete,
      {bool rejouable = false}) async {
    try {
      return _decoder(await requete().timeout(_delaiNormal));
    } on ExceptionApi {
      rethrow; // erreur HTTP : surtout pas confondue avec une panne réseau
    } on TimeoutException {
      if (!rejouable) {
        throw ExceptionApi(0, 'Le serveur met trop de temps à répondre. Réessaie.');
      }
    } catch (_) {
      // SocketException, ClientException… = serveur injoignable / pas de réseau
      throw ExceptionApi(0, 'Pas de connexion. Vérifie ton accès à internet.');
    }

    // Le service dormait peut-être : on lui laisse le temps de se lever.
    reveil.value = true;
    try {
      return _decoder(await requete().timeout(_delaiReveil));
    } on ExceptionApi {
      rethrow;
    } on TimeoutException {
      throw ExceptionApi(0, 'Le serveur ne répond pas. Réessaie dans un instant.');
    } catch (_) {
      throw ExceptionApi(0, 'Pas de connexion. Vérifie ton accès à internet.');
    } finally {
      reveil.value = false;
    }
  }

  Future<dynamic> get(String chemin, {Map<String, String>? params}) =>
      _envoyer(() => _http.get(_uri(chemin, params), headers: _entetes),
          rejouable: true);

  Future<dynamic> post(String chemin, {Object? corps}) =>
      _envoyer(() => _http.post(_uri(chemin),
          headers: _entetes, body: corps == null ? null : jsonEncode(corps)));

  Future<dynamic> patch(String chemin, {Object? corps}) =>
      _envoyer(() => _http.patch(_uri(chemin),
          headers: _entetes, body: corps == null ? null : jsonEncode(corps)));

  Future<dynamic> delete(String chemin) =>
      _envoyer(() => _http.delete(_uri(chemin), headers: _entetes));

  /// POST /auth/connexion — corps x-www-form-urlencoded imposé par la spec OAuth2.
  Future<String> connexion(String identifiant, String motDePasse) async {
    final donnees = await _envoyer(() => _http.post(_uri('/auth/connexion'),
        body: {'username': identifiant, 'password': motDePasse})) as Map<String, dynamic>;
    return donnees['access_token'] as String;
  }

  /// POST /auth/renvoyer-verification — renvoie le mail de confirmation.
  /// Réponse volontairement générique côté API (ne révèle pas si le compte existe).
  Future<void> renvoyerVerification(String adresseMail) async {
    await post('/auth/renvoyer-verification', corps: {'adresse_mail': adresseMail});
  }

  /// POST /auth/mot-de-passe-oublie — envoie un lien de réinitialisation.
  /// Réponse générique côté API (ne révèle pas si le compte existe).
  Future<void> motDePasseOublie(String adresseMail) async {
    await post('/auth/mot-de-passe-oublie', corps: {'adresse_mail': adresseMail});
  }
}

/// Client partagé par toute l'app. Réassignable pour qu'un test puisse le
/// remplacer par un client doublé (cf. test/).
ClientApi api = ClientApi();
