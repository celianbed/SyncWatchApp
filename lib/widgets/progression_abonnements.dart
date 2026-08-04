// Section « Où en sont tes abonnements » sur une fiche série : la progression
// (anti-spoiler) des personnes suivies qui suivent aussi cette série.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../ecrans/ecran_profil_public.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import 'avatar_utilisateur.dart';

class ProgressionAbonnements extends StatefulWidget {
  final int referenceTmdb;
  const ProgressionAbonnements({super.key, required this.referenceTmdb});

  @override
  State<ProgressionAbonnements> createState() => _ProgressionAbonnementsState();
}

class _ProgressionAbonnementsState extends State<ProgressionAbonnements> {
  late final Future<List<ProgressionAmi>> _progressions = _charger();

  Future<List<ProgressionAmi>> _charger() async {
    final d = await api
        .get('/series/${widget.referenceTmdb}/progression-abonnements') as List;
    return [for (final p in d) ProgressionAmi.depuisJson(p as Map<String, dynamic>)];
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return FutureBuilder<List<ProgressionAmi>>(
      future: _progressions,
      builder: (context, snap) {
        final liste = snap.data;
        if (liste == null || liste.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Où en sont tes abonnements', style: typo.titleMedium),
            const SizedBox(height: 12),
            for (final p in liste)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LigneProgression(progression: p),
              ),
          ],
        );
      },
    );
  }
}

class _LigneProgression extends StatelessWidget {
  final ProgressionAmi progression;
  const _LigneProgression({required this.progression});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final p = progression;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EcranProfilPublic(idUtilisateur: p.idUtilisateur))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AvatarUtilisateur(pseudo: p.pseudo, avatar: p.avatar, taille: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.pseudo,
                              style: typo.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${p.episodesVus}/${p.totalEpisodes}',
                            style: typo.labelSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p.position,
                        style: typo.bodySmall
                            ?.copyWith(color: CouleursSW.accentSecondaire)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: p.fraction, minHeight: 5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
