// Liste des personnes bloquées — sans elle, le blocage serait sans retour.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../widgets/avatar_utilisateur.dart';

class EcranBlocages extends StatefulWidget {
  const EcranBlocages({super.key});

  @override
  State<EcranBlocages> createState() => _EcranBlocagesState();
}

class _EcranBlocagesState extends State<EcranBlocages> {
  late Future<List<ResumeUtilisateur>> _blocages = _charger();

  Future<List<ResumeUtilisateur>> _charger() async {
    final donnees = await api.get('/utilisateurs/moi/blocages') as List;
    return [
      for (final u in donnees)
        ResumeUtilisateur.depuisJson(u as Map<String, dynamic>)
    ];
  }

  Future<void> _debloquer(ResumeUtilisateur u) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await api.delete('/utilisateurs/${u.idUtilisateur}/bloquer');
      messager.showSnackBar(
          SnackBar(content: Text('${u.pseudo} n\'est plus bloqué')));
      // corps en bloc : une flèche renverrait le Future, que setState refuse
      setState(() {
        _blocages = _charger();
      });
    } on ExceptionApi catch (e) {
      messager.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Personnes bloquées')),
      body: FutureBuilder<List<ResumeUtilisateur>>(
        future: _blocages,
        builder: (context, instantane) {
          if (instantane.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = instantane.data ?? [];
          if (liste.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Tu n\'as bloqué personne.',
                    style: typo.bodySmall, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: liste.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = liste[i];
              return ListTile(
                leading: AvatarUtilisateur(
                    pseudo: u.pseudo, avatar: u.avatar, taille: 40),
                title: Text(u.pseudo, style: typo.bodyMedium),
                subtitle: Text('Vos abonnements ont été rompus',
                    style: typo.bodySmall),
                trailing: TextButton(
                  onPressed: () => _debloquer(u),
                  child: const Text('Débloquer'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
