// Connexion / inscription — email ou pseudo + mot de passe.
import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api/client_api.dart';
import '../api/session.dart';
import '../theme.dart';
import '../widgets/halo.dart';

class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _formulaire = GlobalKey<FormState>();
  final _mail = TextEditingController();
  final _pseudo = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _inscription = false;
  bool _chargement = false;
  bool _masquerMdp = true;
  // Non null → on affiche le panneau « vérifie ton adresse mail » (valeur = mail deviné).
  String? _mailAverifier;
  // identifiant + mot de passe conservés pour le sondage (connexion auto une fois vérifié)
  String _identifiantAverifier = '';
  String _mdpAverifier = '';

  @override
  void dispose() {
    _mail.dispose();
    _pseudo.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formulaire.currentState!.validate()) return;
    setState(() => _chargement = true);
    final session = context.read<Session>();
    try {
      if (_inscription) {
        await session.inscription(
          _mail.text.trim(),
          _pseudo.text.trim(),
          _motDePasse.text,
        );
        // compte créé : il faut confirmer l'adresse avant de pouvoir se connecter
        if (mounted) {
          _ouvrirPanneauVerification(_mail.text.trim(), _mail.text.trim());
        }
      } else {
        await session.connexion(_mail.text.trim(), _motDePasse.text);
        // succès : main.dart bascule vers la coquille via le Consumer<Session>
      }
    } on ExceptionApi catch (e) {
      // 403 « Adresse mail non vérifiée » → on bascule sur l'attente de vérification
      if (!_inscription && e.code == 403 && e.message.contains('vérifi')) {
        final identifiant = _mail.text.trim();
        if (mounted) {
          _ouvrirPanneauVerification(
            identifiant,
            identifiant.contains('@') ? identifiant : '',
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _basculer(bool inscription) {
    if (_inscription != inscription) {
      setState(() => _inscription = inscription);
    }
  }

  Future<void> _connexionGoogle() =>
      _connexionFournisseur((session) => session.connexionGoogle());

  Future<void> _connexionApple() =>
      _connexionFournisseur((session) => session.connexionApple());

  Future<void> _connexionFournisseur(
      Future<void> Function(Session) connecter) async {
    setState(() => _chargement = true);
    try {
      await connecter(context.read<Session>());
      // succès : main.dart bascule vers la coquille via le Consumer<Session>
    } on SignInWithAppleAuthorizationException catch (e) {
      // annulation de la feuille Apple : ce n'est pas une erreur à afficher
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connexion Apple impossible.')));
      }
    } on ExceptionApi catch (e) {
      if (mounted && e.message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  /// Affiche le panneau d'attente de vérification en mémorisant de quoi sonder
  /// la connexion (identifiant + mot de passe) et pré-remplir le renvoi de mail.
  void _ouvrirPanneauVerification(String identifiant, String mailPourRenvoi) {
    setState(() {
      _identifiantAverifier = identifiant;
      _mdpAverifier = _motDePasse.text;
      _mailAverifier = mailPourRenvoi;
    });
  }

  /// Ouvre la feuille « mot de passe oublié » (reset via lien web).
  void _motDePasseOublie() {
    final prerempli = _mail.text.contains('@') ? _mail.text.trim() : '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleMotDePasseOublie(mailInitial: prerempli),
    );
  }

  /// Retour au formulaire depuis le panneau de vérification, mail pré-rempli.
  void _revenirConnexion(String mail) {
    if (mail.isNotEmpty) _mail.text = mail;
    _motDePasse.clear();
    setState(() {
      _mailAverifier = null;
      _inscription = false;
      // ne pas garder le mot de passe en clair en mémoire une fois le sondage fini
      _identifiantAverifier = '';
      _mdpAverifier = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          const Halo(
            couleur: CouleursSW.accent,
            alignement: Alignment(-1.2, -1.0),
          ),
          const Halo(
            couleur: CouleursSW.accentSecondaire,
            alignement: Alignment(1.3, 1.1),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: _mailAverifier != null
                    ? _PanneauVerification(
                        mailInitial: _mailAverifier!,
                        identifiant: _identifiantAverifier,
                        motDePasse: _mdpAverifier,
                        surRetour: _revenirConnexion,
                      )
                    : Form(
                        key: _formulaire,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Wordmark : la typo est le logo (pas de pastille)
                            Text.rich(
                              TextSpan(
                                style: GoogleFonts.sora(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: CouleursSW.texte,
                                ),
                                children: const [
                                  TextSpan(text: 'Sync'),
                                  TextSpan(
                                    text: 'Watch',
                                    style: TextStyle(color: CouleursSW.accent),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            // courte barre d'accent sous le wordmark
                            Center(
                              child: Container(
                                width: 34,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: CouleursSW.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Tes séries et tes films, au même endroit.',
                              style: typo.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                _Onglet(
                                  libelle: 'Connexion',
                                  actif: !_inscription,
                                  surTape: () => _basculer(false),
                                ),
                                const SizedBox(width: 8),
                                _Onglet(
                                  libelle: 'Inscription',
                                  actif: _inscription,
                                  surTape: () => _basculer(true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_inscription) ...[
                              TextFormField(
                                controller: _pseudo,
                                decoration: const InputDecoration(
                                  hintText: 'Pseudo',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: CouleursSW.texteSecondaire,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().length < 3)
                                    ? '3 caractères minimum'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _mail,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: InputDecoration(
                                hintText: _inscription
                                    ? 'Adresse mail'
                                    : 'Adresse mail ou pseudo',
                                prefixIcon: const Icon(
                                  Icons.alternate_email,
                                  color: CouleursSW.texteSecondaire,
                                  size: 20,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Champ requis';
                                }
                                if (_inscription && !v.contains('@')) {
                                  return 'Adresse mail invalide';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _motDePasse,
                              obscureText: _masquerMdp,
                              decoration: InputDecoration(
                                hintText: 'Mot de passe',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: CouleursSW.texteSecondaire,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _masquerMdp
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: CouleursSW.texteSecondaire,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _masquerMdp = !_masquerMdp,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                                  (_inscription && (v == null || v.length < 8))
                                  ? '8 caractères minimum'
                                  : (v == null || v.isEmpty)
                                  ? 'Champ requis'
                                  : null,
                              onFieldSubmitted: (_) => _valider(),
                            ),
                            if (!_inscription)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _motDePasseOublie,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Mot de passe oublié ?'),
                                ),
                              ),
                            SizedBox(height: _inscription ? 24 : 12),
                            ElevatedButton(
                              onPressed: _chargement ? null : _valider,
                              child: _chargement
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _inscription
                                          ? 'Créer mon compte'
                                          : 'Se connecter',
                                    ),
                            ),
                            ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: .12))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text('ou', style: typo.bodySmall),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: .12))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Apple avant Google : Apple demande que son bouton
                            // ne soit pas moins visible que les autres logins.
                            if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                              SignInWithAppleButton(
                                onPressed:
                                    _chargement ? () {} : _connexionApple,
                                text: 'Continuer avec Apple',
                                height: 48,
                                style: SignInWithAppleButtonStyle.white,
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(14)),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (googleDisponible)
                            OutlinedButton.icon(
                              onPressed:
                                  _chargement ? null : _connexionGoogle,
                              icon: const Text('G',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF4285F4))),
                              label: const Text('Continuer avec Google'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: CouleursSW.texte,
                                side: BorderSide(
                                    color: Colors.white
                                        .withValues(alpha: .18)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille de saisie de l'adresse mail pour recevoir un lien de réinitialisation.
class _FeuilleMotDePasseOublie extends StatefulWidget {
  final String mailInitial;
  const _FeuilleMotDePasseOublie({required this.mailInitial});

  @override
  State<_FeuilleMotDePasseOublie> createState() =>
      _FeuilleMotDePasseOublieState();
}

class _FeuilleMotDePasseOublieState extends State<_FeuilleMotDePasseOublie> {
  late final _mail = TextEditingController(text: widget.mailInitial);
  bool _envoi = false;

  @override
  void dispose() {
    _mail.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final mail = _mail.text.trim();
    if (!mail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renseigne une adresse mail valide.')),
      );
      return;
    }
    setState(() => _envoi = true);
    try {
      await context.read<Session>().motDePasseOublie(mail);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si un compte existe, un lien de réinitialisation vient de partir.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mot de passe oublié', style: typo.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Entre ton adresse mail et on t’envoie un lien pour choisir un '
            'nouveau mot de passe.',
            style: typo.bodySmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Adresse mail',
              prefixIcon: Icon(
                Icons.alternate_email,
                color: CouleursSW.texteSecondaire,
                size: 20,
              ),
            ),
            onSubmitted: (_) => _envoyer(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _envoi ? null : _envoyer,
            child: _envoi
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
  }
}

/// Pastille plate : rond légèrement teinté + icône de la même couleur.
/// (Ni dégradé ni glow — cohérent avec le wordmark épuré.)
class _PastilleLogo extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  const _PastilleLogo({required this.icone, this.couleur = CouleursSW.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .14),
          shape: BoxShape.circle,
        ),
        child: Icon(icone, size: 34, color: couleur),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  final String libelle;
  final bool actif;
  final VoidCallback surTape;

  const _Onglet({
    required this.libelle,
    required this.actif,
    required this.surTape,
  });

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
              color: actif ? CouleursSW.accent : Colors.transparent,
            ),
          ),
          child: Text(
            libelle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: actif ? CouleursSW.accent : CouleursSW.texteSecondaire,
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran intermédiaire après inscription (ou login d'un compte non vérifié).
/// Attend la confirmation d'adresse en « temps réel » : sonde la connexion en
/// arrière-plan et, dès que le compte est vérifié, connecte automatiquement.
class _PanneauVerification extends StatefulWidget {
  final String mailInitial;
  final String identifiant; // mail ou pseudo, pour sonder la connexion
  final String motDePasse;
  final void Function(String mail) surRetour;

  const _PanneauVerification({
    required this.mailInitial,
    required this.identifiant,
    required this.motDePasse,
    required this.surRetour,
  });

  @override
  State<_PanneauVerification> createState() => _PanneauVerificationState();
}

class _PanneauVerificationState extends State<_PanneauVerification> {
  late final _mail = TextEditingController(text: widget.mailInitial);
  bool _envoi = false;
  int _cooldown = 0; // secondes avant de pouvoir renvoyer
  Timer? _minuteurCooldown;

  bool _verifie =
      false; // vérification détectée → on affiche le ✅ puis on connecte
  bool _sondageEnCours = false;
  Timer? _minuteurSondage;

  @override
  void initState() {
    super.initState();
    // Sonde tout de suite puis toutes les 5 s, tant que non vérifié.
    // 5 s = 12 appels/min : sous le quota de /auth/connexion (30/min côté API).
    _sonder();
    _minuteurSondage = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _sonder(),
    );
  }

  @override
  void dispose() {
    _minuteurCooldown?.cancel();
    _minuteurSondage?.cancel();
    _mail.dispose();
    super.dispose();
  }

  /// Tente la connexion : 403 tant que non vérifié, succès une fois le lien cliqué.
  Future<void> _sonder() async {
    if (_sondageEnCours || _verifie || widget.identifiant.isEmpty) return;
    _sondageEnCours = true;
    try {
      final jeton = await api.connexion(widget.identifiant, widget.motDePasse);
      // compte vérifié : on affiche le ✅ un court instant, puis on entre dans l'app
      _minuteurSondage?.cancel();
      if (!mounted) return;
      setState(() => _verifie = true);
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      await context.read<Session>().connecterAvecJeton(jeton);
      // main.dart bascule vers la Coquille via le Consumer<Session>
    } on ExceptionApi catch (e) {
      // 403 = pas encore vérifié, 429 = quota atteint → on réessaiera au prochain tick
      if (e.code != 403 && e.code != 429 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      // erreur réseau ponctuelle : on ignore, le prochain tick retentera
    } finally {
      _sondageEnCours = false;
    }
  }

  void _demarrerCooldown() {
    setState(() => _cooldown = 30);
    _minuteurCooldown?.cancel();
    _minuteurCooldown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _renvoyer() async {
    final mail = _mail.text.trim();
    if (!mail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renseigne une adresse mail valide.')),
      );
      return;
    }
    setState(() => _envoi = true);
    try {
      await context.read<Session>().renvoyerVerification(mail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si un compte non vérifié existe, '
              'un nouveau lien vient de partir.',
            ),
          ),
        );
      }
      _demarrerCooldown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;

    // État final : vérifié → ✅ + connexion automatique en cours
    if (_verifie) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PastilleLogo(
              icone: Icons.check_rounded, couleur: CouleursSW.succes),
          const SizedBox(height: 20),
          Text(
            'Compte vérifié',
            style: typo.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Connexion en cours…',
            style: typo.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final enAttente = _cooldown > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PastilleLogo(icone: Icons.mark_email_read_rounded),
        const SizedBox(height: 20),
        Text(
          'Vérifie ton adresse mail',
          style: typo.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'On t’a envoyé un lien de confirmation. Ouvre-le : l’app te '
          'connectera automatiquement.',
          style: typo.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // indicateur « temps réel » : on attend la confirmation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('En attente de confirmation…', style: typo.bodySmall),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _mail,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Adresse mail',
            prefixIcon: Icon(
              Icons.alternate_email,
              color: CouleursSW.texteSecondaire,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (_envoi || enAttente) ? null : _renvoyer,
          child: _envoi
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  enAttente
                      ? 'Renvoyer dans $_cooldown s'
                      : 'Renvoyer l’email de confirmation',
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.surRetour(_mail.text.trim()),
          child: const Text('Revenir à la connexion'),
        ),
      ],
    );
  }
}
