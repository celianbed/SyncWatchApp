// Calendrier — diffusions à venir des séries suivies, groupées par jour.
// Alimenté par GET /calendrier (fenêtre de 30 jours).
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../util/rafraichissement.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/affiche_tmdb.dart';
import '../widgets/chargeur_async.dart';
import 'ecran_fiche_serie.dart';

class EcranCalendrier extends StatefulWidget {
    final bool actif;
  const EcranCalendrier({super.key, this.actif = false});

  @override
  State<EcranCalendrier> createState() => _EcranCalendrierState();
}

class _EcranCalendrierState extends State<EcranCalendrier>
    with RafraichitSiPerime {
  @override
  bool get visible => widget.actif;

  @override
  void rafraichir() => _rafraichir();

  @override
  void didUpdateWidget(EcranCalendrier ancien) {
    super.didUpdateWidget(ancien);
    if (widget.actif && !ancien.actif) rafraichirSiNecessaire();
  }

  late Future<List<CalendrierEntree>> _entrees;

  @override
  void initState() {
    super.initState();
    _entrees = _charger();
  }

  Future<List<CalendrierEntree>> _charger() async {
    final donnees =
        await api.get('/calendrier', params: {'jours': '30'}) as List;
    return [
      for (final e in donnees)
        CalendrierEntree.depuisJson(e as Map<String, dynamic>)
    ];
  }

  Future<void> _rafraichir() async {
    // corps en bloc : « () => _entrees = _charger() » renverrait le Future de
    // l'affectation, ce que setState refuse.
    final futur = _charger();
    setState(() {
      _entrees = futur;
    });
    await futur;
  }

  /// Groupe les entrées (déjà triées par l'API) par jour de diffusion.
  List<(DateTime, List<CalendrierEntree>)> _parJour(
      List<CalendrierEntree> entrees) {
    final groupes = <(DateTime, List<CalendrierEntree>)>[];
    for (final entree in entrees) {
      final jour = entree.episode.dateDiffusion;
      if (jour == null) continue;
      if (groupes.isEmpty || groupes.last.$1 != jour) {
        groupes.add((jour, []));
      }
      groupes.last.$2.add(entree);
    }
    return groupes;
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _rafraichir,
        child: ChargeurAsync<List<CalendrierEntree>>(
          future: _entrees,
          surReessayer: _rafraichir,
          enfant: (donnees) {
            final groupes = _parJour(donnees);
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Text('Calendrier', style: typo.headlineMedium),
                const SizedBox(height: 4),
                Text('Les diffusions à venir sur 30 jours',
                    style: typo.bodySmall),
                const SizedBox(height: 16),
                if (groupes.isEmpty)
                  const _MessageVide(
                      icone: Icons.event_available_outlined,
                      texte:
                          'Aucune diffusion prévue ce mois-ci.\nSeules les séries que tu suis apparaissent ici.')
                else
                  for (final (jour, entrees) in groupes) ...[
                    _EnteteJour(jour: jour),
                    const SizedBox(height: 10),
                    for (final entree in entrees) ...[
                      _CarteDiffusion(
                          entree: entree, surOuvrir: () => _ouvrir(entree)),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _ouvrir(CalendrierEntree entree) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                EcranFicheSerie(referenceTmdb: entree.serie.referenceTmdb)))
        .then((_) => _rafraichir());
  }
}

class _EnteteJour extends StatelessWidget {
  final DateTime jour;
  const _EnteteJour({required this.jour});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: CouleursSW.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(formatJourLong(jour), style: typo.titleLarge),
      ],
    );
  }
}

class _CarteDiffusion extends StatelessWidget {
  final CalendrierEntree entree;
  final VoidCallback surOuvrir;

  const _CarteDiffusion({required this.entree, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final episode = entree.episode;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: surOuvrir,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AfficheTmdb(
                  chemin: entree.serie.affiche,
                  largeur: 44,
                  hauteur: 66,
                  rayon: 8,
                  largeurTmdb: 154),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entree.serie.titre,
                        style: typo.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                        episode.titre == null
                            ? episode.code
                            : '${episode.code} · ${episode.titre}',
                        style: typo.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: CouleursSW.texteSecondaire),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageVide extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _MessageVide({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Icon(icone, size: 48, color: CouleursSW.texteSecondaire),
        const SizedBox(height: 16),
        Text(texte,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      ],
    );
  }
}
