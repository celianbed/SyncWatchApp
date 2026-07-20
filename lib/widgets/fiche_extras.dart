// Blocs partagés des fiches série et film : chips de genres, note perso,
// « Où regarder » (JustWatch via TMDB) et « Titres similaires ».
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import 'affiche_tmdb.dart';
import 'rangee_resultats.dart';

/// Genres en chips arrondies, à la place d'une ligne de texte.
class ChipsGenres extends StatelessWidget {
  final List<Genre> genres;
  const ChipsGenres({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final genre in genres)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CouleursSW.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(genre.libelle.toUpperCase(),
                style: const TextStyle(
                    color: CouleursSW.texteSecondaire,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6)),
          ),
      ],
    );
  }
}

/// « Ta note ?/10 » + note TMDB — la note perso passe par l'API avis.
class BlocNoterFiche extends StatefulWidget {
  final int? idSerie;
  final int? idFilm;
  final double? noteTmdb;

  const BlocNoterFiche({super.key, this.idSerie, this.idFilm, this.noteTmdb});

  @override
  State<BlocNoterFiche> createState() => _BlocNoterFicheState();
}

class _BlocNoterFicheState extends State<BlocNoterFiche> {
  MonAvis? _avis; // mon avis sur cette cible, s'il existe

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final donnees = await api.get('/avis/moi') as List;
      MonAvis? trouve;
      for (final brut in donnees) {
        final avis = MonAvis.depuisJson(brut as Map<String, dynamic>);
        final memeCible = (widget.idSerie != null &&
                avis.idSerie == widget.idSerie) ||
            (widget.idFilm != null && avis.idFilm == widget.idFilm);
        if (memeCible) trouve = avis;
      }
      if (mounted) setState(() => _avis = trouve);
    } on ExceptionApi {
      // bloc silencieux : la fiche reste utilisable sans la note
    }
  }

  Future<void> _noter(int note) async {
    try {
      final Map<String, dynamic> brut;
      if (_avis == null) {
        brut = await api.post('/avis', corps: {
          if (widget.idSerie != null) 'id_serie': widget.idSerie,
          if (widget.idFilm != null) 'id_film': widget.idFilm,
          'note': note,
        }) as Map<String, dynamic>;
      } else {
        brut = await api.patch('/avis/${_avis!.idAvis}',
            corps: {'note': note}) as Map<String, dynamic>;
      }
      if (mounted) setState(() => _avis = MonAvis.depuisJson(brut));
    } on ExceptionApi catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _choisirNote() {
    showModalBottomSheet(
      context: context,
      builder: (contexteFeuille) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ta note', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var note = 1; note <= 10; note++)
                    _PastilleNote(
                      note: note,
                      active: _avis?.note == note,
                      surTape: () {
                        Navigator.of(contexteFeuille).pop();
                        _noter(note);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CarteNote(
            libelle: 'TA NOTE',
            valeur: _avis?.note == null ? '?/10' : '${_avis!.note}/10',
            couleur: CouleursSW.accent,
            icone: Icons.star_rounded,
            surTape: _choisirNote,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CarteNote(
            libelle: 'TMDB',
            valeur: widget.noteTmdb == null
                ? '—'
                : '★ ${widget.noteTmdb!.toStringAsFixed(1)}',
            couleur: CouleursSW.accentSecondaire,
          ),
        ),
      ],
    );
  }
}

class _CarteNote extends StatelessWidget {
  final String libelle;
  final String valeur;
  final Color couleur;
  final IconData? icone;
  final VoidCallback? surTape;

  const _CarteNote(
      {required this.libelle,
      required this.valeur,
      required this.couleur,
      this.icone,
      this.surTape});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: surTape,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: 20, color: couleur),
                    const SizedBox(width: 6),
                  ],
                  Text(valeur,
                      style: typo.titleLarge?.copyWith(color: couleur)),
                ],
              ),
              const SizedBox(height: 4),
              Text(libelle,
                  style: typo.labelSmall?.copyWith(letterSpacing: .8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastilleNote extends StatelessWidget {
  final int note;
  final bool active;
  final VoidCallback surTape;

  const _PastilleNote(
      {required this.note, required this.active, required this.surTape});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? CouleursSW.accent : CouleursSW.fond,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: surTape,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text('$note',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : CouleursSW.texte)),
          ),
        ),
      ),
    );
  }
}

/// « Où regarder » — offres de streaming en France (attribution JustWatch).
class SectionOuRegarder extends StatelessWidget {
  final Future<PlateformesVisionnage> plateformes;
  const SectionOuRegarder({super.key, required this.plateformes});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return FutureBuilder(
      future: plateformes,
      builder: (context, instantane) {
        final donnees = instantane.data;
        if (donnees == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Où regarder', style: typo.titleLarge),
            const SizedBox(height: 2),
            Text('Disponibilités en France · Données JustWatch',
                style: typo.bodySmall),
            const SizedBox(height: 12),
            if (donnees.vide)
              Text('Aucune offre de streaming trouvée.', style: typo.bodySmall)
            else ...[
              _GroupePlateformes(libelle: 'Abonnement', liste: donnees.abonnement),
              _GroupePlateformes(libelle: 'Gratuit', liste: donnees.gratuit),
              _GroupePlateformes(libelle: 'Location', liste: donnees.location),
              _GroupePlateformes(libelle: 'Achat', liste: donnees.achat),
            ],
          ],
        );
      },
    );
  }
}

class _GroupePlateformes extends StatelessWidget {
  final String libelle;
  final List<Plateforme> liste;
  const _GroupePlateformes({required this.libelle, required this.liste});

  @override
  Widget build(BuildContext context) {
    if (liste.isEmpty) return const SizedBox.shrink();
    final typo = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle.toUpperCase(),
              style: typo.labelSmall?.copyWith(letterSpacing: .8)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final plateforme in liste) _ChipPlateforme(plateforme)],
          ),
        ],
      ),
    );
  }
}

class _ChipPlateforme extends StatelessWidget {
  final Plateforme plateforme;
  const _ChipPlateforme(this.plateforme);

  @override
  Widget build(BuildContext context) {
    final url = urlImageTmdb(plateforme.logo, largeur: 92);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CouleursSW.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (url != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(imageUrl: url, width: 24, height: 24),
            ),
            const SizedBox(width: 8),
          ],
          Text(plateforme.nom,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: CouleursSW.texte)),
        ],
      ),
    );
  }
}

/// « Titres similaires » — recommandations TMDB en rangée d'affiches.
class SectionSimilaires extends StatelessWidget {
  final Future<List<ResultatRecherche>> resultats;
  final void Function(ResultatRecherche) surOuvrir;

  const SectionSimilaires(
      {super.key, required this.resultats, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text('Titres similaires', style: typo.titleLarge),
        const SizedBox(height: 12),
        CarrouselResultats(resultats: resultats, surOuvrir: surOuvrir),
      ],
    );
  }
}
