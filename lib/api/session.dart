// Session utilisateur : jeton JWT (trousseau iOS) + profil courant.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../modeles/modeles.dart';
import '../services/push.dart';
import 'client_api.dart';

// ID du client OAuth « Web » Firebase (= GOOGLE_CLIENT_ID côté API). Public (pas secret).
const _googleServerClientId =
    '947966302351-c36jc6ghv32qp1iec6786h4ck0kepe4m.apps.googleusercontent.com';

/// ID du client OAuth « iOS » Firebase. **Vide = bouton Google masqué sur iPhone** :
/// sans cet identifiant, google_sign_in échoue nativement dès l'ouverture du
/// sélecteur de compte. À renseigner en même temps que le schéma d'URL, que
/// `ios/scripts/configurer_google_signin.sh` installe dans Info.plist.
const googleClientIdIos =
    '947966302351-17qn8r0rc941kpl4dtl77ue5jkjhkt7q.apps.googleusercontent.com';

final _googleSignIn = GoogleSignIn(
  // le clientId ne vaut que pour iOS ; sur Android c'est le fichier de config qui parle
  clientId: Platform.isIOS && googleClientIdIos.isNotEmpty ? googleClientIdIos : null,
  serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
);

/// La connexion Google est-elle utilisable sur cette plateforme ?
/// `defaultTargetPlatform` plutôt que `Platform` : les tests peuvent le forcer.
bool get googleDisponible =>
    defaultTargetPlatform == TargetPlatform.android || googleClientIdIos.isNotEmpty;

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
        // Avant `_profil()`, et pas après : si le profil échoue (API en train
        // de se réveiller, réseau capricieux), on partait au catch et
        // l'appareil n'était jamais enregistré de toute la session.
        Push.initialiser(); // enregistre l'appareil pour les notifs push (iOS et Android)
        utilisateur = await _profil();
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

  /// Connexion via Google : ouvre le sélecteur de compte, récupère l'id_token,
  /// et le fait valider par l'API (qui crée/lie le compte).
  Future<void> connexionGoogle() async {
    final compte = await _googleSignIn.signIn();
    if (compte == null) return; // annulé par l'utilisateur
    final idToken = (await compte.authentication).idToken;
    if (idToken == null) throw ExceptionApi(0, 'Jeton Google indisponible.');
    final donnees = await api.post('/auth/google',
        corps: {'id_token': idToken}) as Map<String, dynamic>;
    await connecterAvecJeton(donnees['access_token'] as String);
  }

  /// Connexion via Apple : la feuille système renvoie un jeton d'identité que
  /// l'API vérifie. Prénom et adresse ne sont donnés qu'à la toute première
  /// autorisation : on les transmet, Apple ne les redonnera jamais.
  Future<void> connexionApple() async {
    final identifiants = await SignInWithApple.getAppleIDCredential(scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ]);
    final jetonIdentite = identifiants.identityToken;
    if (jetonIdentite == null) throw ExceptionApi(0, 'Jeton Apple indisponible.');
    final donnees = await api.post('/auth/apple', corps: {
      'identity_token': jetonIdentite,
      'prenom': ?identifiants.givenName,
      // permet à l'API de révoquer l'accès Apple si le compte est supprimé
      'code': identifiants.authorizationCode,
    }) as Map<String, dynamic>;
    await connecterAvecJeton(donnees['access_token'] as String);
  }

  /// Finalise la session à partir d'un jeton déjà obtenu (utilisé par le sondage
  /// de vérification, qui teste la connexion sans encore entrer dans l'app).
  Future<void> connecterAvecJeton(String jeton) async {
    api.jeton = jeton;
    await _stockage.write(key: _cleJeton, value: jeton);
    utilisateur = await _profil();
    Push.initialiser(); // enregistre l'appareil pour les notifs push (iOS et Android)
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
    await Push.oublier(); // avant d'effacer le jeton : l'appel exige d'être authentifié
    api.jeton = null;
    utilisateur = null;
    await _stockage.delete(key: _cleJeton);
    _googleSignIn.signOut(); // pour re-choisir le compte au prochain login Google
    notifyListeners();
  }

  /// Supprime définitivement le compte, puis ramène à l'écran de connexion.
  Future<void> supprimerMonCompte() async {
    await Push.oublier(); // tant que le compte existe : après, l'appel serait rejeté
    await api.delete('/utilisateurs/moi');
    await deconnexion();
  }

  Future<Utilisateur> _profil() async => Utilisateur.depuisJson(
      await api.get('/utilisateurs/moi') as Map<String, dynamic>);
}
