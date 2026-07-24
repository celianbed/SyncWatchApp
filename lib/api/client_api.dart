// Client HTTP vers l'API SyncWatch.
// L'URL se change au lancement : flutter run --dart-define=SYNCWATCH_API=http://127.0.0.1:8000
import 'dart:async';
import 'dart:convert';

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
      if (corps is Map && corps['detail'] is String) {
        message = corps['detail'] as String;
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

  final _http = http.Client();

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
  Future<dynamic> _envoyer(Future<http.Response> Function() requete) async {
    final http.Response reponse;
    try {
      reponse = await requete().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ExceptionApi(0, 'Le serveur met trop de temps à répondre. Réessaie.');
    } catch (_) {
      // SocketException, ClientException… = serveur injoignable / pas de réseau
      throw ExceptionApi(0, 'Pas de connexion. Vérifie ton accès à internet.');
    }
    return _decoder(reponse); // hors du catch : ses ExceptionApi remontent telles quelles
  }

  Future<dynamic> get(String chemin, {Map<String, String>? params}) =>
      _envoyer(() => _http.get(_uri(chemin, params), headers: _entetes));

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

/// Instance unique partagée par toute l'app.
final api = ClientApi();
