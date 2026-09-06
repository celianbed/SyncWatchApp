// Profil public d'un utilisateur : header, bouton Suivre, compteurs (cliquables
// vers la communauté), séries suivies et derniers avis.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/avatar_utilisateur.dart';
import '../widgets/badge_ami.dart';
import '../widgets/chargeur_async.dart';
import '../widgets/rangee_resultats.dart';
import 'ecran_communaute.dart';
import 'ecran_fiche_film.dart';
import 'ecran_fiche_serie.dart';
import 'ecran_liste_resultats.dart'; // ouvrirFiche

const _moisPleins = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

class EcranProfilPublic extends StatefulWidget {
  final int idUtilisateur;
  const EcranProfilPublic({super.key, required this.idUtilisateur});

  @override
  State<EcranProfilPublic> createState() => _EcranProfilPublicState();
}

class _EcranProfilPublicState extends State<EcranProfilPublic> {
  late Future<ProfilPublic> _profil = _chargerProfil();
  late final Future<List<ResultatRecherche>> _series = _chargerSeries();
  late final Future<List<AvisProfil>> _avis = _chargerAvis();
  late final Future<Compatibilite> _compat = _chargerCompat();
  ProfilPublic? _p;
  bool _enCours = false;

  Future<ProfilPublic> _chargerProfil() async {
    final p = ProfilPublic.depuisJson(
        await api.get('/utilisateurs/${widget.idUtilisateur}') as Map<String, dynamic>);
    _p = p;
    return p;
  }

  Future<List<ResultatRecherche>> _chargerSeries() async {
    final d = await api.get('/utilisateurs/${widget.idUtilisateur}/series-suivies') as List;
    return [for (final s in d) ResultatRecherche.depuisJson(s as Map<String, dynamic>)];
  }

  Future<List<AvisProfil>> _chargerAvis() async {
    final d = await api.get('/utilisateurs/${widget.idUtilisateur}/avis') as List;
    return [for (final a in d) AvisProfil.depuisJson(a as Map<String, dynamic>)];
  }

  Future<Compatibilite> _chargerCompat() async => Compatibilite.depuisJson(
      await api.get('/utilisateurs/${widget.idUtilisateur}/compatibilite')
          as Map<String, dynamic>);

  Future<void> _basculerAbonnement(ProfilPublic p) async {
    final avant = p.estAbonne;
    setState(() {
      p.estAbonne = !avant;
      p.nbAbonnes += avant ? -1 : 1;
      _enCours = true;
    });
    try {
      final chemin = '/utilisateurs/${p.idUtilisateur}/abonner';
      avant ? await api.delete(chemin) : await api.post(chemin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(avant
                ? 'Tu ne suis plus ${p.pseudo}'
                : 'Tu suis ${p.pseudo} ✓')));
      }
    } on ExceptionApi catch (e) {
      if (!mounted) return;
      setState(() {
        p.estAbonne = avant;
        p.nbAbonnes += avant ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _ouvrirCommunaute(bool abonnes) {
    final p = _p;
    if (p == null) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranCommunaute(
            idUtilisateur: p.idUtilisateur,
            titre: 'Communauté de ${p.pseudo}',
            abonnesDabord: abonnes)));
  }

  void _ouvrirAvis(AvisProfil a) {
    if (a.referenceTmdb == null) return;
    final page = a.type == 'film'
        ? EcranFicheFilm(referenceTmdb: a.referenceTmdb!)
        : EcranFicheSerie(referenceTmdb: a.referenceTmdb!);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ChargeurAsync<ProfilPublic>(
        future: _profil,
        surReessayer: () => setState(() => _profil = _chargerProfil()),
        enfant: _contenu,
      ),
    );
  }

  Widget _contenu(ProfilPublic p) {
    final typo = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Center(child: AvatarUtilisateur(pseudo: p.pseudo, avatar: p.avatar, taille: 84)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(p.pseudo,
                  style: typo.titleLarge,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis),
            ),
            if (p.estAmi) ...[const SizedBox(width: 8), const BadgeAmi()],
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('Membre depuis ${_moisPleins[p.dateInscription.month - 1]} '
              '${p.dateInscription.year}', style: typo.bodySmall),
        ),
        FutureBuilder<Compatibilite>(
          future: _compat,
          builder: (_, snap) {
            final c = snap.data;
            if (c == null || !c.pertinent) return const SizedBox(height: 18);
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(child: _ChipCompatibilite(compat: c)),
            );
          },
        ),
        const SizedBox(height: 18),
        _BoutonSuivrePlein(
            abonne: p.estAbonne, enCours: _enCours, surTape: () => _basculerAbonnement(p)),
        const SizedBox(height: 20),
        Row(
          children: [
            _Compteur(valeur: p.nbAbonnes, libelle: 'Abonnés',
                surTape: () => _ouvrirCommunaute(true)),
            _Compteur(valeur: p.nbAbonnements, libelle: 'Abonnements',
                surTape: () => _ouvrirCommunaute(false)),
            _Compteur(valeur: p.nbSeries, libelle: 'Séries'),
          ],
        ),
        const SizedBox(height: 28),
        Text('Séries suivies', style: typo.titleMedium),
        const SizedBox(height: 12),
        CarrouselResultats(
            resultats: _series, surOuvrir: (r) => ouvrirFiche(context, r)),
        const SizedBox(height: 28),
        Text('Derniers avis', style: typo.titleMedium),
        const SizedBox(height: 12),
        FutureBuilder<List<AvisProfil>>(
          future: _avis,
          builder: (_, snap) {
            if (!snap.hasData) return const SizedBox(height: 40);
            final avis = snap.data!;
            if (avis.isEmpty) {
              return Text('Aucun avis pour l’instant.', style: typo.bodySmall);
            }
            return Column(
              children: [
                for (final a in avis)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CarteAvis(avis: a, surTape: () => _ouvrirAvis(a)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Badge « Ami » (suivi mutuel). Public : réutilisé aussi dans la rangée.
class _BoutonSuivrePlein extends StatelessWidget {
  final bool abonne;
  final bool enCours;
  final VoidCallback surTape;
  const _BoutonSuivrePlein(
      {required this.abonne, required this.enCours, required this.surTape});

  @override
  Widget build(BuildContext context) {
    final enfant = enCours
        ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Text(abonne ? '✓  Abonné' : 'Suivre');
    final surPresse = enCours ? null : surTape;
    return abonne
        ? OutlinedButton(onPressed: surPresse, child: enfant)
        : FilledButton(onPressed: surPresse, child: enfant);
  }
}

class _ChipCompatibilite extends StatelessWidget {
  final Compatibilite compat;
  const _ChipCompatibilite({required this.compat});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CouleursSW.accent.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${compat.pourcentage}% compatible',
              style: typo.titleMedium?.copyWith(
                  color: CouleursSW.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(compat.detail, style: typo.labelSmall),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  final int valeur;
  final String libelle;
  final VoidCallback? surTape;
  const _Compteur({required this.valeur, required this.libelle, this.surTape});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: surTape,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Text('$valeur',
                    style: typo.titleLarge?.copyWith(color: CouleursSW.accent)),
                const SizedBox(height: 2),
                Text(libelle, style: typo.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteAvis extends StatelessWidget {
  final AvisProfil avis;
  final VoidCallback surTape;
  const _CarteAvis({required this.avis, required this.surTape});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: surTape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(avis.titre,
                    style: typo.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (avis.note != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CouleursSW.accentSecondaire.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('★ ${avis.note}/10',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CouleursSW.accentSecondaire)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
