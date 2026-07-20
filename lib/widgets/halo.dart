// Halo de couleur diffus en arrière-plan — donne de la profondeur au fond
// sombre de la charte (utilisé par l'onboarding et la connexion).
import 'package:flutter/material.dart';

class Halo extends StatelessWidget {
  final Color couleur;
  final Alignment alignement;
  const Halo({super.key, required this.couleur, required this.alignement});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignement,
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [couleur.withValues(alpha: .16), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
