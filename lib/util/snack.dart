// Confirmation accompagnée d'une possibilité d'annuler.
//
// Le bouton est placé DANS le contenu, et non dans le champ `action:` d'une
// SnackBar. Ce n'est pas un caprice : dans cette version de Flutter, une
// SnackBar portant un `SnackBarAction` ne se referme jamais d'elle-même — son
// minuteur d'auto-fermeture ne démarre pas. Vérifié en isolation, sans une
// ligne de SyncWatch ; ni une `duration` explicite ni `showCloseIcon` n'y
// changent rien. La refermer à la main marchait, mais laissait un minuteur en
// vol après chaque confirmation. Déplacer le bouton évite les deux problèmes.
import 'package:flutter/material.dart';


/// Affiche `texte` avec un bouton d'annulation, et se referme seule.
void afficherAnnulable(
  ScaffoldMessengerState messager, {
  required String texte,
  required String libelleAction,
  required VoidCallback surAction,
}) {
  final theme = Theme.of(messager.context);
  // Mêmes couleur et gabarit qu'un SnackBarAction : le bouton change de place,
  // pas d'apparence. `shrinkWrap` et une hauteur libre évitent d'imposer les
  // 36 px d'un TextButton ordinaire, qui gonflaient la barre.
  final couleur = theme.snackBarTheme.actionTextColor ??
      theme.colorScheme.inversePrimary;

  messager.showSnackBar(SnackBar(
    content: Row(
      children: [
        Expanded(child: Text(texte)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            messager.hideCurrentSnackBar();
            surAction();
          },
          style: TextButton.styleFrom(
            foregroundColor: couleur,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            textStyle: theme.snackBarTheme.contentTextStyle
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Text(libelleAction),
        ),
      ],
    ),
  ));
}
