// Statistiques — KPI, activité 7 dernières semaines, historique récent.
// Maquette HD · Statistiques. (« Genres préférés » attend un endpoint dédié.)
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../util/rafraichissement.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/chargeur_async.dart';

/// « 3 ép. · 1 film · 2h10 » — détail d'une semaine (parties à zéro masquées).
String _detailVisionnages(PeriodeStats p) {
  final parts = [
    if (p.episodesVus > 0) '${p.episodesVus} ép.',
    if (p.filmsVus > 0) '${p.filmsVus} film${p.filmsVus > 1 ? "s" : ""}',
  ];
  final compte = parts.isEmpty ? '0' : parts.join(' · ');
  return '$compte · ${formatDuree(p.minutes)}';
}

class EcranStats extends StatefulWidget {
    final bool actif;
  const EcranStats({super.key, this.actif = false});

  @override
  State<EcranStats> createState() => _EcranStatsState();
}

class _EcranStatsState extends State<EcranStats>
    with RafraichitSiPerime {
  @override
  bool get visible => widget.actif;

  @override
  void rafraichir() => setState(() {
        _donnees = _charger();
      });

  @override
  void didUpdateWidget(EcranStats ancien) {
    super.didUpdateWidget(ancien);
    if (widget.actif && !ancien.actif) rafraichirSiNecessaire();
  }

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
              'films_vus': 0,
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
        child: ChargeurAsync<(StatsGlobales, List<PeriodeStats>)>(
          future: _donnees,
          surReessayer: _rafraichir,
          enfant: (donnees) {
            final (stats, historique) = donnees;
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
                Text('Visionnages par semaine',
                    style: typo.titleMedium),
                const SizedBox(height: 2),
                Text('Épisodes + films, sur les 7 dernières semaines',
                    style: typo.bodySmall),
                const SizedBox(height: 14),
                _GraphiqueBarres(semaines: semaines),
                const SizedBox(height: 28),
                Text('Historique récent', style: typo.titleMedium),
                const SizedBox(height: 14),
                if (historique.isEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Aucun visionnage pour l’instant.',
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
                                _detailVisionnages(periode),
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
    final typo = Theme.of(context).textTheme;
    final maxi = semaines.fold<int>(
        0, (acc, p) => p.visionnages > acc ? p.visionnages : acc);
    return Card(
      child: Container(
        // hauteur interne = 190 - 14 - 12 = 164 ; colonne max :
        // nombre 16 + 4 + barre (8+108) + 6 + label 16 = 158 < 164 → pas d'overflow
        height: 190,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: maxi == 0
            ? Center(
                child: Text('Aucun épisode vu sur les 7 dernières semaines.',
                    style: typo.bodySmall, textAlign: TextAlign.center))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final periode in semaines)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // nombre de visionnages de la semaine : repère de hauteur
                        Text('${periode.visionnages}',
                            style: typo.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: periode.visionnages == maxi
                                    ? CouleursSW.accentSecondaire
                                    : CouleursSW.texteSecondaire)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 26,
                          height: 8 + 108 * (periode.visionnages / maxi),
                          decoration: BoxDecoration(
                            // la meilleure semaine ressort en cyan
                            color: periode.visionnages == maxi
                                ? CouleursSW.accentSecondaire
                                : CouleursSW.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // lundi de la semaine, jour/mois (le mois lève la confusion)
                        Text('${periode.periode.day}/${periode.periode.month}',
                            style: typo.labelSmall),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
