// Ligne d'utilisateur réutilisable (recherche, abonnés, abonnements) :
// avatar, pseudo + badge « Ami », sous-titre libre, bouton Suivre/Abonné optimiste.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import 'avatar_utilisateur.dart';

class RangeeUtilisateur extends StatefulWidget {
  final ResumeUtilisateur utilisateur;
  final String sousTitre; // ex. « 142 séries · 38 films » ou « Vous suit »
  final VoidCallback surOuvrir; // ouvre le profil public

  const RangeeUtilisateur({
    super.key,
    required this.utilisateur,
    required this.sousTitre,
    required this.surOuvrir,
  });

  @override
  State<RangeeUtilisateur> createState() => _RangeeUtilisateurState();
}

class _RangeeUtilisateurState extends State<RangeeUtilisateur> {
  bool _enCours = false;

  Future<void> _basculerAbonnement() async {
    final u = widget.utilisateur;
    final avant = u.estAbonne;
    setState(() {
      u.estAbonne = !avant; // optimiste
      _enCours = true;
    });
    try {
      final chemin = '/utilisateurs/${u.idUtilisateur}/abonner';
      avant ? await api.delete(chemin) : await api.post(chemin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(avant
                ? 'Tu ne suis plus ${u.pseudo}'
                : 'Tu suis ${u.pseudo} ✓')));
      }
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() => u.estAbonne = avant); // rollback
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.utilisateur;
    final typo = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.surOuvrir,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AvatarUtilisateur(pseudo: u.pseudo, avatar: u.avatar, taille: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(u.pseudo,
                              style: typo.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (u.estAmi) ...[
                          const SizedBox(width: 6),
                          const _BadgeAmi(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(widget.sousTitre,
                        style: typo.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BoutonAbonnement(
                  abonne: u.estAbonne,
                  enCours: _enCours,
                  surTape: _basculerAbonnement),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeAmi extends StatelessWidget {
  const _BadgeAmi();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: CouleursSW.accentSecondaire.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('Ami',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CouleursSW.accentSecondaire)),
    );
  }
}

/// « Suivre » (plein) si pas abonné, « Abonné » (contour) si abonné.
class _BoutonAbonnement extends StatelessWidget {
  final bool abonne;
  final bool enCours;
  final VoidCallback surTape;

  const _BoutonAbonnement(
      {required this.abonne, required this.enCours, required this.surTape});

  @override
  Widget build(BuildContext context) {
    final enfant = enCours
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Text(abonne ? 'Abonné' : 'Suivre');
    final surPresse = enCours ? null : surTape;
    return abonne
        ? OutlinedButton(
            onPressed: surPresse,
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: enfant)
        : FilledButton(
            onPressed: surPresse,
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: enfant);
  }
}
