// Connexion / inscription — email ou pseudo + mot de passe.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
      } else {
        await session.connexion(_mail.text.trim(), _motDePasse.text);
      }
      // succès : main.dart bascule vers la coquille via le Consumer<Session>
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
                child: Form(
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
  const _PastilleLogo();

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
        child:
            const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white),
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
