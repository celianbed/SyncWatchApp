// Statistiques — KPI, activité 7 dernières semaines, historique récent.
// Maquette HD · Statistiques. (« Genres préférés » attend un endpoint dédié.)
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../util/format.dart';

class EcranStats extends StatefulWidget {
  const EcranStats({super.key});

  @override
  State<EcranStats> createState() => _EcranStatsState();
}

class _EcranStatsState extends State<EcranStats> {
  late Future<(StatsGlobales, List<PeriodeStats>)> _donnees;

  @override
  void initState() {
    super.initState();
    _donnees = _charger();
  }

  Future<(StatsGlobales, List<PeriodeStats>)> _charger() async {
    final debut = DateTime.now().subtract(const Duration(days: 49));
    final resultats = await Future.wait([
      api.get('/stats'),
      api.get('/stats/historique', params: {
        'periode': 'semaine',
        'debut':
            '${debut.year}-${debut.month.toString().padLeft(2, '0')}-${debut.day.toString().padLeft(2, '0')}',
      }),
    ]);
    return (
      StatsGlobales.depuisJson(resultats[0] as Map<String, dynamic>),
      [
        for (final p in resultats[1] as List)
          PeriodeStats.depuisJson(p as Map<String, dynamic>)
      ],
    );
  }

  Future<void> _rafraichir() async {
    // corps en bloc : la closure ne doit rien retourner (sinon setState râle car
    // « () => _donnees = _charger() » renvoie le Future de l'affectation).
    final futur = _charger();
    setState(() {
      _donnees = futur;
    });
    await futur;
  }

  /// Les 7 dernières semaines, les manquantes à zéro.
  List<PeriodeStats> _septSemaines(List<PeriodeStats> historique) {
    final maintenant = DateTime.now();
    // lundi de la semaine courante, à minuit
    final lundi = DateTime(maintenant.year, maintenant.month, maintenant.day)
        .subtract(Duration(days: maintenant.weekday - 1));
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final semaine = lundi.subtract(Duration(days: 7 * i));
          return historique.firstWhere(
            (p) =>
                p.periode.year == semaine.year &&
                p.periode.month == semaine.month &&
                p.periode.day == semaine.day,
            orElse: () => PeriodeStats.depuisJson({
              'periode': semaine.toIso8601String(),
              'episodes_vus': 0,
              'minutes': 0,
            }),
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _rafraichir,
        child: FutureBuilder(
          future: _donnees,
          builder: (context, instantane) {
            if (instantane.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (instantane.hasError) {
              return ListView(padding: const EdgeInsets.all(24), children: [
                Text('${instantane.error}',
                    style: typo.bodySmall, textAlign: TextAlign.center)
              ]);
            }
            final (stats, historique) = instantane.data!;
            final semaines = _septSemaines(historique);
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                Text('Mes statistiques', style: typo.headlineMedium),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _CarteKpi(
                        valeur: '${(stats.minutesTotales / 60).round()} h',
                        libelle: 'devant l’écran'),
                    const SizedBox(width: 10),
                    _CarteKpi(
                        valeur: '${stats.episodesVus}',
                        libelle: 'épisodes vus'),
                    const SizedBox(width: 10),
                    _CarteKpi(
                        valeur: '${stats.seriesTerminees}',
                        libelle: 'séries finies'),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Activité — 7 dernières semaines',
                    style: typo.titleMedium),
                const SizedBox(height: 14),
                _GraphiqueBarres(semaines: semaines),
                const SizedBox(height: 28),
                Text('Historique récent', style: typo.titleMedium),
                const SizedBox(height: 14),
                if (historique.isEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Aucun épisode vu pour l’instant.',
                              style: typo.bodySmall,
                              textAlign: TextAlign.center)))
                else
                  for (final periode in historique.reversed.take(5)) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Text(
                                'Semaine du ${formatDateCourte(periode.periode)}',
                                style: typo.bodyMedium),
                            const Spacer(),
                            Text(
                                '${periode.episodesVus} ép. · ${formatDuree(periode.minutes)}',
                                style: typo.bodySmall?.copyWith(
                                    color: CouleursSW.accent,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CarteKpi extends StatelessWidget {
  final String valeur;
  final String libelle;
  const _CarteKpi({required this.valeur, required this.libelle});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(valeur,
                  style: typo.titleLarge?.copyWith(color: CouleursSW.accent)),
              const SizedBox(height: 4),
              Text(libelle,
                  style: typo.labelSmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphiqueBarres extends StatelessWidget {
  final List<PeriodeStats> semaines;
  const _GraphiqueBarres({required this.semaines});

  @override
  Widget build(BuildContext context) {
    final maxi = semaines.fold<int>(0,
        (acc, p) => p.episodesVus > acc ? p.episodesVus : acc);
    return Card(
      child: Container(
        height: 180,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: maxi == 0
            ? Center(
                child: Text('Aucune activité sur la période.',
                    style: Theme.of(context).textTheme.bodySmall))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final periode in semaines)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 26,
                          height: 8 + 120 * (periode.episodesVus / maxi),
                          decoration: BoxDecoration(
                            // la meilleure semaine ressort en cyan, cf. maquette
                            color: periode.episodesVus == maxi
                                ? CouleursSW.accentSecondaire
                                : CouleursSW.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('${periode.periode.day}',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
