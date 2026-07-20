// Profil — infos du compte, édition (pseudo/avatar), notifications, déconnexion.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../api/client_api.dart';
import '../api/session.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import 'ecran_notifications.dart';

const _moisPleins = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

class EcranProfil extends StatelessWidget {
  const EcranProfil({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final utilisateur = session.utilisateur;
    final typo = Theme.of(context).textTheme;

    return SafeArea(
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
          const SizedBox(height: 32),
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
                  trailing: const Icon(Icons.chevron_right,
                      color: CouleursSW.texteSecondaire),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EcranNotifications())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout,
                      color: CouleursSW.danger, size: 22),
                  title: Text('Se déconnecter',
                      style:
                          typo.bodyMedium?.copyWith(color: CouleursSW.danger)),
                  onTap: () => _confirmerDeconnexion(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('API : ${ClientApi.urlBase}',
              style: typo.labelSmall, textAlign: TextAlign.center),
        ],
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
