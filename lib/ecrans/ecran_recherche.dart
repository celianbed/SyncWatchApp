// Recherche TMDB — onglets Séries | Films, grille d'affiches 3 colonnes 2:3.
// Wireframe W2 · Recherche.
import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/affiche_tmdb.dart';
import 'ecran_fiche_film.dart';
import 'ecran_fiche_serie.dart';

class EcranRecherche extends StatefulWidget {
  const EcranRecherche({super.key});

  @override
  State<EcranRecherche> createState() => _EcranRechercheState();
}

class _EcranRechercheState extends State<EcranRecherche> {
  final _champ = TextEditingController();
  Timer? _antiRebond;
  String _onglet = 'serie';
  List<ResultatRecherche>? _resultats; // null = pas encore de recherche
  bool _chargement = false;

  @override
  void dispose() {
    _antiRebond?.cancel();
    _champ.dispose();
    super.dispose();
  }

  void _surSaisie(String q) {
    _antiRebond?.cancel();
    _antiRebond = Timer(const Duration(milliseconds: 400), () => _chercher(q));
  }

  Future<void> _chercher(String q) async {
    final requete = q.trim();
    if (requete.isEmpty) {
      setState(() {
        _resultats = null;
        _chargement = false;
      });
      return;
    }
    setState(() => _chargement = true);
    try {
      final donnees = await api.get('/search', params: {'q': requete}) as List;
      if (!mounted || _champ.text.trim() != requete) return; // réponse périmée
      setState(() {
        _resultats = [
          for (final r in donnees)
            ResultatRecherche.depuisJson(r as Map<String, dynamic>)
        ];
        _chargement = false;
      });
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final filtres =
        _resultats?.where((r) => r.type == _onglet).toList() ?? [];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recherche', style: typo.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _champ,
              onChanged: _surSaisie,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Série ou film…',
                prefixIcon: Icon(Icons.search,
                    color: CouleursSW.texteSecondaire, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Onglet(
                    libelle: 'Séries',
                    actif: _onglet == 'serie',
                    surTape: () => setState(() => _onglet = 'serie')),
                const SizedBox(width: 8),
                _Onglet(
                    libelle: 'Films',
                    actif: _onglet == 'film',
                    surTape: () => setState(() => _onglet = 'film')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _corps(filtres)),
          ],
        ),
      ),
    );
  }

  Widget _corps(List<ResultatRecherche> filtres) {
    if (_chargement) return const Center(child: CircularProgressIndicator());
    if (_resultats == null) {
      return const _Indication(
          icone: Icons.local_movies_outlined,
          texte: 'Cherche une série ou un film\npour commencer à suivre.');
    }
    if (filtres.isEmpty) {
      return const _Indication(
          icone: Icons.search_off, texte: 'Aucun résultat.');
    }
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2 / 3, // affiches 2:3, cf. charte
      ),
      itemCount: filtres.length,
      itemBuilder: (context, i) {
        final resultat = filtres[i];
        return GestureDetector(
          onTap: () {
            final page = resultat.type == 'serie'
                ? EcranFicheSerie(referenceTmdb: resultat.referenceTmdb)
                : EcranFicheFilm(referenceTmdb: resultat.referenceTmdb);
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => page));
          },
          child: LayoutBuilder(
            builder: (_, contraintes) => AfficheTmdb(
                chemin: resultat.affiche,
                largeur: contraintes.maxWidth,
                hauteur: contraintes.maxHeight),
          ),
        );
      },
    );
  }
}

class _Onglet extends StatelessWidget {
  final String libelle;
  final bool actif;
  final VoidCallback surTape;

  const _Onglet(
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
            border: Border.all(
                color: actif ? CouleursSW.accent : Colors.transparent),
          ),
          child: Text(libelle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: actif ? CouleursSW.accent : CouleursSW.texteSecondaire)),
        ),
      ),
    );
  }
}

class _Indication extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _Indication({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48, color: CouleursSW.texteSecondaire),
          const SizedBox(height: 12),
          Text(texte,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
