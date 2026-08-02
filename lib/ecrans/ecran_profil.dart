// Profil — infos du compte, édition (pseudo/avatar), notifications, déconnexion.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../api/session.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../widgets/rangee_resultats.dart';
import 'ecran_liste_resultats.dart';
import 'ecran_notifications.dart';

const _moisPleins = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

class EcranProfil extends StatefulWidget {
  const EcranProfil({super.key});

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  late Future<StatsGlobales> _stats;
  late Future<List<ResultatRecherche>> _favoris;
  late Future<List<ResultatRecherche>> _filmsVus;
  late Future<int> _nonLues;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    _stats = _chargerStats();
    _favoris = _chargerListe('/utilisateurs/moi/favoris');
    _filmsVus = _chargerListe('/utilisateurs/moi/films-vus');
    _nonLues = _chargerNonLues();
  }

  Future<StatsGlobales> _chargerStats() async =>
      StatsGlobales.depuisJson(await api.get('/stats') as Map<String, dynamic>);

  Future<int> _chargerNonLues() async {
    final donnees =
        await api.get('/notifications', params: {'lue': 'false'}) as List;
    return donnees.length;
  }

  Future<List<ResultatRecherche>> _chargerListe(String chemin) async {
    final donnees = await api.get(chemin) as List;
    return [
      for (final r in donnees)
        ResultatRecherche.depuisJson(r as Map<String, dynamic>)
    ];
  }

  Future<void> _rafraichir() async {
    setState(_charger);
    await Future.wait([_stats, _favoris, _filmsVus]);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final utilisateur = session.utilisateur;
    final typo = Theme.of(context).textTheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _rafraichir,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(child: _Avatar(utilisateur: utilisateur)),
            const SizedBox(height: 16),
            Text(utilisateur?.pseudo ?? '…',
                style: typo.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(utilisateur?.adresseMail ?? '',
                style: typo.bodySmall, textAlign: TextAlign.center),
            if (utilisateur != null) ...[
              const SizedBox(height: 4),
              Text(
                'Membre depuis ${_moisPleins[utilisateur.dateInscription.month - 1]} ${utilisateur.dateInscription.year}',
                style: typo.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),
            // Résumé des statistiques
            FutureBuilder<StatsGlobales>(
              future: _stats,
              builder: (context, snap) => snap.hasData
                  ? _RangeeStats(stats: snap.data!)
                  : const SizedBox(height: 72),
            ),
            const SizedBox(height: 28),
            _TitreSection(titre: 'Favoris'),
            const SizedBox(height: 12),
            CarrouselResultats(
                resultats: _favoris,
                surOuvrir: (r) => ouvrirFiche(context, r)),
            const SizedBox(height: 28),
            _TitreSection(titre: 'Vu récemment'),
            const SizedBox(height: 12),
            CarrouselResultats(
                resultats: _filmsVus,
                surOuvrir: (r) => ouvrirFiche(context, r)),
            const SizedBox(height: 28),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined,
                        color: CouleursSW.texteSecondaire, size: 22),
                    title: Text('Modifier le profil', style: typo.bodyMedium),
                    trailing: const Icon(Icons.chevron_right,
                        color: CouleursSW.texteSecondaire),
                    onTap: utilisateur == null
                        ? null
                        : () => _modifierProfil(context, utilisateur),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined,
                        color: CouleursSW.texteSecondaire, size: 22),
                    title: Text('Notifications', style: typo.bodyMedium),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FutureBuilder<int>(
                          future: _nonLues,
                          builder: (context, snap) {
                            final n = snap.data ?? 0;
                            if (n == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: CouleursSW.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(n > 9 ? '9+' : '$n',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            );
                          },
                        ),
                        const Icon(Icons.chevron_right,
                            color: CouleursSW.texteSecondaire),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const EcranNotifications()));
                      // au retour, le nombre de non lues a pu changer
                      if (mounted) {
                        setState(() => _nonLues = _chargerNonLues());
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout,
                        color: CouleursSW.danger, size: 22),
                    title: Text('Se déconnecter',
                        style: typo.bodyMedium
                            ?.copyWith(color: CouleursSW.danger)),
                    onTap: () => _confirmerDeconnexion(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const _CreditTmdb(),
          ],
        ),
      ),
    );
  }

  void _modifierProfil(BuildContext context, Utilisateur utilisateur) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // laisse la place au clavier
      builder: (_) => _FeuilleEditionProfil(utilisateur: utilisateur),
    );
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: CouleursSW.surface,
        title: const Text('Se déconnecter ?'),
        content: const Text('Tu devras te reconnecter pour retrouver ton suivi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(contexteDialogue).pop(),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.of(contexteDialogue).pop();
              context.read<Session>().deconnexion();
            },
            child: const Text('Se déconnecter',
                style: TextStyle(color: CouleursSW.danger)),
          ),
        ],
      ),
    );
  }
}

/// Crédit TMDB — attribution obligatoire de l'API TMDB (métadonnées, affiches,
/// bandes-annonces). L'app n'est ni approuvée ni certifiée par TMDB.
class _CreditTmdb extends StatelessWidget {
  const _CreditTmdb();

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('Métadonnées, affiches et bandes-annonces fournies par TMDB',
            style: typo.labelSmall, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          style: typo.labelSmall?.copyWith(color: CouleursSW.texteSecondaire),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Titre de section (Favoris, Vu récemment…).
class _TitreSection extends StatelessWidget {
  final String titre;
  const _TitreSection({required this.titre});

  @override
  Widget build(BuildContext context) =>
      Text(titre, style: Theme.of(context).textTheme.titleMedium);
}

/// Résumé compact des statistiques : 4 tuiles.
class _RangeeStats extends StatelessWidget {
  final StatsGlobales stats;
  const _RangeeStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('${(stats.minutesTotales / 60).round()} h', 'vues'),
      ('${stats.episodesVus}', 'épisodes'),
      ('${stats.filmsVus}', 'films'),
      ('${stats.seriesTerminees}', 'séries finies'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _MiniStat(valeur: items[i].$1, libelle: items[i].$2)),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String valeur;
  final String libelle;
  const _MiniStat({required this.valeur, required this.libelle});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          children: [
            Text(valeur,
                style: typo.titleMedium?.copyWith(color: CouleursSW.accent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(libelle,
                style: typo.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Avatar circulaire : image distante si renseignée, sinon initiales.
class _Avatar extends StatelessWidget {
  final Utilisateur? utilisateur;
  const _Avatar({required this.utilisateur});

  @override
  Widget build(BuildContext context) {
    final initiales = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: CouleursSW.accent.withValues(alpha: .2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          utilisateur == null || utilisateur!.pseudo.isEmpty
              ? '?'
              : utilisateur!.pseudo
                  .substring(0, utilisateur!.pseudo.length >= 2 ? 2 : 1)
                  .toUpperCase(),
          style: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: CouleursSW.accent),
        ),
      ),
    );
    final avatar = utilisateur?.avatar;
    if (avatar == null || avatar.isEmpty) return initiales;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatar,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        placeholder: (_, _) => initiales,
        errorWidget: (_, _, _) => initiales,
      ),
    );
  }
}

/// Feuille d'édition du profil — n'envoie que les champs modifiés.
class _FeuilleEditionProfil extends StatefulWidget {
  final Utilisateur utilisateur;
  const _FeuilleEditionProfil({required this.utilisateur});

  @override
  State<_FeuilleEditionProfil> createState() => _FeuilleEditionProfilState();
}

class _FeuilleEditionProfilState extends State<_FeuilleEditionProfil> {
  final _formulaire = GlobalKey<FormState>();
  late final _pseudo = TextEditingController(text: widget.utilisateur.pseudo);
  late final _avatar =
      TextEditingController(text: widget.utilisateur.avatar ?? '');
  bool _chargement = false;

  @override
  void dispose() {
    _pseudo.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formulaire.currentState!.validate()) return;
    final pseudo = _pseudo.text.trim();
    final avatar = _avatar.text.trim();
    final pseudoChange = pseudo != widget.utilisateur.pseudo;
    final avatarChange = avatar != (widget.utilisateur.avatar ?? '');
    if (!pseudoChange && !avatarChange) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _chargement = true);
    try {
      await context.read<Session>().mettreAJourProfil(
          pseudo: pseudoChange ? pseudo : null,
          avatar: avatarChange ? avatar : null);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour ✓')));
    } on ExceptionApi catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Padding(
      // remonte la feuille au-dessus du clavier
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formulaire,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Modifier le profil', style: typo.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _pseudo,
              decoration: const InputDecoration(
                hintText: 'Pseudo',
                prefixIcon: Icon(Icons.person_outline,
                    color: CouleursSW.texteSecondaire, size: 20),
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? '3 caractères minimum'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _avatar,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'URL de l’avatar (vide = aucun)',
                prefixIcon: Icon(Icons.image_outlined,
                    color: CouleursSW.texteSecondaire, size: 20),
              ),
              validator: (v) {
                final url = v?.trim() ?? '';
                return url.isEmpty || url.startsWith('http')
                    ? null
                    : 'URL invalide (http/https)';
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _chargement ? null : _enregistrer,
              child: _chargement
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
