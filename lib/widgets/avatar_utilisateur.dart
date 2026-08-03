// Avatar circulaire d'un utilisateur : image distante si dispo, sinon initiales.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class AvatarUtilisateur extends StatelessWidget {
  final String pseudo;
  final String? avatar;
  final double taille;

  const AvatarUtilisateur({
    super.key,
    required this.pseudo,
    this.avatar,
    this.taille = 44,
  });

  @override
  Widget build(BuildContext context) {
    final initiales = pseudo.isEmpty
        ? '?'
        : pseudo.substring(0, pseudo.length >= 2 ? 2 : 1).toUpperCase();
    final substitut = Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: CouleursSW.accent.withValues(alpha: .2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initiales,
            style: GoogleFonts.sora(
                fontSize: taille * .34,
                fontWeight: FontWeight.w700,
                color: CouleursSW.accent)),
      ),
    );
    final url = avatar;
    if (url == null || url.isEmpty) return substitut;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: taille,
        height: taille,
        fit: BoxFit.cover,
        placeholder: (_, _) => substitut,
        errorWidget: (_, _, _) => substitut,
      ),
    );
  }
}
