// Session utilisateur : jeton JWT (trousseau iOS) + profil courant.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../modeles/modeles.dart';
import '../services/push.dart';
import 'client_api.dart';

class Session extends ChangeNotifier {
  static const _cleJeton = 'jeton_syncwatch';
  static const _cleOnboarding = 'onboarding_vu';
  final _stockage = const FlutterSecureStorage();

  Utilisateur? utilisateur;
  bool pret = false; // restauration du jeton terminée (écran de démarrage)
  bool onboardingVu = false; // présentation déjà affichée sur cet appareil

  bool get connecte => api.jeton != null;

  Future<void> restaurer() async {
    api.surNonAutorise = deconnexion; // session expirée → retour connexion
    try {
      onboardingVu = await _stockage.read(key: _cleOnboarding) != null;
      final jeton = await _stockage.read(key: _cleJeton);
      if (jeton != null) {
        api.jeton = jeton;
        utilisateur = await _profil();
        Push.initialiser(); // enregistre l'appareil pour les notifs push (Android)
      }
    } catch (_) {
      api.jeton = null; // jeton périmé ou API injoignable : on repart propre
    }
    pret = true;
    notifyListeners();
  }

  Future<void> terminerOnboarding() async {
    onboardingVu = true;
    await _stockage.write(key: _cleOnboarding, value: '1');
    notifyListeners();
  }

  Future<void> connexion(String identifiant, String motDePasse) async {
    await connecterAvecJeton(await api.connexion(identifiant, motDePasse));
  }

  /// Finalise la session à partir d'un jeton déjà obtenu (utilisé par le sondage
  /// de vérification, qui teste la connexion sans encore entrer dans l'app).
  Future<void> connecterAvecJeton(String jeton) async {
    api.jeton = jeton;
    await _stockage.write(key: _cleJeton, value: jeton);
    utilisateur = await _profil();
    Push.initialiser(); // enregistre l'appareil pour les notifs push (Android)
    notifyListeners();
  }

  /// Crée le compte. Ne connecte pas : l'API l'interdit tant que l'adresse mail
  /// n'est pas confirmée (un lien de vérification vient d'être envoyé).
  Future<void> inscription(
      String adresseMail, String pseudo, String motDePasse) async {
    await api.post('/utilisateurs', corps: {
      'adresse_mail': adresseMail,
      'pseudo': pseudo,
      'mot_de_passe': motDePasse,
    });
  }

  /// Renvoie le mail de confirmation d'adresse (compte non encore vérifié).
  Future<void> renvoyerVerification(String adresseMail) =>
      api.renvoyerVerification(adresseMail);

  /// Demande un lien de réinitialisation de mot de passe (reset via page web).
  Future<void> motDePasseOublie(String adresseMail) =>
      api.motDePasseOublie(adresseMail);

  /// Met à jour le profil ; `avatar` vide = retirer l'avatar.
  /// Seuls les champs non null sont envoyés (PATCH partiel).
  Future<void> mettreAJourProfil({String? pseudo, String? avatar}) async {
    final corps = <String, dynamic>{
      'pseudo': ?pseudo,
      if (avatar != null) 'avatar': avatar.trim().isEmpty ? null : avatar.trim(),
    };
    if (corps.isEmpty) return;
    utilisateur = Utilisateur.depuisJson(
        await api.patch('/utilisateurs/moi', corps: corps)
            as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> deconnexion() async {
    api.jeton = null;
    utilisateur = null;
    await _stockage.delete(key: _cleJeton);
    notifyListeners();
  }

  Future<Utilisateur> _profil() async => Utilisateur.depuisJson(
      await api.get('/utilisateurs/moi') as Map<String, dynamic>);
}
