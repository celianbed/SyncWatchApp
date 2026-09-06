// Section « Distribution » des fiches série et film.
//
// La liste des acteurs, tout le monde l'a — elle vient de TMDB. Ce qui n'est
// qu'ici, c'est le compteur « déjà vu dans N titres », calculé sur l'historique
// de visionnage : c'est lui qui justifie la table de casting, et c'est lui
// qu'on met en avant.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import 'affiche_tmdb.dart';

class SectionCasting extends StatefulWidget {
  /// « series » ou « films » — le segment de l'API.
  final String type;
  final int referenceTmdb;

  const SectionCasting(
      {super.key, required this.type, required this.referenceTmdb});

  @override
  State<SectionCasting> createState() => _SectionCastingState();
}

class _SectionCastingState extends State<SectionCasting> {
  late final Future<List<MembreCasting>> _casting = _charger();

  Future<List<MembreCasting>> _charger() async {
    try {
      final donnees = await api
          .get('/${widget.type}/${widget.referenceTmdb}/casting') as List;
      return [
        for (final m in donnees)
          MembreCasting.depuisJson(m as Map<String, dynamic>)
      ];
    } on ExceptionApi {
      // titre pas encore en cache : la section se tait plutôt que d'alarmer
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return FutureBuilder<List<MembreCasting>>(
      future: _casting,
      builder: (context, instantane) {
        final liste = instantane.data;
        if (liste == null || liste.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Distribution', style: typo.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _CarteActeur(membre: liste[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CarteActeur extends StatelessWidget {
  final MembreCasting membre;
  const _CarteActeur({required this.membre});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final url = urlImageTmdb(membre.photo, largeur: 185);
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 92,
              height: 108,
              child: url == null
                  ? Container(
                      color: CouleursSW.surface,
                      child: const Icon(Icons.person_outline,
                          color: CouleursSW.texteSecondaire),
                    )
                  : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(membre.nom,
              style: typo.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (membre.personnage != null)
            Text(membre.personnage!,
                style: typo.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (membre.dejaVuDans > 0) ...[
            const SizedBox(height: 4),
            Text(
                membre.dejaVuDans == 1
                    ? 'Déjà vu·e dans 1 titre'
                    : 'Déjà vu·e dans ${membre.dejaVuDans} titres',
                style: typo.labelSmall?.copyWith(
                    color: CouleursSW.accentSecondaire,
                    fontWeight: FontWeight.w700),
                maxLines: 2),
          ],
        ],
      ),
    );
  }
}
