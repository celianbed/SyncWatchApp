// Profil — infos du compte, édition (pseudo/avatar), notifications, déconnexion.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/client_api.dart';
import '../api/session.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../util/avatars.dart';
import '../util/validation.dart';
import '../widgets/rangee_resultats.dart';
import 'ecran_blocages.dart';
import 'ecran_communaute.dart';
import 'ecran_liste_resultats.dart';
import 'ecran_notifications.dart';

const _moisPleins = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

class EcranProfil extends StatefulWidget {
  /// Rappel pour basculer vers l'onglet Recherche (« Trouver des amis »).
  final VoidCallback? onOuvrirRecherche;
  const EcranProfil({super.key, this.onOuvrirRecherche});

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  late Future<StatsGlobales> _stats;
  late Future<List<ResultatRecherche>> _favoris;
  late Future<List<ResultatRecherche>> _filmsVus;
  late Future<List<ResultatRecherche>> _aVoir;
  late Future<int> _nonLues;
  Future<ProfilPublic>? _communaute; // compteurs abonnés/abonnements

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    _stats = _chargerStats();
    _favoris = _chargerListe('/utilisateurs/moi/favoris');
    _filmsVus = _chargerListe('/utilisateurs/moi/films-vus');
    _aVoir = _chargerListe('/utilisateurs/moi/a-voir');
    _nonLues = _chargerNonLues();
    final id = context.read<Session>().utilisateur?.id;
    if (id != null) _communaute = _chargerCommunaute(id);
  }

  Future<ProfilPublic> _chargerCommunaute(int id) async =>
      ProfilPublic.depuisJson(
          await api.get('/utilisateurs/$id') as Map<String, dynamic>);

  Future<StatsGlobales> _chargerStats() async =>
      StatsGlobales.depuisJson(await api.get('/stats') as Map<String, dynamic>);

  Future<int> _chargerNonLues() async {
    // route dédiée : compter en récupérant la liste la rendrait impossible à borner
    final donnees = await api.get('/notifications/nombre-non-lues');
    return (donnees as Map<String, dynamic>)['nombre'] as int;
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
    await Future.wait([_stats, _favoris, _filmsVus, _aVoir]);
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
              const SizedBox(height: 20),
              _CarteCommunaute(
                communaute: _communaute,
                surOuvrir: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        EcranCommunaute(idUtilisateur: utilisateur.id))),
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
            // Les films mis de côté depuis leur fiche : sans cette section, le
            // bouton « À voir plus tard » écrivait dans le vide.
            _TitreSection(titre: 'À voir'),
            const SizedBox(height: 12),
            CarrouselResultats(
                resultats: _aVoir,
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
                    leading: const Icon(Icons.person_search_outlined,
                        color: CouleursSW.texteSecondaire, size: 22),
                    title: Text('Trouver des amis', style: typo.bodyMedium),
                    trailing: const Icon(Icons.chevron_right,
                        color: CouleursSW.texteSecondaire),
                    onTap: widget.onOuvrirRecherche,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.block,
                        color: CouleursSW.texteSecondaire, size: 22),
                    title: Text('Personnes bloquées', style: typo.bodyMedium),
                    trailing: const Icon(Icons.chevron_right,
                        color: CouleursSW.texteSecondaire),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const EcranBlocages())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined,
                        color: CouleursSW.texteSecondaire, size: 22),
                    title: Text('Confidentialité', style: typo.bodyMedium),
                    trailing: const Icon(Icons.open_in_new,
                        color: CouleursSW.texteSecondaire, size: 18),
                    onTap: () => _ouvrirPageLegale('/confidentialite'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined,
                        color: CouleursSW.texteSecondaire, size: 22),
                    title: Text('Mentions légales', style: typo.bodyMedium),
                    trailing: const Icon(Icons.open_in_new,
                        color: CouleursSW.texteSecondaire, size: 18),
                    onTap: () => _ouvrirPageLegale('/mentions-legales'),
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
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined,
                        color: CouleursSW.danger, size: 22),
                    title: Text('Supprimer mon compte',
                        style: typo.bodyMedium
                            ?.copyWith(color: CouleursSW.danger)),
                    onTap: () => _confirmerSuppression(context),
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

  /// Ouvre une page légale servie par l'API, dans le navigateur du système.
  Future<void> _ouvrirPageLegale(String chemin) async {
    final uri = Uri.parse('${ClientApi.urlBase}$chemin');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir la page.')));
      }
    }
  }

  void _modifierProfil(BuildContext context, Utilisateur utilisateur) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // laisse la place au clavier
      builder: (_) => _FeuilleEditionProfil(utilisateur: utilisateur),
    );
  }

  /// Suppression définitive du compte — obligatoire dans l'app pour l'App Store,
  /// et volontairement plus engageante qu'une simple déconnexion.
  void _confirmerSuppression(BuildContext context) {
    showDialog(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: CouleursSW.surface,
        title: const Text('Supprimer ton compte ?'),
        content: const Text(
            'Ton suivi, tes épisodes vus, tes avis et tes abonnements seront '
            'effacés définitivement. Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(contexteDialogue).pop(),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.of(contexteDialogue).pop();
              _supprimer(context);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: CouleursSW.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _supprimer(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await context.read<Session>().supprimerMonCompte();
      // succès : main.dart revient à l'écran de connexion via le Consumer<Session>
    } catch (e) {
      messager.showSnackBar(SnackBar(content: Text(e.toString())));
    }
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

/// Carte « Ma communauté » (haut du profil) : accès aux abonnés/abonnements
/// avec les compteurs en sous-titre.
class _CarteCommunaute extends StatelessWidget {
  final Future<ProfilPublic>? communaute;
  final VoidCallback surOuvrir;
  const _CarteCommunaute({required this.communaute, required this.surOuvrir});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.people_outline,
            color: CouleursSW.accent, size: 24),
        title: Text('Ma communauté', style: typo.bodyMedium),
        subtitle: FutureBuilder<ProfilPublic>(
          future: communaute,
          builder: (_, snap) {
            final c = snap.data;
            if (c == null) return const SizedBox.shrink();
            return Text(
                '${c.nbAbonnes} abonnés · ${c.nbAbonnements} abonnements',
                style: typo.labelSmall);
          },
        ),
        trailing: const Icon(Icons.chevron_right,
            color: CouleursSW.texteSecondaire),
        onTap: surOuvrir,
      ),
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
  late String _avatar = widget.utilisateur.avatar ?? '';
  bool _chargement = false;

  /// La grille : les avatars proposés, plus celui déjà porté s'il vient
  /// d'ailleurs (un compte plus ancien avait pu coller n'importe quelle URL).
  List<String> get _choix {
    final actuel = widget.utilisateur.avatar;
    return [
      if (actuel != null && actuel.isNotEmpty && !avatarsProposes.contains(actuel))
        actuel,
      ...avatarsProposes,
    ];
  }

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formulaire.currentState!.validate()) return;
    final pseudo = _pseudo.text.trim();
    final avatar = _avatar;
    final pseudoChange = pseudo != widget.utilisateur.pseudo;
    final avatarChange = avatar != (widget.utilisateur.avatar ?? '');
    if (!pseudoChange && !avatarChange) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _chargement = true);
    // capturé avant le pop : après, ce contexte n'a plus de Scaffold sous lui
    final messager = ScaffoldMessenger.of(context);
    try {
      await context.read<Session>().mettreAJourProfil(
          pseudo: pseudoChange ? pseudo : null,
          avatar: avatarChange ? avatar : null);
      if (!mounted) return;
      Navigator.of(context).pop();
      messager.showSnackBar(
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
              validator: erreurPseudo,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Avatar', style: typo.labelSmall),
            ),
            const SizedBox(height: 10),
            _GrilleAvatars(
              choix: _choix,
              selection: _avatar,
              surChoisir: (url) => setState(() => _avatar = url),
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

/// Grille de choix d'avatar : la sélection est visible tout de suite, elle
/// part au serveur avec le reste du formulaire. La première case retire
/// l'avatar et rend les initiales.
class _GrilleAvatars extends StatelessWidget {
  final List<String> choix;
  final String selection;
  final ValueChanged<String> surChoisir;

  const _GrilleAvatars(
      {required this.choix, required this.selection, required this.surChoisir});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: GridView.count(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        padding: EdgeInsets.zero,
        children: [
          _CaseAvatar(
            selectionne: selection.isEmpty,
            surTape: () => surChoisir(''),
            child: const Icon(Icons.person_off_outlined,
                color: CouleursSW.texteSecondaire, size: 22),
          ),
          for (final url in choix)
            _CaseAvatar(
              selectionne: selection == url,
              surTape: () => surChoisir(url),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const Icon(Icons.broken_image,
                      color: CouleursSW.texteSecondaire, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaseAvatar extends StatelessWidget {
  final bool selectionne;
  final VoidCallback surTape;
  final Widget child;

  const _CaseAvatar(
      {required this.selectionne, required this.surTape, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: surTape,
      child: Container(
        decoration: BoxDecoration(
          color: CouleursSW.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: selectionne ? CouleursSW.accent : Colors.transparent,
            width: 2.5,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Center(child: child),
      ),
    );
  }
}
