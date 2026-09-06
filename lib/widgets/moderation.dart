// Signalement et blocage — exigés par la directive 1.2 de l'App Store dès
// qu'une app laisse ses utilisateurs publier du texte visible par d'autres.
//
// Les deux gestes ont des rôles distincts : le blocage agit immédiatement et
// n'engage que vous ; le signalement alerte l'éditeur, qui tranchera.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../theme.dart';

/// Motifs proposés, dans l'ordre de gravité. La liste est fermée côté API :
/// elle se traite plus vite qu'un texte libre, et elle guide la personne.
const _motifs = {
  'haine': 'Propos haineux',
  'harcelement': 'Harcèlement',
  'contenu_sexuel': 'Contenu sexuel',
  'spoiler': 'Spoiler non signalé',
  'spam': 'Spam ou publicité',
  'autre': 'Autre',
};

/// Ouvre la feuille de signalement. [idAvis] ou [idVise], jamais les deux.
Future<void> ouvrirSignalement(
  BuildContext context, {
  int? idAvis,
  int? idVise,
  required String quoi,
}) async {
  assert((idAvis == null) != (idVise == null), 'une cible et une seule');
  final messager = ScaffoldMessenger.of(context);

  final motif = await showModalBottomSheet<String>(
    context: context,
    // six motifs plus l'explication dépassent la hauteur d'une feuille
    // ordinaire sur un petit écran : on la laisse grandir, et défiler.
    isScrollControlled: true,
    builder: (contexteFeuille) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text('Signaler $quoi',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                  'Nous examinons les signalements sous 24 heures. '
                  'Le contenu disparaît de votre vue immédiatement.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            for (final entree in _motifs.entries)
              ListTile(
                title: Text(entree.value),
                onTap: () => Navigator.of(contexteFeuille).pop(entree.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (motif == null) return;

  try {
    await api.post('/signalements', corps: {
      'id_avis': ?idAvis,
      'id_vise': ?idVise,
      'motif': motif,
    });
    messager.showSnackBar(const SnackBar(
        content: Text('Signalement envoyé. Nous l\'examinons sous 24 h.')));
  } on ExceptionApi catch (e) {
    messager.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Demande confirmation puis bloque. Renvoie vrai si le blocage a eu lieu.
Future<bool> confirmerBlocage(BuildContext context,
    {required int idUtilisateur, required String pseudo}) async {
  final messager = ScaffoldMessenger.of(context);
  final confirme = await showDialog<bool>(
    context: context,
    builder: (contexteDialogue) => AlertDialog(
      title: Text('Bloquer $pseudo ?'),
      content: const Text(
          'Vous ne verrez plus ses avis ni son profil, et cette personne ne '
          'verra plus les vôtres. Vos abonnements mutuels seront rompus. '
          'Elle n\'en sera pas informée.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: const Text('Annuler')),
        TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: const Text('Bloquer',
                style: TextStyle(color: CouleursSW.danger))),
      ],
    ),
  );
  if (confirme != true) return false;

  try {
    await api.post('/utilisateurs/$idUtilisateur/bloquer');
    messager.showSnackBar(SnackBar(content: Text('$pseudo est bloqué')));
    return true;
  } on ExceptionApi catch (e) {
    messager.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}
