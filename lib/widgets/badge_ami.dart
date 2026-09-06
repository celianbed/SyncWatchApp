// Badge « Ami » — suivi mutuel. Il existait en deux exemplaires quasi
// identiques (profil public et ligne d'utilisateur), à deux tailles près.
import 'package:flutter/material.dart';

import '../theme.dart';

class BadgeAmi extends StatelessWidget {
  /// Version resserrée, pour les lignes de liste.
  final bool petit;

  const BadgeAmi({super.key, this.petit = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: petit ? 7 : 8, vertical: petit ? 2 : 3),
      decoration: BoxDecoration(
        color: CouleursSW.accentSecondaire.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Ami',
          style: TextStyle(
              fontSize: petit ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: CouleursSW.accentSecondaire)),
    );
  }
}
