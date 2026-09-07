// Recherche — deux modes : Titres (séries/films TMDB) et Utilisateurs (amis).
import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../widgets/squelette.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/affiche_tmdb.dart';
import '../widgets/rangee_utilisateur.dart';
import 'ecran_fiche_film.dart';
import 'ecran_fiche_serie.dart';
import 'ecran_profil_public.dart';

class EcranRecherche extends StatefulWidget {
  const EcranRecherche({super.key});

  @override
  State<EcranRecherche> createState() => _EcranRechercheState();
}

class _EcranRechercheState extends State<EcranRecherche> {
  final _champ = TextEditingController();
  Timer? _antiRebond;
  String _mode = 'titres'; // 'titres' | 'utilisateurs'
  List<ResultatRecherche>? _resultats; // null = pas de recherche titres (séries + films)
  List<ResumeUtilisateur>? _users; // null = pas de recherche users
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

  void _changerMode(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _resultats = null;
      _users = null;
    });
    _chercher(_champ.text);
  }

  Future<void> _chercher(String q) async {
    final requete = q.trim();
    if (requete.isEmpty) {
      setState(() {
        _resultats = null;
        _users = null;
        _chargement = false;
      });
      return;
    }
    setState(() => _chargement = true);
    try {
      if (_mode == 'utilisateurs') {
        final d = await api.get('/search/utilisateurs', params: {'q': requete}) as List;
        if (!mounted || _champ.text.trim() != requete) return;
        setState(() {
          _users = [
            for (final u in d) ResumeUtilisateur.depuisJson(u as Map<String, dynamic>)
          ];
          _chargement = false;
        });
      } else {
        final d = await api.get('/search', params: {'q': requete}) as List;
        if (!mounted || _champ.text.trim() != requete) return;
        setState(() {
          _resultats = [
            for (final r in d) ResultatRecherche.depuisJson(r as Map<String, dynamic>)
          ];
          _chargement = false;
        });
      }
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final users = _mode == 'utilisateurs';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recherche', style: typo.headlineMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                _Onglet(
                    libelle: 'Titres',
                    actif: !users,
                    surTape: () => _changerMode('titres')),
                const SizedBox(width: 8),
                _Onglet(
                    libelle: 'Utilisateurs',
                    actif: users,
                    surTape: () => _changerMode('utilisateurs')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _champ,
              onChanged: _surSaisie,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: users ? 'Rechercher un pseudo…' : 'Série ou film…',
                prefixIcon: const Icon(Icons.search,
                    color: CouleursSW.texteSecondaire, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
                child: users ? _corpsUsers() : _corpsTitres(_resultats ?? [])),
          ],
        ),
      ),
    );
  }

  Widget _corpsUsers() {
    if (_chargement) return const SqueletteListe(nombre: 6, hauteur: 72);
    if (_users == null) {
      return const _Indication(
          icone: Icons.group_outlined,
          texte: 'Cherche un ami par son pseudo\npour voir son profil et le suivre.');
    }
    if (_users!.isEmpty) {
      return const _Indication(
          icone: Icons.person_off_outlined, texte: 'Aucun utilisateur trouvé.');
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _users!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final u = _users![i];
        return RangeeUtilisateur(
          utilisateur: u,
          sousTitre: '${u.nbSeries} séries · ${u.nbFilms} films',
          surOuvrir: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EcranProfilPublic(idUtilisateur: u.idUtilisateur))),
        );
      },
    );
  }

  Widget _corpsTitres(List<ResultatRecherche> filtres) {
    if (_chargement) return const SqueletteListe(nombre: 6, hauteur: 72);
    if (_resultats == null) {
      return const _Indication(
          icone: Icons.local_movies_outlined,
          texte: 'Cherche une série ou un film\npour commencer à suivre.');
    }
    if (filtres.isEmpty) {
      return const _Indication(icone: Icons.search_off, texte: 'Aucun résultat.');
    }
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2 / 3,
      ),
      itemCount: filtres.length,
      itemBuilder: (context, i) {
        final resultat = filtres[i];
        return GestureDetector(
          onTap: () {
            final page = resultat.type == 'serie'
                ? EcranFicheSerie(referenceTmdb: resultat.referenceTmdb)
                : EcranFicheFilm(referenceTmdb: resultat.referenceTmdb);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
