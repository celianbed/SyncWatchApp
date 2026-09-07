// Fil d'activité — ce que font les personnes suivies : avis, films vus,
// nouvelles séries suivies. Ouvert depuis l'en-tête de l'Accueil.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../widgets/squelette.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/avatar_utilisateur.dart';
import '../widgets/chargeur_async.dart';
import 'ecran_fiche_film.dart';
import 'ecran_fiche_serie.dart';
import 'ecran_profil_public.dart';

class EcranActivite extends StatefulWidget {
  const EcranActivite({super.key});

  @override
  State<EcranActivite> createState() => _EcranActiviteState();
}

class _EcranActiviteState extends State<EcranActivite> {
  late Future<List<EvenementActivite>> _fil = _charger();

  Future<List<EvenementActivite>> _charger() async {
    final d = await api.get('/activite') as List;
    return [
      for (final e in d) EvenementActivite.depuisJson(e as Map<String, dynamic>)
    ];
  }

  Future<void> _rafraichir() async {
    final futur = _charger();
    setState(() => _fil = futur);
    await futur;
  }

  void _ouvrirTitre(EvenementActivite e) {
    if (e.referenceTmdb == null) return;
    final page = e.typeCible == 'film'
        ? EcranFicheFilm(referenceTmdb: e.referenceTmdb!)
        : EcranFicheSerie(referenceTmdb: e.referenceTmdb!);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _ouvrirProfil(EvenementActivite e) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranProfilPublic(idUtilisateur: e.idActeur)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activité')),
      body: RefreshIndicator(
        onRefresh: _rafraichir,
        child: ChargeurAsync<List<EvenementActivite>>(
          future: _fil,
          squelette: const SqueletteListe(nombre: 6, hauteur: 64),
          surReessayer: _rafraichir,
          enfant: (fil) {
            if (fil.isEmpty) return const _Vide();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: fil.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _LigneActivite(
                evenement: fil[i],
                surTitre: () => _ouvrirTitre(fil[i]),
                surProfil: () => _ouvrirProfil(fil[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LigneActivite extends StatelessWidget {
  final EvenementActivite evenement;
  final VoidCallback surTitre;
  final VoidCallback surProfil;

  const _LigneActivite(
      {required this.evenement, required this.surTitre, required this.surProfil});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final e = evenement;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: surTitre,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: surProfil,
                child:
                    AvatarUtilisateur(pseudo: e.pseudo, avatar: e.avatar, taille: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: typo.bodyMedium,
                        children: [
                          TextSpan(
                              text: e.pseudo,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: ' ${e.action} '),
                          TextSpan(
                              text: e.titre,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (e.note != null)
                            TextSpan(
                                text: '  ★ ${e.note}/10',
                                style: const TextStyle(
                                    color: CouleursSW.accentSecondaire,
                                    fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_tempsRelatif(e.date), style: typo.labelSmall),
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

/// « à l'instant », « il y a 3 h », « il y a 2 j »…
String _tempsRelatif(DateTime date) {
  final d = DateTime.now().difference(date);
  if (d.inMinutes < 1) return 'à l’instant';
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  if (d.inHours < 24) return 'il y a ${d.inHours} h';
  if (d.inDays < 7) return 'il y a ${d.inDays} j';
  return 'il y a ${(d.inDays / 7).floor()} sem';
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.dynamic_feed_outlined,
            size: 48, color: CouleursSW.texteSecondaire),
        const SizedBox(height: 16),
        Text(
            'Aucune activité pour l’instant.\nSuis des utilisateurs pour voir ce '
            'qu’ils regardent et notent.',
            style: typo.bodySmall,
            textAlign: TextAlign.center),
      ],
    );
  }
}
