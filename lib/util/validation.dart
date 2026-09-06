// Règles de saisie, alignées sur celles de l'API (schemas/utilisateur.py).
//
// Elles doivent rester identiques des deux côtés : plus strictes ici, on
// bloquerait des comptes que l'API accepte ; plus laxistes, on renvoie la
// personne sur un 422 qu'elle n'a pas demandé.
import 'dart:convert';

/// Équivalent du motif `^[\w .\-]+$` de l'API. Attention : en Python `\w` est
/// Unicode (« Zoé » passe), alors qu'en Dart il reste ASCII — d'où \p{L}\p{N}.
final _motifPseudo = RegExp(r'^[\p{L}\p{N}_ .\-]+$', unicode: true);

/// Une adresse doit avoir un domaine avec un point : l'API s'appuie sur
/// EmailStr, plus exigeant qu'un simple « contient un @ ».
final _motifMail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// bcrypt refuse au-delà de 72 **octets** : un accent en compte deux.
const _maxOctetsMotDePasse = 72;

String? erreurPseudo(String? valeur) {
  final pseudo = valeur?.trim() ?? '';
  if (pseudo.isEmpty) return 'Champ requis';
  if (pseudo.length < 3) return '3 caractères minimum';
  if (pseudo.length > 30) return '30 caractères maximum';
  if (!_motifPseudo.hasMatch(pseudo)) {
    return 'Lettres, chiffres, espaces, . - et _ uniquement';
  }
  return null;
}

String? erreurAdresseMail(String? valeur) {
  final mail = valeur?.trim() ?? '';
  if (mail.isEmpty) return 'Champ requis';
  if (!_motifMail.hasMatch(mail)) return 'Adresse mail invalide';
  return null;
}

String? erreurMotDePasse(String? valeur) {
  final mdp = valeur ?? '';
  if (mdp.isEmpty) return 'Champ requis';
  if (mdp.length < 8) return '8 caractères minimum';
  if (utf8.encode(mdp).length > _maxOctetsMotDePasse) {
    return 'Mot de passe trop long';
  }
  return null;
}
