// Feuille « Recommander à… » : choisit un ami (parmi ses abonnements) à qui
// recommander un titre → notification chez lui.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import 'squelette.dart';
import '../api/session.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/avatar_utilisateur.dart';
import '../widgets/chargeur_async.dart';

Future<void> ouvrirRecommander(BuildContext context,
    {required int referenceTmdb, required String type}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: CouleursSW.surface,
    builder: (_) => _FeuilleRecommander(referenceTmdb: referenceTmdb, type: type),
  );
}

class _FeuilleRecommander extends StatefulWidget {
  final int referenceTmdb;
  final String type;
  const _FeuilleRecommander({required this.referenceTmdb, required this.type});

  @override
  State<_FeuilleRecommander> createState() => _FeuilleRecommanderState();
}

class _FeuilleRecommanderState extends State<_FeuilleRecommander> {
  late final Future<List<ResumeUtilisateur>> _amis = _charger();
  int? _enCours; // id de l'utilisateur en cours d'envoi

  Future<List<ResumeUtilisateur>> _charger() async {
    final monId = context.read<Session>().utilisateur?.id;
    if (monId == null) return [];
    final d = await api.get('/utilisateurs/$monId/abonnements') as List;
    return [
      for (final u in d) ResumeUtilisateur.depuisJson(u as Map<String, dynamic>)
    ];
  }

  Future<void> _recommander(ResumeUtilisateur u) async {
    final messagerie = ScaffoldMessenger.of(context);
    setState(() => _enCours = u.idUtilisateur);
    try {
      await api.post('/utilisateurs/${u.idUtilisateur}/recommander', corps: {
        'reference_tmdb': widget.referenceTmdb,
        'type': widget.type,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      messagerie.showSnackBar(SnackBar(content: Text('Recommandé à ${u.pseudo} ✓')));
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() => _enCours = null);
      messagerie.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recommander à…', style: typo.titleLarge),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ChargeurAsync<List<ResumeUtilisateur>>(
                future: _amis,
                squelette: const SqueletteListe(nombre: 4, hauteur: 56),
                enfant: (amis) {
                  if (amis.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                          'Abonne-toi à des utilisateurs pour pouvoir leur '
                          'recommander des titres.',
                          style: typo.bodySmall, textAlign: TextAlign.center),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: amis.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final u = amis[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AvatarUtilisateur(
                            pseudo: u.pseudo, avatar: u.avatar, taille: 40),
                        title: Text(u.pseudo, style: typo.titleMedium),
                        trailing: _enCours == u.idUtilisateur
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded,
                                color: CouleursSW.accent, size: 20),
                        onTap: _enCours == null ? () => _recommander(u) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
