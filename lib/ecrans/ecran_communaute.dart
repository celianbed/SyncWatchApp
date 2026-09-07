// Ma communauté — abonnés / abonnements d'un utilisateur, avec bouton Suivre.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../widgets/squelette.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/chargeur_async.dart';
import '../widgets/rangee_utilisateur.dart';
import 'ecran_profil_public.dart';

class EcranCommunaute extends StatefulWidget {
  final int idUtilisateur;
  final String titre;
  final bool abonnesDabord;

  const EcranCommunaute({
    super.key,
    required this.idUtilisateur,
    this.titre = 'Ma communauté',
    this.abonnesDabord = true,
  });

  @override
  State<EcranCommunaute> createState() => _EcranCommunauteState();
}

class _EcranCommunauteState extends State<EcranCommunaute> {
  late bool _abonnesActif = widget.abonnesDabord;
  late final Future<List<ResumeUtilisateur>> _abonnes = _charger('abonnes');
  late final Future<List<ResumeUtilisateur>> _abonnements = _charger('abonnements');

  Future<List<ResumeUtilisateur>> _charger(String type) async {
    final donnees =
        await api.get('/utilisateurs/${widget.idUtilisateur}/$type') as List;
    return [
      for (final u in donnees)
        ResumeUtilisateur.depuisJson(u as Map<String, dynamic>)
    ];
  }

  /// Sous-titre = relation (« Vous suivez · vous suit »), sinon compteurs.
  String _sousTitre(ResumeUtilisateur u) {
    final parts = <String>[
      if (u.estAbonne) 'Vous suivez',
      if (u.meSuit) 'vous suit',
    ];
    return parts.isEmpty
        ? '${u.nbSeries} séries · ${u.nbFilms} films'
        : parts.join(' · ');
  }

  void _ouvrir(ResumeUtilisateur u) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranProfilPublic(idUtilisateur: u.idUtilisateur)));
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              children: [
                _Segment(
                    libelle: 'Abonnés',
                    actif: _abonnesActif,
                    surTape: () => setState(() => _abonnesActif = true)),
                const SizedBox(width: 8),
                _Segment(
                    libelle: 'Abonnements',
                    actif: !_abonnesActif,
                    surTape: () => setState(() => _abonnesActif = false)),
              ],
            ),
          ),
          Expanded(
            child: ChargeurAsync<List<ResumeUtilisateur>>(
              future: _abonnesActif ? _abonnes : _abonnements,
              squelette: const SqueletteListe(nombre: 6, hauteur: 64),
              enfant: (liste) {
                if (liste.isEmpty) {
                  return Center(
                    child: Text(
                        _abonnesActif
                            ? 'Personne ne suit encore.'
                            : 'Aucun abonnement pour l’instant.',
                        style: typo.bodySmall),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: liste.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => RangeeUtilisateur(
                    utilisateur: liste[i],
                    sousTitre: _sousTitre(liste[i]),
                    surOuvrir: () => _ouvrir(liste[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String libelle;
  final bool actif;
  final VoidCallback surTape;
  const _Segment(
      {required this.libelle, required this.actif, required this.surTape});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: surTape,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: actif
                ? CouleursSW.accent.withValues(alpha: .18)
                : CouleursSW.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: actif ? CouleursSW.accent : Colors.transparent),
          ),
          child: Text(libelle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      actif ? CouleursSW.accent : CouleursSW.texteSecondaire)),
        ),
      ),
    );
  }
}
