// Connexion / inscription — email ou pseudo + mot de passe.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
            _mail.text.trim(), _pseudo.text.trim(), _motDePasse.text);
        // compte créé : il faut confirmer l'adresse avant de pouvoir se connecter
        if (mounted) setState(() => _mailAverifier = _mail.text.trim());
      } else {
        await session.connexion(_mail.text.trim(), _motDePasse.text);
        // succès : main.dart bascule vers la coquille via le Consumer<Session>
      }
    } on ExceptionApi catch (e) {
      // 403 « Adresse mail non vérifiée » → on propose de renvoyer le lien
      if (!_inscription && e.code == 403 && e.message.contains('vérifi')) {
        final identifiant = _mail.text.trim();
        if (mounted) {
          setState(() =>
              _mailAverifier = identifiant.contains('@') ? identifiant : '');
        }
      } else if (mounted) {
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

  void _basculer(bool inscription) {
    if (_inscription != inscription) {
      setState(() => _inscription = inscription);
    }
  }

  /// Retour au formulaire depuis le panneau de vérification, mail pré-rempli.
  void _revenirConnexion(String mail) {
    if (mail.isNotEmpty) _mail.text = mail;
    _motDePasse.clear();
    setState(() {
      _mailAverifier = null;
      _inscription = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          const Halo(
              couleur: CouleursSW.accent, alignement: Alignment(-1.2, -1.0)),
          const Halo(
              couleur: CouleursSW.accentSecondaire,
              alignement: Alignment(1.3, 1.1)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: _mailAverifier != null
                    ? _PanneauVerification(
                        mailInitial: _mailAverifier!,
                        surRetour: _revenirConnexion)
                    : Form(
                  key: _formulaire,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PastilleLogo(),
                      const SizedBox(height: 20),
                      // Logo
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.sora(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: CouleursSW.texte),
                          children: const [
                            TextSpan(text: 'Sync'),
                            TextSpan(
                                text: 'Watch',
                                style: TextStyle(color: CouleursSW.accent)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text('Tes séries et tes films, au même endroit.',
                          style: typo.bodySmall, textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          _Onglet(
                              libelle: 'Connexion',
                              actif: !_inscription,
                              surTape: () => _basculer(false)),
                          const SizedBox(width: 8),
                          _Onglet(
                              libelle: 'Inscription',
                              actif: _inscription,
                              surTape: () => _basculer(true)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_inscription) ...[
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
                      ],
                      TextFormField(
                        controller: _mail,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: _inscription
                              ? 'Adresse mail'
                              : 'Adresse mail ou pseudo',
                          prefixIcon: const Icon(Icons.alternate_email,
                              color: CouleursSW.texteSecondaire, size: 20),
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
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: CouleursSW.texteSecondaire, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _masquerMdp
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: CouleursSW.texteSecondaire,
                                size: 20),
                            onPressed: () =>
                                setState(() => _masquerMdp = !_masquerMdp),
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
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _chargement ? null : _valider,
                        child: _chargement
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_inscription
                                ? 'Créer mon compte'
                                : 'Se connecter'),
                      ),
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

/// Pastille « icône d'app » : carré arrondi dégradé accent → cyan.
class _PastilleLogo extends StatelessWidget {
  final IconData icone;
  const _PastilleLogo({this.icone = Icons.play_arrow_rounded});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CouleursSW.accent, CouleursSW.accentSecondaire],
          ),
          boxShadow: [
            BoxShadow(
                color: CouleursSW.accent.withValues(alpha: .35),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(icone, size: 44, color: Colors.white),
      ),
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
                  color:
                      actif ? CouleursSW.accent : CouleursSW.texteSecondaire)),
        ),
      ),
    );
  }
}

/// Écran intermédiaire après inscription (ou login d'un compte non vérifié) :
/// invite à confirmer l'adresse mail et permet de renvoyer le lien.
class _PanneauVerification extends StatefulWidget {
  final String mailInitial;
  final void Function(String mail) surRetour;

  const _PanneauVerification(
      {required this.mailInitial, required this.surRetour});

  @override
  State<_PanneauVerification> createState() => _PanneauVerificationState();
}

class _PanneauVerificationState extends State<_PanneauVerification> {
  late final _mail = TextEditingController(text: widget.mailInitial);
  bool _envoi = false;
  int _cooldown = 0; // secondes avant de pouvoir renvoyer
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    _mail.dispose();
    super.dispose();
  }

  void _demarrerCooldown() {
    setState(() => _cooldown = 30);
    _minuteur?.cancel();
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _renvoyer() async {
    final mail = _mail.text.trim();
    if (!mail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renseigne une adresse mail valide.')));
      return;
    }
    setState(() => _envoi = true);
    try {
      await context.read<Session>().renvoyerVerification(mail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Si un compte non vérifié existe, '
                'un nouveau lien vient de partir.')));
      }
      _demarrerCooldown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final enAttente = _cooldown > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PastilleLogo(icone: Icons.mark_email_read_rounded),
        const SizedBox(height: 20),
        Text('Vérifie ton adresse mail',
            style: typo.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
            'On t’a envoyé un lien de confirmation. Ouvre-le pour activer ton '
            'compte, puis reviens te connecter.',
            style: typo.bodySmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        TextField(
          controller: _mail,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Adresse mail',
            prefixIcon: Icon(Icons.alternate_email,
                color: CouleursSW.texteSecondaire, size: 20),
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
                      strokeWidth: 2, color: Colors.white))
              : Text(enAttente
                  ? 'Renvoyer dans $_cooldown s'
                  : 'Renvoyer l’email de confirmation'),
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
